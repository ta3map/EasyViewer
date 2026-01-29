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
    probeCount = params.probe;
    smoothingWindow = params.smoothing_window;
    
    fig = figure('Name', 'IOS Video Recording', 'NumberTitle', 'off', ...
        'Units', 'normalized', 'Position', [0.25 0.15 0.5 0.7], 'Visible', 'on');
    ax = axes(fig, 'Units', 'normalized', 'Position', [0.1 0.15 0.6 0.75]);
    chartAx = axes(fig, 'Units', 'normalized', 'Position', [0.75 0.1 0.2 0.8], 'Visible', 'off');
    colormap(fig, gray);
    
    [~, fileName, ~] = fileparts(filePath);
    
    totalTime = 0;
    if meta.totalFrames > 0
        [~, tLast, ~] = readIOS2(filePath, 'startframe', meta.totalFrames, 'endframe', meta.totalFrames, 'Format', 'Lin');
        if ~isempty(tLast)
            totalTime = tLast(1);
        end
    end
    totalTimeStr = sec2timeStr(totalTime);
    
    hTimeEdit = uicontrol(fig, 'Style', 'edit', 'Units', 'normalized', ...
        'Position', [0.1 0.05 0.6 0.04], 'String', sprintf('0:00.00 / %s', totalTimeStr), ...
        'HorizontalAlignment', 'center', 'Enable', 'inactive', 'BackgroundColor', 'white');
    
    probeHintText = [];
    if probeCount > 0
        probeHintText = uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
            'Position', [0.1 0.92 0.6 0.03], 'String', sprintf('%s - Click to add %d probe(s)', fileName, probeCount), ...
            'HorizontalAlignment', 'center', 'FontSize', 12, 'FontWeight', 'bold');
    else
        probeHintText = uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
            'Position', [0.1 0.92 0.6 0.03], 'String', fileName, ...
            'HorizontalAlignment', 'center', 'FontSize', 12, 'FontWeight', 'bold');
    end
    
    state = struct('iosPath', filePath, 'meta', meta, 'him', [], 'timeEdit', hTimeEdit, 'probeHintText', probeHintText, ...
        'iosMode', iosMode, 'baseframeStart', 1, 'baseframeEnd', 1, 'baseframeData', [], 'baseframeRangeUsed', [], ...
        'gaussianSigma', gaussianSigma, 'floatingBaseMode', floatingBaseMode, ...
        'baseDelay', baseframeDurationSeconds, 'contrast', contrast, 'clim', [0 65535], 'climIosBase', [], ...
        'probeCount', probeCount, 'probes', [], 'awaitingProbeClick', false, 'probeData', [], 'probeHandles', [], ...
        'probesReady', false, 'chartAx', chartAx, 'chartLines', [], 'chartRawData', struct('x', {}, 'y', {}), ...
        'probeTimes', [], 'chartSmoothingWindow', smoothingWindow, 'totalTime', totalTime, 'fileName', fileName);
    
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
    
    numProbes = 0;
    probeTimes = [];
    if probeCount > 0
        showFrame(fig, ax, 1);
        drawnow;
        
        uiwait(fig);
        
        state = fig.UserData;
        numProbes = length(state.probes);
        state.probeData = cell(numProbes, 1);
        state.probeTimes = [];
        for i = 1:numProbes
            state.probeData{i} = [];
        end
        probeTimes = [];
        fig.UserData = state;
    end
    
    v = VideoWriter(outputPath, 'MPEG-4');
    v.FrameRate = frameRate;
    open(v);
    
    framesToRecord = 1:stepSize:totalFrames;
    numFramesToRecord = length(framesToRecord);
    
    try
        for idx = 1:numFramesToRecord
            k = framesToRecord(idx);
            [data, t, ~] = readIOS2(filePath, 'startframe', k, 'endframe', k, 'Format', 'Lin');
            if isempty(data) || any(isnan(data(:)))
                continue
            end
            
            showFrame(fig, ax, k, data, t);
            drawnow;
            
            if probeCount > 0 && ~isempty(state.probes)
                state = fig.UserData;
                frame = ensure2DFrame(data);
                frameD = double(frame);
                frameFiltered = applyGaussianFilter(frameD, state.gaussianSigma);
                
                if state.iosMode
                    if state.floatingBaseMode
                        baseframeData = computeFloatingBaseframe(fig, t(1));
                        if isempty(baseframeData)
                            base = [];
                        else
                            base = double(baseframeData);
                        end
                    else
                        if isempty(state.baseframeData)
                            state = computeBaseframe(fig);
                            state = fig.UserData;
                        end
                        base = double(state.baseframeData);
                    end
                    
                    if ~isempty(base)
                        for probeIdx = 1:numProbes
                            probe = state.probes(probeIdx);
                            rowRange = [probe.rect(1), probe.rect(2)];
                            colRange = [probe.rect(3), probe.rect(4)];
                            
                            frameRegion = frameFiltered(rowRange(1):rowRange(2), colRange(1):colRange(2));
                            baseRegion = base(rowRange(1):rowRange(2), colRange(1):colRange(2));
                            
                            denom = baseRegion;
                            denom(denom == 0) = NaN;
                            iosRegion = (frameRegion - denom) ./ denom;
                            
                            meanIos = mean(iosRegion(:), 'omitnan');
                            state.probeData{probeIdx}(end + 1) = meanIos;
                        end
                        state.probeTimes(end + 1) = t(1);
                        probeTimes(end + 1) = t(1);
                    end
                else
                    for probeIdx = 1:numProbes
                        probe = state.probes(probeIdx);
                        rowRange = [probe.rect(1), probe.rect(2)];
                        colRange = [probe.rect(3), probe.rect(4)];
                        
                        region = frameFiltered(rowRange(1):rowRange(2), colRange(1):colRange(2));
                        meanVal = mean(region(:), 'omitnan');
                        state.probeData{probeIdx}(end + 1) = meanVal;
                    end
                    state.probeTimes(end + 1) = t(1);
                    probeTimes(end + 1) = t(1);
                end
                fig.UserData = state;
                updateChart(fig, ax, t(1));
            end
            
            frame = getframe(fig);
            writeVideo(v, frame);
        end
        
        close(v);
        
        state = fig.UserData;
        if probeCount > 0 && ~isempty(state.probes) && ~isempty(state.probeData)
            createProbeTracesFigure(state.probes, state.probeData, probeTimes, outputPath);
        end
        
        close(fig);
        
        probeDataResult = [];
        if probeCount > 0 && ~isempty(state.probes) && ~isempty(state.probeData)
            probeDataResult = struct();
            for i = 1:length(state.probes)
                probeDataResult(i).center = state.probes(i).center;
                probeDataResult(i).rect = state.probes(i).rect;
                probeDataResult(i).data = state.probeData{i};
                if ~isempty(probeTimes)
                    probeDataResult(i).times = probeTimes;
                end
            end
        end
        
        result = struct( ...
            'module_name', 'autoIosVideo', ...
            'module_display_name', 'Auto IOS Video', ...
            'module_description', 'Автоматическое сохранение видео iOS', ...
            'report_path', outputPath, ...
            'parameters', params);
        
        if ~isempty(probeDataResult)
            result.probe_data = probeDataResult;
        end
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

function showFrame(fig, ax, k, data, t)
    state = fig.UserData;
    if nargin < 4
        [data, t, ~] = readIOS2(state.iosPath, 'startframe', k, 'endframe', k, 'Format', 'Lin');
        if isempty(data) || any(isnan(data(:)))
            return
        end
    end
    if isempty(data) || any(isnan(data(:)))
        return
    end
    frame = ensure2DFrame(data);
    
    if state.probeCount > 0 && length(state.probes) < state.probeCount
        displayFrame = double(frame);
        if isempty(state.him) || ~isvalid(state.him)
            cla(ax);
            state.him = imagesc(ax, displayFrame);
            axis(ax, 'image');
            axis(ax, 'off');
            state.him.ButtonDownFcn = @(~,~) onProbeClick(fig, ax);
        else
            state.him.CData = displayFrame;
        end
        ax.YDir = 'normal';
        ax.CLim = [min(frame(:)) max(frame(:))];
        
        timeStr = sec2timeStr(t(1));
        totalTimeStr = sec2timeStr(state.totalTime);
        state.timeEdit.String = sprintf('%s / %s', timeStr, totalTimeStr);
        
        remainingProbes = state.probeCount - length(state.probes);
        if remainingProbes > 0 && ~isempty(state.probeHintText) && isvalid(state.probeHintText)
            state.probeHintText.String = sprintf('%s - Click to add %d more probe(s)', state.fileName, remainingProbes);
        elseif remainingProbes == 0 && ~isempty(state.probeHintText) && isvalid(state.probeHintText)
            state.probeHintText.String = state.fileName;
        end
        
        drawProbes(fig, ax);
        fig.UserData = state;
        return
    end
    
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
        if isempty(state.clim) || state.clim(1) == 0 && state.clim(2) == 65535
            state.clim = [min(frame(:)) max(frame(:))];
        end
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
    totalTimeStr = sec2timeStr(state.totalTime);
    state.timeEdit.String = sprintf('%s / %s', timeStr, totalTimeStr);
    
    if state.probeCount > 0
        if ~isempty(state.probes)
            drawProbes(fig, ax);
        end
        remainingProbes = state.probeCount - length(state.probes);
        if remainingProbes > 0 && ~isempty(state.probeHintText) && isvalid(state.probeHintText)
            state.probeHintText.String = sprintf('%s - Click to add %d more probe(s)', state.fileName, remainingProbes);
        elseif remainingProbes == 0 && ~isempty(state.probeHintText) && isvalid(state.probeHintText)
            state.probeHintText.String = state.fileName;
        end
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

function onProbeClick(fig, ax)
    state = fig.UserData;
    if state.probeCount <= 0 || length(state.probes) >= state.probeCount
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
    
    probe = struct();
    probe.center = [row, col];
    probe.rect = [row_min, row_max, col_min, col_max];
    probe.handle = [];
    
    numProbes = length(state.probes);
    colors = getColors(numProbes + 1);
    probe.color = colors{numProbes + 1};
    
    if isempty(state.probes)
        state.probes = probe;
    else
        state.probes(end + 1) = probe;
    end
    
    remainingProbes = state.probeCount - length(state.probes);
    if remainingProbes > 0 && ~isempty(state.probeHintText) && isvalid(state.probeHintText)
        state.probeHintText.String = sprintf('%s - Click to add %d more probe(s)', state.fileName, remainingProbes);
    elseif remainingProbes == 0 && ~isempty(state.probeHintText) && isvalid(state.probeHintText)
        state.probeHintText.String = state.fileName;
    end
    
    fig.UserData = state;
    
    showFrame(fig, ax, 1);
    
    if length(state.probes) >= state.probeCount
        uiresume(fig);
    end
end

function drawProbes(fig, ax)
    state = fig.UserData;
    if isempty(state.probes) || isempty(state.him) || ~isvalid(state.him)
        return
    end
    
    if isempty(state.probeHandles)
        state.probeHandles = [];
    end
    
    for i = 1:length(state.probeHandles)
        if ~isempty(state.probeHandles(i)) && isvalid(state.probeHandles(i))
            delete(state.probeHandles(i));
        end
    end
    
    state.probeHandles = [];
    
    for i = 1:length(state.probes)
        probe = state.probes(i);
        row_min = probe.rect(1);
        row_max = probe.rect(2);
        col_min = probe.rect(3);
        col_max = probe.rect(4);
        
        x = [col_min, col_max, col_max, col_min, col_min] - 0.5;
        y = [row_min, row_min, row_max, row_max, row_min] - 0.5;
        
        probeColor = hex2rgb(probe.color);
        hLine = line(ax, x, y, 'Color', probeColor, 'LineWidth', 2, 'HitTest', 'off');
        state.probeHandles(end + 1) = hLine;
    end
    
    fig.UserData = state;
end

function updateChart(fig, ax, t)
    state = fig.UserData;
    if state.probeCount <= 0 || isempty(state.probes) || isempty(state.probeData)
        return
    end
    
    chartAx = state.chartAx;
    numProbes = length(state.probes);
    
    if isempty(state.chartLines) || length(state.chartLines) ~= numProbes
        cla(chartAx);
        hold(chartAx, 'on');
        chartLines = [];
        colors = getColors(numProbes);
        for i = 1:numProbes
            probeColor = hex2rgb(colors{i});
            hLine = plot(chartAx, NaN, NaN, 'Color', probeColor, 'LineWidth', 1.5);
            chartLines = [chartLines; hLine];
        end
        state.chartLines = chartLines;
        state.chartRawData = struct('x', {}, 'y', {});
        for i = 1:numProbes
            state.chartRawData(i).x = [];
            state.chartRawData(i).y = [];
        end
        xlabel(chartAx, 'Time (s)');
        ylabel(chartAx, 'IOS');
        grid(chartAx, 'on');
        chartAx.Visible = 'on';
    end
    
    if ~isfield(state, 'chartRawData') || isempty(state.chartRawData)
        for i = 1:numProbes
            state.chartRawData(i).x = [];
            state.chartRawData(i).y = [];
        end
    end
    
    for probeIdx = 1:numProbes
        if probeIdx <= length(state.probeData) && ~isempty(state.probeData{probeIdx})
            if probeIdx <= length(state.chartRawData) && ~isempty(state.probeTimes)
                dataLen = length(state.probeData{probeIdx});
                timeLen = length(state.probeTimes);
                if dataLen <= timeLen
                    state.chartRawData(probeIdx).x = state.probeTimes(1:dataLen);
                    state.chartRawData(probeIdx).y = state.probeData{probeIdx};
                end
            end
        end
    end
    
    for probeIdx = 1:numProbes
        if probeIdx <= length(state.chartLines) && ~isempty(state.chartLines(probeIdx)) && ...
           probeIdx <= length(state.chartRawData)
            h = state.chartLines(probeIdx);
            if ishghandle(h)
                xRaw = state.chartRawData(probeIdx).x;
                yRaw = state.chartRawData(probeIdx).y;
                if ~isempty(xRaw) && ~isempty(yRaw)
                    if state.chartSmoothingWindow > 1 && length(xRaw) >= state.chartSmoothingWindow
                        [xSmoothed, ySmoothed] = applySmoothingToChartData(xRaw, yRaw, state.chartSmoothingWindow);
                        set(h, 'XData', xSmoothed, 'YData', ySmoothed);
                    else
                        set(h, 'XData', xRaw, 'YData', yRaw);
                    end
                end
            end
        end
    end
    
    fig.UserData = state;
end

function [xSmoothed, ySmoothed] = applySmoothingToChartData(xData, yData, windowSize)
    if windowSize <= 1 || length(yData) < windowSize
        xSmoothed = xData;
        ySmoothed = yData;
        return
    end
    
    windowSize = round(windowSize);
    if windowSize < 1
        windowSize = 1;
    end
    
    if exist('movmean', 'file') == 2
        ySmoothed = movmean(yData, windowSize);
        xSmoothed = xData;
    else
        n = length(yData);
        ySmoothed = zeros(size(yData));
        halfWindow = floor(windowSize / 2);
        
        for i = 1:n
            startIdx = max(1, i - halfWindow);
            endIdx = min(n, i + halfWindow);
            ySmoothed(i) = mean(yData(startIdx:endIdx), 'omitnan');
        end
        xSmoothed = xData;
    end
end

function createProbeTracesFigure(probes, probeData, times, outputPath)
    if isempty(probes) || isempty(probeData)
        return
    end
    
    figTag = 'AutoIosVideoProbeTraces';
    
    existingFig = findobj('Type', 'figure', 'Tag', figTag);
    if ~isempty(existingFig)
        figure(existingFig);
        clf(existingFig);
    else
        existingFig = figure('Name', 'IOS Probe Traces', 'NumberTitle', 'off', 'Tag', figTag);
    end
    
    numProbes = length(probes);
    cols = ceil(sqrt(numProbes));
    rows = ceil(numProbes / cols);
    
    colors = getColors(numProbes);
    
    for i = 1:numProbes
        subplot(rows, cols, i);
        probeColor = hex2rgb(colors{i});
        if ~isempty(times) && length(times) == length(probeData{i})
            plot(times, probeData{i}, 'Color', probeColor, 'LineWidth', 1.5);
        else
            plot(probeData{i}, 'Color', probeColor, 'LineWidth', 1.5);
        end
        xlabel('Time (s)');
        ylabel('IOS');
        title(sprintf('Probe %d (row=%d, col=%d)', i, probes(i).center(1), probes(i).center(2)));
        grid on;
    end
    
    if nargin >= 4 && ~isempty(outputPath)
        [fileDir, fileName, ~] = fileparts(outputPath);
        tracesPath = fullfile(fileDir, [fileName, '_traces.png']);
        print(existingFig, tracesPath, '-dpng', '-r300');
    end
end
