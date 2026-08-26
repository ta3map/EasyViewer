function [wasApplied, sourceType, meanOpts] = setupMeanEventsGUI(config)
global visualSettings shiftCoeff meanControlsState
global time_back time_forward timeUnitFactor
global csd_split_by_channel_gaps csd_contrast_coef csd_contrast_is_display

if nargin < 1 || ~isstruct(config)
    config = struct();
end
if ~isfield(config, 'hasEvents')
    config.hasEvents = true;
end
if ~isfield(config, 'hasStimuli')
    config.hasStimuli = true;
end
if ~isfield(config, 'eventsCount')
    config.eventsCount = 0;
end
if ~isfield(config, 'stimuliCount')
    config.stimuliCount = 0;
end

wasApplied = false;
sourceType = 'events';
meanOpts = struct();

figTag = 'OptionsMeanEvents';
if activateOrCreateFigure(figTag)
    return
end

sourceItems = {};
sourceValues = {};
if config.hasEvents
    sourceItems{end+1} = 'Events';
    sourceValues{end+1} = 'events';
end
if config.hasStimuli
    sourceItems{end+1} = 'Stimuli';
    sourceValues{end+1} = 'stimuli';
end
if isempty(sourceItems)
    return
end

defaultXlims = [-time_back, time_forward] * timeUnitFactor;
if numel(defaultXlims) ~= 2 || defaultXlims(1) >= defaultXlims(2)
    defaultXlims = [-1, 1];
end

initialState = struct( ...
    'xLim', defaultXlims, ...
    'contrastPercent', normalizeCsdContrastCoef(csd_contrast_coef), ...
    'hpCutoffHz', 100, ...
    'baselineBoundary', defaultXlims(1) / 2, ...
    'hpFilterEnabled', true, ...
    'baselineEnabled', true, ...
    'muaWhiteTraces', true, ...
    'heatmapSmoothSigma', 0.1, ...
    'csd_split_by_channel_gaps', logical(csd_split_by_channel_gaps));

initialStartIndex = 1;
initialEndIndex = 0;
initialUseAll = true;
initialShowMua = false;
if isfield(visualSettings, 'show_spikes')
    initialShowMua = logical(visualSettings.show_spikes);
end
initialShowCsd = false;
if isfield(visualSettings, 'show_CSD')
    initialShowCsd = logical(visualSettings.show_CSD);
end
initialShiftSpacing = shiftCoeff;
initialRemoveBaseline = true;
if isstruct(meanControlsState) && isfield(meanControlsState, 'preDialog') && isstruct(meanControlsState.preDialog)
    preDialogState = meanControlsState.preDialog;
    if isfield(preDialogState, 'sourceType') && any(strcmp(preDialogState.sourceType, sourceValues))
        defaultSourceIdx = find(strcmp(sourceValues, preDialogState.sourceType), 1);
    end
    if isfield(preDialogState, 'startIndex') && isnumeric(preDialogState.startIndex)
        initialStartIndex = max(1, round(double(preDialogState.startIndex)));
    end
    if isfield(preDialogState, 'endIndex') && isnumeric(preDialogState.endIndex)
        initialEndIndex = max(1, round(double(preDialogState.endIndex)));
    end
    if isfield(preDialogState, 'useAll')
        initialUseAll = logical(preDialogState.useAll);
    end
    if isfield(preDialogState, 'show_spikes')
        initialShowMua = logical(preDialogState.show_spikes);
    end
    if isfield(preDialogState, 'show_CSD')
        initialShowCsd = logical(preDialogState.show_CSD);
    end
    if isfield(preDialogState, 'shiftCoeff')
        initialShiftSpacing = double(preDialogState.shiftCoeff);
    end
    if isfield(preDialogState, 'removeBaseline')
        initialRemoveBaseline = logical(preDialogState.removeBaseline);
    end
end
modeKey = 'mua';
if initialShowCsd
    modeKey = 'csd';
end
if isstruct(meanControlsState) && isfield(meanControlsState, modeKey) && isstruct(meanControlsState.(modeKey))
    initialState = mergeState(initialState, meanControlsState.(modeKey));
end
initialState.contrastPercent = normalizeCsdContrastCoef(csd_contrast_coef);

if isfield(initialState, 'xLim') && isnumeric(initialState.xLim) && numel(initialState.xLim) == 2
    if initialState.xLim(1) >= initialState.xLim(2)
        initialState.xLim = defaultXlims;
    end
else
    initialState.xLim = defaultXlims;
end

figurePos = [120, 120, 620, 460];
fig = figure('Name', 'Mean Parameters', 'Tag', figTag, ...
    'NumberTitle', 'off', 'MenuBar', 'none', 'ToolBar', 'none', ...
    'Position', figurePos, 'Resize', 'off', 'WindowStyle', 'modal', ...
    'CloseRequestFcn', @cancelCallback);

basePanel = uipanel('Parent', fig, 'Title', 'Base', 'Units', 'pixels', 'Position', [20, 300, 280, 140]);
renderPanel = uipanel('Parent', fig, 'Title', 'Render', 'Units', 'pixels', 'Position', [320, 300, 280, 140]);
preCsdPanel = uipanel('Parent', fig, 'Title', 'Pre-CSD / Heatmap', 'Units', 'pixels', 'Position', [20, 90, 580, 190]);

uicontrol('Parent', basePanel, 'Style', 'text', 'String', 'Source', ...
    'Position', [12, 86, 90, 20], 'HorizontalAlignment', 'left');
sourcePopup = uicontrol('Parent', basePanel, 'Style', 'popupmenu', ...
    'String', sourceItems, 'Position', [98, 84, 160, 24], 'BackgroundColor', 'white');
if ~exist('defaultSourceIdx', 'var') || isempty(defaultSourceIdx)
    defaultSourceIdx = find(strcmp(sourceValues, 'events'), 1);
end
if isempty(defaultSourceIdx)
    defaultSourceIdx = 1;
end
set(sourcePopup, 'Value', defaultSourceIdx);

showMua = initialShowMua;
showCsd = initialShowCsd;

showMuaCheckbox = uicontrol('Parent', basePanel, 'Style', 'checkbox', 'String', 'MUA', ...
    'Position', [12, 54, 80, 24], 'Value', double(showMua));
showCsdCheckbox = uicontrol('Parent', basePanel, 'Style', 'checkbox', 'String', 'CSD', ...
    'Position', [98, 54, 80, 24], 'Value', double(showCsd));
uicontrol('Parent', basePanel, 'Style', 'text', 'String', 'Channel spacing', ...
    'Position', [12, 22, 90, 20], 'HorizontalAlignment', 'left');
shiftEdit = uicontrol('Parent', basePanel, 'Style', 'edit', 'BackgroundColor', 'white', ...
    'String', num2str(initialShiftSpacing, '%.6g'), 'Position', [98, 20, 80, 24]);
uicontrol('Parent', renderPanel, 'Style', 'text', 'String', 'Start index', ...
    'Position', [12, 94, 80, 18], 'HorizontalAlignment', 'left');
startIndexEdit = uicontrol('Parent', renderPanel, 'Style', 'edit', 'BackgroundColor', 'white', ...
    'String', num2str(initialStartIndex), 'Position', [92, 92, 62, 22]);
uicontrol('Parent', renderPanel, 'Style', 'text', 'String', 'End index', ...
    'Position', [162, 94, 70, 18], 'HorizontalAlignment', 'left');
endIndexEdit = uicontrol('Parent', renderPanel, 'Style', 'edit', 'BackgroundColor', 'white', ...
    'String', num2str(initialEndIndex), 'Position', [232, 92, 42, 22]);
useAllCheckbox = uicontrol('Parent', renderPanel, 'Style', 'checkbox', 'String', 'All events', ...
    'Position', [12, 70, 90, 20], 'Value', double(initialUseAll), 'Callback', @syncIndexEditsEnable);
rangeHintLabel = uicontrol('Parent', renderPanel, 'Style', 'text', ...
    'String', '', 'Position', [104, 70, 166, 16], ...
    'HorizontalAlignment', 'left', 'ForegroundColor', [0.25 0.25 0.25]);

uicontrol('Parent', renderPanel, 'Style', 'text', 'String', 'X min', ...
    'Position', [12, 52, 60, 18], 'HorizontalAlignment', 'left');
xMinEdit = uicontrol('Parent', renderPanel, 'Style', 'edit', 'BackgroundColor', 'white', ...
    'String', num2str(initialState.xLim(1), '%.6g'), 'Position', [62, 50, 92, 22]);
uicontrol('Parent', renderPanel, 'Style', 'text', 'String', 'X max', ...
    'Position', [162, 52, 60, 18], 'HorizontalAlignment', 'left');
xMaxEdit = uicontrol('Parent', renderPanel, 'Style', 'edit', 'BackgroundColor', 'white', ...
    'String', num2str(initialState.xLim(2), '%.6g'), 'Position', [212, 50, 62, 22]);
removeBaselineCheckbox = uicontrol('Parent', renderPanel, 'Style', 'checkbox', 'String', 'Remove baseline', ...
    'Position', [12, 22, 122, 22], 'Value', double(initialRemoveBaseline));
muaWhiteCheckbox = uicontrol('Parent', renderPanel, 'Style', 'checkbox', 'String', 'MUA white traces', ...
    'Position', [138, 22, 136, 22], 'Value', double(logical(initialState.muaWhiteTraces)));

hpEnabledCheckbox = uicontrol('Parent', preCsdPanel, 'Style', 'checkbox', ...
    'String', 'High Pass Filter', 'Position', [12, 130, 120, 24], ...
    'Value', double(logical(initialState.hpFilterEnabled)));
uicontrol('Parent', preCsdPanel, 'Style', 'text', 'String', 'High Pass, Hz', ...
    'Position', [140, 132, 78, 20], 'HorizontalAlignment', 'left');
hpEdit = uicontrol('Parent', preCsdPanel, 'Style', 'edit', 'BackgroundColor', 'white', ...
    'String', num2str(initialState.hpCutoffHz, '%.6g'), 'Position', [220, 130, 55, 24]);
baselineEnabledCheckbox = uicontrol('Parent', preCsdPanel, 'Style', 'checkbox', ...
    'String', 'Baseline to', 'Position', [290, 130, 90, 24], ...
    'Value', double(logical(initialState.baselineEnabled)));
baselineEdit = uicontrol('Parent', preCsdPanel, 'Style', 'edit', 'BackgroundColor', 'white', ...
    'String', num2str(initialState.baselineBoundary, '%.6g'), 'Position', [382, 130, 75, 24]);
uicontrol('Parent', preCsdPanel, 'Style', 'text', 'String', 'Smooth', ...
    'Position', [12, 92, 70, 20], 'HorizontalAlignment', 'left');
smoothEdit = uicontrol('Parent', preCsdPanel, 'Style', 'edit', 'BackgroundColor', 'white', ...
    'String', num2str(initialState.heatmapSmoothSigma, '%.6g'), 'Position', [82, 90, 85, 24]);
uicontrol('Parent', preCsdPanel, 'Style', 'text', 'String', 'Contrast, %', ...
    'Position', [190, 92, 80, 20], 'HorizontalAlignment', 'left');
contrastEdit = uicontrol('Parent', preCsdPanel, 'Style', 'edit', 'BackgroundColor', 'white', ...
    'String', num2str(initialState.contrastPercent, '%.6g'), 'Position', [266, 90, 85, 24]);
splitGroupsCheckbox = uicontrol('Parent', preCsdPanel, 'Style', 'checkbox', ...
    'String', 'Split channel groups', ...
    'Position', [12, 50, 160, 24], ...
    'Value', double(logical(initialState.csd_split_by_channel_gaps)));

set(hpEnabledCheckbox, 'Callback', @syncHpEditEnable);
syncHpEditEnable();
set(baselineEnabledCheckbox, 'Callback', @syncBaselineEditEnable);
syncBaselineEditEnable();
set(showMuaCheckbox, 'Callback', @syncMuaWhiteVisibility);
set(sourcePopup, 'Callback', @sourceChangedCallback);
syncMuaWhiteVisibility();
sourceChangedCallback();
syncIndexEditsEnable();

uicontrol('Parent', fig, 'Style', 'pushbutton', 'String', 'Apply', ...
    'Position', [220, 26, 90, 38], 'Callback', @applyCallback);
uicontrol('Parent', fig, 'Style', 'pushbutton', 'String', 'Cancel', ...
    'Position', [322, 26, 90, 38], 'Callback', @cancelCallback);

uiwait(fig);

    function out = mergeState(baseState, overrideState)
        out = baseState;
        if ~isstruct(overrideState)
            return
        end
        fields = fieldnames(baseState);
        for k = 1:numel(fields)
            f = fields{k};
            if isfield(overrideState, f)
                out.(f) = overrideState.(f);
            end
        end
    end

    function applyCallback(~, ~)
        sourceType = sourceValues{get(sourcePopup, 'Value')};
        showMuaVal = logical(get(showMuaCheckbox, 'Value'));
        showCsdVal = logical(get(showCsdCheckbox, 'Value'));
        startIndexVal = str2double(strrep(get(startIndexEdit, 'String'), ',', '.'));
        endIndexVal = str2double(strrep(get(endIndexEdit, 'String'), ',', '.'));
        useAllVal = logical(get(useAllCheckbox, 'Value'));

        shiftVal = str2double(strrep(get(shiftEdit, 'String'), ',', '.'));
        xMinVal = str2double(strrep(get(xMinEdit, 'String'), ',', '.'));
        xMaxVal = str2double(strrep(get(xMaxEdit, 'String'), ',', '.'));
        hpVal = str2double(strrep(get(hpEdit, 'String'), ',', '.'));
        baselineVal = str2double(strrep(get(baselineEdit, 'String'), ',', '.'));
        smoothVal = str2double(strrep(get(smoothEdit, 'String'), ',', '.'));
        contrastVal = str2double(strrep(get(contrastEdit, 'String'), ',', '.'));

        numbers = [shiftVal, xMinVal, xMaxVal, hpVal, baselineVal, smoothVal, contrastVal, startIndexVal, endIndexVal];
        if any(~isfinite(numbers)) || any(isnan(numbers))
            errordlg('Please fill all numeric fields with valid numbers.', 'Mean Parameters', 'modal');
            return
        end
        if shiftVal <= 0
            errordlg('Channel spacing must be > 0.', 'Mean Parameters', 'modal');
            return
        end
        if xMinVal >= xMaxVal
            errordlg('X min must be less than X max.', 'Mean Parameters', 'modal');
            return
        end
        selectedCount = sourceCount(sourceType);
        rangeMin = 1;
        rangeMax = max(1, selectedCount);
        startIndexVal = round(startIndexVal);
        endIndexVal = round(endIndexVal);
        calcStart = startIndexVal;
        calcEnd = endIndexVal;
        if useAllVal
            calcStart = rangeMin;
            calcEnd = rangeMax;
        end
        if selectedCount < 1
            errordlg(sprintf('No points available for "%s".', sourceType), 'Mean Parameters', 'modal');
            return
        end
        if calcStart < rangeMin || calcStart > rangeMax || calcEnd < rangeMin || calcEnd > rangeMax || calcStart > calcEnd
            errordlg(sprintf('Invalid index range [%d, %d]. Available range: [%d, %d].', ...
                calcStart, calcEnd, rangeMin, rangeMax), ...
                'Mean Parameters', 'modal');
            return
        end

        removeBaselineVal = logical(get(removeBaselineCheckbox, 'Value'));
        hpEnabledVal = logical(get(hpEnabledCheckbox, 'Value'));
        baselineEnabledVal = logical(get(baselineEnabledCheckbox, 'Value'));
        muaWhiteVal = logical(get(muaWhiteCheckbox, 'Value'));
        splitGroupsVal = logical(get(splitGroupsCheckbox, 'Value'));

        meanOpts = struct();
        meanOpts.removeBaseline = removeBaselineVal;
        meanOpts.show_spikes = showMuaVal;
        meanOpts.show_CSD = showCsdVal;
        meanOpts.shiftCoeff = shiftVal;
        meanOpts.xLimits = [xMinVal, xMaxVal];
        meanOpts.csd_hp_cutoff_hz = hpVal;
        meanOpts.csd_baseline_boundary = baselineVal;
        meanOpts.hpFilterEnabled = hpEnabledVal;
        meanOpts.baselineEnabled = baselineEnabledVal;
        meanOpts.heatmapSmoothSigma = smoothVal;
        meanOpts.contrastPercent = contrastVal;
        meanOpts.muaWhiteTraces = muaWhiteVal;
        meanOpts.startIndex = calcStart;
        meanOpts.endIndex = calcEnd;
        meanOpts.csd_split_by_channel_gaps = splitGroupsVal;
        csd_split_by_channel_gaps = splitGroupsVal;
        csd_contrast_coef = normalizeCsdContrastCoef(contrastVal);
        csd_contrast_is_display = true;
        if ~isstruct(meanControlsState)
            meanControlsState = struct();
        end
        modeKey = 'mua';
        if showCsdVal
            modeKey = 'csd';
        end
        meanControlsState.(modeKey) = struct( ...
            'contrastPercent', contrastVal, ...
            'hpCutoffHz', hpVal, ...
            'baselineBoundary', baselineVal, ...
            'xLim', [xMinVal, xMaxVal], ...
            'hpFilterEnabled', hpEnabledVal, ...
            'baselineEnabled', baselineEnabledVal, ...
            'muaWhiteTraces', muaWhiteVal, ...
            'heatmapSmoothSigma', smoothVal, ...
            'csd_split_by_channel_gaps', splitGroupsVal);
        meanControlsState.preDialog = struct( ...
            'sourceType', sourceType, ...
            'startIndex', startIndexVal, ...
            'endIndex', endIndexVal, ...
            'useAll', useAllVal, ...
            'show_spikes', showMuaVal, ...
            'show_CSD', showCsdVal, ...
            'shiftCoeff', shiftVal, ...
            'removeBaseline', removeBaselineVal, ...
            'csd_split_by_channel_gaps', splitGroupsVal);
        saveChannelSettings('meanControlsState', 'csd_contrast_coef', 'csd_contrast_is_display', 'csd_split_by_channel_gaps');

        wasApplied = true;
        uiresume(fig);
        delete(fig);
    end

    function cancelCallback(~, ~)
        wasApplied = false;
        if isvalid(fig)
            uiresume(fig);
            delete(fig);
        end
    end

    function sourceChangedCallback(~, ~)
        selectedSourceType = sourceValues{get(sourcePopup, 'Value')};
        selectedCount = sourceCount(selectedSourceType);
        maxIndex = max(1, selectedCount);
        if initialEndIndex < 1
            initialEndIndex = maxIndex;
        end
        set(startIndexEdit, 'String', num2str(min(max(initialStartIndex, 1), maxIndex)));
        set(endIndexEdit, 'String', num2str(min(max(initialEndIndex, 1), maxIndex)));
        set(rangeHintLabel, 'String', sprintf('Available range: 1..%d', maxIndex));
    end

    function syncIndexEditsEnable(~, ~)
        enableState = 'on';
        if logical(get(useAllCheckbox, 'Value'))
            enableState = 'off';
        end
        set(startIndexEdit, 'Enable', enableState);
        set(endIndexEdit, 'Enable', enableState);
    end

    function syncMuaWhiteVisibility(~, ~)
        visibleState = 'off';
        if logical(get(showMuaCheckbox, 'Value'))
            visibleState = 'on';
        end
        set(muaWhiteCheckbox, 'Visible', visibleState);
    end

    function syncBaselineEditEnable(~, ~)
        enableState = 'off';
        if logical(get(baselineEnabledCheckbox, 'Value'))
            enableState = 'on';
        end
        set(baselineEdit, 'Enable', enableState);
    end

    function syncHpEditEnable(~, ~)
        enableState = 'off';
        if logical(get(hpEnabledCheckbox, 'Value'))
            enableState = 'on';
        end
        set(hpEdit, 'Enable', enableState);
    end

    function count = sourceCount(sourceTypeIn)
        count = config.eventsCount;
        if strcmp(sourceTypeIn, 'stimuli')
            count = config.stimuliCount;
        end
    end
end
