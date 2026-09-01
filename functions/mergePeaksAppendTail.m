function [peakTimes, peaks, widths, prominences] = mergePeaksAppendTail(peakTimes, peaks, widths, prominences, newTimes, newPeaks, newWidths, newProms, minPeakDistance)
%MERGEPEAKSAPPENDTAIL Append chunk peaks; re-merge only the overlapping tail.

newTimes = newTimes(:);
newPeaks = newPeaks(:);
newWidths = newWidths(:);
newProms = newProms(:);

if isempty(newTimes)
    return;
end

if isempty(peakTimes)
    [peakTimes, peaks, widths, prominences] = mergePeaksByMinDistance( ...
        newTimes, newPeaks, newWidths, newProms, minPeakDistance);
    return;
end

tailStart = find(peakTimes >= newTimes(1) - minPeakDistance, 1, 'first');
if isempty(tailStart)
    [newTimes, newPeaks, newWidths, newProms] = mergePeaksByMinDistance( ...
        newTimes, newPeaks, newWidths, newProms, minPeakDistance);
    peakTimes = [peakTimes; newTimes]; %#ok<AGROW>
    peaks = [peaks; newPeaks]; %#ok<AGROW>
    widths = [widths; newWidths]; %#ok<AGROW>
    prominences = [prominences; newProms]; %#ok<AGROW>
    return;
end

prefixTimes = peakTimes(1:tailStart - 1);
prefixPeaks = peaks(1:tailStart - 1);
prefixWidths = widths(1:tailStart - 1);
prefixProms = prominences(1:tailStart - 1);

[tailTimes, tailPeaks, tailWidths, tailProms] = mergePeaksByMinDistance( ...
    [peakTimes(tailStart:end); newTimes], ...
    [peaks(tailStart:end); newPeaks], ...
    [widths(tailStart:end); newWidths], ...
    [prominences(tailStart:end); newProms], ...
    minPeakDistance);

peakTimes = [prefixTimes; tailTimes]; %#ok<AGROW>
peaks = [prefixPeaks; tailPeaks]; %#ok<AGROW>
widths = [prefixWidths; tailWidths]; %#ok<AGROW>
prominences = [prefixProms; tailProms]; %#ok<AGROW>

end
