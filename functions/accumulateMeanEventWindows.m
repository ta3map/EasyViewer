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
    % Идеальное окно события: idealStart ... idealStart+winLen-1.
    % Обрезаем его по границам записи, но сохраняем положение внутри буфера
    % усреднения относительно idealStart (иначе левая граница "уезжает" и
    % destTo выходит за размер meanData для событий в начале записи).
    windowStart = max(idealStart, 1);
    windowEnd = min(idealStart + winLen - 1, nTime);
    if windowEnd < windowStart
        updateEventWaitbar(wb, showWaitbar, i, numEvents, fracLo, fracHi);
        continue;
    end
    % timeWindowIndices возвращает отсчёты t < t2, поэтому верхняя граница
    % интервала должна быть больше времени последнего нужного отсчёта,
    % чтобы включить сам отсчёт windowEnd.
    if windowEnd < nTime
        intervalEndTime = time(windowEnd + 1);
    elseif nTime > 1
        intervalEndTime = time(windowEnd) + (time(windowEnd) - time(windowEnd - 1));
    else
        intervalEndTime = time(windowEnd) + 1 / Fs;
    end
    time_interval = [time(windowStart), intervalEndTime];

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

    % time_vec — срез массива time, поэтому индекс первого считанного
    % отсчёта берём оттуда (защита от ошибок округления границ интервала).
    readStartIdx = find(time(:) == time_vec(1), 1, 'first');
    if isempty(readStartIdx)
        updateEventWaitbar(wb, showWaitbar, i, numEvents, fracLo, fracHi);
        continue;
    end
    destFrom = readStartIdx - idealStart + 1;
    destTo = destFrom + size(eventDataProcessed, 1) - 1;
    if destFrom < 1
        trim = 1 - destFrom;
        eventDataProcessed = eventDataProcessed(1 + trim:end, :);
        destFrom = 1;
    end
    if destTo > winLen
        eventDataProcessed = eventDataProcessed(1:winLen - destFrom + 1, :);
        destTo = winLen;
    end
    if destFrom > destTo
        updateEventWaitbar(wb, showWaitbar, i, numEvents, fracLo, fracHi);
        continue;
    end
    meanData(destFrom:destTo, :) = meanData(destFrom:destTo, :) + eventDataProcessed;

    nProcessed = nProcessed + 1;
    processedTimePoints(nProcessed) = timePoints(i);
    % Храним событие в полном размере окна: края, обрезанные границами
    % записи, заполняем NaN, чтобы длина совпадала с timeAxis (иначе
    % построение оригинальных трасс и детекция пиков падают из-за
    % несовпадения размеров).
    fullEventData = nan(winLen, nChOut);
    fullEventData(destFrom:destTo, :) = eventDataProcessed;
    eventDataScaled = fullEventData .* chScale;
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
