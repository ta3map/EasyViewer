function [meanData, originalEventsData, wasCanceled, nProcessed, processedTimePoints] = accumulateMeanEventWindows(params)
%ACCUMULATEMEANEVENTWINDOWS Per-event lazy read + accumulate mean trace.

wasCanceled = false;
nProcessed = 0;
processedTimePoints = [];

if ~isfield(params, 'lfp_file') || isempty(params.lfp_file)
    error('accumulateMeanEventWindows:params.lfp_file', 'params.lfp_file is required.');
end

timePoints = params.timePoints;
meanWindow = params.meanWindow;
Fs = params.Fs;
time = params.time;
channelSettings = params.channelSettings;
ch_inxs = find([channelSettings{:, 2}]);
ch_inxs = ch_inxs(:)';
params.ch_inxs = ch_inxs;
read_ch = ch_inxs;
mean_group_ch = params.mean_group_ch;
removeBaseline = isfield(params, 'removeBaseline') && logical(params.removeBaseline);

winLen = round(meanWindow * Fs);
halfWin = round(meanWindow * Fs / 2);
nTime = numel(time);
numEvents = numel(timePoints);
nChOut = numel(ch_inxs);
meanData = zeros(winLen, nChOut);
originalEventsData = {};

scalingCoefficients = [channelSettings{:, 3}];
chScale = reshape(scalingCoefficients(ch_inxs), 1, []);

externalWb = isfield(params, 'wb') && ~isempty(params.wb) && isvalid(params.wb);
showWaitbar = ~isfield(params, 'showWaitbar') || logical(params.showWaitbar);
wb = [];
if externalWb
    wb = params.wb;
    setappdata(wb, 'canceling', 0);
    showWaitbar = true;
end
if showWaitbar && isempty(wb)
    wb = createCancelableWaitbar(0, 'Processing events...', 'Calculating mean events');
end
fracLo = 0;
fracHi = 1;
if isfield(params, 'progress') && isstruct(params.progress)
    if isfield(params.progress, 'fracLo')
        fracLo = params.progress.fracLo;
    end
    if isfield(params.progress, 'fracHi')
        fracHi = params.progress.fracHi;
    end
end

for i = 1:numEvents
    drawnow;
    if isWaitbarCanceled(wb)
        wasCanceled = true;
        break;
    end

    eventIdx = round(timePoints(i) * Fs);
    idealStart = eventIdx - halfWin;
    windowStart = max(idealStart, 1);
    windowEnd = min(windowStart + winLen - 1, nTime);
    time_interval = [time(windowStart), time(windowEnd)];

    [local_lfp, time_vec, cols] = readLfpChannelsForInterval( ...
        params.lfp_file, time, time_interval, read_ch, mean_group_ch);
    if isempty(local_lfp)
        updateEventWaitbar(wb, showWaitbar, i, numEvents, fracLo, fracHi);
        continue;
    end

    [~, colIdx] = ismember(ch_inxs(:), cols);
    eventDataRaw = zeros(size(local_lfp, 1), nChOut);
    present = colIdx > 0;
    eventDataRaw(:, present) = local_lfp(:, colIdx(present));

    eventDataRaw = processMeanEventWindow(eventDataRaw, time_vec, params);

    if removeBaseline
        eventDataProcessed = eventDataRaw - nanmedian(eventDataRaw);
    else
        eventDataProcessed = eventDataRaw;
    end

    destFrom = windowStart - idealStart + 1;
    destTo = destFrom + size(eventDataProcessed, 1) - 1;
    meanData(destFrom:destTo, :) = meanData(destFrom:destTo, :) + eventDataProcessed;

    nProcessed = nProcessed + 1;
    processedTimePoints(nProcessed) = timePoints(i);
    eventDataScaled = eventDataProcessed .* chScale;
    originalEventsData{end + 1} = eventDataScaled; %#ok<AGROW>

    updateEventWaitbar(wb, showWaitbar, i, numEvents, fracLo, fracHi);
end

if nProcessed > 0
    meanData = meanData / nProcessed;
end

if showWaitbar && ~isempty(wb) && ~externalWb && isvalid(wb)
    delete(wb);
end

end

function data = processMeanEventWindow(data, time_vec, params)
if isfield(params, 'remove_artifact') && params.remove_artifact ...
        && isfield(params, 'stims') && ~isempty(params.stims) ...
        && isfield(params, 'artifact_window_ms')
    win_r = round(params.artifact_window_ms * (params.Fs / 1000));
    stims_in = params.stims(params.stims >= time_vec(1) & params.stims < time_vec(end));
    if ~isempty(stims_in)
        data = removeStimArtifact(data, stims_in, time_vec, win_r, params.artifact_interp_method);
    end
end

if isfield(params, 'channel_index_original') && size(data, 2) == 1 ...
        && isfield(params, 'filter_enabled') && params.filter_enabled(params.channel_index_original)
    data = applyFilter(data, params.filterSettings, params.newFs);
    return;
end

if isfield(params, 'filter_enabled') && isfield(params, 'ch_inxs') ...
        && sum(params.filter_enabled(params.ch_inxs)) > 0
    ch_to_filter = params.filter_enabled(params.ch_inxs);
    data(:, ch_to_filter) = applyFilter(data(:, ch_to_filter), params.filterSettings, params.newFs);
end

end

function updateEventWaitbar(wb, showWaitbar, i, numEvents, fracLo, fracHi)
if ~showWaitbar || isempty(wb) || ~isvalid(wb)
    return;
end
frac = fracLo + (i / numEvents) * (fracHi - fracLo);
waitbar(frac, wb, sprintf('Reading event %d/%d', i, numEvents));
drawnow;
end
