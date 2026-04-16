function abf_to_zav(abfFilePath, zavFilePath, lfp_Fs, detectMua, doResample, collectSweeps, selectedChannels, mua_std_coef, hWaitBar, progressCallback)
    % Конвертирует ABF-файл в формат ZAV.
    %
    % Параметры:
    %   abfFilePath   - путь к ABF-файлу.
    %   zavFilePath   - путь для сохранения ZAV-файла.
    %   lfp_Fs        - желаемая частота дискретизации для LFP (например, 1000 Гц).
    %   detectMua     - логическое значение, указывающее, нужно ли обнаруживать МСА.
    %   doResample    - логическое значение, указывающее, нужно ли выполнять ресемплинг.
    %   collectSweeps - логическое значение, указывающее, нужно ли сохранять данные по свипам.
    
    if nargin < 10
        progressCallback = [];
    end

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
    m = []; % matfile объект
    numSweeps_total = []; % Общее количество свипов для всех каналов
    
    % Profiling: initialize time counters
    profile_times = struct();
    profile_times.total = 0;
    profile_times.abfload = 0;
    profile_times.resample = 0;
    profile_times.mua_detect = 0;
    profile_times.file_write = 0;
    profile_times.lfpVar_calc = 0;
    profile_times.other = 0;
    tic_total = tic;
    formatEta = @(sec) sprintf('~%d min %d s left', floor(sec / 60), round(rem(sec, 60)));
    
    chIdx = 1;
    for truechIdx = selectedChannelIndices'        
        chName = channelNames(truechIdx); % Используем круглые скобки.
        current_message = ['Channel processing: ', chName{1}];
        disp(current_message); % Выводим имя канала.
        
        progress = chIdx / numChannels;
        elapsed = toc(tic_total);
        remain_sec = elapsed * (1 - progress) / max(progress, eps);
        updateWaitbar(progress, sprintf('%d/%d: %s %s', chIdx, numChannels, chName{1}, formatEta(remain_sec)));
        notifyProgress(progress, 'channel', sprintf('Channel %d/%d', chIdx, numChannels));
        
        % Чтение данных канала.
        tic_abf = tic;
        [data, ~, ~] = abfload(abfFilePath, 'channels', chName, 'doDispInfo', false);
        profile_times.abfload = profile_times.abfload + toc(tic_abf);

        % Определение количества свипов и длины свипа.
        % Для gap-free режима данные 2D, для episodic - 3D
        if hd_abf.nOperationMode == 3
            % gap-free режим: данные 2D [data pts] by [channels], но мы запросили один канал
            numSweeps = 1;
            if isempty(numSweeps_total)
                numSweeps_total = 1;
            end
        else
            % episodic режим: данные 3D
            numSweeps = size(data, 3);
            if isempty(numSweeps_total)
                numSweeps_total = numSweeps;
            end
        end

        % Инициализация матрицы для хранения ресемплированных данных.
        data_resampled_all = cell(numSweeps, 1);
        lfp_lengths = zeros(numSweeps, 1);

        for sweepIdx = 1:numSweeps
            if hd_abf.nOperationMode == 3
                % gap-free: данные 2D, преобразуем в вектор
                sweepData = reshape(data, [], 1);
            else
                % episodic: извлекаем данные для текущего свипа
                sweepData = data(:, :, sweepIdx);
                sweepData = reshape(sweepData, [], 1); % Преобразуем в вектор.
            end

            if doResample
                % Используем resample1 для ресемплинга (без краевых эффектов)
                tic_rs = tic;
                data_resampled = resample1(sweepData, actual_lfp_Fs, orig_Fs);
                profile_times.resample = profile_times.resample + toc(tic_rs);
                lfp_length = length(data_resampled);
            else
                data_resampled = sweepData;
                lfp_length = length(data_resampled);
            end

            data_resampled_all{sweepIdx} = data_resampled;
            lfp_lengths(sweepIdx) = lfp_length;

            % Обнаружение МСА, если требуется.
            if detectMua
                % Используем данные текущего свипа для обнаружения МСА.
                tic_mua = tic;
                [tStamp, ampl, shape] = detectMUAzav(sweepData, hd_abf, mua_std_coef, true);
                profile_times.mua_detect = profile_times.mua_detect + toc(tic_mua);
                spks(chIdx, sweepIdx).tStamp = single(tStamp);
                spks(chIdx, sweepIdx).ampl = single(abs(ampl));
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

        % Инициализация матрицы LFP в файле при первом проходе.
        if ~lfp_initialized
            % Создаем matfile для прямого доступа к файлу
            m = matfile(zavFilePath, 'Writable', true);
            
            % Инициализируем lfp в файле (не в памяти)
            % Для gap-free режима всегда используем 2D массив
            if hd_abf.nOperationMode == 3
                % gap-free: 2D массив [lfp_length * numSweeps_total, numChannels]
                m.lfp = zeros(lfp_length * numSweeps_total, numChannels, 'single');
            elseif collectSweeps
                % episodic с collectSweeps: 3D массив
                m.lfp = zeros(lfp_length, numChannels, numSweeps_total, 'single');
            else
                % episodic без collectSweeps: 2D массив
                m.lfp = zeros(lfp_length * numSweeps_total, numChannels, 'single');
            end
            lfp_initialized = true;
        end

        % Подготовка данных канала: собираем все sweeps в один блок
        tic_write = tic;
        if hd_abf.nOperationMode == 3
            % gap-free: один sweep, записываем как есть
            data_resampled = data_resampled_all{1};
            if length(data_resampled) > lfp_length
                data_resampled = data_resampled(1:lfp_length);
            elseif length(data_resampled) < lfp_length
                data_resampled = [data_resampled; zeros(lfp_length - length(data_resampled), 1)];
            end
            % Записываем весь канал одним блоком
            m.lfp(:, chIdx) = single(data_resampled);
        elseif collectSweeps
            % episodic с collectSweeps: записываем все sweeps канала одним блоком
            channel_data = zeros(lfp_length, numSweeps, 'single');
            for sweepIdx = 1:numSweeps
                data_resampled = data_resampled_all{sweepIdx};
                if length(data_resampled) > lfp_length
                    data_resampled = data_resampled(1:lfp_length);
                elseif length(data_resampled) < lfp_length
                    data_resampled = [data_resampled; zeros(lfp_length - length(data_resampled), 1)];
                end
                channel_data(:, sweepIdx) = single(data_resampled);
            end
            % Записываем весь канал со всеми sweeps одним блоком
            m.lfp(:, chIdx, :) = channel_data;
        else
            % episodic без collectSweeps: собираем все sweeps в один вектор
            channel_data = zeros(lfp_length * numSweeps, 1, 'single');
            for sweepIdx = 1:numSweeps
                data_resampled = data_resampled_all{sweepIdx};
                if length(data_resampled) > lfp_length
                    data_resampled = data_resampled(1:lfp_length);
                elseif length(data_resampled) < lfp_length
                    data_resampled = [data_resampled; zeros(lfp_length - length(data_resampled), 1)];
                end
                idx_start = (sweepIdx - 1) * lfp_length + 1;
                idx_end = sweepIdx * lfp_length;
                channel_data(idx_start:idx_end) = single(data_resampled);
            end
            % Записываем весь канал одним блоком
            m.lfp(:, chIdx) = channel_data;
        end
        profile_times.file_write = profile_times.file_write + toc(tic_write);
        chIdx = chIdx+1;
    end

    % Расчет вариации LFP по каналам из данных в файле.
    tic_lfpVar = tic;
    lfpVar = zeros(1, numChannels);
    for chIdx = 1:numChannels
        % Для gap-free режима всегда используем 2D чтение
        if hd_abf.nOperationMode == 3
            channel_data = m.lfp(:, chIdx);
        elseif collectSweeps
            channel_data = m.lfp(:, chIdx, :);
            channel_data = channel_data(:);
        else
            channel_data = m.lfp(:, chIdx);
        end
        lfpVar(chIdx) = std(channel_data) / 10;
    end
    profile_times.lfpVar_calc = toc(tic_lfpVar);

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
        hd.dataPts = lfp_length * numChannels * numSweeps_total;
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
        elseif ~collectSweeps && sweepStartAsStim && hd_abf.nOperationMode ~= 3
            % episodic режим без collectSweeps: упаковываем свипы в один вектор
            % Время стимула = начало каждого свипа в сэмплах сохраненных данных
            % В итоговом векторе начало каждого свипа: 0, lfp_length, 2*lfp_length, ...
            zavp.realStim = struct('r', (0:(numSweeps_total-1))' * lfp_length);
        else
            zavp.realStim = struct('r', []); 
        end
    else
        zavp.realStim = struct('r', []); 
    end
    
    % Инициализация chnlGrp.
    chnlGrp = []; % Если у вас есть информация о группах каналов, можно заполнить.

    % Сохранение остальных данных через matfile.
    m.hd = hd;
    m.spks = spks;
    m.lfpVar = lfpVar;
    m.zavp = zavp;
    m.chnlGrp = chnlGrp;

    % Profiling: final calculation and output
    profile_times.total = toc(tic_total);
    profile_times.other = profile_times.total - profile_times.abfload - profile_times.resample - ...
        profile_times.mua_detect - profile_times.file_write - profile_times.lfpVar_calc;
    
    fprintf('\n=== Profiling abf_to_zav ===\n');
    fprintf('Total time: %.2f sec\n', profile_times.total);
    fprintf('  Data reading (abfload): %.2f sec (%.1f%%)\n', profile_times.abfload, 100*profile_times.abfload/profile_times.total);
    fprintf('  Resampling: %.2f sec (%.1f%%)\n', profile_times.resample, 100*profile_times.resample/profile_times.total);
    fprintf('  MUA detection: %.2f sec (%.1f%%)\n', profile_times.mua_detect, 100*profile_times.mua_detect/profile_times.total);
    fprintf('  File writing (matfile): %.2f sec (%.1f%%)\n', profile_times.file_write, 100*profile_times.file_write/profile_times.total);
    fprintf('  lfpVar calculation: %.2f sec (%.1f%%)\n', profile_times.lfpVar_calc, 100*profile_times.lfpVar_calc/profile_times.total);
    fprintf('  Other: %.2f sec (%.1f%%)\n', profile_times.other, 100*profile_times.other/profile_times.total);
    fprintf('==============================\n\n');

    notifyProgress(1, 'finalize', 'Complete');

    function notifyProgress(itemProgress, stage, message)
        if isempty(progressCallback)
            return;
        end
        progressStruct = struct('itemProgress', itemProgress, 'stage', stage, 'message', message);
        progressCallback(progressStruct);
    end

    function updateWaitbar(itemProgress, message)
        if isempty(progressCallback)
            waitbar(itemProgress, hWaitBar, message);
            return;
        end
        waitbar(itemProgress, hWaitBar);
    end
end