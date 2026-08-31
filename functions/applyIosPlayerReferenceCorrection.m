function [displayFrame, state] = applyIosPlayerReferenceCorrection(frame, state)
    displayFrame = frame;
    if ~state.iosMode
        return
    end
    if state.referenceFullSize && isempty(state.referenceCursor)
        frameSize = size(frame);
        referenceCursor = struct();
        referenceCursor.center = [round(frameSize(1)/2), round(frameSize(2)/2)];
        referenceCursor.rect = [1, frameSize(1), 1, frameSize(2)];
        referenceCursor.handle = [];
        referenceCursor.size = max(frameSize(1), frameSize(2));
        state.referenceCursor = referenceCursor;
    end
    if isempty(state.referenceCursor)
        return
    end
    refCursor = state.referenceCursor;
    rowRange = [refCursor.rect(1), refCursor.rect(2)];
    colRange = [refCursor.rect(3), refCursor.rect(4)];
    refRegion = frame(rowRange(1):rowRange(2), colRange(1):colRange(2));
    refIosValue = median(refRegion(:), 'omitnan');
    displayFrame = frame - refIosValue;
end
