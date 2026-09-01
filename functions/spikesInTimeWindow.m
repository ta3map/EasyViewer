function spk_sec = spikesInTimeWindow(chIdx, t1_sec, t2_sec, prg, lfpVarCh)
%SPIKESINTIMEWINDOW Spike times (seconds) in window passing amplitude threshold.

global spks

spk_sec = [];
if chIdx > numel(spks) || ~isstruct(spks(chIdx))
    return;
end
if ~isfield(spks(chIdx), 'tStampSorted') || isempty(spks(chIdx).tStampSorted)
    if ~isfield(spks(chIdx), 'tStamp') || ~isfield(spks(chIdx), 'ampl')
        return;
    end
    ii = abs(double(spks(chIdx).ampl)) >= (lfpVarCh * prg);
    spk = spks(chIdx).tStamp(ii) / 1000;
    spk_sec = spk(spk >= t1_sec & spk < t2_sec);
    return;
end

t1_ms = t1_sec * 1000;
t2_ms = t2_sec * 1000;
ts = spks(chIdx).tStampSorted;
i0 = find(ts >= t1_ms, 1, 'first');
i1 = find(ts < t2_ms, 1, 'last');
if isempty(i0) || isempty(i1)
    return;
end

amps = double(spks(chIdx).amplSorted(i0:i1));
mask = abs(amps) >= (lfpVarCh * prg);
spk_sec = ts(i0:i1);
spk_sec = spk_sec(mask) / 1000;

end
