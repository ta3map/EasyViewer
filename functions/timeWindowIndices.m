function [row_start, row_end] = timeWindowIndices(t, t1, t2)
% Indices in nondecreasing t: first t(i) >= t1, last t(j) < t2.
% Empty [] if the window has no samples.

t = t(:);
n = numel(t);
if n == 0
    row_start = [];
    row_end = [];
    return;
end

row_start = lowerBoundGE(t, t1);
row_end = lowerBoundGE(t, t2) - 1;

if row_start > n || row_end < 1 || row_end < row_start
    row_start = [];
    row_end = [];
end

end

function i = lowerBoundGE(X, v)
lo = 1;
hi = numel(X) + 1;
while lo < hi
    mid = floor((lo + hi) / 2);
    if X(mid) < v
        lo = mid + 1;
    else
        hi = mid;
    end
end
i = lo;
end
