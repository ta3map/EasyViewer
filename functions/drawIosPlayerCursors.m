function drawIosPlayerCursors(fig, ax)
    state = fig.UserData;
    if isempty(state.him) || ~isvalid(state.him)
        return
    end
    displayFrame = state.him.CData;
    frameSize = size(displayFrame);
    frameForIos = state.preGeometricFrame;
    if isempty(frameForIos)
        frameForIos = displayFrame;
    end
    geom = [state.rotationAngle, state.offsetX, state.offsetY, state.zoomFactor];
    if ~isempty(state.cursors)
        for i = 1:length(state.cursors)
            state.cursors(i) = drawOneCursor(fig, ax, state, i, frameSize, frameForIos, geom);
        end
    end
    state = fig.UserData;
    state = drawReferenceCursor(ax, state, frameSize, geom);
    fig.UserData = state;
end

function cursor = drawOneCursor(fig, ax, state, i, frameSize, frameForIos, geom)
    cursor = state.cursors(i);
    if ~isfield(cursor, 'visible')
        cursor.visible = true;
    end
    if ~isfield(cursor, 'textHandle')
        cursor.textHandle = [];
    end
    if ~cursor.visible
        cursor = hideCursorGraphics(cursor);
        state.cursors(i) = cursor;
        fig.UserData = state;
        return
    end
    [x, y, xLine, yLine] = cursorDisplayCoords(cursor, geom, frameSize);
    isSelected = (~isempty(state.selectedCursorIndex) && state.selectedCursorIndex == i);
    cursorColor = hex2rgb(cursor.color);
    if isSelected
        cursor = drawSelectedCursor(ax, cursor, x, y);
    else
        cursor = drawNormalCursor(ax, cursor, xLine, yLine, cursorColor);
    end
    cursor = drawCursorIosLabel(ax, state, cursor, frameForIos, geom, frameSize);
    state.cursors(i) = cursor;
    fig.UserData = state;
end

function cursor = hideCursorGraphics(cursor)
    if ~isempty(cursor.handle) && isvalid(cursor.handle)
        delete(cursor.handle);
        cursor.handle = [];
    end
    if ~isempty(cursor.textHandle) && isvalid(cursor.textHandle)
        delete(cursor.textHandle);
        cursor.textHandle = [];
    end
end

function [x, y, xLine, yLine] = cursorDisplayCoords(cursor, geom, frameSize)
    row_min = cursor.rect(1);
    row_max = cursor.rect(2);
    col_min = cursor.rect(3);
    col_max = cursor.rect(4);
    [x1, y1] = iosPlayerOriginalToDisplay(row_min - 0.5, col_min - 0.5, geom(1), geom(2), geom(3), geom(4), frameSize);
    [x2, y2] = iosPlayerOriginalToDisplay(row_min - 0.5, col_max + 0.5, geom(1), geom(2), geom(3), geom(4), frameSize);
    [x3, y3] = iosPlayerOriginalToDisplay(row_max + 0.5, col_max + 0.5, geom(1), geom(2), geom(3), geom(4), frameSize);
    [x4, y4] = iosPlayerOriginalToDisplay(row_max + 0.5, col_min - 0.5, geom(1), geom(2), geom(3), geom(4), frameSize);
    x = [x1, x2, x3, x4];
    y = [y1, y2, y3, y4];
    xLine = [x1, x2, x3, x4, x1];
    yLine = [y1, y2, y3, y4, y1];
end

function cursor = drawSelectedCursor(ax, cursor, x, y)
    if ~isempty(cursor.handle) && isvalid(cursor.handle) && isa(cursor.handle, 'matlab.graphics.primitive.Patch')
        cursor.handle.XData = x;
        cursor.handle.YData = y;
        return
    end
    if ~isempty(cursor.handle) && isvalid(cursor.handle)
        delete(cursor.handle);
    end
    cursor.handle = patch(ax, x, y, 'r', 'FaceAlpha', 0.6, 'EdgeColor', 'r', 'LineWidth', 3, 'HitTest', 'off');
end

function cursor = drawNormalCursor(ax, cursor, xLine, yLine, cursorColor)
    if ~isempty(cursor.handle) && isvalid(cursor.handle) && isa(cursor.handle, 'matlab.graphics.primitive.Line')
        cursor.handle.XData = xLine;
        cursor.handle.YData = yLine;
        cursor.handle.Color = cursorColor;
        return
    end
    if ~isempty(cursor.handle) && isvalid(cursor.handle)
        delete(cursor.handle);
    end
    cursor.handle = line(ax, xLine, yLine, 'Color', cursorColor, 'LineWidth', 2, 'HitTest', 'off');
end

function cursor = drawCursorIosLabel(ax, state, cursor, frameForIos, geom, frameSize)
    if ~state.showIosValues
        if ~isempty(cursor.textHandle) && isvalid(cursor.textHandle)
            delete(cursor.textHandle);
            cursor.textHandle = [];
        end
        return
    end
    iosValue = computeIosPlayerCursorValue(state, cursor, frameForIos, state.iosMode, state.baseframeData, []);
    if isnan(iosValue) || ~isfinite(iosValue)
        if ~isempty(cursor.textHandle) && isvalid(cursor.textHandle)
            delete(cursor.textHandle);
            cursor.textHandle = [];
        end
        return
    end
    row_min = cursor.rect(1);
    col_max = cursor.rect(4);
    [textX, textY] = iosPlayerOriginalToDisplay(row_min, col_max, geom(1), geom(2), geom(3), geom(4), frameSize);
    textX = textX + 2;
    if ~isempty(cursor.textHandle) && isvalid(cursor.textHandle)
        cursor.textHandle.String = sprintf('%.4f', iosValue);
        cursor.textHandle.Position = [textX, textY, 0];
        return
    end
    cursor.textHandle = text(ax, textX, textY, sprintf('%.4f', iosValue), ...
        'Color', 'yellow', 'FontSize', 10, 'FontWeight', 'bold', ...
        'BackgroundColor', 'black', 'EdgeColor', 'yellow', 'Margin', 2);
end

function state = drawReferenceCursor(ax, state, frameSize, geom)
    if isempty(state.referenceCursor)
        children = ax.Children;
        for i = length(children):-1:1
            if isa(children(i), 'matlab.graphics.primitive.Line') && isequal(children(i).Color, [0 0 1])
                delete(children(i));
            end
        end
        return
    end
    refCursor = state.referenceCursor;
    [~, ~, xLine, yLine] = cursorDisplayCoords(refCursor, geom, frameSize);
    if ~isempty(refCursor.handle) && isvalid(refCursor.handle) && isa(refCursor.handle, 'matlab.graphics.primitive.Line')
        refCursor.handle.XData = xLine;
        refCursor.handle.YData = yLine;
    else
        if ~isempty(refCursor.handle) && isvalid(refCursor.handle)
            delete(refCursor.handle);
        end
        refCursor.handle = line(ax, xLine, yLine, 'Color', 'b', 'LineWidth', 2, 'HitTest', 'off');
    end
    state.referenceCursor = refCursor;
end
