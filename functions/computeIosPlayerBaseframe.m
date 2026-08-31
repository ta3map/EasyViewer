function state = computeIosPlayerBaseframe(state)
    s = state.baseframeStart;
    e = state.baseframeEnd;
    [data, ~, ~] = readIOS2(state.iosPath, 'startframe', s, 'endframe', e, 'Format', 'Lin');
    if isempty(data)
        state.baseframeData = [];
        return
    end
    data = double(ensureIosFrame2D(data));
    if ndims(data) == 3
        for i = 1:size(data, 3)
            data(:, :, i) = applyIosPlayerFilters(data(:, :, i), 'gaussian', state.gaussianSigma);
        end
        state.baseframeData = mean(data, 3);
    else
        state.baseframeData = applyIosPlayerFilters(data, 'gaussian', state.gaussianSigma);
    end
    state.baseframeRangeUsed = [s e];
end
