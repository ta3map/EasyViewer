function [y1, y2, slope_value, slope_angle] = calculateSlope(channel_data, time_vector, time1, time2)
    % calculateSlope - вычисляет наклон (slope) между двумя точками сигнала
    %
    % Входные параметры:
    %   channel_data - вектор данных канала
    %   time_vector  - соответствующий вектор времени
    %   time1        - время первой точки (в секундах)
    %   time2        - время второй точки (в секундах)
    %
    % Выходные параметры:
    %   y1          - значение амплитуды в первой точке
    %   y2          - значение амплитуды во второй точке
    %   slope_value - значение наклона (dy/dx)
    %   slope_angle - угол наклона в градусах
    
    % Проверка входных данных
    if length(channel_data) ~= length(time_vector)
        error('Channel data and time vector must have the same length');
    end
    
    if time1 == time2
        % Избегаем деления на ноль
        y1 = NaN;
        y2 = NaN;
        slope_value = NaN;
        slope_angle = NaN;
        return;
    end
    
    % Находим ближайшие индексы для заданных времен
    idx1 = ClosestIndex(time1, time_vector);
    idx2 = ClosestIndex(time2, time_vector);
    
    % Проверяем, что индексы в допустимых пределах
    if isnan(idx1) || isnan(idx2) || idx1 < 1 || idx2 < 1 || ...
       idx1 > length(channel_data) || idx2 > length(channel_data)
        y1 = NaN;
        y2 = NaN;
        slope_value = NaN;
        slope_angle = NaN;
        return;
    end
    
    % Получаем значения амплитуды в найденных точках
    y1 = channel_data(idx1);
    y2 = channel_data(idx2);
    
    % Получаем точные времена из временного вектора
    actual_time1 = time_vector(idx1);
    actual_time2 = time_vector(idx2);
    
    % Вычисляем slope
    dx = actual_time2 - actual_time1;
    dy = y2 - y1;
    
    if dx == 0
        % Избегаем деления на ноль
        slope_value = NaN;
        slope_angle = NaN;
    else
        slope_value = dy / dx;
        
        % Вычисляем угол в градусах
        slope_angle = atan(slope_value) * 180 / pi;
    end
    
    % Дополнительная проверка на NaN значения
    if isnan(y1) || isnan(y2)
        slope_value = NaN;
        slope_angle = NaN;
    end
    
end 