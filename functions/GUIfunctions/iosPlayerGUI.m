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
        'Position', [0.5 0.26 0.15 0.03], 'Min', 0, 'Max', 20, 'Value', 1);
    hGaussianEdit = uicontrol(fig, 'Style', 'edit', 'Units', 'normalized', ...
        'Position', [0.67 0.26 0.05 0.03], 'String', '1.0');
    hSubtractMeanCheck = uicontrol(fig, 'Style', 'checkbox', 'Units', 'normalized', ...
        'Position', [0.74 0.26 0.12 0.03], 'String', 'Subtract mean', 'Value', 0);
    hIosCheck = uicontrol(fig, 'Style', 'checkbox', 'Units', 'normalized', ...
        'Position', [0.1 0.22 0.04 0.03], 'String', 'IOS', 'Value', 0);
    hBaseStartEdit = uicontrol(fig, 'Style', 'edit', 'Units', 'normalized', ...
        'Position', [0.16 0.22 0.06 0.03], 'String', '1', 'Visible', 'off');
    hBaseEndEdit = uicontrol(fig, 'Style', 'edit', 'Units', 'normalized', ...
        'Position', [0.24 0.22 0.06 0.03], 'String', '1', 'Visible', 'off');
    hSetBaseBtn = uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
        'Position', [0.32 0.22 0.1 0.03], 'String', 'Set baseframe', 'Visible', 'off');

    h = struct('slider', hSlider, 'timeEdit', hTimeEdit, 'playBtn', hPlayBtn, ...
        'speedPopup', hSpeedPopup, 'openBtn', hOpenBtn, 'contrastSlider', hContrastSlider, ...
        'navStart', hNavStart, 'navPrev', hNavPrev, 'navNext', hNavNext, 'navEnd', hNavEnd, ...
        'iosCheck', hIosCheck, 'baseStartEdit', hBaseStartEdit, 'baseEndEdit', hBaseEndEdit, ...
        'setBaseBtn', hSetBaseBtn, 'gaussianSlider', hGaussianSlider, 'gaussianEdit', hGaussianEdit, ...
        'subtractMeanCheck', hSubtractMeanCheck);
    state = struct('iosPath', iosPath, 'meta', [], 'playTimer', [], 'clim', [0 65535], 'h', h, 'him', [], ...
        'iosMode', false, 'baseframeStart', 1, 'baseframeEnd', 1, 'baseframeData', [], 'baseframeRangeUsed', [], ...
        'gaussianSigma', 1.0, 'subtractMean', false);
    fig.UserData = state;

    hSlider.Callback = @(src,~) onSlider(src, fig, ax);
    hTimeEdit.Callback = @(src,~) onTimeEdit(src, fig, ax);
    hPlayBtn.Callback = @(src,~) onPlayPause(src, fig, ax);
    hOpenBtn.Callback = @(src,~) onOpen(src, fig, ax);
    hContrastSlider.Callback = @(src,~) onContrast(src, fig, ax);
    hGaussianSlider.Callback = @(src,~) onGaussianSlider(src, fig, ax);
    hGaussianEdit.Callback = @(src,~) onGaussianEdit(src, fig, ax);
    hSubtractMeanCheck.Callback = @(src,~) onSubtractMean(src, fig, ax);
    hNavStart.Callback = @(src,~) onNav(src, fig, ax, 'start');
    hNavPrev.Callback = @(src,~) onNav(src, fig, ax, 'prev');
    hNavNext.Callback = @(src,~) onNav(src, fig, ax, 'next');
    hNavEnd.Callback = @(src,~) onNav(src, fig, ax, 'end');
    hIosCheck.Callback = @(src,~) onIosCheck(src, fig, ax);
    hSetBaseBtn.Callback = @(src,~) onSetBaseframe(src, fig, ax);
    hBaseStartEdit.Callback = @(src,~) onBaseRangeEdit(src, fig, ax, 'start');
    hBaseEndEdit.Callback = @(src,~) onBaseRangeEdit(src, fig, ax, 'end');

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

function state = computeBaseframe(fig)
    state = fig.UserData;
    if isempty(state.meta)
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
    if ndims(data) == 4
        data = squeeze(data);
    end
    if ndims(data) == 3
        for i = 1:size(data, 3)
            fr = applyGaussianFilter(data(:, :, i), state.gaussianSigma);
            if state.subtractMean
                fr = fr - mean(fr(:));
            end
            data(:, :, i) = fr;
        end
        state.baseframeData = mean(data, 3);
    else
        fr = applyGaussianFilter(data, state.gaussianSigma);
        if state.subtractMean
            fr = fr - mean(fr(:));
        end
        state.baseframeData = fr;
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
    state.baseframeData = [];
    state.baseframeStart = 1;
    n20 = 1;
    if meta.dt > 0
        n20 = round(20 / meta.dt);
    end
    state.baseframeEnd = min(meta.totalFrames, 1 + n20);
    state.h.baseStartEdit.String = num2str(state.baseframeStart);
    state.h.baseEndEdit.String = num2str(state.baseframeEnd);
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
    if isempty(state.meta)
        return
    end
    [data, t, ~] = readIOS2(state.iosPath, 'startframe', k, 'endframe', k, 'Format', 'Lin');
    if isempty(data) || any(isnan(data(:)))
        return
    end
    if ndims(data) == 4
        frame = squeeze(data);
    else
        frame = data;
    end
    if ndims(frame) ~= 2
        return
    end
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
        base = state.baseframeData;
        if ~isequal(size(frame), size(base))
            state.h.timeEdit.String = sec2timeStr(t(1));
            state.h.slider.Value = k;
            fig.UserData = state;
            return
        end
        frameD = double(frame);
        frameD = applyGaussianFilter(frameD, state.gaussianSigma);
        if state.subtractMean
            frameD = frameD - mean(frameD(:));
        end
        denom = double(base);
        denom(denom == 0) = NaN;
        iosFrame = (frameD - denom) ./ denom;
        displayFrame = iosFrame;
        climIos = max(abs(displayFrame(:)));
        if ~isfinite(climIos) || climIos == 0
            climIos = 0.01;
        end
        climIos = [-climIos climIos];
    else
        frameD = double(frame);
        displayFrame = applyGaussianFilter(frameD, state.gaussianSigma);
        if state.subtractMean
            displayFrame = displayFrame - mean(displayFrame(:));
        end
        climIos = [];
    end
    if ndims(displayFrame) ~= 2
        return
    end
    if isempty(state.him) || ~isvalid(state.him)
        state.clim = [min(frame(:)) max(frame(:))];
        state.him = imagesc(ax, displayFrame);
        axis(ax, 'image');
        axis(ax, 'off');
    else
        state.him.CData = displayFrame;
    end
    ax.YDir = 'normal';
    if state.iosMode && ~isempty(climIos)
        ax.CLim = climIos;
    else
        c = double(state.h.contrastSlider.Value);
        center = double(state.clim(1) + state.clim(2)) / 2;
        half = double(state.clim(2) - state.clim(1)) / 2;
        ax.CLim = center + (half / c) * [-1 1];
    end

    state.h.timeEdit.String = sec2timeStr(t(1));
    state.h.slider.Value = k;
    fig.UserData = state;
end

function onSlider(src, fig, ax)
    state = fig.UserData;
    if isempty(state.meta)
        return
    end
    k = round(src.Value);
    k = max(1, min(k, state.meta.totalFrames));
    showFrame(fig, ax, k);
end

function onNav(~, fig, ax, where)
    state = fig.UserData;
    if isempty(state.meta)
        return
    end
    N = state.meta.totalFrames;
    cur = round(state.h.slider.Value);
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
    state = fig.UserData;
    if isempty(state.meta)
        return
    end
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
    state = fig.UserData;
    if isempty(state.meta)
        return
    end
    if ~isempty(state.playTimer) && isvalid(state.playTimer)
        stop(state.playTimer);
        delete(state.playTimer);
        state.playTimer = [];
        src.String = 'Play';
        fig.UserData = state;
        return
    end
    N = state.meta.totalFrames;
    cur = round(state.h.slider.Value);
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
    end
    state.h.baseStartEdit.Visible = vis;
    state.h.baseEndEdit.Visible = vis;
    state.h.setBaseBtn.Visible = vis;
    fig.UserData = state;
    k = round(state.h.slider.Value);
    showFrame(fig, ax, k);
end

function onSetBaseframe(~, fig, ax)
    state = fig.UserData;
    if isempty(state.meta)
        return
    end
    cur = round(state.h.slider.Value);
    state.baseframeStart = cur;
    n20 = 20;
    if state.meta.dt > 0
        n20 = round(20 / state.meta.dt);
    end
    state.baseframeEnd = min(state.meta.totalFrames, cur + n20);
    state.baseframeData = [];
    state.baseframeRangeUsed = [];
    state.h.baseStartEdit.String = num2str(state.baseframeStart);
    state.h.baseEndEdit.String = num2str(state.baseframeEnd);
    fig.UserData = state;
    if state.iosMode
        k = round(state.h.slider.Value);
        showFrame(fig, ax, k);
    end
end

function onBaseRangeEdit(src, fig, ax, which)
    state = fig.UserData;
    if isempty(state.meta)
        return
    end
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
    state.baseframeData = [];
    state.baseframeRangeUsed = [];
    fig.UserData = state;
    if state.iosMode
        k = round(state.h.slider.Value);
        showFrame(fig, ax, k);
    end
end

function onGaussianSlider(src, fig, ax)
    state = fig.UserData;
    sigma = double(src.Value);
    state.gaussianSigma = sigma;
    state.h.gaussianEdit.String = sprintf('%.2f', sigma);
    state.baseframeData = [];
    state.baseframeRangeUsed = [];
    fig.UserData = state;
    if ~isempty(state.meta)
        k = round(state.h.slider.Value);
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
    state.baseframeData = [];
    state.baseframeRangeUsed = [];
    fig.UserData = state;
    if ~isempty(state.meta)
        k = round(state.h.slider.Value);
        showFrame(fig, ax, k);
    end
end

function onSubtractMean(src, fig, ax)
    state = fig.UserData;
    state.subtractMean = logical(src.Value);
    state.baseframeData = [];
    state.baseframeRangeUsed = [];
    fig.UserData = state;
    if ~isempty(state.meta)
        k = round(state.h.slider.Value);
        showFrame(fig, ax, k);
    end
end

function onContrast(~, fig, ax)
    state = fig.UserData;
    if isempty(state.meta) || isempty(state.him) || ~isvalid(state.him)
        return
    end
    c = double(state.h.contrastSlider.Value);
    center = double(state.clim(1) + state.clim(2)) / 2;
    half = double(state.clim(2) - state.clim(1)) / 2;
    ax.CLim = center + (half / c) * [-1 1];
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
