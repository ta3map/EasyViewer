function ch = stackEventChannels(a, na, b, nb)
    a = normalizeEventChannels(a, na);
    b = normalizeEventChannels(b, nb);
    if na == 0
        ch = b;
        return;
    end
    if nb == 0
        ch = a;
        return;
    end
    k = max(size(a, 2), size(b, 2));
    if size(a, 2) < k
        a(:, end+1:k) = a(:, 1);
    end
    if size(b, 2) < k
        b(:, end+1:k) = b(:, 1);
    end
    ch = [a; b];
end
