function [slope_value, slope_angle, peak_time, peak_value, baseline_value, onset_time, onset_value, measurement_metadata] = ...
    calculateSlopeMeasurement(channel_data, time_vector, baseline_start, baseline_end, peak_start, peak_end, ...
    slope_percent, peak_polarity, rel_shift)
    % calculateSlopeMeasurement - расчет всех результатов измерения (slope, peak, onset, baseline)
    % Адаптированная версия calculateResults() из signalAnalysisGUI
    %
    % Входные параметры:
    %   channel_data   - вектор данных канала [samples x 1]
    %   time_vector     - вектор времени (абсолютное время) [samples x 1]
    %   baseline_start  - начало диапазона baseline (абсолютное время)
    %   baseline_end    - конец диапазона baseline (абсолютное время)
    %   peak_start      - начало диапазона поиска пика (абсолютное время)
    %   peak_end        - конец диапазона поиска пика (абсолютное время)
    %   slope_percent   - процент для расчета slope точек (например, 20)
    %   peak_polarity   - полярность пика ('positive' или 'negative')
    %   rel_shift       - сдвиг для преобразования в относительное время (обычно время стимула)
    %
    % Выходные параметры:
    %   slope_value         - значение slope
    %   slope_angle         - угол наклона в градусах
    %   peak_time           - относительное время пика
    %   peak_value          - значение пика
    %   baseline_value      - значение baseline
    %   onset_time          - относительное время онсета
    %   onset_value         - значение онсета
    %   measurement_metadata - структура с метаданными измерения
    
    % Инициализация выходных переменных
    slope_value = NaN;
    slope_angle = NaN;
    peak_time = NaN;
    peak_value = NaN;
    baseline_value = NaN;
    onset_time = NaN;
    onset_value = NaN;
    measurement_metadata = struct();
    
    % Проверка входных данных
    if isempty(channel_data) || isempty(time_vector) || length(channel_data) ~= length(time_vector)
        return;
    end
    
    % Преобразуем абсолютные времена в относительные
    time_vector_rel = time_vector - rel_shift;
    baseline_start_rel = baseline_start - rel_shift;
    baseline_end_rel = baseline_end - rel_shift;
    peak_start_rel = peak_start - rel_shift;
    peak_end_rel = peak_end - rel_shift;
    
    % Создаем структуру baseline_data для calculateMeasurementByType
    baseline_data_struct = struct();
    baseline_data_struct.baseline_start = baseline_start_rel;
    baseline_data_struct.baseline_end = baseline_end_rel;
    baseline_data_struct.peak_start = peak_start_rel;
    baseline_data_struct.peak_end = peak_end_rel;
    baseline_data_struct.slope_percent = slope_percent;
    baseline_data_struct.peak_polarity = peak_polarity;
    
    % Расчет slope с использованием calculateMeasurementByType
    [slope_value, measurement_metadata] = calculateMeasurementByType(channel_data, time_vector_rel, ...
        baseline_data_struct.peak_start, baseline_data_struct.peak_end, 'Slope', baseline_data_struct);
    
    % Добавляем rel_shift в метаданные для возможности получения абсолютного времени
    measurement_metadata.rel_shift = rel_shift;
    
    % Извлекаем все необходимые значения из метаданных
    if isfield(measurement_metadata, 'slope_angle')
        slope_angle = measurement_metadata.slope_angle;
    else
        slope_angle = NaN;
    end
    
    if isfield(measurement_metadata, 'peak_time')
        peak_time = measurement_metadata.peak_time;
    else
        peak_time = NaN;
    end
    
    if isfield(measurement_metadata, 'peak_value')
        peak_value = measurement_metadata.peak_value;
    else
        peak_value = NaN;
    end
    
    if isfield(measurement_metadata, 'baseline_value')
        baseline_value = measurement_metadata.baseline_value;
    else
        baseline_value = NaN;
    end
    
    if isfield(measurement_metadata, 'onset_time')
        onset_time = measurement_metadata.onset_time;
    else
        onset_time = NaN;
    end
    
    if isfield(measurement_metadata, 'onset_value')
        onset_value = measurement_metadata.onset_value;
    else
        onset_value = NaN;
    end
    
    % Добавляем onset_method если его нет
    if ~isfield(measurement_metadata, 'onset_method')
        measurement_metadata.onset_method = 'calculated_by_slope';
    end
end






