function varargout = detectMUA_streaming(dataChunk, hd, mua_std_coef, remove_ttl_artifact, raw_Fs, muaState, varargin)
% DETECTMUA_STREAMING - Потоковая версия детекции MUA
% Обрабатывает данные по частям без загрузки всего канала в память
%
%   Инициализация:
%       muaState = detectMUA_streaming([], hd, mua_std_coef, remove_ttl_artifact, raw_Fs);
%
%   Обработка чанка:
%       muaState = detectMUA_streaming(chunk, hd, mua_std_coef, remove_ttl_artifact, raw_Fs, muaState);
%
%   Финализация:
%       [tStamp, ampl, shape] = detectMUA_streaming([], hd, mua_std_coef, remove_ttl_artifact, raw_Fs, muaState, 'finalize');
%
%   Args:
%       dataChunk: Вектор данных чанка (или [] для инициализации/финализации)
%       hd: Структура заголовка с параметрами
%       mua_std_coef: Коэффициент порога для детекции
%       remove_ttl_artifact: Флаг удаления TTL артефактов
%       raw_Fs: Частота дискретизации (Hz)
%       muaState: Состояние обработки (для инкрементальной обработки)
%       varargin: 'finalize' для финализации

    % Параметры bandpass фильтра (200-1000 Hz)
    Fc = [200, 1000];
    RC1 = 1/(2*pi*Fc(1));
    alpha1 = RC1/(RC1+1/raw_Fs);
    RC2 = 1/(2*pi*Fc(2));
    alpha2 = RC2/(RC2+1/raw_Fs);
    
    % Инициализация состояния
    if nargin < 6 || isempty(muaState)
        muaState = struct();
        muaState.filt1_state = 0;
        muaState.filt2_state = 0;
        muaState.n = 0;
        muaState.mean_val = 0;
        muaState.M2 = 0;
        muaState.all_peaks = [];
        muaState.all_amplitudes = [];
        muaState.all_prominences = [];
        muaState.current_offset = 0;
        muaState.alpha1 = alpha1;
        muaState.alpha2 = alpha2;
        
        varargout{1} = muaState;
        return;
    end
    
    % Финализация
    if nargin >= 7 && strcmp(varargin{1}, 'finalize')
        std_final = sqrt(muaState.M2 / muaState.n);
        
        % Удаление TTL артефактов (если нужно)
        if remove_ttl_artifact
            if isfield(hd, "inTTL_timestamps")
                ttl_window = 200;
                ttl_ticks = hd.inTTL_timestamps.t(:,1)/hd.fADCSampleInterval;
                
                for ttl1 = ttl_ticks'
                    cond = muaState.all_peaks > ttl1 - ttl_window & muaState.all_peaks < ttl1 + ttl_window & ...
                           muaState.all_prominences < 10*std_final;
                    muaState.all_peaks(cond) = [];
                    muaState.all_amplitudes(cond) = [];
                    muaState.all_prominences(cond) = [];
                end
            end
        end
        
        % Формирование результата
        total_samples = muaState.current_offset;
        Time = 1e3*((0:total_samples-1) / raw_Fs);
        
        if ~isempty(muaState.all_peaks)
            tStamp = np_flatten(Time(muaState.all_peaks))';
            ampl = muaState.all_amplitudes;
        else
            tStamp = [];
            ampl = [];
        end
        shape = [];
        
        varargout{1} = tStamp;
        varargout{2} = ampl;
        varargout{3} = shape;
        return;
    end
    
    % Обработка чанка
    chunk = dataChunk;
    
    % Первый фильтр (low-pass, 200 Hz)
    Filt1 = zeros(size(chunk));
    Filt1(1) = muaState.filt1_state;
    
    for h = 2:length(chunk)
        Filt1(h) = muaState.alpha1*(Filt1(h-1)) + muaState.alpha1*(chunk(h)-chunk(h-1));
    end
    
    % Второй фильтр (high-pass, 1000 Hz)
    Filt2 = zeros(size(Filt1));
    Filt2(1) = muaState.filt2_state;
    
    for h = 2:length(Filt1)
        Filt2(h) = muaState.alpha2*(Filt2(h-1)) + muaState.alpha2*(Filt1(h)-Filt1(h-1));
    end
    
    % Bandpass = low-pass - high-pass
    Filt = Filt1 - Filt2;
    
    % Сохраняем состояние для следующего чанка
    muaState.filt1_state = Filt1(end);
    muaState.filt2_state = Filt2(end);
    
    % Baseline correction с медианным фильтром
    baseline = medfilt1(Filt, 32);
    Filt(Filt>baseline) = baseline(Filt>baseline);
    Filt = Filt - baseline;
    
    % Инкрементальное вычисление std (Welford's algorithm)
    for i = 1:length(Filt)
        muaState.n = muaState.n + 1;
        delta = Filt(i) - muaState.mean_val;
        muaState.mean_val = muaState.mean_val + delta / muaState.n;
        muaState.M2 = muaState.M2 + delta * (Filt(i) - muaState.mean_val);
    end
    
    % Вычисляем текущее std для порога
    std_val = sqrt(muaState.M2 / muaState.n);
    
    % Поиск пиков в текущем чанке
    [chunk_ampl, chunk_spk, ~, chunk_p] = findpeaks(-Filt, ...
        'MinPeakProminence', mua_std_coef*std_val, 'MaxPeakWidth', 12);
    
    % Корректируем индексы пиков с учетом смещения
    chunk_spk = chunk_spk + muaState.current_offset;
    
    % Сохраняем пики
    muaState.all_peaks = [muaState.all_peaks; chunk_spk(:)];
    muaState.all_amplitudes = [muaState.all_amplitudes; chunk_ampl(:)];
    muaState.all_prominences = [muaState.all_prominences; chunk_p(:)];
    
    muaState.current_offset = muaState.current_offset + length(chunk);
    
    varargout{1} = muaState;
end

