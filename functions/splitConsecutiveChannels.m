function [segments, gapIdx] = splitConsecutiveChannels(ch_inxs)
% segments: Nx2 [startPos endPos] in positions within ch_inxs
% gapIdx: indices i where ch_inxs(i) and ch_inxs(i+1) have a gap (diff>1)

    ch_inxs = ch_inxs(:);
    if isempty(ch_inxs)
        segments = zeros(0, 2);
        gapIdx = zeros(0, 1);
        return;
    end
    
    gapIdx = find(diff(ch_inxs) > 1);
    startPos = [1; gapIdx + 1];
    endPos = [gapIdx; numel(ch_inxs)];
    segments = [startPos, endPos];
end

