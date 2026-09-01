function [peakTimes, peaks, widths, prominences] = mergePeaksByMinDistance(peakTimes, peaks, widths, prominences, minPeakDistance)
%MERGEPEAKSBYMINDISTANCE Sort peaks and drop duplicates closer than minPeakDistance.

peakTimes = peakTimes(:);
peaks = peaks(:);
widths = widths(:);
prominences = prominences(:);

if isempty(peakTimes)
    return;
end

[peakTimes, sortIdx] = sort(peakTimes);
peaks = peaks(sortIdx);
widths = widths(sortIdx);
prominences = prominences(sortIdx);

keep = true(size(peakTimes));
for i = 2:numel(peakTimes)
    if (peakTimes(i) - peakTimes(i - 1)) < minPeakDistance
        keep(i) = false;
    end
end

peakTimes = peakTimes(keep);
peaks = peaks(keep);
widths = widths(keep);
prominences = prominences(keep);

end
