function closest_index = ClosestIndex(x, X)
if size(X, 2) > 1
    X = X';
end
if isnan(x)
    closest_index = nan;
else
[~,closest_index] = min(abs(X-x));
end