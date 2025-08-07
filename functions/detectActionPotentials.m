function [ap_results, ap_metadata] = detectActionPotentials(signal_data, time_data, varargin)
    % DETECTACTIONPOTENTIALS - Автоматическое обнаружение и характеристика потенциалов действия
    %
    % Синтаксис:
    %   [ap_results, ap_metadata] = detectActionPotentials(signal_data, time_data)
    %   [ap_results, ap_metadata] = detectActionPotentials(signal_data, time_data, 'param', value, ...)
    %
    % Входные параметры:
    %   signal_data - вектор данных сигнала
    %   time_data   - вектор времени (должен быть той же длины что и signal_data)
    %
    % Дополнительные параметры (name-value pairs):
    %   'threshold_method' - метод определения порога срабатывания:
    %                        'derivative' (по умолчанию), 'amplitude', 'manual'
    %   'threshold_value'  - значение порога (для manual метода)
    %   'derivative_threshold' - порог производной в мВ/мс (по умолчанию 10)
    %   'amplitude_threshold'  - порог амплитуды в std (по умолчанию 3)
    %   'min_interval'     - минимальный интервал между AP в мс (по умолчанию 1)
    %   'refractory_period' - рефрактерный период в мс (по умолчанию 2)
    %   'baseline_window'  - окно для расчета baseline в мс (по умолчанию 10)
    %   'peak_search_window' - окно поиска пика в мс (по умолчанию 5)
    %   'slope_percent'    - процент для расчета наклона (по умолчанию 20)
    %   'onset_method'     - метод определения онсета (по умолчанию 'derivative')
    %   'onset_threshold'  - порог для онсета (по умолчанию 3)
    %
    % Выходные параметры:
    %   ap_results - структура с результатами для каждого найденного AP:
    %     .threshold_time    - время порога срабатывания
    %     .threshold_value   - значение порога срабатывания
    %     .peak_time         - время пика
    %     .peak_value        - значение пика
    %     .amplitude_abs     - абсолютная амплитуда
    %     .amplitude_rel     - амплитуда относительно порога
    %     .half_width        - полуширина
    %     .rise_time         - время нарастания
    %     .decay_time        - время спада
    %     .max_dv_dt         - максимальная скорость нарастания
    %     .area              - площадь под кривой
    %     .onset_time        - время онсета
    %     .onset_value       - значение онсета
    %     .slope_value       - наклон восходящей фазы
    %     .slope_angle       - угол наклона в градусах
    %     .baseline_value    - значение baseline
    %     .refractory_period - рефрактерный период до следующего AP
    %
    %   ap_metadata - метаданные анализа:
    %     .total_aps         - общее количество найденных AP
    %     .firing_rate       - частота срабатывания (AP/с)
    %     .mean_amplitude    - средняя амплитуда
    %     .std_amplitude     - стандартное отклонение амплитуды
    %     .mean_half_width   - средняя полуширина
    %     .std_half_width    - стандартное отклонение полуширины
    %     .mean_rise_time    - среднее время нарастания
    %     .std_rise_time     - стандартное отклонение времени нарастания
    %     .parameters        - использованные параметры
    %
    % Пример использования:
    %   [results, metadata] = detectActionPotentials(lfp_data, time_data, ...
    %       'threshold_method', 'derivative', ...
    %       'derivative_threshold', 15, ...
    %       'min_interval', 2);
    
    % Парсинг входных параметров
    p = inputParser;
    addRequired(p, 'signal_data', @isnumeric);
    addRequired(p, 'time_data', @isnumeric);
    addParameter(p, 'threshold_method', 'derivative', @ischar);
    addParameter(p, 'threshold_value', [], @isnumeric);
    addParameter(p, 'derivative_threshold', 10, @isnumeric);
    addParameter(p, 'amplitude_threshold', 3, @isnumeric);
    addParameter(p, 'min_interval', 1, @isnumeric);
    addParameter(p, 'refractory_period', 2, @isnumeric);
    addParameter(p, 'baseline_window', 10, @isnumeric);
    addParameter(p, 'peak_search_window', 5, @isnumeric);
    addParameter(p, 'slope_percent', 20, @isnumeric);
    addParameter(p, 'onset_method', 'derivative', @ischar);
    addParameter(p, 'onset_threshold', 3, @isnumeric);
    
    parse(p, signal_data, time_data, varargin{:});
    
    % Извлекаем параметры
    threshold_method = p.Results.threshold_method;
    threshold_value = p.Results.threshold_value;
    derivative_threshold = p.Results.derivative_threshold;
    amplitude_threshold = p.Results.amplitude_threshold;
    min_interval = p.Results.min_interval;
    refractory_period = p.Results.refractory_period;
    baseline_window = p.Results.baseline_window;
    peak_search_window = p.Results.peak_search_window;
    slope_percent = p.Results.slope_percent;
    onset_method = p.Results.onset_method;
    onset_threshold = p.Results.onset_threshold;
    
    % Проверка входных данных
    if length(signal_data) ~= length(time_data)
        error('signal_data и time_data должны иметь одинаковую длину');
    end
    
    if isempty(signal_data)
        ap_results = [];
        ap_metadata = struct('total_aps', 0, 'firing_rate', 0);
        return;
    end
    
    % Убеждаемся что данные в правильном формате
    signal_data = signal_data(:);
    time_data = time_data(:);
    
    % Вычисляем частоту дискретизации
    dt = mean(diff(time_data));
    if dt <= 0
        error('Время должно быть монотонно возрастающим');
    end
    fs = 1/dt;
    
    % Конвертируем временные окна из мс в точки
    baseline_points = round(baseline_window / 1000 * fs);
    peak_search_points = round(peak_search_window / 1000 * fs);
    min_interval_points = round(min_interval / 1000 * fs);
    refractory_points = round(refractory_period / 1000 * fs);
    
    % Находим пороги срабатывания
    threshold_indices = findActionPotentialThresholds(signal_data, time_data, ...
        threshold_method, threshold_value, derivative_threshold, amplitude_threshold, ...
        min_interval_points, refractory_points);
    
    if isempty(threshold_indices)
        ap_results = [];
        ap_metadata = struct('total_aps', 0, 'firing_rate', 0);
        return;
    end
    
    % Анализируем каждый найденный потенциал действия
    ap_results = struct();
    valid_aps = 0;
    
    for i = 1:length(threshold_indices)
        threshold_idx = threshold_indices(i);
        
        % Определяем окно анализа для текущего AP
        [start_idx, end_idx] = getAnalysisWindow(signal_data, threshold_idx, ...
            baseline_points, peak_search_points);
        
        if start_idx < 1 || end_idx > length(signal_data)
            continue; % Пропускаем AP на краях данных
        end
        
        % Извлекаем сегмент данных
        segment_data = signal_data(start_idx:end_idx);
        segment_time = time_data(start_idx:end_idx);
        
        % Нормализуем время относительно порога
        threshold_time = time_data(threshold_idx);
        segment_time_rel = segment_time - threshold_time;
        
        % Анализируем AP
        try
            ap_result = analyzeSingleActionPotential(segment_data, segment_time_rel, ...
                threshold_idx - start_idx + 1, slope_percent, onset_method, onset_threshold);
            
            % Добавляем абсолютные времена
            ap_result.threshold_time = threshold_time;
            ap_result.peak_time = threshold_time + ap_result.peak_time_rel;
            ap_result.onset_time = threshold_time + ap_result.onset_time_rel;
            
            % Вычисляем рефрактерный период
            if i < length(threshold_indices)
                next_threshold_time = time_data(threshold_indices(i+1));
                ap_result.refractory_period = (next_threshold_time - threshold_time) * 1000; % в мс
            else
                ap_result.refractory_period = NaN;
            end
            
            valid_aps = valid_aps + 1;
            ap_results(valid_aps) = ap_result;
            
        catch ME
            fprintf('Ошибка при анализе AP #%d: %s\n', i, ME.message);
            continue;
        end
    end
    
    % Вычисляем метаданные
    if valid_aps > 0
        ap_metadata = calculateAPMetadata(ap_results, time_data);
        ap_metadata.parameters = p.Results;
    else
        ap_metadata = struct('total_aps', 0, 'firing_rate', 0);
        ap_metadata.parameters = p.Results;
    end
    
    fprintf('Найдено и проанализировано %d потенциалов действия\n', valid_aps);
end

function threshold_indices = findActionPotentialThresholds(signal_data, time_data, ...
    threshold_method, threshold_value, derivative_threshold, amplitude_threshold, ...
    min_interval_points, refractory_points)
    % Находит индексы порогов срабатывания AP
    
    threshold_indices = [];
    
    switch threshold_method
        case 'derivative'
            % Метод на основе производной
            dt = mean(diff(time_data));
            derivative = diff(signal_data) / dt;
            
            % Находим точки где производная превышает порог
            threshold_crossings = find(derivative > derivative_threshold);
            
            % Фильтруем по минимальному интервалу
            if ~isempty(threshold_crossings)
                filtered_crossings = [threshold_crossings(1)];
                for i = 2:length(threshold_crossings)
                    if threshold_crossings(i) - filtered_crossings(end) >= min_interval_points
                        filtered_crossings = [filtered_crossings, threshold_crossings(i)];
                    end
                end
                threshold_indices = filtered_crossings;
            end
            
        case 'amplitude'
            % Метод на основе амплитуды
            baseline = mean(signal_data);
            std_signal = std(signal_data);
            threshold_level = baseline + amplitude_threshold * std_signal;
            
            % Находим пересечения порога
            above_threshold = signal_data > threshold_level;
            threshold_crossings = find(diff(above_threshold) == 1);
            
            % Фильтруем по минимальному интервалу
            if ~isempty(threshold_crossings)
                filtered_crossings = [threshold_crossings(1)];
                for i = 2:length(threshold_crossings)
                    if threshold_crossings(i) - filtered_crossings(end) >= min_interval_points
                        filtered_crossings = [filtered_crossings, threshold_crossings(i)];
                    end
                end
                threshold_indices = filtered_crossings;
            end
            
        case 'manual'
            % Ручной метод - используем заданное значение
            if isempty(threshold_value)
                error('Для manual метода необходимо указать threshold_value');
            end
            
            above_threshold = signal_data > threshold_value;
            threshold_crossings = find(diff(above_threshold) == 1);
            
            % Фильтруем по минимальному интервалу
            if ~isempty(threshold_crossings)
                filtered_crossings = [threshold_crossings(1)];
                for i = 2:length(threshold_crossings)
                    if threshold_crossings(i) - filtered_crossings(end) >= min_interval_points
                        filtered_crossings = [filtered_crossings, threshold_crossings(i)];
                    end
                end
                threshold_indices = filtered_crossings;
            end
            
        otherwise
            error('Неизвестный метод определения порога: %s', threshold_method);
    end
end

function [start_idx, end_idx] = getAnalysisWindow(signal_data, threshold_idx, ...
    baseline_points, peak_search_points)
    % Определяет окно анализа для AP
    
    % Начало окна - baseline_points точек до порога
    start_idx = max(1, threshold_idx - baseline_points);
    
    % Конец окна - peak_search_points точек после порога
    end_idx = min(length(signal_data), threshold_idx + peak_search_points);
end

function ap_result = analyzeSingleActionPotential(segment_data, segment_time, ...
    threshold_idx, slope_percent, onset_method, onset_threshold)
    % Анализирует отдельный потенциал действия
    
    % Базовые параметры
    ap_result = struct();
    
    % Baseline - среднее значение до порога
    baseline_data = segment_data(1:threshold_idx);
    ap_result.baseline_value = mean(baseline_data);
    
    % Находим пик
    [peak_value, peak_idx] = max(segment_data);
    ap_result.peak_value = peak_value;
    ap_result.peak_time_rel = segment_time(peak_idx);
    
    % Абсолютная амплитуда
    ap_result.amplitude_abs = peak_value - ap_result.baseline_value;
    
    % Амплитуда относительно порога
    threshold_value = segment_data(threshold_idx);
    ap_result.amplitude_rel = peak_value - threshold_value;
    
    % Полуширина
    half_amplitude = ap_result.baseline_value + ap_result.amplitude_abs / 2;
    half_amplitude_indices = find(segment_data >= half_amplitude);
    
    if length(half_amplitude_indices) >= 2
        half_width_start = segment_time(half_amplitude_indices(1));
        half_width_end = segment_time(half_amplitude_indices(end));
        ap_result.half_width = (half_width_end - half_width_start) * 1000; % в мс
    else
        ap_result.half_width = NaN;
    end
    
    % Время нарастания (от порога до пика)
    ap_result.rise_time = (ap_result.peak_time_rel - segment_time(threshold_idx)) * 1000; % в мс
    
    % Время спада (от пика до 50% амплитуды)
    decay_start_idx = peak_idx;
    decay_end_idx = find(segment_data(peak_idx:end) <= half_amplitude, 1);
    
    if ~isempty(decay_end_idx)
        decay_end_idx = peak_idx + decay_end_idx - 1;
        ap_result.decay_time = (segment_time(decay_end_idx) - ap_result.peak_time_rel) * 1000; % в мс
    else
        ap_result.decay_time = NaN;
    end
    
    % Максимальная скорость нарастания
    dt = mean(diff(segment_time));
    derivative = diff(segment_data) / dt;
    ap_result.max_dv_dt = max(derivative);
    
    % Площадь под кривой (от порога до возврата к baseline)
    baseline_return_idx = find(segment_data(peak_idx:end) <= ap_result.baseline_value, 1);
    if ~isempty(baseline_return_idx)
        baseline_return_idx = peak_idx + baseline_return_idx - 1;
        area_data = segment_data(threshold_idx:baseline_return_idx);
        area_time = segment_time(threshold_idx:baseline_return_idx);
        ap_result.area = trapz(area_time, area_data - ap_result.baseline_value);
    else
        ap_result.area = NaN;
    end
    
    % Онсет (используем функцию из calculateOnset.m)
    try
        [onset_time, onset_value, ~] = calculateOnset(segment_data, segment_time, ...
            segment_time(1), segment_time(threshold_idx), ...
            segment_time(threshold_idx), segment_time(end), ...
            onset_method, onset_threshold);
        
        ap_result.onset_time_rel = onset_time;
        ap_result.onset_value = onset_value;
    catch
        ap_result.onset_time_rel = NaN;
        ap_result.onset_value = NaN;
    end
    
    % Наклон восходящей фазы (используем функцию из calculateAdvancedSlope.m)
    try
        [~, ~, ~, slope_value, slope_angle, ~] = calculateAdvancedSlope(segment_data, segment_time, ...
            segment_time(1), segment_time(threshold_idx), ...
            segment_time(threshold_idx), segment_time(end), ...
            slope_percent, 'positive');
        
        ap_result.slope_value = slope_value;
        ap_result.slope_angle = slope_angle;
    catch
        ap_result.slope_value = NaN;
        ap_result.slope_angle = NaN;
    end
    
    % Порог срабатывания
    ap_result.threshold_value = threshold_value;
end

function metadata = calculateAPMetadata(ap_results, time_data)
    % Вычисляет метаданные для всех найденных AP
    
    metadata = struct();
    
    % Общее количество AP
    metadata.total_aps = length(ap_results);
    
    % Частота срабатывания
    total_time = time_data(end) - time_data(1);
    metadata.firing_rate = metadata.total_aps / total_time;
    
    % Статистики амплитуды
    amplitudes = [ap_results.amplitude_abs];
    valid_amplitudes = amplitudes(~isnan(amplitudes));
    if ~isempty(valid_amplitudes)
        metadata.mean_amplitude = mean(valid_amplitudes);
        metadata.std_amplitude = std(valid_amplitudes);
    else
        metadata.mean_amplitude = NaN;
        metadata.std_amplitude = NaN;
    end
    
    % Статистики полуширины
    half_widths = [ap_results.half_width];
    valid_half_widths = half_widths(~isnan(half_widths));
    if ~isempty(valid_half_widths)
        metadata.mean_half_width = mean(valid_half_widths);
        metadata.std_half_width = std(valid_half_widths);
    else
        metadata.mean_half_width = NaN;
        metadata.std_half_width = NaN;
    end
    
    % Статистики времени нарастания
    rise_times = [ap_results.rise_time];
    valid_rise_times = rise_times(~isnan(rise_times));
    if ~isempty(valid_rise_times)
        metadata.mean_rise_time = mean(valid_rise_times);
        metadata.std_rise_time = std(valid_rise_times);
    else
        metadata.mean_rise_time = NaN;
        metadata.std_rise_time = NaN;
    end
    
    % Статистики времени спада
    decay_times = [ap_results.decay_time];
    valid_decay_times = decay_times(~isnan(decay_times));
    if ~isempty(valid_decay_times)
        metadata.mean_decay_time = mean(valid_decay_times);
        metadata.std_decay_time = std(valid_decay_times);
    else
        metadata.mean_decay_time = NaN;
        metadata.std_decay_time = NaN;
    end
    
    % Статистики максимальной скорости нарастания
    max_dv_dts = [ap_results.max_dv_dt];
    valid_max_dv_dts = max_dv_dts(~isnan(max_dv_dts));
    if ~isempty(valid_max_dv_dts)
        metadata.mean_max_dv_dt = mean(valid_max_dv_dts);
        metadata.std_max_dv_dt = std(valid_max_dv_dts);
    else
        metadata.mean_max_dv_dt = NaN;
        metadata.std_max_dv_dt = NaN;
    end
    
    % Статистики наклона
    slopes = [ap_results.slope_value];
    valid_slopes = slopes(~isnan(slopes));
    if ~isempty(valid_slopes)
        metadata.mean_slope = mean(valid_slopes);
        metadata.std_slope = std(valid_slopes);
    else
        metadata.mean_slope = NaN;
        metadata.std_slope = NaN;
    end
    
    % Статистики рефрактерного периода
    refractory_periods = [ap_results.refractory_period];
    valid_refractory_periods = refractory_periods(~isnan(refractory_periods));
    if ~isempty(valid_refractory_periods)
        metadata.mean_refractory_period = mean(valid_refractory_periods);
        metadata.std_refractory_period = std(valid_refractory_periods);
    else
        metadata.mean_refractory_period = NaN;
        metadata.std_refractory_period = NaN;
    end
end 