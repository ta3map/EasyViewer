function [onset_time, onset_value, onset_method] = calculateOnset(signal_data, time_data, baseline_start, baseline_end, peak_start, peak_end, method, threshold)
    % CALCULATEONSET - вычисление онсета сигнала различными методами
    %
    % Входные параметры:
    %   signal_data - вектор данных сигнала
    %   time_data - вектор времени
    %   baseline_start, baseline_end - границы baseline диапазона
    %   peak_start, peak_end - границы диапазона поиска пика (и онсета)
    %   method - метод расчета ('threshold_crossing', 'derivative', 'inflection', etc.)
    %   threshold - пороговое значение (для threshold_crossing - в единицах std)
    %
    % Выходные параметры:
    %   onset_time - время онсета
    %   onset_value - значение сигнала в точке онсета
    %   onset_method - использованный метод (для информации)
    
    % Проверка входных данных
    if isempty(signal_data) || isempty(time_data) || length(signal_data) ~= length(time_data)
        onset_time = NaN;
        onset_value = NaN;
        onset_method = 'invalid_data';
        return;
    end
    
    % Находим индексы для baseline и peak диапазонов
    baseline_idx = time_data >= baseline_start & time_data <= baseline_end;
    peak_idx = time_data >= peak_start & time_data <= peak_end;
    
    if sum(baseline_idx) < 2 || sum(peak_idx) < 2
        onset_time = NaN;
        onset_value = NaN;
        onset_method = 'insufficient_data';
        return;
    end
    
    % Вычисляем baseline статистики
    baseline_data = signal_data(baseline_idx);
    baseline_mean = mean(baseline_data);
    baseline_std = std(baseline_data);
    
    % Данные в диапазоне поиска пика
    peak_data = signal_data(peak_idx);
    peak_time = time_data(peak_idx);
    
    % Выбираем метод расчета
    switch lower(method)
        case 'threshold_crossing'
            [onset_time, onset_value] = thresholdCrossingMethod(peak_data, peak_time, baseline_mean, baseline_std, threshold);
            onset_method = 'threshold_crossing';
            
        case 'derivative'
            [onset_time, onset_value] = derivativeMethod(peak_data, peak_time, baseline_mean, baseline_std, threshold);
            onset_method = 'derivative';
            
        case 'inflection'
            [onset_time, onset_value] = inflectionMethod(peak_data, peak_time, baseline_mean, baseline_std, threshold);
            onset_method = 'inflection';
            
        case 'statistical'
            [onset_time, onset_value] = statisticalMethod(peak_data, peak_time, baseline_mean, baseline_std, threshold);
            onset_method = 'statistical';
            
        otherwise
            % По умолчанию используем threshold_crossing
            [onset_time, onset_value] = thresholdCrossingMethod(peak_data, peak_time, baseline_mean, baseline_std, threshold);
            onset_method = 'threshold_crossing';
    end
end

function [onset_time, onset_value] = thresholdCrossingMethod(peak_data, peak_time, baseline_mean, baseline_std, threshold)
    % Метод пересечения порога: ищем точку, где сигнал превышает baseline + N*std
    
    % Вычисляем порог
    threshold_value = baseline_mean + threshold * baseline_std;
    
    % Ищем первое пересечение порога
    crossing_idx = find(peak_data > threshold_value, 1, 'first');
    
    if isempty(crossing_idx)
        onset_time = NaN;
        onset_value = NaN;
        return;
    end
    
    onset_time = peak_time(crossing_idx);
    onset_value = peak_data(crossing_idx);
end

function [onset_time, onset_value] = derivativeMethod(peak_data, peak_time, baseline_mean, baseline_std, threshold)
    % Метод производной: ищем точку, где производная превышает порог
    
    % Вычисляем первую производную
    derivative = diff(peak_data) ./ diff(peak_time);
    derivative_time = peak_time(1:end-1) + diff(peak_time)/2;
    
    % Вычисляем порог для производной (на основе baseline std)
    derivative_threshold = threshold * baseline_std / mean(diff(peak_time));
    
    % Ищем первое превышение порога производной
    crossing_idx = find(derivative > derivative_threshold, 1, 'first');
    
    if isempty(crossing_idx)
        onset_time = NaN;
        onset_value = NaN;
        return;
    end
    
    onset_time = derivative_time(crossing_idx);
    onset_value = peak_data(crossing_idx + 1); % +1 так как derivative короче на 1
end

function [onset_time, onset_value] = inflectionMethod(peak_data, peak_time, baseline_mean, baseline_std, threshold)
    % Метод точки перегиба: ищем экстремум второй производной
    
    % Вычисляем вторую производную
    first_derivative = diff(peak_data) ./ diff(peak_time);
    second_derivative = diff(first_derivative) ./ diff(peak_time(1:end-1));
    second_derivative_time = peak_time(2:end-1) + diff(peak_time(1:end-1))/2;
    
    % Ищем максимум второй производной (точка перегиба)
    [~, max_idx] = max(second_derivative);
    
    if isempty(max_idx)
        onset_time = NaN;
        onset_value = NaN;
        return;
    end
    
    onset_time = second_derivative_time(max_idx);
    onset_value = peak_data(max_idx + 2); % +2 так как second_derivative короче на 2
end

function [onset_time, onset_value] = statisticalMethod(peak_data, peak_time, baseline_mean, baseline_std, threshold)
    % Статистический метод: ищем точку, где z-score превышает порог
    
    % Вычисляем z-score относительно baseline
    z_scores = (peak_data - baseline_mean) / baseline_std;
    
    % Ищем первое превышение порога z-score
    crossing_idx = find(z_scores > threshold, 1, 'first');
    
    if isempty(crossing_idx)
        onset_time = NaN;
        onset_value = NaN;
        return;
    end
    
    onset_time = peak_time(crossing_idx);
    onset_value = peak_data(crossing_idx);
end 