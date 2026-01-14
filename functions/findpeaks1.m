function result = findpeaks1(params)
    % FINDPEAKS1 - находит пики и обязательно детектирует онсеты для каждого пика
    % 
    % result = findpeaks1(params)
    %
    % Входные параметры (структура params):
    %   params.signal - вектор данных сигнала
    %   params.time - вектор времени (должен совпадать по длине с signal)
    %   params.timeUnitFactor - масштаб времени (например, 1000 для ms, 1 для s)
    %   params.max_peak_onset_dist - максимальное расстояние между онсетом и пиком ([] если не используется)
    %   params.use_change_point_as_onset - если true, используется change_time как онсет, иначе ищется онсет между change_idx и peak_idx
    %   params.check_overlap - если true, выполняется проверка на перекрытие пиков и удаление перекрывающихся
    %   params.MinPeakHeight - минимальная высота пика (параметр для findpeaks)
    %   params.MinPeakDistance - минимальное расстояние между пиками (параметр для findpeaks)
    %   params.WidthReference - ссылка для ширины пика (параметр для findpeaks)
    %   и другие параметры для findpeaks
    %
    % Выходные параметры (структура result):
    %   result.peaks - амплитуды пиков
    %   result.peak_times - времена пиков
    %   result.widths - ширины пиков
    %   result.prominences - prominences пиков
    %   result.onset_times - времена онсетов (NaN если онсет не найден)
    %   result.onset_values - значения сигнала в точках онсетов (NaN если онсет не найден)
    %   result.onset_indices - индексы онсетов
    %
    % Алгоритм детекции онсетов:
    %   - Сначала находятся точки изменения во всем сигнале
    %   - Для каждой точки изменения вычисляется baseline как медиана данных до этой точки
    %   - Для каждой точки изменения ищется пик в окне после изменения
    %   - Ищется онсет как точка начала роста от baseline к пику
    %   - Проверка на перекрытие пиков в конце
    
    signal = params.signal;
    time = params.time;
    timeUnitFactor = params.timeUnitFactor;
    max_peak_onset_dist = params.max_peak_onset_dist;
    use_change_point_as_onset = params.use_change_point_as_onset;
    check_overlap = params.check_overlap;
    
    % Формируем varargin для findpeaks из параметров структуры
    varargin = {};
    findpeaks_params = {'MinPeakHeight', 'MinPeakDistance', 'WidthReference', 'MinPeakProminence', 'MinPeakWidth', 'MaxPeakWidth'};
    for i = 1:length(findpeaks_params)
        param_name = findpeaks_params{i};
        if isfield(params, param_name)
            varargin{end+1} = param_name;
            varargin{end+1} = params.(param_name);
        end
    end
    
    % Находим точки изменения во всем сигнале
    % Используем 'linear' для детекции точки перегиба, где начинается плавная дифлексия вверх
    change_points = findchangepts(signal, 'Statistic', 'linear',MaxNumChanges=20);
    
    % Фильтруем change_points: оставляем только те, где значение сигнала не превышает MAD
    if ~isempty(change_points)
        signal_mad = mad(signal, 1);
        signal_median = median(signal);
        change_values = signal(change_points);
        valid_mask = abs(change_values - signal_median) <= signal_mad;
        change_points = change_points(valid_mask);
    end
        
    % Инициализируем массивы для результатов
    peaks = [];
    peak_times = [];
    widths = [];
    prominences = [];
    onset_times = [];
    onset_values = [];
    onset_indices = [];
    
    % Для каждой точки изменения ищем пик в окне после нее
    for cpIdx = 1:length(change_points)
        change_idx = change_points(cpIdx);
        change_time = time(change_idx);
        
        % Определяем окно поиска пика после точки изменения
        % Используем окно до следующей точки изменения или до конца сигнала
        if cpIdx < length(change_points)
            window_end_idx = change_points(cpIdx + 1);
        else
            window_end_idx = length(signal);
        end
        
        window_indices = change_idx:window_end_idx;
        if length(window_indices) < 2
            continue;
        end
        
        window_signal = signal(window_indices);
        window_time = time(window_indices);
        
        % MinPeakDistance должен быть строго меньше размаха окна по времени
        % (иначе findpeaks выдаст ошибку "Expected MinPeakDistance ... < ...")
        mpd_key_idx = find(strcmpi(varargin, 'MinPeakDistance'), 1, 'first');
        if ~isempty(mpd_key_idx) && mpd_key_idx < numel(varargin)
            mpd_val = varargin{mpd_key_idx + 1};
            if isnumeric(mpd_val) && isscalar(mpd_val)
                window_span = abs(window_time(end) - window_time(1));
                window_span_lt = max(0, window_span - eps(window_span));
                varargin{mpd_key_idx + 1} = min(mpd_val, window_span_lt);
            end
        end

        % Ищем пики в окне с параметрами из varargin
        [window_peaks, window_peak_times, window_widths, window_prominences] = findpeaks(window_signal, window_time, varargin{:});
        
        if ~isempty(window_peaks)
            % Берем первый найденный пик в окне
            peak_value = window_peaks(1);
            peak_time = window_peak_times(1);
            
            % Находим индекс пика в исходном сигнале
            [~, peak_idx] = min(abs(time - peak_time));
            
            % Вычисляем baseline как медиана данных за 10 мс до точки изменения
            baseline_window = 0.01 * timeUnitFactor;
            baseline_start_time = change_time - baseline_window;
            [~, baseline_start_idx] = min(abs(time - baseline_start_time));
            baseline_start_idx = max(1, baseline_start_idx);
            baseline_window = signal(baseline_start_idx:change_idx);
            baseline_value = median(baseline_window);
            
            % Определяем онсет в зависимости от режима
            if use_change_point_as_onset
                % Используем change_time как онсет
                onset_time = change_time;
                onset_idx = change_idx;
                onset_value = signal(change_idx);
            else
                % Ищем онсет: от пика к точке изменения + 30% времени назад
                % Ищем точку, где значение <= порога (близко к baseline), что означает начало роста
                threshold_value = baseline_value + (peak_value - baseline_value) * 0.1;
                
                % Вычисляем расстояние между change_idx и peak_idx во времени
                change_to_peak_time = peak_time - change_time;
                extension_time = change_to_peak_time * 0.3;
                
                % Определяем начало поиска: change_idx - 30% времени назад
                search_start_time = change_time - extension_time;
                [~, search_start_idx] = min(abs(time - search_start_time));
                search_start_idx = max(1, search_start_idx);
                
                % Ищем от пика к началу (в обратном направлении), пропуская сам пик
                search_indices = (peak_idx-1):-1:search_start_idx;
                if length(search_indices) < 2
                    continue;
                end
                
                search_data = signal(search_indices);
                search_time_vec = time(search_indices);
                
                % Находим первую точку (от пика к началу) где значение <= 10% от пика
                % Это будет точка начала роста сигнала к пику
                onset_candidates = find(search_data <= threshold_value);
                if isempty(onset_candidates)
                    continue;
                end
                
                onset_idx = search_indices(onset_candidates(1));
                onset_time = search_time_vec(onset_candidates(1));
                onset_value = signal(onset_idx);
            end
            
            % Проверяем расстояние между онсетом и пиком (только если max_peak_onset_dist > 0)
            peak_onset_distance = peak_time - onset_time;
            if ~isempty(max_peak_onset_dist) && max_peak_onset_dist > 0 && peak_onset_distance > max_peak_onset_dist
                continue;
            end
            
            peaks = [peaks; peak_value];
            peak_times = [peak_times; peak_time];
            widths = [widths; window_widths(1)];
            prominences = [prominences; window_prominences(1)];
            onset_times = [onset_times; onset_time];
            onset_values = [onset_values; onset_value];
            onset_indices = [onset_indices; onset_idx];
        end
    end
    
    % Проверка на перекрытие пиков (опционально)
    if check_overlap && length(peak_times) > 1
        % Сортируем по времени пиков
        [peak_times, sort_idx] = sort(peak_times);
        peaks = peaks(sort_idx);
        widths = widths(sort_idx);
        prominences = prominences(sort_idx);
        onset_times = onset_times(sort_idx);
        onset_values = onset_values(sort_idx);
        onset_indices = onset_indices(sort_idx);
        
        % Удаляем перекрывающиеся пики
        keep_mask = true(size(peak_times));
        for i = 1:length(peak_times)-1
            if ~keep_mask(i)
                continue;
            end
            
            % Проверяем перекрытие с последующими пиками
            for j = i+1:length(peak_times)
                if ~keep_mask(j)
                    continue;
                end
                
                % Пики перекрываются, если расстояние между ними меньше суммы их ширин
                peak_distance = peak_times(j) - peak_times(i);
                combined_width = widths(i) + widths(j);
                
                if peak_distance < combined_width
                    % Оставляем пик с большей prominence
                    if prominences(i) >= prominences(j)
                        keep_mask(j) = false;
                    else
                        keep_mask(i) = false;
                        break;
                    end
                end
            end
        end
        
        % Применяем маску
        peaks = peaks(keep_mask);
        peak_times = peak_times(keep_mask);
        widths = widths(keep_mask);
        prominences = prominences(keep_mask);
        onset_times = onset_times(keep_mask);
        onset_values = onset_values(keep_mask);
        onset_indices = onset_indices(keep_mask);
    end
    
    result.peaks = peaks;
    result.peak_times = peak_times;
    result.widths = widths;
    result.prominences = prominences;
    result.onset_times = onset_times;
    result.onset_values = onset_values;
    result.onset_indices = onset_indices;
end
