function fileIdx = sessionToFileChannel(sessionIdx)
    global channelFileOrder
    fileIdx = sessionIdx;
    n = numel(channelFileOrder);
    if n >= 1 && ~isempty(sessionIdx) && max(sessionIdx) <= n && min(sessionIdx) >= 1
        fileIdx = channelFileOrder(sessionIdx);
    end
end
