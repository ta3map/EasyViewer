function [lagTimes, crossCorr] = eventCrossCorrelationFromBins(ev1, ev2, binSize, windowSize, normalize)
%EVENTCROSSCORRELATIONFROMBINS Event CCG via histcounts + xcorr.

    ev1 = ev1(:);
    ev2 = ev2(:);
    minTime = min([min(ev1), min(ev2)]);
    maxTime = max([max(ev1), max(ev2)]);
    maxTimeForEdges = max(maxTime, minTime + binSize);
    edges = minTime:binSize:maxTimeForEdges;
    eventHist1 = histcounts(ev1, edges, 'Normalization', 'count');
    eventHist2 = histcounts(ev2, edges, 'Normalization', 'count');
    if normalize
        [crossCorrRaw, lags] = xcorr(eventHist1, eventHist2, 'normalized');
    else
        [crossCorrRaw, lags] = xcorr(eventHist1, eventHist2);
    end
    lagTimes = lags * binSize;
    validIndices = abs(lagTimes) <= windowSize / 2;
    lagTimes = lagTimes(validIndices);
    crossCorr = crossCorrRaw(validIndices);
end
