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
    
    all_times = [];
    all_amplitudes = [];
    all_widths = [];
    all_prominences = [];
    all_channels = [];
    all_event_indices = [];
    all_onset_times = [];
    all_onset_values = [];
    all_slopes = [];
    all_tangent_x1 = [];
    all_tangent_y1 = [];
    all_tangent_x2 = [];
    all_tangent_y2 = [];
    all_decay_times = [];
    all_decay_values = [];
    all_decay_slopes = [];
    all_decay_tangent_x1 = [];
    all_decay_tangent_y1 = [];
    all_decay_tangent_x2 = [];
    all_decay_tangent_y2 = [];
    
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
            
            peaks = findpeaks1_result.peaks;
            peak_times = findpeaks1_result.peak_times;
            widths = findpeaks1_result.widths;
            prominences = findpeaks1_result.prominences;
            peak_onset_times = findpeaks1_result.onset_times;
            peak_onset_indices = findpeaks1_result.onset_indices;
            slopes = findpeaks1_result.slopes;
            tangent_x1 = findpeaks1_result.tangent_x1;
            tangent_y1 = findpeaks1_result.tangent_y1;
            tangent_x2 = findpeaks1_result.tangent_x2;
            tangent_y2 = findpeaks1_result.tangent_y2;
            decay_times = findpeaks1_result.decay_times;
            decay_indices = findpeaks1_result.decay_indices;
            decay_slopes = findpeaks1_result.decay_slopes;
            decay_tangent_x1 = findpeaks1_result.decay_tangent_x1;
            decay_tangent_y1 = findpeaks1_result.decay_tangent_y1;
            decay_tangent_x2 = findpeaks1_result.decay_tangent_x2;
            decay_tangent_y2 = findpeaks1_result.decay_tangent_y2;
            
            if isempty(peaks)
                continue;
            end
            
            % Убираем слишком широкие пики
            wide_peaks_mask = widths > max_peak_width;
            peak_times(wide_peaks_mask) = [];
            peaks(wide_peaks_mask) = [];
            widths(wide_peaks_mask) = [];
            prominences(wide_peaks_mask) = [];
            peak_onset_times(wide_peaks_mask) = [];
            peak_onset_indices(wide_peaks_mask) = [];
            slopes(wide_peaks_mask) = [];
            tangent_x1(wide_peaks_mask) = [];
            tangent_y1(wide_peaks_mask) = [];
            tangent_x2(wide_peaks_mask) = [];
            tangent_y2(wide_peaks_mask) = [];
            decay_times(wide_peaks_mask) = [];
            decay_indices(wide_peaks_mask) = [];
            decay_slopes(wide_peaks_mask) = [];
            decay_tangent_x1(wide_peaks_mask) = [];
            decay_tangent_y1(wide_peaks_mask) = [];
            decay_tangent_x2(wide_peaks_mask) = [];
            decay_tangent_y2(wide_peaks_mask) = [];
            
            if isempty(peaks)
                continue;
            end
            
            % Сохраняем найденные пики
            % Убеждаемся, что все векторы являются столбцами
            peak_times = peak_times(:);
            peaks = peaks(:);
            widths = widths(:);
            prominences = prominences(:);
            peak_onset_times = peak_onset_times(:);
            
            % Значения онсетов берем строго из исходных данных канала (в тех же координатах, что и трейсы)
            peak_onset_values = NaN(size(peak_onset_times));
            valid_onsets = ~isnan(peak_onset_times) & ~isnan(peak_onset_indices);
            if any(valid_onsets)
                onset_signal_idx = peak_onset_indices(valid_onsets);
                onset_signal_idx = min(length(channelData), max(1, onset_signal_idx));
                peak_onset_values(valid_onsets) = channelData(onset_signal_idx);
            end
            
            % Значения спада берем строго из исходных данных канала (в тех же координатах, что и трейсы)
            decay_values = NaN(size(decay_times));
            valid_decays = ~isnan(decay_times) & ~isnan(decay_indices);
            if any(valid_decays)
                decay_signal_idx = decay_indices(valid_decays);
                decay_signal_idx = min(length(channelData), max(1, decay_signal_idx));
                decay_values(valid_decays) = channelData(decay_signal_idx);
            end
            
            % Инвертируем значения обратно для negative полярности (для правильной визуализации)
            if strcmp(Polarity, 'negative')
                peaks = -peaks;
                tangent_y1 = -tangent_y1;
                tangent_y2 = -tangent_y2;
                decay_tangent_y1 = -decay_tangent_y1;
                decay_tangent_y2 = -decay_tangent_y2;
            end
            
            all_times = [all_times; peak_times];
            all_amplitudes = [all_amplitudes; peaks];
            all_widths = [all_widths; widths];
            all_prominences = [all_prominences; prominences];
            all_channels = [all_channels; repmat(channelIdx, length(peaks), 1)];
            all_event_indices = [all_event_indices; repmat(eventIdx, length(peaks), 1)];
            all_onset_times = [all_onset_times; peak_onset_times];
            all_onset_values = [all_onset_values; peak_onset_values];
            all_slopes = [all_slopes; slopes];
            all_tangent_x1 = [all_tangent_x1; tangent_x1];
            all_tangent_y1 = [all_tangent_y1; tangent_y1];
            all_tangent_x2 = [all_tangent_x2; tangent_x2];
            all_tangent_y2 = [all_tangent_y2; tangent_y2];
            all_decay_times = [all_decay_times; decay_times];
            all_decay_values = [all_decay_values; decay_values];
            all_decay_slopes = [all_decay_slopes; decay_slopes];
            all_decay_tangent_x1 = [all_decay_tangent_x1; decay_tangent_x1];
            all_decay_tangent_y1 = [all_decay_tangent_y1; decay_tangent_y1];
            all_decay_tangent_x2 = [all_decay_tangent_x2; decay_tangent_x2];
            all_decay_tangent_y2 = [all_decay_tangent_y2; decay_tangent_y2];
        end
    end
    
    % Сортировка по времени
    if ~isempty(all_times)
        [sorted_times, sort_idx] = sort(all_times);
        events.times = sorted_times;
        events.amplitudes = all_amplitudes(sort_idx);
        events.widths = all_widths(sort_idx);
        events.prominences = all_prominences(sort_idx);
        events.channels = all_channels(sort_idx);
        events.eventIndices = all_event_indices(sort_idx);
        events.onset_times = all_onset_times(sort_idx);
        events.onset_values = all_onset_values(sort_idx);
        events.slopes = all_slopes(sort_idx);
        events.tangent_x1 = all_tangent_x1(sort_idx);
        events.tangent_y1 = all_tangent_y1(sort_idx);
        events.tangent_x2 = all_tangent_x2(sort_idx);
        events.tangent_y2 = all_tangent_y2(sort_idx);
        events.decay_times = all_decay_times(sort_idx);
        events.decay_values = all_decay_values(sort_idx);
        events.decay_slopes = all_decay_slopes(sort_idx);
        events.decay_tangent_x1 = all_decay_tangent_x1(sort_idx);
        events.decay_tangent_y1 = all_decay_tangent_y1(sort_idx);
        events.decay_tangent_x2 = all_decay_tangent_x2(sort_idx);
        events.decay_tangent_y2 = all_decay_tangent_y2(sort_idx);
    else
        events.times = [];
        events.amplitudes = [];
        events.widths = [];
        events.prominences = [];
        events.channels = [];
        events.eventIndices = [];
        events.onset_times = [];
        events.onset_values = [];
        events.slopes = [];
        events.tangent_x1 = [];
        events.tangent_y1 = [];
        events.tangent_x2 = [];
        events.tangent_y2 = [];
        events.decay_times = [];
        events.decay_values = [];
        events.decay_slopes = [];
        events.decay_tangent_x1 = [];
        events.decay_tangent_y1 = [];
        events.decay_tangent_x2 = [];
        events.decay_tangent_y2 = [];
    end
    
    events.polarity = Polarity;
    events.numEvents = length(events.times);
    
    % Подсчет событий до и после нуля
    if ~isempty(events.times)
        events.numEventsBeforeZero = sum(events.times < 0);
        events.numEventsAfterZero = sum(events.times > 0);
    else
        events.numEventsBeforeZero = 0;
        events.numEventsAfterZero = 0;
    end
    
    debugState('detectPeaksInOriginalData', 'Total events found: %d', events.numEvents);
    debugState('detectPeaksInOriginalData', 'Events before zero: %d', events.numEventsBeforeZero);
    debugState('detectPeaksInOriginalData', 'Events after zero: %d', events.numEventsAfterZero);
    if isfield(events, 'onset_times') && ~isempty(events.onset_times)
        num_onsets = sum(~isnan(events.onset_times));
        debugState('detectPeaksInOriginalData', 'Onsets found: %d of %d', num_onsets, length(events.onset_times));
    end
end
