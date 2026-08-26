function tsec = mergeSpikeTimesSec(spks, chIdx, muaCoef, lfpVarVec)
%MERGESPIKETIMESSEC Merge spike times (sec) from selected channels with MUA threshold.

    tsec = [];
    for k = chIdx(:)'
        ts = spks(k).tStamp;
        if isempty(ts)
            continue
        end
        ts = double(ts(:));
        if isvector(lfpVarVec) && numel(lfpVarVec) >= k && isfield(spks(k), 'ampl') && ~isempty(spks(k).ampl)
            lv = double(lfpVarVec(k));
            if isfinite(muaCoef) && muaCoef >= 0 && isfinite(lv) && lv > 0
                a = double(spks(k).ampl(:));
                n = min(numel(ts), numel(a));
                ts = ts(1:n);
                a = a(1:n);
                ts = ts(abs(a) >= lv * muaCoef);
            end
        end
        if isempty(ts)
            continue
        end
        tsec = [tsec; ts / 1000]; %#ok<AGROW>
    end
    tsec = sort(tsec);
end
