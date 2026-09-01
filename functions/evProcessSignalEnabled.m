function tf = evProcessSignalEnabled()
%EVPROCESSSIGNALENABLED True when bench passed and MEX is enabled.

persistent cachedFlag cachedPath
flagPath = evProcessSignalFlagPath();
if isempty(cachedPath) || ~strcmp(cachedPath, flagPath)
    cachedPath = flagPath;
    cachedFlag = isfile(flagPath) && exist('evProcessSignal', 'file') == 3;
end
tf = cachedFlag;

end

function p = evProcessSignalFlagPath()
p = fullfile(fileparts(which('applyFilter')), 'evProcessSignal.enabled');
end
