function col = padEventColumn(src, n, fill)
    col = repmat(fill, n, 1);
    src = src(:);
    m = min(n, numel(src));
    col(1:m) = src(1:m);
end
