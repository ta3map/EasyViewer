function iosPlayerGUI(iosPath)
    if nargin < 1
        iosPath = '';
    end
    fig = figure('Name', 'IOS Player', 'NumberTitle', 'off', ...
        'Units', 'normalized', 'Position', [0.25 0.15 0.5 0.7]);
    ax = axes(fig, 'Units', 'normalized', 'Position', [0.1 0.5 0.8 0.45]);
    colormap(fig, gray);
    hSlider = uicontrol(fig, 'Style', 'slider', 'Units', 'normalized', ...
        'Position', [0.1 0.38 0.8 0.04], 'Min', 1, 'Max', 2, 'Value', 1);
    hTimeEdit = uicontrol(fig, 'Style', 'edit', 'Units', 'normalized', ...
        'Position', [0.1 0.32 0.12 0.04], 'String', '0:00.0');
    hNavStart = uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
        'Position', [0.24 0.32 0.05 0.04], 'String', '|<<');
    hNavPrev = uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
        'Position', [0.30 0.32 0.05 0.04], 'String', '<');
    hNavNext = uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
        'Position', [0.36 0.32 0.05 0.04], 'String', '>');
    hNavEnd = uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
        'Position', [0.42 0.32 0.05 0.04], 'String', '>>|');
    hPlayBtn = uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
        'Position', [0.5 0.32 0.06 0.04], 'String', 'Play');
    hSpeedPopup = uicontrol(fig, 'Style', 'popupmenu', 'Units', 'normalized', ...
        'Position', [0.58 0.32 0.08 0.04], 'String', {'0.5x','1x','2x'}, 'Value', 2);
    hOpenBtn = uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
        'Position', [0.68 0.32 0.12 0.04], 'String', 'Open');
    hContrastSlider = uicontrol(fig, 'Style', 'slider', 'Units', 'normalized', ...
        'Position', [0.1 0.26 0.3 0.03], 'Min', 0.2, 'Max', 2, 'Value', 1);
    uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.42 0.26 0.08 0.03], 'String', 'Gaussian:', 'HorizontalAlignment', 'left');
    hGaussianSlider = uicontrol(fig, 'Style', 'slider', 'Units', 'normalized', ...
        'Position', [0.5 0.26 0.15 0.03], 'Min', 0, 'Max', 20, 'Value', 3);
    hGaussianEdit = uicontrol(fig, 'Style', 'edit', 'Units', 'normalized', ...
        'Position', [0.67 0.26 0.05 0.03], 'String', '3.0');
    hIosCheck = uicontrol(fig, 'Style', 'checkbox', 'Units', 'normalized', ...
        'Position', [0.1 0.22 0.04 0.03], 'String', 'IOS', 'Value', 0);
    hBaseStartEdit = uicontrol(fig, 'Style', 'edit', 'Units', 'normalized', ...
        'Position', [0.16 0.22 0.06 0.03], 'String', '1', 'Visible', 'off');
    hBaseEndEdit = uicontrol(fig, 'Style', 'edit', 'Units', 'normalized', ...
        'Position', [0.24 0.22 0.06 0.03], 'String', '1', 'Visible', 'off');
    hSetBaseBtn = uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
        'Position', [0.32 0.22 0.1 0.03], 'String', 'Set baseframe', 'Visible', 'off');
    hFloatingBaseCheck = uicontrol(fig, 'Style', 'checkbox', 'Units', 'normalized', ...
        'Position', [0.1 0.19 0.12 0.03], 'String', 'Floating base', 'Value', 0, 'Visible', 'off');
    hBaseDelayEdit = uicontrol(fig, 'Style', 'edit', 'Units', 'normalized', ...
        'Position', [0.24 0.19 0.06 0.03], 'String', '1.0', 'Visible', 'off');

    hAddCursorBtn = uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
        'Position', [0.44 0.22 0.1 0.03], 'String', 'Add Cursor');
    hGetTracesBtn = uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
        'Position', [0.56 0.22 0.1 0.03], 'String', 'Get Traces');
    hAddReferenceBtn = uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
        'Position', [0.68 0.22 0.1 0.03], 'String', 'Add Reference');
    hDeleteReferenceBtn = uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
        'Position', [0.8 0.22 0.1 0.03], 'String', 'Delete Reference');

    uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.1 0.15 0.2 0.03], 'String', 'Cursors:', 'HorizontalAlignment', 'left');
    hCursorsTable = uitable(fig, 'Units', 'normalized', ...
        'Position', [0.1 0.05 0.5 0.1], ...
        'ColumnName', {'#', 'Row', 'Col', 'Visible'}, ...
        'ColumnEditable', [false false false true], ...
        'ColumnFormat', {'numeric', 'numeric', 'numeric', 'logical'}, ...
        'ColumnWidth', {30 80 80 60}, ...
        'Data', cell(0, 4), ...
        'CellSelectionCallback', @(src, event) onCursorsTableSelection(src, event, fig), ...
        'CellEditCallback', @(src, event) onCursorsTableEdit(src, event, fig, ax));
    hEditCursorBtn = uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
        'Position', [0.62 0.11 0.12 0.03], 'String', 'Edit Position');
    hDeleteCursorBtn = uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
        'Position', [0.62 0.08 0.12 0.03], 'String', 'Delete Selected');
    hClearCursorsBtn = uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
        'Position', [0.62 0.05 0.12 0.03], 'String', 'Clear All');
    hShowIosCheck = uicontrol(fig, 'Style', 'checkbox', 'Units', 'normalized', ...
        'Position', [0.76 0.11 0.14 0.03], 'String', 'Show IOS values', 'Value', 0);

    h = struct('slider', hSlider, 'timeEdit', hTimeEdit, 'playBtn', hPlayBtn, ...
        'speedPopup', hSpeedPopup, 'openBtn', hOpenBtn, 'contrastSlider', hContrastSlider, ...
        'navStart', hNavStart, 'navPrev', hNavPrev, 'navNext', hNavNext, 'navEnd', hNavEnd, ...
        'iosCheck', hIosCheck, 'baseStartEdit', hBaseStartEdit, 'baseEndEdit', hBaseEndEdit, ...
        'setBaseBtn', hSetBaseBtn, 'gaussianSlider', hGaussianSlider, 'gaussianEdit', hGaussianEdit, ...
        'addCursorBtn', hAddCursorBtn, 'getTracesBtn', hGetTracesBtn, 'addReferenceBtn', hAddReferenceBtn, ...
        'deleteReferenceBtn', hDeleteReferenceBtn, 'floatingBaseCheck', hFloatingBaseCheck, 'baseDelayEdit', hBaseDelayEdit, ...
        'cursorsTable', hCursorsTable, 'editCursorBtn', hEditCursorBtn, ...
        'deleteCursorBtn', hDeleteCursorBtn, 'clearCursorsBtn', hClearCursorsBtn, ...
        'showIosCheck', hShowIosCheck);
    state = struct('iosPath', iosPath, 'meta', [], 'playTimer', [], 'clim', [0 65535], 'h', h, 'him', [], ...
        'iosMode', false, 'baseframeStart', 1, 'baseframeEnd', 1, 'baseframeData', [], 'baseframeRangeUsed', [], ...
        'gaussianSigma', 3.0, 'climIosBase', [], 'cursors', [], 'awaitingClick', false, ...
        'referenceCursor', [], 'awaitingReferenceClick', false, 'floatingBaseMode', false, 'baseDelay', 1.0, ...
        'editingCursorIndex', [], 'showIosValues', false, 'selectedCursorIndex', []);
    fig.UserData = state;

    hSlider.Callback = @(src,~) onSlider(src, fig, ax);
    hTimeEdit.Callback = @(src,~) onTimeEdit(src, fig, ax);
    hPlayBtn.Callback = @(src,~) onPlayPause(src, fig, ax);
    hOpenBtn.Callback = @(src,~) onOpen(src, fig, ax);
    hContrastSlider.Callback = @(src,~) onContrast(src, fig, ax);
    hGaussianSlider.Callback = @(src,~) onGaussianSlider(src, fig, ax);
    hGaussianEdit.Callback = @(src,~) onGaussianEdit(src, fig, ax);
    hNavStart.Callback = @(src,~) onNav(src, fig, ax, 'start');
    hNavPrev.Callback = @(src,~) onNav(src, fig, ax, 'prev');
    hNavNext.Callback = @(src,~) onNav(src, fig, ax, 'next');
    hNavEnd.Callback = @(src,~) onNav(src, fig, ax, 'end');
    hIosCheck.Callback = @(src,~) onIosCheck(src, fig, ax);
    hSetBaseBtn.Callback = @(src,~) onSetBaseframe(src, fig, ax);
    hBaseStartEdit.Callback = @(src,~) onBaseRangeEdit(src, fig, ax, 'start');
    hBaseEndEdit.Callback = @(src,~) onBaseRangeEdit(src, fig, ax, 'end');
    hFloatingBaseCheck.Callback = @(src,~) onFloatingBaseCheck(src, fig, ax);
    hBaseDelayEdit.Callback = @(src,~) onBaseDelayEdit(src, fig, ax);
    hAddCursorBtn.Callback = @(src,~) onAddCursor(src, fig, ax);
    hGetTracesBtn.Callback = @(src,~) onGetTraces(src, fig, ax);
    hAddReferenceBtn.Callback = @(src,~) onAddReference(src, fig, ax);
    hDeleteReferenceBtn.Callback = @(src,~) onDeleteReference(src, fig, ax);
    hEditCursorBtn.Callback = @(src,~) onEditCursor(src, fig, ax);
    hDeleteCursorBtn.Callback = @(src,~) onDeleteCursor(src, fig, ax);
    hClearCursorsBtn.Callback = @(src,~) onClearCursors(src, fig, ax);
    hShowIosCheck.Callback = @(src,~) onShowIosCheck(src, fig, ax);

    if ~isempty(iosPath) && exist(iosPath, 'file')
        openFile(fig, ax, iosPath);
    end
end

function filtered = applyGaussianFilter(img, sigma)
    if sigma <= 0
        filtered = img;
        return
    end
    if exist('imgaussfilt', 'file') == 2
        filtered = imgaussfilt(img, sigma);
    else
        hsize = max(3, 2 * ceil(3 * sigma) + 1);
        h = fspecial('gaussian', hsize, sigma);
        filtered = conv2(img, h, 'same');
    end
end

function valid = hasValidMeta(fig)
    state = fig.UserData;
    valid = ~isempty(state.meta);
end

function k = getCurrentFrame(state)
    k = round(state.h.slider.Value);
end

function n20 = calculateN20Frames(meta)
    n20 = 1;
    if meta.dt > 0
        n20 = round(20 / meta.dt);
    end
end

function state = clearBaseframe(state)
    state.baseframeData = [];
    state.baseframeRangeUsed = [];
end

function data = ensure2DFrame(data)
    if ndims(data) == 4
        data = squeeze(data);
    end
end

function baseRange = getBaseRange(state)
    ranges = {state.clim, state.climIosBase};
    idx = 1 + double(~isempty(state.climIosBase));
    baseRange = ranges{idx};
end

function applyContrast(ax, baseRange, contrastValue)
    center = double(baseRange(1) + baseRange(2)) / 2;
    half = double(baseRange(2) - baseRange(1)) / 2;
    ax.CLim = center + (half / contrastValue) * [-1 1];
end

function state = computeBaseframe(fig)
    state = fig.UserData;
    if ~hasValidMeta(fig)
        return
    end
    s = state.baseframeStart;
    e = state.baseframeEnd;
    [data, ~, ~] = readIOS2(state.iosPath, 'startframe', s, 'endframe', e, 'Format', 'Lin');
    if isempty(data)
        state.baseframeData = [];
        fig.UserData = state;
        return
    end
    data = double(data);
    data = ensure2DFrame(data);
    if ndims(data) == 3
        for i = 1:size(data, 3)
            data(:, :, i) = applyGaussianFilter(data(:, :, i), state.gaussianSigma);
        end
        state.baseframeData = mean(data, 3);
    else
        state.baseframeData = applyGaussianFilter(data, state.gaussianSigma);
    end
    state.baseframeRangeUsed = [s e];
    fig.UserData = state;
end

function baseframeData = computeFloatingBaseframe(fig, currentTime)
    state = fig.UserData;
    baseframeData = [];
    if ~hasValidMeta(fig)
        return
    end
    meta = state.meta;
    delay = state.baseDelay;
    baseTime = currentTime - delay;
    k_base = 1;
    if meta.dt > 0
        k_base = round((baseTime - meta.t0) / meta.dt) + 1;
    end
    k_base = max(1, min(k_base, meta.totalFrames));
    [data, ~, ~] = readIOS2(state.iosPath, 'startframe', k_base, 'endframe', k_base, 'Format', 'Lin');
    if isempty(data)
        return
    end
    data = double(data);
    data = ensure2DFrame(data);
    baseframeData = applyGaussianFilter(data, state.gaussianSigma);
end

function openFile(fig, ax, fname)
    state = fig.UserData;
    if ~isempty(state.playTimer) && isvalid(state.playTimer)
        stop(state.playTimer);
        delete(state.playTimer);
        state.playTimer = [];
        state.h.playBtn.String = 'Play';
    end
    
    if ~isempty(state.cursors)
        for i = 1:length(state.cursors)
            deleteCursorGraphics(state.cursors(i));
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
    
    meta = readIOS2(fname, 'metadataOnly', true);
    state.meta = meta;
    state.iosPath = fname;
    state.clim = [0 65535];
    state.h.contrastSlider.Value = 1;
    state.h.gaussianSlider.Value = state.gaussianSigma;
    state.h.gaussianEdit.String = sprintf('%.2f', state.gaussianSigma);
    state = clearBaseframe(state);
    state.baseframeStart = 1;
    n20 = calculateN20Frames(meta);
    state.baseframeEnd = min(meta.totalFrames, 1 + n20);
    state.h.baseStartEdit.String = num2str(state.baseframeStart);
    state.h.baseEndEdit.String = num2str(state.baseframeEnd);
    state.floatingBaseMode = false;
    state.baseDelay = 1.0;
    state.h.baseDelayEdit.String = sprintf('%.2f', state.baseDelay);
    
    state.cursors = [];
    state.awaitingClick = false;
    state.referenceCursor = [];
    state.awaitingReferenceClick = false;
    state.editingCursorIndex = [];
    state.selectedCursorIndex = [];
    fig.UserData = state;
    updateCursorsTable(fig);

    N = meta.totalFrames;
    state.h.slider.Min = 1;
    state.h.slider.Max = max(2, N);
    state.h.slider.Value = 1;
    state.h.slider.SliderStep = [1/max(1,N-1) 10/max(1,N-1)];
    if N == 1
        state.h.slider.SliderStep = [1 1];
    end

    showFrame(fig, ax, 1);
end

function showFrame(fig, ax, k)
    state = fig.UserData;
    if ~hasValidMeta(fig)
        return
    end
    [data, t, ~] = readIOS2(state.iosPath, 'startframe', k, 'endframe', k, 'Format', 'Lin');
    if isempty(data) || any(isnan(data(:)))
        return
    end
    frame = ensure2DFrame(data);
    if state.iosMode
        if state.floatingBaseMode
            baseframeData = computeFloatingBaseframe(fig, t(1));
            if isempty(baseframeData)
                state.h.timeEdit.String = sec2timeStr(t(1));
                state.h.slider.Value = k;
                fig.UserData = state;
                return
            end
            base = double(baseframeData);
        else
            needBase = isempty(state.baseframeData) || isempty(state.baseframeRangeUsed) || ...
                state.baseframeStart ~= state.baseframeRangeUsed(1) || ...
                state.baseframeEnd ~= state.baseframeRangeUsed(2);
            if needBase
                state = computeBaseframe(fig);
                state = fig.UserData;
            end
            if isempty(state.baseframeData)
                state.h.timeEdit.String = sec2timeStr(t(1));
                state.h.slider.Value = k;
                fig.UserData = state;
                return
            end
            base = double(state.baseframeData);
        end
        frameD = double(frame);
        frameD = applyGaussianFilter(frameD, state.gaussianSigma);
        denom = base;
        denom(denom == 0) = NaN;
        iosFrame = (frameD - denom) ./ denom;
        
        if ~isempty(state.referenceCursor)
            refCursor = state.referenceCursor;
            rowRange = [refCursor.rect(1), refCursor.rect(2)];
            colRange = [refCursor.rect(3), refCursor.rect(4)];
            refRegion = iosFrame(rowRange(1):rowRange(2), colRange(1):colRange(2));
            refIosValue = mean(refRegion(:), 'omitnan');
            displayFrame = iosFrame - refIosValue;
        else
            displayFrame = iosFrame;
        end
        
        climIos = max(abs(displayFrame(:)));
        if ~isfinite(climIos) || climIos == 0
            climIos = 0.01;
        end
        climIos = [-climIos climIos];
        state.climIosBase = climIos;
    else
        frameD = double(frame);
        displayFrame = applyGaussianFilter(frameD, state.gaussianSigma);
        climIos = [];
    end
    if isempty(state.him) || ~isvalid(state.him)
        cla(ax);
        state.clim = [min(frame(:)) max(frame(:))];
        state.him = imagesc(ax, displayFrame);
        axis(ax, 'image');
        axis(ax, 'off');
        state.him.ButtonDownFcn = @(~,~) onImageClick(fig, ax);
    else
        state.him.CData = displayFrame;
    end
    ax.YDir = 'normal';
    
    drawCursors(fig, ax);
    c = double(state.h.contrastSlider.Value);
    applyContrast(ax, getBaseRange(state), c);

    state.h.timeEdit.String = sec2timeStr(t(1));
    state.h.slider.Value = k;
    fig.UserData = state;
end

function onSlider(src, fig, ax)
    if ~hasValidMeta(fig)
        return
    end
    state = fig.UserData;
    k = round(src.Value);
    k = max(1, min(k, state.meta.totalFrames));
    showFrame(fig, ax, k);
end

function onNav(~, fig, ax, where)
    if ~hasValidMeta(fig)
        return
    end
    state = fig.UserData;
    N = state.meta.totalFrames;
    cur = getCurrentFrame(state);
    switch where
        case 'start'
            cur = 1;
        case 'end'
            cur = N;
        case 'prev'
            cur = max(1, cur - 1);
        case 'next'
            cur = min(N, cur + 1);
    end
    showFrame(fig, ax, cur);
end

function onTimeEdit(src, fig, ax)
    if ~hasValidMeta(fig)
        return
    end
    state = fig.UserData;
    sec = timeStr2sec(src.String);
    if isnan(sec)
        return
    end
    meta = state.meta;
    k = 1;
    if meta.dt > 0
        k = round((sec - meta.t0) / meta.dt) + 1;
    end
    k = max(1, min(k, meta.totalFrames));
    showFrame(fig, ax, k);
end

function onPlayPause(src, fig, ax)
    if ~hasValidMeta(fig)
        return
    end
    state = fig.UserData;
    if ~isempty(state.playTimer) && isvalid(state.playTimer)
        stop(state.playTimer);
        delete(state.playTimer);
        state.playTimer = [];
        src.String = 'Play';
        fig.UserData = state;
        return
    end
    N = state.meta.totalFrames;
    cur = getCurrentFrame(state);
    speeds = [0.5 1 2];
    speed = speeds(state.h.speedPopup.Value);
    dt = state.meta.dt / speed;
    if dt <= 0
        dt = 0.05;
    end
    src.String = 'Pause';
    drawnow
    state.playTimer = timer('ExecutionMode', 'fixedRate', 'Period', dt, ...
        'TimerFcn', @(~,~) playStep(fig, ax));
    state.playTimer.UserData = struct('cur', cur, 'N', N);
    fig.UserData = state;
    start(state.playTimer);
end

function playStep(fig, ax)
    state = fig.UserData;
    t = state.playTimer.UserData;
    t.cur = t.cur + 1;
    if t.cur > t.N
        stop(state.playTimer);
        delete(state.playTimer);
        state.playTimer = [];
        state.h.playBtn.String = 'Play';
        fig.UserData = state;
        return
    end
    state.playTimer.UserData = t;
    fig.UserData = state;
    showFrame(fig, ax, t.cur);
end

function onIosCheck(src, fig, ax)
    state = fig.UserData;
    state.iosMode = logical(src.Value);
    vis = 'off';
    if state.iosMode
        vis = 'on';
    else
        state.climIosBase = [];
    end
    state.h.floatingBaseCheck.Visible = vis;
    state.h.baseDelayEdit.Visible = vis;
    if state.floatingBaseMode && state.iosMode
        visBase = 'off';
    else
        visBase = vis;
    end
    state.h.baseStartEdit.Visible = visBase;
    state.h.baseEndEdit.Visible = visBase;
    state.h.setBaseBtn.Visible = visBase;
    fig.UserData = state;
    k = getCurrentFrame(state);
    showFrame(fig, ax, k);
end

function onFloatingBaseCheck(src, fig, ax)
    state = fig.UserData;
    state.floatingBaseMode = logical(src.Value);
    if state.floatingBaseMode && state.iosMode
        visBase = 'off';
    elseif state.iosMode
        visBase = 'on';
    else
        visBase = 'off';
    end
    state.h.baseStartEdit.Visible = visBase;
    state.h.baseEndEdit.Visible = visBase;
    state.h.setBaseBtn.Visible = visBase;
    state = clearBaseframe(state);
    fig.UserData = state;
    if state.iosMode
        k = getCurrentFrame(state);
        showFrame(fig, ax, k);
    end
end

function onBaseDelayEdit(src, fig, ax)
    state = fig.UserData;
    delay = str2double(src.String);
    if isnan(delay) || delay < 0
        src.String = sprintf('%.2f', state.baseDelay);
        return
    end
    state.baseDelay = delay;
    state = clearBaseframe(state);
    fig.UserData = state;
    if state.iosMode
        k = getCurrentFrame(state);
        showFrame(fig, ax, k);
    end
end

function onSetBaseframe(~, fig, ax)
    if ~hasValidMeta(fig)
        return
    end
    state = fig.UserData;
    cur = getCurrentFrame(state);
    state.baseframeStart = cur;
    n20 = calculateN20Frames(state.meta);
    state.baseframeEnd = min(state.meta.totalFrames, cur + n20);
    state = clearBaseframe(state);
    state.h.baseStartEdit.String = num2str(state.baseframeStart);
    state.h.baseEndEdit.String = num2str(state.baseframeEnd);
    fig.UserData = state;
    if state.iosMode
        k = getCurrentFrame(state);
        showFrame(fig, ax, k);
    end
end

function onBaseRangeEdit(src, fig, ax, which)
    if ~hasValidMeta(fig)
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
    state = clearBaseframe(state);
    fig.UserData = state;
    if state.iosMode
        k = getCurrentFrame(state);
        showFrame(fig, ax, k);
    end
end

function onGaussianSlider(src, fig, ax)
    state = fig.UserData;
    sigma = double(src.Value);
    state.gaussianSigma = sigma;
    state.h.gaussianEdit.String = sprintf('%.2f', sigma);
    state = clearBaseframe(state);
    fig.UserData = state;
    if hasValidMeta(fig)
        k = getCurrentFrame(state);
        showFrame(fig, ax, k);
    end
end

function onGaussianEdit(src, fig, ax)
    state = fig.UserData;
    sigma = str2double(src.String);
    if isnan(sigma) || sigma < 0
        src.String = sprintf('%.2f', state.gaussianSigma);
        return
    end
    sigma = max(0, min(20, sigma));
    state.gaussianSigma = sigma;
    state.h.gaussianSlider.Value = sigma;
    state = clearBaseframe(state);
    fig.UserData = state;
    if hasValidMeta(fig)
        k = getCurrentFrame(state);
        showFrame(fig, ax, k);
    end
end

function onContrast(~, fig, ax)
    if ~hasValidMeta(fig)
        return
    end
    state = fig.UserData;
    if isempty(state.him) || ~isvalid(state.him)
        return
    end
    c = double(state.h.contrastSlider.Value);
    applyContrast(ax, getBaseRange(state), c);
end

function onOpen(~, fig, ax)
    [f, p] = uigetfile('*.ios', 'Select IOS file');
    if isequal(f, 0)
        return
    end
    fname = fullfile(p, f);
    openFile(fig, ax, fname);
end

function sec = timeStr2sec(s)
    sec = NaN;
    parts = strsplit(s, ':');
    if length(parts) == 1
        sec = str2double(parts{1});
        return
    end
    if length(parts) >= 2
        m = str2double(parts{1});
        secRest = str2double(parts{2});
        if isnan(m) || isnan(secRest)
            return
        end
        sec = m * 60 + secRest;
    end
end

function s = sec2timeStr(sec)
    m = floor(sec / 60);
    sVal = sec - m * 60;
    s = sprintf('%d:%05.2f', m, sVal);
end

function onAddCursor(src, fig, ax)
    state = fig.UserData;
    if ~hasValidMeta(fig)
        return
    end
    state.awaitingClick = true;
    state.awaitingReferenceClick = false;
    state.editingCursorIndex = [];
    state.h.addReferenceBtn.String = 'Add Reference';
    state.h.editCursorBtn.String = 'Edit Position';
    src.String = 'Click on image...';
    fig.UserData = state;
end

function onAddReference(src, fig, ax)
    state = fig.UserData;
    if ~hasValidMeta(fig)
        return
    end
    state.awaitingReferenceClick = true;
    state.awaitingClick = false;
    state.editingCursorIndex = [];
    state.h.addCursorBtn.String = 'Add Cursor';
    state.h.editCursorBtn.String = 'Edit Position';
    src.String = 'Click on image...';
    fig.UserData = state;
end

function onImageClick(fig, ax)
    state = fig.UserData;
    if state.awaitingReferenceClick
        if ~hasValidMeta(fig)
            return
        end
        cp = get(ax, 'CurrentPoint');
        col = round(cp(1, 1));
        row = round(cp(1, 2));
        
        if isempty(state.him) || ~isvalid(state.him)
            return
        end
        
        frameSize = size(state.him.CData);
        if row < 1 || row > frameSize(1) || col < 1 || col > frameSize(2)
            return
        end
        
        halfSize = 5;
        row_min = max(1, row - halfSize);
        row_max = min(frameSize(1), row + halfSize);
        col_min = max(1, col - halfSize);
        col_max = min(frameSize(2), col + halfSize);
        
        referenceCursor = struct();
        referenceCursor.center = [row, col];
        referenceCursor.rect = [row_min, row_max, col_min, col_max];
        referenceCursor.handle = [];
        
        state.referenceCursor = referenceCursor;
        state.awaitingReferenceClick = false;
        state.h.addReferenceBtn.String = 'Add Reference';
        fig.UserData = state;
        
        drawCursors(fig, ax);
        return
    end
    
    if ~isempty(state.editingCursorIndex)
        if ~hasValidMeta(fig)
            return
        end
        cp = get(ax, 'CurrentPoint');
        col = round(cp(1, 1));
        row = round(cp(1, 2));
        
        if isempty(state.him) || ~isvalid(state.him)
            return
        end
        
        frameSize = size(state.him.CData);
        if row < 1 || row > frameSize(1) || col < 1 || col > frameSize(2)
            return
        end
        
        cursorIdx = state.editingCursorIndex;
        if cursorIdx < 1 || cursorIdx > length(state.cursors)
            state.editingCursorIndex = [];
            state.h.editCursorBtn.String = 'Edit Position';
            fig.UserData = state;
            return
        end
        
        halfSize = 5;
        row_min = max(1, row - halfSize);
        row_max = min(frameSize(1), row + halfSize);
        col_min = max(1, col - halfSize);
        col_max = min(frameSize(2), col + halfSize);
        
        cursor = state.cursors(cursorIdx);
        if ~isempty(cursor.handle) && isvalid(cursor.handle)
            delete(cursor.handle);
        end
        
        cursor.center = [row, col];
        cursor.rect = [row_min, row_max, col_min, col_max];
        cursor.handle = [];
        if ~isfield(cursor, 'visible')
            cursor.visible = true;
        end
        if ~isfield(cursor, 'textHandle')
            cursor.textHandle = [];
        end
        
        state.cursors(cursorIdx) = cursor;
        state.editingCursorIndex = [];
        state.h.editCursorBtn.String = 'Edit Position';
        fig.UserData = state;
        
        updateCursorsTable(fig);
        drawCursors(fig, ax);
        return
    end
    
    if ~state.awaitingClick
        return
    end
    if ~hasValidMeta(fig)
        return
    end
    cp = get(ax, 'CurrentPoint');
    col = round(cp(1, 1));
    row = round(cp(1, 2));
    
    if isempty(state.him) || ~isvalid(state.him)
        return
    end
    
    frameSize = size(state.him.CData);
    if row < 1 || row > frameSize(1) || col < 1 || col > frameSize(2)
        return
    end
    
    halfSize = 5;
    row_min = max(1, row - halfSize);
    row_max = min(frameSize(1), row + halfSize);
    col_min = max(1, col - halfSize);
    col_max = min(frameSize(2), col + halfSize);
    
    cursor = struct();
    cursor.center = [row, col];
    cursor.rect = [row_min, row_max, col_min, col_max];
    cursor.handle = [];
    cursor.visible = true;
    cursor.textHandle = [];
    
    if isempty(state.cursors)
        state.cursors = cursor;
    else
        state.cursors(end + 1) = cursor;
    end
    
    state.awaitingClick = false;
    state.h.addCursorBtn.String = 'Add Cursor';
    fig.UserData = state;
    
    updateCursorsTable(fig);
    drawCursors(fig, ax);
end

function drawCursors(fig, ax)
    state = fig.UserData;
    if isempty(state.him) || ~isvalid(state.him)
        return
    end
    
    children = ax.Children;
    for i = length(children):-1:1
        child = children(i);
        if (isa(child, 'matlab.graphics.primitive.Line') && ...
           (isequal(child.Color, [1 0 0]) || isequal(child.Color, [0 0 0]))) || ...
           (isa(child, 'matlab.graphics.primitive.Patch') && ...
           isequal(child.FaceColor, [1 0 0]))
            delete(child);
        elseif isa(child, 'matlab.graphics.primitive.Text')
            delete(child);
        end
    end
    
    displayFrame = state.him.CData;
    
    if ~isempty(state.cursors)
        for i = 1:length(state.cursors)
            cursor = state.cursors(i);
            if ~isfield(cursor, 'visible')
                cursor.visible = true;
            end
            if ~isfield(cursor, 'textHandle')
                cursor.textHandle = [];
            end
            
            if ~cursor.visible
                state.cursors(i) = cursor;
                continue
            end
            
            row_min = cursor.rect(1);
            row_max = cursor.rect(2);
            col_min = cursor.rect(3);
            col_max = cursor.rect(4);
            
            isSelected = (~isempty(state.selectedCursorIndex) && state.selectedCursorIndex == i);
            
            if isSelected
                x = [col_min, col_max, col_max, col_min] - 0.5;
                y = [row_min, row_min, row_max, row_max] - 0.5;
                cursor.handle = patch(ax, x, y, 'r', 'FaceAlpha', 0.6, 'EdgeColor', 'r', 'LineWidth', 3, 'HitTest', 'off');
            else
                x = [col_min, col_max, col_max, col_min, col_min] - 0.5;
                y = [row_min, row_min, row_max, row_max, row_min] - 0.5;
                cursor.handle = line(ax, x, y, 'Color', 'k', 'LineWidth', 2, 'HitTest', 'off');
            end
            
            if state.showIosValues
                iosValue = computeCursorIos(state, cursor, displayFrame, state.iosMode, state.baseframeData, []);
                if ~isnan(iosValue) && isfinite(iosValue)
                    textX = col_max + 2;
                    textY = row_min;
                    cursor.textHandle = text(ax, textX, textY, sprintf('%.4f', iosValue), ...
                        'Color', 'yellow', 'FontSize', 10, 'FontWeight', 'bold', ...
                        'BackgroundColor', 'black', 'EdgeColor', 'yellow', 'Margin', 2);
                end
            end
            
            state.cursors(i) = cursor;
        end
    end
    
    if ~isempty(state.referenceCursor)
        refCursor = state.referenceCursor;
        if ~isempty(refCursor.handle) && isvalid(refCursor.handle)
            delete(refCursor.handle);
        end
        
        row_min = refCursor.rect(1);
        row_max = refCursor.rect(2);
        col_min = refCursor.rect(3);
        col_max = refCursor.rect(4);
        
        x = [col_min, col_max, col_max, col_min, col_min] - 0.5;
        y = [row_min, row_min, row_max, row_max, row_min] - 0.5;
        
        refCursor.handle = line(ax, x, y, 'Color', 'b', 'LineWidth', 2, 'HitTest', 'off');
        state.referenceCursor = refCursor;
    else
        children = ax.Children;
        for i = length(children):-1:1
            if isa(children(i), 'matlab.graphics.primitive.Line') && ...
               isequal(children(i).Color, [0 0 1])
                delete(children(i));
            end
        end
    end
    
    fig.UserData = state;
end

function meanIos = computeIosForRegion(state, rowRange, colRange, frameFiltered, baseframeData)
    frameRegion = double(frameFiltered(rowRange(1):rowRange(2), colRange(1):colRange(2)));
    baseRegion = double(baseframeData(rowRange(1):rowRange(2), colRange(1):colRange(2)));
    
    denom = baseRegion;
    denom(denom == 0) = NaN;
    iosRegion = (frameRegion - denom) ./ denom;
    
    meanIos = mean(iosRegion(:), 'omitnan');
end

function iosValue = computeCursorIos(state, cursor, displayFrame, iosMode, baseframeData, frameFiltered)
    rowRange = [cursor.rect(1), cursor.rect(2)];
    colRange = [cursor.rect(3), cursor.rect(4)];
    
    if iosMode
        cursorRegion = displayFrame(rowRange(1):rowRange(2), colRange(1):colRange(2));
        iosValue = mean(cursorRegion(:), 'omitnan');
    else
        if isempty(baseframeData) || isempty(frameFiltered)
            iosValue = NaN;
            return
        end
        frameRegion = double(frameFiltered(rowRange(1):rowRange(2), colRange(1):colRange(2)));
        baseRegion = double(baseframeData(rowRange(1):rowRange(2), colRange(1):colRange(2)));
        
        denom = baseRegion;
        denom(denom == 0) = NaN;
        iosRegion = (frameRegion - denom) ./ denom;
        
        iosValue = mean(iosRegion(:), 'omitnan');
        
        if ~isempty(state.referenceCursor)
            refCursor = state.referenceCursor;
            refRowRange = [refCursor.rect(1), refCursor.rect(2)];
            refColRange = [refCursor.rect(3), refCursor.rect(4)];
            refRegion = double(frameFiltered(refRowRange(1):refRowRange(2), refColRange(1):refColRange(2)));
            refBaseRegion = double(baseframeData(refRowRange(1):refRowRange(2), refColRange(1):refColRange(2)));
            refDenom = refBaseRegion;
            refDenom(refDenom == 0) = NaN;
            refIosRegion = (refRegion - refDenom) ./ refDenom;
            refIosValue = mean(refIosRegion(:), 'omitnan');
            iosValue = iosValue - refIosValue;
        end
    end
end

function onGetTraces(src, fig, ax)
    state = fig.UserData;
    hWaitbar = waitbar(0, 'Initializing...');
    drawnow;
    
    try
        fprintf('onGetTraces: Starting...\n');
        if ~hasValidMeta(fig)
            close(hWaitbar);
            fprintf('ERROR: No file loaded\n');
            return
        end
        if isempty(state.cursors)
            close(hWaitbar);
            fprintf('ERROR: No cursors added\n');
            return
        end
        fprintf('onGetTraces: Found %d cursors\n', length(state.cursors));
        
        if ~state.iosMode
            waitbar(0.05, hWaitbar, 'Enabling IOS mode...');
            drawnow;
            fprintf('onGetTraces: Enabling IOS mode\n');
            state.iosMode = true;
            state.h.iosCheck.Value = 1;
            vis = 'on';
            state.h.floatingBaseCheck.Visible = vis;
            state.h.baseDelayEdit.Visible = vis;
            if state.floatingBaseMode
                visBase = 'off';
            else
                visBase = vis;
            end
            state.h.baseStartEdit.Visible = visBase;
            state.h.baseEndEdit.Visible = visBase;
            state.h.setBaseBtn.Visible = visBase;
            fig.UserData = state;
        end
        
        meta = state.meta;
        totalFrames = meta.totalFrames;
        fprintf('onGetTraces: Total frames: %d\n', totalFrames);
        
        if ~state.floatingBaseMode
            waitbar(0.1, hWaitbar, 'Checking baseframe...');
            drawnow;
            fprintf('onGetTraces: Checking baseframe...\n');
            
            needBase = isempty(state.baseframeData) || isempty(state.baseframeRangeUsed) || ...
                state.baseframeStart ~= state.baseframeRangeUsed(1) || ...
                state.baseframeEnd ~= state.baseframeRangeUsed(2);
            if needBase
                waitbar(0.2, hWaitbar, 'Computing baseframe...');
                drawnow;
                fprintf('onGetTraces: Computing baseframe (frames %d-%d)...\n', state.baseframeStart, state.baseframeEnd);
                state = computeBaseframe(fig);
                state = fig.UserData;
                fprintf('onGetTraces: Baseframe computed\n');
            end
            if isempty(state.baseframeData)
                close(hWaitbar);
                fprintf('ERROR: Baseframe computation failed\n');
                return
            end
            base = double(state.baseframeData);
        end
        
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
        
        waitbar(0.3, hWaitbar, 'Reading and processing frames...');
        drawnow;
        fprintf('onGetTraces: Starting to read frames from %s\n', state.iosPath);
        
        batchSize = 100;
        for batchStart = 1:batchSize:totalFrames
            batchEnd = min(batchStart + batchSize - 1, totalFrames);
            progress = 0.3 + 0.65 * (batchStart / totalFrames);
            waitbar(progress, hWaitbar, sprintf('Reading frames %d-%d/%d...', batchStart, batchEnd, totalFrames));
            drawnow;
            fprintf('onGetTraces: Reading frames %d-%d/%d\n', batchStart, batchEnd, totalFrames);
            
            [data, t, ~] = readIOS2(state.iosPath, 'startframe', batchStart, 'endframe', batchEnd, 'Format', 'Lin');
            if isempty(data)
                fprintf('ERROR: Failed to read frames %d-%d\n', batchStart, batchEnd);
                close(hWaitbar);
                return
            end
            
            data = ensure2DFrame(data);
            times(batchStart:batchEnd) = t;
            
            for frameIdx = 1:size(data, 3)
                globalFrameIdx = batchStart + frameIdx - 1;
                currentTime = t(frameIdx);
                
                frame = double(data(:, :, frameIdx));
                frameFiltered = applyGaussianFilter(frame, state.gaussianSigma);
                
                if state.floatingBaseMode
                    baseframeData = computeFloatingBaseframe(fig, currentTime);
                    if isempty(baseframeData)
                        continue
                    end
                    base = double(baseframeData);
                end
                
                if ~isempty(state.referenceCursor)
                    refCursor = state.referenceCursor;
                    rowRange = [refCursor.rect(1), refCursor.rect(2)];
                    colRange = [refCursor.rect(3), refCursor.rect(4)];
                    
                    frameRegion = frameFiltered(rowRange(1):rowRange(2), colRange(1):colRange(2));
                    baseRegion = base(rowRange(1):rowRange(2), colRange(1):colRange(2));
                    
                    denom = baseRegion;
                    denom(denom == 0) = NaN;
                    iosRegion = (frameRegion - denom) ./ denom;
                    
                    refIosValue = mean(iosRegion(:), 'omitnan');
                    referenceTrace(globalFrameIdx) = refIosValue;
                end
                
                for cursorIdx = 1:numCursors
                    cursor = state.cursors(cursorIdx);
                    rowRange = [cursor.rect(1), cursor.rect(2)];
                    colRange = [cursor.rect(3), cursor.rect(4)];
                    
                    frameRegion = frameFiltered(rowRange(1):rowRange(2), colRange(1):colRange(2));
                    baseRegion = base(rowRange(1):rowRange(2), colRange(1):colRange(2));
                    
                    denom = baseRegion;
                    denom(denom == 0) = NaN;
                    iosRegion = (frameRegion - denom) ./ denom;
                    
                    meanIos = mean(iosRegion(:), 'omitnan');
                    traces{cursorIdx}(globalFrameIdx) = meanIos;
                end
            end
            fprintf('onGetTraces: Processed frames %d-%d\n', batchStart, batchEnd);
        end
        
        if ~isempty(referenceTrace)
            waitbar(0.95, hWaitbar, 'Applying reference correction...');
            drawnow;
            fprintf('onGetTraces: Applying reference correction to traces\n');
            for i = 1:numCursors
                traces{i} = traces{i} - referenceTrace;
            end
        end
        
        waitbar(0.95, hWaitbar, 'Creating plots...');
        drawnow;
        
        traceFig = figure('Name', 'IOS Traces', 'NumberTitle', 'off');
        numCursors = length(traces);
        cols = ceil(sqrt(numCursors));
        rows = ceil(numCursors / cols);
        
        for i = 1:numCursors
            subplot(rows, cols, i);
            plot(times, traces{i}, 'LineWidth', 1.5);
            xlabel('Time (s)');
            ylabel('IOS');
            title(sprintf('Cursor %d (row=%d, col=%d)', i, state.cursors(i).center(1), state.cursors(i).center(2)));
            grid on;
        end
        
        waitbar(1.0, hWaitbar, 'Complete!');
        drawnow;
        fprintf('onGetTraces: Complete! Created %d traces\n', numCursors);
        pause(0.5);
        close(hWaitbar);
        
    catch ME
        if exist('hWaitbar', 'var') && isvalid(hWaitbar)
            close(hWaitbar);
        end
        fprintf('ERROR in onGetTraces: %s\n', ME.message);
        fprintf('Stack trace:\n');
        for k = 1:length(ME.stack)
            fprintf('  %s at line %d\n', ME.stack(k).file, ME.stack(k).line);
        end
        rethrow(ME);
    end
end

function updateCursorsTable(fig)
    state = fig.UserData;
    if isempty(state.cursors)
        state.h.cursorsTable.Data = cell(0, 4);
    else
        numCursors = length(state.cursors);
        data = cell(numCursors, 4);
        for i = 1:numCursors
            cursor = state.cursors(i);
            if ~isfield(cursor, 'visible')
                cursor.visible = true;
                state.cursors(i) = cursor;
            end
            data{i, 1} = i;
            data{i, 2} = cursor.center(1);
            data{i, 3} = cursor.center(2);
            data{i, 4} = cursor.visible;
        end
        state.h.cursorsTable.Data = data;
    end
    fig.UserData = state;
end

function onCursorsTableEdit(src, event, fig, ax)
    state = fig.UserData;
    if isempty(state.cursors)
        return
    end
    if event.Indices(2) ~= 4
        return
    end
    rowIdx = event.Indices(1);
    if rowIdx < 1 || rowIdx > length(state.cursors)
        return
    end
    newValue = event.NewData;
    cursor = state.cursors(rowIdx);
    cursor.visible = logical(newValue);
    state.cursors(rowIdx) = cursor;
    fig.UserData = state;
    drawCursors(fig, ax);
end

function onShowIosCheck(src, fig, ax)
    state = fig.UserData;
    state.showIosValues = logical(src.Value);
    fig.UserData = state;
    drawCursors(fig, ax);
end

function onEditCursor(src, fig, ax)
    state = fig.UserData;
    if ~hasValidMeta(fig)
        return
    end
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
    
    state.awaitingClick = false;
    state.awaitingReferenceClick = false;
    state.editingCursorIndex = selectedRow;
    state.h.addCursorBtn.String = 'Add Cursor';
    state.h.addReferenceBtn.String = 'Add Reference';
    src.String = 'Click on image...';
    fig.UserData = state;
end

function deleteCursorGraphics(cursor)
    if ~isempty(cursor.handle) && isvalid(cursor.handle)
        delete(cursor.handle);
    end
    if isfield(cursor, 'textHandle') && ~isempty(cursor.textHandle) && isvalid(cursor.textHandle)
        delete(cursor.textHandle);
    end
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
    
    deleteCursorGraphics(state.cursors(selectedRow));
    state.cursors = state.cursors([1:selectedRow-1, selectedRow+1:end]);
    fig.UserData = state;
    
    updateCursorsTable(fig);
    drawCursors(fig, ax);
end

function onClearCursors(~, fig, ax)
    state = fig.UserData;
    if isempty(state.cursors)
        return
    end
    
    for i = 1:length(state.cursors)
        deleteCursorGraphics(state.cursors(i));
    end
    
    state.cursors = [];
    fig.UserData = state;
    
    updateCursorsTable(fig);
    drawCursors(fig, ax);
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
    ax = findobj(fig, 'Type', 'axes');
    if ~isempty(ax)
        drawCursors(fig, ax);
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
    fig.UserData = state;
    
    if hasValidMeta(fig)
        k = getCurrentFrame(state);
        showFrame(fig, ax, k);
    else
        drawCursors(fig, ax);
    end
end
