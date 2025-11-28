function [tStamp, ampl, shape] = detectMUA_streaming(dataChunks, hd, mua_std_coef, remove_ttl_artifact, raw_Fs)
% DETECTMUA_STREAMING - Потоковая версия детекции MUA
% Обрабатывает данные по частям без загрузки всего канала в память
%
%   Args:
%       dataChunks: Cell array с чанками данных канала
%       hd: Структура заголовка с параметрами
%       mua_std_coef: Коэффициент порога для детекции
%       remove_ttl_artifact: Флаг удаления TTL артефактов
%       raw_Fs: Частота дискретизации (Hz)

    % Параметры bandpass фильтра (200-1000 Hz)
    Fc = [200, 1000];
    RC1 = 1/(2*pi*Fc(1));
    alpha1 = RC1/(RC1+1/raw_Fs);
    RC2 = 1/(2*pi*Fc(2));
    alpha2 = RC2/(RC2+1/raw_Fs);
    
    % Инициализация состояния фильтров
    filt1_state = 0;
    filt2_state = 0;
    
    % Инициализация для инкрементального вычисления std (Welford's algorithm)
    n = 0;
    mean_val = 0;
    M2 = 0;
    
    % Массивы для сбора всех пиков
    all_peaks = [];
    all_amplitudes = [];
    all_prominences = [];
    
    % Текущее смещение для индексов
    current_offset = 0;
    
    % Обработка всех чанков
    for chunkIdx = 1:length(dataChunks)
        chunk = dataChunks{chunkIdx};
        
        % Первый фильтр (low-pass, 200 Hz)
        Filt1 = zeros(size(chunk));
        Filt1(1) = filt1_state; % Продолжаем с предыдущего состояния
        
        for h = 2:length(chunk)
            Filt1(h) = alpha1*(Filt1(h-1)) + alpha1*(chunk(h)-chunk(h-1));
        end
        
        % Второй фильтр (high-pass, 1000 Hz)
        Filt2 = zeros(size(Filt1));
        Filt2(1) = filt2_state;
        
        for h = 2:length(Filt1)
            Filt2(h) = alpha2*(Filt2(h-1)) + alpha2*(Filt1(h)-Filt1(h-1));
        end
        
        % Bandpass = low-pass - high-pass
        Filt = Filt1 - Filt2;
        
        % Сохраняем состояние для следующего чанка
        filt1_state = Filt1(end);
        filt2_state = Filt2(end);
        
        % Baseline correction с медианным фильтром
        baseline = medfilt1(Filt, 32);
        Filt(Filt>baseline) = baseline(Filt>baseline);
        Filt = Filt - baseline;
        
        % Инкрементальное вычисление std (Welford's algorithm)
        for i = 1:length(Filt)
            n = n + 1;
            delta = Filt(i) - mean_val;
            mean_val = mean_val + delta / n;
            M2 = M2 + delta * (Filt(i) - mean_val);
        end
        
        % Вычисляем текущее std для порога
        std_val = sqrt(M2 / n);
        
        % Поиск пиков в текущем чанке
        [chunk_ampl, chunk_spk, ~, chunk_p] = findpeaks(-Filt, ...
            'MinPeakProminence', mua_std_coef*std_val, 'MaxPeakWidth', 12);
        
        % Корректируем индексы пиков с учетом смещения
        chunk_spk = chunk_spk + current_offset;
        
        % Сохраняем пики
        all_peaks = [all_peaks; chunk_spk(:)];
        all_amplitudes = [all_amplitudes; chunk_ampl(:)];
        all_prominences = [all_prominences; chunk_p(:)];
        
        current_offset = current_offset + length(chunk);
    end
    
    % Финальное std
    std_final = sqrt(M2 / n);
    
    % Удаление TTL артефактов (если нужно)
    if remove_ttl_artifact
        if isfield(hd, "inTTL_timestamps")
            ttl_window = 200;
            ttl_ticks = hd.inTTL_timestamps.t(:,1)/hd.fADCSampleInterval;
            
            for ttl1 = ttl_ticks'
                cond = all_peaks > ttl1 - ttl_window & all_peaks < ttl1 + ttl_window & ...
                       all_prominences < 10*std_final;
                all_peaks(cond) = [];
                all_amplitudes(cond) = [];
                all_prominences(cond) = [];
            end
        end
    end
    
    % Формирование результата
    total_samples = current_offset;
    Time = 1e3*((0:total_samples-1) / raw_Fs);
    
    if ~isempty(all_peaks)
        tStamp = np_flatten(Time(all_peaks))';
        ampl = all_amplitudes;
    else
        tStamp = [];
        ampl = [];
    end
    shape = [];
end

