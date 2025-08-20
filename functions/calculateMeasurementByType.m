function [measurement_value, measurement_metadata] = calculateMeasurementByType(channel_data, time_vector, range_start, range_end, function_type, varargin)
    % calculateMeasurementByType - вычисление различных типов измерений в заданном диапазоне
    %
    % Входные параметры:
    %   channel_data   - вектор данных канала
    %   time_vector    - соответствующий вектор времени (относительное время от 0)
    %   range_start    - начало диапазона измерения (относительное время от 0)
    %   range_end      - конец диапазона измерения (относительное время от 0)
    %   function_type  - тип функции измерения ('Mean', 'Max', 'Min', 'Std', 'Peak', 'RMS', 'Slope')
    %   varargin       - дополнительные параметры:
    %                    для 'Slope': baseline_data структура с полями:
    %                    .baseline_start - начало диапазона baseline
    %                    .baseline_end   - конец диапазона baseline
    %                    .peak_start     - начало диапазона поиска пика
    %                    .peak_end       - конец диапазона поиска пика
    %                    .slope_percent  - процент для расчета slope точек
    %                    .peak_polarity  - полярность пика ('positive' или 'negative')
    %
    % Выходные параметры:
    %   measurement_value    - значение измерения
    %   measurement_metadata - структура с метаданными измерения
    

    if range_start > range_end
        % swap range_start and range_end
        tmp = range_start;
        range_start = range_end;
        range_end = tmp;
    end
    
    % Инициализация выходных значений
    measurement_value = NaN;
    measurement_metadata = struct('type', function_type, 'range_start', range_start, 'range_end', range_end);
    
    % Проверка входных данных
    if length(channel_data) ~= length(time_vector)
        warning('Channel data and time vector must have the same length');
        return;
    end
    
    % Поиск данных в заданном диапазоне (координаты уже относительные)
    range_indices = find(time_vector >= range_start & time_vector <= range_end);
    if isempty(range_indices)
        warning('No data points found in measurement range [%.3f, %.3f]', range_start, range_end);
        return;
    end
    
    % Проверяем что диапазон не пустой
    if range_start >= range_end
        warning('Invalid measurement range: start (%.3f) >= end (%.3f)', range_start, range_end);
        return;
    end
    
    % Получаем данные в диапазоне
    range_data = channel_data(range_indices);
    
    % Вычисляем значение в зависимости от типа функции
    switch function_type
        case 'Mean'
            measurement_value = mean(range_data);
            
            % Добавляем объект для визуализации - горизонтальная пунктирная линия
            measurement_metadata.visualization = struct();
            measurement_metadata.visualization.mean_line = struct();
            measurement_metadata.visualization.mean_line.type = 'line';
            % Координаты уже относительные (от 0)
            measurement_metadata.visualization.mean_line.coordinates = struct('x1', range_start, 'y1', measurement_value, ...
                                                                         'x2', range_end, 'y2', measurement_value);
            measurement_metadata.visualization.mean_line.style = struct('color', 'b', 'linewidth', 1, 'linestyle', ':');
            
        case 'Max'
            measurement_value = max(range_data);
            
        case 'Min'
            measurement_value = min(range_data);
            
        case 'Std'
            measurement_value = std(range_data);
            
        case 'Peak'
            % Находим пик (максимальное абсолютное значение)
            [~, max_idx] = max(abs(range_data));
            measurement_value = range_data(max_idx);
            
        case 'RMS'
            % Root Mean Square
            measurement_value = sqrt(mean(range_data.^2));
            
        case 'Slope'
            % Расчет slope с использованием calculateSlope
            if isempty(varargin) || ~isstruct(varargin{1})
                warning('Slope calculation requires baseline_data structure as first varargin argument');
                return;
            end
            
            baseline_data = varargin{1};
            
            % Расчет baseline на исходных данных
            [baseline_value, ~] = calculateBaseline(channel_data, time_vector, ...
                baseline_data.baseline_start, baseline_data.baseline_end);
            
            % Для отрицательного пика инвертируем сигнал и baseline
            if strcmp(baseline_data.peak_polarity, 'negative')
                channel_data_for_slope = -channel_data;
                baseline_value_for_slope = -baseline_value;
            else
                channel_data_for_slope = channel_data;
                baseline_value_for_slope = baseline_value;
            end
            
            % Расчет slope с использованием calculateSlope (теперь возвращает и онсет)
            [slope_value, slope_angle, regression_points, peak_time, peak_value, onset_time, onset_value] = ...
                calculateSlope(channel_data_for_slope, time_vector, baseline_value_for_slope, ...
                             range_start, range_end, baseline_data.slope_percent);
            
            % Инвертируем результаты обратно если был отрицательный пик
            if strcmp(baseline_data.peak_polarity, 'negative')
                % Инвертируем значения, но не времена
                peak_value = -peak_value;
                onset_value = -onset_value;
                regression_points.value1 = -regression_points.value1;
                regression_points.value2 = -regression_points.value2;
                % slope_value и slope_angle не меняем, так как они уже правильные
                % baseline_value оставляем исходным, так как он уже правильный
            end
            
            % Возвращаем slope_value как основное значение измерения
            measurement_value = slope_value;
            
            % Добавляем все метаданные slope в measurement_metadata
            measurement_metadata.slope_value = slope_value;
            measurement_metadata.slope_angle = slope_angle;
            measurement_metadata.regression_points = regression_points;
            measurement_metadata.baseline_value = baseline_value; % Исходное значение baseline
            measurement_metadata.peak_time = peak_time;
            measurement_metadata.peak_value = peak_value;
            measurement_metadata.onset_time = onset_time;
            measurement_metadata.onset_value = onset_value;
            measurement_metadata.onset_method = 'calculated_by_slope';
            measurement_metadata.baseline_data = baseline_data;
            
            % Добавляем объекты для визуализации
            measurement_metadata.visualization = struct();
            
            % Точка пика
            measurement_metadata.visualization.peak_marker = struct();
            measurement_metadata.visualization.peak_marker.type = 'point';
            measurement_metadata.visualization.peak_marker.coordinates = struct('x', peak_time, 'y', peak_value);
            measurement_metadata.visualization.peak_marker.style = struct('color', 'r', 'marker', 'o', 'markersize', 10, 'markerfacecolor', 'r');
            
            % Линия slope (регрессии)
            measurement_metadata.visualization.slope_line = struct();
            measurement_metadata.visualization.slope_line.type = 'line';
            measurement_metadata.visualization.slope_line.coordinates = struct('x1', regression_points.time1, 'y1', regression_points.value1, ...
                                                                       'x2', regression_points.time2, 'y2', regression_points.value2);
            measurement_metadata.visualization.slope_line.style = struct('color', 'k', 'linewidth', 4, 'linestyle', '-');
            
            % Точки регрессии
            measurement_metadata.visualization.regression_markers = struct();
            measurement_metadata.visualization.regression_markers.type = 'points';
            measurement_metadata.visualization.regression_markers.coordinates = struct('x', [regression_points.time1, regression_points.time2], ...
                                                                               'y', [regression_points.value1, regression_points.value2]);
            measurement_metadata.visualization.regression_markers.style = struct('color', 'k', 'marker', 'o', 'markersize', 6, 'markerfacecolor', 'k');
            
            % Подпись со значением пика около пика
            measurement_metadata.visualization.peak_label = struct();
            measurement_metadata.visualization.peak_label.type = 'text';
            measurement_metadata.visualization.peak_label.coordinates = struct('x', peak_time, 'y', peak_value);
            measurement_metadata.visualization.peak_label.text = sprintf('%.3f', peak_value);
            measurement_metadata.visualization.peak_label.style = struct('color', 'k', 'fontweight', 'bold', 'fontsize', 10, 'horizontalalignment', 'center');
            
        otherwise
            warning('Unknown function type: %s. Using Mean instead.', function_type);
            measurement_value = mean(range_data);
            function_type = 'Mean';
    end
    
    % Дополнительные метаданные
    measurement_metadata.std_value = std(range_data);
    measurement_metadata.min_value = min(range_data);
    measurement_metadata.max_value = max(range_data);
    measurement_metadata.data_points = length(range_data);
    measurement_metadata.function_type = function_type;
    
end 