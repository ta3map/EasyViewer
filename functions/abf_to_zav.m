function abf_to_zav(abfFilePath, zavFilePath, lfp_Fs, detectMua, doResample, collectSweeps, selectedChannels, mua_std_coef, hWaitBar)
    % Конвертирует ABF-файл в формат ZAV.
    %
    % Параметры:
    %   abfFilePath   - путь к ABF-файлу.
    %   zavFilePath   - путь для сохранения ZAV-файла.
    %   lfp_Fs        - желаемая частота дискретизации для LFP (например, 1000 Гц).
    %   detectMua     - логическое значение, указывающее, нужно ли обнаруживать МСА.
    %   doResample    - логическое значение, указывающее, нужно ли выполнять ресемплинг.
    %   collectSweeps - логическое значение, указывающее, нужно ли сохранять данные по свипам.
    
    sweepStartAsStim = true;
    
    % Чтение заголовка ABF-файла.
    [~, ~, hd_abf] = abfload(abfFilePath, 'stop', 1);

    % Получение списка имен каналов.
    channelNames = hd_abf.recChNames; % Имена каналов.
    % Находим индексы выбранных каналов.
    [~, selectedChannelIndices] = ismember(selectedChannels, channelNames);

    numChannels = numel(selectedChannels); % Количество каналов.

    % Оригинальная частота дискретизации.
    orig_Fs = 1e6 / hd_abf.si; % hd_abf.si в микросекундах на сэмпл.

    % Определяем фактическую частоту дискретизации LFP.
    if doResample
        actual_lfp_Fs = lfp_Fs;
    else
        actual_lfp_Fs = orig_Fs;
    end

    % Инициализация структуры спайков.
    if collectSweeps
        spks = repmat(struct('tStamp', [], 'ampl', [], 'shape', []), numChannels, hd_abf.lActualEpisodes);
    else
        spks = repmat(struct('tStamp', [], 'ampl', [], 'shape', []), numChannels, 1);
    end

    % Предварительные переменные для LFP.
    lfp_initialized = false;
    chIdx = 1;
    for truechIdx = selectedChannelIndices'        
        chName = channelNames(truechIdx); % Используем круглые скобки.
        current_message = ['Channel processing: ', chName{1}];
        disp(current_message); % Выводим имя канала.
        
        waitbar([chIdx/numChannels], hWaitBar, current_message);
        
        % Чтение данных канала.
        [data, ~, ~] = abfload(abfFilePath, 'channels', chName, 'doDispInfo', false);

        % Определение количества свипов и длины свипа.
        numSweeps = size(data, 3);

        % Инициализация матрицы для хранения ресемплированных данных.
        data_resampled_all = cell(numSweeps, 1);
        lfp_lengths = zeros(numSweeps, 1);

        for sweepIdx = 1:numSweeps
            sweepData = data(:, :, sweepIdx);
            sweepData = reshape(sweepData, [], 1); % Преобразуем в вектор.

            if doResample
                % Используем interp1 для обеспечения одинаковой длины данных.
                t_original = (0:length(sweepData)-1) / orig_Fs;
                totalDuration = t_original(end);
                lfp_length = round(totalDuration * actual_lfp_Fs) + 1;
                t_resampled = (0:lfp_length-1) / actual_lfp_Fs;
                data_resampled = interp1(t_original, double(sweepData), t_resampled, 'linear', 'extrap')';
            else
                data_resampled = sweepData;
                lfp_length = length(data_resampled);
            end

            data_resampled_all{sweepIdx} = data_resampled;
            lfp_lengths(sweepIdx) = lfp_length;

            % Обнаружение МСА, если требуется.
            if detectMua
                % Используем данные текущего свипа для обнаружения МСА.
                [tStamp, ampl, shape] = detectMUA(sweepData, hd_abf, mua_std_coef, true);
                spks(chIdx, sweepIdx).tStamp = single(tStamp);
                spks(chIdx, sweepIdx).ampl = single(-ampl);
                spks(chIdx, sweepIdx).shape = shape;
            else
                % Инициализируем пустые поля.
%                 spks(chIdx, sweepIdx).tStamp = [];
%                 spks(chIdx, sweepIdx).ampl = [];
%                 spks(chIdx, sweepIdx).shape = [];
                spks = [];
            end
        end

        % Проверяем, что длина данных одинаковая для всех свипов.
        if any(lfp_lengths ~= lfp_lengths(1))
            warning('The length of resampled data varies between sweeps. Will be truncated to minimum length.');
            lfp_length = min(lfp_lengths);
        else
            lfp_length = lfp_lengths(1);
        end

        % Инициализация матрицы LFP при первом проходе.
        if ~lfp_initialized
            if collectSweeps
                lfp = zeros(lfp_length, numChannels, numSweeps);
            else
                lfp = zeros(lfp_length * numSweeps, numChannels);
            end
            lfp_initialized = true;
        end

        % Заполнение матрицы LFP.
        for sweepIdx = 1:numSweeps
            data_resampled = data_resampled_all{sweepIdx};

            % Усечение или дополнение данных до lfp_length.
            if length(data_resampled) > lfp_length
                data_resampled = data_resampled(1:lfp_length);
            elseif length(data_resampled) < lfp_length
                data_resampled = [data_resampled; zeros(lfp_length - length(data_resampled), 1)];
            end

            if collectSweeps
                lfp(:, chIdx, sweepIdx) = data_resampled;
            else
                idx_start = (sweepIdx - 1) * lfp_length + 1;
                idx_end = sweepIdx * lfp_length;
                lfp(idx_start:idx_end, chIdx) = data_resampled;
            end
        end
        chIdx = chIdx+1;
    end

    % Расчет вариации LFP по каналам.
    if collectSweeps
        lfpVar = squeeze(var(lfp));        
    else
        lfpVar = var(reshape(lfp, [], numChannels));
    end

    % Сборка структуры hd для ZAV.
    hd = struct();
    hd.fFileSignature = hd_abf.fFileSignature;
    hd.nOperationMode = hd_abf.nOperationMode;
    hd.lActualEpisodes = hd_abf.lActualEpisodes;
    hd.nADCNumChannels = numChannels;
    hd.recChNames = selectedChannels;
    hd.recChUnits = hd_abf.recChUnits(selectedChannelIndices);
    hd.ch_si = repmat(1e6 / actual_lfp_Fs, 1, numChannels); % Интервал сэмплирования в микросекундах.
    hd.dataPtsPerChan = lfp_length;
    if collectSweeps
        hd.dataPts = lfp_length * numChannels * numSweeps;
    else
        hd.dataPts = lfp_length * numChannels;
    end
    hd.si = 1e6 / actual_lfp_Fs; % Обновляем si в микросекундах.
    hd.fADCSampleInterval = hd_abf.fADCSampleInterval;
    hd.recTime = hd_abf.recTime;
    %hd.sweepStartInPts = hd_abf.sweepStartInPts;

    % Создание структуры zavp.
    zavp = struct();
    zavp.file = abfFilePath;
    zavp.siS = 1 / orig_Fs; % Интервал сэмплирования в секундах.
    zavp.dwnSmplFrq = actual_lfp_Fs; % Частота дискретизации LFP.
    zavp.stimCh = []; % Предположим, что нет стимуляционных каналов.
    
    % Добавляем поле 'r' в realStim.
    if isfield(hd_abf, 'sweepStartInPts')
        if collectSweeps && sweepStartAsStim
            zavp.realStim = struct('r', zeros(size(hd_abf.sweepStartInPts))');
        end
    else
        zavp.realStim = struct('r', []); 
    end
    
    % Инициализация chnlGrp.
    chnlGrp = []; % Если у вас есть информация о группах каналов, можно заполнить.

    % Сохранение данных в ZAV-файл.
    save(zavFilePath, 'lfp', 'spks', 'hd', 'lfpVar', 'zavp', 'chnlGrp', '-v7.3');

end