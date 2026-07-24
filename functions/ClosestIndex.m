function closest_indexes = ClosestIndex(x, X)
% Indices in X nearest to values in x. X is nondecreasing (time axis).
% On equal distance prefers the smaller index (same as min(abs(X-x))).

X = X(:);
n = numel(X);
closest_indexes = nan(size(x));

for k = 1:numel(x)
    v = x(k);
    if isnan(v)
        continue;
    end

    lo = 1;
    hi = n + 1;
    while lo < hi
        mid = floor((lo + hi) / 2);
        if X(mid) < v
            lo = mid + 1;
        else
            hi = mid;
        end
    end

    iRight = min(lo, n);
    iLeft = max(lo - 1, 1);
    chooseRight = abs(X(iRight) - v) < abs(X(iLeft) - v);
    closest_indexes(k) = iLeft + chooseRight * (iRight - iLeft);
end

end
