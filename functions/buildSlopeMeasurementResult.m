function new_result = buildSlopeMeasurementResult(values, measurement_metadata, ctx)
%BUILDSLOPEMEASUREMENTRESULT Build one slope_measurement_results entry.

    if nargin < 2 || isempty(measurement_metadata)
        metadata = struct();
    else
        metadata = measurement_metadata;
    end

    metadata.channel = ctx.channel;
    metadata.baseline_start = ctx.baseline_start;
    metadata.baseline_end = ctx.baseline_end;
    metadata.peak_start = ctx.peak_start;
    metadata.peak_end = ctx.peak_end;
    metadata.slope_percent = ctx.slope_percent;
    metadata.peak_polarity = ctx.peak_polarity;
    metadata.chosen_time_interval = ctx.chosen_time_interval;

    metadata.selectedCenter = ctx.selectedCenter;
    metadata.event_inx = ctx.event_inx;
    metadata.stim_inx = ctx.stim_inx;
    metadata.sweep_inx = ctx.sweep_inx;
    metadata.onset_method = ctx.onset_method;
    metadata.onset_threshold = ctx.onset_threshold;
    metadata.show_baseline = ctx.show_baseline;
    metadata.show_onset = ctx.show_onset;
    metadata.show_slope = ctx.show_slope;
    metadata.show_peak = ctx.show_peak;

    metadata.analysis_smooth_enabled = ctx.analysis_smooth_enabled;
    metadata.analysis_smooth_span = ctx.analysis_smooth_span;
    metadata.analysis_smooth_method = ctx.analysis_smooth_method;
    metadata.analysis_show_raw_signal = ctx.analysis_show_raw_signal;

    if ~isfield(metadata, 'rel_shift')
        if strcmp(ctx.selectedCenter, 'stimulus') && ctx.stims_exist && ~isempty(ctx.stims)
            metadata.rel_shift = ctx.stims(ctx.stim_inx);
        else
            metadata.rel_shift = ctx.chosen_time_interval(1);
        end
    end

    metadata.cursor_positions = struct( ...
        'baseline_start', ctx.baseline_start, ...
        'baseline_end', ctx.baseline_end, ...
        'peak_start', ctx.peak_start, ...
        'peak_end', ctx.peak_end);

    new_result = struct( ...
        'baseline_value', values.baseline_value, ...
        'slope_value', values.slope_value, ...
        'peak_time', values.peak_time, ...
        'peak_value', values.peak_value, ...
        'onset_time', values.onset_time, ...
        'onset_value', values.onset_value, ...
        'onset_method', values.onset_method, ...
        'metadata', metadata);

    if strcmp(ctx.selectedCenter, 'stimulus') && ctx.stims_exist && ~isempty(ctx.stims)
        new_result.metadata.stim_time = ctx.stims(ctx.stim_inx);
    else
        new_result.metadata.stim_time = NaN;
    end
end
