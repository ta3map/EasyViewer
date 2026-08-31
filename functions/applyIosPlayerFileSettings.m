function state = applyIosPlayerFileSettings(fig, state, settings)
    if isempty(settings) || ~isstruct(settings)
        fig.UserData = state;
        return
    end
    if isfield(settings, 'clim') && numel(settings.clim) == 2
        state.clim = settings.clim;
    end
    if isfield(settings, 'iosMode')
        state.iosMode = logical(settings.iosMode);
        state.h.iosCheck.Value = double(state.iosMode);
    end
    if isfield(settings, 'baseframeStart')
        state.baseframeStart = settings.baseframeStart;
        state.h.baseStartEdit.String = num2str(state.baseframeStart);
    end
    if isfield(settings, 'baseframeEnd')
        state.baseframeEnd = settings.baseframeEnd;
        state.h.baseEndEdit.String = num2str(state.baseframeEnd);
    end
    if isfield(settings, 'baseDelay')
        state.baseDelay = settings.baseDelay;
        state.h.baseDelayEdit.String = sprintf('%.2f', state.baseDelay);
    end
    if isfield(settings, 'floatingBaseMode')
        state.floatingBaseMode = logical(settings.floatingBaseMode);
        state.h.floatingBaseCheck.Value = double(state.floatingBaseMode);
    end
    if isfield(settings, 'rotationAngle')
        state = applyIosPlayerPipelineParam(state, 'rotationAngle', settings.rotationAngle);
    end
    if isfield(settings, 'offsetX')
        state = applyIosPlayerPipelineParam(state, 'offsetX', settings.offsetX);
    end
    if isfield(settings, 'offsetY')
        state = applyIosPlayerPipelineParam(state, 'offsetY', settings.offsetY);
    end
    if isfield(settings, 'zoomFactor')
        state = applyIosPlayerPipelineParam(state, 'zoomFactor', settings.zoomFactor);
    end
    if isfield(settings, 'referenceFullSize')
        state.referenceFullSize = logical(settings.referenceFullSize);
        state.h.referenceFullSizeCheck.Value = double(state.referenceFullSize);
    end
    if isfield(settings, 'climIosMin') && ~isempty(settings.climIosMin)
        state.climIosMin = settings.climIosMin;
        state.h.iosMinEdit.String = sprintf('%.6f', state.climIosMin);
    end
    if isfield(settings, 'climIosMax') && ~isempty(settings.climIosMax)
        state.climIosMax = settings.climIosMax;
        state.h.iosMaxEdit.String = sprintf('%.6f', state.climIosMax);
    end
    if isfield(settings, 'cursors')
        state.cursors = unpackCursorsFromSettings(settings.cursors);
    end
    if isfield(settings, 'referenceCursor')
        state.referenceCursor = unpackReferenceCursorFromSettings(settings.referenceCursor);
    end
    if isfield(settings, 'currentFrame')
        v = state.h.slider.Min;
        m = state.h.slider.Max;
        state.h.slider.Value = max(v, min(m, round(settings.currentFrame)));
    end
    fig.UserData = state;
end

function cursors = unpackCursorsFromSettings(cursors)
    if isempty(cursors)
        cursors = [];
        return
    end
    for i = 1:numel(cursors)
        cursors(i).handle = [];
        cursors(i).textHandle = [];
    end
end

function referenceCursor = unpackReferenceCursorFromSettings(referenceCursor)
    if isempty(referenceCursor)
        return
    end
    referenceCursor.handle = [];
end
