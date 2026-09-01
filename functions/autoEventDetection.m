function [events_detected, Trace_out, time_res, amplitudes_detected, widths_detected, channels_detected, metadata_detected, prominences_detected, indices_detected, wasCanceled] = autoEventDetection(params)
    global Fs time newFs lfp_file wb filterSettings filter_avaliable mean_group_ch
    global stims_exist stims art_rem_settings autoDetectionAccum

    wasCanceled = false;
    fprintf('Please wait...\n');

    if isempty(wb) || ~isvalid(wb)
        wb = createCancelableWaitbar(0, 'Initializing...', 'Event Detection');
    else
        setappdata(wb, 'canceling', 0);
    end
    drawnow;
    if cancelDetectionIfRequested(wb)
        wasCanceled = true;
        [events_detected, Trace_out, time_res, amplitudes_detected, widths_detected, channels_detected, metadata_detected, prominences_detected, indices_detected] = emptyDetectionOutputs();
        closeDetectionWaitbar(wb, wasCanceled);
        return;
    end

    DetectionType = params.DetectionType;
    MinPeakProminence = params.MinPeakProminence;
    ChPos = params.ChPos;
    ChNeg = params.ChNeg;
    MinPeakDistance = params.MinPeakDistance;
    detect = params.detect;

    if ~detect
        [Trace_out, time_res, wasCanceled] = previewDetectionTrace(params);
        autoDetectionAccum = struct('trace', Trace_out(:), 'time_res', time_res(:), ...
            'peakTimes', [], 'peaks', [], 'widths', [], 'prominences', []);
        events_detected = [];
        amplitudes_detected = [];
        widths_detected = [];
        channels_detected = [];
        metadata_detected = [];
        prominences_detected = [];
        indices_detected = [];
        closeDetectionWaitbar(wb, wasCanceled);
        return;
    end

    max_peak_width = params.max_peak_width;
    UseTimeRange = false;
    StartTime = time(1);
    EndTime = time(end);
    if isfield(params, 'UseTimeRange')
        UseTimeRange = params.UseTimeRange;
    end
    if isfield(params, 'StartTime')
        StartTime = params.StartTime;
    end
    if isfield(params, 'EndTime')
        EndTime = params.EndTime;
    end

    SearchAroundStimuli = false;
    SearchWindow = 0;
    SearchAroundDirection = 2;
    if isfield(params, 'SearchAroundStimuli')
        SearchAroundStimuli = params.SearchAroundStimuli;
    end
    if isfield(params, 'SearchWindow')
        SearchWindow = params.SearchWindow;
    end
    if isfield(params, 'SearchAroundDirection')
        SearchAroundDirection = params.SearchAroundDirection;
    end
    isTwoSided = (SearchAroundDirection == 1);
    stimSearch = SearchAroundStimuli && stims_exist && ~isempty(stims) && ~UseTimeRange;

    chunks = planDetectionTimeChunks(time, UseTimeRange, StartTime, EndTime, Fs, MinPeakDistance, art_rem_settings, stims_exist);
    if isempty(chunks)
        showEmptyTraceError();
    end

    nChunks = numel(chunks);
    autoDetectionAccum.mergedPeakTimes = [];
    autoDetectionAccum.mergedPeaks = [];
    autoDetectionAccum.mergedWidths = [];
    autoDetectionAccum.mergedProminences = [];
    workTraceParts = cell(nChunks, 1);
    workTimeParts = cell(nChunks, 1);
    nWorkParts = 0;
    hasChunkData = false;

    for k = 1:nChunks
        drawnow;
        if cancelDetectionIfRequested(wb)
            wasCanceled = true;
            break;
        end

        [coreTrace, coreTime] = processDetectionChunk(chunks(k), params);
        coreTrace = finalizeDetectionTrace(coreTrace);
        hasChunkData = hasChunkData || ~isempty(coreTrace);

        if stimSearch
            nWorkParts = nWorkParts + 1;
            workTraceParts{nWorkParts} = coreTrace(:);
            workTimeParts{nWorkParts} = coreTime(:);
            setDetectionWaitbar(wb, k / nChunks, sprintf('Chunk %d/%d', k, nChunks));
        end

        if ~stimSearch
            appendChunkFindpeaks(coreTrace, coreTime, MinPeakProminence, MinPeakDistance, max_peak_width);
            reportDetectionProgress(params, wb, k / nChunks, sprintf('Chunk %d/%d', k, nChunks), ...
                autoDetectionAccum.mergedPeakTimes);
        end

        drawnow;
        if cancelDetectionIfRequested(wb)
            wasCanceled = true;
            break;
        end
    end

    if ~hasChunkData && ~wasCanceled
        showEmptyTraceError();
    end

    Trace_out = [];
    time_res = [];

    if stimSearch
        workTrace = cell2mat(workTraceParts(1:nWorkParts));
        workTime = cell2mat(workTimeParts(1:nWorkParts));
        [events_detected, amplitudes_detected, widths_detected, prominences, stimCanceled] = ...
            detectEventsAroundStimuli(workTrace, workTime, stims, SearchWindow, isTwoSided, ...
            MinPeakProminence, MinPeakDistance, max_peak_width, wb, params);
        wasCanceled = wasCanceled || stimCanceled;
    else
        [events_detected, amplitudes_detected, widths_detected, prominences] = ...
            mergedPeaksFromAccum(MinPeakDistance);
    end

    if UseTimeRange && ~isempty(events_detected)
        time_mask = events_detected >= StartTime & events_detected <= EndTime;
        events_detected = events_detected(time_mask);
        amplitudes_detected = amplitudes_detected(time_mask);
        widths_detected = widths_detected(time_mask);
        prominences = prominences(time_mask);
    end

    [channels_detected, metadata_detected, prominences_detected, indices_detected] = ...
        buildDetectionMetadata(events_detected, amplitudes_detected, prominences, params);

    closeDetectionWaitbar(wb, wasCanceled);
end

function appendChunkFindpeaks(coreTrace, coreTime, minPeakProminence, minPeakDistance, maxPeakWidth)
    global autoDetectionAccum

    if numel(coreTrace) < 2
        return;
    end
    timeSpan = coreTime(end) - coreTime(1);
    if timeSpan <= minPeakDistance
        return;
    end

    findpeaksParams = {'MinPeakDistance', minPeakDistance, 'WidthReference', 'halfheight', 'MinPeakHeight', minPeakProminence};
    [peaks, peakTimes, w, prom] = findpeaks(coreTrace, coreTime, findpeaksParams{:});
    if isempty(peakTimes)
        return;
    end
    if ~isempty(w)
        keep = w <= maxPeakWidth;
        peakTimes = peakTimes(keep);
        peaks = peaks(keep);
        w = w(keep);
        prom = prom(keep);
    end
    [autoDetectionAccum.mergedPeakTimes, autoDetectionAccum.mergedPeaks, autoDetectionAccum.mergedWidths, autoDetectionAccum.mergedProminences] = ...
        mergePeaksAppendTail(autoDetectionAccum.mergedPeakTimes, autoDetectionAccum.mergedPeaks, ...
        autoDetectionAccum.mergedWidths, autoDetectionAccum.mergedProminences, ...
        peakTimes, peaks, w, prom, minPeakDistance);
end

function [events, amplitudes, widths, prominences] = mergedPeaksFromAccum(~)
    global autoDetectionAccum

    events = autoDetectionAccum.mergedPeakTimes;
    amplitudes = autoDetectionAccum.mergedPeaks;
    widths = autoDetectionAccum.mergedWidths;
    prominences = autoDetectionAccum.mergedProminences;
end

function [events_detected, Trace_out, time_res, amplitudes_detected, widths_detected, channels_detected, metadata_detected, prominences_detected, indices_detected] = emptyDetectionOutputs()
    events_detected = [];
    Trace_out = [];
    time_res = [];
    amplitudes_detected = [];
    widths_detected = [];
    channels_detected = [];
    metadata_detected = [];
    prominences_detected = [];
    indices_detected = [];
end

function closeDetectionWaitbar(wb, wasCanceled)
    if wasCanceled
        fprintf('Event detection stopped by user.\n');
    else
        setDetectionWaitbar(wb, 1.0, 'Complete');
        fprintf('Events detected.\n');
    end
    if ~isempty(wb) && isvalid(wb)
        delete(wb);
    end
end

function setDetectionWaitbar(wb, frac, msg)
    if isempty(wb) || ~isvalid(wb)
        return;
    end
    waitbar(frac, wb, msg);
end

function reportDetectionProgress(params, wb, frac, baseMsg, events)
    events = filterEventsToTimeRange(params, events);
    nEv = numel(events);
    setDetectionWaitbar(wb, frac, sprintf('%s, %d events', baseMsg, nEv));
    drawnow;
    if ~isfield(params, 'onDetectionProgress')
        return;
    end
    cb = params.onDetectionProgress;
    if isa(cb, 'function_handle')
        cb(events);
    end
end

function events = filterEventsToTimeRange(params, events)
    useTimeRange = isfield(params, 'UseTimeRange') && params.UseTimeRange;
    if ~useTimeRange || isempty(events)
        return;
    end
    events = events(events >= params.StartTime & events <= params.EndTime);
end

function chunks = planDetectionTimeChunks(time, useTimeRange, startTime, endTime, Fs, minPeakDistance, artRemSettings, stimsExist)
    DETECTION_CHUNK_SEC = 30;

    if useTimeRange
        t1 = startTime;
        t2 = endTime;
    else
        t1 = time(1);
        t2 = time(end);
    end

    [rowStart, rowEnd] = timeWindowIndices(time, t1, t2);
    if isempty(rowStart)
        chunks = struct('coreStart', {}, 'coreEnd', {}, 'padStart', {}, 'padEnd', {});
        return;
    end

    nSamples = numel(time);
    winR = 0;
    if stimsExist && isstruct(artRemSettings) && isfield(artRemSettings, 'artifact_window_ms') ...
            && artRemSettings.artifact_window_ms > 0
        winR = round(artRemSettings.artifact_window_ms * (Fs / 1000));
    end

    peakPad = max(1, round(minPeakDistance * Fs));
    chunkSamples = max(1, round(DETECTION_CHUNK_SEC * Fs));
    chunks = struct('coreStart', {}, 'coreEnd', {}, 'padStart', {}, 'padEnd', {});

    coreStart = rowStart;
    while coreStart <= rowEnd
        coreEnd = min(coreStart + chunkSamples - 1, rowEnd);
        coreLen = coreEnd - coreStart + 1;
        filterPad = max(round(coreLen * 0.10), 1);
        pad = max([filterPad, winR, peakPad]);
        padStart = max(1, coreStart - pad);
        padEnd = min(nSamples, coreEnd + pad);
        c = struct('coreStart', coreStart, 'coreEnd', coreEnd, 'padStart', padStart, 'padEnd', padEnd);
        chunks(end + 1) = c; %#ok<AGROW>
        coreStart = coreEnd + 1;
    end
end

function [coreTrace, coreTime] = processDetectionChunk(chunk, params)
    global Fs time newFs lfp_file filterSettings filter_avaliable mean_group_ch
    global stims_exist stims art_rem_settings

    DetectionType = params.DetectionType;
    ChPos = params.ChPos;
    ChNeg = params.ChNeg;

    time_interval = [time(chunk.padStart), time(chunk.padEnd)];
    dataParams = struct( ...
        'remove_artifact', stims_exist && ~isempty(stims) && art_rem_settings.artifact_window_ms > 0, ...
        'artifact_window_ms', art_rem_settings.artifact_window_ms, ...
        'artifact_interp_method', art_rem_settings.interp_method, ...
        'stims', stims, 'Fs', Fs, 'mean_group_ch', mean_group_ch);

    rawFrq = Fs;
    lfpFrq = round(newFs);

    switch DetectionType
        case 'one channel positive'
            [posRaw, timePad] = getSignalDataForInterval(lfp_file, time, ChPos, time_interval, dataParams);
            if isempty(posRaw)
                coreTrace = [];
                coreTime = [];
                return;
            end
            detOpts = struct('profile', 'detection', 'filter_enabled', filter_avaliable(ChPos), ...
                'filterSettings', filterSettings, 'newFs', newFs, 'Fs', rawFrq);
            [posRaw, timeExt] = processSignalChannels(posRaw, timePad, detOpts);
            traceExt = posRaw(:)';
        case 'one channel negative'
            [negRaw, timePad] = getSignalDataForInterval(lfp_file, time, ChNeg, time_interval, dataParams);
            if isempty(negRaw)
                coreTrace = [];
                coreTime = [];
                return;
            end
            detOpts = struct('profile', 'detection', 'filter_enabled', filter_avaliable(ChNeg), ...
                'filterSettings', filterSettings, 'newFs', newFs, 'Fs', rawFrq);
            [negRaw, timeExt] = processSignalChannels(negRaw, timePad, detOpts);
            traceExt = -negRaw(:)';
        otherwise
            [posRaw, ~] = getSignalDataForInterval(lfp_file, time, ChPos, time_interval, dataParams);
            [negRaw, ~] = getSignalDataForInterval(lfp_file, time, ChNeg, time_interval, dataParams);
            if isempty(posRaw) || isempty(negRaw)
                coreTrace = [];
                coreTime = [];
                return;
            end
            posRaw = filterDetectionChannel(posRaw, ChPos, filterSettings, filter_avaliable, newFs);
            negRaw = filterDetectionChannel(negRaw, ChNeg, filterSettings, filter_avaliable, newFs);
            traceExt = buildDetectionTraceSegment(posRaw, negRaw, DetectionType, lfpFrq, rawFrq);
            timeExt = linspace(time(chunk.padStart), time(chunk.padEnd), numel(traceExt));
    end

    timeExt = timeExt(:)';
    if numel(timeExt) ~= numel(traceExt)
        timeExt = linspace(time(chunk.padStart), time(chunk.padEnd), numel(traceExt));
    end
    coreT1 = time(chunk.coreStart);
    coreT2 = time(chunk.coreEnd);
    coreMask = timeExt >= coreT1 & timeExt <= coreT2;
    coreTrace = traceExt(coreMask);
    coreTime = timeExt(coreMask);
end

function y = filterDetectionChannel(raw, ch, filterSettings, filter_avaliable, newFs)
    y = raw;
    if filter_avaliable(ch)
        y = applyFilter(raw, filterSettings, newFs);
    end
end

function trace = buildDetectionTraceSegment(posRaw, negRaw, detectionType, lfpFrq, rawFrq)
    posTrace = resample1(posRaw, lfpFrq, rawFrq)';
    negTrace = resample1(negRaw, lfpFrq, rawFrq)';
    switch detectionType
        case 'two channels difference'
            trace = posTrace - negTrace;
        case 'two channels multiplied'
            trace = -(negTrace .* posTrace);
    end
end

function trace = finalizeDetectionTrace(trace)
    trace(isnan(trace)) = nanmean(trace);
    trace = trace - mean(trace);
    trace = np_flatten(trace);
end

function [events, amplitudes, widths, prominences, wasCanceled] = detectEventsAroundStimuli(trace, timeRes, stims, searchWindow, isTwoSided, minPeakProminence, minPeakDistance, maxPeakWidth, wb, params)
    wasCanceled = false;
    allPeakTimes = [];
    allPeaks = [];
    allWidths = [];
    allProminences = [];
    mpdWarningShown = false;
    numStims = numel(stims);

    reportDetectionProgress(params, wb, 0.65, sprintf('Detecting around %d stimuli', numStims), []);

    for stimIdx = 1:numStims
        drawnow;
        if cancelDetectionIfRequested(wb)
            wasCanceled = true;
            break;
        end

        stim = stims(stimIdx);
        windowStart = stim - searchWindow * isTwoSided;
        windowEnd = stim + searchWindow;
        windowMask = timeRes >= windowStart & timeRes <= windowEnd;
        if ~any(windowMask)
            continue;
        end

        traceWindow = trace(windowMask);
        timeWindow = timeRes(windowMask);
        if numel(traceWindow) < 2
            continue;
        end

        timeSpanWindow = timeWindow(end) - timeWindow(1);
        if minPeakDistance >= timeSpanWindow
            if ~mpdWarningShown
                suggested = max(0, timeSpanWindow - eps(timeSpanWindow));
                msg = sprintf(['MinPeakDistance is too large for the current search window.\n\n' ...
                    'MATLAB requires: MinPeakDistance < (max(time) - min(time))\n' ...
                    'Current MinPeakDistance: %.6f s\n' ...
                    'Available window time span: %.6f s\n' ...
                    'Suggested maximum value: %.6f s\n\n' ...
                    'Please decrease "Minimal Time Between Peaks" in the GUI and press Detect again.'], ...
                    minPeakDistance, timeSpanWindow, suggested);
                uiwait(msgbox(msg, 'MinPeakDistance too large', 'warn', 'modal'));
                mpdWarningShown = true;
            end
            break;
        end

        findpeaksParams = {'MinPeakDistance', minPeakDistance, 'WidthReference', 'halfheight', 'MinPeakHeight', minPeakProminence};
        [peaksWindow, peakTimesWindow, widthsWindow, prominencesWindow] = ...
            findpeaks(traceWindow, timeWindow, findpeaksParams{:});
        if ~isempty(widthsWindow)
            wideMask = widthsWindow <= maxPeakWidth;
            peaksWindow = peaksWindow(wideMask);
            peakTimesWindow = peakTimesWindow(wideMask);
            widthsWindow = widthsWindow(wideMask);
            prominencesWindow = prominencesWindow(wideMask);
        end
        if ~isempty(peakTimesWindow)
            allPeakTimes = [allPeakTimes; peakTimesWindow(:)]; %#ok<AGROW>
            allPeaks = [allPeaks; peaksWindow(:)]; %#ok<AGROW>
            allWidths = [allWidths; widthsWindow(:)]; %#ok<AGROW>
            allProminences = [allProminences; prominencesWindow(:)]; %#ok<AGROW>
        end

        [evSoFar, ~, ~, ~] = mergePeaksByMinDistance(allPeakTimes, allPeaks, allWidths, allProminences, minPeakDistance);
        reportDetectionProgress(params, wb, 0.65 + 0.25 * (stimIdx / numStims), ...
            sprintf('Stimulus %d/%d', stimIdx, numStims), evSoFar);
    end

    [allPeakTimes, allPeaks, allWidths, allProminences] = ...
        mergePeaksByMinDistance(allPeakTimes, allPeaks, allWidths, allProminences, minPeakDistance);
    events = allPeakTimes;
    amplitudes = allPeaks;
    widths = allWidths;
    prominences = allProminences;
end

function tf = cancelDetectionIfRequested(wb)
    drawnow;
    tf = isWaitbarCanceled(wb);
end

function showEmptyTraceError()
    errorMsg = sprintf(['Error: No data available for event detection.\n\n' ...
        'Possible causes:\n' ...
        '1. Time range (Use time range) contains no data\n' ...
        '2. Selected channels contain no data\n' ...
        '3. Data filtering resulted in empty result\n\n' ...
        'Recommendations:\n' ...
        '- Check time range settings\n' ...
        '- Ensure selected channels exist\n' ...
        '- Disable filters or time range and try again']);
    uiwait(msgbox(errorMsg, 'Event Detection Error', 'error', 'modal'));
    error('Trace_out is empty - no data available for detection');
end

function [Trace_out, time_res, wasCanceled] = previewDetectionTrace(params)
    global Fs time wb art_rem_settings stims_exist

    wasCanceled = false;
    UseTimeRange = false;
    StartTime = time(1);
    EndTime = time(end);
    if isfield(params, 'UseTimeRange')
        UseTimeRange = params.UseTimeRange;
    end
    if isfield(params, 'StartTime')
        StartTime = params.StartTime;
    end
    if isfield(params, 'EndTime')
        EndTime = params.EndTime;
    end

    chunks = planDetectionTimeChunks(time, UseTimeRange, StartTime, EndTime, Fs, ...
        params.MinPeakDistance, art_rem_settings, stims_exist);
    if isempty(chunks)
        Trace_out = [];
        time_res = [];
        return;
    end

    Trace_out = [];
    time_res = [];
    nChunks = numel(chunks);
    traceParts = cell(nChunks, 1);
    timeParts = cell(nChunks, 1);

    for k = 1:nChunks
        setDetectionWaitbar(wb, k / nChunks, sprintf('Preview chunk %d/%d', k, nChunks));
        drawnow;
        if cancelDetectionIfRequested(wb)
            wasCanceled = true;
            Trace_out = [];
            time_res = [];
            return;
        end

        [coreTrace, coreTime] = processDetectionChunk(chunks(k), params);
        traceParts{k} = coreTrace(:);
        timeParts{k} = coreTime(:);
    end

    Trace_out = cell2mat(traceParts);
    time_res = cell2mat(timeParts);

    if isempty(Trace_out)
        return;
    end

    Trace_out = finalizeDetectionTrace(Trace_out);
end

function [channels_detected, metadata_detected, prominences_detected, indices_detected] = buildDetectionMetadata(events_detected, amplitudes_detected, prominences, params)
    global time

    DetectionType = params.DetectionType;
    ChPos = params.ChPos;
    ChNeg = params.ChNeg;
    nEv = numel(events_detected);
    if nEv == 0
        channels_detected = zeros(0, 1);
        metadata_detected = struct('source', {}, 'method', {}, 'data_type', {}, 'polarity', {}, 'prominence', {}, 'detection_params', {});
        prominences_detected = [];
        indices_detected = [];
        return;
    end

    prominences_detected = prominences(:);
    indices_detected = ClosestIndex(events_detected, time, true);

    if strcmp(DetectionType, 'two channels difference') || strcmp(DetectionType, 'two channels multiplied')
        channels_detected = repmat([ChPos, ChNeg], nEv, 1);
    elseif strcmp(DetectionType, 'one channel positive')
        channels_detected = repmat(ChPos, nEv, 1);
    elseif strcmp(DetectionType, 'one channel negative')
        channels_detected = repmat(ChNeg, nEv, 1);
    else
        channels_detected = ones(nEv, 1);
    end

    metadata_detected = repmat(struct(...
        'source', 'auto', ...
        'method', 'peaks', ...
        'data_type', 'LFP', ...
        'polarity', DetectionType, ...
        'prominence', NaN, ...
        'detection_params', struct(...
            'MinPeakProminence', params.MinPeakProminence, ...
            'MinPeakDistance', params.MinPeakDistance, ...
            'MaxPeakWidth', params.max_peak_width ...
        ) ...
    ), nEv, 1);

    for i = 1:nEv
        metadata_detected(i).prominence = prominences_detected(i);
    end
end
