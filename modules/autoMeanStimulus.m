function result = autoMeanStimulus(filePath, fileId, params)
    global zav_calling autodetection_settings timeUnitFactor
    
    metadata = zav_calling(filePath);
    if isempty(metadata)
        result = [];
        return
    end

    buildFigure = params.buildFigure;
    opts = struct('autoScale', params.autoScale, 'xLimits', params.xLimits, 'showOriginalTraces', params.showOriginalTraces, 'removeBaseline', params.removeBaseline, 'removeArtifact', params.removeArtifact, 'artifactWindow_ms', params.artifactWindow_ms, 'SmoothingKernel_s', params.SmoothingKernel_s, 'SubtractMean', params.SubtractMean);
    if isfield(params, 'Channel')
        opts.Channel = params.Channel;
    end
    [calcResult, plotParams] = calculateMeanEvents('stimuli', opts);

    detParams = struct('Polarity', params.Polarity, ...
        'MinPeakProminence', params.MinPeakProminence, ...
        'MinPeakDistance', params.MinPeakDistance_s * timeUnitFactor, ...
        'MaxPeakWidth', params.MaxPeakWidth_s * timeUnitFactor, ...
        'SmoothingKernel_s', params.SmoothingKernel_s * timeUnitFactor);

    events = detectPeaksInOriginalData(calcResult, detParams);

    timePoints = calcResult.timePoints;
    stim_dt_min_max = 'N/A';
    if numel(timePoints) >= 2
        dt = diff(timePoints(:)) * timeUnitFactor;
        stim_dt_min_max = sprintf('%.2f - %.2f', min(dt), max(dt));
    end
    calcResult.stim_dt_min_max = stim_dt_min_max;

    figPath = '';
    if buildFigure
        figPath = plotMeanStimulusFullResult(calcResult, plotParams, events, metadata, params);
    end
    
    result = struct( ...
        'module_name', 'autoMeanStimulus', ...
        'module_display_name', 'Auto Mean Stimulus', ...
        'module_description', 'Автоусреднение стимулов', ...
        'report_path', figPath, ...
        'parameters', params, ...
        'calcResult', calcResult, ...
        'events', events, ...
        'stim_dt_min_max', stim_dt_min_max, ...
        'tableResultInsert', {{'stim_dt_min_max', 'events.median_first_onset', 'events.mean_first_onset', 'events.median_onset_after_zero', 'events.mean_onset_after_zero', 'events.first_onset_jitter', 'events.has_response_mean', 'events.median_amplitude_before_zero', 'events.median_amplitude_after_zero', 'events.amplitude_jitter', 'events.av_trace_onset_ms', 'events.av_trace_peak_ms', 'events.av_trace_peak_amplitude', 'events.av_trace_halfpeak_ms', 'events.has_response_av_trace'}});
end

