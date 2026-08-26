function autoEventDetectionGUI()
    % Загрузка настроек только из локального *_channelSettings.stn
    global events event_comments hd evfilename eventDeleteEdit
    global events_exist event_inx
    global table_calling event_title_string updatePlotFunc
    global timeUnitFactor selectedUnit matFilePath
    global hMinPeakProminence hDetectionType hMainChannel hSubtractChannelCheck hSubtractChannel hMaxPeakWidth
    global hMinPeakDistance
    global hSourceType selectedCenter timeCenterPopup windowSize chosen_time_interval
    global hSearchAroundStimuli hSearchWindow hSearchAroundDirection stims_exist stims
    global hUseTimeRange hStartTime hEndTime time
    global hShowMeanPreview
    global wb
    global autodetection_settings

    settings = [];
    if ~isempty(matFilePath)
        [settingsPath, settingsName, ~] = fileparts(matFilePath);
        channelSettingsFilePath = fullfile(settingsPath, [settingsName '_channelSettings.stn']);
        if exist(channelSettingsFilePath, 'file') == 2
            loadedLocal = load(channelSettingsFilePath, '-mat');
            if isfield(loadedLocal, 'autodetection_settings') && isstruct(loadedLocal.autodetection_settings)
                settings = loadedLocal.autodetection_settings;
            end
        end
    end
    if isempty(settings) && isstruct(autodetection_settings) && isfield(autodetection_settings, 'MinPeakProminence')
        settings = autodetection_settings;
    end
    if ~isempty(settings)
        autodetection_settings = settings;
    end
    
    [coordsData, coordsFile] = loadGUICoords('autoEventDetectionGUI_coords.json');
    relativeTags = {'plotPanel'};
    getElementPosition = @(tag) getGUIElementPosition(coordsData, tag, relativeTags);
    
    % Результаты детекции — только локально в этом GUI (не global)
    amplitudes_detected = [];
    widths_detected = [];
    channels_detected = [];
    metadata_detected = [];
    indices_detected = [];
    prominences_detected = [];
    events_detected = [];
    
    % Идентификатор (tag) для GUI фигуры
    figTag = 'EventDetection';
    
    % Поиск открытой фигуры с заданным идентификатором
    guiFig = findobj('Type', 'figure', 'Tag', figTag);
    
    if ~isempty(guiFig)
        % Делаем существующее окно текущим (активным)
        figure(guiFig);
        return
    end
        
    % Окно Auto Event Detection
    base_figure_position = coordsData.base_figure_position;
    detectionFig = figure('Name', 'Auto Event Detection', 'Tag', figTag, ...
        'Resize', 'on', ...
        'NumberTitle', 'off', 'MenuBar', 'none', 'ToolBar', 'figure', 'Position', base_figure_position, ...
        'Visible', 'off');
    
    % Эксперимент: включаем тулбар при создании, затем скрываем его
    hToolbar = findall(detectionFig, 'Type', 'uitoolbar');
    if ~isempty(hToolbar)
        set(hToolbar, 'Visible', 'off');
    end
    
    % Окно выбора источника данных LFP или CSD
    uicontrol(detectionFig, 'Style', 'text', 'Position', getElementPosition('sourceText'), 'String', 'Source:', 'Tag', 'sourceText', 'Visible', 'off');
    hSourceType = uicontrol(detectionFig, 'Style', 'popupmenu', 'Position', getElementPosition('sourceType'), 'String', {'LFP', 'CSD'}, 'Callback', @changeDetectionType, 'Tag', 'sourceType', 'Visible', 'off');

    % Режим: Positive / Negative
    uicontrol(detectionFig, 'Style', 'text', 'Position', getElementPosition('detectionTypeText'), 'String', 'Mode:', 'Tag', 'detectionTypeText');
    hDetectionType = uicontrol(detectionFig, 'Style', 'popupmenu', 'Position', getElementPosition('detectionType'), 'String', {'Positive', 'Negative'}, 'Callback', @detectionControlsCallback, 'Tag', 'detectionType');

    % Основной канал и опция вычитания другого канала
    uicontrol(detectionFig, 'Style', 'text', 'Position', getElementPosition('chPosText'), 'String', 'Channel:', 'Tag', 'chPosText');
    hMainChannel = uicontrol(detectionFig, 'Style', 'popupmenu', 'Position', getElementPosition('chPos'), 'String', hd.recChNames, 'Callback', @mainChannelCallback, 'Tag', 'chPos');
    hSubtractChannelCheck = uicontrol(detectionFig, 'Style', 'checkbox', 'Position', getElementPosition('subtractChannelCheckbox'), 'String', 'Subtract another channel', 'Value', 0, 'Callback', @detectionControlsCallback, 'Tag', 'subtractChannelCheckbox');
    hChNeg_text = uicontrol(detectionFig, 'Style', 'text', 'Position', getElementPosition('chNegText'), 'String', 'Channel to subtract:', 'Tag', 'chNegText', 'Visible', 'off');
    hSubtractChannel = uicontrol(detectionFig, 'Style', 'popupmenu', 'Position', getElementPosition('chNeg'), 'String', hd.recChNames, 'Callback', @detectionControlsCallback, 'Tag', 'chNeg', 'Visible', 'off');
    
    % Окошко для ввода минимальной высоты пика
    hMinPeakProminence_text = uicontrol(detectionFig, 'Style', 'text', 'Position', getElementPosition('minPeakProminenceText'), 'String', 'Threshold:', 'Tag', 'minPeakProminenceText');
    hMinPeakProminence = uicontrol(detectionFig, 'Style', 'edit', 'Position', getElementPosition('minPeakProminence'), 'String', '50', 'Tag', 'minPeakProminence');

    % Окошко для ввода MinPeakDistance
    hMinPeakDistance_text = uicontrol(detectionFig, 'Style', 'text', 'Position', getElementPosition('minPeakDistanceText'), 'String', ['Minimal Time Between Peaks (' selectedUnit '):'], 'Tag', 'minPeakDistanceText');
    hMinPeakDistance = uicontrol(detectionFig, 'Style', 'edit', 'Position', getElementPosition('minPeakDistance'), 'String', num2str(3*timeUnitFactor), 'Tag', 'minPeakDistance');

    hMaxPeakWidth_text = uicontrol(detectionFig, 'Style', 'text', 'Position', getElementPosition('maxPeakWidthText'), 'String', ['Max peak width (' selectedUnit '):'], 'Tag', 'maxPeakWidthText');
    hMaxPeakWidth = uicontrol(detectionFig, 'Style', 'edit', 'Position', getElementPosition('maxPeakWidth'), 'String', num2str(0.05*timeUnitFactor), 'Tag', 'maxPeakWidth');

    % Чекбокс для использования временного диапазона
    hUseTimeRange = uicontrol(detectionFig, 'Style', 'checkbox', 'Position', getElementPosition('useTimeRange'), 'String', 'Use time range', 'Value', 0, 'Callback', @timeRangeCallback, 'Tag', 'useTimeRange');
    
    % Поля ввода времени начала и конца
    hStartTimeLabel = uicontrol(detectionFig, 'Style', 'text', 'Position', getElementPosition('startTimeLabel'), 'String', ['Start (' selectedUnit '):'], 'Visible', 'off', 'Tag', 'startTimeLabel');
    hStartTime = uicontrol(detectionFig, 'Style', 'edit', 'Position', getElementPosition('startTime'), 'String', num2str(time(1)*timeUnitFactor), 'Visible', 'off', 'Tag', 'startTime');
    
    hEndTimeLabel = uicontrol(detectionFig, 'Style', 'text', 'Position', getElementPosition('endTimeLabel'), 'String', ['End (' selectedUnit '):'], 'Visible', 'off', 'Tag', 'endTimeLabel');
    hEndTime = uicontrol(detectionFig, 'Style', 'edit', 'Position', getElementPosition('endTime'), 'String', num2str(time(end)*timeUnitFactor), 'Visible', 'off', 'Tag', 'endTime');

    % Чекбокс для поиска вокруг стимулов
    hSearchAroundStimuli = uicontrol(detectionFig, 'Style', 'checkbox', 'Position', getElementPosition('searchAroundStimuli'), 'String', 'Search around stimuli', 'Value', 0, 'Callback', @changeDetectionType, 'Tag', 'searchAroundStimuli');
    
    % Поле ввода размера окна поиска
    hSearchWindow_text = uicontrol(detectionFig, 'Style', 'text', 'Position', getElementPosition('searchWindowText'), 'String', ['Search window (' selectedUnit '):'], 'Tag', 'searchWindowText');
    hSearchWindow = uicontrol(detectionFig, 'Style', 'edit', 'Position', getElementPosition('searchWindow'), 'String', num2str(0.5*timeUnitFactor), 'Tag', 'searchWindow');

    % Выпадающий список направления окна поиска
    hSearchAroundDirection_text = uicontrol(detectionFig, 'Style', 'text', ...
        'Position', getElementPosition('searchDirectionText'), ...
        'String', 'Search direction:', ...
        'Tag', 'searchDirectionText', 'Visible', 'off');
    hSearchAroundDirection = uicontrol(detectionFig, 'Style', 'popupmenu', ...
        'Position', getElementPosition('searchDirection'), ...
        'String', {'Two-sided (-window..+window)', 'One-sided after (0..+window)'}, ...
        'Value', 2, ...
        'Tag', 'searchDirection', 'Visible', 'off');

    hShowMeanPreview = uicontrol(detectionFig, 'Style', 'checkbox', ...
        'Position', getElementPosition('showMeanPreview'), ...
        'String', 'Show mean preview', 'Value', 0, ...
        'Tag', 'showMeanPreview');

    % Инициализация видимости элементов в зависимости от наличия стимулов
    changeDetectionType();

    % Создаем контейнер для графиков (аналогично plotFromTableGUI.m)
    plotPanel = uipanel('Parent', detectionFig, ...
        'Position', getElementPosition('plotPanel'), ...
        'Tag', 'plotPanel');
    
    % Инициализация значений из настроек (без колбэков — иначе autoThreshold затирает порог)
    set([hDetectionType, hMainChannel, hSubtractChannelCheck, hSubtractChannel, hUseTimeRange], 'Callback', []);
    nCh = numel(hd.recChNames);
    validMode = ~isempty(settings) && isfield(settings, 'PolarityIndex') && isfield(settings, 'MainChannel') && ...
        isfield(settings, 'SubtractChannelEnabled') && isfield(settings, 'SubtractChannel');
    if validMode
        pi = round(settings.PolarityIndex);
        mc = round(settings.MainChannel);
        sc = round(settings.SubtractChannel);
        if (pi >= 1 && pi <= 2) && (mc >= 1 && mc <= nCh) && (sc >= 1 && sc <= nCh)
            set(hDetectionType, 'Value', pi);
            set(hMainChannel, 'Value', mc);
            set(hSubtractChannelCheck, 'Value', settings.SubtractChannelEnabled);
            set(hSubtractChannel, 'Value', sc);
        else
            validMode = false;
        end
    end
    if ~validMode
        set(hDetectionType, 'Value', 1);
        set(hMainChannel, 'Value', 1);
        set(hSubtractChannelCheck, 'Value', 0);
        set(hSubtractChannel, 'Value', 1);
    end

    if ~isempty(settings)
        safeSetPopupValue(hSourceType, settings.SourceTypeIndex, ...
                          numel(get(hSourceType,'String')), 'SourceType');

        set(hMinPeakProminence, 'String', num2str(settings.MinPeakProminence));

        set(hMinPeakDistance, 'String', num2str(settings.MinPeakDistance*timeUnitFactor));
        set(hMinPeakDistance_text, 'String', ['Minimal Time Between Peaks (' selectedUnit '):']);
        
        if isfield(settings, 'SourceTypeIndex')
            if ~isempty(settings.SourceTypeIndex)
                set(hSourceType, 'Value', settings.SourceTypeIndex);
            else
                set(hSourceType, 'Value', 1);
            end
        else
            set(hSourceType, 'Value', 1);
        end
        
        if isfield(settings, 'MaxPeakWidth')
            if ~isempty(settings.MaxPeakWidth)
                set(hMaxPeakWidth, 'String', num2str(settings.MaxPeakWidth*timeUnitFactor));
            else
                set(hMaxPeakWidth, 'String', num2str(0.05*timeUnitFactor));
            end
        end
        set(hMaxPeakWidth_text, 'String', ['Max peak width (' selectedUnit '):']);
        
        % Вызовите функции изменения режима/типа детекции, если необходимо
        changeDetectionType()
        
        % Инициализация новых параметров из настроек
        if isfield(settings, 'SearchAroundStimuli')
            set(hSearchAroundStimuli, 'Value', settings.SearchAroundStimuli);
        end
        if isfield(settings, 'SearchWindow')
            set(hSearchWindow, 'String', num2str(settings.SearchWindow*timeUnitFactor));
        end
        if isfield(settings, 'SearchAroundDirection')
            safeSetPopupValue(hSearchAroundDirection, settings.SearchAroundDirection, ...
                numel(get(hSearchAroundDirection, 'String')), 'SearchAroundDirection');
        end
        
        % Обновляем видимость поля Search window после загрузки настроек
        if stims_exist
            search_enabled = get(hSearchAroundStimuli, 'Value');
            if search_enabled
                set(hSearchWindow_text, 'visible', 'on')
                set(hSearchWindow, 'visible', 'on')
                set(hSearchAroundDirection_text, 'visible', 'on')
                set(hSearchAroundDirection, 'visible', 'on')
            else
                set(hSearchWindow_text, 'visible', 'off')
                set(hSearchWindow, 'visible', 'off')
                set(hSearchAroundDirection_text, 'visible', 'off')
                set(hSearchAroundDirection, 'visible', 'off')
            end
        end
        
        % Инициализация параметров временного диапазона из настроек
        if isfield(settings, 'UseTimeRange')
            set(hUseTimeRange, 'Value', settings.UseTimeRange);
        end
        if isfield(settings, 'StartTime')
            set(hStartTime, 'String', num2str(settings.StartTime*timeUnitFactor));
        end
        if isfield(settings, 'EndTime')
            set(hEndTime, 'String', num2str(settings.EndTime*timeUnitFactor));
        end
        if isfield(settings, 'ShowMeanPreview')
            set(hShowMeanPreview, 'Value', settings.ShowMeanPreview);
        end
        
        % Обновляем видимость полей временного диапазона после загрузки настроек
        useTimeRange = get(hUseTimeRange, 'Value');
        if useTimeRange
            set(hStartTimeLabel, 'visible', 'on')
            set(hStartTime, 'visible', 'on')
            set(hEndTimeLabel, 'visible', 'on')
            set(hEndTime, 'visible', 'on')
        else
            set(hStartTimeLabel, 'visible', 'off')
            set(hStartTime, 'visible', 'off')
            set(hEndTimeLabel, 'visible', 'off')
            set(hEndTime, 'visible', 'off')
        end
        changeDetectionType();
    end
    set(hDetectionType, 'Callback', @detectionControlsCallback);
    set(hMainChannel, 'Callback', @mainChannelCallback);
    set(hSubtractChannelCheck, 'Callback', @detectionControlsCallback);
    set(hSubtractChannel, 'Callback', @detectionControlsCallback);
    set(hUseTimeRange, 'Callback', @timeRangeCallback);

    % Кнопка сброса настроек (слева от Check Detection)
    uicontrol(detectionFig, 'Style', 'pushbutton', 'String', 'Reset settings',...
        'Position', getElementPosition('resetSettingsBtn'), 'Callback', @resetSettingsCallback, 'Tag', 'resetSettingsBtn');
    % Кнопка 'Check Detection'
    uicontrol(detectionFig, 'Style', 'pushbutton', 'String', 'Check Detection',...
        'Position', getElementPosition('checkDetectionBtn'), 'Callback', @checkDetectionCallback, 'Tag', 'checkDetectionBtn');
    set(hMinPeakProminence, 'Callback', @previewThresholdOnly);
    set([hStartTime, hEndTime], 'Callback', @previewData);

    % Кнопка 'Apply'
    applybutton = uicontrol(detectionFig, 'Style', 'pushbutton', 'String', 'Apply',...
        'Position', getElementPosition('applyBtn'), 'Callback', @detectButtonCallback, 'Tag', 'applyBtn');
    set(applybutton, 'Enable', 'off')
    
    % Устанавливаем обработчик изменения размера окна
    set(detectionFig, 'SizeChangedFcn', @(~,~) resizeComponentsCallback(detectionFig, coordsFile));
    
    detectionFig.WindowState = 'maximized';
    
    hasPlotSnapshot = ~isempty(settings) && isfield(settings, 'plotSnapshot') && isstruct(settings.plotSnapshot) ...
        && isfield(settings.plotSnapshot, 'Trace_out');
    if hasPlotSnapshot
        snap = settings.plotSnapshot;
        if ~get(hShowMeanPreview, 'Value')
            snap.meanTrace = [];
            snap.meanMin = [];
            snap.meanMax = [];
            snap.meanRaster = [];
            snap.meanTime = [];
            snap.meanN = 0;
        end
        events_detected = snap.events_detected;
        amplitudes_detected = [];
        widths_detected = [];
        channels_detected = [];
        metadata_detected = [];
        indices_detected = [];
        if isfield(snap, 'amplitudes_detected')
            amplitudes_detected = snap.amplitudes_detected;
        end
        if isfield(snap, 'widths_detected')
            widths_detected = snap.widths_detected;
        end
        if isfield(snap, 'channels_detected')
            channels_detected = snap.channels_detected;
        end
        if isfield(snap, 'metadata_detected')
            metadata_detected = snap.metadata_detected;
        end
        if isfield(snap, 'indices_detected')
            indices_detected = snap.indices_detected;
        end
        drawPlotsFromSnapshot(snap);
        updateApplyButton();
        if isfield(settings, 'MinPeakProminence')
            set(hMinPeakProminence, 'String', num2str(settings.MinPeakProminence));
        end
    else
        previewData();
        if ~isempty(settings) && isfield(settings, 'MinPeakProminence')
            set(hMinPeakProminence, 'String', num2str(settings.MinPeakProminence));
        end
    end
    
    set(detectionFig, 'Visible', 'on');
    
    % Функция обратного вызова для изменения размера
    function resizeComponentsCallback(figHandle, coordsFile)
        try
            ResizeElements(figHandle, coordsFile);
        catch ME
            warning('Error scaling elements: %s', ME.message);
        end
    end

    function timeRangeCallback(~, ~)
        isChecked = get(hUseTimeRange, 'Value');
        if isChecked
            set(hSearchAroundStimuli, 'Value', 0);
        end
        if isChecked
            set(hStartTimeLabel, 'Visible', 'on');
            set(hStartTime, 'Visible', 'on');
            set(hEndTimeLabel, 'Visible', 'on');
            set(hEndTime, 'Visible', 'on');
        else
            set(hStartTimeLabel, 'Visible', 'off');
            set(hStartTime, 'Visible', 'off');
            set(hEndTimeLabel, 'Visible', 'off');
            set(hEndTime, 'Visible', 'off');
        end
        changeDetectionType();
        previewData();
    end

    function mainChannelCallback(~, ~)
        changeDetectionType();
        previewData('autoThreshold');
    end

    function detectionControlsCallback(~, ~)
        changeDetectionType();
        previewData('autoThreshold');
    end

    function [detectionType, chPos, chNeg] = uiToDetectionParams()
        polarityIdx = get(hDetectionType, 'Value');
        mainCh = get(hMainChannel, 'Value');
        subtractOn = get(hSubtractChannelCheck, 'Value');
        subtractCh = get(hSubtractChannel, 'Value');
        nCh = numel(hd.recChNames);
        mainCh = min(max(mainCh, 1), nCh);
        subtractCh = min(max(subtractCh, 1), nCh);
        if polarityIdx == 1
            if ~subtractOn
                detectionType = 'one channel positive';
                chPos = mainCh;
                chNeg = 1;
            else
                detectionType = 'two channels difference';
                chPos = mainCh;
                chNeg = subtractCh;
            end
        else
            if ~subtractOn
                detectionType = 'one channel negative';
                chPos = 1;
                chNeg = mainCh;
            else
                detectionType = 'two channels difference';
                chPos = subtractCh;
                chNeg = mainCh;
            end
        end
    end

    function resetSettingsCallback(~, ~)
        set(hDetectionType, 'Value', 1);
        set(hMainChannel, 'Value', 1);
        set(hSubtractChannelCheck, 'Value', 0);
        set(hSubtractChannel, 'Value', 1);
        set(hSourceType, 'Value', 1);
        set(hMinPeakProminence, 'String', '50');
        set(hMinPeakDistance, 'String', num2str(3*timeUnitFactor));
        set(hMaxPeakWidth, 'String', num2str(0.05*timeUnitFactor));
        set(hUseTimeRange, 'Value', 0);
        set(hStartTime, 'String', num2str(time(1)*timeUnitFactor));
        set(hEndTime, 'String', num2str(time(end)*timeUnitFactor));
        set(hSearchAroundStimuli, 'Value', 0);
        set(hSearchWindow, 'String', num2str(0.5*timeUnitFactor));
        set(hSearchAroundDirection, 'Value', 2);
        set(hShowMeanPreview, 'Value', 0);
        changeDetectionType();
    end

    function changeDetectionType(~,~)
        subtractOn = get(hSubtractChannelCheck, 'Value');
        set(hChNeg_text, 'Visible', subtractOn);
        set(hSubtractChannel, 'Visible', subtractOn);

        % Управление видимостью элементов временного диапазона
        useTimeRange = get(hUseTimeRange, 'Value');
        if useTimeRange
            set(hStartTimeLabel, 'visible', 'on')
            set(hStartTime, 'visible', 'on')
            set(hEndTimeLabel, 'visible', 'on')
            set(hEndTime, 'visible', 'on')
        else
            set(hStartTimeLabel, 'visible', 'off')
            set(hStartTime, 'visible', 'off')
            set(hEndTimeLabel, 'visible', 'off')
            set(hEndTime, 'visible', 'off')
        end
        
        % Показывать/скрывать элементы поиска вокруг стимулов
        if stims_exist
            set(hSearchAroundStimuli, 'visible', 'on')
            % Если включен поиск вокруг стимулов, выключаем временной диапазон
            search_enabled = get(hSearchAroundStimuli, 'Value');
            if search_enabled
                set(hUseTimeRange, 'Value', 0)
                useTimeRange = 0;
                set(hStartTimeLabel, 'visible', 'off')
                set(hStartTime, 'visible', 'off')
                set(hEndTimeLabel, 'visible', 'off')
                set(hEndTime, 'visible', 'off')
            end
            % Поле Search window видно только если чекбокс включен и не включен временной диапазон
            if search_enabled && ~useTimeRange
                set(hSearchWindow_text, 'visible', 'on')
                set(hSearchWindow, 'visible', 'on')
                set(hSearchAroundDirection_text, 'visible', 'on')
                set(hSearchAroundDirection, 'visible', 'on')
            else
                set(hSearchWindow_text, 'visible', 'off')
                set(hSearchWindow, 'visible', 'off')
                set(hSearchAroundDirection_text, 'visible', 'off')
                set(hSearchAroundDirection, 'visible', 'off')
            end
        else
            set(hSearchAroundStimuli, 'visible', 'off')
            set(hSearchWindow_text, 'visible', 'off')
            set(hSearchWindow, 'visible', 'off')
            set(hSearchAroundDirection_text, 'visible', 'off')
            set(hSearchAroundDirection, 'visible', 'off')
            set(hSearchAroundStimuli, 'Value', 0)
        end
        
%         previewData()

    end

    function previewData(src, ~)
        % Пересчёт трассы: канал / polarity / subtract / time range.
        if isempty(wb) || ~isvalid(wb)
            wb = createCancelableWaitbar(0, 'Preview: preparing...', 'Event Detection');
        else
            setappdata(wb, 'canceling', 0);
            waitbar(0, wb, 'Preview: preparing...');
        end
        drawnow;
        [params.DetectionType, params.ChPos, params.ChNeg] = uiToDetectionParams();
        params.MinPeakProminence = str2double(get(hMinPeakProminence, 'String'));
        params.MinPeakDistance = str2double(get(hMinPeakDistance, 'String')) / timeUnitFactor;
        SourceTypes = get(hSourceType, 'String');
        params.SourceType = SourceTypes{get(hSourceType, 'Value')};
        params.detect = false;
        params.max_peak_width = str2double(get(hMaxPeakWidth, 'String')) / timeUnitFactor;
        params.SearchAroundStimuli = get(hSearchAroundStimuli, 'Value');
        params.SearchWindow = str2double(get(hSearchWindow, 'String')) / timeUnitFactor;
        params.SearchAroundDirection = get(hSearchAroundDirection, 'Value');
        params.UseTimeRange = get(hUseTimeRange, 'Value');
        params.StartTime = str2double(get(hStartTime, 'String')) / timeUnitFactor;
        params.EndTime = str2double(get(hEndTime, 'String')) / timeUnitFactor;
        params.ShowMeanPreview = get(hShowMeanPreview, 'Value');

        [~, Trace_out, time_res, ~, ~, ~, ~, ~, ~, wasCanceled] = autoEventDetection(params);
        if wasCanceled
            return;
        end

        Trace_out(isnan(Trace_out)) = 0;
        Trace_out(isinf(Trace_out)) = 0;

        autoThreshold = nargin > 0 && ischar(src);
        updatePreviewPlots(Trace_out, time_res, params, autoThreshold);
    end

    function previewThresholdOnly(~, ~)
        chosen_th = str2double(get(hMinPeakProminence, 'String'));
        plotPanelLocal = findobj(detectionFig, 'Tag', 'plotPanel');
        ax1 = findobj(plotPanelLocal, 'Tag', 'axPreviewTrace');
        ax2 = findobj(plotPanelLocal, 'Tag', 'axPreviewHist');
        if isempty(ax1) || isempty(ax2)
            return;
        end
        set(findobj(ax1, 'Tag', 'ylChosenTh'), 'Value', chosen_th);
        set(findobj(ax2, 'Tag', 'ylChosenTh'), 'Value', chosen_th);
        yl = ylim(ax2);
        ySpan = yl(2) - yl(1);
        labelLift = 0.05 * ySpan;
        valueLift = 0.02 * ySpan;
        topPad = 0.01 * ySpan;
        hLabel = findobj(ax2, 'Tag', 'txtChosenThLabel');
        hValue = findobj(ax2, 'Tag', 'txtChosenThValue');
        set(hLabel, 'Position', [hLabel.Position(1), min(chosen_th + labelLift, yl(2) - topPad), 0]);
        set(hValue, 'String', num2str(chosen_th, 3), ...
            'Position', [hValue.Position(1), min(chosen_th + valueLift, yl(2) - topPad), 0]);
    end

    function updatePreviewPlots(Trace_out, time_res, params, autoThreshold)
        useTimeRange = isfield(params, 'UseTimeRange') && params.UseTimeRange;
        if useTimeRange
            inWindow = time_res >= params.StartTime & time_res <= params.EndTime;
            Trace_out = Trace_out(inWindow);
            time_res = time_res(inWindow);
        end

        numSegments = min(100, numel(Trace_out));
        Trace_out = findSegmentMaxima(Trace_out, numSegments);
        time_res = linspace(time_res(1), time_res(end), numSegments);

        yMin = quantile(Trace_out, 0.02);
        yMax = quantile(Trace_out, 0.98);
        if yMax <= yMin
            yMax = yMin + 1;
        end
        inRange = Trace_out >= yMin & Trace_out <= yMax;
        dataInRange = Trace_out(inRange);
        if isempty(dataInRange)
            dataInRange = Trace_out;
        end
        outlier = quantile(dataInRange, 0.999);
        std3 = 3 * nanstd(dataInRange);
        std2 = 2 * nanstd(dataInRange);

        chosen_th = params.MinPeakProminence;
        if autoThreshold
            chosen_th = std2;
            set(hMinPeakProminence, 'String', num2str(std2));
        end

        nBins = max(25, min(80, round(3 * sqrt(numel(Trace_out)))));
        peakEdges = linspace(yMin, yMax, nBins + 1);
        peakCounts = histcounts(Trace_out, peakEdges);
        peakValues = peakCounts / max(sum(peakCounts), 1);

        plotPanelLocal = findobj(detectionFig, 'Tag', 'plotPanel');
        ax1 = findobj(plotPanelLocal, 'Tag', 'axPreviewTrace');
        ax2 = findobj(plotPanelLocal, 'Tag', 'axPreviewHist');
        if isempty(ax1) || isempty(ax2)
            snap = struct();
            snap.Trace_out = Trace_out(:);
            snap.time_res = time_res(:);
            snap.events_detected = events_detected;
            snap.amplitudes_detected = amplitudes_detected;
            snap.widths_detected = widths_detected;
            snap.channels_detected = [];
            snap.metadata_detected = [];
            snap.indices_detected = [];
            snap.prominences_detected = prominences_detected;
            snap.yMin = yMin;
            snap.yMax = yMax;
            snap.outlier = outlier;
            snap.std3 = std3;
            snap.chosen_th = chosen_th;
            snap.detect = ~isempty(events_detected);
            snap.needStimuliPlots = false;
            snap.UseTimeRange = logical(useTimeRange);
            snap.StartTime = 0;
            snap.EndTime = 0;
            if useTimeRange
                snap.StartTime = params.StartTime;
                snap.EndTime = params.EndTime;
            end
            snap.histPeak = struct('edges', peakEdges, 'values', peakValues);
            snap.rel_times = [];
            snap.histRel = struct('edges', [], 'values', []);
            snap.histAmp = struct('edges', [], 'values', []);
            snap.meanTrace = [];
            snap.meanMin = [];
            snap.meanMax = [];
            snap.meanRaster = [];
            snap.meanTime = [];
            snap.meanN = 0;
            snap.meanWinSec = 0;
            drawPlotsFromSnapshot(snap);
            return;
        end

        hBar = findobj(ax1, 'Type', 'bar');
        set(hBar, 'XData', time_res * timeUnitFactor, 'YData', Trace_out);
        if useTimeRange
            xlim(ax1, [params.StartTime, params.EndTime] * timeUnitFactor);
        else
            xlim(ax1, [time_res(1), time_res(end)] * timeUnitFactor);
        end
        ylim(ax1, [yMin, yMax]);
        hTh1 = findobj(ax1, 'Tag', 'ylChosenTh');
        set(hTh1, 'Value', chosen_th);

        cla(ax2);
        hold(ax2, 'on');
        histogram(ax2, 'BinEdges', peakEdges, 'BinCounts', peakValues, ...
            'Orientation', 'horizontal', ...
            'FaceColor', [0.3 0.6 0.9], ...
            'EdgeColor', 'none');
        ylim(ax2, [yMin, yMax]);
        maxProb = max(peakValues);
        if isempty(maxProb) || maxProb <= 0
            maxProb = 1;
        end
        yl = ylim(ax2);
        ySpan = yl(2) - yl(1);
        labelLift = 0.05 * ySpan;
        valueLift = 0.02 * ySpan;
        topPad = 0.01 * ySpan;
        yline(ax2, outlier, 'k:');
        outlier_x = maxProb * 0.9;
        text(ax2, outlier_x, min(outlier + labelLift, yl(2) - topPad), 'outlier', 'VerticalAlignment', 'bottom');
        text(ax2, outlier_x, min(outlier + valueLift, yl(2) - topPad), num2str(outlier, 3), 'VerticalAlignment', 'bottom');
        yline(ax2, std3, 'k:');
        text(ax2, maxProb, min(std3 + labelLift, yl(2) - topPad), '3*STD', 'VerticalAlignment', 'bottom');
        text(ax2, maxProb, min(std3 + valueLift, yl(2) - topPad), num2str(std3, 3), 'VerticalAlignment', 'bottom');
        yline(ax2, chosen_th, 'r:', 'Tag', 'ylChosenTh');
        text(ax2, maxProb * 0.5, min(chosen_th + labelLift, yl(2) - topPad), 'now', 'VerticalAlignment', 'bottom', 'Tag', 'txtChosenThLabel');
        text(ax2, maxProb * 0.5, min(chosen_th + valueLift, yl(2) - topPad), num2str(chosen_th, 3), 'color', 'r', 'VerticalAlignment', 'bottom', 'Tag', 'txtChosenThValue');
        xlabel(ax2, 'Probability');
        ylabel(ax2, 'Peak Height');
        title(ax2, 'Distribution of Peak Height');
        hold(ax2, 'off');
    end

    function checkDetectionCallback(~, ~)
        
        % Очищаем контейнер графиков
        plotPanel = findobj(detectionFig, 'Tag', 'plotPanel');
        if ~isempty(plotPanel)
            delete(plotPanel.Children);
            
            % Проверяем, включен ли поиск вокруг стимулов
            searchEnabled = get(hSearchAroundStimuli, 'Value') && stims_exist && ~isempty(stims);
            previewEnabled = get(hShowMeanPreview, 'Value');
            
            if searchEnabled
                if previewEnabled
                    t = tiledlayout(plotPanel, 4, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
                    numTiles = 8;
                else
                    t = tiledlayout(plotPanel, 3, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
                    numTiles = 6;
                end
            else
                if previewEnabled
                    t = tiledlayout(plotPanel, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
                    numTiles = 4;
                else
                    t = tiledlayout(plotPanel, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
                    numTiles = 2;
                end
            end
            
            % Показываем "Detecting ..." только на нужных осях
            for i = 1:numTiles
                ax = nexttile(t);
                text(ax, 0.5, 0.5, 'Detecting ...', 'HorizontalAlignment', 'center', ...
                     'VerticalAlignment', 'middle', 'FontSize', 14, 'Units', 'normalized');
                axis(ax, 'off');
            end
        end
        
        drawnow;
        
        % Сбор значений параметров и упаковка их в структуру
        [params.DetectionType, params.ChPos, params.ChNeg] = uiToDetectionParams();
        params.MinPeakProminence = str2double(get(hMinPeakProminence, 'String'));
        params.MinPeakDistance = str2double(get(hMinPeakDistance, 'String')) / timeUnitFactor;
        SourceTypes = get(hSourceType, 'String');
        params.SourceType = SourceTypes{get(hSourceType, 'Value')};
        params.detect = true;
        params.max_peak_width = str2double(get(hMaxPeakWidth, 'String')) / timeUnitFactor;
        params.SearchAroundStimuli = get(hSearchAroundStimuli, 'Value');
        params.SearchWindow = str2double(get(hSearchWindow, 'String')) / timeUnitFactor;
        params.SearchAroundDirection = get(hSearchAroundDirection, 'Value');
        params.UseTimeRange = get(hUseTimeRange, 'Value');
        params.StartTime = str2double(get(hStartTime, 'String')) / timeUnitFactor;
        params.EndTime = str2double(get(hEndTime, 'String')) / timeUnitFactor;
        params.ShowMeanPreview = get(hShowMeanPreview, 'Value');
        
        [events_detected, Trace_out, time_res, amplitudes_detected, widths_detected, channels_detected, metadata_detected, prominences_detected, indices_detected, wasCanceled] = autoEventDetection(params);
        if wasCanceled
            return;
        end
        
        Trace_out(isnan(Trace_out)) = 0;
        Trace_out(isinf(Trace_out)) = 0;
        
        [~, plotSnapshot] = plotRequest(events_detected, Trace_out, time_res, params, prominences_detected, amplitudes_detected, widths_detected);
        plotSnapshot.channels_detected = channels_detected;
        plotSnapshot.metadata_detected = metadata_detected;
        plotSnapshot.indices_detected = indices_detected;
        plotSnapshot.prominences_detected = prominences_detected;
        saveSettings(plotSnapshot);
        updateApplyButton();
    end

    function updateApplyButton()
        set(applybutton, 'Enable', 'off');
        if ~isempty(events_detected)
            set(applybutton, 'Enable', 'on');
        end
    end

    function [std2, snap] = plotRequest(events_in, Trace_out, time_res, params, prominences_detected, amplitudes_in, widths_in, autoThreshold)

        useTimeRange = isfield(params, 'UseTimeRange') && params.UseTimeRange;
        if useTimeRange
            inWindow = time_res >= params.StartTime & time_res <= params.EndTime;
            Trace_out = Trace_out(inWindow);
            time_res = time_res(inWindow);
        end
        
        meanTrace = [];
        meanMin = [];
        meanMax = [];
        meanRaster = [];
        meanTime = [];
        meanN = 0;
        meanWinSec = 0;
        if isfield(params, 'ShowMeanPreview') && params.ShowMeanPreview && ...
                params.detect && ~isempty(events_in) && ~isempty(widths_in)
            winSec = 8 * median(widths_in);
            dt = (time_res(end) - time_res(1)) / max(numel(time_res) - 1, 1);
            halfSamples = max(1, round((winSec / 2) / dt));
            nSamples = 2 * halfSamples + 1;
            meanTime = linspace(-winSec / 2, winSec / 2, nSamples);
            sumTrace = zeros(1, nSamples);
            minTrace = inf(1, nSamples);
            maxTrace = -inf(1, nSamples);
            rasterBuf = zeros(numel(events_in), nSamples);
            nUsed = 0;
            for i = 1:numel(events_in)
                [~, centerIdx] = min(abs(time_res - events_in(i)));
                i0 = centerIdx - halfSamples;
                i1 = centerIdx + halfSamples;
                if i0 >= 1 && i1 <= numel(Trace_out)
                    seg = reshape(Trace_out(i0:i1), 1, []);
                    nUsed = nUsed + 1;
                    rasterBuf(nUsed, :) = seg;
                    sumTrace = sumTrace + seg;
                    minTrace = min(minTrace, seg);
                    maxTrace = max(maxTrace, seg);
                end
            end
            meanN = nUsed;
            meanWinSec = winSec;
            if nUsed > 0
                meanTrace = (sumTrace / nUsed).';
                meanMin = minTrace(:);
                meanMax = maxTrace(:);
                meanRaster = rasterBuf(1:nUsed, :);
                meanTime = meanTime(:);
            else
                meanTime = [];
            end
        end
        
        numSegments = min(100, numel(Trace_out));
        Trace_out = findSegmentMaxima(Trace_out, numSegments);
        time_res = linspace(time_res(1), time_res(end), numSegments);
        
        yMin = quantile(Trace_out, 0.02);
        yMax = quantile(Trace_out, 0.98);
        if yMax <= yMin
            yMax = yMin + 1;
        end
        inRange = Trace_out >= yMin & Trace_out <= yMax;
        dataInRange = Trace_out(inRange);
        if isempty(dataInRange)
            dataInRange = Trace_out;
        end
        outlier = quantile(dataInRange, 0.999);
        std3 = 3*nanstd(dataInRange);
        std2 = 2*nanstd(dataInRange);
        
        chosen_th = params.MinPeakProminence;
        if nargin >= 8 && autoThreshold
            chosen_th = std2;
            set(hMinPeakProminence, 'String', num2str(std2));
        end
        
        SearchAroundStimuli = false;
        if isfield(params, 'SearchAroundStimuli')
            SearchAroundStimuli = params.SearchAroundStimuli;
        end
        needStimuliPlots = SearchAroundStimuli && params.detect && ~isempty(events_in) && stims_exist && ~isempty(stims);
        
        nBins = max(25, min(80, round(3*sqrt(numel(Trace_out)))));
        peakEdges = linspace(yMin, yMax, nBins + 1);
        peakCounts = histcounts(Trace_out, peakEdges);
        peakValues = peakCounts / max(sum(peakCounts), 1);
        
        rel_times = [];
        histRel = struct('edges', [], 'values', []);
        histAmp = struct('edges', [], 'values', []);
        if needStimuliPlots
            rel_times = zeros(numel(events_in), 1);
            for i = 1:numel(events_in)
                [~, closest_stim_idx] = min(abs(stims - events_in(i)));
                rel_times(i) = events_in(i) - stims(closest_stim_idx);
            end
            relScaled = rel_times * timeUnitFactor;
            [relCounts, relEdges] = histcounts(relScaled, 30);
            histRel.edges = relEdges;
            histRel.values = relCounts / max(sum(relCounts), 1);
            [ampCounts, ampEdges] = histcounts(amplitudes_in, 30);
            histAmp.edges = ampEdges;
            histAmp.values = ampCounts / max(sum(ampCounts), 1);
        end
        
        startTime = 0;
        endTime = 0;
        if useTimeRange
            startTime = params.StartTime;
            endTime = params.EndTime;
        end
        
        snap = struct();
        snap.Trace_out = Trace_out(:);
        snap.time_res = time_res(:);
        snap.events_detected = events_in;
        snap.amplitudes_detected = amplitudes_in;
        snap.widths_detected = widths_in;
        snap.channels_detected = [];
        snap.metadata_detected = [];
        snap.indices_detected = [];
        snap.prominences_detected = prominences_detected;
        snap.yMin = yMin;
        snap.yMax = yMax;
        snap.outlier = outlier;
        snap.std3 = std3;
        snap.chosen_th = chosen_th;
        snap.detect = logical(params.detect);
        snap.needStimuliPlots = logical(needStimuliPlots);
        snap.UseTimeRange = logical(useTimeRange);
        snap.StartTime = startTime;
        snap.EndTime = endTime;
        snap.histPeak = struct('edges', peakEdges, 'values', peakValues);
        snap.rel_times = rel_times;
        snap.histRel = histRel;
        snap.histAmp = histAmp;
        snap.meanTrace = meanTrace;
        snap.meanMin = meanMin;
        snap.meanMax = meanMax;
        snap.meanRaster = meanRaster;
        snap.meanTime = meanTime;
        snap.meanN = meanN;
        snap.meanWinSec = meanWinSec;
        
        drawPlotsFromSnapshot(snap);
    end

    function drawPlotsFromSnapshot(snap)
        plotPanelLocal = findobj(detectionFig, 'Tag', 'plotPanel');
        if isempty(plotPanelLocal)
            return;
        end
        delete(plotPanelLocal.Children);
        
        hasMean = isfield(snap, 'meanTrace') && ~isempty(snap.meanTrace);
        if snap.needStimuliPlots
            if hasMean
                t = tiledlayout(plotPanelLocal, 4, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
            else
                t = tiledlayout(plotPanelLocal, 3, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
            end
        else
            if hasMean
                t = tiledlayout(plotPanelLocal, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
            else
                t = tiledlayout(plotPanelLocal, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
            end
        end
        
        ax1 = nexttile(t);
        ax1.Tag = 'axPreviewTrace';
        hold(ax1, 'on');
        bar(ax1, snap.time_res * timeUnitFactor, snap.Trace_out, 'FaceColor', [0.3 0.6 0.9], 'EdgeColor', 'none');
        xlabel(ax1, ['Time, ' selectedUnit]);
        yline(ax1, snap.chosen_th, 'k:', 'Tag', 'ylChosenTh');
        if snap.UseTimeRange
            xlim(ax1, [snap.StartTime, snap.EndTime] * timeUnitFactor);
        else
            xlim(ax1, [snap.time_res(1), snap.time_res(end)] * timeUnitFactor);
        end
        ylim(ax1, [snap.yMin, snap.yMax]);
        tBins = snap.time_res(:);
        dtBin = (tBins(end) - tBins(1)) / max(numel(tBins) - 1, 1);
        binIdx = round((snap.events_detected(:) - tBins(1)) / dtBin) + 1;
        binIdx = unique(max(1, min(numel(tBins), binIdx)), 'stable');
        Lines(tBins(binIdx) * timeUnitFactor, [], 'r', ':');
        if ~isempty(snap.events_detected)
            title(ax1, [num2str(numel(snap.events_detected)), ' events'], 'interpreter', 'none');
        else
            title(ax1, '');
        end
        hold(ax1, 'off');
        
        ax2 = nexttile(t);
        ax2.Tag = 'axPreviewHist';
        hold(ax2, 'on');
        histogram(ax2, 'BinEdges', snap.histPeak.edges, 'BinCounts', snap.histPeak.values, ...
            'Orientation', 'horizontal', ...
            'FaceColor', [0.3 0.6 0.9], ...
            'EdgeColor', 'none');
        ylim(ax2, [snap.yMin, snap.yMax]);
        maxProb = max(snap.histPeak.values);
        if isempty(maxProb) || maxProb <= 0
            maxProb = 1;
        end
        yl = ylim(ax2);
        ySpan = yl(2) - yl(1);
        labelLift = 0.05 * ySpan;
        valueLift = 0.02 * ySpan;
        topPad = 0.01 * ySpan;
        
        yline(ax2, snap.outlier, 'k:');
        outlier_x = maxProb * 0.9;
        text(ax2, outlier_x, min(snap.outlier + labelLift, yl(2) - topPad), 'outlier', 'VerticalAlignment', 'bottom');
        text(ax2, outlier_x, min(snap.outlier + valueLift, yl(2) - topPad), num2str(snap.outlier, 3), 'VerticalAlignment', 'bottom');
        
        yline(ax2, snap.std3, 'k:');
        text(ax2, maxProb, min(snap.std3 + labelLift, yl(2) - topPad), '3*STD', 'VerticalAlignment', 'bottom');
        text(ax2, maxProb, min(snap.std3 + valueLift, yl(2) - topPad), num2str(snap.std3, 3), 'VerticalAlignment', 'bottom');
        
        yline(ax2, snap.chosen_th, 'r:', 'Tag', 'ylChosenTh');
        text(ax2, maxProb * 0.5, min(snap.chosen_th + labelLift, yl(2) - topPad), 'now', 'VerticalAlignment', 'bottom', 'Tag', 'txtChosenThLabel');
        text(ax2, maxProb * 0.5, min(snap.chosen_th + valueLift, yl(2) - topPad), num2str(snap.chosen_th, 3), 'color', 'r', 'VerticalAlignment', 'bottom', 'Tag', 'txtChosenThValue');
        
        xlabel(ax2, 'Probability');
        ylabel(ax2, 'Peak Height');
        title(ax2, 'Distribution of Peak Height');
        hold(ax2, 'off');
        
        if snap.needStimuliPlots
            relScaled = snap.rel_times * timeUnitFactor;
            ax3 = nexttile(t);
            hold(ax3, 'on');
            boxplot(ax3, relScaled, 'Orientation', 'horizontal');
            y_jitter = 0.5 + 0.15 * (rand(size(relScaled)) - 0.5);
            scatter(ax3, relScaled, y_jitter, 20, 'k', '.', 'MarkerFaceAlpha', 0.6);
            xlabel(ax3, ['Relative time from stimulus, ' selectedUnit]);
            ylabel(ax3, 'Events');
            title(ax3, sprintf('Event timing relative to stimuli (n=%d)', numel(snap.rel_times)));
            grid(ax3, 'on');
            hold(ax3, 'off');
            
            ax4 = nexttile(t);
            hold(ax4, 'on');
            histogram(ax4, 'BinEdges', snap.histRel.edges, 'BinCounts', snap.histRel.values, ...
                'FaceColor', [0.3 0.6 0.9], 'EdgeColor', 'k');
            xlabel(ax4, ['Relative time from stimulus, ' selectedUnit]);
            ylabel(ax4, 'Probability');
            title(ax4, 'Distribution of relative event times');
            grid(ax4, 'on');
            xlim(ax3, xlim(ax4));
            hold(ax4, 'off');
            
            ax5 = nexttile(t);
            hold(ax5, 'on');
            boxplot(ax5, snap.amplitudes_detected, 'Orientation', 'horizontal');
            y_jitter_amp = 0.5 + 0.15 * (rand(size(snap.amplitudes_detected)) - 0.5);
            scatter(ax5, snap.amplitudes_detected, y_jitter_amp, 20, 'k', '.', 'MarkerFaceAlpha', 0.6);
            xlabel(ax5, 'Event amplitude');
            ylabel(ax5, 'Events');
            title(ax5, sprintf('Event amplitudes (n=%d)', numel(snap.amplitudes_detected)));
            grid(ax5, 'on');
            hold(ax5, 'off');
            
            ax6 = nexttile(t);
            hold(ax6, 'on');
            histogram(ax6, 'BinEdges', snap.histAmp.edges, 'BinCounts', snap.histAmp.values, ...
                'FaceColor', [0.3 0.6 0.9], 'EdgeColor', 'k');
            xlabel(ax6, 'Event amplitude');
            ylabel(ax6, 'Probability');
            title(ax6, 'Distribution of event amplitudes');
            grid(ax6, 'on');
            xlim(ax5, xlim(ax6));
            hold(ax6, 'off');
        end
        
        if hasMean
            axMean = nexttile(t);
            hold(axMean, 'on');
            tMean = snap.meanTime * timeUnitFactor;
            if isfield(snap, 'meanMin') && isfield(snap, 'meanMax') && ...
                    ~isempty(snap.meanMin) && ~isempty(snap.meanMax)
                xFill = [tMean; flipud(tMean)];
                yFill = [snap.meanMax(:); flipud(snap.meanMin(:))];
                fill(axMean, xFill, yFill, [0.3 0.6 0.9], 'FaceAlpha', 0.25, 'EdgeColor', 'none');
            end
            plot(axMean, tMean, snap.meanTrace, ...
                'Color', [0.3 0.6 0.9], 'LineWidth', 1.5);
            xline(axMean, 0, 'k:');
            xlabel(axMean, ['Time relative to peak, ' selectedUnit]);
            title(axMean, sprintf('Mean event (n=%d)', snap.meanN), 'interpreter', 'none');
            grid(axMean, 'on');
            hold(axMean, 'off');
            
            axRaster = nexttile(t);
            if isfield(snap, 'meanRaster') && ~isempty(snap.meanRaster)
                imagesc(axRaster, tMean, 1:size(snap.meanRaster, 1), snap.meanRaster);
                set(axRaster, 'YDir', 'normal');
                colormap(axRaster, parula);
                xline(axRaster, 0, 'k:');
                xlabel(axRaster, ['Time relative to peak, ' selectedUnit]);
                ylabel(axRaster, 'Event #');
                title(axRaster, 'Event slices', 'interpreter', 'none');
            end
        end
    end


    function detectButtonCallback(~, ~)
        if isempty(events_detected)
            fprintf('Please run "Check Detection" first before applying results.\n');
            return;
        end

        [~, filename, ~] = fileparts(matFilePath);
        evfilename = [filename '_auto'];

        setEventsState(events_detected(:), ...
            'indices', indices_detected, ...
            'amplitudes', amplitudes_detected, ...
            'channels', channels_detected, ...
            'widths', widths_detected, ...
            'prominences', prominences_detected, ...
            'metadata', metadata_detected, ...
            'source', 'auto', ...
            'title', 'Autodetected', ...
            'event_inx', 1, ...
            'sync', false);

        if ~isempty(table_calling)
            table_calling();
        else
            syncEventTable();
        end

        set(eventDeleteEdit, 'String', num2str(event_inx));
        saveSettings();

        if events_exist && ~isempty(events)
            selectedCenter = 'events';
            set(timeCenterPopup, 'Value', timeCenterNav('popupIndex'));
            chosen_time_interval(1) = events(event_inx);
            chosen_time_interval(2) = events(event_inx) + windowSize;
        else
            fprintf('No events detected. Please adjust detection parameters.\n');
        end

        if ~isempty(updatePlotFunc)
            updatePlotFunc();
        else
            updatePlot();
        end
        close(detectionFig);
    end

end

function saveSettings(plotSnapshot)
    global hMinPeakProminence hDetectionType hMainChannel hSubtractChannelCheck hSubtractChannel hMaxPeakWidth
    global hMinPeakDistance
    global hSourceType timeUnitFactor hSearchAroundStimuli hSearchWindow hSearchAroundDirection
    global hUseTimeRange hStartTime hEndTime
    global hShowMeanPreview
    global autodetection_settings

    settings.MinPeakProminence = str2double(get(hMinPeakProminence, 'String'));
    settings.PolarityIndex = get(hDetectionType, 'Value');
    settings.MainChannel = get(hMainChannel, 'Value');
    settings.SubtractChannelEnabled = get(hSubtractChannelCheck, 'Value');
    settings.SubtractChannel = get(hSubtractChannel, 'Value');
    settings.MinPeakDistance = str2double(get(hMinPeakDistance, 'String')) / timeUnitFactor;
    settings.SourceTypeIndex = get(hSourceType, 'Value');
    settings.MaxPeakWidth = str2double(get(hMaxPeakWidth, 'String')) / timeUnitFactor;
    settings.SearchAroundStimuli = get(hSearchAroundStimuli, 'Value');
    settings.SearchWindow = str2double(get(hSearchWindow, 'String')) / timeUnitFactor;
    settings.SearchAroundDirection = get(hSearchAroundDirection, 'Value');
    settings.UseTimeRange = get(hUseTimeRange, 'Value');
    settings.StartTime = str2double(get(hStartTime, 'String')) / timeUnitFactor;
    settings.EndTime = str2double(get(hEndTime, 'String')) / timeUnitFactor;
    settings.ShowMeanPreview = get(hShowMeanPreview, 'Value');
    
    if nargin >= 1 && isstruct(plotSnapshot)
        settings.plotSnapshot = plotSnapshot;
    elseif isstruct(autodetection_settings) && isfield(autodetection_settings, 'plotSnapshot')
        settings.plotSnapshot = autodetection_settings.plotSnapshot;
    end
    
    autodetection_settings = settings;
    saveChannelSettings('autodetection_settings');
end

function safeSetPopupValue(hPopup, requestedValue, maxItems, popupLabel)
    % Если popupLabel не передали, сделаем его пустым
    if nargin < 4
        popupLabel = '';
    end

    if isempty(requestedValue) || ~isnumeric(requestedValue) || isnan(requestedValue)
        requestedValue = 1;
        warning("%s: value restored to default (was empty or invalid) ", popupLabel)
    end
    
    requestedValue = round(requestedValue);
    if requestedValue < 1
        requestedValue = 1;
        warning("%s: value < 1, restored to default ", popupLabel)
    elseif requestedValue > maxItems
        requestedValue = maxItems;
        warning("%s: value too big, restored to default ", popupLabel)
    end
    
    set(hPopup, 'Value', requestedValue);
end
