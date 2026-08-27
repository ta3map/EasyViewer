function results = autoMeasureSlopeRanges(opts)
%AUTOMEASURESLOPERANGES Batch slope measurement for centers (stim/event/continuous).
%
%   opts.centers          - vector of center times (seconds)
%   opts.windowSize       - window length after each center
%   opts.baseline_rel     - struct with .start .end (relative to center)
%   opts.peak_rel         - struct with .start .end
%   opts.selectedCenter   - 'stimulus' | 'events' | 'continuous'
%   opts.channel, .slope_percent, .peak_polarity
%   opts.onset_method, .onset_threshold
%   opts.show_baseline, .show_onset, .show_slope, .show_peak
%   opts.time_back, .time_forward
%   opts.analysis_smooth_enabled, .analysis_smooth_span, .analysis_smooth_method
%   opts.analysis_show_raw_signal
%   opts.remove_artifact, .artifact_window_ms, .artifact_interp_method (optional)

    global lfp_file time Fs stims mean_group_ch art_rem_settings

    centers = opts.centers(:);
    n = numel(centers);
    results = struct('baseline_value', {}, 'slope_value', {}, ...
        'peak_time', {}, 'peak_value', {}, ...
        'onset_time', {}, 'onset_value', {}, 'onset_method', {}, ...
        'metadata', {});

    data_params = struct();
    data_params.smoothing_enabled = opts.analysis_smooth_enabled;
    data_params.smoothing_span = opts.analysis_smooth_span;
    data_params.smoothing_method = opts.analysis_smooth_method;
    data_params.stims = stims;
    data_params.Fs = Fs;
    data_params.mean_group_ch = mean_group_ch;
    if isfield(opts, 'remove_artifact')
        data_params.remove_artifact = opts.remove_artifact;
    else
        data_params.remove_artifact = false;
    end
    if isfield(opts, 'artifact_window_ms')
        data_params.artifact_window_ms = opts.artifact_window_ms;
    else
        data_params.artifact_window_ms = art_rem_settings.artifact_window_ms;
    end
    if isfield(opts, 'artifact_interp_method')
        data_params.artifact_interp_method = opts.artifact_interp_method;
    else
        data_params.artifact_interp_method = art_rem_settings.interp_method;
    end

    for i = 1:n
        center = centers(i);
        chosen_time_interval = [center, center + opts.windowSize];
        rel_shift = center;

        baseline_start = center + opts.baseline_rel.start;
        baseline_end = center + opts.baseline_rel.end;
        peak_start = center + opts.peak_rel.start;
        peak_end = center + opts.peak_rel.end;

        calc_interval = getMeasurementInterval(baseline_start, baseline_end, peak_start, peak_end, ...
            chosen_time_interval, opts.time_back, opts.time_forward, time);

        [channel_data, time_vector] = getSignalDataForInterval( ...
            lfp_file, time, opts.channel, calc_interval, data_params);

        [slope_value, ~, peak_time, peak_value, baseline_value, onset_time, onset_value, measurement_metadata] = ...
            calculateSlopeMeasurement(channel_data, time_vector, ...
            baseline_start, baseline_end, peak_start, peak_end, ...
            opts.slope_percent, opts.peak_polarity, rel_shift);

        values = struct( ...
            'baseline_value', baseline_value, ...
            'slope_value', slope_value, ...
            'peak_time', peak_time, ...
            'peak_value', peak_value, ...
            'onset_time', onset_time, ...
            'onset_value', onset_value, ...
            'onset_method', 'calculated_by_slope');
        if isfield(measurement_metadata, 'onset_method')
            values.onset_method = measurement_metadata.onset_method;
        end

        ctx = struct();
        ctx.channel = opts.channel;
        ctx.baseline_start = baseline_start;
        ctx.baseline_end = baseline_end;
        ctx.peak_start = peak_start;
        ctx.peak_end = peak_end;
        ctx.slope_percent = opts.slope_percent;
        ctx.peak_polarity = opts.peak_polarity;
        ctx.chosen_time_interval = chosen_time_interval;
        ctx.selectedCenter = opts.selectedCenter;
        ctx.event_inx = i;
        ctx.stim_inx = i;
        ctx.sweep_inx = NaN;
        ctx.onset_method = opts.onset_method;
        ctx.onset_threshold = opts.onset_threshold;
        ctx.show_baseline = opts.show_baseline;
        ctx.show_onset = opts.show_onset;
        ctx.show_slope = opts.show_slope;
        ctx.show_peak = opts.show_peak;
        ctx.analysis_smooth_enabled = opts.analysis_smooth_enabled;
        ctx.analysis_smooth_span = opts.analysis_smooth_span;
        ctx.analysis_smooth_method = opts.analysis_smooth_method;
        ctx.analysis_show_raw_signal = opts.analysis_show_raw_signal;
        ctx.stims = stims;
        ctx.stims_exist = ~isempty(stims);

        if strcmp(opts.selectedCenter, 'events')
            ctx.stim_inx = NaN;
        elseif strcmp(opts.selectedCenter, 'stimulus')
            ctx.event_inx = NaN;
        else
            ctx.stim_inx = NaN;
            ctx.event_inx = NaN;
        end

        results(end+1) = buildSlopeMeasurementResult(values, measurement_metadata, ctx); %#ok<AGROW>
    end
end
