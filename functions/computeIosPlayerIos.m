function processedFrame = computeIosPlayerIos(filteredFrame, baseFrame, iosMode)
    if ~iosMode || isempty(baseFrame)
        processedFrame = filteredFrame;
        return
    end
    denom = double(baseFrame);
    denom(denom == 0) = NaN;
    processedFrame = (filteredFrame - denom) ./ denom;
end
