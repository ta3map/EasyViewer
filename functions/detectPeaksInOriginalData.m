function events = detectPeaksInOriginalData(calcResult, params)
    % Детекция пиков в оригинальных данных каждого события
    % params должна содержать:
    %   Polarity: 'positive' или 'negative'
    %   MinPeakProminence: минимальная амплитуда пика
    %   MinPeakDistance: минимальное расстояние между пиками (в единицах timeAxis)
    %   MaxPeakWidth: максимальная ширина пика (в единицах timeAxis)
    
    timeAxis = calcResult.timeAxisScaled;
    Fs = calcResult.Fs;
    activeChannels = calcResult.activeChannels;
    originalEventsData = calcResult.originalEventsData;
    timeUnitFactor = calcResult.timeUnitFactor;
    
    Polarity = params.Polarity;
    MinPeakProminence = params.MinPeakProminence;
    MinPeakDistance = params.MinPeakDistance;
    max_peak_width = params.MaxPeakWidth;
    
    numChannels = length(activeChannels);
    numEvents = length(originalEventsData);
    
    debugState('detectPeaksInOriginalData', 'Detecting peaks in %d original events', numEvents);
    
    % Список полей из findpeaks1_result (без маппинга)
    findpeaksFields = {'peak_times', 'peaks', 'widths', 'prominences', ...
                       'onset_times', 'slopes', ...
                       'tangent_x1', 'tangent_y1', 'tangent_x2', 'tangent_y2', ...
                       'decay_times', 'decay_slopes', ...
                       'decay_tangent_x1', 'decay_tangent_y1', 'decay_tangent_x2', 'decay_tangent_y2'};
    
    % Дополнительные поля для events
    extraFields = {'channels', 'eventIndices', 'onset_values', 'decay_values'};
    
    % Инициализация cell arrays для всех полей
    for i = 1:length(findpeaksFields)
        events.(findpeaksFields{i}) = {};
    end
    for i = 1:length(extraFields)
        events.(extraFields{i}) = {};
    end
    
    % Detection for each event
    for eventIdx = 1:numEvents
        eventData = originalEventsData{eventIdx};
        
        % Детекция по каждому каналу в этом событии
        for chIdx = 1:numChannels
            channelIdx = activeChannels(chIdx);
            channelData = eventData(:, chIdx);
            
            % Применяем полярность
            if strcmp(Polarity, 'negative')
                Trace_out = -channelData;
            else
                Trace_out = channelData;
            end
            
            Trace_out(isnan(Trace_out)) = nanmean(Trace_out);
            Trace_out = np_flatten(Trace_out);
            
            % Вычисляем базовую линию и статистику из Trace_out перед findpeaks
            baseline_idx = round(length(Trace_out) * 0.1);
            baseline_idx = max(1, min(baseline_idx, length(Trace_out)));
            baseline_data = Trace_out(1:baseline_idx);
            baseline_value = median(baseline_data);
            baseline_std = std(baseline_data);
            
            % MinPeakDistance передается напрямую в findpeaks (как в autoEventDetection)
            % timeAxis уже масштабирован с учетом timeUnitFactor, поэтому findpeaks сам пересчитает
            findpeaks1_params.signal = Trace_out;
            findpeaks1_params.time = timeAxis;
            findpeaks1_params.timeUnitFactor = timeUnitFactor;
            findpeaks1_params.max_peak_onset_dist = 0.03*timeUnitFactor;
            findpeaks1_params.use_change_point_as_onset = false;
            findpeaks1_params.check_overlap = true;
            findpeaks1_params.MinPeakHeight = MinPeakProminence;
            findpeaks1_params.MinPeakDistance = MinPeakDistance;
            findpeaks1_params.WidthReference = 'halfheight';

            % Детекция пиков с обязательной детекцией онсетов
            findpeaks1_result = findpeaks1(findpeaks1_params);
            
            if isempty(findpeaks1_result.peaks)
                continue;
            end
            
            % Убираем слишком широкие пики
            wide_peaks_mask = findpeaks1_result.widths > max_peak_width;
            findpeaks1_fields = fieldnames(findpeaks1_result);
            for i = 1:length(findpeaks1_fields)
                field = findpeaks1_fields{i};
                if isnumeric(findpeaks1_result.(field)) && length(findpeaks1_result.(field)) == length(findpeaks1_result.peaks)
                    findpeaks1_result.(field)(wide_peaks_mask) = [];
                end
            end
            
            if isempty(findpeaks1_result.peaks)
                continue;
            end
            
            % Преобразуем в столбцы и копируем напрямую из findpeaks1_result
            numPeaks = length(findpeaks1_result.peaks);
            for i = 1:length(findpeaksFields)
                field = findpeaksFields{i};
                events.(field){end+1} = findpeaks1_result.(field)(:);
            end
            
            % Значения онсетов берем строго из исходных данных канала
            peak_onset_indices = findpeaks1_result.onset_indices(:);
            peak_onset_values = NaN(size(findpeaks1_result.onset_times));
            valid_onsets = ~isnan(findpeaks1_result.onset_times) & ~isnan(peak_onset_indices);
            if any(valid_onsets)
                onset_signal_idx = peak_onset_indices(valid_onsets);
                onset_signal_idx = min(length(channelData), max(1, onset_signal_idx));
                peak_onset_values(valid_onsets) = channelData(onset_signal_idx);
            end
            events.onset_values{end+1} = peak_onset_values(:);
            
            % Значения спада берем строго из исходных данных канала
            decay_indices = findpeaks1_result.decay_indices(:);
            decay_values = NaN(size(findpeaks1_result.decay_times));
            valid_decays = ~isnan(findpeaks1_result.decay_times) & ~isnan(decay_indices);
            if any(valid_decays)
                decay_signal_idx = decay_indices(valid_decays);
                decay_signal_idx = min(length(channelData), max(1, decay_signal_idx));
                decay_values(valid_decays) = channelData(decay_signal_idx);
            end
            events.decay_values{end+1} = decay_values(:);
            
            % Инвертируем значения обратно для negative полярности
            if strcmp(Polarity, 'negative')
                events.peaks{end} = -events.peaks{end};
                events.tangent_y1{end} = -events.tangent_y1{end};
                events.tangent_y2{end} = -events.tangent_y2{end};
                events.decay_tangent_y1{end} = -events.decay_tangent_y1{end};
                events.decay_tangent_y2{end} = -events.decay_tangent_y2{end};
            end
            
            % Добавляем дополнительные поля
            events.channels{end+1} = repmat(channelIdx, numPeaks, 1);
            events.eventIndices{end+1} = repmat(eventIdx, numPeaks, 1);
        end
    end
    
    % Объединение cell arrays в векторы
    allFields = [findpeaksFields, extraFields];
    if ~isempty(events.peak_times)
        for i = 1:length(allFields)
            events.(allFields{i}) = vertcat(events.(allFields{i}){:});
        end
        
        % Сортировка по времени
        [sorted_times, sort_idx] = sort(events.peak_times);
        events.peak_times = sorted_times;
        for i = 2:length(allFields)
            events.(allFields{i}) = events.(allFields{i})(sort_idx);
        end
    else
        for i = 1:length(allFields)
            events.(allFields{i}) = [];
        end
    end
    
    % Расчет first_onset для каждого канала
    % Для каждого триала находим первый онсет, затем медиана этих значений по триалам
    first_onset_by_channel = NaN(size(activeChannels));
    first_onset_slope_by_channel = NaN(size(activeChannels));
    first_decay_slope_by_channel = NaN(size(activeChannels));
    if ~isempty(events.peak_times)
        for chIdx = 1:length(activeChannels)
            channelIdx = activeChannels(chIdx);
            channel_mask = events.channels == channelIdx & events.onset_times > 0 & ~isnan(events.onset_times);
            if any(channel_mask)
                % Получаем уникальные триалы для этого канала
                unique_trials = unique(events.eventIndices(channel_mask));
                first_onsets_per_trial = [];
                first_slopes_per_trial = [];
                first_decay_slopes_per_trial = [];
                
                % Для каждого триала находим первый онсет (минимальный)
                for trialIdx = unique_trials(:)'
                    trial_channel_mask = channel_mask & events.eventIndices == trialIdx;
                    if any(trial_channel_mask)
                        trial_onset_times = events.onset_times(trial_channel_mask);
                        [min_onset, min_idx] = min(trial_onset_times);
                        first_onsets_per_trial(end+1) = min_onset;
                        
                        trial_indices = find(trial_channel_mask);
                        idx_in_events = trial_indices(min_idx);
                        first_slopes_per_trial(end+1) = events.slopes(idx_in_events);
                        first_decay_slopes_per_trial(end+1) = events.decay_slopes(idx_in_events);
                    end
                end
                
                % Медиана первых онсетов по всем триалам
                if ~isempty(first_onsets_per_trial)
                    first_onset_by_channel(chIdx) = median(first_onsets_per_trial);
                    
                    first_slopes_valid = first_slopes_per_trial(~isnan(first_slopes_per_trial));
                    if ~isempty(first_slopes_valid)
                        first_onset_slope_by_channel(chIdx) = median(first_slopes_valid);
                    end
                    
                    first_decay_slopes_valid = first_decay_slopes_per_trial(~isnan(first_decay_slopes_per_trial));
                    if ~isempty(first_decay_slopes_valid)
                        first_decay_slope_by_channel(chIdx) = median(first_decay_slopes_valid);
                    end
                end
            end
        end
    end
    events.first_onset_by_channel = first_onset_by_channel;
    events.first_onset_slope_by_channel = first_onset_slope_by_channel;
    events.first_decay_slope_by_channel = first_decay_slope_by_channel;
    response_onsets = first_onset_by_channel(~isnan(first_onset_by_channel));
    if ~isempty(response_onsets)
        events.median_first_onset = median(response_onsets);
    else
        events.median_first_onset = NaN;
    end
    
    % Вычисление медианной амплитуды до и после нуля
    if ~isempty(events.peak_times) && ~isempty(events.peaks)
        before_zero_mask = events.peak_times <= 0;
        after_zero_mask = events.peak_times > 0;
        
        if any(before_zero_mask)
            events.median_amplitude_before_zero = median(events.peaks(before_zero_mask));
        else
            events.median_amplitude_before_zero = NaN;
        end
        
        if any(after_zero_mask)
            events.median_amplitude_after_zero = median(events.peaks(after_zero_mask));
        else
            events.median_amplitude_after_zero = NaN;
        end
    else
        events.median_amplitude_before_zero = NaN;
        events.median_amplitude_after_zero = NaN;
    end
    
    % Расчет медианных slope и decay_slope по каналам (control и response)
    onset_slopes_control = NaN(size(activeChannels));
    onset_slopes_response = NaN(size(activeChannels));
    decay_slopes_control = NaN(size(activeChannels));
    decay_slopes_response = NaN(size(activeChannels));
    
    if ~isempty(events.peak_times)
        for chIdx = 1:length(activeChannels)
            channelIdx = activeChannels(chIdx);
            
            % Контрольные события (onset_times <= 0)
            control_mask = events.channels == channelIdx & ...
                           events.onset_times <= 0 & ...
                           ~isnan(events.onset_times) & ...
                           ~isnan(events.slopes);
            if any(control_mask)
                onset_slopes_control(chIdx) = median(events.slopes(control_mask));
            end
            
            control_decay_mask = events.channels == channelIdx & ...
                                 events.onset_times <= 0 & ...
                                 ~isnan(events.onset_times) & ...
                                 ~isnan(events.decay_slopes);
            if any(control_decay_mask)
                decay_slopes_control(chIdx) = median(events.decay_slopes(control_decay_mask));
            end
            
            % Ответные события (onset_times > 0)
            response_mask = events.channels == channelIdx & ...
                            events.onset_times > 0 & ...
                            ~isnan(events.onset_times) & ...
                            ~isnan(events.slopes);
            if any(response_mask)
                onset_slopes_response(chIdx) = median(events.slopes(response_mask));
            end
            
            response_decay_mask = events.channels == channelIdx & ...
                                  events.onset_times > 0 & ...
                                  ~isnan(events.onset_times) & ...
                                  ~isnan(events.decay_slopes);
            if any(response_decay_mask)
                decay_slopes_response(chIdx) = median(events.decay_slopes(response_decay_mask));
            end
        end
    end
    
    events.onset_slopes_control = onset_slopes_control;
    events.onset_slopes_response = onset_slopes_response;
    events.decay_slopes_control = decay_slopes_control;
    events.decay_slopes_response = decay_slopes_response;
    
    events.polarity = Polarity;
    events.numEvents = length(events.peak_times);
    
    % Подсчет событий до и после нуля
    if ~isempty(events.peak_times)
        events.numEventsBeforeZero = sum(events.peak_times < 0);
        events.numEventsAfterZero = sum(events.peak_times > 0);
    else
        events.numEventsBeforeZero = 0;
        events.numEventsAfterZero = 0;
    end
    
    % Попарный t-тест: подсчет количеств до и после нуля по триалам для каждого канала
    paired_ttest_pvalue_by_channel = NaN(size(activeChannels));
    has_response_mean = false(size(activeChannels));
    
    if ~isempty(events.peak_times) && isfield(events, 'eventIndices') && ~isempty(events.eventIndices)
        for chIdx = 1:length(activeChannels)
            channelIdx = activeChannels(chIdx);
            channel_mask = events.channels == channelIdx;
            
            if ~any(channel_mask)
                continue;
            end
            
            unique_trials = unique(events.eventIndices(channel_mask));
            
            if length(unique_trials) < 2
                continue;
            end
            
            count_before = [];
            count_after = [];
            
            for trialIdx = unique_trials(:)'
                trial_mask = channel_mask & events.eventIndices == trialIdx;
                count_before(end+1) = sum(trial_mask & events.peak_times < 0);
                count_after(end+1) = sum(trial_mask & events.peak_times > 0);
            end
            
            if length(count_before) >= 2 && length(count_after) >= 2
                try
                    [~, pvalue] = ttest(count_before, count_after);
                    paired_ttest_pvalue_by_channel(chIdx) = pvalue;
                    has_response_mean(chIdx) = mean(count_after) > mean(count_before);
                catch
                    paired_ttest_pvalue_by_channel(chIdx) = NaN;
                    has_response_mean(chIdx) = false;
                end
            end
        end
    end
    
    events.paired_ttest_pvalue_by_channel = paired_ttest_pvalue_by_channel;
    events.has_response_mean = has_response_mean;
    
    debugState('detectPeaksInOriginalData', 'Total events found: %d', events.numEvents);
    debugState('detectPeaksInOriginalData', 'Events before zero: %d', events.numEventsBeforeZero);
    debugState('detectPeaksInOriginalData', 'Events after zero: %d', events.numEventsAfterZero);
    if isfield(events, 'onset_times') && ~isempty(events.onset_times)
        num_onsets = sum(~isnan(events.onset_times));
        debugState('detectPeaksInOriginalData', 'Onsets found: %d of %d', num_onsets, length(events.onset_times));
    end
end
