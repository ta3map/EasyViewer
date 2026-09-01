function [local_lfp, time_vector, cols] = readLfpChannelsForInterval(lfp_file, time, time_interval, channel_indices, mean_group_ch)
%READLFPCHANNELSFORINTERVAL Lazy matfile slice for one or more channels + mean group.

channel_indices = channel_indices(:)';
channel_indices = channel_indices(isfinite(channel_indices) & channel_indices >= 1);

[row_start, row_end] = timeWindowIndices(time, time_interval(1), time_interval(2));
if isempty(row_start)
    local_lfp = [];
    time_vector = [];
    cols = [];
    return;
end

lfpDims = lfp_size(lfp_file);
nCh = lfpDims(2);
channel_indices = channel_indices(channel_indices <= nCh);

mg = false(1, nCh);
if ~isempty(mean_group_ch) && any(mean_group_ch(:))
    rawMg = mean_group_ch(:);
    if islogical(rawMg)
        n = min(numel(rawMg), nCh);
        mg(1:n) = rawMg(1:n);
    else
        idx = round(rawMg(isfinite(rawMg) & rawMg >= 1 & rawMg <= nCh));
        mg(idx) = true;
    end
end

cols = unique([channel_indices, find(mg)], 'stable');
if isempty(cols)
    local_lfp = [];
    time_vector = [];
    cols = [];
    return;
end

local_lfp = readLfpSlice(lfp_file, row_start, row_end, cols);
if any(mg)
    meanLocal = ismember(cols, find(mg));
    local_lfp(:, meanLocal) = local_lfp(:, meanLocal) - mean(local_lfp(:, meanLocal), 2);
end
time_vector = time(row_start:row_end);

end

function block = readLfpSlice(lfp_file, row_start, row_end, cols)
rows = row_start:row_end;
cols = cols(:)';
if ~isa(lfp_file, 'matlab.io.MatFile')
    block = lfp_file.lfp(rows, cols);
    return
end

if isscalar(cols)
    block = lfp_file.lfp(rows, cols);
    return
end

d = diff(cols);
if all(d == d(1))
    block = lfp_file.lfp(rows, cols(1):d(1):cols(end));
    return
end

colRange = min(cols):max(cols);
wide = lfp_file.lfp(rows, colRange);
[~, pick] = ismember(cols, colRange);
block = wide(:, pick);
end
