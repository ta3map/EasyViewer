function iosPlayerGUI(iosPath)
    if nargin < 1
        iosPath = '';
    end
    fig = figure('Name', 'IOS Player', 'NumberTitle', 'off', ...
        'Units', 'normalized', 'Position', [0.25 0.2 0.5 0.6]);
    ax = axes(fig, 'Units', 'normalized', 'Position', [0.1 0.45 0.8 0.5]);
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

    hAddCursorBtn = uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
        'Position', [0.44 0.22 0.1 0.03], 'String', 'Add Cursor');
    hGetTracesBtn = uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
        'Position', [0.56 0.22 0.1 0.03], 'String', 'Get Traces');

    h = struct('slider', hSlider, 'timeEdit', hTimeEdit, 'playBtn', hPlayBtn, ...
        'speedPopup', hSpeedPopup, 'openBtn', hOpenBtn, 'contrastSlider', hContrastSlider, ...
        'navStart', hNavStart, 'navPrev', hNavPrev, 'navNext', hNavNext, 'navEnd', hNavEnd, ...
        'iosCheck', hIosCheck, 'baseStartEdit', hBaseStartEdit, 'baseEndEdit', hBaseEndEdit, ...
        'setBaseBtn', hSetBaseBtn, 'gaussianSlider', hGaussianSlider, 'gaussianEdit', hGaussianEdit, ...
        'addCursorBtn', hAddCursorBtn, 'getTracesBtn', hGetTracesBtn);
    state = struct('iosPath', iosPath, 'meta', [], 'playTimer', [], 'clim', [0 65535], 'h', h, 'him', [], ...
        'iosMode', false, 'baseframeStart', 1, 'baseframeEnd', 1, 'baseframeData', [], 'baseframeRangeUsed', [], ...
        'gaussianSigma', 3.0, 'climIosBase', [], 'cursors', [], 'awaitingClick', false);
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
    hAddCursorBtn.Callback = @(src,~) onAddCursor(src, fig, ax);
    hGetTracesBtn.Callback = @(src,~) onGetTraces(src, fig, ax);

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

function openFile(fig, ax, fname)
    state = fig.UserData;
    if ~isempty(state.playTimer) && isvalid(state.playTimer)
        stop(state.playTimer);
        delete(state.playTimer);
        state.playTimer = [];
        state.h.playBtn.String = 'Play';
    end
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
    state.cursors = [];
    state.awaitingClick = false;
    fig.UserData = state;

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
        frameD = double(frame);
        frameD = applyGaussianFilter(frameD, state.gaussianSigma);
        base = double(state.baseframeData);
        denom = base;
        denom(denom == 0) = NaN;
        iosFrame = (frameD - denom) ./ denom;
        displayFrame = iosFrame;
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
    state.h.baseStartEdit.Visible = vis;
    state.h.baseEndEdit.Visible = vis;
    state.h.setBaseBtn.Visible = vis;
    fig.UserData = state;
    k = getCurrentFrame(state);
    showFrame(fig, ax, k);
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
    src.String = 'Click on image...';
    fig.UserData = state;
end

function onImageClick(fig, ax)
    state = fig.UserData;
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
    
    if isempty(state.cursors)
        state.cursors = cursor;
    else
        state.cursors(end + 1) = cursor;
    end
    
    state.awaitingClick = false;
    state.h.addCursorBtn.String = 'Add Cursor';
    fig.UserData = state;
    
    drawCursors(fig, ax);
end

function drawCursors(fig, ax)
    state = fig.UserData;
    if isempty(state.cursors) || isempty(state.him) || ~isvalid(state.him)
        return
    end
    
    for i = 1:length(state.cursors)
        cursor = state.cursors(i);
        if ~isempty(cursor.handle) && isvalid(cursor.handle)
            delete(cursor.handle);
        end
        
        row_min = cursor.rect(1);
        row_max = cursor.rect(2);
        col_min = cursor.rect(3);
        col_max = cursor.rect(4);
        
        x = [col_min, col_max, col_max, col_min, col_min] - 0.5;
        y = [row_min, row_min, row_max, row_max, row_min] - 0.5;
        
        cursor.handle = line(ax, x, y, 'Color', 'r', 'LineWidth', 2, 'HitTest', 'off');
        state.cursors(i) = cursor;
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
            state.h.baseStartEdit.Visible = vis;
            state.h.baseEndEdit.Visible = vis;
            state.h.setBaseBtn.Visible = vis;
            fig.UserData = state;
        end
        
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
        
        meta = state.meta;
        totalFrames = meta.totalFrames;
        fprintf('onGetTraces: Total frames: %d\n', totalFrames);
        
        numCursors = length(state.cursors);
        traces = cell(numCursors, 1);
        for i = 1:numCursors
            traces{i} = zeros(totalFrames, 1);
        end
        times = zeros(totalFrames, 1);
        
        base = double(state.baseframeData);
        
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
                
                frame = double(data(:, :, frameIdx));
                frameFiltered = applyGaussianFilter(frame, state.gaussianSigma);
                
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
