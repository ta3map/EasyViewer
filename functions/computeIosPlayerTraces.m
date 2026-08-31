function computeIosPlayerTraces(fig)
    state = fig.UserData;
    debugState('computeIosPlayerTraces', 'Starting: %d cursors, %d frames', length(state.cursors), state.meta.totalFrames);
    if ~iosPlayerHasValidMeta(fig)
        error('No file loaded');
    end
    if isempty(state.cursors)
        error('No cursors added');
    end
    if ~state.iosMode
        state.iosMode = true;
        state.h.iosCheck.Value = 1;
        fig.UserData = state;
        syncIosPlayerModeUi(fig);
        state = fig.UserData;
    end
    totalFrames = state.meta.totalFrames;
    numCursors = length(state.cursors);
    traces = cell(numCursors, 1);
    for i = 1:numCursors
        traces{i} = zeros(totalFrames, 1);
    end
    times = zeros(totalFrames, 1);
    referenceTrace = [];
    if ~isempty(state.referenceCursor)
        referenceTrace = zeros(totalFrames, 1);
    end
    batchSize = 100;
    for batchStart = 1:batchSize:totalFrames
        batchEnd = min(batchStart + batchSize - 1, totalFrames);
        [batchData, batchTimes] = readIOS2(state.iosPath, 'startframe', batchStart, 'endframe', batchEnd, 'Format', 'Lin');
        batchData = ensureIosFrame2D(batchData);
        if isempty(batchData)
            continue
        end
        for localIdx = 1:(batchEnd - batchStart + 1)
            globalFrameIdx = batchStart + localIdx - 1;
            if ndims(batchData) == 3
                rawFrame = batchData(:, :, localIdx);
            else
                rawFrame = batchData;
            end
            if isempty(rawFrame) || any(isnan(rawFrame(:)))
                continue
            end
            times(globalFrameIdx) = batchTimes(localIdx);
            filteredFrame = applyIosPlayerFilters(double(rawFrame), 'gaussian', state.gaussianSigma);
            [baseFrame, state] = getIosPlayerBaseFrame(state, globalFrameIdx);
            if isempty(baseFrame)
                continue
            end
            processedFrame = computeIosPlayerIos(filteredFrame, baseFrame, true);
            if ~isempty(state.referenceCursor)
                refCursor = state.referenceCursor;
                rowRange = [refCursor.rect(1), refCursor.rect(2)];
                colRange = [refCursor.rect(3), refCursor.rect(4)];
                refRegion = processedFrame(rowRange(1):rowRange(2), colRange(1):colRange(2));
                referenceTrace(globalFrameIdx) = median(refRegion(:), 'omitnan');
            end
            if ~strcmp(state.noiseFilterType, 'none')
                processedFrame = applyIosPlayerFilters(processedFrame, state.noiseFilterType, state.noiseFilterParam);
            end
            for cursorIdx = 1:numCursors
                cursor = state.cursors(cursorIdx);
                rowRange = [cursor.rect(1), cursor.rect(2)];
                colRange = [cursor.rect(3), cursor.rect(4)];
                cursorRegion = processedFrame(rowRange(1):rowRange(2), colRange(1):colRange(2));
                traces{cursorIdx}(globalFrameIdx) = mean(cursorRegion(:), 'omitnan');
            end
        end
        fig.UserData = state;
        debugState('computeIosPlayerTraces', 'Processed frames %d-%d', batchStart, batchEnd);
    end
    if ~isempty(referenceTrace)
        for i = 1:numCursors
            traces{i} = traces{i} - referenceTrace;
        end
    end
    traceFig = figure('Name', 'IOS Traces', 'NumberTitle', 'off');
    cols = ceil(sqrt(numCursors));
    rows = ceil(numCursors / cols);
    for i = 1:numCursors
        subplot(rows, cols, i);
        cursorColor = hex2rgb(state.cursors(i).color);
        plot(times, traces{i}, 'Color', cursorColor, 'LineWidth', 1.5);
        xlabel('Time (s)');
        ylabel('IOS');
        title(sprintf('Cursor %d (row=%d, col=%d)', i, state.cursors(i).center(1), state.cursors(i).center(2)));
        grid on;
    end
    debugState('computeIosPlayerTraces', 'Done: %d trace plots', numCursors);
end
