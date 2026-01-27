function result = autoDetectStimuli(filePath, fileId, params)
    global zav_calling timeUnitFactor stims saveChannelSettingsFunc
    global lfp time Fs channelTable updatePlot
    
    metadata = zav_calling(filePath);
    if isempty(metadata)
        result = [];
        return
    end

    % Получение активных каналов
    channelSettings = get(channelTable, 'Data');
    channelEnabled = [channelSettings{:, 2}];
    activeChannels = find(channelEnabled);
    
    if isempty(activeChannels)
        fprintf('No active channels found.\n');
        result = struct( ...
            'module_name', 'autoDetectStimuli', ...
            'module_display_name', 'Auto Detect Stimuli', ...
            'module_description', 'Автодетекция стимулов в сигнале', ...
            'parameters', params, ...
            'num_stimuli', 0, ...
            'median_stim_delta', NaN, ...
            'anomalous_stim_count', 0, ...
            'tableResultInsert', {{'num_stimuli', 'median_stim_delta', 'anomalous_stim_count'}});
        return;
    end
    
    if params.Channel > 0
        selectedChannels = round(params.Channel);
    else
        selectedChannels = activeChannels;
    end
    selectedChannels = selectedChannels(:);
    
    % Детекция событий
    events_detected = detectPeaksInSignal(lfp, time, Fs, timeUnitFactor, selectedChannels, params);
    
    % Обновление глобальной переменной stims
    stims = events_detected(:);
    [stims, ~] = sort(stims);
    
    debugState('autoDetectStimuli', 'Updated stims: %d stimuli, range [%.6f, %.6f] seconds', ...
        length(stims), min(stims), max(stims));
    
    % Сохранение через saveChannelSettingsFunc (сохраняет обновленный stims)
    saveChannelSettingsFunc();
    
    % Обновление графика после обновления stims
    updatePlot();
    
    anomalousStimCount = 0;
    medianStimDelta = NaN;
    if ~isempty(stims) && length(stims) >= 2
        sortedStims = sort(stims(:));
        stimDiffs = diff(sortedStims);
        medianStimDelta = median(stimDiffs);
        anomalousMask = stimDiffs < 0.9 * medianStimDelta;
        anomalousStimCount = sum(anomalousMask);
    end
    
    [folder, baseName, ~] = fileparts(metadata.filePath);
    
    result = struct( ...
        'module_name', 'autoDetectStimuli', ...
        'module_display_name', 'Auto Detect Stimuli', ...
        'module_description', 'Автодетекция стимулов в сигнале', ...
        'parameters', params, ...
        'num_stimuli', length(stims), ...
        'median_stim_delta', medianStimDelta, ...
        'anomalous_stim_count', anomalousStimCount, ...
        'tableResultInsert', {{'num_stimuli', 'median_stim_delta', 'anomalous_stim_count'}});
end

function events_detected = detectPeaksInSignal(lfp, time, Fs, timeUnitFactor, channels, params)
    Polarity = params.Polarity;
    MinPeakProminence = params.MinPeakProminence;
    % Масштабируем параметры времени для findpeaks (params в секундах, time тоже в секундах)
    MinPeakDistance = params.MinPeakDistance_s * timeUnitFactor;
    max_peak_width = params.MaxPeakWidth_s * timeUnitFactor;
    
    kernel_time_scaled = params.SmoothingKernel_s * timeUnitFactor;
    
    debugState('detectPeaksInSignal', '=== Detection parameters ===');
    debugState('detectPeaksInSignal', 'Polarity: %s', Polarity);
    debugState('detectPeaksInSignal', 'MinPeakProminence: %.3f', MinPeakProminence);
    debugState('detectPeaksInSignal', 'MinPeakDistance: %.6f (scaled time units, timeUnitFactor=%.1f)', MinPeakDistance, timeUnitFactor);
    debugState('detectPeaksInSignal', 'MaxPeakWidth: %.6f (scaled time units)', max_peak_width);
    debugState('detectPeaksInSignal', 'SmoothingKernel: %.6f (scaled time units)', kernel_time_scaled);
    debugState('detectPeaksInSignal', 'Channels to process: %s', mat2str(channels));
    debugState('detectPeaksInSignal', 'Fs: %d Hz', Fs);
    debugState('detectPeaksInSignal', 'Time range: [%.6f, %.6f] seconds', min(time), max(time));
    debugState('detectPeaksInSignal', 'Signal length: %d samples', length(time));
    
    all_times = [];
    
    % Детекция по каждому каналу
    for chIdx = 1:length(channels)
        channelIdx = channels(chIdx);
        channelData = lfp(:, channelIdx);
        
        debugState('detectPeaksInSignal', '--- Channel %d ---', channelIdx);
        debugState('detectPeaksInSignal', 'Channel data: min=%.3f, max=%.3f, mean=%.3f, std=%.3f', ...
            min(channelData), max(channelData), mean(channelData), std(channelData));
        
        % Применяем полярность
        if strcmp(Polarity, 'negative')
            Trace_out = -channelData;
        else
            Trace_out = channelData;
        end
        
        Trace_out(isnan(Trace_out)) = nanmean(Trace_out);
        Trace_out = Trace_out - mean(Trace_out);
        Trace_out = np_flatten(Trace_out);
        
        debugState('detectPeaksInSignal', 'After preprocessing: min=%.3f, max=%.3f, mean=%.3f, std=%.3f', ...
            min(Trace_out), max(Trace_out), mean(Trace_out), std(Trace_out));
        debugState('detectPeaksInSignal', '99.9%% quantile: %.3f', quantile(Trace_out, 0.999));
        
        % Масштабируем time для findpeaks (в единицах timeUnitFactor)
        time_scaled = time * timeUnitFactor;
        
        % Детекция пиков
        [peaks, peak_times, widths, prominences] = findpeaks(Trace_out, time_scaled, ...
            'MinPeakHeight', MinPeakProminence, ...
            'MinPeakDistance', MinPeakDistance, ...
            'WidthReference', 'halfheight');
        
        debugState('detectPeaksInSignal', 'After findpeaks: found %d peaks', length(peaks));
        if ~isempty(peaks)
            debugState('detectPeaksInSignal', 'Peak amplitudes range: [%.3f, %.3f]', min(peaks), max(peaks));
            debugState('detectPeaksInSignal', 'Peak widths range: [%.6f, %.6f] (scaled units)', min(widths), max(widths));
            debugState('detectPeaksInSignal', 'Peak prominences range: [%.3f, %.3f]', min(prominences), max(prominences));
            debugState('detectPeaksInSignal', 'Peak times range: [%.6f, %.6f] (scaled units)', min(peak_times), max(peak_times));
        else
            debugState('detectPeaksInSignal', 'No peaks found with MinPeakHeight=%.3f', MinPeakProminence);
            % Попробуем найти пики без ограничений для диагностики
            [peaks_all, ~, widths_all, prominences_all] = findpeaks(Trace_out, time_scaled);
            if ~isempty(peaks_all)
                debugState('detectPeaksInSignal', 'Preliminary analysis (no params): found %d peaks', length(peaks_all));
                debugState('detectPeaksInSignal', 'All peaks amplitudes: min=%.3f, max=%.3f, median=%.3f, mean=%.3f', ...
                    min(peaks_all), max(peaks_all), median(peaks_all), mean(peaks_all));
                debugState('detectPeaksInSignal', 'All peaks prominences: min=%.3f, max=%.3f, median=%.3f, mean=%.3f', ...
                    min(prominences_all), max(prominences_all), median(prominences_all), mean(prominences_all));
                debugState('detectPeaksInSignal', 'Recommended MinPeakProminence: %.3f (median prominence)', median(prominences_all));
                debugState('detectPeaksInSignal', 'Recommended MinPeakProminence: %.3f (25%% quantile)', quantile(prominences_all, 0.25));
            else
                debugState('detectPeaksInSignal', 'WARNING: No peaks found even without parameters! Signal may be too smooth or noisy.');
            end
            continue;
        end
        
        % Убираем слишком широкие пики
        wide_peaks_mask = widths > max_peak_width;
        num_wide_peaks = sum(wide_peaks_mask);
        peak_times(wide_peaks_mask) = [];
        peaks(wide_peaks_mask) = [];
        widths(wide_peaks_mask) = [];
        prominences(wide_peaks_mask) = [];
        
        debugState('detectPeaksInSignal', 'After width filtering: removed %d peaks (too wide, > %.6f)', ...
            num_wide_peaks, max_peak_width);
        debugState('detectPeaksInSignal', 'Remaining peaks for channel %d: %d', channelIdx, length(peaks));
        
        if isempty(peak_times)
            debugState('detectPeaksInSignal', 'All peaks were too wide for channel %d', channelIdx);
            continue;
        end
        
        % Преобразуем времена обратно в секунды
        peak_times_seconds = peak_times / timeUnitFactor;
        all_times = [all_times; peak_times_seconds(:)];
        debugState('detectPeaksInSignal', 'Added %d peaks from channel %d', length(peak_times_seconds), channelIdx);
    end
    
    % Убираем дубликаты и сортируем
    events_detected = unique(all_times);
    events_detected = sort(events_detected);
    
    debugState('detectPeaksInSignal', '=== Final results ===');
    debugState('detectPeaksInSignal', 'Total unique events found: %d', length(events_detected));
    if ~isempty(events_detected)
        debugState('detectPeaksInSignal', 'Event times range: [%.6f, %.6f] seconds', min(events_detected), max(events_detected));
    end
end

