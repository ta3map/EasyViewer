function spks = sortSpikeTimestamps(spks)
%SORTSPIKETIMESTAMPS Pre-sort spike times per channel for window queries.

for k = 1:numel(spks)
    if ~isstruct(spks(k)) || ~isfield(spks(k), 'tStamp') || isempty(spks(k).tStamp)
        spks(k).tStampSorted = zeros(0, 1);
        spks(k).amplSorted = zeros(0, 1);
        continue;
    end
    nTs = numel(spks(k).tStamp);
    nAm = numel(spks(k).ampl);
    if nAm ~= nTs
        spks(k).tStampSorted = zeros(0, 1);
        spks(k).amplSorted = zeros(0, 1);
        continue;
    end
    [spks(k).tStampSorted, ord] = sort(spks(k).tStamp(:));
    spks(k).amplSorted = spks(k).ampl(ord);
end

end
