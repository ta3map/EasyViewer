function [tStamp, ampl, shape] = detectMUAzav(data, hd, mua_std_coef, remove_ttl_artifact)

    raw_Fs = 1 / (hd.si * 1e-6);
    si = hd.si * 1e-6;
    dataFlt = ZavFilter(data, raw_Fs, 'high', 300, 2);
    if (raw_Fs / 2.001) > 4000
        dataFlt = ZavFilter(dataFlt, raw_Fs, 'low', 4000, 2);
    end

    lfpVar = CalcMinVar(dataFlt, si, data, 1);
    thrshld = -mua_std_coef * lfpVar;
    spks1 = find(dataFlt < thrshld);
    spks1((spks1 <= 1) | (spks1 >= numel(dataFlt))) = [];

    spk = zeros(numel(spks1), 1);
    z = 1;
    interrupts = find(diff(spks1) > 1);
    t1 = 1;
    for t = 1:numel(interrupts)
        jj = (spks1(t1) - 1):(spks1(interrupts(t)) + 1);
        mins = ZavFindMins(dataFlt(jj));
        spk(z:(z + numel(mins) - 1)) = mins + jj(1) - 1;
        z = z + numel(mins);
        t1 = interrupts(t) + 1;
    end
    if (t1 <= numel(spks1))
        mins = ZavFindMins(dataFlt((spks1(t1) - 1):(spks1(end) + 1)));
        spk(z:(z + numel(mins) - 1)) = mins + spks1(t1) - 2;
        z = z + numel(mins);
    end
    spk(z:end) = [];
    ampl = dataFlt(spk);

    numPoints = numel(data);
    Time = 1e3 * ((0:numPoints - 1) / raw_Fs);

    if remove_ttl_artifact
        if isfield(hd, "inTTL_timestamps") && ~isempty(hd.inTTL_timestamps)
            ttl_window = 200;
            ttl_ticks = hd.inTTL_timestamps.t(:, 1) / hd.fADCSampleInterval;
            for ttl1 = ttl_ticks'
                cond = spk > ttl1 - ttl_window & spk < ttl1 + ttl_window & ampl > -10 * lfpVar;
                spk(cond) = [];
                ampl(cond) = [];
            end
        end
    end

    tStamp = np_flatten(Time(spk))';
    shape = [];
end
