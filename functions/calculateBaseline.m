function [baseline_value, baseline_indices] = calculateBaseline(channel_data, time_vector, baseline_start, baseline_end)
    % calculateBaseline - расчет базовой линии сигнала
    %
    % Входные параметры:
    %   channel_data   - вектор данных канала
    %   time_vector    - соответствующий вектор времени
    %   baseline_start - начало диапазона baseline (в секундах)
    %   baseline_end   - конец диапазона baseline (в секундах)
    %
    % Выходные параметры:
    %   baseline_value   - среднее значение baseline
    %   baseline_indices - индексы точек, использованных для расчета baseline
    
    % Инициализация выходных значений
    baseline_value = NaN;
    baseline_indices = [];
    
    % Проверка входных данных
    if length(channel_data) ~= length(time_vector)
        error('Channel data and time vector must have the same length');
    end
    
    % Поиск индексов в диапазоне baseline
    baseline_indices = find(time_vector >= baseline_start & time_vector <= baseline_end);
    
    if isempty(baseline_indices)
        warning('No data points found in baseline range');
        return;
    end
    
    % Расчет baseline как среднее значение
    baseline_value = mean(channel_data(baseline_indices));
    
end 