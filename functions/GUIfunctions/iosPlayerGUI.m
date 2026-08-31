function iosPlayerGUI(iosPath)
    if nargin < 1
        iosPath = '';
    end
    figTag = 'iosPlayerGUI';
    guiFig = findobj('Type', 'figure', 'Tag', figTag);
    if ~isempty(guiFig)
        figure(guiFig);
        return
    end
    global auto_open_last_file
    assetsPath = getAssetsPath();
    playIcon = fullfile(assetsPath, 'play_btn.png');
    pauseIcon = fullfile(assetsPath, 'pause_btn.png');
    recordIcon = fullfile(assetsPath, 'record_btn.png');
    stopIcon = fullfile(assetsPath, 'stop_btn.png');
    [coordsData, coordsFile] = loadGUICoords('iosPlayerGUI_coords.json');
    base_figure_position = coordsData.base_figure_position;
    fig = figure('Name', 'IOS Player', 'NumberTitle', 'off', ...
        'Position', base_figure_position, 'Tag', figTag, 'Resize', 'on');
    [ax, chartAx, h] = createIosPlayerUi(fig, coordsData, assetsPath, playIcon, pauseIcon, recordIcon, stopIcon);
    colormap(fig, gray);
    state = struct('iosPath', iosPath, 'meta', [], 'playTimer', [], 'clim', [0 65535], 'h', h, 'him', [], ...
        'iosMode', false, 'baseframeStart', 1, 'baseframeEnd', 1, 'baseframeData', [], 'baseframeRangeUsed', [], ...
        'gaussianSigma', 3.0, 'climIosBase', [], 'climIosMin', [], 'climIosMax', [], 'cursors', [], 'awaitingClick', false, ...
        'referenceCursor', [], 'awaitingReferenceClick', false, 'referenceSize', 10, 'referenceFullSize', false, ...
        'floatingBaseMode', false, 'baseDelay', 1.0, ...
        'noiseFilterType', 'none', 'noiseFilterParam', 5, ...
        'editingCursorIndex', [], 'showIosValues', false, 'selectedCursorIndex', [], ...
        'chartAx', chartAx, 'chartLines', [], 'chartData', [], 'chartSmoothWindow', 1, ...
        'isRecording', false, 'videoWriter', [], ...
        'colormapScheme', 'gray', 'playIcon', playIcon, 'pauseIcon', pauseIcon, 'recordIcon', recordIcon, 'stopIcon', stopIcon, ...
        'rotationAngle', 0, 'offsetX', 0, 'offsetY', 0, 'zoomFactor', 1, 'preGeometricFrame', []);
    state.imageClickCallback = @(~,~) onImageClick(fig, ax);
    fig.UserData = state;

    h.cursorsTable.CellSelectionCallback = @(src, event) onCursorsTableSelection(src, event, fig);
    h.cursorsTable.CellEditCallback = @(src, event) onCursorsTableEdit(src, event, fig, ax);
    bindGuiCallbacks(fig, {
        'slider', @(src,~) onSlider(src, fig, ax);
        'time_edit', @(src,~) onTimeEdit(src, fig, ax);
        'play_btn', @(src,~) onPlayPause(src, fig, ax);
        'speed_popup', @(src,~) onSpeedChange(src, fig, ax);
        'open_btn', @(src,~) onOpen(src, fig, ax);
        'record_btn', @(src,~) onRecord(src, fig, ax);
        'contrast_slider', @(src,~) syncIosPlayerSliderEdit(fig, ax, 'contrast', 'slider');
        'contrast_edit', @(src,~) syncIosPlayerSliderEdit(fig, ax, 'contrast', 'edit');
        'gaussian_slider', @(src,~) syncIosPlayerSliderEdit(fig, ax, 'gaussianSigma', 'slider');
        'gaussian_edit', @(src,~) syncIosPlayerSliderEdit(fig, ax, 'gaussianSigma', 'edit');
        'nav_start', @(src,~) onNav(src, fig, ax, 'start');
        'nav_prev', @(src,~) onNav(src, fig, ax, 'prev');
        'nav_next', @(src,~) onNav(src, fig, ax, 'next');
        'nav_end', @(src,~) onNav(src, fig, ax, 'end');
        'ios_check', @(src,~) onIosCheck(src, fig, ax);
        'set_base_btn', @(src,~) onSetBaseframe(src, fig, ax);
        'base_start_edit', @(src,~) onBaseRangeEdit(src, fig, ax, 'start');
        'base_end_edit', @(src,~) onBaseRangeEdit(src, fig, ax, 'end');
        'floating_base_check', @(src,~) onFloatingBaseCheck(src, fig, ax);
        'base_delay_edit', @(src,~) onBaseDelayEdit(src, fig, ax);
        'add_cursor_btn', @(src,~) onAddCursor(src, fig, ax);
        'get_traces_btn', @(src,~) onGetTraces(src, fig, ax);
        'add_reference_btn', @(src,~) onAddReference(src, fig, ax);
        'delete_reference_btn', @(src,~) onDeleteReference(src, fig, ax);
        'reference_size_edit', @(src,~) onReferenceSizeEdit(src, fig, ax);
        'reference_full_size_check', @(src,~) onReferenceFullSizeCheck(src, fig, ax);
        'edit_cursor_btn', @(src,~) onEditCursor(src, fig, ax);
        'delete_cursor_btn', @(src,~) onDeleteCursor(src, fig, ax);
        'clear_cursors_btn', @(src,~) onClearCursors(src, fig, ax);
        'show_ios_check', @(src,~) onShowIosCheck(src, fig, ax);
        'clear_chart_btn', @(src,~) onClearChart(src, fig);
        'show_chart_check', @(src,~) onShowChartCheck(src, fig);
        'chart_smooth_edit', @(src,~) onChartSmoothEdit(src, fig);
        'ios_min_edit', @(src,~) onIosRangeEdit(src, fig, ax, 'min');
        'ios_max_edit', @(src,~) onIosRangeEdit(src, fig, ax, 'max');
        'colormap_popup', @(src,~) onColormapChange(src, fig, ax);
        'noise_filter_popup', @(src,~) onNoiseFilterChange(src, fig, ax);
        'blur_sigma_slider', @(src,~) onNoiseFilterParamSlider(src, fig, ax);
        'blur_sigma_edit', @(src,~) onNoiseFilterParamEdit(src, fig, ax);
        'rotation_slider', @(src,~) syncIosPlayerSliderEdit(fig, ax, 'rotationAngle', 'slider');
        'rotation_edit', @(src,~) syncIosPlayerSliderEdit(fig, ax, 'rotationAngle', 'edit');
        'offset_x_slider', @(src,~) syncIosPlayerSliderEdit(fig, ax, 'offsetX', 'slider');
        'offset_x_edit', @(src,~) syncIosPlayerSliderEdit(fig, ax, 'offsetX', 'edit');
        'offset_y_slider', @(src,~) syncIosPlayerSliderEdit(fig, ax, 'offsetY', 'slider');
        'offset_y_edit', @(src,~) syncIosPlayerSliderEdit(fig, ax, 'offsetY', 'edit');
        'zoom_slider', @(src,~) syncIosPlayerSliderEdit(fig, ax, 'zoomFactor', 'slider');
        'zoom_edit', @(src,~) syncIosPlayerSliderEdit(fig, ax, 'zoomFactor', 'edit');
        'reset_pipeline_btn', @(src,~) onResetPipeline(src, fig, ax);
    });

    applyIosPlayerGlobalSettings(fig, loadIosPlayerGlobalSettings());
    fig.CloseRequestFcn = @(src,~) closeIosPlayerWindow(src);
    set(fig, 'SizeChangedFcn', @(~,~) resizeIosPlayerCallback(fig, coordsFile));
    fig.WindowState = 'maximized';
    debugState('iosPlayerGUI', 'IOS Player started');

    if ~isempty(iosPath) && exist(iosPath, 'file')
        openIosPlayerFile(fig, ax, iosPath);
    else
        autoOpenLastFile(fig, ax);
    end

    function closeIosPlayerWindow(fig)
        state = fig.UserData;
        debugState('iosPlayerGUI', 'Closing window');
        if ~isempty(state.playTimer) && isvalid(state.playTimer)
            stop(state.playTimer);
            delete(state.playTimer);
        end
        saveIosPlayerGlobalSettings(packIosPlayerGlobalSettings(state));
        if ~isempty(state.iosPath) && exist(state.iosPath, 'file')
            saveIosPlayerFileSettings(state.iosPath, packIosPlayerFileSettings(state));
            debugState('iosPlayerGUI', 'Saved file settings: %s', state.iosPath);
        end
        delete(fig);
        manageMainWindows('IosPlayerGUI');
    end

    function autoOpenLastFile(fig, ax)
        if isempty(auto_open_last_file) || ~auto_open_last_file
            return
        end
        settings = loadIosPlayerGlobalSettings();
        if ~isfield(settings, 'lastOpenedPath')
            return
        end
        lastPath = settings.lastOpenedPath;
        if ~exist(lastPath, 'file')
            debugState('iosPlayerGUI', 'Auto-open skipped, file missing: %s', lastPath);
            return
        end
        debugState('iosPlayerGUI', 'Auto-opening last file: %s', lastPath);
        openIosPlayerFile(fig, ax, lastPath);
    end
end

function onSlider(src, fig, ax)
    if ~iosPlayerHasValidMeta(fig)
        return
    end
    state = fig.UserData;
    k = round(src.Value);
    k = max(1, min(k, state.meta.totalFrames));
    showIosPlayerFrame(fig, ax, k);
end

function onNav(~, fig, ax, where)
    if ~iosPlayerHasValidMeta(fig)
        return
    end
    state = fig.UserData;
    N = state.meta.totalFrames;
    cur = getIosPlayerCurrentFrame(state);
    switch where
        case 'start'
            cur = 1;
            clearIosPlayerChart(fig);
        case 'end'
            cur = N;
        case 'prev'
            cur = max(1, cur - 1);
        case 'next'
            cur = min(N, cur + 1);
    end
    debugState('onNav', '%s -> frame %d/%d', where, cur, N);
    showIosPlayerFrame(fig, ax, cur);
end

function onTimeEdit(src, fig, ax)
    if ~iosPlayerHasValidMeta(fig)
        return
    end
    state = fig.UserData;
    sec = iosPlayerTimeStr2sec(src.String);
    if isnan(sec)
        return
    end
    meta = state.meta;
    k = 1;
    if meta.dt > 0
        k = round((sec - meta.t0) / meta.dt) + 1;
    end
    k = max(1, min(k, meta.totalFrames));
    showIosPlayerFrame(fig, ax, k);
end

function onPlayPause(src, fig, ax)
    if ~iosPlayerHasValidMeta(fig)
        return
    end
    state = fig.UserData;
    if ~isempty(state.playTimer) && isvalid(state.playTimer)
        stop(state.playTimer);
        delete(state.playTimer);
        state.playTimer = [];
        src.String = createIosPlayerIconButtonHTML(state.playIcon);
        fig.UserData = state;
        debugState('onPlayPause', 'Playback paused at frame %d', getIosPlayerCurrentFrame(state));
        return
    end
    N = state.meta.totalFrames;
    cur = getIosPlayerCurrentFrame(state);
    if cur >= N
        cur = 1;
        showIosPlayerFrame(fig, ax, cur);
    end
    speeds = getIosPlayerPlaybackSpeeds();
    speed = speeds(state.h.speedPopup.Value);
    dt = state.meta.dt / speed;
    if dt <= 0
        dt = 0.05;
    end
    src.String = createIosPlayerIconButtonHTML(state.pauseIcon);
    drawnow
    state.playTimer = timer('ExecutionMode', 'singleShot', 'StartDelay', dt, ...
        'TimerFcn', @(~,~) playStep(fig, ax));
    state.playTimer.UserData = struct('cur', cur, 'N', N);
    fig.UserData = state;
    start(state.playTimer);
    debugState('onPlayPause', 'Playback started: frame %d/%d, speed=%gx, dt=%.4fs', cur, N, speed, dt);
end

function playStep(fig, ax)
    state = fig.UserData;
    if isempty(state.playTimer) || ~isvalid(state.playTimer)
        return
    end
    t = state.playTimer.UserData;
    speeds = getIosPlayerPlaybackSpeeds();
    speed = speeds(state.h.speedPopup.Value);
    stepSize = max(1, round(speed));
    t.cur = t.cur + stepSize;
    if t.cur > t.N
        stop(state.playTimer);
        delete(state.playTimer);
        state.playTimer = [];
        state.h.playBtn.String = createIosPlayerIconButtonHTML(state.playIcon);
        fig.UserData = state;
        debugState('playStep', 'Playback finished at frame %d', t.N);
        showIosPlayerFrame(fig, ax, t.N);
        return
    end
    state.playTimer.UserData = t;
    fig.UserData = state;
    try
        showIosPlayerFrame(fig, ax, t.cur);
    catch ME
        debugState('playStep', 'Error at frame %d: %s', t.cur, ME.message);
        warning('IOS Player playStep: %s', ME.message);
    end
    drawnow;
    state = fig.UserData;
    if isempty(state.playTimer) || ~isvalid(state.playTimer)
        return
    end
    dt = state.meta.dt / speed;
    if dt <= 0
        dt = 0.05;
    end
    stop(state.playTimer);
    state.playTimer.StartDelay = dt;
    start(state.playTimer);
    fig.UserData = state;
end

function onSpeedChange(src, fig, ax)
    state = fig.UserData;
    if ~isempty(state.playTimer) && isvalid(state.playTimer)
        speeds = getIosPlayerPlaybackSpeeds();
        speed = speeds(src.Value);
        dt = state.meta.dt / speed;
        if dt <= 0
            dt = 0.05;
        end
        stop(state.playTimer);
        state.playTimer.StartDelay = dt;
        start(state.playTimer);
        fig.UserData = state;
        debugState('onSpeedChange', 'Speed changed to %gx, dt=%.4fs', speed, dt);
    end
end

function onIosCheck(src, fig, ax)
    state = fig.UserData;
    state.iosMode = logical(src.Value);
    if state.iosMode
        state.climIosMin = [];
        state.climIosMax = [];
        state.climIosBase = [];
        fig.UserData = state;
        state = computeIosPlayerBaseframe(state);
        fig.UserData = state;
    else
        state.climIosBase = [];
        fig.UserData = state;
    end
    syncIosPlayerModeUi(fig);
    refreshIosPlayerView(fig, ax);
    debugState('onIosCheck', 'IOS mode %s', mat2str(state.iosMode));
end

function onFloatingBaseCheck(src, fig, ax)
    state = fig.UserData;
    state.floatingBaseMode = logical(src.Value);
    state = clearIosPlayerBaseframe(state);
    fig.UserData = state;
    syncIosPlayerModeUi(fig);
    if state.iosMode
        refreshIosPlayerView(fig, ax);
    end
    debugState('onFloatingBaseCheck', 'Floating base %s', mat2str(state.floatingBaseMode));
end

function onBaseDelayEdit(src, fig, ax)
    state = fig.UserData;
    delay = str2double(src.String);
    if isnan(delay) || delay < 0
        src.String = sprintf('%.2f', state.baseDelay);
        return
    end
    state.baseDelay = delay;
    state = clearIosPlayerBaseframe(state);
    fig.UserData = state;
    debugState('onBaseDelayEdit', 'Base delay = %.2fs', delay);
    if state.iosMode && state.floatingBaseMode
        refreshIosPlayerView(fig, ax);
    end
end

function onSetBaseframe(~, fig, ax)
    if ~iosPlayerHasValidMeta(fig)
        return
    end
    state = fig.UserData;
    cur = getIosPlayerCurrentFrame(state);
    state.baseframeStart = cur;
    n20 = calculateIosPlayerN20Frames(state.meta);
    state.baseframeEnd = min(state.meta.totalFrames, cur + n20);
    state = clearIosPlayerBaseframe(state);
    state.h.baseStartEdit.String = num2str(state.baseframeStart);
    state.h.baseEndEdit.String = num2str(state.baseframeEnd);
    fig.UserData = state;
    debugState('onSetBaseframe', 'Baseframe range %d-%d (from frame %d)', state.baseframeStart, state.baseframeEnd, cur);
    if state.iosMode
        refreshIosPlayerView(fig, ax);
    end
end

function onBaseRangeEdit(src, fig, ax, which)
    if ~iosPlayerHasValidMeta(fig)
        return
    end
    state = fig.UserData;
    v = round(str2double(src.String));
    if isnan(v) || v < 1
        return
    end
    v = min(v, state.meta.totalFrames);
    if isequal(which, 'start')
        state.baseframeStart = v;
    else
        state.baseframeEnd = v;
    end
    state = clearIosPlayerBaseframe(state);
    fig.UserData = state;
    debugState('onBaseRangeEdit', 'Baseframe %s = %d', which, v);
    if state.iosMode
        refreshIosPlayerView(fig, ax);
    end
end

function onNoiseFilterChange(src, fig, ax)
    state = fig.UserData;
    filterTypes = {'none', 'median', 'wiener', 'highpass'};
    selectedIdx = src.Value;
    if selectedIdx < 1 || selectedIdx > length(filterTypes)
        selectedIdx = 1;
    end
    state.noiseFilterType = filterTypes{selectedIdx};
    state = applyIosPlayerNoiseFilterUi(state, state.noiseFilterType);
    fig.UserData = state;
    debugState('onNoiseFilterChange', 'Noise filter: %s', state.noiseFilterType);
    refreshIosPlayerView(fig, ax);
end

function onNoiseFilterParamSlider(~, fig, ax)
    state = fig.UserData;
    state.noiseFilterParam = double(state.h.blurSigmaSlider.Value);
    state.h.blurSigmaEdit.String = formatIosPlayerNoiseFilterParam(state);
    fig.UserData = state;
    refreshIosPlayerView(fig, ax);
end

function onNoiseFilterParamEdit(src, fig, ax)
    state = fig.UserData;
    param = str2double(src.String);
    if isnan(param) || param < state.h.blurSigmaSlider.Min
        src.String = formatIosPlayerNoiseFilterParam(state);
        return
    end
    param = max(state.h.blurSigmaSlider.Min, min(state.h.blurSigmaSlider.Max, param));
    state.noiseFilterParam = param;
    state.h.blurSigmaSlider.Value = param;
    fig.UserData = state;
    refreshIosPlayerView(fig, ax);
end

function onResetPipeline(~, fig, ax)
    state = fig.UserData;
    state = resetIosPlayerPipeline(state);
    fig.UserData = state;
    debugState('onResetPipeline', 'Pipeline reset to defaults');
    refreshIosPlayerView(fig, ax);
end

function onColormapChange(src, fig, ax)
    state = fig.UserData;
    colormapNames = {'gray','jet','hot','cool','parula','hsv','spring','summer','autumn','winter','bone','copper','pink','lines'};
    selectedIdx = src.Value;
    if selectedIdx < 1 || selectedIdx > length(colormapNames)
        return
    end
    selectedScheme = colormapNames{selectedIdx};
    colormap(fig, selectedScheme);
    state.colormapScheme = selectedScheme;
    fig.UserData = state;
    refreshIosPlayerView(fig, ax);
end

function onOpen(~, fig, ax)
    startPath = '';
    settings = loadIosPlayerGlobalSettings();
    if isfield(settings, 'lastOpenedPath')
        lastPath = settings.lastOpenedPath;
        if exist(lastPath, 'file')
            startPath = fileparts(lastPath);
        elseif exist(lastPath, 'dir')
            startPath = lastPath;
        end
    end
    if isempty(startPath)
        [f, p] = uigetfile('*.ios', 'Select IOS file');
    else
        [f, p] = uigetfile('*.ios', 'Select IOS file', startPath);
    end
    if isequal(f, 0)
        debugState('onOpen', 'File selection canceled');
        return
    end
    fname = fullfile(p, f);
    debugState('onOpen', 'Selected file: %s', fname);
    openIosPlayerFile(fig, ax, fname);
end

function onRecord(~, fig, ax)
    state = fig.UserData;
    
    if state.isRecording
        state.isRecording = false;
        state.h.recordBtn.String = createIosPlayerIconButtonHTML(state.recordIcon);
        fig.UserData = state;
        debugState('onRecord', 'Recording stopped by user');
        return
    end
    
    if ~iosPlayerHasValidMeta(fig)
        return
    end
    
    iosPath = state.iosPath;
    if isempty(iosPath)
        return
    end
    
    [filePath, fileName, ~] = fileparts(iosPath);
    if isempty(filePath)
        filePath = pwd;
    end
    
    defaultFileName = [fileName, '.mp4'];
    defaultPath = fullfile(filePath, defaultFileName);
    
    [f, p] = uiputfile('*.mp4', 'Save Video As', defaultPath);
    if isequal(f, 0)
        debugState('onRecord', 'Save dialog canceled');
        return
    end
    outputPath = fullfile(p, f);
    debugState('onRecord', 'Recording to: %s', outputPath);
    
    v = [];
    try
        speeds = getIosPlayerPlaybackSpeeds();
        speed = speeds(state.h.speedPopup.Value);
        stepSize = max(1, round(speed));
        
        totalFrames = state.meta.totalFrames;
        
        if state.meta.dt > 0
            originalFrameRate = 1 / state.meta.dt;
            frameRate = originalFrameRate;
        else
            frameRate = 30;
        end
        
        if frameRate <= 0
            frameRate = 30;
        end
        
        v = VideoWriter(outputPath, 'MPEG-4');
        v.FrameRate = frameRate;
        open(v);
        
        state.isRecording = true;
        state.videoWriter = v;
        state.h.recordBtn.String = createIosPlayerIconButtonHTML(state.stopIcon);
        fig.UserData = state;
        drawnow;
        
        framesToRecord = 1:stepSize:totalFrames;
        numFramesToRecord = length(framesToRecord);
        
        for idx = 1:numFramesToRecord
            state = fig.UserData;
            if ~state.isRecording
                break
            end
            
            k = framesToRecord(idx);
            showIosPlayerFrame(fig, ax, k);
            drawnow;
            
            frame = getframe(ax);
            writeVideo(v, frame);
        end
        
        close(v);
        
        state = fig.UserData;
        state.isRecording = false;
        state.videoWriter = [];
        state.h.recordBtn.String = createIosPlayerIconButtonHTML(state.recordIcon);
        fig.UserData = state;
        
        if idx == numFramesToRecord
            debugState('onRecord', 'Recording complete: %d frames -> %s', numFramesToRecord, outputPath);
            msgbox(sprintf('Video saved successfully to:\n%s', outputPath), 'Recording Complete', 'help');
        else
            debugState('onRecord', 'Recording stopped early at frame %d/%d', idx, numFramesToRecord);
            msgbox('Video recording stopped by user.', 'Recording Stopped', 'warn');
        end
        
    catch ME
        debugState('onRecord', 'Recording error: %s', ME.message);
        if ~isempty(v) && isvalid(v)
            close(v);
        end
        state = fig.UserData;
        state.isRecording = false;
        state.videoWriter = [];
        state.h.recordBtn.String = createIosPlayerIconButtonHTML(state.recordIcon);
        fig.UserData = state;
        errordlg(sprintf('Error during video recording:\n%s', ME.message), 'Recording Error');
        rethrow(ME);
    end
end

function onAddCursor(~, fig, ax)
    state = fig.UserData;
    if ~iosPlayerHasValidMeta(fig)
        return
    end
    state = setIosPlayerClickMode(state, 'addCursor', []);
    fig.UserData = state;
end

function onAddReference(~, fig, ax)
    state = fig.UserData;
    if ~iosPlayerHasValidMeta(fig)
        return
    end
    if ~isempty(state.referenceCursor)
        return
    end
    state = setIosPlayerClickMode(state, 'addReference', []);
    fig.UserData = state;
end

function onImageClick(fig, ax)
    state = fig.UserData;
    if state.awaitingReferenceClick
        if ~iosPlayerHasValidMeta(fig) || isempty(state.him) || ~isvalid(state.him)
            return
        end
        [row, col, frameSize] = iosPlayerClickToOriginal(fig, ax);
        if state.referenceFullSize
            rect = [1, frameSize(1), 1, frameSize(2)];
            referenceSize = max(frameSize(1), frameSize(2));
        else
            [rect, referenceSize] = iosPlayerRectAround(row, col, state.referenceSize, frameSize);
        end
        referenceCursor = struct('center', [row, col], 'rect', rect, 'handle', [], 'size', referenceSize);
        state.referenceCursor = referenceCursor;
        state = setIosPlayerClickMode(state, 'idle', []);
        fig.UserData = state;
        syncIosPlayerReferenceButtons(fig);
        debugState('onImageClick', 'Reference added at [%d,%d], size=%d', row, col, referenceSize);
        drawIosPlayerCursors(fig, ax);
        return
    end
    if ~isempty(state.editingCursorIndex)
        if ~iosPlayerHasValidMeta(fig) || isempty(state.him) || ~isvalid(state.him)
            return
        end
        cursorIdx = state.editingCursorIndex;
        if cursorIdx < 1 || cursorIdx > length(state.cursors)
            state = setIosPlayerClickMode(state, 'idle', []);
            fig.UserData = state;
            return
        end
        [row, col, frameSize] = iosPlayerClickToOriginal(fig, ax);
        cursor = state.cursors(cursorIdx);
        if ~isfield(cursor, 'size')
            cursor.size = 10;
        end
        [rect, halfSize] = iosPlayerRectAround(row, col, cursor.size, frameSize);
        deleteIosPlayerCursorGraphics(cursor);
        cursor.center = [row, col];
        cursor.rect = rect;
        cursor.handle = [];
        cursor.size = halfSize;
        if ~isfield(cursor, 'visible')
            cursor.visible = true;
        end
        if ~isfield(cursor, 'textHandle')
            cursor.textHandle = [];
        end
        state.cursors(cursorIdx) = cursor;
        state = setIosPlayerClickMode(state, 'idle', []);
        fig.UserData = state;
        syncIosPlayerCursorsUi(fig, ax, true);
        return
    end
    if ~state.awaitingClick
        return
    end
    if ~iosPlayerHasValidMeta(fig) || isempty(state.him) || ~isvalid(state.him)
        return
    end
    [row, col, frameSize] = iosPlayerClickToOriginal(fig, ax);
    halfSize = 10;
    [rect, ~] = iosPlayerRectAround(row, col, halfSize, frameSize);
    cursor = struct('center', [row, col], 'rect', rect, 'handle', [], 'visible', true, ...
        'textHandle', [], 'size', halfSize);
    numCursors = length(state.cursors);
    colors = getColors(numCursors + 1);
    cursor.color = colors{numCursors + 1};
    if isempty(state.cursors)
        state.cursors = cursor;
    else
        state.cursors(end + 1) = cursor;
    end
    state = setIosPlayerClickMode(state, 'idle', []);
    fig.UserData = state;
    debugState('onImageClick', 'Cursor %d added at [%d,%d]', numCursors + 1, row, col);
    syncIosPlayerCursorsUi(fig, ax, true);
end

function onGetTraces(~, fig, ax)
    debugState('onGetTraces', 'Starting trace extraction');
    hWaitbar = waitbar(0, 'Computing traces...');
    drawnow;
    try
        computeIosPlayerTraces(fig);
        waitbar(1, hWaitbar, 'Complete');
        pause(0.3);
        close(hWaitbar);
        debugState('onGetTraces', 'Trace extraction complete');
    catch ME
        debugState('onGetTraces', 'Error: %s', ME.message);
        if exist('hWaitbar', 'var') && isvalid(hWaitbar)
            close(hWaitbar);
        end
        rethrow(ME);
    end
end

function onCursorsTableEdit(src, event, fig, ax)
    state = fig.UserData;
    if isempty(state.cursors)
        return
    end
    colIdx = event.Indices(2);
    rowIdx = event.Indices(1);
    if rowIdx < 1 || rowIdx > length(state.cursors)
        return
    end
    data = src.Data;
    cursor = state.cursors(rowIdx);

    if colIdx == 4
        cursor.size = round(data{rowIdx, 4});
        sz = size(state.him.CData);
        r = cursor.center(1); c = cursor.center(2); h = cursor.size;
        cursor.rect = [max(1,r-h), min(sz(1),r+h), max(1,c-h), min(sz(2),c+h)];
        deleteIosPlayerCursorGraphics(cursor);
        cursor.handle = [];
    elseif colIdx == 5
        cursor.visible = logical(data{rowIdx, 5});
    else
        return
    end
    
    state.cursors(rowIdx) = cursor;
    fig.UserData = state;
    drawIosPlayerCursors(fig, ax);
    if state.iosMode && iosPlayerHasValidMeta(fig)
        refreshIosPlayerView(fig, ax);
    end
end

function onShowIosCheck(src, fig, ax)
    state = fig.UserData;
    state.showIosValues = logical(src.Value);
    fig.UserData = state;
    drawIosPlayerCursors(fig, ax);
end

function onEditCursor(~, fig, ax)
    state = fig.UserData;
    if ~iosPlayerHasValidMeta(fig) || isempty(state.cursors)
        return
    end
    selection = state.h.cursorsTable.UserData;
    if isempty(selection) || isempty(selection.Indices)
        return
    end
    selectedRow = selection.Indices(1, 1);
    if selectedRow < 1 || selectedRow > length(state.cursors)
        return
    end
    state = setIosPlayerClickMode(state, 'edit', selectedRow);
    fig.UserData = state;
end

function onDeleteCursor(~, fig, ax)
    state = fig.UserData;
    if isempty(state.cursors)
        return
    end
    selection = state.h.cursorsTable.UserData;
    if isempty(selection) || isempty(selection.Indices)
        return
    end
    selectedRow = selection.Indices(1, 1);
    if selectedRow < 1 || selectedRow > length(state.cursors)
        return
    end
    
    deleteIosPlayerCursorGraphics(state.cursors(selectedRow));
    state.cursors = state.cursors([1:selectedRow-1, selectedRow+1:end]);
    fig.UserData = state;
    debugState('onDeleteCursor', 'Deleted cursor %d, remaining=%d', selectedRow, length(state.cursors));
    syncIosPlayerCursorsUi(fig, ax, true);
end

function onClearCursors(~, fig, ax)
    state = fig.UserData;
    if isempty(state.cursors)
        return
    end
    
    for i = 1:length(state.cursors)
        deleteIosPlayerCursorGraphics(state.cursors(i));
    end
    
    state.cursors = [];
    fig.UserData = state;
    debugState('onClearCursors', 'All cursors cleared');
    syncIosPlayerCursorsUi(fig, ax, true);
end

function onCursorsTableSelection(src, event, fig)
    src.UserData = event;
    state = fig.UserData;
    if ~isempty(event.Indices) && size(event.Indices, 1) > 0
        selectedRow = event.Indices(1, 1);
        if selectedRow >= 1 && selectedRow <= length(state.cursors)
            state.selectedCursorIndex = selectedRow;
        else
            state.selectedCursorIndex = [];
        end
    else
        state.selectedCursorIndex = [];
    end
    fig.UserData = state;
    if ~iosPlayerHasValidMeta(fig)
        return
    end
    ax = getIosPlayerMainAx(fig);
    drawIosPlayerCursors(fig, ax);
    
    if state.iosMode && ~isempty(state.cursors) && ~isempty(state.chartLines)
        state = fig.UserData;
        for i = 1:length(state.chartLines)
            if ~isempty(state.chartLines(i)) && ishghandle(state.chartLines(i))
                if ~isempty(state.selectedCursorIndex) && state.selectedCursorIndex == i
                    state.chartLines(i).LineWidth = 3.0;
                else
                    state.chartLines(i).LineWidth = 1.5;
                end
            end
        end
        fig.UserData = state;
    end
end

function onReferenceSizeEdit(src, fig, ax)
    state = fig.UserData;
    sizeValue = str2double(src.String);
    if isnan(sizeValue) || sizeValue < 1
        src.String = num2str(state.referenceSize);
        return
    end
    state.referenceSize = round(sizeValue);
    state.referenceFullSize = false;
    state.h.referenceFullSizeCheck.Value = 0;
    src.String = num2str(state.referenceSize);
    
    if ~isempty(state.referenceCursor) && ~isempty(state.him) && isvalid(state.him)
        refCursor = state.referenceCursor;
        frameSize = size(state.him.CData);
        row = refCursor.center(1);
        col = refCursor.center(2);
        [rect, halfSize] = iosPlayerRectAround(row, col, state.referenceSize, frameSize);
        refCursor.rect = rect;
        refCursor.size = halfSize;
        state.referenceCursor = refCursor;
    end
    fig.UserData = state;
    if ~isempty(state.him) && isvalid(state.him)
        drawIosPlayerCursors(fig, ax);
        if state.iosMode && iosPlayerHasValidMeta(fig)
            refreshIosPlayerView(fig, ax);
        end
    end
end

function onDeleteReference(~, fig, ax)
    state = fig.UserData;
    if isempty(state.referenceCursor)
        return
    end
    
    if ~isempty(state.referenceCursor.handle) && isvalid(state.referenceCursor.handle)
        delete(state.referenceCursor.handle);
    end
    
    children = ax.Children;
    for i = length(children):-1:1
        if isa(children(i), 'matlab.graphics.primitive.Line') && ...
           isequal(children(i).Color, [0 0 1])
            delete(children(i));
        end
    end
    
    state.referenceCursor = [];
    state.referenceFullSize = false;
    state.h.referenceFullSizeCheck.Value = 0;
    if state.iosMode
        state.h.referenceSizeText.Visible = 'on';
        state.h.referenceSizeEdit.Visible = 'on';
    end
    fig.UserData = state;
    syncIosPlayerReferenceButtons(fig);
    debugState('onDeleteReference', 'Reference removed');
    
    if iosPlayerHasValidMeta(fig)
        refreshIosPlayerView(fig, ax);
    else
        drawIosPlayerCursors(fig, ax);
    end
end

function onReferenceFullSizeCheck(src, fig, ax)
    state = fig.UserData;
    state.referenceFullSize = logical(src.Value);
    
    if state.referenceFullSize
        state.h.referenceSizeText.Visible = 'off';
        state.h.referenceSizeEdit.Visible = 'off';
        
        if ~isempty(state.him) && isvalid(state.him)
            frameSize = size(state.him.CData);
            
            if ~isempty(state.referenceCursor)
                refCursor = state.referenceCursor;
                row_min = 1;
                row_max = frameSize(1);
                col_min = 1;
                col_max = frameSize(2);
                
                refCursor.rect = [row_min, row_max, col_min, col_max];
                refCursor.size = max(frameSize(1), frameSize(2));
                refCursor.center = [round(frameSize(1)/2), round(frameSize(2)/2)];
                state.referenceCursor = refCursor;
            else
                row_min = 1;
                row_max = frameSize(1);
                col_min = 1;
                col_max = frameSize(2);
                
                referenceCursor = struct();
                referenceCursor.center = [round(frameSize(1)/2), round(frameSize(2)/2)];
                referenceCursor.rect = [row_min, row_max, col_min, col_max];
                referenceCursor.handle = [];
                referenceCursor.size = max(frameSize(1), frameSize(2));
                
                state.referenceCursor = referenceCursor;
            end
        end
    else
        if state.iosMode
            visRefSize = 'on';
        else
            visRefSize = 'off';
        end
        state.h.referenceSizeText.Visible = visRefSize;
        state.h.referenceSizeEdit.Visible = visRefSize;
    end
    
    fig.UserData = state;
    syncIosPlayerReferenceButtons(fig);
    
    if iosPlayerHasValidMeta(fig)
        refreshIosPlayerView(fig, ax);
    else
        drawIosPlayerCursors(fig, ax);
    end
end

function onIosRangeEdit(src, fig, ax, which)
    state = fig.UserData;
    if ~iosPlayerHasValidMeta(fig) || ~state.iosMode
        return
    end
    val = str2double(src.String);
    if isnan(val) || ~isfinite(val)
        if isequal(which, 'min')
            src.String = sprintf('%.6f', state.climIosMin);
        else
            src.String = sprintf('%.6f', state.climIosMax);
        end
        return
    end
    if isequal(which, 'min')
        state.climIosMin = val;
    else
        state.climIosMax = val;
    end
    state.climIosBase = [state.climIosMin state.climIosMax];
    fig.UserData = state;
    refreshIosPlayerView(fig, ax);
end

function onClearChart(~, fig)
    clearIosPlayerChart(fig);
end

function onShowChartCheck(src, fig)
    state = fig.UserData;
    if ~isempty(state.chartAx) && ishghandle(state.chartAx)
        if src.Value
            state.chartAx.Visible = 'on';
        else
            state.chartAx.Visible = 'off';
        end
    end
    fig.UserData = state;
end

function onChartSmoothEdit(src, fig)
    state = fig.UserData;
    val = str2double(src.String);
    if isnan(val) || val < 1
        src.String = num2str(state.chartSmoothWindow);
        return
    end
    state.chartSmoothWindow = round(val);
    src.String = num2str(state.chartSmoothWindow);
    fig.UserData = state;
end

function resizeIosPlayerCallback(fig, coordsFile)
    try
        ResizeElements(fig, coordsFile);
    catch ME
        debugState('resizeIosPlayerCallback', 'Error: %s', ME.message);
        warning('Error scaling IOS Player elements: %s', ME.message);
    end
end

