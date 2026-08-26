function ch = normalizeEventChannels(channels, n)
    if n == 0
        ch = [];
        return;
    end
    ch = ones(n, 1);
    if isempty(channels)
        return;
    end
    if size(channels, 1) == n && size(channels, 2) >= 1
        ch = channels;
        return;
    end
    flat = channels(:);
    m = min(n, numel(flat));
    ch(1:m, 1) = flat(1:m);
end
