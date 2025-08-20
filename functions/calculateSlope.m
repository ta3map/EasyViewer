function [slope_value, slope_angle, regression_points, peak_time, peak_value, onset_time, onset_value] = ...
    calculateSlope(channel_data, time_vector, baseline_value, ...
                  peak_start, peak_end, slope_percent)
    % calculateSlope - расчет наклона (slope) сигнала с использованием baseline
    % Функция всегда работает с положительными пиками
    %
    % Входные параметры:
    %   channel_data   - вектор данных канала
    %   time_vector    - соответствующий вектор времени
    %   baseline_value - значение базовой линии (рассчитывается снаружи)
    %   peak_start     - начало диапазона поиска пика (в секундах)
    %   peak_end       - конец диапазона поиска пика (в секундах)
    %   slope_percent  - процент для расчета slope точек (например, 20)
    %
    % Выходные параметры:
    %   slope_value      - значение наклона (dy/dx)
    %   slope_angle      - угол наклона в градусах
    %   regression_points - структура с точками для линейной регрессии
    %   peak_time        - время пика
    %   peak_value       - значение амплитуды пика
    %   onset_time       - время onset (5% от baseline до пика)
    %   onset_value      - значение сигнала в точке onset
    
    % Инициализация выходных значений
    slope_value = NaN;
    slope_angle = NaN;
    regression_points = struct('time1', NaN, 'value1', NaN, 'time2', NaN, 'value2', NaN);
    peak_time = NaN;
    peak_value = NaN;
    onset_time = NaN;
    onset_value = NaN;
    
    % 1. Поиск пика в заданном диапазоне
    peak_indices = find(time_vector >= peak_start & time_vector <= peak_end);
    peak_data_segment = channel_data(peak_indices);
    
    % Всегда ищем максимум
    [peak_value, peak_idx_local] = max(peak_data_segment);
    peak_idx_global = peak_indices(peak_idx_local);
    peak_time = time_vector(peak_idx_global);
    
    % 2. Расчет значений для точек
    peak_distance = abs(peak_value - baseline_value); % Всегда берем абсолютную разницу
    
    % Значения амплитуд для точек (всегда для положительного пика)
    value_50percent = baseline_value + peak_distance * 0.5;
    value_upper = baseline_value + peak_distance * (1 - slope_percent / 100); % Ближе к пику
    value_lower = baseline_value + peak_distance * (slope_percent / 100);     % Ближе к baseline
    value_onset = baseline_value + peak_distance * 0.05;                      % Всегда чуть выше baseline
    
    % 3. Поиск всех точек в диапазоне от пика до начала (в обратном порядке)
    search_indices = find(time_vector >= peak_start & time_vector <= peak_time);
    search_indices = fliplr(search_indices); % Переворачиваем индексы для поиска от пика
    search_data = channel_data(search_indices);
    search_time = time_vector(search_indices);
    
    % Функция для поиска первой точки, пересекающей заданное значение
    function idx = findFirstCrossing(data, target_value)
        idx = find(data <= target_value, 1, 'first');
        if isempty(idx)
            idx = 1;
        end
    end
    
    % Сначала ищем точку 50%
    idx_50 = findFirstCrossing(search_data, value_50percent);
    
    % Ищем верхнюю точку от пика к началу
    idx_upper = findFirstCrossing(search_data, value_upper);
    if isempty(idx_upper)
        idx_upper = 1;
    end
    
    % Ищем нижнюю точку от 50% к началу
    idx_lower = findFirstCrossing(search_data(idx_50:end), value_lower);
    if ~isempty(idx_lower)
        idx_lower = idx_lower + idx_50 - 1;
        
        % Поиск onset только после нижней точки
        idx_onset = findFirstCrossing(search_data(idx_lower:end), value_onset);
        if ~isempty(idx_onset)
            idx_onset = idx_onset + idx_lower - 1;
            onset_time = search_time(idx_onset);
            onset_value = search_data(idx_onset);
        end
    end
    
    % Сохранение точек и расчет slope
    time1 = search_time(idx_lower);
    value1 = search_data(idx_lower);
    time2 = search_time(idx_upper);
    value2 = search_data(idx_upper);
    
    % Расчет slope
    dx = time2 - time1;
    dy = value2 - value1;
    slope_value = dy / dx;
    slope_angle = atan(slope_value) * 180 / pi;
    
    % Сохранение точек регрессии
    regression_points.time1 = time1;
    regression_points.value1 = value1;
    regression_points.time2 = time2;
    regression_points.value2 = value2;
end 