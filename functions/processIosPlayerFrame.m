function [displayFrame, baseRange, state, t] = processIosPlayerFrame(state, k)
    [rawFrame, t] = loadIosPlayerRawFrame(state, k);
    if isempty(rawFrame) || any(isnan(rawFrame(:)))
        debugState('processIosPlayerFrame', 'Invalid raw frame %d', k);
        displayFrame = [];
        baseRange = [];
        return
    end
    filteredFrame = applyIosPlayerFilters(double(rawFrame), 'gaussian', state.gaussianSigma);
    [baseFrame, state] = getIosPlayerBaseFrame(state, k);
    if state.iosMode && isempty(baseFrame)
        debugState('processIosPlayerFrame', 'No baseframe for frame %d', k);
        displayFrame = [];
        baseRange = [];
        return
    end
    processedFrame = computeIosPlayerIos(filteredFrame, baseFrame, state.iosMode);
    [displayFrame, state] = applyIosPlayerReferenceCorrection(processedFrame, state);
    if ~strcmp(state.noiseFilterType, 'none')
        displayFrame = applyIosPlayerFilters(displayFrame, state.noiseFilterType, state.noiseFilterParam);
    end
    state.preGeometricFrame = displayFrame;
    displayFrame = applyIosPlayerGeometry(displayFrame, state.rotationAngle, state.offsetX, state.offsetY, state.zoomFactor);
    [baseRange, state] = computeIosPlayerDisplayRange(displayFrame, rawFrame, state);
end
