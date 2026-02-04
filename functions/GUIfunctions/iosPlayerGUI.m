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
    global SettingsFilepath auto_open_last_file iosChartData
    if isempty(SettingsFilepath)
        SettingsFilepath = fullfile(tempdir, 'ev_settings.mat');
    end
    assetsPath = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))), 'assets');
    playIcon = fullfile(assetsPath, 'play_btn.png');
    pauseIcon = fullfile(assetsPath, 'pause_btn.png');
    recordIcon = fullfile(assetsPath, 'record_btn.png');
    stopIcon = fullfile(assetsPath, 'stop_btn.png');
    fig = figure('Name', 'IOS Player', 'NumberTitle', 'off', ...
        'Units', 'normalized', 'Position', [0.25 0.15 0.5 0.7], 'Tag', figTag);
    ax = axes(fig, 'Units', 'normalized', 'Position', [0.070 0.532 0.603 0.406]);
    chartAx = axes(fig, 'Units', 'normalized', 'Position', [0.670 0.110 0.316 0.194], 'Visible', 'off');
    colormap(fig, gray);
    hSlider = uicontrol(fig, 'Style', 'slider', 'Units', 'normalized', ...
        'Position', [0.152 0.442 0.525 0.040], 'Min', 1, 'Max', 2, 'Value', 1);
    hTimeEdit = uicontrol(fig, 'Style', 'edit', 'Units', 'normalized', ...
        'Position', [0.024 0.442 0.120 0.040], 'String', '0:00.0');
    hNavStart = uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
        'Position', [0.239 0.391 0.050 0.040], 'String', createIconButtonHTML(fullfile(assetsPath, 'nav_start_btn.png')));
    hNavPrev = uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
        'Position', [0.295 0.391 0.050 0.040], 'String', createIconButtonHTML(fullfile(assetsPath, 'previous_button.png')));
    hNavNext = uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
        'Position', [0.355 0.391 0.050 0.040], 'String', createIconButtonHTML(fullfile(assetsPath, 'next_button.png')));
    hNavEnd = uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
        'Position', [0.412 0.391 0.050 0.040], 'String', createIconButtonHTML(fullfile(assetsPath, 'nav_end_btn.png')));
    hPlayBtn = uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
        'Position', [0.131 0.391 0.099 0.040], 'String', createIconButtonHTML(playIcon));
    hSpeedPopup = uicontrol(fig, 'Style', 'popupmenu', 'Units', 'normalized', ...
        'Position', [0.477 0.391 0.080 0.040], 'String', {'0.5x','1x','2x','5x','10x','20x','50x','100x','200x','500x','1000x'}, 'Value', 2);
    hOpenBtn = uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
        'Position', [0.011 0.952 0.120 0.040], 'String', 'Open');
    hFilePathText = uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.135 0.952 0.540 0.040], 'String', 'No file opened', ...
        'HorizontalAlignment', 'left', 'FontSize', 8);
    hRecordBtn = uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
        'Position', [0.024 0.391 0.100 0.040], 'String', createIconButtonHTML(recordIcon));
    hContrastText = uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.754 0.923 0.080 0.040], 'String', 'Contrast:', 'HorizontalAlignment', 'left');
    hContrastSlider = uicontrol(fig, 'Style', 'slider', 'Units', 'normalized', ...
        'Position', [0.754 0.898 0.158 0.040], 'Min', 0.2, 'Max', 2, 'Value', 1);
    hContrastEdit = uicontrol(fig, 'Style', 'edit', 'Units', 'normalized', ...
        'Position', [0.918 0.898 0.055 0.040], 'String', '1.0');
    hGaussianText = uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.754 0.825 0.080 0.040], 'String', 'Gaussian:', 'HorizontalAlignment', 'left');
    hGaussianSlider = uicontrol(fig, 'Style', 'slider', 'Units', 'normalized', ...
        'Position', [0.754 0.800 0.158 0.040], 'Min', 0, 'Max', 100, 'Value', 3);
    hGaussianEdit = uicontrol(fig, 'Style', 'edit', 'Units', 'normalized', ...
        'Position', [0.918 0.800 0.055 0.040], 'String', '3.0');
    hNoiseFilterText = uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.754 0.722 0.080 0.040], 'String', 'Noise filter:', 'HorizontalAlignment', 'left');
    hNoiseFilterPopup = uicontrol(fig, 'Style', 'popupmenu', 'Units', 'normalized', ...
        'Position', [0.834 0.722 0.136 0.040], 'String', {'None','Median','Wiener','Highpass'}, 'Value', 1);
    hColormapText = uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.754 0.603 0.080 0.040], 'String', 'Colormap:', 'HorizontalAlignment', 'left');
    hColormapPopup = uicontrol(fig, 'Style', 'popupmenu', 'Units', 'normalized', ...
        'Position', [0.834 0.600 0.139 0.040], 'String', {'gray','jet','hot','cool','parula','hsv','spring','summer','autumn','winter','bone','copper','pink','lines'}, 'Value', 1);
    hBlurSigmaText = uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.754 0.686 0.080 0.040], 'String', 'Kernel size:', 'HorizontalAlignment', 'left', 'Visible', 'off');
    hBlurSigmaSlider = uicontrol(fig, 'Style', 'slider', 'Units', 'normalized', ...
        'Position', [0.754 0.668 0.158 0.040], 'Min', 1, 'Max', 1000, 'Value', 5, 'Visible', 'off');
    hBlurSigmaEdit = uicontrol(fig, 'Style', 'edit', 'Units', 'normalized', ...
        'Position', [0.918 0.668 0.055 0.040], 'String', '5', 'Visible', 'off');
    hRotationText = uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.754 0.563 0.080 0.040], 'String', 'Rotation:', 'HorizontalAlignment', 'left');
    hRotationSlider = uicontrol(fig, 'Style', 'slider', 'Units', 'normalized', ...
        'Position', [0.754 0.5628 0.158 0.020], 'Min', -180, 'Max', 180, 'Value', 0);
    hRotationEdit = uicontrol(fig, 'Style', 'edit', 'Units', 'normalized', ...
        'Position', [0.918 0.538 0.055 0.040], 'String', '0');
    hOffsetXText = uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.754 0.523 0.080 0.040], 'String', 'Offset X:', 'HorizontalAlignment', 'left');
    hOffsetXSlider = uicontrol(fig, 'Style', 'slider', 'Units', 'normalized', ...
        'Position', [0.754,0.527075804776739,0.158,0.02], 'Min', -200, 'Max', 200, 'Value', 0);
    hOffsetXEdit = uicontrol(fig, 'Style', 'edit', 'Units', 'normalized', ...
        'Position', [0.918 0.498 0.055 0.040], 'String', '0');
    hOffsetYText = uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.754 0.483 0.080 0.040], 'String', 'Offset Y:', 'HorizontalAlignment', 'left');
    hOffsetYSlider = uicontrol(fig, 'Style', 'slider', 'Units', 'normalized', ...
        'Position', [0.754,0.48523738317757,0.158,0.02], 'Min', -200, 'Max', 200, 'Value', 0);
    hOffsetYEdit = uicontrol(fig, 'Style', 'edit', 'Units', 'normalized', ...
        'Position', [0.918 0.458 0.055 0.040], 'String', '0');
    hZoomText = uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.754 0.443 0.080 0.040], 'String', 'Zoom:', 'HorizontalAlignment', 'left');
    hZoomSlider = uicontrol(fig, 'Style', 'slider', 'Units', 'normalized', ...
        'Position', [0.754,0.44316,0.158,0.02], 'Min', 0.25, 'Max', 4, 'Value', 1);
    hZoomEdit = uicontrol(fig, 'Style', 'edit', 'Units', 'normalized', ...
        'Position', [0.918 0.418 0.055 0.040], 'String', '1.0');
    hResetPipelineBtn = uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
        'Position', [0.754 0.378 0.219 0.040], 'String', 'Reset pipeline');
    hIosCheck = uicontrol(fig, 'Style', 'checkbox', 'Units', 'normalized', ...
        'Position', [0.030 0.294 0.050 0.040], 'String', 'IOS', 'Value', 0);
    hBaseStartText = uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.331 0.283 0.070 0.040], 'String', 'Base start:', 'HorizontalAlignment', 'left', 'Visible', 'off');
    hBaseStartEdit = uicontrol(fig, 'Style', 'edit', 'Units', 'normalized', ...
        'Position', [0.331 0.261 0.055 0.040], 'String', '1', 'Visible', 'off');
    hBaseEndText = uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.455 0.283 0.055 0.040], 'String', 'Base end:', 'HorizontalAlignment', 'left', 'Visible', 'off');
    hBaseEndEdit = uicontrol(fig, 'Style', 'edit', 'Units', 'normalized', ...
        'Position', [0.455 0.261 0.055 0.040], 'String', '1', 'Visible', 'off');
    hSetBaseBtn = uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
        'Position', [0.518 0.265 0.100 0.040], 'String', 'Set baseframe', 'Visible', 'off');
    hGetTracesBtn = uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
        'Position', [0.905 0.010 0.090 0.040], 'String', 'Get Traces');
    hAddReferenceBtn = uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
        'Position', [0.480 0.188 0.105 0.040], 'String', 'Add Reference', 'Visible', 'off');
    hDeleteReferenceBtn = uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
        'Position', [0.479 0.150 0.105 0.040], 'String', 'Delete Reference', 'Visible', 'off');
    hFloatingBaseCheck = uicontrol(fig, 'Style', 'checkbox', 'Units', 'normalized', ...
        'Position', [0.030 0.230 0.120 0.040], 'String', 'Floating base', 'Value', 0, 'Visible', 'off');
    hBaseDelayText = uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.396 0.283 0.060 0.040], 'String', 'Base delay:', 'HorizontalAlignment', 'left', 'Visible', 'off');
    hBaseDelayEdit = uicontrol(fig, 'Style', 'edit', 'Units', 'normalized', ...
        'Position', [0.396 0.261 0.055 0.040], 'String', '1.0', 'Visible', 'off');
    hReferenceSizeText = uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.348 0.165 0.080 0.040], 'String', 'Ref Size:', 'HorizontalAlignment', 'left', 'Visible', 'off');
    hReferenceSizeEdit = uicontrol(fig, 'Style', 'edit', 'Units', 'normalized', ...
        'Position', [0.395 0.165 0.055 0.040], 'String', '10', 'Visible', 'off');
    hReferenceFullSizeCheck = uicontrol(fig, 'Style', 'checkbox', 'Units', 'normalized', ...
        'Position', [0.173 0.175 0.131 0.039], 'String', 'Full Image Reference', 'Value', 0, 'Visible', 'off');
    hAddCursorBtn = uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
        'Position', [0.498 0.083 0.090 0.040], 'String', 'Add Cursor');
    hIosMinText = uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.150 0.283 0.060 0.040], 'String', 'IOS Min:', 'HorizontalAlignment', 'left', 'Visible', 'off');
    hIosMinEdit = uicontrol(fig, 'Style', 'edit', 'Units', 'normalized', ...
        'Position', [0.147 0.261 0.055 0.040], 'String', '', 'Visible', 'off');
    hIosMaxText = uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.234 0.282 0.060 0.040], 'String', 'IOS Max:', 'HorizontalAlignment', 'left', 'Visible', 'off');
    hIosMaxEdit = uicontrol(fig, 'Style', 'edit', 'Units', 'normalized', ...
        'Position', [0.234 0.262 0.055 0.040], 'String', '', 'Visible', 'off');

    hCursorsText = uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.029 0.106 0.080 0.040], 'String', 'Cursors:', 'HorizontalAlignment', 'left');
    hCursorsTable = uitable(fig, 'Units', 'normalized', ...
        'Position', [0.030 0.010 0.369 0.113], ...
        'ColumnName', {'#', 'Row', 'Col', 'Size', 'Visible'}, ...
        'ColumnEditable', [false false false true true], ...
        'ColumnFormat', {'numeric', 'numeric', 'numeric', 'numeric', 'logical'}, ...
        'ColumnWidth', {30 80 80 60 60}, ...
        'Data', cell(0, 5), ...
        'CellSelectionCallback', @(src, event) onCursorsTableSelection(src, event, fig), ...
        'CellEditCallback', @(src, event) onCursorsTableEdit(src, event, fig, ax));
    hEditCursorBtn = uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
        'Position', [0.407 0.083 0.090 0.040], 'String', 'Edit Position');
    hDeleteCursorBtn = uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
        'Position', [0.406 0.040 0.095 0.040], 'String', 'Delete Selected');
    hClearCursorsBtn = uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
        'Position', [0.502 0.040 0.090 0.040], 'String', 'Clear All');
    hShowIosCheck = uicontrol(fig, 'Style', 'checkbox', 'Units', 'normalized', ...
        'Position', [0.115 0.145 0.140 0.030], 'String', 'Show IOS values', 'Value', 0);
    hClearChartBtn = uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
        'Position', [0.809 0.010 0.090 0.040], 'String', 'Clear Chart', 'Visible', 'off');
    hShowChartCheck = uicontrol(fig, 'Style', 'checkbox', 'Units', 'normalized', ...
        'Position', [0.710 0.010 0.095 0.040], 'String', 'Show Chart', 'Value', 1, 'Visible', 'off');
    hChartSmoothText = uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.670 0.055 0.055 0.032], 'String', 'Smooth:', 'HorizontalAlignment', 'left', 'Visible', 'off');
    hChartSmoothEdit = uicontrol(fig, 'Style', 'edit', 'Units', 'normalized', ...
        'Position', [0.728 0.055 0.042 0.032], 'String', '1', 'Visible', 'off');

    h = struct('slider', hSlider, 'timeEdit', hTimeEdit, 'playBtn', hPlayBtn, ...
        'speedPopup', hSpeedPopup, 'openBtn', hOpenBtn, 'filePathText', hFilePathText, 'recordBtn', hRecordBtn, 'contrastText', hContrastText, 'contrastSlider', hContrastSlider, 'contrastEdit', hContrastEdit, ...
        'navStart', hNavStart, 'navPrev', hNavPrev, 'navNext', hNavNext, 'navEnd', hNavEnd, ...
        'iosCheck', hIosCheck, 'baseStartText', hBaseStartText, 'baseStartEdit', hBaseStartEdit, ...
        'baseEndText', hBaseEndText, 'baseEndEdit', hBaseEndEdit, 'setBaseBtn', hSetBaseBtn, ...
        'gaussianText', hGaussianText, 'gaussianSlider', hGaussianSlider, 'gaussianEdit', hGaussianEdit, ...
        'colormapText', hColormapText, 'colormapPopup', hColormapPopup, ...
        'addCursorBtn', hAddCursorBtn, 'getTracesBtn', hGetTracesBtn, 'addReferenceBtn', hAddReferenceBtn, ...
        'deleteReferenceBtn', hDeleteReferenceBtn, 'referenceSizeEdit', hReferenceSizeEdit, 'referenceSizeText', hReferenceSizeText, ...
        'referenceFullSizeCheck', hReferenceFullSizeCheck, ...
        'floatingBaseCheck', hFloatingBaseCheck, 'baseDelayText', hBaseDelayText, 'baseDelayEdit', hBaseDelayEdit, ...
        'noiseFilterText', hNoiseFilterText, 'noiseFilterPopup', hNoiseFilterPopup, ...
        'blurSigmaText', hBlurSigmaText, 'blurSigmaSlider', hBlurSigmaSlider, 'blurSigmaEdit', hBlurSigmaEdit, ...
        'rotationText', hRotationText, 'rotationSlider', hRotationSlider, 'rotationEdit', hRotationEdit, ...
        'offsetXText', hOffsetXText, 'offsetXSlider', hOffsetXSlider, 'offsetXEdit', hOffsetXEdit, ...
        'offsetYText', hOffsetYText, 'offsetYSlider', hOffsetYSlider, 'offsetYEdit', hOffsetYEdit, ...
        'zoomText', hZoomText, 'zoomSlider', hZoomSlider, 'zoomEdit', hZoomEdit, ...
        'resetPipelineBtn', hResetPipelineBtn, ...
        'cursorsText', hCursorsText, 'cursorsTable', hCursorsTable, 'editCursorBtn', hEditCursorBtn, ...
        'deleteCursorBtn', hDeleteCursorBtn, 'clearCursorsBtn', hClearCursorsBtn, ...
        'showIosCheck', hShowIosCheck, 'clearChartBtn', hClearChartBtn, ...
        'showChartCheck', hShowChartCheck, 'chartSmoothText', hChartSmoothText, 'chartSmoothEdit', hChartSmoothEdit, ...
        'iosMinText', hIosMinText, 'iosMinEdit', hIosMinEdit, ...
        'iosMaxText', hIosMaxText, 'iosMaxEdit', hIosMaxEdit);
    state = struct('iosPath', iosPath, 'meta', [], 'playTimer', [], 'clim', [0 65535], 'h', h, 'him', [], ...
        'iosMode', false, 'baseframeStart', 1, 'baseframeEnd', 1, 'baseframeData', [], 'baseframeRangeUsed', [], ...
        'gaussianSigma', 3.0, 'climIosBase', [], 'climIosMin', [], 'climIosMax', [], 'cursors', [], 'awaitingClick', false, ...
        'referenceCursor', [], 'awaitingReferenceClick', false, 'referenceSize', 10, 'referenceFullSize', false, ...
        'floatingBaseMode', false, 'baseDelay', 1.0, ...
        'noiseFilterType', 'none', 'noiseFilterParam', 5, ...
        'editingCursorIndex', [], 'showIosValues', false, 'selectedCursorIndex', [], ...
        'chartAx', chartAx, 'chartLines', [], 'chartSmoothWindow', 1, ...
        'isUpdating', false, 'isRecording', false, 'videoWriter', [], ...
        'colormapScheme', 'gray', 'playIcon', playIcon, 'pauseIcon', pauseIcon, 'recordIcon', recordIcon, 'stopIcon', stopIcon, ...
        'rotationAngle', 0, 'offsetX', 0, 'offsetY', 0, 'zoomFactor', 1, 'preGeometricFrame', []);
    fig.UserData = state;

    hSlider.Callback = @(src,~) onSlider(src, fig, ax);
    hTimeEdit.Callback = @(src,~) onTimeEdit(src, fig, ax);
    hPlayBtn.Callback = @(src,~) onPlayPause(src, fig, ax);
    hSpeedPopup.Callback = @(src,~) onSpeedChange(src, fig, ax);
    hOpenBtn.Callback = @(src,~) onOpen(src, fig, ax);
    hRecordBtn.Callback = @(src,~) onRecord(src, fig, ax);
    hContrastSlider.Callback = @(src,~) onContrastSlider(src, fig, ax);
    hContrastEdit.Callback = @(src,~) onContrastEdit(src, fig, ax);
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
    hReferenceSizeEdit.Callback = @(src,~) onReferenceSizeEdit(src, fig, ax);
    hReferenceFullSizeCheck.Callback = @(src,~) onReferenceFullSizeCheck(src, fig, ax);
    hEditCursorBtn.Callback = @(src,~) onEditCursor(src, fig, ax);
    hDeleteCursorBtn.Callback = @(src,~) onDeleteCursor(src, fig, ax);
    hClearCursorsBtn.Callback = @(src,~) onClearCursors(src, fig, ax);
    hShowIosCheck.Callback = @(src,~) onShowIosCheck(src, fig, ax);
    hClearChartBtn.Callback = @(src,~) onClearChart(src, fig);
    hShowChartCheck.Callback = @(src,~) onShowChartCheck(src, fig);
    hChartSmoothEdit.Callback = @(src,~) onChartSmoothEdit(src, fig);
    hIosMinEdit.Callback = @(src,~) onIosRangeEdit(src, fig, ax, 'min');
    hIosMaxEdit.Callback = @(src,~) onIosRangeEdit(src, fig, ax, 'max');
    hColormapPopup.Callback = @(src,~) onColormapChange(src, fig, ax);
    hNoiseFilterPopup.Callback = @(src,~) onNoiseFilterChange(src, fig, ax);
    hBlurSigmaSlider.Callback = @(src,~) onNoiseFilterParamSlider(src, fig, ax);
    hBlurSigmaEdit.Callback = @(src,~) onNoiseFilterParamEdit(src, fig, ax);
    hRotationSlider.Callback = @(src,~) onRotationSlider(src, fig, ax);
    hRotationEdit.Callback = @(src,~) onRotationEdit(src, fig, ax);
    hOffsetXSlider.Callback = @(src,~) onOffsetXSlider(src, fig, ax);
    hOffsetXEdit.Callback = @(src,~) onOffsetXEdit(src, fig, ax);
    hOffsetYSlider.Callback = @(src,~) onOffsetYSlider(src, fig, ax);
    hOffsetYEdit.Callback = @(src,~) onOffsetYEdit(src, fig, ax);
    hZoomSlider.Callback = @(src,~) onZoomSlider(src, fig, ax);
    hZoomEdit.Callback = @(src,~) onZoomEdit(src, fig, ax);
    hResetPipelineBtn.Callback = @(src,~) onResetPipeline(src, fig, ax);

    applyLoadedSettings(fig, ax);
    fig.CloseRequestFcn = @(src,~) closeIosPlayerWindow(src);
    fig.WindowState = 'maximized';

    if ~isempty(iosPath) && exist(iosPath, 'file')
        openFile(fig, ax, iosPath);
    else
        autoOpenLastFile(fig, ax);
    end

    function closeIosPlayerWindow(fig)
        state = fig.UserData;
        if ~isempty(state.playTimer) && isvalid(state.playTimer)
            stop(state.playTimer);
            delete(state.playTimer);
        end
        saveIosPlayerSettings(fig);
        delete(fig);
        manageMainWindows('IosPlayerGUI');
    end

    function saveIosPlayerSettings(fig)
        if isempty(SettingsFilepath)
            SettingsFilepath = fullfile(tempdir, 'ev_settings.mat');
        end
        state = fig.UserData;
        s = struct();
        s.currentFrame = state.h.slider.Value;
        s.contrast = state.h.contrastSlider.Value;
        s.clim = state.clim;
        s.gaussianSigma = state.gaussianSigma;
        s.iosMode = state.iosMode;
        s.baseframeStart = state.baseframeStart;
        s.baseframeEnd = state.baseframeEnd;
        s.baseDelay = state.baseDelay;
        s.floatingBaseMode = state.floatingBaseMode;
        s.speedPopupValue = state.h.speedPopup.Value;
        s.colormapScheme = state.colormapScheme;
        s.noiseFilterType = state.noiseFilterType;
        s.noiseFilterParam = state.noiseFilterParam;
        s.rotationAngle = state.rotationAngle;
        s.offsetX = state.offsetX;
        s.offsetY = state.offsetY;
        s.zoomFactor = state.zoomFactor;
        s.referenceSize = state.referenceSize;
        s.referenceFullSize = state.referenceFullSize;
        s.showIosValues = state.showIosValues;
        s.showChart = state.h.showChartCheck.Value;
        if ~isempty(state.climIosMin)
            s.climIosMin = state.climIosMin;
        end
        if ~isempty(state.climIosMax)
            s.climIosMax = state.climIosMax;
        end
        s.visFloatingBaseCheck = state.h.floatingBaseCheck.Visible;
        s.visBaseStartText = state.h.baseStartText.Visible;
        s.visBaseStartEdit = state.h.baseStartEdit.Visible;
        s.visBaseEndText = state.h.baseEndText.Visible;
        s.visBaseEndEdit = state.h.baseEndEdit.Visible;
        s.visSetBaseBtn = state.h.setBaseBtn.Visible;
        s.visBaseDelayText = state.h.baseDelayText.Visible;
        s.visBaseDelayEdit = state.h.baseDelayEdit.Visible;
        s.visBlurSigmaText = state.h.blurSigmaText.Visible;
        s.visBlurSigmaSlider = state.h.blurSigmaSlider.Visible;
        s.visBlurSigmaEdit = state.h.blurSigmaEdit.Visible;
        s.visReferenceSizeText = state.h.referenceSizeText.Visible;
        s.visReferenceSizeEdit = state.h.referenceSizeEdit.Visible;
        s.visReferenceFullSizeCheck = state.h.referenceFullSizeCheck.Visible;
        s.visAddReferenceBtn = state.h.addReferenceBtn.Visible;
        s.visDeleteReferenceBtn = state.h.deleteReferenceBtn.Visible;
        s.visIosMinText = state.h.iosMinText.Visible;
        s.visIosMinEdit = state.h.iosMinEdit.Visible;
        s.visIosMaxText = state.h.iosMaxText.Visible;
        s.visIosMaxEdit = state.h.iosMaxEdit.Visible;
        s.visClearChartBtn = state.h.clearChartBtn.Visible;
        s.visShowChartCheck = state.h.showChartCheck.Visible;
        s.visChartAx = state.chartAx.Visible;
        s.chartSmoothWindow = state.chartSmoothWindow;
        if ~isempty(state.iosPath) && ischar(state.iosPath)
            s.lastOpenedPath = state.iosPath;
        end
        iosplayer_settings = s;
        save(SettingsFilepath, 'iosplayer_settings', '-append');
    end

    function applyLoadedSettings(fig, ax)
        if ~exist(SettingsFilepath, 'file')
            return
        end
        d = load(SettingsFilepath, 'iosplayer_settings');
        if ~isfield(d, 'iosplayer_settings')
            return
        end
        settings = d.iosplayer_settings;
        state = fig.UserData;
        nSpeed = numel(state.h.speedPopup.String);
        nColormap = numel(state.h.colormapPopup.String);
        nNoise = numel(state.h.noiseFilterPopup.String);
        if isfield(settings, 'currentFrame')
            v = state.h.slider.Min;
            m = state.h.slider.Max;
            state.h.slider.Value = max(v, min(m, round(settings.currentFrame)));
        end
        if isfield(settings, 'contrast')
            c = max(0.2, min(2, double(settings.contrast)));
            state.h.contrastSlider.Value = c;
            state.h.contrastEdit.String = sprintf('%.2f', c);
        end
        if isfield(settings, 'clim') && numel(settings.clim) == 2
            state.clim = settings.clim;
        end
        if isfield(settings, 'gaussianSigma')
            sigma = max(0, min(100, double(settings.gaussianSigma)));
            state.gaussianSigma = sigma;
            state.h.gaussianSlider.Value = sigma;
            state.h.gaussianEdit.String = sprintf('%.2f', sigma);
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
        if isfield(settings, 'speedPopupValue') && nSpeed >= 1
            v = max(1, min(nSpeed, round(settings.speedPopupValue)));
            state.h.speedPopup.Value = v;
        end
        if isfield(settings, 'colormapScheme') && ischar(settings.colormapScheme)
            state.colormapScheme = settings.colormapScheme;
            list = state.h.colormapPopup.String;
            idx = find(strcmpi(list, settings.colormapScheme), 1);
            if ~isempty(idx)
                state.h.colormapPopup.Value = idx;
            end
            colormap(fig, state.colormapScheme);
        end
        if isfield(settings, 'noiseFilterType')
            state.noiseFilterType = settings.noiseFilterType;
            list = {'none','median','wiener','highpass'};
            idx = find(strcmpi(list, settings.noiseFilterType), 1);
            if ~isempty(idx) && idx <= nNoise
                state.h.noiseFilterPopup.Value = idx;
            end
        end
        if isfield(settings, 'noiseFilterParam')
            p = max(1, min(1000, round(settings.noiseFilterParam)));
            state.noiseFilterParam = p;
            state.h.blurSigmaSlider.Value = p;
            state.h.blurSigmaEdit.String = num2str(p);
        end
        if isfield(settings, 'rotationAngle')
            a = max(-180, min(180, double(settings.rotationAngle)));
            state.rotationAngle = a;
            state.h.rotationSlider.Value = a;
            state.h.rotationEdit.String = sprintf('%.1f', a);
        end
        if isfield(settings, 'offsetX')
            x = max(-200, min(200, round(double(settings.offsetX))));
            state.offsetX = x;
            state.h.offsetXSlider.Value = x;
            state.h.offsetXEdit.String = sprintf('%.0f', x);
        end
        if isfield(settings, 'offsetY')
            y = max(-200, min(200, round(double(settings.offsetY))));
            state.offsetY = y;
            state.h.offsetYSlider.Value = y;
            state.h.offsetYEdit.String = sprintf('%.0f', y);
        end
        if isfield(settings, 'zoomFactor')
            z = max(0.25, min(4, double(settings.zoomFactor)));
            state.zoomFactor = z;
            state.h.zoomSlider.Value = z;
            state.h.zoomEdit.String = sprintf('%.2f', z);
        end
        if isfield(settings, 'referenceSize')
            state.referenceSize = settings.referenceSize;
            state.h.referenceSizeEdit.String = num2str(state.referenceSize);
        end
        if isfield(settings, 'referenceFullSize')
            state.referenceFullSize = logical(settings.referenceFullSize);
            state.h.referenceFullSizeCheck.Value = double(state.referenceFullSize);
        end
        if isfield(settings, 'showIosValues')
            state.showIosValues = logical(settings.showIosValues);
            state.h.showIosCheck.Value = double(state.showIosValues);
        end
        if isfield(settings, 'showChart')
            state.h.showChartCheck.Value = double(logical(settings.showChart));
        end
        if isfield(settings, 'chartSmoothWindow')
            w = round(settings.chartSmoothWindow);
            state.chartSmoothWindow = max(1, w);
            state.h.chartSmoothEdit.String = num2str(state.chartSmoothWindow);
        end
        if isfield(settings, 'climIosMin') && ~isempty(settings.climIosMin)
            state.climIosMin = settings.climIosMin;
            state.h.iosMinEdit.String = sprintf('%.6f', state.climIosMin);
        end
        if isfield(settings, 'climIosMax') && ~isempty(settings.climIosMax)
            state.climIosMax = settings.climIosMax;
            state.h.iosMaxEdit.String = sprintf('%.6f', state.climIosMax);
        end
        visPairs = {'visFloatingBaseCheck','floatingBaseCheck'; 'visBaseStartText','baseStartText'; 'visBaseStartEdit','baseStartEdit'; 'visBaseEndText','baseEndText'; 'visBaseEndEdit','baseEndEdit'; 'visSetBaseBtn','setBaseBtn'; 'visBaseDelayText','baseDelayText'; 'visBaseDelayEdit','baseDelayEdit'; 'visBlurSigmaText','blurSigmaText'; 'visBlurSigmaSlider','blurSigmaSlider'; 'visBlurSigmaEdit','blurSigmaEdit'; 'visReferenceSizeText','referenceSizeText'; 'visReferenceSizeEdit','referenceSizeEdit'; 'visReferenceFullSizeCheck','referenceFullSizeCheck'; 'visAddReferenceBtn','addReferenceBtn'; 'visDeleteReferenceBtn','deleteReferenceBtn'; 'visIosMinText','iosMinText'; 'visIosMinEdit','iosMinEdit'; 'visIosMaxText','iosMaxText'; 'visIosMaxEdit','iosMaxEdit'; 'visClearChartBtn','clearChartBtn'; 'visShowChartCheck','showChartCheck'; 'visChartAx','chartAx'};
        for i = 1:size(visPairs, 1)
            fn = visPairs{i, 1};
            hName = visPairs{i, 2};
            if isfield(settings, fn)
                if strcmp(hName, 'chartAx')
                    state.chartAx.Visible = settings.(fn);
                else
                    state.h.(hName).Visible = settings.(fn);
                end
            end
        end
        fig.UserData = state;
    end

    function autoOpenLastFile(fig, ax)
        if isempty(auto_open_last_file) || ~auto_open_last_file
            return
        end
        if isempty(SettingsFilepath) || ~exist(SettingsFilepath, 'file')
            return
        end
        d = load(SettingsFilepath, 'iosplayer_settings');
        if ~isfield(d, 'iosplayer_settings') || ~isfield(d.iosplayer_settings, 'lastOpenedPath')
            return
        end
        lastPath = d.iosplayer_settings.lastOpenedPath;
        if ~exist(lastPath, 'file')
            return
        end
        openFile(fig, ax, lastPath);
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

function resultFrame = applySubtractBlurred(frame, blurSigma)
    if blurSigma <= 0
        resultFrame = frame;
        return
    end
    blurredFrame = applyGaussianFilter(frame, blurSigma);
    resultFrame = frame - blurredFrame;
end

function filtered = applyMedianFilter(img, windowSize)
    if windowSize < 3
        filtered = img;
        return
    end
    windowSize = round(windowSize);
    if mod(windowSize, 2) == 0
        windowSize = windowSize + 1;
    end
    if exist('medfilt2', 'file') == 2
        filtered = medfilt2(img, [windowSize windowSize]);
    else
        filtered = img;
    end
end

function filtered = applyWienerFilter(img, windowSize)
    if windowSize < 3
        filtered = img;
        return
    end
    windowSize = round(windowSize);
    if mod(windowSize, 2) == 0
        windowSize = windowSize + 1;
    end
    if exist('wiener2', 'file') == 2
        filtered = wiener2(img, [windowSize windowSize]);
    else
        filtered = img;
    end
end

function filtered = applyHighpassFilter(img, sigma)
    if sigma <= 0
        filtered = img;
        return
    end
    lowpass = applyGaussianFilter(img, sigma);
    filtered = img - lowpass;
end

function filtered = applyNoiseFilter(frame, filterType, param)
    switch filterType
        case 'median'
            filtered = applyMedianFilter(frame, param);
        case 'wiener'
            filtered = applyWienerFilter(frame, param);
        case 'highpass'
            filtered = applyHighpassFilter(frame, param);
        otherwise
            filtered = frame;
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

function baseframeData = computeFloatingBaseframe(fig, k)
    state = fig.UserData;
    baseframeData = [];
    if ~hasValidMeta(fig)
        return
    end
    meta = state.meta;
    delay = str2double(state.h.baseDelayEdit.String);
    if isnan(delay) || delay < 0
        delay = state.baseDelay;
    end
    frames_back = 1;
    if meta.dt > 0
        frames_back = round(delay / meta.dt);
    elseif meta.dt < 0
        frames_back = round(delay / abs(meta.dt));
        if k - frames_back < 1
            k_base = 1;
        else
            k_base = k - frames_back;
        end
    else
        k_base = 1;
    end
    if meta.dt > 0
        k_base = max(1, k - frames_back);
    end
    [data, ~, ~] = readIOS2(state.iosPath, 'startframe', k_base, 'endframe', k_base, 'Format', 'Lin');
    if isempty(data)
        return
    end
    data = double(data);
    data = ensure2DFrame(data);
    baseframeData = applyGaussianFilter(data, state.gaussianSigma);
end

function [rawFrame, t] = loadRawFrame(state, k)
    [data, t, ~] = readIOS2(state.iosPath, 'startframe', k, 'endframe', k, 'Format', 'Lin');
    rawFrame = ensure2DFrame(data);
end

function baseFrame = getBaseFrame(fig, k)
    state = fig.UserData;
    baseFrame = [];
    
    if ~state.iosMode
        return
    end
    
    if state.floatingBaseMode
        baseFrame = computeFloatingBaseframe(fig, k);
    else
        needBase = isempty(state.baseframeData) || isempty(state.baseframeRangeUsed) || ...
            state.baseframeStart ~= state.baseframeRangeUsed(1) || ...
            state.baseframeEnd ~= state.baseframeRangeUsed(2);
        if needBase
            state = computeBaseframe(fig);
            state = fig.UserData;
        end
        if ~isempty(state.baseframeData)
            baseFrame = double(state.baseframeData);
        end
    end
end

function processedFrame = computeIOS(filteredFrame, baseFrame, state)
    if ~state.iosMode || isempty(baseFrame)
        processedFrame = filteredFrame;
        return
    end
    
    denom = double(baseFrame);
    denom(denom == 0) = NaN;
    processedFrame = (filteredFrame - denom) ./ denom;
end

function [displayFrame, state] = applyReferenceCorrection(frame, state, fig)
    displayFrame = frame;
    
    if ~state.iosMode
        return
    end
    
    if state.referenceFullSize && isempty(state.referenceCursor)
        frameSize = size(frame);
        referenceCursor = struct();
        referenceCursor.center = [round(frameSize(1)/2), round(frameSize(2)/2)];
        referenceCursor.rect = [1, frameSize(1), 1, frameSize(2)];
        referenceCursor.handle = [];
        referenceCursor.size = max(frameSize(1), frameSize(2));
        state.referenceCursor = referenceCursor;
        fig.UserData = state;
    end
    
    if ~isempty(state.referenceCursor)
        refCursor = state.referenceCursor;
        rowRange = [refCursor.rect(1), refCursor.rect(2)];
        colRange = [refCursor.rect(3), refCursor.rect(4)];
        refRegion = frame(rowRange(1):rowRange(2), colRange(1):colRange(2));
        refIosValue = median(refRegion(:), 'omitnan');
        displayFrame = frame - refIosValue;
    end
end

function [baseRange, state] = computeDisplayRange(displayFrame, rawFrame, state, fig)
    percentileMin = 0.01;
    percentileMax = 99.99;
    
    if state.iosMode
        if isempty(state.climIosMin) || isempty(state.climIosMax)
            state.climIosMin = prctile(displayFrame(:), percentileMin);
            state.climIosMax = prctile(displayFrame(:), percentileMax);
            state.h.iosMinEdit.String = sprintf('%.6f', state.climIosMin);
            state.h.iosMaxEdit.String = sprintf('%.6f', state.climIosMax);
        end
        state.climIosBase = [state.climIosMin state.climIosMax];
        baseRange = state.climIosBase;
        fig.UserData = state;
    else
        if isempty(state.clim) || (state.clim(1) == 0 && state.clim(2) == 65535)
            state.clim = [prctile(rawFrame(:), percentileMin) prctile(rawFrame(:), percentileMax)];
        end
        baseRange = state.clim;
        fig.UserData = state;
    end
end

function [x, y] = originalToDisplay(row, col, state, frameSize)
    H = frameSize(1);
    W = frameSize(2);
    cx = (W + 1) / 2;
    cy = (H + 1) / 2;
    angle_rad = -state.rotationAngle * pi / 180;
    col1 = (col - cx) * cos(angle_rad) - (row - cy) * sin(angle_rad) + cx;
    row1 = (col - cx) * sin(angle_rad) + (row - cy) * cos(angle_rad) + cy;
    col2 = col1 + state.offsetX;
    row2 = row1 + state.offsetY;
    x = (col2 - cx) * state.zoomFactor + cx;
    y = (row2 - cy) * state.zoomFactor + cy;
end

function [row, col] = displayToOriginal(x, y, state, frameSize)
    H = frameSize(1);
    W = frameSize(2);
    cx = (W + 1) / 2;
    cy = (H + 1) / 2;
    angle_rad = state.rotationAngle * pi / 180;
    col2 = (x - cx) / state.zoomFactor + cx;
    row2 = (y - cy) / state.zoomFactor + cy;
    col1 = col2 - state.offsetX;
    row1 = row2 - state.offsetY;
    col = (col1 - cx) * cos(angle_rad) - (row1 - cy) * sin(angle_rad) + cx;
    row = (col1 - cx) * sin(angle_rad) + (row1 - cy) * cos(angle_rad) + cy;
end

function out = applyRotation(frame, angleDeg)
    if angleDeg == 0
        out = frame;
        return
    end
    out = imrotate(frame, angleDeg, 'bilinear', 'crop');
end

function out = applyOffset(frame, offsetX, offsetY)
    if offsetX == 0 && offsetY == 0
        out = frame;
        return
    end
    out = imtranslate(frame, [offsetX, offsetY], 'OutputView', 'same');
end

function out = applyZoom(frame, zoomFactor, origSize)
    if zoomFactor == 1
        out = frame;
        return
    end
    H = origSize(1);
    W = origSize(2);
    resized = imresize(frame, zoomFactor, 'bilinear');
    [Hr, Wr] = size(resized);
    if Hr >= H && Wr >= W
        r0 = floor((Hr - H) / 2) + 1;
        c0 = floor((Wr - W) / 2) + 1;
        out = resized(r0:(r0 + H - 1), c0:(c0 + W - 1));
    else
        out = zeros(H, W, 'like', frame);
        r0 = floor((H - Hr) / 2) + 1;
        c0 = floor((W - Wr) / 2) + 1;
        out(r0:(r0 + Hr - 1), c0:(c0 + Wr - 1)) = resized;
    end
end

function [displayFrame, baseRange, state, t] = processFramePipeline(fig, k)
    state = fig.UserData;
    
    [rawFrame, t] = loadRawFrame(state, k);
    if isempty(rawFrame) || any(isnan(rawFrame(:)))
        displayFrame = [];
        baseRange = [];
        return
    end
    
    filteredFrame = applyGaussianFilter(double(rawFrame), state.gaussianSigma);
    
    baseFrame = getBaseFrame(fig, k);
    if state.iosMode && isempty(baseFrame)
        displayFrame = [];
        baseRange = [];
        return
    end
    
    processedFrame = computeIOS(filteredFrame, baseFrame, state);
    
    [displayFrame, state] = applyReferenceCorrection(processedFrame, state, fig);
    
    if ~strcmp(state.noiseFilterType, 'none')
        displayFrame = applyNoiseFilter(displayFrame, state.noiseFilterType, state.noiseFilterParam);
    end
    
    state.preGeometricFrame = displayFrame;
    displayFrame = applyRotation(displayFrame, state.rotationAngle);
    displayFrame = applyOffset(displayFrame, state.offsetX, state.offsetY);
    displayFrame = applyZoom(displayFrame, state.zoomFactor, size(displayFrame));
    
    [baseRange, state] = computeDisplayRange(displayFrame, rawFrame, state, fig);
    
    fig.UserData = state;
end

function openFile(fig, ax, fname)
    state = fig.UserData;
    if ~isempty(state.playTimer) && isvalid(state.playTimer)
        stop(state.playTimer);
        delete(state.playTimer);
        state.playTimer = [];
        state.h.playBtn.String = createIconButtonHTML(state.playIcon);
    end
    
    if state.isRecording && ~isempty(state.videoWriter) && isvalid(state.videoWriter)
        close(state.videoWriter);
        state.isRecording = false;
        state.videoWriter = [];
        state.h.recordBtn.String = createIconButtonHTML(state.recordIcon);
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
    clearChart(fig);
    
    meta = readIOS2(fname, 'metadataOnly', true);
    state.meta = meta;
    state.iosPath = fname;
    [~, t13, ~] = readIOS2(fname, 'startframe', 1, 'endframe', min(3, meta.totalFrames), 'Format', 'Lin');
    t13 = [t13(:); NaN(max(0, 3 - numel(t13)), 1)];
    fprintf('openFile: t(1)=%g, t(2)=%g, t(3)=%g\n', t13(1), t13(2), t13(3));
    state.h.filePathText.String = fname;
    state = clearBaseframe(state);
    state.cursors = [];
    state.awaitingClick = false;
    state.referenceCursor = [];
    state.awaitingReferenceClick = false;
    state.editingCursorIndex = [];
    state.selectedCursorIndex = [];
    state.isUpdating = false;
    state.preGeometricFrame = [];
    
    fig.UserData = state;
    updateCursorsTable(fig);
    showHideChart(fig);
    initChart(fig);

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
    if state.isUpdating
        return
    end
    state.isUpdating = true;
    fig.UserData = state;
    
    try
        if ~hasValidMeta(fig)
            state.isUpdating = false;
            fig.UserData = state;
            return
        end
        
        [displayFrame, baseRange, state, t] = processFramePipeline(fig, k);
        
        if isempty(displayFrame)
            state.h.timeEdit.String = sec2timeStr(t(1));
            state.h.slider.Value = k;
            state.isUpdating = false;
            fig.UserData = state;
            return
        end
        
        if isempty(state.him) || ~isvalid(state.him)
            cla(ax);
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
        applyContrast(ax, baseRange, c);

        state.h.timeEdit.String = sec2timeStr(t(1));
        state.h.slider.Value = k;
        state.isUpdating = false;
        if state.iosMode && ~isempty(state.cursors) && ~isempty(state.him) && isvalid(state.him)
            state = updateChart(state, fig, ax, t(1));
        end
        fig.UserData = state;
    catch ME
        state.isUpdating = false;
        fig.UserData = state;
        rethrow(ME);
    end
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
            clearChart(fig);
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
        src.String = createIconButtonHTML(state.playIcon);
        fig.UserData = state;
        return
    end
    N = state.meta.totalFrames;
    cur = getCurrentFrame(state);
    if cur >= N
        cur = 1;
        showFrame(fig, ax, cur);
    end
    speeds = [0.5 1 2 5 10 20 50 100 200 500 1000];
    speed = speeds(state.h.speedPopup.Value);
    dt = state.meta.dt / speed;
    if dt <= 0
        dt = 0.05;
    end
    src.String = createIconButtonHTML(state.pauseIcon);
    drawnow
    state.playTimer = timer('ExecutionMode', 'singleShot', 'StartDelay', dt, ...
        'TimerFcn', @(~,~) playStep(fig, ax));
    state.playTimer.UserData = struct('cur', cur, 'N', N);
    fig.UserData = state;
    start(state.playTimer);
end

function playStep(fig, ax)
    try
        state = fig.UserData;
        if isempty(state.playTimer) || ~isvalid(state.playTimer)
            return
        end
        t = state.playTimer.UserData;
        speeds = [0.5 1 2 5 10 20 50 100 200 500 1000];
        speed = speeds(state.h.speedPopup.Value);
        stepSize = max(1, round(speed));
        t.cur = t.cur + stepSize;
        if t.cur > t.N
            stop(state.playTimer);
            delete(state.playTimer);
            state.playTimer = [];
            state.h.playBtn.String = createIconButtonHTML(state.playIcon);
            showFrame(fig, ax, t.N);
            fig.UserData = state;
            return
        end
        state.playTimer.UserData = t;
        fig.UserData = state;
        showFrame(fig, ax, t.cur);
        drawnow;
        dt = state.meta.dt / speed;
        if dt <= 0
            dt = 0.05;
        end
        stop(state.playTimer);
        state.playTimer.StartDelay = dt;
        start(state.playTimer);
        fig.UserData = state;
    catch
    end
end

function onSpeedChange(src, fig, ax)
    state = fig.UserData;
    if ~isempty(state.playTimer) && isvalid(state.playTimer)
        speeds = [0.5 1 2 5 10 20 50 100 200 500 1000];
        speed = speeds(src.Value);
        dt = state.meta.dt / speed;
        if dt <= 0
            dt = 0.05;
        end
        stop(state.playTimer);
        state.playTimer.StartDelay = dt;
        start(state.playTimer);
        fig.UserData = state;
    end
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
    if state.floatingBaseMode && state.iosMode
        visBase = 'off';
        visDelay = 'on';
    else
        visBase = vis;
        visDelay = 'off';
    end
    state.h.baseDelayEdit.Visible = visDelay;
    state.h.baseDelayText.Visible = visDelay;
    state.h.baseStartText.Visible = visBase;
    state.h.baseStartEdit.Visible = visBase;
    state.h.baseEndText.Visible = visBase;
    state.h.baseEndEdit.Visible = visBase;
    state.h.setBaseBtn.Visible = visBase;
    if state.iosMode
        visRefSize = 'on';
    else
        visRefSize = 'off';
    end
    state.h.referenceSizeText.Visible = visRefSize;
    state.h.referenceSizeEdit.Visible = visRefSize;
    state.h.referenceFullSizeCheck.Visible = visRefSize;
    state.h.addReferenceBtn.Visible = vis;
    state.h.deleteReferenceBtn.Visible = vis;
    state.h.iosMinText.Visible = vis;
    state.h.iosMinEdit.Visible = vis;
    state.h.iosMaxText.Visible = vis;
    state.h.iosMaxEdit.Visible = vis;
    fig.UserData = state;
    showHideChart(fig);
    k = getCurrentFrame(state);
    showFrame(fig, ax, k);
end

function onFloatingBaseCheck(src, fig, ax)
    state = fig.UserData;
    state.floatingBaseMode = logical(src.Value);
    if state.floatingBaseMode && state.iosMode
        visBase = 'off';
        visDelay = 'on';
    elseif state.iosMode
        visBase = 'on';
        visDelay = 'off';
    else
        visBase = 'off';
        visDelay = 'off';
    end
    state.h.baseStartText.Visible = visBase;
    state.h.baseStartEdit.Visible = visBase;
    state.h.baseEndText.Visible = visBase;
    state.h.baseEndEdit.Visible = visBase;
    state.h.setBaseBtn.Visible = visBase;
    state.h.baseDelayText.Visible = visDelay;
    state.h.baseDelayEdit.Visible = visDelay;
    if state.iosMode
        visRefSize = 'on';
    else
        visRefSize = 'off';
    end
    state.h.referenceSizeText.Visible = visRefSize;
    state.h.referenceSizeEdit.Visible = visRefSize;
    state.h.referenceFullSizeCheck.Visible = visRefSize;
    state.h.addReferenceBtn.Visible = visRefSize;
    state.h.deleteReferenceBtn.Visible = visRefSize;
    state.h.iosMinText.Visible = visRefSize;
    state.h.iosMinEdit.Visible = visRefSize;
    state.h.iosMaxText.Visible = visRefSize;
    state.h.iosMaxEdit.Visible = visRefSize;
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
    if state.iosMode && state.floatingBaseMode
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
    sigma = max(0, min(100, sigma));
    state.gaussianSigma = sigma;
    state.h.gaussianSlider.Value = sigma;
    state = clearBaseframe(state);
    fig.UserData = state;
    if hasValidMeta(fig)
        k = getCurrentFrame(state);
        showFrame(fig, ax, k);
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
    
    if strcmp(state.noiseFilterType, 'none')
        state.h.blurSigmaText.Visible = 'off';
        state.h.blurSigmaSlider.Visible = 'off';
        state.h.blurSigmaEdit.Visible = 'off';
    else
        state.h.blurSigmaText.Visible = 'on';
        state.h.blurSigmaSlider.Visible = 'on';
        state.h.blurSigmaEdit.Visible = 'on';
        if strcmp(state.noiseFilterType, 'median')
            state.h.blurSigmaText.String = 'Kernel size:';
            state.h.blurSigmaSlider.Min = 3;
            state.h.blurSigmaSlider.Max = 1000;
            if state.noiseFilterParam < 3
                state.noiseFilterParam = 5;
            end
        elseif strcmp(state.noiseFilterType, 'wiener')
            state.h.blurSigmaText.String = 'Kernel size:';
            state.h.blurSigmaSlider.Min = 3;
            state.h.blurSigmaSlider.Max = 1000;
            if state.noiseFilterParam < 3
                state.noiseFilterParam = 5;
            end
        elseif strcmp(state.noiseFilterType, 'highpass')
            state.h.blurSigmaText.String = 'Sigma:';
            state.h.blurSigmaSlider.Min = 0.1;
            state.h.blurSigmaSlider.Max = 1000;
            if state.noiseFilterParam < 0.1
                state.noiseFilterParam = 3.0;
            end
        end
        state.h.blurSigmaSlider.Value = state.noiseFilterParam;
        if strcmp(state.noiseFilterType, 'highpass')
            state.h.blurSigmaEdit.String = sprintf('%.2f', state.noiseFilterParam);
        elseif strcmp(state.noiseFilterType, 'median') || strcmp(state.noiseFilterType, 'wiener')
            state.h.blurSigmaEdit.String = sprintf('%d', round(state.noiseFilterParam));
        else
            state.h.blurSigmaEdit.String = sprintf('%.2f', state.noiseFilterParam);
        end
    end
    
    fig.UserData = state;
    if hasValidMeta(fig)
        k = getCurrentFrame(state);
        showFrame(fig, ax, k);
    end
end

function onNoiseFilterParamSlider(src, fig, ax)
    state = fig.UserData;
    param = double(src.Value);
    state.noiseFilterParam = param;
    if strcmp(state.noiseFilterType, 'highpass')
        state.h.blurSigmaEdit.String = sprintf('%.2f', param);
    elseif strcmp(state.noiseFilterType, 'median') || strcmp(state.noiseFilterType, 'wiener')
        state.h.blurSigmaEdit.String = sprintf('%d', round(param));
    else
        state.h.blurSigmaEdit.String = sprintf('%.2f', param);
    end
    fig.UserData = state;
    if hasValidMeta(fig)
        k = getCurrentFrame(state);
        showFrame(fig, ax, k);
    end
end

function onNoiseFilterParamEdit(src, fig, ax)
    state = fig.UserData;
    param = str2double(src.String);
    if isnan(param) || param < state.h.blurSigmaSlider.Min
        if strcmp(state.noiseFilterType, 'highpass')
            src.String = sprintf('%.2f', state.noiseFilterParam);
        elseif strcmp(state.noiseFilterType, 'median') || strcmp(state.noiseFilterType, 'wiener')
            src.String = sprintf('%d', round(state.noiseFilterParam));
        else
            src.String = sprintf('%.2f', state.noiseFilterParam);
        end
        return
    end
    param = max(state.h.blurSigmaSlider.Min, min(state.h.blurSigmaSlider.Max, param));
    state.noiseFilterParam = param;
    state.h.blurSigmaSlider.Value = param;
    fig.UserData = state;
    if hasValidMeta(fig)
        k = getCurrentFrame(state);
        showFrame(fig, ax, k);
    end
end

function onRotationSlider(src, fig, ax)
    state = fig.UserData;
    val = double(src.Value);
    state.rotationAngle = val;
    state.h.rotationEdit.String = sprintf('%.1f', val);
    fig.UserData = state;
    if hasValidMeta(fig)
        k = getCurrentFrame(state);
        showFrame(fig, ax, k);
    end
end

function onRotationEdit(src, fig, ax)
    state = fig.UserData;
    val = str2double(src.String);
    if isnan(val)
        src.String = sprintf('%.1f', state.rotationAngle);
        return
    end
    val = max(-180, min(180, val));
    state.rotationAngle = val;
    state.h.rotationSlider.Value = val;
    state.h.rotationEdit.String = sprintf('%.1f', val);
    fig.UserData = state;
    if hasValidMeta(fig)
        k = getCurrentFrame(state);
        showFrame(fig, ax, k);
    end
end

function onOffsetXSlider(src, fig, ax)
    state = fig.UserData;
    val = round(double(src.Value));
    state.offsetX = val;
    state.h.offsetXEdit.String = sprintf('%.0f', val);
    fig.UserData = state;
    if hasValidMeta(fig)
        k = getCurrentFrame(state);
        showFrame(fig, ax, k);
    end
end

function onOffsetXEdit(src, fig, ax)
    state = fig.UserData;
    val = str2double(src.String);
    if isnan(val)
        src.String = sprintf('%.0f', state.offsetX);
        return
    end
    val = max(-200, min(200, round(val)));
    state.offsetX = val;
    state.h.offsetXSlider.Value = val;
    state.h.offsetXEdit.String = sprintf('%.0f', val);
    fig.UserData = state;
    if hasValidMeta(fig)
        k = getCurrentFrame(state);
        showFrame(fig, ax, k);
    end
end

function onOffsetYSlider(src, fig, ax)
    state = fig.UserData;
    val = round(double(src.Value));
    state.offsetY = val;
    state.h.offsetYEdit.String = sprintf('%.0f', val);
    fig.UserData = state;
    if hasValidMeta(fig)
        k = getCurrentFrame(state);
        showFrame(fig, ax, k);
    end
end

function onOffsetYEdit(src, fig, ax)
    state = fig.UserData;
    val = str2double(src.String);
    if isnan(val)
        src.String = sprintf('%.0f', state.offsetY);
        return
    end
    val = max(-200, min(200, round(val)));
    state.offsetY = val;
    state.h.offsetYSlider.Value = val;
    state.h.offsetYEdit.String = sprintf('%.0f', val);
    fig.UserData = state;
    if hasValidMeta(fig)
        k = getCurrentFrame(state);
        showFrame(fig, ax, k);
    end
end

function onZoomSlider(src, fig, ax)
    state = fig.UserData;
    val = double(src.Value);
    state.zoomFactor = val;
    state.h.zoomEdit.String = sprintf('%.2f', val);
    fig.UserData = state;
    if hasValidMeta(fig)
        k = getCurrentFrame(state);
        showFrame(fig, ax, k);
    end
end

function onZoomEdit(src, fig, ax)
    state = fig.UserData;
    val = str2double(src.String);
    if isnan(val) || val < 0.25 || val > 4
        src.String = sprintf('%.2f', state.zoomFactor);
        return
    end
    state.zoomFactor = val;
    state.h.zoomSlider.Value = val;
    fig.UserData = state;
    if hasValidMeta(fig)
        k = getCurrentFrame(state);
        showFrame(fig, ax, k);
    end
end

function onResetPipeline(~, fig, ax)
    state = fig.UserData;
    state.rotationAngle = 0;
    state.offsetX = 0;
    state.offsetY = 0;
    state.zoomFactor = 1;
    state.gaussianSigma = 3;
    state.noiseFilterType = 'none';
    state.noiseFilterParam = 5;
    state.h.rotationSlider.Value = 0;
    state.h.rotationEdit.String = '0';
    state.h.offsetXSlider.Value = 0;
    state.h.offsetXEdit.String = '0';
    state.h.offsetYSlider.Value = 0;
    state.h.offsetYEdit.String = '0';
    state.h.zoomSlider.Value = 1;
    state.h.zoomEdit.String = '1.0';
    state.h.gaussianSlider.Value = 3;
    state.h.gaussianEdit.String = '3.0';
    state.h.noiseFilterPopup.Value = 1;
    state.h.blurSigmaText.Visible = 'off';
    state.h.blurSigmaSlider.Visible = 'off';
    state.h.blurSigmaEdit.Visible = 'off';
    state.h.blurSigmaSlider.Value = 5;
    state.h.blurSigmaEdit.String = '5';
    state = clearBaseframe(state);
    fig.UserData = state;
    if hasValidMeta(fig)
        k = getCurrentFrame(state);
        showFrame(fig, ax, k);
    end
end

function onContrastSlider(src, fig, ax)
    state = fig.UserData;
    c = double(src.Value);
    state.h.contrastEdit.String = sprintf('%.2f', c);
    fig.UserData = state;
    if ~hasValidMeta(fig)
        return
    end
    if isempty(state.him) || ~isvalid(state.him)
        return
    end
    applyContrast(ax, getBaseRange(state), c);
end

function onContrastEdit(src, fig, ax)
    state = fig.UserData;
    c = str2double(src.String);
    if isnan(c) || c < 0.2 || c > 2
        src.String = sprintf('%.2f', state.h.contrastSlider.Value);
        return
    end
    state.h.contrastSlider.Value = c;
    fig.UserData = state;
    if ~hasValidMeta(fig)
        return
    end
    if isempty(state.him) || ~isvalid(state.him)
        return
    end
    applyContrast(ax, getBaseRange(state), c);
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
    if hasValidMeta(fig)
        k = getCurrentFrame(state);
        showFrame(fig, ax, k);
    end
end

function onOpen(~, fig, ax)
    global SettingsFilepath
    startPath = '';
    if ~isempty(SettingsFilepath) && exist(SettingsFilepath, 'file')
        d = load(SettingsFilepath, 'iosplayer_settings');
        if isfield(d, 'iosplayer_settings') && isfield(d.iosplayer_settings, 'lastOpenedPath')
            lastPath = d.iosplayer_settings.lastOpenedPath;
            if exist(lastPath, 'file')
                startPath = fileparts(lastPath);
            elseif exist(lastPath, 'dir')
                startPath = lastPath;
            end
        end
    end
    if isempty(startPath)
        [f, p] = uigetfile('*.ios', 'Select IOS file');
    else
        [f, p] = uigetfile('*.ios', 'Select IOS file', startPath);
    end
    if isequal(f, 0)
        return
    end
    fname = fullfile(p, f);
    openFile(fig, ax, fname);
end

function onRecord(~, fig, ax)
    state = fig.UserData;
    
    if state.isRecording
        state.isRecording = false;
        state.h.recordBtn.String = createIconButtonHTML(state.recordIcon);
        fig.UserData = state;
        return
    end
    
    if ~hasValidMeta(fig)
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
        return
    end
    outputPath = fullfile(p, f);
    
    v = [];
    try
        speeds = [0.5 1 2 5 10 20 50 100 200 500 1000];
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
        state.h.recordBtn.String = createIconButtonHTML(state.stopIcon);
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
            showFrame(fig, ax, k);
            drawnow;
            
            frame = getframe(ax);
            writeVideo(v, frame);
        end
        
        close(v);
        
        state = fig.UserData;
        state.isRecording = false;
        state.videoWriter = [];
        state.h.recordBtn.String = createIconButtonHTML(state.recordIcon);
        fig.UserData = state;
        
        if idx == numFramesToRecord
            msgbox(sprintf('Video saved successfully to:\n%s', outputPath), 'Recording Complete', 'help');
        else
            msgbox('Video recording stopped by user.', 'Recording Stopped', 'warn');
        end
        
    catch ME
        if ~isempty(v) && isvalid(v)
            close(v);
        end
        state = fig.UserData;
        state.isRecording = false;
        state.videoWriter = [];
        state.h.recordBtn.String = createIconButtonHTML(state.recordIcon);
        fig.UserData = state;
        errordlg(sprintf('Error during video recording:\n%s', ME.message), 'Recording Error');
        rethrow(ME);
    end
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
        if isempty(state.him) || ~isvalid(state.him)
            return
        end
        frameSize = size(state.him.CData);
        cp = get(ax, 'CurrentPoint');
        [row, col] = displayToOriginal(cp(1, 1), cp(1, 2), state, frameSize);
        row = round(row);
        col = round(col);
        row = max(1, min(frameSize(1), row));
        col = max(1, min(frameSize(2), col));
        
        if state.referenceFullSize
            row_min = 1;
            row_max = frameSize(1);
            col_min = 1;
            col_max = frameSize(2);
            referenceSize = max(frameSize(1), frameSize(2));
        else
            halfSize = state.referenceSize;
            row_min = max(1, row - halfSize);
            row_max = min(frameSize(1), row + halfSize);
            col_min = max(1, col - halfSize);
            col_max = min(frameSize(2), col + halfSize);
            referenceSize = halfSize;
        end
        
        referenceCursor = struct();
        referenceCursor.center = [row, col];
        referenceCursor.rect = [row_min, row_max, col_min, col_max];
        referenceCursor.handle = [];
        referenceCursor.size = referenceSize;
        
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
        if isempty(state.him) || ~isvalid(state.him)
            return
        end
        frameSize = size(state.him.CData);
        cp = get(ax, 'CurrentPoint');
        [row, col] = displayToOriginal(cp(1, 1), cp(1, 2), state, frameSize);
        row = round(row);
        col = round(col);
        row = max(1, min(frameSize(1), row));
        col = max(1, min(frameSize(2), col));
        
        cursorIdx = state.editingCursorIndex;
        if cursorIdx < 1 || cursorIdx > length(state.cursors)
            state.editingCursorIndex = [];
            state.h.editCursorBtn.String = 'Edit Position';
            fig.UserData = state;
            return
        end
        
        cursor = state.cursors(cursorIdx);
        if ~isfield(cursor, 'size')
            cursor.size = 10;
        end
        halfSize = cursor.size;
        row_min = max(1, row - halfSize);
        row_max = min(frameSize(1), row + halfSize);
        col_min = max(1, col - halfSize);
        col_max = min(frameSize(2), col + halfSize);
        
        if ~isempty(cursor.handle) && isvalid(cursor.handle)
            delete(cursor.handle);
        end
        
        cursorColor = cursor.color;
        
        cursor.center = [row, col];
        cursor.rect = [row_min, row_max, col_min, col_max];
        cursor.handle = [];
        cursor.color = cursorColor;
        cursor.size = halfSize;
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
        if state.iosMode && hasValidMeta(fig)
            k = getCurrentFrame(state);
            showFrame(fig, ax, k);
        end
        return
    end
    
    if ~state.awaitingClick
        return
    end
    if ~hasValidMeta(fig)
        return
    end
    if isempty(state.him) || ~isvalid(state.him)
        return
    end
    frameSize = size(state.him.CData);
    cp = get(ax, 'CurrentPoint');
    [row, col] = displayToOriginal(cp(1, 1), cp(1, 2), state, frameSize);
    row = round(row);
    col = round(col);
    row = max(1, min(frameSize(1), row));
    col = max(1, min(frameSize(2), col));
    
    halfSize = 10;
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
    cursor.size = halfSize;
    
    numCursors = length(state.cursors);
    colors = getColors(numCursors + 1);
    cursor.color = colors{numCursors + 1};
    
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
    showHideChart(fig);
    if state.iosMode && hasValidMeta(fig)
        k = getCurrentFrame(state);
        showFrame(fig, ax, k);
    end
end

function drawCursors(fig, ax)
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
                if ~isempty(cursor.handle) && isvalid(cursor.handle)
                    delete(cursor.handle);
                    cursor.handle = [];
                end
                if ~isempty(cursor.textHandle) && isvalid(cursor.textHandle)
                    delete(cursor.textHandle);
                    cursor.textHandle = [];
                end
                state.cursors(i) = cursor;
                continue
            end
            
            row_min = cursor.rect(1);
            row_max = cursor.rect(2);
            col_min = cursor.rect(3);
            col_max = cursor.rect(4);
            
            [x1, y1] = originalToDisplay(row_min - 0.5, col_min - 0.5, state, frameSize);
            [x2, y2] = originalToDisplay(row_min - 0.5, col_max + 0.5, state, frameSize);
            [x3, y3] = originalToDisplay(row_max + 0.5, col_max + 0.5, state, frameSize);
            [x4, y4] = originalToDisplay(row_max + 0.5, col_min - 0.5, state, frameSize);
            x = [x1, x2, x3, x4];
            y = [y1, y2, y3, y4];
            
            isSelected = (~isempty(state.selectedCursorIndex) && state.selectedCursorIndex == i);
            
            cursorColor = hex2rgb(cursor.color);
            
            if isSelected
                if ~isempty(cursor.handle) && isvalid(cursor.handle) && isa(cursor.handle, 'matlab.graphics.primitive.Patch')
                    cursor.handle.XData = x;
                    cursor.handle.YData = y;
                else
                    if ~isempty(cursor.handle) && isvalid(cursor.handle)
                        delete(cursor.handle);
                    end
                    cursor.handle = patch(ax, x, y, 'r', 'FaceAlpha', 0.6, 'EdgeColor', 'r', 'LineWidth', 3, 'HitTest', 'off');
                end
            else
                xLine = [x1, x2, x3, x4, x1];
                yLine = [y1, y2, y3, y4, y1];
                if ~isempty(cursor.handle) && isvalid(cursor.handle) && isa(cursor.handle, 'matlab.graphics.primitive.Line')
                    cursor.handle.XData = xLine;
                    cursor.handle.YData = yLine;
                    cursor.handle.Color = cursorColor;
                else
                    if ~isempty(cursor.handle) && isvalid(cursor.handle)
                        delete(cursor.handle);
                    end
                    cursor.handle = line(ax, xLine, yLine, 'Color', cursorColor, 'LineWidth', 2, 'HitTest', 'off');
                end
            end
            
            if state.showIosValues
                iosValue = computeCursorIos(state, cursor, frameForIos, state.iosMode, state.baseframeData, []);
                if ~isnan(iosValue) && isfinite(iosValue)
                    [textX, textY] = originalToDisplay(row_min, col_max, state, frameSize);
                    textX = textX + 2;
                    if ~isempty(cursor.textHandle) && isvalid(cursor.textHandle)
                        cursor.textHandle.String = sprintf('%.4f', iosValue);
                        cursor.textHandle.Position = [textX, textY, 0];
                    else
                        cursor.textHandle = text(ax, textX, textY, sprintf('%.4f', iosValue), ...
                            'Color', 'yellow', 'FontSize', 10, 'FontWeight', 'bold', ...
                            'BackgroundColor', 'black', 'EdgeColor', 'yellow', 'Margin', 2);
                    end
                else
                    if ~isempty(cursor.textHandle) && isvalid(cursor.textHandle)
                        delete(cursor.textHandle);
                        cursor.textHandle = [];
                    end
                end
            else
                if ~isempty(cursor.textHandle) && isvalid(cursor.textHandle)
                    delete(cursor.textHandle);
                    cursor.textHandle = [];
                end
            end
            
            state.cursors(i) = cursor;
        end
    end
    
    if ~isempty(state.referenceCursor)
        refCursor = state.referenceCursor;
        row_min = refCursor.rect(1);
        row_max = refCursor.rect(2);
        col_min = refCursor.rect(3);
        col_max = refCursor.rect(4);
        
        [x1, y1] = originalToDisplay(row_min - 0.5, col_min - 0.5, state, frameSize);
        [x2, y2] = originalToDisplay(row_min - 0.5, col_max + 0.5, state, frameSize);
        [x3, y3] = originalToDisplay(row_max + 0.5, col_max + 0.5, state, frameSize);
        [x4, y4] = originalToDisplay(row_max + 0.5, col_min - 0.5, state, frameSize);
        x = [x1, x2, x3, x4, x1];
        y = [y1, y2, y3, y4, y1];
        
        if ~isempty(refCursor.handle) && isvalid(refCursor.handle) && isa(refCursor.handle, 'matlab.graphics.primitive.Line')
            refCursor.handle.XData = x;
            refCursor.handle.YData = y;
        else
            if ~isempty(refCursor.handle) && isvalid(refCursor.handle)
                delete(refCursor.handle);
            end
            refCursor.handle = line(ax, x, y, 'Color', 'b', 'LineWidth', 2, 'HitTest', 'off');
        end
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
            refIosValue = median(refIosRegion(:), 'omitnan');
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
            if state.floatingBaseMode
                visBase = 'off';
                visDelay = 'on';
            else
                visBase = vis;
                visDelay = 'off';
            end
            state.h.baseDelayEdit.Visible = visDelay;
            state.h.baseDelayText.Visible = visDelay;
            state.h.baseStartText.Visible = visBase;
            state.h.baseStartEdit.Visible = visBase;
            state.h.baseEndText.Visible = visBase;
            state.h.baseEndEdit.Visible = visBase;
            state.h.setBaseBtn.Visible = visBase;
            state.h.referenceSizeText.Visible = 'on';
            state.h.referenceSizeEdit.Visible = 'on';
            state.h.referenceFullSizeCheck.Visible = 'on';
            state.h.addReferenceBtn.Visible = 'on';
            state.h.deleteReferenceBtn.Visible = 'on';
            state.h.iosMinText.Visible = 'on';
            state.h.iosMinEdit.Visible = 'on';
            state.h.iosMaxText.Visible = 'on';
            state.h.iosMaxEdit.Visible = 'on';
            fig.UserData = state;
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
            
            for globalFrameIdx = batchStart:batchEnd
                [rawFrame, t] = loadRawFrame(state, globalFrameIdx);
                if isempty(rawFrame) || any(isnan(rawFrame(:)))
                    continue
                end
                times(globalFrameIdx) = t(1);
                
                filteredFrame = applyGaussianFilter(double(rawFrame), state.gaussianSigma);
                
                baseFrame = getBaseFrame(fig, globalFrameIdx);
                state = fig.UserData;
                if isempty(baseFrame)
                    continue
                end
                
                processedFrame = computeIOS(filteredFrame, baseFrame, state);
                
                if ~isempty(state.referenceCursor)
                    refCursor = state.referenceCursor;
                    rowRange = [refCursor.rect(1), refCursor.rect(2)];
                    colRange = [refCursor.rect(3), refCursor.rect(4)];
                    refRegion = processedFrame(rowRange(1):rowRange(2), colRange(1):colRange(2));
                    refIosValue = median(refRegion(:), 'omitnan');
                    referenceTrace(globalFrameIdx) = refIosValue;
                end
                
                if ~strcmp(state.noiseFilterType, 'none')
                    processedFrame = applyNoiseFilter(processedFrame, state.noiseFilterType, state.noiseFilterParam);
                end
                
                for cursorIdx = 1:numCursors
                    cursor = state.cursors(cursorIdx);
                    rowRange = [cursor.rect(1), cursor.rect(2)];
                    colRange = [cursor.rect(3), cursor.rect(4)];
                    cursorRegion = processedFrame(rowRange(1):rowRange(2), colRange(1):colRange(2));
                    meanIos = mean(cursorRegion(:), 'omitnan');
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
            cursorColor = hex2rgb(state.cursors(i).color);
            plot(times, traces{i}, 'Color', cursorColor, 'LineWidth', 1.5);
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
        state.h.cursorsTable.Data = cell(0, 5);
    else
        numCursors = length(state.cursors);
        data = cell(numCursors, 5);
        for i = 1:numCursors
            cursor = state.cursors(i);
            if ~isfield(cursor, 'visible')
                cursor.visible = true;
                state.cursors(i) = cursor;
            end
            if ~isfield(cursor, 'size')
                cursor.size = 10;
                state.cursors(i) = cursor;
            end
            data{i, 1} = i;
            data{i, 2} = cursor.center(1);
            data{i, 3} = cursor.center(2);
            data{i, 4} = cursor.size;
            data{i, 5} = cursor.visible;
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
        deleteCursorGraphics(cursor);
        cursor.handle = [];
    elseif colIdx == 5
        cursor.visible = logical(data{rowIdx, 5});
    else
        return
    end
    
    state.cursors(rowIdx) = cursor;
    fig.UserData = state;
    drawCursors(fig, ax);
    if state.iosMode && hasValidMeta(fig)
        k = getCurrentFrame(state);
        showFrame(fig, ax, k);
    end
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
    showHideChart(fig);
    if state.iosMode && hasValidMeta(fig)
        k = getCurrentFrame(state);
        showFrame(fig, ax, k);
    end
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
    showHideChart(fig);
    if state.iosMode && hasValidMeta(fig)
        k = getCurrentFrame(state);
        showFrame(fig, ax, k);
    end
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
    if ~isempty(state.him) && isvalid(state.him)
        ax = state.him.Parent;
    else
        allAxes = findobj(fig, 'Type', 'axes');
        chartAx = state.chartAx;
        for i = 1:length(allAxes)
            if allAxes(i) ~= chartAx
                ax = allAxes(i);
                break;
            end
        end
        if ~exist('ax', 'var')
            return
        end
    end
    drawCursors(fig, ax);
    
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
        halfSize = state.referenceSize;
        row = refCursor.center(1);
        col = refCursor.center(2);
        row_min = max(1, row - halfSize);
        row_max = min(frameSize(1), row + halfSize);
        col_min = max(1, col - halfSize);
        col_max = min(frameSize(2), col + halfSize);
        refCursor.rect = [row_min, row_max, col_min, col_max];
        refCursor.size = halfSize;
        state.referenceCursor = refCursor;
    end
    
    fig.UserData = state;
    if ~isempty(state.him) && isvalid(state.him)
        drawCursors(fig, ax);
        if state.iosMode && hasValidMeta(fig)
            k = getCurrentFrame(state);
            showFrame(fig, ax, k);
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
    fig.UserData = state;
    
    if hasValidMeta(fig)
        k = getCurrentFrame(state);
        showFrame(fig, ax, k);
    else
        drawCursors(fig, ax);
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
    
    if hasValidMeta(fig)
        k = getCurrentFrame(state);
        showFrame(fig, ax, k);
    else
        drawCursors(fig, ax);
    end
end

function state = updateChart(state, fig, ax, t)
    global iosChartData
    numCursors = length(state.cursors);
    if numCursors == 0 || isempty(iosChartData)
        return
    end
    w = max(1, round(state.chartSmoothWindow));
    frameForIos = state.him.CData;
    for i = 1:numCursors
        iosChartData(i).x = [iosChartData(i).x; t];
        iosVal = computeCursorIos(state, state.cursors(i), frameForIos, state.iosMode, state.baseframeData, []);
        iosChartData(i).y = [iosChartData(i).y, iosVal];
        yPlot = iosChartData(i).y;
        if w > 1 && numel(yPlot) >= w
            yPlot = smooth1(yPlot(:), w, 'moving');
            yPlot = yPlot(:)';
        end
        set(state.chartLines(i), 'Color', hex2rgb(state.cursors(i).color), 'XData', iosChartData(i).x, 'YData', yPlot);
    end
end

function initChart(fig)
    global iosChartData
    state = fig.UserData;
    chartAx = state.chartAx;
    maxCursors = 64;
    cla(chartAx);
    hold(chartAx, 'on');
    chartLines = [];
    iosChartData = struct('x', cell(1, maxCursors), 'y', cell(1, maxCursors));
    for i = 1:maxCursors
        hLine = plot(chartAx, NaN, NaN, 'Color', [0.5 0.5 0.5], 'LineWidth', 1.5);
        chartLines = [chartLines; hLine];
    end
    state.chartLines = chartLines;
    xlabel(chartAx, 'Time (s)');
    ylabel(chartAx, 'IOS');
    grid(chartAx, 'on');
    fig.UserData = state;
end

function clearChart(fig)
    global iosChartData
    state = fig.UserData;
    chartAx = state.chartAx;
    
    if ~isempty(chartAx) && ishghandle(chartAx)
        cla(chartAx);
    end
    
    if ~isempty(state.chartLines)
        for i = 1:length(state.chartLines)
            if ~isempty(state.chartLines(i)) && ishghandle(state.chartLines(i))
                delete(state.chartLines(i));
            end
        end
    end
    
    state.chartLines = [];
    maxCursors = 64;
    iosChartData = struct('x', cell(1, maxCursors), 'y', cell(1, maxCursors));
    fig.UserData = state;
end

function showHideChart(fig)
    state = fig.UserData;
    chartAx = state.chartAx;
    
    shouldShow = state.iosMode && ~isempty(state.cursors);
    
    if shouldShow
        state.h.clearChartBtn.Visible = 'on';
        state.h.showChartCheck.Visible = 'on';
        state.h.chartSmoothText.Visible = 'on';
        state.h.chartSmoothEdit.Visible = 'on';
        if state.h.showChartCheck.Value
            chartAx.Visible = 'on';
        else
            chartAx.Visible = 'off';
        end
    else
        chartAx.Visible = 'off';
        state.h.clearChartBtn.Visible = 'off';
        state.h.showChartCheck.Visible = 'off';
        state.h.chartSmoothText.Visible = 'off';
        state.h.chartSmoothEdit.Visible = 'off';
        clearChart(fig);
    end
    
    fig.UserData = state;
end

function onClearChart(~, fig)
    clearChart(fig);
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

function onIosRangeEdit(src, fig, ax, which)
    state = fig.UserData;
    if ~hasValidMeta(fig) || ~state.iosMode
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
    k = getCurrentFrame(state);
    showFrame(fig, ax, k);
end

function htmlStr = createIconButtonHTML(imgPath, textStr, iconSize)
    if nargin < 3
        iconSize = 30;
    end
    if nargin < 2
        textStr = '';
    end
    imgPathEscaped = strrep(imgPath, '\', '/');
    if isempty(textStr)
        htmlStr = sprintf('<html><img src="file:///%s" width="%d" height="%d"></html>', imgPathEscaped, iconSize, iconSize);
    else
        htmlStr = sprintf('<html><img src="file:///%s" width="%d" height="%d">&nbsp;%s</html>', imgPathEscaped, iconSize, iconSize, textStr);
    end
end
