function [rawFrame, t] = loadIosPlayerRawFrame(state, k)
    [data, t, ~] = readIOS2(state.iosPath, 'startframe', k, 'endframe', k, 'Format', 'Lin');
    rawFrame = ensureIosFrame2D(data);
end
