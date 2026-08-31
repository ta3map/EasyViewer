function iosValue = computeIosPlayerCursorValue(state, cursor, displayFrame, iosMode, baseframeData, frameFiltered)
    rowRange = [cursor.rect(1), cursor.rect(2)];
    colRange = [cursor.rect(3), cursor.rect(4)];
    if iosMode
        cursorRegion = displayFrame(rowRange(1):rowRange(2), colRange(1):colRange(2));
        iosValue = mean(cursorRegion(:), 'omitnan');
        return
    end
    if isempty(baseframeData) || isempty(frameFiltered)
        iosValue = NaN;
        return
    end
    iosValue = computeIosPlayerRegionMean(frameFiltered, baseframeData, rowRange, colRange);
    if isempty(state.referenceCursor)
        return
    end
    refCursor = state.referenceCursor;
    refRowRange = [refCursor.rect(1), refCursor.rect(2)];
    refColRange = [refCursor.rect(3), refCursor.rect(4)];
    refIosValue = computeIosPlayerRegionMedian(frameFiltered, baseframeData, refRowRange, refColRange);
    iosValue = iosValue - refIosValue;
end

function meanIos = computeIosPlayerRegionMean(frameFiltered, baseframeData, rowRange, colRange)
    frameRegion = double(frameFiltered(rowRange(1):rowRange(2), colRange(1):colRange(2)));
    baseRegion = double(baseframeData(rowRange(1):rowRange(2), colRange(1):colRange(2)));
    denom = baseRegion;
    denom(denom == 0) = NaN;
    iosRegion = (frameRegion - denom) ./ denom;
    meanIos = mean(iosRegion(:), 'omitnan');
end

function medianIos = computeIosPlayerRegionMedian(frameFiltered, baseframeData, rowRange, colRange)
    frameRegion = double(frameFiltered(rowRange(1):rowRange(2), colRange(1):colRange(2)));
    baseRegion = double(baseframeData(rowRange(1):rowRange(2), colRange(1):colRange(2)));
    denom = baseRegion;
    denom(denom == 0) = NaN;
    iosRegion = (frameRegion - denom) ./ denom;
    medianIos = median(iosRegion(:), 'omitnan');
end
