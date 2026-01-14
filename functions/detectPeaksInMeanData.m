function events = detectPeaksInMeanData(calcResult, params)
    % Детекция пиков в средних данных из calcResult по всем каналам
    % params должна содержать:
    %   Polarity: 'positive' или 'negative'
    %   MinPeakProminence: минимальная амплитуда пика
    %   MinPeakDistance: минимальное расстояние между пиками (в единицах timeAxis)
    %   MaxPeakWidth: максимальная ширина пика (в единицах timeAxis)
    %   ShowRecommendations: true/false - показывать рекомендации по параметрам на основе предварительного анализа (по умолчанию false)
    
    timeAxis = calcResult.timeAxisScaled;
    Fs = calcResult.Fs;
    activeChannels = calcResult.activeChannels;
    timeUnitFactor = calcResult.timeUnitFactor;
    
    Polarity = params.Polarity;
    MinPeakProminence = params.MinPeakProminence;
    MinPeakDistance = params.MinPeakDistance;
    max_peak_width = params.MaxPeakWidth;
    
    meanData = calcResult.meanData;
    % meanData содержит все каналы, нужно выбрать только активные
    meanData = meanData(:, activeChannels);
    
    numChannels = size(meanData, 2);
    
    debugState('detectPeaksInMeanData', '=== Detection parameters ===');
    debugState('detectPeaksInMeanData', 'Polarity: %s', Polarity);
    debugState('detectPeaksInMeanData', 'MinPeakProminence: %.3f', MinPeakProminence);
    debugState('detectPeaksInMeanData', 'MinPeakDistance: %.6f (time units)', MinPeakDistance);
    debugState('detectPeaksInMeanData', 'MaxPeakWidth: %.6f (time units)', max_peak_width);
    debugState('detectPeaksInMeanData', 'Active channels: %d', numChannels);
    debugState('detectPeaksInMeanData', 'TimeAxis range: [%.6f, %.6f]', min(timeAxis), max(timeAxis));
    debugState('detectPeaksInMeanData', 'Fs: %d Hz', Fs);
    
    all_times = [];
    all_amplitudes = [];
    all_widths = [];
    all_prominences = [];
    all_channels = [];
    
    % Детекция по каждому каналу
    for chIdx = 1:numChannels
        channelIdx = activeChannels(chIdx);
        channelData = meanData(:, chIdx);
        
        % Применяем полярность
        if strcmp(Polarity, 'negative')
            Trace_out = -channelData;
        else
            Trace_out = channelData;
        end
        
        Trace_out(isnan(Trace_out)) = nanmean(Trace_out);
        Trace_out = np_flatten(Trace_out);
        
        debugState('detectPeaksInMeanData', '--- Channel %d ---', channelIdx);
        debugState('detectPeaksInMeanData', 'Using pre-smoothed data from calcResult');
        debugState('detectPeaksInMeanData', 'Trace_out length: %d samples', numel(Trace_out));
        debugState('detectPeaksInMeanData', 'Trace_out min: %.3f, max: %.3f, mean: %.3f, std: %.3f', ...
            min(Trace_out), max(Trace_out), mean(Trace_out), std(Trace_out));
        debugState('detectPeaksInMeanData', 'Trace_out 99.9%% quantile: %.3f', quantile(Trace_out, 0.999));
        
        % Предварительный анализ: findpeaks без параметров для оценки данных (опционально)
        showRecommendations = isfield(params, 'ShowRecommendations') && logical(params.ShowRecommendations);
        if showRecommendations
            [peaks_all, ~, widths_all, prominences_all] = findpeaks(Trace_out, timeAxis);
            debugState('detectPeaksInMeanData', 'Preliminary analysis (findpeaks without params): found %d peaks', length(peaks_all));
            if ~isempty(peaks_all)
                debugState('detectPeaksInMeanData', 'All peaks amplitudes: min=%.3f, max=%.3f, median=%.3f, mean=%.3f', ...
                    min(peaks_all), max(peaks_all), median(peaks_all), mean(peaks_all));
                debugState('detectPeaksInMeanData', 'All peaks prominences: min=%.3f, max=%.3f, median=%.3f, mean=%.3f', ...
                    min(prominences_all), max(prominences_all), median(prominences_all), mean(prominences_all));
                debugState('detectPeaksInMeanData', 'All peaks widths: min=%.6f, max=%.6f, median=%.6f, mean=%.6f', ...
                    min(widths_all), max(widths_all), median(widths_all), mean(widths_all));
                debugState('detectPeaksInMeanData', 'Recommended MinPeakProminence: %.3f (median prominence)', median(prominences_all));
                debugState('detectPeaksInMeanData', 'Recommended MinPeakProminence: %.3f (mean prominence)', mean(prominences_all));
                debugState('detectPeaksInMeanData', 'Recommended MinPeakProminence: %.3f (25%% quantile prominence)', quantile(prominences_all, 0.25));
                debugState('detectPeaksInMeanData', 'Recommended MinPeakProminence: %.3f (75%% quantile prominence)', quantile(prominences_all, 0.75));
                debugState('detectPeaksInMeanData', 'Recommended MinPeakProminence: %.3f (90%% quantile prominence)', quantile(prominences_all, 0.90));
                debugState('detectPeaksInMeanData', 'Current MinPeakProminence: %.3f (%.1f%% of peaks would pass)', ...
                    MinPeakProminence, 100 * sum(prominences_all >= MinPeakProminence) / length(prominences_all));
                debugState('detectPeaksInMeanData', 'Recommended MaxPeakWidth: %.6f (median width)', median(widths_all));
                debugState('detectPeaksInMeanData', 'Recommended MaxPeakWidth: %.6f (75%% quantile width)', quantile(widths_all, 0.75));
                debugState('detectPeaksInMeanData', 'Current MaxPeakWidth: %.6f (%.1f%% of peaks would pass)', ...
                    max_peak_width, 100 * sum(widths_all <= max_peak_width) / length(widths_all));
            else
                debugState('detectPeaksInMeanData', 'WARNING: No peaks found without parameters! Signal may be too smooth or noisy.');
            end
        end
        
        % MinPeakDistance передается напрямую в findpeaks (как в autoEventDetection)
        % timeAxisScaled уже масштабирован на timeUnitFactor, поэтому MinPeakDistance должен быть
        % в тех же масштабированных единицах (например, если timeUnitFactor=1000, то 50 мс = 50 единиц)
        debugState('detectPeaksInMeanData', 'MinPeakDistance: %.6f (scaled time units, timeUnitFactor=%.1f)', MinPeakDistance, timeUnitFactor);
        % Детекция пиков
        [peaks, peak_times, widths, prominences] = findpeaks(Trace_out, timeAxis, ...
            'MinPeakHeight', MinPeakProminence, ...
            'MinPeakDistance', MinPeakDistance, ...
            'WidthReference', 'halfheight');
        
        debugState('detectPeaksInMeanData', 'After findpeaks: found %d peaks', length(peaks));
        if ~isempty(peaks)
            debugState('detectPeaksInMeanData', 'Peak amplitudes range: [%.3f, %.3f]', min(peaks), max(peaks));
            debugState('detectPeaksInMeanData', 'Peak widths range: [%.6f, %.6f]', min(widths), max(widths));
            debugState('detectPeaksInMeanData', 'Peak prominences range: [%.3f, %.3f]', min(prominences), max(prominences));
        end
        
        if isempty(peaks)
            debugState('detectPeaksInMeanData', 'No peaks found for channel %d', channelIdx);
            continue;
        end
        
        % Убираем слишком широкие пики
        wide_peaks_mask = widths > max_peak_width;
        num_wide_peaks = sum(wide_peaks_mask);
        peak_times(wide_peaks_mask) = [];
        peaks(wide_peaks_mask) = [];
        widths(wide_peaks_mask) = [];
        prominences(wide_peaks_mask) = [];
        
        debugState('detectPeaksInMeanData', 'After width filtering: removed %d peaks (too wide, > %.6f)', ...
            num_wide_peaks, max_peak_width);
        debugState('detectPeaksInMeanData', 'Remaining peaks for channel %d: %d', channelIdx, length(peaks));
        
        if isempty(peaks)
            continue;
        end
        
        % Сохраняем найденные пики
        % Убеждаемся, что все векторы являются столбцами
        peak_times = peak_times(:);
        peaks = peaks(:);
        widths = widths(:);
        prominences = prominences(:);
        
        all_times = [all_times; peak_times];
        all_amplitudes = [all_amplitudes; peaks];
        all_widths = [all_widths; widths];
        all_prominences = [all_prominences; prominences];
        all_channels = [all_channels; repmat(activeChannels(chIdx), length(peaks), 1)];
        % Для средних данных все события относятся к одному "событию" (среднему)
        all_event_indices = [all_event_indices; ones(length(peaks), 1)];
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
    else
        events.times = [];
        events.amplitudes = [];
        events.widths = [];
        events.prominences = [];
        events.channels = [];
        events.eventIndices = [];
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
    
    debugState('detectPeaksInMeanData', '=== Final results ===');
    debugState('detectPeaksInMeanData', 'Total events found: %d (polarity: %s)', events.numEvents, Polarity);
    debugState('detectPeaksInMeanData', 'Events before zero: %d', events.numEventsBeforeZero);
    debugState('detectPeaksInMeanData', 'Events after zero: %d', events.numEventsAfterZero);
    if events.numEvents > 0
        debugState('detectPeaksInMeanData', 'Event times range: [%.6f, %.6f]', min(events.times), max(events.times));
        debugState('detectPeaksInMeanData', 'Event amplitudes range: [%.3f, %.3f]', min(events.amplitudes), max(events.amplitudes));
        debugState('detectPeaksInMeanData', 'Channels with events: %s', mat2str(unique(events.channels)'));
    end
end
