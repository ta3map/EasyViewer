function [slope_value, slope_angle, regression_points, peak_time, peak_value] = ...
    calculateSlope(channel_data, time_vector, baseline_value, ...
                  peak_start, peak_end, slope_percent, peak_polarity)
    % calculateSlope - расчет наклона (slope) сигнала с использованием baseline
    % Принимает baseline_value как входной параметр
    %
    % Входные параметры:
    %   channel_data   - вектор данных канала
    %   time_vector    - соответствующий вектор времени
    %   baseline_value - значение базовой линии (рассчитывается снаружи)
    %   peak_start     - начало диапазона поиска пика (в секундах)
    %   peak_end       - конец диапазона поиска пика (в секундах)
    %   slope_percent  - процент для расчета slope точек (например, 20)
    %   peak_polarity  - полярность пика ('positive' или 'negative')
    %
    % Выходные параметры:
    %   slope_value      - значение наклона (dy/dx)
    %   slope_angle      - угол наклона в градусах
    %   regression_points - структура с точками для линейной регрессии
    %   peak_time        - время пика
    %   peak_value       - значение амплитуды пика
    
    % Инициализация выходных значений
    slope_value = NaN;
    slope_angle = NaN;
    regression_points = struct('time1', NaN, 'value1', NaN, 'time2', NaN, 'value2', NaN);
    peak_time = NaN;
    peak_value = NaN;
    
    % Проверка входных данных
    if length(channel_data) ~= length(time_vector)
        error('Channel data and time vector must have the same length');
    end
    
    % Проверка baseline_value
    if isnan(baseline_value)
        warning('Invalid baseline_value provided');
        return;
    end
    
    % 1. Поиск пика в заданном диапазоне
    peak_indices = find(time_vector >= peak_start & time_vector <= peak_end);
    if isempty(peak_indices)
        warning('No data points found in peak search range');
        return;
    end
    
    peak_data_segment = channel_data(peak_indices);
    if strcmp(peak_polarity, 'positive')
        [peak_value, peak_idx_local] = max(peak_data_segment);
    else % negative
        [peak_value, peak_idx_local] = min(peak_data_segment);
    end
    
    peak_idx_global = peak_indices(peak_idx_local);
    peak_time = time_vector(peak_idx_global);
    
    % 2. Расчет точек для slope
    % Расстояние от baseline до пика
    peak_distance = abs(peak_value - baseline_value);
    
    % Точка на slope_percent% выше baseline (в направлении к пику)
    if strcmp(peak_polarity, 'positive')
        target_value1 = baseline_value + peak_distance * (slope_percent / 100);
    else
        target_value1 = baseline_value - peak_distance * (slope_percent / 100);
    end
    
    % Точка на slope_percent% ниже пика (в направлении к baseline)
    if strcmp(peak_polarity, 'positive')
        target_value2 = peak_value - peak_distance * (slope_percent / 100);
    else
        target_value2 = peak_value + peak_distance * (slope_percent / 100);
    end
    
    % 3. Поиск соответствующих временных точек
    % Ищем точки только от начала peak диапазона до пика
    % Создаем диапазон от peak_start до peak_time
    slope_search_indices = find(time_vector >= peak_start & time_vector <= peak_time);
    
    if length(slope_search_indices) < 2
        warning('Insufficient data points in slope search range (peak_start to peak)');
        return;
    end
    
    slope_search_data = channel_data(slope_search_indices);
    slope_search_time = time_vector(slope_search_indices);
    
    % Поиск точки 1 (slope_percent% выше baseline) - ближайшая к target_value1
    [~, idx1] = min(abs(slope_search_data - target_value1));
    time1 = slope_search_time(idx1);
    value1 = slope_search_data(idx1);
    
    % Поиск точки 2 (slope_percent% ниже пика) - ближайшая к target_value2
    [~, idx2] = min(abs(slope_search_data - target_value2));
    time2 = slope_search_time(idx2);
    value2 = slope_search_data(idx2);
    
    % 4. Линейная регрессия между найденными точками
    if time1 == time2
        warning('Slope calculation points are too close');
        return;
    end
    
    % Расчет slope
    dx = time2 - time1;
    dy = value2 - value1;
    slope_value = dy / dx;
    
    % Угол в градусах
    slope_angle = atan(slope_value) * 180 / pi;
    
    % Сохранение точек регрессии
    regression_points.time1 = time1;
    regression_points.value1 = value1;
    regression_points.time2 = time2;
    regression_points.value2 = value2;
    
end 