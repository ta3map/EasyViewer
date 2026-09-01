function [r, c] = findGridCellForChannel(indexGrid, chIdx)
r = [];
c = [];
if chIdx < 1 || isempty(indexGrid)
    return;
end
[rows, cols] = find(indexGrid == chIdx, 1, 'first');
if isempty(rows)
    return;
end
r = rows;
c = cols;
end
