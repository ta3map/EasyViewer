function [t0, t1] = defaultIntervalSecFromSpks(spks)
%DEFAULTINTERVALSECFROMSPKS Min/max spike time across channels (seconds).

    allMs = [];
    for k = 1:numel(spks)
        ts = spks(k).tStamp;
        if isempty(ts)
            continue
        end
        allMs = [allMs; double(ts(:))]; %#ok<AGROW>
    end
    t0 = min(allMs) / 1000;
    t1 = max(allMs) / 1000;
end
