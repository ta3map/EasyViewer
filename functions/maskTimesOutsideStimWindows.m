function keep = maskTimesOutsideStimWindows(t_sec, time, stim_inxs, win_r)
%MASKTIMESOUTSIDESTIMWINDOWS Logical mask: true where t_sec is outside stim windows.

origSize = size(t_sec);
if isempty(t_sec) || isempty(stim_inxs) || win_r == 0
    keep = true(origSize);
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
t_col = t_sec(:);
inArtifact = any(t_col >= tLo & t_col < tHi, 2);
keep = reshape(~inArtifact, origSize);

end
