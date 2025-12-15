function metadata = prepareSlopeMeasurementMetadata(measurement_metadata, params, stim_time, stim_inx, time_back, time_forward)
    % prepareSlopeMeasurementMetadata - подготовка полной структуры metadata для результата измерения
    % Создает структуру metadata совместимую с signalAnalysisGUI
    %
    % Входные параметры:
    %   measurement_metadata - метаданные из calculateMeasurementByType
    %   params                - параметры измерения из JSON
    %   stim_time             - абсолютное время стимула
    %   stim_inx              - индекс стимула
    %   time_back             - время назад от стимула
    %   time_forward          - время вперед от стимула
    %
    % Выходные параметры:
    %   metadata - полная структура metadata совместимая с signalAnalysisGUI
    
    % Копируем базовые метаданные из measurement_metadata
    metadata = measurement_metadata;
    
    % Добавляем параметры измерения
    metadata.channel = params.Channel;
    metadata.baseline_start = stim_time + params.BaselineStart_s;  % абсолютное время
    metadata.baseline_end = stim_time + params.BaselineEnd_s;
    metadata.peak_start = stim_time + params.PeakStart_s;
    metadata.peak_end = stim_time + params.PeakEnd_s;
    metadata.slope_percent = params.SlopePercent;
    metadata.peak_polarity = params.PeakPolarity;
    
    % Временной интервал
    metadata.chosen_time_interval = [stim_time - time_back, stim_time + time_forward];
    
    % Информация о стимуле
    metadata.rel_shift = stim_time;  % критически важно для совместимости
    metadata.stim_inx = stim_inx;
    metadata.stim_time = stim_time;
    
    % Режим навигации
    metadata.selectedCenter = 'stimulus';
    metadata.event_inx = NaN;
    metadata.sweep_inx = NaN;
    
    % Настройки онсета
    if ~isfield(metadata, 'onset_method')
        metadata.onset_method = 'calculated_by_slope';
    end
    if ~isfield(metadata, 'onset_threshold')
        metadata.onset_threshold = NaN;
    end
    
    % Настройки видимости
    metadata.show_baseline = true;
    metadata.show_onset = true;
    metadata.show_slope = true;
    metadata.show_peak = true;
    
    % Позиции курсоров (абсолютные времена)
    metadata.cursor_positions = struct();
    metadata.cursor_positions.baseline_start = metadata.baseline_start;
    metadata.cursor_positions.baseline_end = metadata.baseline_end;
    metadata.cursor_positions.peak_start = metadata.peak_start;
    metadata.cursor_positions.peak_end = metadata.peak_end;
    
    % Поля для зума (не используются в модуле, но нужны для совместимости)
    metadata.zoom_active = false;
    metadata.zoom_start_rel = 0;
    metadata.zoom_end_rel = 1;
    metadata.zoom_y_min = [];
    metadata.zoom_y_max = [];
    metadata.original_xlim = [];
    metadata.original_ylim = [];
end

