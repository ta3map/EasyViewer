function tf = hasUsableMuaData(spks)
%HASUSABLEMUADATA True if spks has at least one channel with matching tStamp/ampl.

tf = false;
if isempty(spks) || ~isstruct(spks)
    return;
end
for i = 1:numel(spks)
    if ~isfield(spks, 'tStamp') || ~isfield(spks, 'ampl')
        continue;
    end
    nTs = numel(spks(i).tStamp);
    nAm = numel(spks(i).ampl);
    if nTs > 0 && nTs == nAm
        tf = true;
        return;
    end
end
end
