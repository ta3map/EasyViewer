function [lags_sec, cc] = muaCrossCorrelationFromBins(tA_sec, tB_sec, binSize_sec, maxLag_sec, normalize, mode, modeParam)
% Cross-correlogram as a lag histogram of spike pairs (tB - tA), not xcorr on binned rates.
% mode 'interval': modeParam = [t0_sec, t1_sec] — only spikes inside [t0,t1].
% mode 'events': modeParam struct .centers_sec, .halfWindow_sec — per-event windows, median across events.

    assert(binSize_sec > 0 && maxLag_sec > 0, 'muaCrossCorrelationFromBins: binSize and maxLag must be positive.');

    lagEdges = (-maxLag_sec):binSize_sec:(maxLag_sec);
    if lagEdges(end) < maxLag_sec
        lagEdges(end + 1) = maxLag_sec;
    end
    lags_sec = (lagEdges(1:end - 1) + lagEdges(2:end)) / 2;

    tA = sort(tA_sec(:));
    tB = sort(tB_sec(:));

    switch mode
        case 'interval'
            t0 = modeParam(1);
            t1 = modeParam(2);
            assert(t1 > t0, 'muaCrossCorrelationFromBins: require t1 > t0.');
            tA = tA(tA >= t0 & tA <= t1);
            tB = tB(tB >= t0 & tB <= t1);
            counts = pairLagCounts(tA, tB, lagEdges, maxLag_sec);
        case 'events'
            centers = modeParam.centers_sec(:);
            halfW = modeParam.halfWindow_sec;
            assert(halfW > 0, 'muaCrossCorrelationFromBins: halfWindow must be positive.');
            assert(~isempty(centers), 'muaCrossCorrelationFromBins: no event centers.');
            nTr = numel(centers);
            nb = numel(lagEdges) - 1;
            stack = zeros(nTr, nb);
            for k = 1:nTr
                c = centers(k);
                tw0 = c - halfW;
                tw1 = c + halfW;
                tAw = tA(tA >= tw0 & tA <= tw1);
                tBw = tB(tB >= tw0 & tB <= tw1);
                stack(k, :) = pairLagCounts(tAw, tBw, lagEdges, maxLag_sec);
            end
            counts = median(stack, 1, 'omitnan');
        otherwise
            error('muaCrossCorrelationFromBins: unknown mode.');
    end

    cc = counts;
    if normalize
        s = sum(cc);
        cc = cc / max(s, eps);
    end
end

function counts = pairLagCounts(tA, tB, lagEdges, maxLag)
    counts = zeros(1, numel(lagEdges) - 1);
    nA = numel(tA);
    nB = numel(tB);
    if nA == 0 || nB == 0
        return;
    end
    ib_lo = 1;
    for ia = 1:nA
        ta = tA(ia);
        lo = ta - maxLag;
        hi = ta + maxLag;
        while ib_lo <= nB && tB(ib_lo) < lo
            ib_lo = ib_lo + 1;
        end
        if ib_lo > nB
            break;
        end
        ib = ib_lo;
        while ib <= nB && tB(ib) <= hi
            ib = ib + 1;
        end
        ib_hi = ib - 1;
        if ib_hi >= ib_lo
            dtv = tB(ib_lo:ib_hi) - ta;
            counts = counts + histcounts(dtv, lagEdges);
        end
    end
end
