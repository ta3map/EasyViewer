function [onset_time, onset_value, onset_method] = calculateOnset(signal_data, time_data, baseline_value, baseline_std, peak_start, peak_end, method, threshold)
    % CALCULATEONSET - вычисление онсета сигнала различными методами
    % Принимает baseline_value и baseline_std как входные параметры
    %
    % Входные параметры:
    %   signal_data - вектор данных сигнала
    %   time_data - вектор времени
    %   baseline_value - значение базовой линии (рассчитывается снаружи)
    %   baseline_std - стандартное отклонение baseline (рассчитывается снаружи)
    %   peak_start, peak_end - границы диапазона поиска пика (и онсета)
    %   method - метод расчета ('threshold_crossing', 'derivative', 'second_derivative', 'inverted_peak')
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
    
    % Проверка baseline параметров
    if isnan(baseline_value) || isnan(baseline_std)
        onset_time = NaN;
        onset_value = NaN;
        onset_method = 'invalid_baseline';
        return;
    end
    
    % Находим индексы для peak диапазона
    peak_idx = time_data >= peak_start & time_data <= peak_end;
    
    if sum(peak_idx) < 2
        onset_time = NaN;
        onset_value = NaN;
        onset_method = 'insufficient_data';
        return;
    end
    
    % Данные в диапазоне поиска пика
    peak_data = signal_data(peak_idx);
    peak_time = time_data(peak_idx);
    
    % Выбираем метод расчета
    switch lower(method)
        case 'threshold_crossing'
            [onset_time, onset_value] = thresholdCrossingMethod(peak_data, peak_time, baseline_value, baseline_std, threshold);
            onset_method = 'threshold_crossing';
            
        case 'derivative'
            [onset_time, onset_value] = derivativeMethod(peak_data, peak_time, baseline_value, baseline_std, threshold);
            onset_method = 'derivative';
            
        case 'second_derivative'
            [onset_time, onset_value] = secondDerivativeMethod(peak_data, peak_time, baseline_value, baseline_std, threshold);
            onset_method = 'second_derivative';
            
        case 'inverted_peak'
            [onset_time, onset_value] = invertedPeakMethod(peak_data, peak_time, baseline_value, baseline_std, threshold);
            onset_method = 'inverted_peak';
            
        otherwise
            % По умолчанию используем threshold_crossing
            [onset_time, onset_value] = thresholdCrossingMethod(peak_data, peak_time, baseline_value, baseline_std, threshold);
            onset_method = 'threshold_crossing';
    end
end

function [onset_time, onset_value] = thresholdCrossingMethod(peak_data, peak_time, baseline_value, baseline_std, threshold)
    % Метод пересечения порога: ищем точку, где сигнал превышает baseline + N*std
    
    % Вычисляем порог
    threshold_value = baseline_value + threshold * baseline_std;
    
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

function [onset_time, onset_value] = derivativeMethod(peak_data, peak_time, baseline_value, baseline_std, threshold)
    % Анализ производной сигнала:
    % 1. Вычисление первой производной (разности соседних точек)
    % 2. Поиск точки, где производная превышает пороговое значение
    % 3. Использование скользящего среднего производной для сглаживания шума
    
    % Вычисляем первую производную
    derivative = diff(peak_data) ./ diff(peak_time);
    derivative_time = peak_time(1:end-1) + diff(peak_time)/2;
    
    % Применяем скользящее среднее для сглаживания шума
    % Размер окна для сглаживания (можно настроить)
    window_size = min(5, length(derivative));
    if window_size > 1
        % Используем скользящее среднее с окном
        smoothed_derivative = movmean(derivative, window_size);
    else
        smoothed_derivative = derivative;
    end
    
    % Вычисляем порог для производной на основе baseline статистики
    % Используем стандартное отклонение baseline для нормализации
    baseline_derivative_std = std(smoothed_derivative(1:min(10, length(smoothed_derivative))));
    derivative_threshold = threshold * baseline_derivative_std;
    
    % Ищем первое превышение порога производной
    crossing_idx = find(smoothed_derivative > derivative_threshold, 1, 'first');
    
    if isempty(crossing_idx)
        onset_time = NaN;
        onset_value = NaN;
        return;
    end
    
    onset_time = derivative_time(crossing_idx);
    onset_value = peak_data(crossing_idx + 1); % +1 так как derivative короче на 1
end

function [onset_time, onset_value] = secondDerivativeMethod(peak_data, peak_time, baseline_value, baseline_std, threshold)
    % Анализ второй производной:
    % 1. Вычисление второй производной (изменение наклона)
    % 2. Поиск точки перегиба как экстремума второй производной
    % 3. Более устойчиво к шуму, чем первая производная
    
    fprintf('DEBUG: peak_data size: %s\n', mat2str(size(peak_data)));
    fprintf('DEBUG: peak_time size: %s\n', mat2str(size(peak_time)));
    
    % Вычисляем первую производную
    first_derivative = diff(peak_data) ./ diff(peak_time);
    first_derivative_time = peak_time(1:end-1);
    
    fprintf('DEBUG: first_derivative size: %s\n', mat2str(size(first_derivative)));
    fprintf('DEBUG: first_derivative_time size: %s\n', mat2str(size(first_derivative_time)));
    
    % Вычисляем вторую производную
    diff_first_derivative = diff(first_derivative);
    diff_first_derivative_time = diff(first_derivative_time);
    
    fprintf('DEBUG: diff_first_derivative size: %s\n', mat2str(size(diff_first_derivative)));
    fprintf('DEBUG: diff_first_derivative_time size: %s\n', mat2str(size(diff_first_derivative_time)));
    
    % Транспонируем diff_first_derivative_time чтобы размеры совпали
    diff_first_derivative_time = diff_first_derivative_time';
    
    fprintf('DEBUG: After transpose - diff_first_derivative_time size: %s\n', mat2str(size(diff_first_derivative_time)));
    
    second_derivative = diff_first_derivative ./ diff_first_derivative_time;
    second_derivative_time = first_derivative_time(1:end-1);
    
    % Применяем сглаживание ко второй производной для уменьшения шума
    window_size = min(3, length(second_derivative));
    if window_size > 1
        smoothed_second_derivative = movmean(second_derivative, window_size);
    else
        smoothed_second_derivative = second_derivative;
    end
    
    % Ищем экстремум второй производной (точка перегиба)
    % Используем абсолютное значение для поиска максимального изменения
    abs_second_derivative = abs(smoothed_second_derivative);
    
    % Находим локальный максимум второй производной
    % Ищем точку, где вторая производная превышает порог
    baseline_second_derivative_std = std(abs_second_derivative(1:min(10, length(abs_second_derivative))));
    second_derivative_threshold = threshold * baseline_second_derivative_std;
    
    % Ищем первое превышение порога второй производной
    crossing_idx = find(abs_second_derivative > second_derivative_threshold, 1, 'first');
    
    if isempty(crossing_idx)
        onset_time = NaN;
        onset_value = NaN;
        return;
    end
    
    onset_time = second_derivative_time(crossing_idx);
    onset_value = peak_data(crossing_idx + 2); % +2 так как second_derivative короче на 2
end 

function [onset_time, onset_value] = invertedPeakMethod(peak_data, peak_time, baseline_value, baseline_std, threshold)
    % Метод перевернутого пика для поиска точки перегиба:
    % 1. Переворачиваем сигнал по времени и амплитуде
    % 2. Ищем пик в перевернутом сигнале (это будет точка перегиба в исходном)
    % 3. Используем функцию findpeaks для надежного поиска пиков
    
    % Переворачиваем сигнал по времени и амплитуде
    inverted_data = -peak_data(end:-1:1);
    inverted_time = peak_time(end:-1:1);
    
    % Вычисляем порог для поиска пика в перевернутом сигнале
    % Используем baseline статистику для определения минимальной высоты пика
    min_peak_height = threshold * baseline_std;
    
    % Ищем пики в перевернутом сигнале
    try
        [peaks, peak_times, ~, prominences] = findpeaks(inverted_data, inverted_time, ...
            'MinPeakHeight', min_peak_height, ...
            'MinPeakProminence', min_peak_height * 0.5);
        
        if isempty(peaks)
            onset_time = NaN;
            onset_value = NaN;
            return;
        end
        
        % Выбираем последний найденный пик (самый поздний по времени в перевернутом сигнале)
        % Это будет точка перегиба в исходном сигнале (онсет)
        onset_time = peak_times(end);
        onset_value = -inverted_data(find(inverted_time == onset_time, 1)); % Возвращаем исходное значение
        
    catch ME
        % Fallback если findpeaks не сработал
        warning('findpeaks failed, using simple maximum search: %s', ME.message);
        
        [~, max_idx] = max(inverted_data);
        onset_time = inverted_time(max_idx);
        onset_value = -inverted_data(max_idx);
    end
end 