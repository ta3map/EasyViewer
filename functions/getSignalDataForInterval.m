function [channel_data, time_vector] = getSignalDataForInterval(lfp_file, time, channel_idx, time_interval, params)
%GETSIGNALDATAFORINTERVAL Channel data for a time window (narrow LFP slice).
%   Pass lfp_file (matfile/struct), NOT lfp_file.lfp — bare .lfp loads the whole array.

if nargin < 5
    params = struct();
end

if ~isfield(params, 'smoothing_enabled')
    params.smoothing_enabled = false;
end
if ~isfield(params, 'smoothing_span')
    params.smoothing_span = 5;
end
if ~isfield(params, 'smoothing_method')
    params.smoothing_method = 'moving';
end
if ~isfield(params, 'remove_artifact')
    params.remove_artifact = false;
end
if ~isfield(params, 'artifact_window_ms')
    params.artifact_window_ms = 0;
end
if ~isfield(params, 'artifact_interp_method')
    params.artifact_interp_method = 'linear';
end
if ~isfield(params, 'stims')
    params.stims = [];
end
if ~isfield(params, 'Fs')
    params.Fs = [];
end
if ~isfield(params, 'mean_group_ch')
    params.mean_group_ch = [];
end

[row_start, row_end] = timeWindowIndices(time, time_interval(1), time_interval(2));
if isempty(row_start)
    channel_data = [];
    time_vector = [];
    return;
end

lfpDims = lfp_size(lfp_file);
nCh = lfpDims(2);
if isempty(channel_idx) || channel_idx < 1 || channel_idx > nCh
    channel_idx = 1;
end

mean_chs = params.mean_group_ch(:);
if islogical(params.mean_group_ch)
    mean_chs = find(params.mean_group_ch);
else
    mean_chs = mean_chs(mean_chs >= 1 & mean_chs <= nCh);
end
cols = unique([channel_idx; mean_chs(:)], 'stable');
local_lfp = lfp_file.lfp(row_start:row_end, cols);

if ~isempty(mean_chs)
    mean_local = ismember(cols, mean_chs);
    local_lfp(:, mean_local) = local_lfp(:, mean_local) - mean(local_lfp(:, mean_local), 2);
end

ch_local = find(cols == channel_idx, 1, 'first');
channel_data = local_lfp(:, ch_local);
time_vector = time(row_start:row_end);

if params.remove_artifact && ~isempty(params.stims) && ~isempty(params.Fs)
    win_r = round(params.artifact_window_ms * (params.Fs / 1000));
    stims_in = params.stims(params.stims >= time_interval(1) & params.stims < time_interval(2));
    if ~isempty(stims_in)
        channel_data = removeStimArtifact(channel_data, stims_in, time_vector, ...
            win_r, params.artifact_interp_method);
    end
end

if params.smoothing_enabled && params.smoothing_span >= 5
    channel_data = smooth1(channel_data(:), params.smoothing_span, params.smoothing_method);
end
end
