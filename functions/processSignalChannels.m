function [data, time_out] = processSignalChannels(data, time_in, opts)
%PROCESSSIGNALCHANNELS Artifact / resample / filter / smooth by profile.

time_in = time_in(:);
time_out = time_in;

switch opts.profile
    case 'viewer'
        if opts.remove_artifact && ~isempty(opts.stims_in)
            win_r = round(opts.artifact_window_ms * (opts.Fs / 1000));
            data = removeStimArtifact(data, opts.stims_in, time_in, win_r, opts.artifact_interp_method);
        end
        if opts.Fs <= opts.newFs
            time_out = time_in;
        else
            data = resample1(data, round(opts.newFs), opts.Fs);
            time_out = linspace(time_in(1), time_in(end), size(data, 1))';
        end
        if any(opts.filter_mask)
            data(:, opts.filter_mask) = applyFilter(data(:, opts.filter_mask), opts.filterSettings, opts.newFs);
        end
    case 'detection'
        data = data(:);
        if opts.filter_enabled
            data = applyFilter(data, opts.filterSettings, opts.newFs);
        end
        if opts.Fs > opts.newFs
            data = resample1(data, round(opts.newFs), opts.Fs);
            time_out = linspace(time_in(1), time_in(end), numel(data))';
        end
    case 'analysis'
        data = data(:);
        if opts.Fs > opts.newFs
            data = resample1(data, round(opts.newFs), opts.Fs);
            time_out = linspace(time_in(1), time_in(end), numel(data))';
        end
        if opts.smoothing_enabled && opts.smoothing_span >= 5
            data = smooth1(data, opts.smoothing_span, opts.smoothing_method);
        end
end

end
