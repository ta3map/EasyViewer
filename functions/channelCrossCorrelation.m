function result = channelCrossCorrelation(lfp, Fs, opts)
%CHANNELCROSSCORRELATION Cross-correlation of two channel-group sums.
%
%   opts.chA, opts.chB          - channel index vectors
%   opts.invertA, opts.invertB  - logical
%   opts.preprocess             - 1 none, 2 detrend, 3 demean, 4 median baseline
%   opts.normalize              - logical
%   opts.windowSize_sec         - half-window trim uses abs(lag) <= window/2
%   opts.resultProcessing       - 1 none, 2 smooth, 3 peak
%   opts.useEvents              - logical
%   opts.events                 - event times (sec), if useEvents
%   opts.eventWindow_sec        - window around each event
%   opts.useTimeRange           - logical
%   opts.startTime, opts.endTime
%   opts.time                   - full time vector (for time range)

    result = struct('lagTimes', [], 'crossCorr', [], 'peakLag', [], 'peakValue', [], 'ok', false, 'message', '');

    sumSignal1 = nansum(lfp(:, opts.chA), 2);
    sumSignal2 = nansum(lfp(:, opts.chB), 2);

    if opts.invertA
        sumSignal1 = -sumSignal1;
    end
    if opts.invertB
        sumSignal2 = -sumSignal2;
    end

    switch opts.preprocess
        case 2
            sumSignal1 = detrend(sumSignal1);
            sumSignal2 = detrend(sumSignal2);
        case 3
            sumSignal1 = sumSignal1 - nanmean(sumSignal1);
            sumSignal2 = sumSignal2 - nanmean(sumSignal2);
        case 4
            sumSignal1 = sumSignal1 - nanmedian(sumSignal1);
            sumSignal2 = sumSignal2 - nanmedian(sumSignal2);
    end

    if opts.useEvents
        if isempty(opts.events)
            result.message = 'Events are not loaded.';
            return
        end
        eventWindow = opts.eventWindow_sec;
        eventSegments1 = [];
        eventSegments2 = [];
        for i = 1:numel(opts.events)
            eventIdx = round(opts.events(i) * Fs);
            windowStart = max(eventIdx - round(eventWindow * Fs / 2), 1);
            windowEnd = min(windowStart + round(eventWindow * Fs) - 1, size(lfp, 1));
            if windowEnd <= size(lfp, 1) && windowStart < windowEnd
                eventSegments1 = [eventSegments1; sumSignal1(windowStart:windowEnd)]; %#ok<AGROW>
                eventSegments2 = [eventSegments2; sumSignal2(windowStart:windowEnd)]; %#ok<AGROW>
            end
        end
        if isempty(eventSegments1)
            result.message = 'No valid event windows found.';
            return
        end
        sumSignal1 = eventSegments1;
        sumSignal2 = eventSegments2;
        timeFiltered = (0:numel(sumSignal1)-1)' / Fs;
    elseif opts.useTimeRange
        timeIndices = opts.time >= opts.startTime & opts.time <= opts.endTime;
        sumSignal1 = sumSignal1(timeIndices);
        sumSignal2 = sumSignal2(timeIndices);
        timeFiltered = opts.time(timeIndices);
    else
        timeFiltered = opts.time;
    end

    sampleRate = 1 / (timeFiltered(2) - timeFiltered(1));
    if opts.normalize
        [crossCorr, lags] = xcorr(sumSignal1, sumSignal2, 'normalized');
    else
        [crossCorr, lags] = xcorr(sumSignal1, sumSignal2);
    end
    lagTimes = lags / sampleRate;

    windowSize = opts.windowSize_sec;
    validIndices = abs(lagTimes) <= windowSize / 2;
    lagTimes = lagTimes(validIndices);
    crossCorr = crossCorr(validIndices);

    peakLag = [];
    peakValue = [];
    switch opts.resultProcessing
        case 2
            winSamples = max(3, round(numel(crossCorr) * 0.05));
            crossCorr = smooth(crossCorr, winSamples);
        case 3
            [peakValue, peakIdx] = max(crossCorr);
            peakLag = lagTimes(peakIdx);
    end

    result.lagTimes = lagTimes;
    result.crossCorr = crossCorr;
    result.peakLag = peakLag;
    result.peakValue = peakValue;
    result.ok = true;
end
