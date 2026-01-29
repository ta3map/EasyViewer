function result = autoIosVideo(filePath, fileId, params)
    if isempty(filePath) || ~exist(filePath, 'file')
        result = [];
        return
    end
    
    meta = readIOS2(filePath, 'metadataOnly', true);
    if isempty(meta)
        result = [];
        return
    end
    
    iosMode = params.ios_mode;
    floatingBaseMode = params.floating_base;
    baseframeDurationSeconds = params.baseframe_duration_seconds;
    gaussianSigma = params.gaussian_sigma;
    contrast = params.contrast;
    speed = params.speed;
    outputFolder = params.output_folder;
    
    fig = figure('Name', 'IOS Video Recording', 'NumberTitle', 'off', ...
        'Units', 'normalized', 'Position', [0.25 0.25 0.5 0.5], 'Visible', 'on');
    ax = axes(fig, 'Units', 'normalized', 'Position', [0.1 0.1 0.8 0.8]);
    colormap(fig, gray);
    
    state = struct('iosPath', filePath, 'meta', meta, 'him', [], 'timeText', [], ...
        'iosMode', iosMode, 'baseframeStart', 1, 'baseframeEnd', 1, 'baseframeData', [], 'baseframeRangeUsed', [], ...
        'gaussianSigma', gaussianSigma, 'floatingBaseMode', floatingBaseMode, ...
        'baseDelay', baseframeDurationSeconds, 'contrast', contrast, 'clim', [0 65535], 'climIosBase', []);
    
    if ~floatingBaseMode
        state.baseframeStart = 1;
        nFrames = 1;
        if meta.dt > 0
            nFrames = round(baseframeDurationSeconds / meta.dt);
        end
        state.baseframeEnd = min(meta.totalFrames, 1 + nFrames);
    end
    
    fig.UserData = state;
    
    if ~floatingBaseMode && iosMode
        state = computeBaseframe(fig);
        state = fig.UserData;
    end
    
    [fileDir, fileName, ~] = fileparts(filePath);
    if isempty(fileDir)
        fileDir = pwd;
    end
    
    if isempty(outputFolder)
        outputPath = fullfile(fileDir, [fileName, '.mp4']);
    else
        if isabsolutepath(outputFolder)
            outputDir = outputFolder;
        else
            outputDir = fullfile(fileDir, outputFolder);
        end
        if ~exist(outputDir, 'dir')
            mkdir(outputDir);
        end
        outputPath = fullfile(outputDir, [fileName, '.mp4']);
    end
    
    stepSize = max(1, round(speed));
    totalFrames = meta.totalFrames;
    
    if meta.dt > 0
        frameRate = 1 / meta.dt;
    else
        frameRate = 30;
    end
    
    if frameRate <= 0
        frameRate = 30;
    end
    
    v = VideoWriter(outputPath, 'MPEG-4');
    v.FrameRate = frameRate;
    open(v);
    
    framesToRecord = 1:stepSize:totalFrames;
    numFramesToRecord = length(framesToRecord);
    
    try
        for idx = 1:numFramesToRecord
            k = framesToRecord(idx);
            showFrame(fig, ax, k);
            drawnow;
            
            frame = getframe(fig);
            writeVideo(v, frame);
        end
        
        close(v);
        close(fig);
        
        result = struct( ...
            'module_name', 'autoIosVideo', ...
            'module_display_name', 'Auto IOS Video', ...
            'module_description', 'Автоматическое сохранение видео iOS', ...
            'report_path', outputPath, ...
            'parameters', params);
    catch ME
        if ~isempty(v) && isvalid(v)
            close(v);
        end
        if ishandle(fig)
            close(fig);
        end
        rethrow(ME);
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

function data = ensure2DFrame(data)
    if ndims(data) == 4
        data = squeeze(data);
    end
end

function applyContrast(ax, baseRange, contrastValue)
    center = double(baseRange(1) + baseRange(2)) / 2;
    half = double(baseRange(2) - baseRange(1)) / 2;
    ax.CLim = center + (half / contrastValue) * [-1 1];
end

function state = computeBaseframe(fig)
    state = fig.UserData;
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

function showFrame(fig, ax, k)
    state = fig.UserData;
    [data, t, ~] = readIOS2(state.iosPath, 'startframe', k, 'endframe', k, 'Format', 'Lin');
    if isempty(data) || any(isnan(data(:)))
        return
    end
    frame = ensure2DFrame(data);
    if state.iosMode
        if state.floatingBaseMode
            baseframeData = computeFloatingBaseframe(fig, t(1));
            if isempty(baseframeData)
                return
            end
            base = double(baseframeData);
        else
            if isempty(state.baseframeData)
                state = computeBaseframe(fig);
                state = fig.UserData;
            end
            if isempty(state.baseframeData)
                return
            end
            base = double(state.baseframeData);
        end
        frameD = double(frame);
        frameD = applyGaussianFilter(frameD, state.gaussianSigma);
        denom = base;
        denom(denom == 0) = NaN;
        displayFrame = (frameD - denom) ./ denom;
        
        climIos = max(abs(displayFrame(:)));
        if ~isfinite(climIos) || climIos == 0
            climIos = 0.01;
        end
        state.climIosBase = [-climIos climIos];
        applyContrast(ax, state.climIosBase, state.contrast);
    else
        frameD = double(frame);
        displayFrame = applyGaussianFilter(frameD, state.gaussianSigma);
        state.clim = [min(frame(:)) max(frame(:))];
        applyContrast(ax, state.clim, state.contrast);
    end
    if isempty(state.him) || ~isvalid(state.him)
        cla(ax);
        state.him = imagesc(ax, displayFrame);
        axis(ax, 'image');
        axis(ax, 'off');
    else
        state.him.CData = displayFrame;
    end
    ax.YDir = 'normal';
    
    timeStr = sec2timeStr(t(1));
    if isempty(state.timeText) || ~isvalid(state.timeText)
        state.timeText = text(ax, 0.02, 0.98, timeStr, ...
            'Units', 'normalized', 'Color', 'yellow', 'FontSize', 14, ...
            'FontWeight', 'bold', 'BackgroundColor', 'black', ...
            'EdgeColor', 'yellow', 'Margin', 5, 'VerticalAlignment', 'top');
    else
        state.timeText.String = timeStr;
    end
    
    fig.UserData = state;
end

function s = sec2timeStr(sec)
    m = floor(sec / 60);
    sVal = sec - m * 60;
    s = sprintf('%d:%05.2f', m, sVal);
end

function isAbs = isabsolutepath(path)
    if isempty(path)
        isAbs = false;
        return
    end
    if ispc
        isAbs = length(path) >= 2 && path(2) == ':';
    else
        isAbs = length(path) >= 1 && path(1) == '/';
    end
end
