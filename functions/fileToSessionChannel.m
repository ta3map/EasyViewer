function sessionIdx = fileToSessionChannel(fileIdx)
    global channelFileOrder
    sessionIdx = fileIdx;
    n = numel(channelFileOrder);
    if n < 1 || isempty(fileIdx)
        return
    end
    rank = zeros(1, n);
    rank(channelFileOrder) = 1:n;
    mask = fileIdx >= 1 & fileIdx <= n;
    sessionIdx(mask) = rank(fileIdx(mask));
end
