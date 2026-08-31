function [baseFrame, state] = getIosPlayerBaseFrame(state, k)
    baseFrame = [];
    if ~state.iosMode
        return
    end
    if state.floatingBaseMode
        baseFrame = computeIosPlayerFloatingBaseframe(state, k);
        return
    end
    needBase = isempty(state.baseframeData) || isempty(state.baseframeRangeUsed) || ...
        state.baseframeStart ~= state.baseframeRangeUsed(1) || ...
        state.baseframeEnd ~= state.baseframeRangeUsed(2);
    if needBase
        state = computeIosPlayerBaseframe(state);
    end
    if ~isempty(state.baseframeData)
        baseFrame = double(state.baseframeData);
    end
end

function baseframeData = computeIosPlayerFloatingBaseframe(state, k)
    baseframeData = [];
    meta = state.meta;
    delay = state.baseDelay;
    frames_back = 1;
    if meta.dt > 0
        frames_back = round(delay / meta.dt);
        k_base = max(1, k - frames_back);
    elseif meta.dt < 0
        frames_back = round(delay / abs(meta.dt));
        k_base = max(1, k - frames_back);
    else
        k_base = 1;
    end
    [data, ~, ~] = readIOS2(state.iosPath, 'startframe', k_base, 'endframe', k_base, 'Format', 'Lin');
    if isempty(data)
        return
    end
    data = double(ensureIosFrame2D(data));
    baseframeData = applyIosPlayerFilters(data, 'gaussian', state.gaussianSigma);
end
