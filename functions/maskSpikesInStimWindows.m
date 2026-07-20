function spks = maskSpikesInStimWindows(spks, time, stim_inxs, win_r)
%MASKSPIKESINSTIMWINDOWS Remove spikes inside stimulus artifact windows.
%   SPKS = MASKSPIKESINSTIMWINDOWS(SPKS, TIME, STIM_INXS, WIN_R)
%   Removes spikes whose time (tStamp/1000, seconds) falls in
%   [time(stim-win_r), time(stim+win_r)) for any stimulus index.

if isempty(spks) || isempty(stim_inxs) || win_r == 0
    return;
end

nTime = numel(time);
stim_inxs = stim_inxs(:);
start_inxs = max(stim_inxs - win_r, 1);
end_inxs = min(stim_inxs + win_r, nTime);
tLo = time(start_inxs);
tHi = time(end_inxs);
tLo = tLo(:)';
tHi = tHi(:)';

for ch = 1:numel(spks)
    if isempty(spks(ch).tStamp)
        continue;
    end
    spk_sec = spks(ch).tStamp / 1000;
    inArtifact = any(spk_sec >= tLo & spk_sec < tHi, 2);
    keep = ~inArtifact;
    spks(ch).tStamp = spks(ch).tStamp(keep);
    spks(ch).ampl = spks(ch).ampl(keep);
end

end
