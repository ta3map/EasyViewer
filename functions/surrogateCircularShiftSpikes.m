function tBs = surrogateCircularShiftSpikes(tB_sec, mode, modeParam)
%SURROGATECIRCULARSHIFTSPIKES Circular-shift spike times for surrogate CCG.
%
%   mode 'interval': modeParam = [t0, t1]
%   mode 'events':   modeParam.centers_sec, modeParam.halfWindow_sec

    tBs = tB_sec(:);
    if strcmp(mode, 'events')
        u0 = min(modeParam.centers_sec) - modeParam.halfWindow_sec;
        u1 = max(modeParam.centers_sec) + modeParam.halfWindow_sec;
    else
        u0 = modeParam(1);
        u1 = modeParam(2);
    end
    mask = tBs >= u0 & tBs <= u1;
    tv = tBs(mask);
    if numel(tv) < 2
        return
    end
    span = u1 - u0;
    off = rand * span;
    tv2 = mod(tv - u0 + off, span) + u0;
    tBs(mask) = sort(tv2);
end
