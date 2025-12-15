function result = autoSlopeMeasurement(filePath, fileId, params)
    % autoSlopeMeasurement - автоматическое измерение slope для всех стимулов
    % Использует те же алгоритмы что и signalAnalysisGUI
    
    global zav_calling timeUnitFactor
    % timeUnitFactor используется только для сохранения результатов, не для расчетов
    global lfp time Fs stims stims_exist
    global art_rem_window_ms mean_group_ch
    
    % Инициализация глобальных переменных если не заданы
    if ~exist('art_rem_window_ms', 'var') || isempty(art_rem_window_ms)
        art_rem_window_ms = 0;
    end
    if ~exist('mean_group_ch', 'var')
        mean_group_ch = [];
    end
    
    % Загрузка файла через zav_calling
    metadata = zav_calling(filePath);
    
    % Проверка наличия стимулов
    if ~stims_exist || isempty(stims)
        debugState('autoSlopeMeasurement', '❌ No stimuli found in file');
        result = struct( ...
            'module_name', 'autoSlopeMeasurement', ...
            'module_display_name', 'Auto Slope Measurement', ...
            'module_description', 'Автоматическое измерение slope для всех стимулов', ...
            'parameters', params, ...
            'num_results', 0);
        return;
    end
    
    % Инициализация результатов
    slope_measurement_results = [];
    
    % Параметры из JSON
    channel_idx = params.Channel;
    baseline_start_rel = params.BaselineStart_s;
    baseline_end_rel = params.BaselineEnd_s;
    peak_start_rel = params.PeakStart_s;
    peak_end_rel = params.PeakEnd_s;
    slope_percent = params.SlopePercent;
    peak_polarity = params.PeakPolarity;
    time_back = params.TimeBack_s;
    time_forward = params.TimeForward_s;
    
    % Параметры обработки
    smoothing_enabled = params.SmoothingEnabled;
    smoothing_span = params.SmoothingSpan;
    smoothing_method = params.SmoothingMethod;
    remove_artifact = params.RemoveArtifact;
    artifact_window_ms = params.ArtifactWindow_ms;
    
    % Проверка корректности канала
    if channel_idx > size(lfp, 2)
        debugState('autoSlopeMeasurement', '⚠️ Channel %d out of range, using channel 1', channel_idx);
        channel_idx = 1;
    end
    
    % Подготовка параметров для getSignalDataForInterval
    data_params = struct();
    data_params.smoothing_enabled = smoothing_enabled;
    data_params.smoothing_span = smoothing_span;
    data_params.smoothing_method = smoothing_method;
    data_params.remove_artifact = remove_artifact;
    data_params.artifact_window_ms = artifact_window_ms;
    data_params.stims = stims;
    data_params.Fs = Fs;
    data_params.mean_group_ch = mean_group_ch;
    
    % Создаем окно прогресса
    total_stims = length(stims);
    hWaitBar = waitbar(0, sprintf('Processing stimulus 1 of %d...', total_stims), 'Name', 'Auto Slope Measurement');
    
    % Цикл по всем стимулам
    for i = 1:total_stims
        % Обновляем прогресс
        progress = i / total_stims;
        waitbar(progress, hWaitBar, sprintf('Processing stimulus %d of %d (%.0f%%)...', i, total_stims, progress*100));
        
        stim_time = stims(i);
        
        try
            % Абсолютные времена для baseline и peak
            baseline_start_abs = stim_time + baseline_start_rel;
            baseline_end_abs = stim_time + baseline_end_rel;
            peak_start_abs = stim_time + peak_start_rel;
            peak_end_abs = stim_time + peak_end_rel;
            
            % Временной интервал для текущего стимула
            time_interval = [stim_time - time_back, stim_time + time_forward];
            
            % Определяем минимальный интервал для расчетов
            calc_interval = getMeasurementInterval(baseline_start_abs, baseline_end_abs, ...
                peak_start_abs, peak_end_abs, time_interval, time_back, time_forward, time);
            
            % Получаем данные для расчетов (расширенный интервал)
            % Используем параметры обработки, включая сглаживание
            [calc_channel_data, calc_time_vector] = getSignalDataForInterval(lfp, time, channel_idx, calc_interval, data_params);
            
            if isempty(calc_channel_data) || isempty(calc_time_vector)
                debugState('autoSlopeMeasurement', '⚠️ No calculation data for stimulus %d, skipping', i);
                continue;
            end
            
            % Вычисляем результаты измерения
            [slope_value, slope_angle, peak_time, peak_value, baseline_value, onset_time, onset_value, measurement_metadata] = ...
                calculateSlopeMeasurement(calc_channel_data, calc_time_vector, baseline_start_abs, baseline_end_abs, ...
                peak_start_abs, peak_end_abs, slope_percent, peak_polarity, stim_time);
            
            % Подготавливаем полную структуру metadata
            full_metadata = prepareSlopeMeasurementMetadata(measurement_metadata, params, stim_time, i, time_back, time_forward);
            
            % Создаем результат
            new_result = struct(...
                'baseline_value', baseline_value, ...
                'slope_value', slope_value, ...
                'peak_time', peak_time, ...
                'peak_value', peak_value, ...
                'onset_time', onset_time, ...
                'onset_value', onset_value, ...
                'onset_method', full_metadata.onset_method, ...
                'metadata', full_metadata);
            
            % Добавляем результат
            slope_measurement_results = [slope_measurement_results, new_result];
            
        catch ME
            debugState('autoSlopeMeasurement', '⚠️ Error processing stimulus %d: %s', i, ME.message);
            continue;
        end
    end
    
    % Закрываем окно прогресса
    if exist('hWaitBar', 'var') && ishandle(hWaitBar)
        close(hWaitBar);
    end
    
    % Проверка наличия результатов
    if isempty(slope_measurement_results)
        debugState('autoSlopeMeasurement', '❌ No valid results obtained');
        result = struct( ...
            'module_name', 'autoSlopeMeasurement', ...
            'module_display_name', 'Auto Slope Measurement', ...
            'module_description', 'Автоматическое измерение slope для всех стимулов', ...
            'parameters', params, ...
            'num_results', 0);
        return;
    end
    
    % Сохранение результатов
    [folder, baseName, ~] = fileparts(metadata.filePath);
    excel_path = fullfile(folder, [baseName, '_auto_slope_measurements.xlsx']);
    
    % Инициализация result_info
    result_info = struct('success', false, 'excel_path', excel_path, 'meta_path', '');
    
    try
        % Получаем timeUnitFactor если не задан
        if ~exist('timeUnitFactor', 'var') || isempty(timeUnitFactor)
            timeUnitFactor = 1;
        end
        
        % Сохраняем результаты
        result_info = saveSlopeMeasurementResults(slope_measurement_results, excel_path, timeUnitFactor, ...
            metadata.filePath, baseName, params);
        
        if result_info.success
            debugState('autoSlopeMeasurement', '✓ Results saved:');
            debugState('autoSlopeMeasurement', '  Excel: %s', result_info.excel_path);
            debugState('autoSlopeMeasurement', '  Metadata: %s', result_info.meta_path);
            debugState('autoSlopeMeasurement', '  Total records: %d', length(slope_measurement_results));
        else
            debugState('autoSlopeMeasurement', '❌ Error saving results');
            if isfield(result_info, 'error')
                debugState('autoSlopeMeasurement', '  Error: %s', result_info.error);
            end
        end
        
    catch ME
        debugState('autoSlopeMeasurement', '❌ Error saving results: %s', ME.message);
        result_info.success = false;
        result_info.error = ME.message;
    end
    
    % Возвращаем структуру результата
    result = struct( ...
        'module_name', 'autoSlopeMeasurement', ...
        'module_display_name', 'Auto Slope Measurement', ...
        'module_description', 'Автоматическое измерение slope для всех стимулов', ...
        'parameters', params, ...
        'num_results', length(slope_measurement_results));
    
    % Добавляем пути к файлам если сохранение прошло успешно
    if result_info.success
        result.report_path = result_info.excel_path;
        result.data_path = result_info.meta_path;
    else
        result.report_path = excel_path;
        result.data_path = '';
    end
end

