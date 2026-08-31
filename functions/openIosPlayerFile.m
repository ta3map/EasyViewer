function openIosPlayerFile(fig, ax, fname)
    debugState('openIosPlayerFile', 'Opening: %s', fname);
    state = fig.UserData;
    state = stopIosPlayerPlayback(state);
    if ~isempty(state.iosPath) && exist(state.iosPath, 'file')
        saveIosPlayerFileSettings(state.iosPath, packIosPlayerFileSettings(state));
    end
    if ~isempty(state.cursors)
        for i = 1:length(state.cursors)
            deleteIosPlayerCursorGraphics(state.cursors(i));
        end
    end
    if ~isempty(state.referenceCursor) && ~isempty(state.referenceCursor.handle) && isvalid(state.referenceCursor.handle)
        delete(state.referenceCursor.handle);
    end
    if ~isempty(state.him) && isvalid(state.him)
        delete(state.him);
        state.him = [];
    end
    cla(ax);
    clearIosPlayerChart(fig);
    meta = readIOS2(fname, 'metadataOnly', true);
    state.meta = meta;
    state.iosPath = fname;
    [~, t13, ~] = readIOS2(fname, 'startframe', 1, 'endframe', min(3, meta.totalFrames), 'Format', 'Lin');
    t13 = [t13(:); NaN(max(0, 3 - numel(t13)), 1)];
    debugState('openIosPlayerFile', 't(1)=%g, t(2)=%g, t(3)=%g, frames=%d', t13(1), t13(2), t13(3), meta.totalFrames);
    state.h.filePathText.String = fname;
    state = clearIosPlayerBaseframe(state);
    state.clim = [0 65535];
    state.climIosBase = [];
    state.climIosMin = [];
    state.climIosMax = [];
    state.iosMode = false;
    state.h.iosCheck.Value = 0;
    state.baseframeStart = 1;
    state.baseframeEnd = 1;
    state.baseDelay = 1.0;
    state.floatingBaseMode = false;
    state.h.floatingBaseCheck.Value = 0;
    state.h.baseStartEdit.String = '1';
    state.h.baseEndEdit.String = '1';
    state.h.baseDelayEdit.String = '1.0';
    defaults = iosPlayerDefaultPipelineState();
    state = applyIosPlayerPipelineParam(state, 'rotationAngle', defaults.rotationAngle);
    state = applyIosPlayerPipelineParam(state, 'offsetX', defaults.offsetX);
    state = applyIosPlayerPipelineParam(state, 'offsetY', defaults.offsetY);
    state = applyIosPlayerPipelineParam(state, 'zoomFactor', defaults.zoomFactor);
    state.referenceFullSize = false;
    state.h.referenceFullSizeCheck.Value = 0;
    state.h.iosMinEdit.String = '';
    state.h.iosMaxEdit.String = '';
    state.cursors = [];
    state.awaitingClick = false;
    state.referenceCursor = [];
    state.awaitingReferenceClick = false;
    state.editingCursorIndex = [];
    state.selectedCursorIndex = [];
    state.preGeometricFrame = [];
    N = meta.totalFrames;
    state.h.slider.Min = 1;
    state.h.slider.Max = max(2, N);
    state.h.slider.Value = 1;
    state.h.slider.SliderStep = [1/max(1,N-1) 10/max(1,N-1)];
    if N == 1
        state.h.slider.SliderStep = [1 1];
    end
    fig.UserData = state;
    fileSettings = loadIosPlayerFileSettings(fname);
    state = fig.UserData;
    state = applyIosPlayerFileSettings(fig, state, fileSettings);
    syncIosPlayerModeUi(fig);
    updateIosPlayerCursorsTable(fig);
    initIosPlayerChart(fig);
    showIosPlayerFrame(fig, ax, getIosPlayerCurrentFrame(fig.UserData));
    state = fig.UserData;
    debugState('openIosPlayerFile', 'Ready: iosMode=%d, cursors=%d', state.iosMode, length(state.cursors));
end
