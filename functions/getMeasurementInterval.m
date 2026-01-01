function interval = getMeasurementInterval(baseline_start, baseline_end, peak_start, peak_end, chosen_time_interval, time_back, time_forward, time)
    % getMeasurementInterval - определение минимального временного интервала для расчетов
    % Точная копия из signalAnalysisGUI
    %
    % Входные параметры:
    %   baseline_start      - начало диапазона baseline (абсолютное время)
    %   baseline_end        - конец диапазона baseline (абсолютное время)
    %   peak_start          - начало диапазона поиска пика (абсолютное время)
    %   peak_end            - конец диапазона поиска пика (абсолютное время)
    %   chosen_time_interval - основной временной интервал [start, end]
    %   time_back           - время назад от начала интервала
    %   time_forward        - время вперед от начала интервала
    %   time                - вектор времени данных
    %
    % Выходные параметры:
    %   interval           - [calc_start, calc_end] минимальный интервал для расчетов
    
    measurement_points = [
        baseline_start, ...
        baseline_end, ...
        peak_start, ...
        peak_end, ...
        chosen_time_interval(1) - time_back, ...
        chosen_time_interval(1) + time_forward];
    
    measurement_points = measurement_points(isfinite(measurement_points));
    
    if isempty(measurement_points)
        interval = [chosen_time_interval(1), chosen_time_interval(2)];
        return;
    end
    
    calc_start = min(measurement_points);
    calc_end = max(measurement_points);
    calc_start = max(calc_start, time(1));
    calc_end = min(calc_end, time(end));
    
    if calc_start == calc_end
        calc_end = calc_start + eps(calc_start + 1);
    end
    
    interval = [calc_start, calc_end];
end

