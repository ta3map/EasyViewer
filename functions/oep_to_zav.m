function oep_to_zav(recordedData, zavFilePath, Fs, newFs, detectMua, mua_std_coef, doResample, channelNames, selectedChIndexes)
% OEP_TO_ZAV Converts Open Ephys data to ZAV format, writing LFP data incrementally to avoid memory issues.
%
%   Args:
%       recordedData: Struct containing Open Ephys data (e.g., from load_open_ephys_data_faster)
%       zavFilePath: Full path to the output .mat file (will be saved in v7.3 format).
%       Fs: Original sampling frequency (Hz).
%       newFs: Target sampling frequency for LFP resampling (Hz). Ignored if doResample is false.
%       detectMua: Boolean flag to enable/disable MUA detection.
%       mua_std_coef: Standard deviation coefficient for MUA detection threshold.
%       doResample: Boolean flag to enable/disable LFP resampling.
%       channelNames: Cell array of all channel names in the original data.
%       selectedChIndexes: Numeric array of indices of the channels to process and save.

    selectedChannels = channelNames(selectedChIndexes);
    recsNumber = size(recordedData, 1);
    numChannels = numel(selectedChannels);

    disp(['Processing ', num2str(numChannels), ' channels.']);

    % --- 1. Предварительный расчет общей длины LFP ---
    % Это необходимо для инициализации переменной lfp в mat-файле правильного размера.
    disp('Calculating final LFP length...');
    final_lfp_length = 0;
    if doResample
        % Рассчитываем длину после ресемплинга, обрабатывая первую запись для примера
        % ПРИМЕЧАНИЕ: Это предполагает, что все записи имеют одинаковую длину!
        % Если записи могут иметь разную длину, нужно будет просуммировать длины всех.
        % Для точности лучше просуммировать длины *всех* записей после ресемплинга.
        for recinx = 1:recsNumber
            % Преобразуем в double перед resample для расчета длины
            temp_data = double(recordedData.Continuous_Samples{recinx}(1, :)');
             % Используем resample на небольшом фрагменте или первом канале, чтобы оценить длину
             % Важно: resample может немного изменять длину из-за краевых эффектов.
             % Безопаснее всего будет обработать *каждый* сегмент.
            resampled_segment = resample(temp_data, newFs, Fs);
            final_lfp_length = final_lfp_length + length(resampled_segment);
            clear temp_data resampled_segment; % Освобождаем память
        end
        disp(['Calculated resampled LFP length: ', num2str(final_lfp_length)]);
    else
        % Просто суммируем длины всех записей
        for recinx = 1:recsNumber
            final_lfp_length = final_lfp_length + length(recordedData.Continuous_Samples{recinx}(1, :));
        end
         disp(['Calculated original LFP length: ', num2str(final_lfp_length)]);
    end
    
    if final_lfp_length == 0
        error('Calculated LFP length is zero. Check input data or calculation logic.');
    end

    % --- 2. Инициализация mat-файла и метаданных ---
    disp(['Initializing output file: ', zavFilePath]);
    m = matfile(zavFilePath, 'Writable', true);

    % Сохраняем заголовок (hd)
    hd.fFileSignature = 'Openephys';
    hd.recChNames = selectedChannels;
    hd.si = (1/Fs) * 1e6; % Sampling interval in microseconds
    m.hd = hd;
    m.chnlGrp = {};

    % Подготовка и сохранение структуры zavp
    zavp.file = zavFilePath;
    zavp.siS = 1 / Fs; % Sampling interval in seconds
    if doResample
        zavp.dwnSmplFrq = newFs;
        zavp.rarStep = zeros(1, numChannels) + (Fs / newFs); % Skip points after resampling
    else
        zavp.dwnSmplFrq = Fs; % If not resampling, effective frequency is the original
        zavp.rarStep = ones(1, numChannels); % Skip points is 1 (no skipping)
    end
    zavp.stimCh = nan;
    zavp.realStim.r = [];
    zavp.realStim.f = [];
    m.zavp = zavp; % Сохраняем zavp в файл

    % Инициализация переменной LFP в файле нужного размера и типа (double)
    % MATLAB создаст переменную в файле, не загружая ее в память
    m.lfp(final_lfp_length, numChannels) = 0.0; % Используем double

    % Инициализация массива для хранения вариации по каждому каналу
    lfpVar_channelwise = zeros(1, numChannels);

    % --- 3. Обнаружение MUA (если включено) ---
    % Эта часть обычно не требует огромной памяти, т.к. обрабатывается по каналам
    spks = struct('tStamp', cell(1, numChannels), 'ampl', cell(1, numChannels), 'shape', cell(1, numChannels));
    if detectMua
        hWaitBarMUA = waitbar(0, 'Starting MUA detection...', 'Name', 'MUA detection.');
        for chIdx = 1:numChannels
            lfp_channel_data_for_mua = [];
            current_channel_global_index = selectedChIndexes(chIdx);
            channelName = strrep(channelNames{current_channel_global_index}, '_', ' ');
            waitbar(chIdx/numChannels, hWaitBarMUA, ['MUA Detection: Channel ', channelName]);

            % Собираем данные для текущего канала из всех записей
            for recinx = 1:recsNumber
                % Загружаем и преобразуем только нужный канал
                channel_data_segment = double(recordedData.Continuous_Samples{recinx}(current_channel_global_index, :)');
                lfp_channel_data_for_mua = [lfp_channel_data_for_mua; channel_data_segment];
                clear channel_data_segment; % Освобождаем память сегмента
            end

            % Детектируем MUA
            disp(['Detecting MUA for channel: ', channelName]);
            [tStamp, ampl, shape] = detectMUA(lfp_channel_data_for_mua, hd, mua_std_coef, true);
            spks(chIdx).tStamp = double(tStamp);
            spks(chIdx).ampl = double(-ampl); % Note the sign change as in original code
            spks(chIdx).shape = shape;

            clear lfp_channel_data_for_mua tStamp ampl shape; % Освобождаем память канала MUA

            percent = chIdx / numChannels;
            current_message = ['MUA detection complete for: ', channelName, ' (', num2str(percent * 100, '%.1f'), '%)'];
            disp(current_message);
        end
        try % Close waitbar safely
           close(hWaitBarMUA);
        catch
        end
        disp('MUA detection finished.');
        % Сохраняем spks в файл сразу после расчета
        m.spks = spks;
        clear spks; % Освобождаем память spks
    else
        disp('MUA detection skipped.');
         % Если MUA не детектируется, нужно сохранить пустую структуру spks
         % или инициализировать ее как переменную в matfile
         m.spks = spks; % Сохраняем пустую инициализированную структуру
         clear spks;
    end


    % --- 4. Обработка LFP (Resampling или копирование) и запись в файл ---
    disp('Processing LFP data channel by channel and writing to file...');
    hWaitBarLFP = waitbar(0, 'Starting LFP processing...', 'Name', 'LFP Processing');

    for chIdx = 1:numChannels
        current_channel_global_index = selectedChIndexes(chIdx);
        channelName = strrep(channelNames{current_channel_global_index}, '_', ' ');
        waitbar(chIdx/numChannels, hWaitBarLFP, ['Processing LFP: Channel ', channelName]);
        disp(['Processing LFP for channel: ', channelName]);

        lfp_channel_processed = []; % Временный массив для данных текущего канала

        % Собираем и обрабатываем (resample или копируем) данные для текущего канала
        for recinx = 1:recsNumber
            % Загружаем и преобразуем только нужный канал
            channel_data_segment = double(recordedData.Continuous_Samples{recinx}(current_channel_global_index, :)');

            if doResample
                resampled_segment = resample(channel_data_segment, newFs, Fs);
                lfp_channel_processed = [lfp_channel_processed; resampled_segment];
                clear resampled_segment;
            else
                lfp_channel_processed = [lfp_channel_processed; channel_data_segment];
            end
             clear channel_data_segment; % Освобождаем память сегмента
        end

        % Проверяем, совпадает ли длина обработанного канала с ожидаемой
        if length(lfp_channel_processed) ~= final_lfp_length
             warning('MATLAB:LengthMismatch', ...
                 'Length of processed data for channel %s (%d) does not match expected length (%d). Check calculation or data consistency.', ...
                 channelName, length(lfp_channel_processed), final_lfp_length);
             % Попытка исправить: записываем только до final_lfp_length, если длинее,
             % или дополняем нулями, если короче (хотя это может исказить данные).
             % Безопаснее всего остановить или тщательно проверить логику расчета final_lfp_length.
             if length(lfp_channel_processed) > final_lfp_length
                 lfp_channel_processed = lfp_channel_processed(1:final_lfp_length);
             else
                 % Дополнение нулями может быть нежелательно. Рассмотрим alternative.
                 % Возможно, стоит пересчитать final_lfp_length более точно.
                 % пока оставим как есть
             end
             % Ensure it fits if adjusted
              if length(lfp_channel_processed) > m.Properties.Size(1)
                   lfp_channel_processed = lfp_channel_processed(1:m.Properties.Size(1));
              end
        end
        
        % Записываем обработанные данные канала непосредственно в mat-файл
        % Используем синтаксис m.variable(rows, cols) = data;
        % Убедимся что размер не превышает инициализированный
        rows_to_write = min(length(lfp_channel_processed), final_lfp_length);
        m.lfp(1:rows_to_write, chIdx) = lfp_channel_processed(1:rows_to_write);

        % Рассчитываем вариацию для текущего канала и сохраняем
        lfpVar_channelwise(chIdx) = var(lfp_channel_processed);

        clear lfp_channel_processed; % Освобождаем память канала

        percent = chIdx / numChannels;
        current_message = ['LFP processing complete for: ', channelName, ' (', num2str(percent * 100, '%.1f'), '%)'];
        disp(current_message);

    end
    try % Close waitbar safely
       close(hWaitBarLFP);
    catch
    end

    % --- 5. Сохранение вариации LFP ---
    disp('Saving LFP variance...');
    m.lfpVar = lfpVar_channelwise; % Сохраняем массив вариаций по каналам

    disp('Processing complete. Data saved to:');
    disp(zavFilePath);

end

