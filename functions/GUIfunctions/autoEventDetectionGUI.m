function autoEventDetectionGUI()
    % Загрузка настроек только из локального *_channelSettings.stn
    global events_exist event_inx
    global table_calling event_title_string
    global timeUnitFactor selectedUnit
    global matFilePath
    
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
    
    % Загружаем координаты элементов из JSON файла
    coordsFile = getGUIConfigPath('autoEventDetectionGUI_coords.json');
    if exist(coordsFile, 'file')
        coordsData = jsondecode(fileread(coordsFile));
    else
        error('Coordinates file not found: %s', coordsFile);
    end
    
    % Вспомогательная функция для получения координат элемента
    function pos = getElementPosition(tag)
        if isfield(coordsData.elements, tag)
            pos = coordsData.elements.(tag);
            % Для панели (plotPanel) оставляем относительные координаты
            if strcmp(tag, 'plotPanel')
                % Панель уже использует относительные координаты, возвращаем как есть
                return;
            end
            % Преобразуем относительные координаты в абсолютные
            base_pos = coordsData.base_figure_position;
            pos = [
                pos(1) * base_pos(3),  % x
                pos(2) * base_pos(4),  % y
                pos(3) * base_pos(3),  % width
                pos(4) * base_pos(4)   % height
            ];
        else
            error('Coordinates for element %s not found in JSON file', tag);
        end
    end
    
    global events event_comments hd events_detected evfilename eventDeleteEdit
    global hMinPeakProminence hDetectionType hMainChannel hSubtractChannelCheck hSubtractChannel hMaxPeakWidth
    global hMinPeakDistance
    global hSourceType selectedCenter timeCenterPopup windowSize chosen_time_interval
    global hSearchAroundStimuli hSearchWindow hSearchAroundDirection stims_exist stims
    global hUseTimeRange hStartTime hEndTime time
    
    % Переменные для хранения результатов детекции в области видимости GUI
    amplitudes_detected = [];
    widths_detected = [];
    channels_detected = [];
    metadata_detected = [];
    indices_detected = [];
    
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
    global time
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

    % Инициализация видимости элементов в зависимости от наличия стимулов
    changeDetectionType();

    % Создаем контейнер для графиков (аналогично plotFromTableGUI.m)
    plotPanel = uipanel('Parent', detectionFig, ...
        'Position', getElementPosition('plotPanel'), ...
        'Tag', 'plotPanel');
    
    % Инициализация значений из настроек (только новый формат; при отсутствии — стандарт)
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

    % Кнопка сброса настроек (слева от Check Detection)
    uicontrol(detectionFig, 'Style', 'pushbutton', 'String', 'Reset settings',...
        'Position', getElementPosition('resetSettingsBtn'), 'Callback', @resetSettingsCallback, 'Tag', 'resetSettingsBtn');
    % Кнопка 'Check Detection'
    uicontrol(detectionFig, 'Style', 'pushbutton', 'String', 'Check Detection',...
        'Position', getElementPosition('checkDetectionBtn'), 'Callback', @checkDetectionCallback, 'Tag', 'checkDetectionBtn');

    % Кнопка 'Apply'
    applybutton = uicontrol(detectionFig, 'Style', 'pushbutton', 'String', 'Apply',...
        'Position', getElementPosition('applyBtn'), 'Callback', @detectButtonCallback, 'Tag', 'applyBtn');
    set(applybutton, 'Enable', 'off')
    
    % Устанавливаем обработчик изменения размера окна
    set(detectionFig, 'SizeChangedFcn', @(~,~) resizeComponentsCallback(detectionFig, coordsFile));
    
    hasPlotSnapshot = ~isempty(settings) && isfield(settings, 'plotSnapshot') && isstruct(settings.plotSnapshot) ...
        && isfield(settings.plotSnapshot, 'Trace_out');
    if hasPlotSnapshot
        snap = settings.plotSnapshot;
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
        set(applybutton, 'Enable', 'on');
        if isfield(settings, 'MinPeakProminence')
            set(hMinPeakProminence, 'String', num2str(settings.MinPeakProminence));
        end
    else
        previewData();
        if ~isempty(settings) && isfield(settings, 'MinPeakProminence')
            set(hMinPeakProminence, 'String', num2str(settings.MinPeakProminence));
        end
    end
    
    % Показываем окно после превью
    set(detectionFig, 'Visible', 'on');
    drawnow;
    
    % Разворачиваем окно после успешной инициализации
    detectionFig.WindowState = 'maximized';
    
    % Функция обратного вызова для изменения размера
    function resizeComponentsCallback(figHandle, coordsFile)
        try
            if exist(coordsFile, 'file')
                coordsData = jsondecode(fileread(coordsFile));
                base_figure_position = coordsData.base_figure_position;
                ResizeElements(figHandle, coordsFile, base_figure_position);
            end
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
    end

    function mainChannelCallback(~, ~)
        changeDetectionType();
        previewData();
    end

    function detectionControlsCallback(~, ~)
        changeDetectionType();
        previewData();
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

    function previewData()
        % Предварительная прорисовка
        global wb
        if isempty(wb) || ~isvalid(wb)
            wb = createCancelableWaitbar(0, 'Preview: preparing...', 'Event Detection');
        else
            setappdata(wb, 'canceling', 0);
            waitbar(0, wb, 'Preview: preparing...');
        end
        drawnow;
        % Сбор значений параметров и упаковка их в структуру
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
               
        [events_detected, Trace_out, time_res, amplitudes_detected, widths_detected, channels_detected, metadata_detected, prominences_detected, ~, wasCanceled] = autoEventDetection(params);
        if wasCanceled
            return;
        end
        
        Trace_out(isnan(Trace_out)) = 0;
        Trace_out(isinf(Trace_out)) = 0;
        
        if ~isempty(wb) && isvalid(wb)
            waitbar(0.9, wb, 'Preview: rendering plots...');
            drawnow;
        end
        outlier = plotRequest(events_detected, Trace_out, time_res, params, prominences_detected, amplitudes_detected);
        set(hMinPeakProminence, 'String', num2str(outlier));
    end

    function checkDetectionCallback(~, ~)
        
        % Очищаем контейнер графиков
        plotPanel = findobj(detectionFig, 'Tag', 'plotPanel');
        if ~isempty(plotPanel)
            delete(plotPanel.Children);
            
            % Проверяем, включен ли поиск вокруг стимулов
            searchEnabled = get(hSearchAroundStimuli, 'Value') && stims_exist && ~isempty(stims);
            
            % Создаем tiledlayout в зависимости от необходимости дополнительных графиков
            if searchEnabled
                t = tiledlayout(plotPanel, 3, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
                numTiles = 6;
            else
                t = tiledlayout(plotPanel, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
                numTiles = 2;
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
        
        saveSettings();
        
        [events_detected, Trace_out, time_res, amplitudes_detected, widths_detected, channels_detected, metadata_detected, prominences_detected, indices_detected, wasCanceled] = autoEventDetection(params);
        if wasCanceled
            return;
        end
        
        Trace_out(isnan(Trace_out)) = 0;
        Trace_out(isinf(Trace_out)) = 0;
        
        [~, plotSnapshot] = plotRequest(events_detected, Trace_out, time_res, params, prominences_detected, amplitudes_detected);
        plotSnapshot.widths_detected = widths_detected;
        plotSnapshot.channels_detected = channels_detected;
        plotSnapshot.metadata_detected = metadata_detected;
        plotSnapshot.indices_detected = indices_detected;
        plotSnapshot.prominences_detected = prominences_detected;
        saveSettings(plotSnapshot);
        
        set(applybutton, 'Enable', 'on')
        
    end

    function [outlier, snap] = plotRequest(events_in, Trace_out, time_res, params, prominences_detected, amplitudes_in)

        numSegments = 100;
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
        
        if params.detect
            chosen_th = params.MinPeakProminence;
        else
            chosen_th = outlier;
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
        
        useTimeRange = params.detect && isfield(params, 'UseTimeRange') && params.UseTimeRange;
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
        snap.widths_detected = [];
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
        
        drawPlotsFromSnapshot(snap);
    end

    function drawPlotsFromSnapshot(snap)
        plotPanelLocal = findobj(detectionFig, 'Tag', 'plotPanel');
        if isempty(plotPanelLocal)
            return;
        end
        delete(plotPanelLocal.Children);
        
        if snap.needStimuliPlots
            t = tiledlayout(plotPanelLocal, 3, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
        else
            t = tiledlayout(plotPanelLocal, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
        end
        
        ax1 = nexttile(t);
        hold(ax1, 'on');
        bar(ax1, snap.time_res * timeUnitFactor, snap.Trace_out, 'FaceColor', [0.3 0.6 0.9], 'EdgeColor', 'none');
        xlabel(ax1, ['Time, ' selectedUnit]);
        yline(ax1, snap.chosen_th, 'k:');
        if snap.UseTimeRange
            xlim(ax1, [snap.StartTime, snap.EndTime] * timeUnitFactor);
        else
            xlim(ax1, [snap.time_res(1), snap.time_res(end)] * timeUnitFactor);
        end
        ylim(ax1, [snap.yMin, snap.yMax]);
        Lines(snap.events_detected * timeUnitFactor, [], 'r', ':');
        if snap.detect
            title(ax1, [num2str(numel(snap.events_detected)), ' events'], 'interpreter', 'none');
        else
            title(ax1, '');
        end
        hold(ax1, 'off');
        
        ax2 = nexttile(t);
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
        
        yline(ax2, snap.chosen_th, 'r:');
        text(ax2, maxProb * 0.5, min(snap.chosen_th + labelLift, yl(2) - topPad), 'now', 'VerticalAlignment', 'bottom');
        text(ax2, maxProb * 0.5, min(snap.chosen_th + valueLift, yl(2) - topPad), num2str(snap.chosen_th, 3), 'color', 'r', 'VerticalAlignment', 'bottom');
        
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
    end


    function detectButtonCallback(~, ~)
        global event_amplitudes event_channels event_widths event_prominences event_metadata event_indices
        
        % Проверяем что переменные с результатами детекции существуют
        if ~exist('amplitudes_detected', 'var') || ~exist('channels_detected', 'var') || ...
           ~exist('widths_detected', 'var') || ~exist('metadata_detected', 'var') || ~exist('indices_detected', 'var')
            fprintf('Please run "Check Detection" first before applying results.\n');
            return;
        end
        
        % Обновление таблицы событий
        events = events_detected(:); % Преобразуем в столбец
        
        if not(isempty(events))
            event_comments = repmat({'...'}, numel(events), 1); % Инициализация комментариев
            
            [events, ev_inxs] = sort(events);
            event_comments = event_comments(ev_inxs);
            event_indices = indices_detected(ev_inxs);
            
            % Сортируем метаданные в том же порядке что и события
            event_amplitudes = amplitudes_detected(ev_inxs);
            
            % Безопасная обработка channels_detected (может быть матрицей или вектором)
            if size(channels_detected, 2) > 1
                event_channels = channels_detected(ev_inxs, :);
            else
                event_channels = channels_detected(ev_inxs);
            end
            
            event_widths = widths_detected(ev_inxs);
            
            % Извлекаем prominence из metadata для сортировки
            temp_prominences = NaN(size(events));
            for i = 1:length(metadata_detected)
                temp_prominences(i) = metadata_detected(i).prominence;
            end
            event_prominences = temp_prominences(ev_inxs);
            
            event_metadata = metadata_detected(ev_inxs);
        else
            event_amplitudes = [];
            event_channels = [];
            event_widths = [];
            event_prominences = [];
            event_metadata = [];
            event_indices = [];
        end
        
        [~, filename, ~] = fileparts(matFilePath);
        
        evfilename = [filename '_auto'];
        event_title_string = 'Autodetected';
        table_calling()
        event_inx = 1;     
        set(eventDeleteEdit, 'String', num2str(event_inx));
                        
        % Сохранение настроек перед закрытием
        saveSettings();
        
        % Проверяем наличие событий перед установкой параметров
        if ~isempty(events)
            events_exist = true;
            event_inx = 1;
            selectedCenter = 'events';
            set(timeCenterPopup, 'Value', 3);
            
            chosen_time_interval(1) = events(event_inx);
            chosen_time_interval(2) = events(event_inx)+windowSize;
        else
            % Если событий нет, не меняем режим и не устанавливаем временной интервал
            events_exist = false;
            % Не меняем selectedCenter и timeCenterPopup
            % Не меняем chosen_time_interval
            fprintf('No events detected. Please adjust detection parameters.\n');
        end
                        
        updatePlot(); % Обновление графика с новыми событиями        
    
        % Закрыть окно Auto Event Detection
        close(detectionFig);
    end

end

function saveSettings(plotSnapshot)
    global hMinPeakProminence hDetectionType hMainChannel hSubtractChannelCheck hSubtractChannel hMaxPeakWidth
    global hMinPeakDistance
    global hSourceType timeUnitFactor hSearchAroundStimuli hSearchWindow hSearchAroundDirection
    global hUseTimeRange hStartTime hEndTime
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
    
    if nargin >= 1 && isstruct(plotSnapshot)
        settings.plotSnapshot = plotSnapshot;
    elseif isstruct(autodetection_settings) && isfield(autodetection_settings, 'plotSnapshot')
        settings.plotSnapshot = autodetection_settings.plotSnapshot;
    end
    
    autodetection_settings = settings;
    saveChannelSettings('autodetection_settings');
end

function [events_detected, Trace_out, time_res, amplitudes_detected, widths_detected, channels_detected, metadata_detected, prominences_detected, indices_detected, wasCanceled] = autoEventDetection(params)
    global Fs time newFs lfp_file wb ch_inxs csd_avaliable filterSettings filter_avaliable mean_group_ch 
    global stims_exist stims time art_rem_settings
    
    wasCanceled = false;
    data_in = lfp_file.lfp;
    fprintf('Please wait...\n');
    
    if isempty(wb) || ~isvalid(wb)
        wb = createCancelableWaitbar(0, 'Initializing...', 'Event Detection');
    else
        setappdata(wb, 'canceling', 0);
    end
    drawnow;
    waitbar(0.06, wb, 'Preparing data...');
    drawnow;
    if isWaitbarCanceled(wb)
        [events_detected, Trace_out, time_res, amplitudes_detected, widths_detected, channels_detected, metadata_detected, prominences_detected, indices_detected, wasCanceled] = stopCanceledAutoEventDetection(wb);
        return;
    end
    
    % Распаковка параметров из структуры
    DetectionType = params.DetectionType;
    MinPeakProminence = params.MinPeakProminence;
    ChPos = params.ChPos;
    ChNeg = params.ChNeg;
    MinPeakDistance = params.MinPeakDistance;
    SourceType = params.SourceType;
    
    detect = params.detect;
    
    max_peak_width = params.max_peak_width;
    
    raw_frq = Fs;
    lfp_frq = round(newFs);
    
    % Фильтруем если попросили
    waitbar(0.08, wb, 'Preparing filters...');
    drawnow;
    waitbar(0.1, wb, 'Applying filters...');
    drawnow;
    if isWaitbarCanceled(wb)
        [events_detected, Trace_out, time_res, amplitudes_detected, widths_detected, channels_detected, metadata_detected, prominences_detected, indices_detected, wasCanceled] = stopCanceledAutoEventDetection(wb);
        return;
    end
    try
        if sum(filter_avaliable)>0
            ch_to_filter = find(filter_avaliable);
            waitbar(0.12, wb, sprintf('Applying filters (channels: %d)...', numel(ch_to_filter)));
            drawnow;
            data_in(:, ch_to_filter) = applyFilter(data_in(:, ch_to_filter), filterSettings, newFs);        
        end
    catch ME
        fprintf('An error occurred: %s\n', ME.message);
    end
    if isWaitbarCanceled(wb)
        [events_detected, Trace_out, time_res, amplitudes_detected, widths_detected, channels_detected, metadata_detected, prominences_detected, indices_detected, wasCanceled] = stopCanceledAutoEventDetection(wb);
        return;
    end

    % Убираем артефакт стимула если включено
    waitbar(0.2, wb, 'Removing stimulus artifacts...');
    drawnow;
    if isWaitbarCanceled(wb)
        [events_detected, Trace_out, time_res, amplitudes_detected, widths_detected, channels_detected, metadata_detected, prominences_detected, indices_detected, wasCanceled] = stopCanceledAutoEventDetection(wb);
        return;
    end
    if stims_exist && ~isempty(stims) && art_rem_settings.artifact_window_ms > 0
        win_r = round(art_rem_settings.artifact_window_ms * (Fs/1000));
        data_in = removeStimArtifact(data_in, stims, time, win_r, art_rem_settings.interp_method);
    end
    
    % Вычитаем среднее из запрошенных
    waitbar(0.3, wb, 'Subtracting mean...');
    drawnow;
    if isWaitbarCanceled(wb)
        [events_detected, Trace_out, time_res, amplitudes_detected, widths_detected, channels_detected, metadata_detected, prominences_detected, indices_detected, wasCanceled] = stopCanceledAutoEventDetection(wb);
        return;
    end
    data_in(:, mean_group_ch) = data_in(:, mean_group_ch) - mean(data_in(:, mean_group_ch), 2); % вычитание выбранных средних каналов
    
    % Если источником выбран CSD
    waitbar(0.4, wb, 'Computing CSD...');
    drawnow;
    if isWaitbarCanceled(wb)
        [events_detected, Trace_out, time_res, amplitudes_detected, widths_detected, channels_detected, metadata_detected, prominences_detected, indices_detected, wasCanceled] = stopCanceledAutoEventDetection(wb);
        return;
    end
    switch SourceType
        case 'CSD'
        % Выборка только разрешенных каналов, которым доступен CSD
        allowed_ch_inxs = ch_inxs(csd_avaliable(ch_inxs) == 1);
        waitbar(0.45, wb, sprintf('Computing CSD (channels: %d)...', numel(allowed_ch_inxs)));
        drawnow;
        data_in = -globalCSD(data_in, allowed_ch_inxs);
    end
    if isWaitbarCanceled(wb)
        [events_detected, Trace_out, time_res, amplitudes_detected, widths_detected, channels_detected, metadata_detected, prominences_detected, indices_detected, wasCanceled] = stopCanceledAutoEventDetection(wb);
        return;
    end

    % Создание Trace_out
    waitbar(0.5, wb, 'Creating detection trace...');
    drawnow;
    if isWaitbarCanceled(wb)
        [events_detected, Trace_out, time_res, amplitudes_detected, widths_detected, channels_detected, metadata_detected, prominences_detected, indices_detected, wasCanceled] = stopCanceledAutoEventDetection(wb);
        return;
    end
    switch DetectionType
        case 'two channels difference'

            waitbar(0.55, wb, 'Resampling channels...');
            drawnow;
            NegTrace = resample1(double(data_in(:, ChNeg)), lfp_frq , raw_frq)';
            PosTrace = resample1(double(data_in(:, ChPos)), lfp_frq , raw_frq)';
            Trace_out = PosTrace - NegTrace;
        case 'two channels multiplied'
            waitbar(0.55, wb, 'Resampling channels...');
            drawnow;
            NegTrace = resample1(double(data_in(:, ChNeg)), lfp_frq , raw_frq)';
            PosTrace = resample1(double(data_in(:, ChPos)), lfp_frq , raw_frq)';              
            Trace_out = -(NegTrace.*PosTrace);        
        case 'one channel negative'
            waitbar(0.55, wb, 'Resampling channel...');
            drawnow;
            NegTrace = resample1(double(data_in(:, ChNeg)), lfp_frq , raw_frq)';
            Trace_out = -NegTrace;
        case 'one channel positive'
            waitbar(0.55, wb, 'Resampling channel...');
            drawnow;
            PosTrace = resample1(double(data_in(:, ChPos)), lfp_frq , raw_frq)';
            Trace_out = PosTrace;
    end
    Trace_out(isnan(Trace_out)) = nanmean(Trace_out);
    Trace_out = Trace_out - mean(Trace_out);
    Trace_out = np_flatten(Trace_out);
    
    time_res = linspace(time(1),time(end),numel(Trace_out));
    
    % Параметры временного диапазона (используются только для фильтрации событий)
    UseTimeRange = false;
    StartTime = time(1);
    EndTime = time(end);
    if isfield(params, 'UseTimeRange')
        UseTimeRange = params.UseTimeRange;
    end
    if isfield(params, 'StartTime')
        StartTime = params.StartTime;
    end
    if isfield(params, 'EndTime')
        EndTime = params.EndTime;
    end
    
    % Проверка на пустой Trace_out
    if isempty(Trace_out) || numel(Trace_out) == 0
        if ~isempty(wb) && isvalid(wb)
            delete(wb);
        end
        
        errorMsg = sprintf(['Error: No data available for event detection.\n\n' ...
            'Possible causes:\n' ...
            '1. Time range (Use time range) contains no data\n' ...
            '2. Selected channels contain no data\n' ...
            '3. Data filtering resulted in empty result\n\n' ...
            'Recommendations:\n' ...
            '- Check time range settings\n' ...
            '- Ensure selected channels exist\n' ...
            '- Disable filters or time range and try again']);
        
        uiwait(msgbox(errorMsg, 'Event Detection Error', 'error', 'modal'));
        error('Trace_out is empty - no data available for detection');
    end
    
    waitbar(0.6, wb, 'Preparing detection...');
    drawnow;
    if isWaitbarCanceled(wb)
        [events_detected, Trace_out, time_res, amplitudes_detected, widths_detected, channels_detected, metadata_detected, prominences_detected, indices_detected, wasCanceled] = stopCanceledAutoEventDetection(wb);
        return;
    end
    
    if detect
        fprintf('=== DEBUG: Detection parameters ===\n');
        fprintf('MinPeakProminence: %.3f\n', MinPeakProminence);
        fprintf('MinPeakDistance: %.6f sec (%.6f samples at %d Hz)\n', MinPeakDistance, MinPeakDistance*lfp_frq, lfp_frq);
        fprintf('MaxPeakWidth: %.6f sec (%.6f samples at %d Hz)\n', max_peak_width, max_peak_width*lfp_frq, lfp_frq);
        fprintf('DetectionType: %s\n', DetectionType);
        fprintf('SourceType: %s\n', SourceType);
        fprintf('ChPos: %d, ChNeg: %d\n', ChPos, ChNeg);
        fprintf('\n=== DEBUG: Trace_out statistics ===\n');
        fprintf('Trace_out length: %d samples\n', numel(Trace_out));
        fprintf('Trace_out min: %.3f\n', min(Trace_out));
        fprintf('Trace_out max: %.3f\n', max(Trace_out));
        fprintf('Trace_out mean: %.3f\n', mean(Trace_out));
        fprintf('Trace_out std: %.3f\n', std(Trace_out));
        fprintf('Trace_out median: %.3f\n', median(Trace_out));
        fprintf('Trace_out 99.9%% quantile: %.3f\n', quantile(Trace_out, 0.999));
        fprintf('\n');
        
            % Проверяем, нужно ли искать вокруг стимулов
            SearchAroundStimuli = false;
            SearchWindow = 0;
            SearchAroundDirection = 2; % 1 - two-sided, 2 - after-only
            if isfield(params, 'SearchAroundStimuli')
                SearchAroundStimuli = params.SearchAroundStimuli;
            end
            if isfield(params, 'SearchWindow')
                SearchWindow = params.SearchWindow;
            end
            if isfield(params, 'SearchAroundDirection')
                SearchAroundDirection = params.SearchAroundDirection;
            end
            isTwoSided = (SearchAroundDirection == 1);
        
        % Поиск вокруг стимулов возможен только если не включен временной диапазон
        if SearchAroundStimuli && stims_exist && ~isempty(stims) && ~UseTimeRange
            fprintf('=== DEBUG: Searching around stimuli ===\n');
            fprintf('Number of stimuli: %d\n', length(stims));
            fprintf('Search window: [%.6f..%.6f] sec\n', -SearchWindow*isTwoSided, SearchWindow);
            fprintf('\n');
            
            waitbar(0.65, wb, sprintf('Detecting events around %d stimuli...', length(stims)));
            drawnow;
            if isWaitbarCanceled(wb)
                [events_detected, Trace_out, time_res, amplitudes_detected, widths_detected, channels_detected, metadata_detected, prominences_detected, indices_detected, wasCanceled] = stopCanceledAutoEventDetection(wb);
                return;
            end
            
            % Инициализация массивов для объединения результатов
            all_peak_times = [];
            all_peaks = [];
            all_widths = [];
            all_prominences = [];
            mpdWarningShown = false;
            
            % Детекция в окнах вокруг каждого стимула
            num_stims = length(stims);
            for stim_idx = 1:num_stims
                waitbar(0.65 + 0.25 * (stim_idx / num_stims), wb, ...
                    sprintf('Processing stimulus %d of %d...', stim_idx, num_stims));
                drawnow;
                if isWaitbarCanceled(wb)
                    [events_detected, Trace_out, time_res, amplitudes_detected, widths_detected, channels_detected, metadata_detected, prominences_detected, indices_detected, wasCanceled] = stopCanceledAutoEventDetection(wb);
                    return;
                end
                stim = stims(stim_idx);
                window_start = stim - SearchWindow*isTwoSided;
                window_end = stim + SearchWindow;
                
                % Находим индексы, попадающие в окно
                window_mask = (time_res >= window_start) & (time_res <= window_end);
                
                if sum(window_mask) == 0
                    continue;
                end
                
                % Выделяем участок сигнала
                Trace_out_window = Trace_out(window_mask);
                time_res_window = time_res(window_mask);
                
                % Пропускаем окно, если данных нет
                if isempty(Trace_out_window) || numel(Trace_out_window) == 0
                    continue;
                end
                
                % findpeaks requires MinPeakDistance < (x(end) - x(1)).
                % Here x is time_res_window; if MinPeakDistance is larger than the
                % available time span in the current window, MATLAB throws an error.
                time_span_window = time_res_window(end) - time_res_window(1);
                if MinPeakDistance >= time_span_window
                    if ~mpdWarningShown
                        suggested = max(0, time_span_window - eps(time_span_window));
                        msg = sprintf(['MinPeakDistance is too large for the current search window.\n\n' ...
                            'MATLAB requires: MinPeakDistance < (max(time) - min(time))\n' ...
                            'Current MinPeakDistance: %.6f s\n' ...
                            'Available window time span: %.6f s\n' ...
                            'Suggested maximum value: %.6f s\n\n' ...
                            'Please decrease "Minimal Time Between Peaks" in the GUI and press Detect again.'], ...
                            MinPeakDistance, time_span_window, suggested);
                        uiwait(msgbox(msg, 'MinPeakDistance too large', 'warn', 'modal'));
                        mpdWarningShown = true;
                    end
                    
                    % Abort full detection to avoid repeated findpeaks errors.
                    all_peak_times = [];
                    all_peaks = [];
                    all_widths = [];
                    all_prominences = [];
                    break;
                end
                
                % Детекция в окне
                findpeaks_params = {'MinPeakDistance', MinPeakDistance, 'WidthReference', 'halfheight', 'MinPeakHeight', MinPeakProminence};
                [peaks_window, peak_times_window, widths_window, prominences_window] = ...
                    findpeaks(Trace_out_window, time_res_window, findpeaks_params{:});
                
                % Фильтрация по ширине
                if ~isempty(widths_window)
                    wide_mask = widths_window <= max_peak_width;
                    peaks_window = peaks_window(wide_mask);
                    peak_times_window = peak_times_window(wide_mask);
                    widths_window = widths_window(wide_mask);
                    prominences_window = prominences_window(wide_mask);
                end
                
                % Добавляем результаты в общие массивы
                if ~isempty(peak_times_window)
                    all_peak_times = [all_peak_times; peak_times_window(:)];
                    all_peaks = [all_peaks; peaks_window(:)];
                    all_widths = [all_widths; widths_window(:)];
                    all_prominences = [all_prominences; prominences_window(:)];
                end
            end
            
            fprintf('=== DEBUG: After window detection ===\n');
            fprintf('Total peaks found in all windows: %d\n', length(all_peak_times));
            fprintf('\n');
            
            waitbar(0.9, wb, 'Removing duplicates...');
            drawnow;
            if isWaitbarCanceled(wb)
                [events_detected, Trace_out, time_res, amplitudes_detected, widths_detected, channels_detected, metadata_detected, prominences_detected, indices_detected, wasCanceled] = stopCanceledAutoEventDetection(wb);
                return;
            end
            
            % Удаление дубликатов (если окна перекрываются)
            if ~isempty(all_peak_times)
                [sorted_times, sort_idx] = sort(all_peak_times);
                sorted_peaks = all_peaks(sort_idx);
                sorted_widths = all_widths(sort_idx);
                sorted_prominences = all_prominences(sort_idx);
                
                % Удаляем события, которые слишком близко друг к другу
                unique_mask = true(size(sorted_times));
                for i = 2:length(sorted_times)
                    if (sorted_times(i) - sorted_times(i-1)) < MinPeakDistance
                        unique_mask(i) = false;
                    end
                end
                
                all_peak_times = sorted_times(unique_mask);
                all_peaks = sorted_peaks(unique_mask);
                all_widths = sorted_widths(unique_mask);
                all_prominences = sorted_prominences(unique_mask);
                
                fprintf('=== DEBUG: After duplicate removal ===\n');
                fprintf('Remaining peaks: %d\n', length(all_peak_times));
                fprintf('\n');
            end
            
            if ~isempty(all_peak_times)
                events_detected = all_peak_times(:);
                amplitudes_detected = all_peaks(:);
                widths_detected = all_widths(:);
                prominences = all_prominences(:);
            else
                events_detected = [];
                amplitudes_detected = [];
                widths_detected = [];
                prominences = [];
            end
            
        else
            % Детекция по всему сигналу (как раньше)
            waitbar(0.7, wb, 'Detecting peaks in full signal...');
            drawnow;
            if isWaitbarCanceled(wb)
                [events_detected, Trace_out, time_res, amplitudes_detected, widths_detected, channels_detected, metadata_detected, prominences_detected, indices_detected, wasCanceled] = stopCanceledAutoEventDetection(wb);
                return;
            end
            
            % Проверка на пустой Trace_out перед вызовом findpeaks
            if isempty(Trace_out) || numel(Trace_out) == 0
                if ~isempty(wb) && isvalid(wb)
                    delete(wb);
                end
                
                errorMsg = sprintf(['Ошибка: Нет данных для детекции событий.\n\n' ...
                    'Возможные причины:\n' ...
                    '1. Временной диапазон (Use time range) не содержит данных\n' ...
                    '2. Выбранные каналы не содержат данных\n' ...
                    '3. Фильтрация данных привела к пустому результату\n\n' ...
                    'Рекомендации:\n' ...
                    '- Проверьте настройки временного диапазона\n' ...
                    '- Убедитесь, что выбранные каналы существуют\n' ...
                    '- Отключите фильтры или временной диапазон и попробуйте снова']);
                
                uiwait(msgbox(errorMsg, 'Ошибка детекции событий', 'error', 'modal'));
                error('Trace_out is empty - no data available for detection');
            end
            
            findpeaks_params = {'MinPeakDistance', MinPeakDistance, 'WidthReference', 'halfheight', 'MinPeakHeight', MinPeakProminence};
            [peaks,peak_times,widths,prominences] = findpeaks(Trace_out, time_res, findpeaks_params{:});
            
            fprintf('=== DEBUG: After findpeaks ===\n');
            fprintf('Found %d peaks\n', length(peaks));
            if ~isempty(peaks)
                fprintf('Peak amplitudes range: [%.3f, %.3f]\n', min(peaks), max(peaks));
                fprintf('Peak widths range: [%.6f, %.6f] sec\n', min(widths), max(widths));
                fprintf('Peak prominences range: [%.3f, %.3f]\n', min(prominences), max(prominences));
            end
            fprintf('\n');
            
            waitbar(0.85, wb, 'Filtering peaks by width...');
            drawnow;
            if isWaitbarCanceled(wb)
                [events_detected, Trace_out, time_res, amplitudes_detected, widths_detected, channels_detected, metadata_detected, prominences_detected, indices_detected, wasCanceled] = stopCanceledAutoEventDetection(wb);
                return;
            end
            
            % убираем слишком широкие пики
            wide_peaks_mask = widths > max_peak_width;
            num_wide_peaks = sum(wide_peaks_mask);
            peak_times(wide_peaks_mask) = [];
            peaks(wide_peaks_mask) = [];
            widths(wide_peaks_mask) = [];
            prominences(wide_peaks_mask) = [];
            
            fprintf('=== DEBUG: After width filtering ===\n');
            fprintf('Removed %d peaks (too wide, > %.6f sec)\n', num_wide_peaks, max_peak_width);
            fprintf('Remaining peaks: %d\n', length(peaks));
            fprintf('\n');
            
            events_detected = peak_times(:);
            amplitudes_detected = peaks(:);
            widths_detected = widths(:);
            prominences = prominences(:);
        end

        if UseTimeRange
            time_mask = events_detected >= StartTime & events_detected <= EndTime;
            events_detected = events_detected(time_mask);
            amplitudes_detected = amplitudes_detected(time_mask);
            widths_detected = widths_detected(time_mask);
            prominences = prominences(time_mask);
        end
        
        waitbar(0.95, wb, 'Finalizing results...');
        drawnow;
        if isWaitbarCanceled(wb)
            [events_detected, Trace_out, time_res, amplitudes_detected, widths_detected, channels_detected, metadata_detected, prominences_detected, indices_detected, wasCanceled] = stopCanceledAutoEventDetection(wb);
            return;
        end
        
        % Формируем каналы и метаданные
        channels_detected = [];
        if strcmp(DetectionType, 'two channels difference') || strcmp(DetectionType, 'two channels multiplied')
            % Для двухканальных методов сохраняем оба канала
            channels_detected = repmat([ChPos, ChNeg], length(events_detected), 1);
        elseif strcmp(DetectionType, 'one channel positive')
            channels_detected = repmat(ChPos, length(events_detected), 1);
        elseif strcmp(DetectionType, 'one channel negative')
            channels_detected = repmat(ChNeg, length(events_detected), 1);
        end
        
        % Создаем метаданные для каждого события
        metadata_detected = repmat(struct(...
            'source', 'auto', ...
            'method', 'peaks', ...
            'data_type', SourceType, ...
            'polarity', DetectionType, ...
            'prominence', NaN, ...
            'detection_params', struct(...
                'MinPeakProminence', MinPeakProminence, ...
                'MinPeakDistance', MinPeakDistance, ...
                'MaxPeakWidth', max_peak_width ...
            ) ...
        ), length(events_detected), 1);
        
        % Добавляем prominence для каждого события
        prominences_detected = prominences(:);
        for i = 1:length(events_detected)
            metadata_detected(i).prominence = prominences(i);
        end
        
        % Индексы в исходной шкале time (создаются при детекции, без поиска при сохранении)
        indices_detected = zeros(length(events_detected), 1);
        for i = 1:length(events_detected)
            [~, indices_detected(i)] = min(abs(time - events_detected(i)));
        end
        
        fprintf('=== DEBUG: Final results ===\n');
        fprintf('Total events detected: %d\n', length(events_detected));
        fprintf('===================================\n\n');
        
    else
        waitbar(0.9, wb, 'Preview mode - no detection');
        events_detected = [];
        amplitudes_detected = [];
        widths_detected = [];
        channels_detected = [];
        metadata_detected = [];
        prominences_detected = [];
        indices_detected = [];
    end
    
    waitbar(1.0, wb, 'Complete');
    if detect
        fprintf('Events detected.\n');
    end
    if ~isempty(wb) && isvalid(wb)
        delete(wb);
    end
end

function [events_detected, Trace_out, time_res, amplitudes_detected, widths_detected, channels_detected, metadata_detected, prominences_detected, indices_detected, wasCanceled] = stopCanceledAutoEventDetection(wb)
    wasCanceled = true;
    events_detected = [];
    Trace_out = [];
    time_res = [];
    amplitudes_detected = [];
    widths_detected = [];
    channels_detected = [];
    metadata_detected = [];
    prominences_detected = [];
    indices_detected = [];
    fprintf('Event detection stopped by user.\n');
    if ~isempty(wb) && isvalid(wb)
        delete(wb);
    end
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
