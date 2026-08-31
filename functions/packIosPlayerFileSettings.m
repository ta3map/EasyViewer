function settings = packIosPlayerFileSettings(state)
    settings = struct();
    settings.sourcePath = canonicalIosPath(state.iosPath);
    settings.currentFrame = round(state.h.slider.Value);
    settings.clim = state.clim;
    settings.iosMode = state.iosMode;
    settings.baseframeStart = state.baseframeStart;
    settings.baseframeEnd = state.baseframeEnd;
    settings.baseDelay = state.baseDelay;
    settings.floatingBaseMode = state.floatingBaseMode;
    settings.rotationAngle = state.rotationAngle;
    settings.offsetX = state.offsetX;
    settings.offsetY = state.offsetY;
    settings.zoomFactor = state.zoomFactor;
    settings.referenceFullSize = state.referenceFullSize;
    if ~isempty(state.climIosMin)
        settings.climIosMin = state.climIosMin;
    end
    if ~isempty(state.climIosMax)
        settings.climIosMax = state.climIosMax;
    end
    settings.cursors = packCursorsForSave(state.cursors);
    settings.referenceCursor = packReferenceCursorForSave(state.referenceCursor);
end

function out = packCursorsForSave(cursors)
    if isempty(cursors)
        out = [];
        return
    end
    n = numel(cursors);
    c = cursors(1);
    out = struct('center', c.center, 'rect', c.rect, 'visible', c.visible, 'size', c.size, 'color', c.color);
    for i = 2:n
        c = cursors(i);
        out(i) = struct('center', c.center, 'rect', c.rect, 'visible', c.visible, 'size', c.size, 'color', c.color);
    end
end

function out = packReferenceCursorForSave(referenceCursor)
    out = [];
    if isempty(referenceCursor)
        return
    end
    out = struct('center', referenceCursor.center, 'rect', referenceCursor.rect, 'size', referenceCursor.size);
end
