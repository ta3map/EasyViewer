function plotFromTableGUI(filePath)
    % plotFromTableGUI - GUI для построения боксплотов из плоских таблиц
    % Поддерживает загрузку из MAT файлов (flatTable), Excel файлов и .meta файлов состояния
    % Фильтрация данных через MATLAB формулы
    % 
    % Optional input:
    %   filePath - path to MAT file (with flatTable), Excel file, or .meta state file to load automatically
    
    % Загружаем глобальные настройки
    loadGlobalSettings();
    global SettingsFilepath
    
    if nargin < 1
        filePath = '';
    end
    
    % Загружаем координаты элементов из JSON файла
    coordsFile = getGUIConfigPath('plotFromTableGUI_coords.json');
    if exist(coordsFile, 'file')
        coordsData = jsondecode(fileread(coordsFile));
    else
        error('Coordinates file not found: %s', coordsFile);
    end
    
    % Вспомогательная функция для получения координат элемента
    function pos = getElementPosition(tag)
        if isfield(coordsData.elements, tag)
            pos = coordsData.elements.(tag);
            
            % Проверяем, не является ли элемент панелью - для них оставляем относительные координаты
            if ~strcmp(tag, 'plotPanel')
                % Преобразуем относительные координаты в абсолютные на основе base_figure_position
                base_pos = coordsData.base_figure_position;
                pos = [
                    pos(1) * base_pos(3),  % x
                    pos(2) * base_pos(4),  % y
                    pos(3) * base_pos(3),  % width
                    pos(4) * base_pos(4)   % height
                ];
            end
        else
            error('Coordinates for element %s not found in JSON file', tag);
        end
    end
    
    figTag = 'plotFromTableGUI';
    guiFig = findobj('Type', 'figure', 'Tag', figTag);
    if ~isempty(guiFig)
        fig = guiFig;
        figure(fig);
        % If filePath provided and GUI already open, load the file or state
        if ~isempty(filePath)
            [~, ~, ext] = fileparts(filePath);
            if strcmpi(ext, '.meta')
                % Загружаем состояние из .meta файла
                try
                    data = load(filePath, '-mat');
                    if ~isfield(data, 'savedState')
                        showError('Invalid state file format');
                        return
                    end
                    savedState = data.savedState;
                    fprintf('State loaded from: %s\n', filePath);
                    loadStateFromSavedState(fig, savedState, filePath);
                catch ME
                    showError(sprintf('Ошибка при загрузке: %s', ME.message));
                end
            else
                % Загружаем обычный файл данных
                loadFileInGUI(fig, filePath);
            end
        end
        return
    end
    
    % Используем базовое положение из JSON файла для начального построения
    base_figure_position = coordsData.base_figure_position;
    
    % Функция обработки закрытия окна (определяем до создания окна)
    function closePlotFromTableWindow(src, ~)
        delete(src);
        manageMainWindows('plotFromTableGUI');
    end
    
    % Создание главного окна
    fig = figure('Position', base_figure_position, ...
        'Name', 'Plot from Table', ...
        'NumberTitle', 'off', ...
        'MenuBar', 'none', ...
        'ToolBar', 'figure', ...
        'Resize', 'on', ...
        'Tag', figTag, ...
        'CloseRequestFcn', @closePlotFromTableWindow);
    
    % Состояние приложения
    state = struct();
    state.table = [];
    state.filePath = '';
    state.groupFilters = [];
    state.groupLabels = containers.Map();
    state.groupColors = containers.Map();
    state.parameters = {};
    state.nextGroupNumber = 1;
    state.showStatistics = true;
    state.showAllPvalues = true;
    state.showFileIds = false;
    state.showYValues = false;
    state.showLegend = true;
    state.yAxisRange = 'auto';
    state.yAxisMin = [];
    state.yAxisMax = [];
    state.xAxisRange = 'auto';
    state.xAxisMin = [];
    state.xAxisMax = [];
    state.title = ' ';
    state.filteredData = struct(); % Структура с отфильтрованными данными для каждого параметра
    state.plotMode = 'BoxPlot'; % Режим визуализации: 'BoxPlot', 'Correlation' или 'Histogram'
    
    set(fig, 'UserData', state);
    
    % Создание UI элементов
    createUI(fig, coordsData);
    
    % Устанавливаем обработчик изменения размера окна (используем анонимную функцию)
    set(fig, 'SizeChangedFcn', @(~,~) resizeComponentsCallback(fig, coordsFile));
    
    % Разворачиваем окно после успешной инициализации
    fig.WindowState = 'maximized';
    
    % Если передан путь к файлу, загружаем его автоматически (имеет приоритет над глобальными настройками)
    if ~isempty(filePath)
        [~, ~, ext] = fileparts(filePath);
        if strcmpi(ext, '.meta')
            % Загружаем состояние из .meta файла
            try
                data = load(filePath, '-mat');
                if ~isfield(data, 'savedState')
                    showError('Invalid state file format');
                    return
                end
                savedState = data.savedState;
                fprintf('State loaded from: %s\n', filePath);
                loadStateFromSavedState(fig, savedState, filePath);
            catch ME
                showError(sprintf('Ошибка при загрузке: %s', ME.message));
            end
        else
            % Загружаем обычный файл данных
            loadFileInGUI(fig, filePath);
        end
    else
        % Если filePath не передан, загружаем состояние из глобальных настроек
        loadBoxplotStateFromGlobalSettings(fig);
    end
end

function createUI(fig, coordsData)
    state = get(fig, 'UserData');
    
    % Вспомогательная функция для получения координат элемента
    function pos = getElementPosition(tag)
        if isfield(coordsData.elements, tag)
            pos = coordsData.elements.(tag);
            
            % Проверяем, не является ли элемент панелью - для них оставляем относительные координаты
            if ~strcmp(tag, 'plotPanel')
                % Преобразуем относительные координаты в абсолютные на основе base_figure_position
                base_pos = coordsData.base_figure_position;
                pos = [
                    pos(1) * base_pos(3),  % x
                    pos(2) * base_pos(4),  % y
                    pos(3) * base_pos(3),  % width
                    pos(4) * base_pos(4)   % height
                ];
            end
        else
            error('Coordinates for element %s not found in JSON file', tag);
        end
    end
    
    % Загрузка данных
    loadActionPopup = uicontrol('Parent', fig, 'Style', 'popupmenu', ...
        'Position', getElementPosition('loadActionPopup'), ...
        'String', {'Load File', 'Load State'}, ...
        'Tag', 'loadActionPopup', ...
        'Callback', @(~,~) loadActionCallback(fig));
    
    saveStateBtn = uicontrol('Parent', fig, 'Style', 'pushbutton', ...
        'Position', getElementPosition('saveStateBtn'), ...
        'String', 'Save State', ...
        'Tag', 'saveStateBtn', ...
        'Callback', @(~,~) saveStateCallback(fig));
    
    filePathText = uicontrol('Parent', fig, 'Style', 'text', ...
        'Position', getElementPosition('filePathText'), ...
        'String', 'No file loaded', ...
        'HorizontalAlignment', 'left', ...
        'Tag', 'filePathText');
    
    columnsListPos = getElementPosition('columnsList');
    uicontrol('Parent', fig, 'Style', 'text', ...
        'Position', getElementPosition('availableColumnsText'), ...
        'String', 'Available Columns', ...
        'FontSize', 10, ...
        'HorizontalAlignment', 'left', ...
        'Tag', 'availableColumnsText');
    
    columnsList = uicontrol('Parent', fig, 'Style', 'listbox', ...
        'Position', columnsListPos, ...
        'String', {}, ...
        'Tag', 'columnsList', ...
        'Max', 2, ...
        'Callback', @(~,~) columnSelectedCallback(fig));
    
    addToAnalysisBtn = uicontrol('Parent', fig, 'Style', 'pushbutton', ...
        'Position', getElementPosition('addToAnalysisBtn'), ...
        'String', 'Add to Analysis', ...
        'Tag', 'addToAnalysisBtn', ...
        'Callback', @(~,~) addColumnToAnalysis(fig));
    
    % Настройка анализа
    paramsTablePos = getElementPosition('paramsTable');
    uicontrol('Parent', fig, 'Style', 'text', ...
        'Position', getElementPosition('analysisColumnsText'), ...
        'String', 'Analysis Columns', ...
        'FontSize', 11, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'left', ...
        'Tag', 'analysisColumnsText');
    
    paramsTable = uitable('Parent', fig, ...
        'Position', paramsTablePos, ...
        'ColumnName', {'Show', 'Group', 'Column', 'Filter', 'Ranges', 'Label', 'Color', 'LineWidth'}, ...
        'ColumnEditable', [true, true, true, true, true, true, true, true], ...
        'ColumnFormat', {'logical', 'char', 'char', 'char', 'char', 'char', 'char', 'numeric'}, ...
        'ColumnWidth', {40, 70, 100, 80, 120, 80, 70, 70}, ...
        'Data', cell(0, 8), ...
        'Tag', 'paramsTable', ...
        'CellEditCallback', @(src, event) paramsTableEditCallback(fig, src, event), ...
        'CellSelectionCallback', @paramsTableSelectionCallback);
    
    analysisActionsPopup = uicontrol('Parent', fig, 'Style', 'popupmenu', ...
        'Position', getElementPosition('analysisActionsPopup'), ...
        'String', {'Actions...', 'Edit Filter', 'Edit Color', 'Clear All', 'Delete Selected', 'Move Up', 'Move Down', 'Clone Selected'}, ...
        'Tag', 'analysisActionsPopup', ...
        'Value', 1, ...
        'Callback', @(~,~) analysisActionsCallback(fig));
    
    dataTablePos = getElementPosition('dataTable');
    uicontrol('Parent', fig, 'Style', 'text', ...
        'Position', getElementPosition('dataPreviewText'), ...
        'String', 'Data Preview', ...
        'FontSize', 11, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'left', ...
        'Tag', 'dataPreviewText');
    
    dataTable = uitable('Parent', fig, ...
        'Position', dataTablePos, ...
        'ColumnEditable', false, ...
        'Tag', 'dataTable', ...
        'Data', cell(0, 1), ...
        'ColumnName', {'Value'});
    
    % Параметры визуализации
    showStatsCheckPos = getElementPosition('showStatsCheck');
    uicontrol('Parent', fig, 'Style', 'text', ...
        'Position', getElementPosition('visualizationOptionsText'), ...
        'String', 'Visualization Options', ...
        'FontSize', 11, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'left', ...
        'Tag', 'visualizationOptionsText');
    
    showStatsCheck = uicontrol('Parent', fig, 'Style', 'checkbox', ...
        'Position', showStatsCheckPos, ...
        'String', 'Show Statistics', ...
        'Value', 1, ...
        'Tag', 'showStatsCheck', ...
        'Callback', @(~,~) updateStatsVisibility(fig));
    
    showAllPvaluesCheck = uicontrol('Parent', fig, 'Style', 'checkbox', ...
        'Position', getElementPosition('showAllPvaluesCheck'), ...
        'String', 'Show All P-values', ...
        'Value', 1, ...
        'Tag', 'showAllPvaluesCheck');
    
    showFileIdsCheck = uicontrol('Parent', fig, 'Style', 'checkbox', ...
        'Position', getElementPosition('showFileIdsCheck'), ...
        'String', 'Show File IDs', ...
        'Value', 0, ...
        'Tag', 'showFileIdsCheck');
    
    showYValuesCheck = uicontrol('Parent', fig, 'Style', 'checkbox', ...
        'Position', getElementPosition('showYValuesCheck'), ...
        'String', 'Show Y Values', ...
        'Value', 0, ...
        'Tag', 'showYValuesCheck');
    
    % Y-ось
    yAxisPopupPos = getElementPosition('yAxisPopup');
    uicontrol('Parent', fig, 'Style', 'text', ...
        'Position', getElementPosition('yAxisRangeText'), ...
        'String', 'Y-axis Range:', ...
        'FontSize', 10, ...
        'HorizontalAlignment', 'left', ...
        'Tag', 'yAxisRangeText');
    
    yAxisPopup = uicontrol('Parent', fig, 'Style', 'popupmenu', ...
        'Position', yAxisPopupPos, ...
        'String', {'Auto', 'Manual'}, ...
        'Tag', 'yAxisPopup', ...
        'Callback', @(~,~) updateYAxisControls(fig));
    
    yAxisMinEdit = uicontrol('Parent', fig, 'Style', 'edit', ...
        'Position', getElementPosition('yAxisMinEdit'), ...
        'String', '', ...
        'Visible', 'off', ...
        'Tag', 'yAxisMinEdit');
    
    yAxisMaxEdit = uicontrol('Parent', fig, 'Style', 'edit', ...
        'Position', getElementPosition('yAxisMaxEdit'), ...
        'String', '', ...
        'Visible', 'off', ...
        'Tag', 'yAxisMaxEdit');
    
    % X-ось
    xAxisPopupPos = getElementPosition('xAxisPopup');
    uicontrol('Parent', fig, 'Style', 'text', ...
        'Position', getElementPosition('xAxisRangeText'), ...
        'String', 'X-axis Range:', ...
        'FontSize', 10, ...
        'HorizontalAlignment', 'left', ...
        'Tag', 'xAxisRangeText');
    
    xAxisPopup = uicontrol('Parent', fig, 'Style', 'popupmenu', ...
        'Position', xAxisPopupPos, ...
        'String', {'Auto', 'Manual'}, ...
        'Tag', 'xAxisPopup', ...
        'Callback', @(~,~) updateXAxisControls(fig));
    
    xAxisMinEdit = uicontrol('Parent', fig, 'Style', 'edit', ...
        'Position', getElementPosition('xAxisMinEdit'), ...
        'String', '', ...
        'Visible', 'off', ...
        'Tag', 'xAxisMinEdit');
    
    xAxisMaxEdit = uicontrol('Parent', fig, 'Style', 'edit', ...
        'Position', getElementPosition('xAxisMaxEdit'), ...
        'String', '', ...
        'Visible', 'off', ...
        'Tag', 'xAxisMaxEdit');
    
    
    % Режим визуализации (выпадающий список на месте кнопки Plot)
    plotModePopup = uicontrol('Parent', fig, 'Style', 'popupmenu', ...
        'Position', getElementPosition('plotModePopup'), ...
        'String', {'BoxPlot', 'Correlation', 'Histogram', 'CountBars'}, ...
        'Tag', 'plotModePopup', ...
        'Value', 1);
    
    % Кнопки (размещаем внизу с отступом)
    plotBtn = uicontrol('Parent', fig, 'Style', 'pushbutton', ...
        'Position', getElementPosition('plotBtn'), ...
        'String', 'Plot', ...
        'FontSize', 11, ...
        'Tag', 'plotBtn', ...
        'Callback', @(~,~) plotBoxplotCallback(fig));
    
    exportBtn = uicontrol('Parent', fig, 'Style', 'pushbutton', ...
        'Position', getElementPosition('exportBtn'), ...
        'String', 'Export', ...
        'FontSize', 11, ...
        'Tag', 'exportBtn', ...
        'Callback', @(~,~) exportPlotCallback(fig));
    
    % Поле для ввода названия графика (над контейнером графиков)
    titleLabel = uicontrol('Parent', fig, 'Style', 'text', ...
        'Position', getElementPosition('titleLabel'), ...
        'String', 'Title:', ...
        'FontSize', 10, ...
        'HorizontalAlignment', 'left', ...
        'Tag', 'titleLabel');
    
    titleEdit = uicontrol('Parent', fig, 'Style', 'edit', ...
        'Position', getElementPosition('titleEdit'), ...
        'String', ' ', ...
        'Tag', 'titleEdit');
    
    showLegendCheck = uicontrol('Parent', fig, 'Style', 'checkbox', ...
        'Position', getElementPosition('showLegendCheck'), ...
        'String', 'Show Legend', ...
        'Value', 1, ...
        'Tag', 'showLegendCheck');
    
    % Область для графика под полем для ввода названия графика
    plotPanel = uipanel('Parent', fig, ...
        'Position', getElementPosition('plotPanel'), ...
        'Tag', 'plotPanel');
end

function showError(errorMsg)
    % showError - Показ ошибки пользователю
    % Входные параметры:
    %   errorMsg - текст сообщения об ошибке
    fprintf('ERROR: %s\n', errorMsg);
    msgbox(errorMsg, 'Error', 'error');
end

function resizeComponentsCallback(fig, coordsFile)
    % resizeComponentsCallback - Функция автомасштабирования элементов при изменении размера окна
    try
        % Загружаем базовый размер из JSON для правильного вычисления коэффициентов масштабирования
        if exist(coordsFile, 'file')
            coordsDataResize = jsondecode(fileread(coordsFile));
            base_figure_position_resize = coordsDataResize.base_figure_position;
            ResizeElements(fig, coordsFile, base_figure_position_resize);
        end
    catch ME
        warning('Error scaling elements: %s', ME.message);
    end
end

function filePath = getFileWithInitialPath(filter, dialogTitle, defaultName)
    % getFileWithInitialPath - Получение пути к файлу с переходом в начальную директорию
    % Входные параметры:
    %   filter - фильтр файлов для uigetfile/uiputfile
    %   dialogTitle - заголовок диалога
    %   defaultName - имя файла по умолчанию (для uiputfile, опционально)
    % Выходные параметры:
    %   filePath - путь к выбранному файлу (пустая строка, если отменено)
    
    initialPath = getBoxplotInitialPath();
    oldDir = pwd;
    
    try
        if exist(initialPath, 'dir')
            cd(initialPath);
        end
        
        if nargin >= 3
            [file, path] = uiputfile(filter, dialogTitle, defaultName);
        else
            [file, path] = uigetfile(filter, dialogTitle);
        end
        
        cd(oldDir);
        
        if isequal(file, 0)
            filePath = '';
            return
        end
        
        filePath = fullfile(path, file);
    catch ME
        try
            cd(oldDir);
        catch
        end
        rethrow(ME);
    end
end

function loadFileCallback(fig)
    filePath = getFileWithInitialPath({'*.mat;*.xlsx;*.xls', 'Data Files (*.mat, *.xlsx, *.xls)'; ...
                                       '*.mat', 'MAT Files (*.mat)'; ...
                                       '*.xlsx;*.xls', 'Excel Files (*.xlsx, *.xls)'}, ...
                                      'Select Data File');
    
    if isempty(filePath)
        return
    end
    
    loadFileInGUI(fig, filePath);
end

function loadActionCallback(fig)
    loadActionPopup = findobj(fig, 'Tag', 'loadActionPopup');
    if isempty(loadActionPopup)
        return
    end
    
    selectedValue = get(loadActionPopup, 'Value');
    
    if selectedValue == 1
        loadFileCallback(fig);
    elseif selectedValue == 2
        loadStateCallback(fig);
    end
    
    set(loadActionPopup, 'Value', 1);
end

function savedState = createSavedStateFromState(state)
    % createSavedStateFromState - Создание структуры savedState из state
    % Входные параметры:
    %   state - структура состояния GUI
    % Выходные параметры:
    %   savedState - структура для сохранения
    
    savedState = struct();
    savedState.filePath = state.filePath;
    savedState.parameters = state.parameters;
    savedState.nextGroupNumber = state.nextGroupNumber;
    savedState.showStatistics = state.showStatistics;
    savedState.showAllPvalues = state.showAllPvalues;
    savedState.showFileIds = state.showFileIds;
    savedState.showYValues = state.showYValues;
    savedState.showLegend = state.showLegend;
    savedState.yAxisRange = state.yAxisRange;
    savedState.yAxisMin = state.yAxisMin;
    savedState.yAxisMax = state.yAxisMax;
    savedState.xAxisRange = state.xAxisRange;
    savedState.xAxisMin = state.xAxisMin;
    savedState.xAxisMax = state.xAxisMax;
    savedState.title = state.title;
    savedState.plotMode = state.plotMode;
end

function state = restoreStateFromSavedState(state, savedState)
    % restoreStateFromSavedState - Восстановление state из savedState
    % Входные параметры:
    %   state - текущая структура состояния GUI
    %   savedState - структура сохраненного состояния
    % Выходные параметры:
    %   state - обновленная структура состояния
    
    if isfield(savedState, 'parameters')
        state.parameters = savedState.parameters;
        for i = 1:length(state.parameters)
            p = state.parameters{i};
            if ~isfield(p, 'groupName')
                if isfield(p, 'groupNumber')
                    state.parameters{i}.groupName = num2str(p.groupNumber);
                else
                    state.parameters{i}.groupName = '1';
                end
            end
            % Инициализируем ranges для старых состояний
            if ~isfield(p, 'ranges')
                state.parameters{i}.ranges = '';
            end
        end
    end
    if isfield(savedState, 'nextGroupNumber')
        state.nextGroupNumber = savedState.nextGroupNumber;
    end
    if isfield(savedState, 'showStatistics')
        state.showStatistics = savedState.showStatistics;
    end
    if isfield(savedState, 'showAllPvalues')
        state.showAllPvalues = savedState.showAllPvalues;
    end
    if isfield(savedState, 'showFileIds')
        state.showFileIds = savedState.showFileIds;
    else
        state.showFileIds = false;
    end
    if isfield(savedState, 'showYValues')
        state.showYValues = savedState.showYValues;
    else
        state.showYValues = false;
    end
    if isfield(savedState, 'showLegend')
        state.showLegend = savedState.showLegend;
    else
        state.showLegend = true;
    end
    if isfield(savedState, 'yAxisRange')
        state.yAxisRange = savedState.yAxisRange;
    end
    if isfield(savedState, 'yAxisMin')
        state.yAxisMin = savedState.yAxisMin;
    end
    if isfield(savedState, 'yAxisMax')
        state.yAxisMax = savedState.yAxisMax;
    end
    if isfield(savedState, 'xAxisRange')
        state.xAxisRange = savedState.xAxisRange;
    end
    if isfield(savedState, 'xAxisMin')
        state.xAxisMin = savedState.xAxisMin;
    end
    if isfield(savedState, 'xAxisMax')
        state.xAxisMax = savedState.xAxisMax;
    end
    if ~isfield(state, 'xAxisRange')
        state.xAxisRange = 'auto';
    end
    if ~isfield(state, 'xAxisMin')
        state.xAxisMin = [];
    end
    if ~isfield(state, 'xAxisMax')
        state.xAxisMax = [];
    end
    if isfield(savedState, 'title')
        state.title = savedState.title;
    end
    if isfield(savedState, 'plotMode')
        state.plotMode = savedState.plotMode;
    else
        state.plotMode = 'BoxPlot';
    end
end

function saveStateToFile(fig, filePath)
    % saveStateToFile - Сохранение состояния в .meta файл
    % Входные параметры:
    %   fig - handle фигуры GUI
    %   filePath - путь к файлу для сохранения
    
    state = get(fig, 'UserData');
    savedState = createSavedStateFromState(state);
    
    save(filePath, 'savedState', '-mat');
    fprintf('State saved to: %s\n', filePath);
    
    % Сохраняем также в глобальные настройки
    saveBoxplotStateToGlobalSettings(fig);
end

function saveStateCallback(fig)
    % Сохранение состояния в .meta файл
    state = get(fig, 'UserData');
    
    if isempty(state.filePath)
        showError('Сначала загрузите файл с данными');
        return
    end
    
    filePath = getFileWithInitialPath('*.meta', 'Save State', 'boxplot_state.meta');
    
    if isempty(filePath)
        return
    end
    
    try
        saveStateToFile(fig, filePath);
    catch ME
        showError(sprintf('Ошибка при сохранении: %s', ME.message));
    end
end

function loadStateFromSavedState(fig, savedState, metaFilePath)
    % loadStateFromSavedState - Общая функция для загрузки состояния из savedState
    % Входные параметры:
    %   fig - handle фигуры GUI
    %   savedState - структура сохраненного состояния
    %   metaFilePath - путь к .meta файлу (опционально, для поиска файла данных в папке .meta файла)
    
    % Сохраняем параметры перед загрузкой файла (loadFileInGUI очищает их)
    savedParameters = {};
    savedNextGroupNumber = 1;
    if isfield(savedState, 'parameters')
        savedParameters = savedState.parameters;
    end
    if isfield(savedState, 'nextGroupNumber')
        savedNextGroupNumber = savedState.nextGroupNumber;
    end
    
    % 1. Загружаем данные
    if isfield(savedState, 'filePath') && ~isempty(savedState.filePath)
        dataFilePath = savedState.filePath;
        
        % Если файл не найден и передан metaFilePath, ищем в папке .meta файла
        if ~exist(dataFilePath, 'file') && ~isempty(metaFilePath)
            [statePath, ~, ~] = fileparts(metaFilePath);
            
            if isempty(statePath)
                statePath = pwd;
            end
            
            originalPath = savedState.filePath;
            originalPath = strrep(originalPath, '\', '/');
            pathParts = strsplit(originalPath, '/');
            if isempty(pathParts{end})
                pathParts = pathParts(1:end-1);
            end
            fileNameWithExt = pathParts{end};
            
            if ~isempty(fileNameWithExt)
                alternativePath = fullfile(statePath, fileNameWithExt);
                
                if exist(alternativePath, 'file')
                    dataFilePath = alternativePath;
                    fprintf('Data file found in state folder: %s\n', dataFilePath);
                else
                    showError(sprintf('Data file not found: %s\nAlso checked: %s', savedState.filePath, alternativePath));
                    return
                end
            else
                showError(sprintf('Data file not found: %s', savedState.filePath));
                return
            end
        elseif ~exist(dataFilePath, 'file')
            % Если файл не найден и metaFilePath пустой (загрузка из глобальных настроек),
            % просто возвращаемся без ошибки
            if isempty(metaFilePath)
                % Файл не найден, возвращаемся без восстановления состояния
                return
            else
                showError(sprintf('Data file not found: %s', savedState.filePath));
                return
            end
        end
        
        loadFileInGUI(fig, dataFilePath);
    else
        % Если filePath отсутствует в savedState, это ошибка только для .meta файлов
        if ~isempty(metaFilePath)
            showError('State file does not contain filePath');
            return
        end
        % Для глобальных настроек это нормально - просто нет файла данных, возвращаемся
        return
    end
    
    % 2. Восстанавливаем параметры и настройки после загрузки файла
    state = get(fig, 'UserData');
    state.parameters = savedParameters;
    state.nextGroupNumber = savedNextGroupNumber;
    state = restoreStateFromSavedState(state, savedState);
    set(fig, 'UserData', state);
    
    % 3. Обновляем UI
    updateAnalysisColumnsDisplay(fig);
    updateUIFromState(fig);
    
    % 4. Обновляем структуру filteredData
    updateFilteredDataStructure(fig);
    
    % 5. Синхронизируем с глобальными настройками
    saveBoxplotStateToGlobalSettings(fig);
    
    % 6. Автоматически строим график после успешного восстановления состояния
    pause(0.1);
    plotBoxplotCallback(fig);
end

function loadStateCallback(fig)
    % Загрузка состояния из .meta файла
    filePath = getFileWithInitialPath('*.meta', 'Load State');
    
    if isempty(filePath)
        return
    end
    
    try
        data = load(filePath, '-mat');
        
        if ~isfield(data, 'savedState')
            showError('Invalid state file format');
            return
        end
        
        savedState = data.savedState;
        
        fprintf('State loaded from: %s\n', filePath);
        loadStateFromSavedState(fig, savedState, filePath);
    catch ME
        showError(sprintf('Ошибка при загрузке: %s', ME.message));
    end
end

function loadFileInGUI(fig, filePath)
    % Load file into GUI (used both by callback and programmatic loading)
    state = get(fig, 'UserData');
    
    try
        [~, ~, ext] = fileparts(filePath);
        if strcmpi(ext, '.mat')
            data = load(filePath, '-mat');
            if isfield(data, 'flatTable')
                state.table = data.flatTable;
            else
                showError('MAT file does not contain variable "flatTable"');
                return
            end
        elseif any(strcmpi(ext, {'.xlsx', '.xls'}))
            state.table = readtable(filePath);
        else
            showError('Unsupported file format');
            return
        end
        
        % Форматируем названия колонок
        state.table = boxplotFormatTableColumnNames(state.table);
        
        % Конвертируем колонки таблицы (определение типов, конвертация числовых cell-массивов, замена пустых ячеек)
        state.table = convertTableColumns(state.table);
        
        state.filePath = filePath;
        state.parameters = {};
        state.nextGroupNumber = 1;
        state.filteredData = struct();
        set(fig, 'UserData', state);
        
        % Update UI
        filePathText = findobj(fig, 'Tag', 'filePathText');
        if ~isempty(filePathText)
            set(filePathText, 'String', boxplotTruncatePath(filePath));
        end
        
        columnsList = findobj(fig, 'Tag', 'columnsList');
        if ~isempty(columnsList) && istable(state.table)
            set(columnsList, 'String', state.table.Properties.VariableNames);
        end
        
        % Clear data table
        dataTable = findobj(fig, 'Tag', 'dataTable');
        if ~isempty(dataTable)
            set(dataTable, 'Data', cell(0, 1));
        end
        
        % Update analysis columns display
        updateAnalysisColumnsDisplay(fig);
    catch ME
        showError(sprintf('Error loading file: %s', ME.message));
    end
end

function columnSelectedCallback(fig)
    % Show selected column data in the preview table
    state = get(fig, 'UserData');
    if isempty(state.table)
        return
    end
    
    columnsList = findobj(fig, 'Tag', 'columnsList');
    if isempty(columnsList)
        return
    end
    
    selectedIdx = get(columnsList, 'Value');
    columnNames = get(columnsList, 'String');
    
    if isempty(selectedIdx) || isempty(columnNames)
        return
    end
    
    % Если выбрано несколько колонок, показываем первую
    if isnumeric(selectedIdx) && length(selectedIdx) > 1
        selectedIdx = selectedIdx(1);
    end
    
    if selectedIdx > length(columnNames)
        return
    end
    
    selectedColumn = columnNames{selectedIdx};
    
    if ~ismember(selectedColumn, state.table.Properties.VariableNames)
        return
    end
    
    % Get column data
    columnData = state.table{:, selectedColumn};
    
    % Convert to cell array for display
    if isnumeric(columnData) || islogical(columnData)
        displayData = cell(length(columnData), 1);
        for i = 1:length(columnData)
            if isnan(columnData(i)) && isnumeric(columnData)
                displayData{i} = 'NaN';
            else
                displayData{i} = num2str(columnData(i));
            end
        end
    elseif iscell(columnData)
        displayData = cell(length(columnData), 1);
        for i = 1:length(columnData)
            if ischar(columnData{i}) || isstring(columnData{i})
                displayData{i} = char(columnData{i});
            else
                displayData{i} = mat2str(columnData{i});
            end
        end
    else
        displayData = cellstr(string(columnData));
    end
    
    % Update table
    dataTable = findobj(fig, 'Tag', 'dataTable');
    if ~isempty(dataTable)
        set(dataTable, 'Data', displayData);
        set(dataTable, 'ColumnName', {selectedColumn});
        set(dataTable, 'RowName', {});
    end
end

function paramsTableSelectionCallback(src, event)
    % Show filtered data from state.filteredData in the preview table
    fig = ancestor(src, 'figure');
    state = get(fig, 'UserData');
    
    if isempty(event.Indices)
        set(src, 'UserData', []);
        return
    end
    
    % Получаем все выделенные строки
    selectedRows = unique(event.Indices(:, 1));
    
    % Сохраняем выделение в UserData таблицы для использования в editFilterCallback
    set(src, 'UserData', event.Indices);
    
    if isempty(selectedRows)
        return
    end
    
    if ~isfield(state, 'parameterToFieldName') || isempty(state.filteredData)
        return
    end
    
    allColumnData = {};
    columnNames = {};
    allParamData = {};
    
    for rowIdx = selectedRows(:)'
        if rowIdx < 1 || rowIdx > length(state.parameterToFieldName)
            continue
        end
        fieldName = state.parameterToFieldName{rowIdx};
        if isempty(fieldName) || ~isfield(state.filteredData, fieldName)
            continue
        end
        param = state.parameters{rowIdx};
        paramData = state.filteredData.(fieldName);
        if ~isfield(paramData, 'data')
            continue
        end
        columnData = paramData.data;
        
        % Преобразуем данные в cell array
        if isnumeric(columnData) || islogical(columnData)
            displayData = cell(length(columnData), 1);
            for i = 1:length(columnData)
                if isnan(columnData(i)) && isnumeric(columnData)
                    displayData{i} = 'NaN';
                else
                    displayData{i} = num2str(columnData(i));
                end
            end
        elseif iscell(columnData)
            displayData = cell(length(columnData), 1);
            for i = 1:length(columnData)
                if ischar(columnData{i}) || isstring(columnData{i})
                    displayData{i} = char(columnData{i});
                else
                    displayData{i} = mat2str(columnData{i});
                end
            end
        else
            displayData = cellstr(string(columnData));
        end
        
        allColumnData{end+1} = displayData;
        allParamData{end+1} = paramData;
        
        % Формируем название колонки - используем Label
        if ~isempty(param.label)
            columnDisplayName = param.label;
        else
            columnDisplayName = param.column;
        end
        columnNames{end+1} = columnDisplayName;
    end
    
    if isempty(allColumnData)
        return
    end
    
    % Определяем максимальную длину данных
    maxDataLength = 0;
    for i = 1:length(allColumnData)
        maxDataLength = max(maxDataLength, length(allColumnData{i}));
    end
    
    % Количество строк статистики
    numStatsRows = 9; % n, mean, median, std, Q25, Q75, min, max, NaN count
    statsLabels = {'n', 'mean', 'median', 'std', 'Q25', 'Q75', 'min', 'max', 'NaN count'};
    
    % Создаем таблицу с данными и статистикой (статистика вверху)
    tableData = cell(numStatsRows + maxDataLength, length(allColumnData));
    
    % Заполняем данные и статистику
    for col = 1:length(allColumnData)
        colData = allColumnData{col};
        paramData = allParamData{col};
        
        % Сначала заполняем статистику вверху
        if isfield(paramData, 'stats') && isnumeric(paramData.data)
            stats = paramData.stats;
            tableData{1, col} = stats.count;
            tableData{2, col} = sprintf('%.4f', stats.mean);
            tableData{3, col} = sprintf('%.4f', stats.median);
            tableData{4, col} = sprintf('%.4f', stats.std);
            tableData{5, col} = sprintf('%.4f', stats.q25);
            tableData{6, col} = sprintf('%.4f', stats.q75);
            tableData{7, col} = sprintf('%.4f', stats.min);
            tableData{8, col} = sprintf('%.4f', stats.max);
            tableData{9, col} = stats.nanCount;
        else
            % Если статистики нет или данные не числовые, заполняем пустыми строками
            for row = 1:numStatsRows
                tableData{row, col} = '';
            end
        end
        
        % Затем заполняем данные
        for row = 1:maxDataLength
            dataRow = numStatsRows + row;
            if row <= length(colData)
                tableData{dataRow, col} = colData{row};
            else
                tableData{dataRow, col} = '';
            end
        end
    end
    
    % Формируем имена строк: лейблы статистики вверху, номера для данных
    rowNames = cell(numStatsRows + maxDataLength, 1);
    for i = 1:numStatsRows
        rowNames{i} = statsLabels{i};
    end
    for row = 1:maxDataLength
        rowNames{numStatsRows + row} = num2str(row);
    end
    
    % Update table
    dataTable = findobj(fig, 'Tag', 'dataTable');
    if ~isempty(dataTable)
        set(dataTable, 'Data', tableData);
        set(dataTable, 'ColumnName', columnNames);
        set(dataTable, 'RowName', rowNames);
    end
end

function addColumnToAnalysis(fig)
    % Добавление выбранных колонок в поле анализа
    state = get(fig, 'UserData');
    if isempty(state.table)
        return
    end
    
    columnsList = findobj(fig, 'Tag', 'columnsList');
    paramsTable = findobj(fig, 'Tag', 'paramsTable');
    
    if isempty(columnsList) || isempty(paramsTable)
        return
    end
    
    selectedIdx = get(columnsList, 'Value');
    columnNames = get(columnsList, 'String');
    
    if isempty(selectedIdx) || isempty(columnNames)
        return
    end
    
    % Обработка множественного выбора
    if ~isnumeric(selectedIdx)
        selectedIdx = double(selectedIdx);
    end
    
    % Добавляем выбранные колонки
    for i = 1:length(selectedIdx)
        if selectedIdx(i) <= length(columnNames)
            colName = columnNames{selectedIdx(i)};
            % Генерируем цвет для нового параметра
            colorIndex = length(state.parameters) + 1;
            colors = getColors(colorIndex);
            colorHex = colors{colorIndex};
            state.parameters{end+1} = struct('column', colName, 'groupName', '1', 'filter', '', 'ranges', '', 'label', colName, 'color', colorHex, 'lineWidth', 1, 'visible', true);
        end
    end
    
    set(fig, 'UserData', state);
    updateAnalysisColumnsDisplay(fig);
    updateFilteredDataStructure(fig);
end

function analysisActionsCallback(fig)
    % Обработчик действий с таблицей анализа
    analysisActionsPopup = findobj(fig, 'Tag', 'analysisActionsPopup');
    if isempty(analysisActionsPopup)
        return
    end
    
    selectedValue = get(analysisActionsPopup, 'Value');
    
    % Возвращаем значение в исходное состояние
    set(analysisActionsPopup, 'Value', 1);
    
    switch selectedValue
        case 2  % Edit Filter
            editFilterCallback(fig);
        case 3  % Edit Color
            editColorCallback(fig);
        case 4  % Clear All
            clearAnalysisColumns(fig);
        case 5  % Delete Selected
            deleteSelectedRow(fig);
        case 6  % Move Up
            moveRowUp(fig);
        case 7  % Move Down
            moveRowDown(fig);
        case 8  % Clone Selected
            cloneSelectedRows(fig);
    end
end

function clearAnalysisColumns(fig)
    % Очистка поля анализа
    state = get(fig, 'UserData');
    state.parameters = {};
    state.nextGroupNumber = 1;
    state.filteredData = struct();
    set(fig, 'UserData', state);
    updateAnalysisColumnsDisplay(fig);
    updateFilteredDataStructure(fig);
end

function deleteSelectedRow(fig)
    % Удаление выделенной строки из таблицы анализа
    state = get(fig, 'UserData');
    paramsTable = findobj(fig, 'Tag', 'paramsTable');
    
    if isempty(paramsTable) || isempty(state.parameters)
        return
    end
    
    % Получаем выделенные строки
    tableData = get(paramsTable, 'Data');
    if isempty(tableData)
        return
    end
    
    % Получаем выделение из UserData таблицы
    selectedIndices = get(paramsTable, 'UserData');
    if isempty(selectedIndices)
        return
    end
    
    selectedRows = unique(selectedIndices(:, 1));
    if isempty(selectedRows)
        return
    end
    
    % Удаляем выделенные строки (в обратном порядке, чтобы индексы не сдвигались)
    selectedRows = sort(selectedRows, 'descend');
    for i = 1:length(selectedRows)
        rowIdx = selectedRows(i);
        if rowIdx >= 1 && rowIdx <= length(state.parameters)
            state.parameters(rowIdx) = [];
        end
    end
    
    set(fig, 'UserData', state);
    updateAnalysisColumnsDisplay(fig);
    updateFilteredDataStructure(fig);
end

function moveRowUp(fig)
    % Перемещение выделенной строки вверх
    state = get(fig, 'UserData');
    paramsTable = findobj(fig, 'Tag', 'paramsTable');
    
    if isempty(paramsTable) || isempty(state.parameters) || length(state.parameters) < 2
        return
    end
    
    % Получаем выделенные строки
    selectedIndices = get(paramsTable, 'UserData');
    if isempty(selectedIndices)
        return
    end
    
    selectedRows = unique(selectedIndices(:, 1));
    if isempty(selectedRows) || any(selectedRows == 1)
        % Нельзя переместить первую строку вверх
        return
    end
    
    % Сортируем по возрастанию и перемещаем вверх
    selectedRows = sort(selectedRows, 'ascend');
    for i = 1:length(selectedRows)
        rowIdx = selectedRows(i);
        if rowIdx > 1 && rowIdx <= length(state.parameters)
            % Меняем местами с предыдущей строкой
            temp = state.parameters{rowIdx};
            state.parameters{rowIdx} = state.parameters{rowIdx - 1};
            state.parameters{rowIdx - 1} = temp;
        end
    end
    
    set(fig, 'UserData', state);
    updateAnalysisColumnsDisplay(fig);
    updateFilteredDataStructure(fig);
    
    % Восстанавливаем выделение (смещаем на одну позицию вверх)
    newSelectedRows = selectedRows - 1;
    if ~isempty(newSelectedRows)
        newIndices = [newSelectedRows(:), ones(length(newSelectedRows), 1)];
        set(paramsTable, 'UserData', newIndices);
    end
end

function moveRowDown(fig)
    % Перемещение выделенной строки вниз
    state = get(fig, 'UserData');
    paramsTable = findobj(fig, 'Tag', 'paramsTable');
    
    if isempty(paramsTable) || isempty(state.parameters) || length(state.parameters) < 2
        return
    end
    
    % Получаем выделенные строки
    selectedIndices = get(paramsTable, 'UserData');
    if isempty(selectedIndices)
        return
    end
    
    selectedRows = unique(selectedIndices(:, 1));
    if isempty(selectedRows) || any(selectedRows == length(state.parameters))
        % Нельзя переместить последнюю строку вниз
        return
    end
    
    % Сортируем по убыванию и перемещаем вниз
    selectedRows = sort(selectedRows, 'descend');
    for i = 1:length(selectedRows)
        rowIdx = selectedRows(i);
        if rowIdx >= 1 && rowIdx < length(state.parameters)
            % Меняем местами со следующей строкой
            temp = state.parameters{rowIdx};
            state.parameters{rowIdx} = state.parameters{rowIdx + 1};
            state.parameters{rowIdx + 1} = temp;
        end
    end
    
    set(fig, 'UserData', state);
    updateAnalysisColumnsDisplay(fig);
    updateFilteredDataStructure(fig);
    
    % Восстанавливаем выделение (смещаем на одну позицию вниз)
    newSelectedRows = selectedRows + 1;
    if ~isempty(newSelectedRows)
        newIndices = [newSelectedRows(:), ones(length(newSelectedRows), 1)];
        set(paramsTable, 'UserData', newIndices);
    end
end

function cloneSelectedRows(fig)
    % Клонирование выделенных строк и добавление их вниз таблицы
    state = get(fig, 'UserData');
    paramsTable = findobj(fig, 'Tag', 'paramsTable');
    
    if isempty(paramsTable) || isempty(state.parameters)
        return
    end
    
    % Получаем выделенные строки
    selectedIndices = get(paramsTable, 'UserData');
    if isempty(selectedIndices)
        return
    end
    
    selectedRows = unique(selectedIndices(:, 1));
    if isempty(selectedRows)
        return
    end
    
    % Проверяем валидность индексов
    validRows = selectedRows(selectedRows >= 1 & selectedRows <= length(state.parameters));
    if isempty(validRows)
        return
    end
    
    % Клонируем выделенные строки
    clonedParams = cell(1, length(validRows));
    for i = 1:length(validRows)
        rowIdx = validRows(i);
        clonedParams{i} = state.parameters{rowIdx};
    end
    
    % Добавляем клонированные строки в конец
    state.parameters = [state.parameters, clonedParams];
    
    set(fig, 'UserData', state);
    updateAnalysisColumnsDisplay(fig);
    updateFilteredDataStructure(fig);
    
    % Выделяем новые строки (клонированные)
    numRows = length(state.parameters);
    newSelectedRows = (numRows - length(validRows) + 1):numRows;
    if ~isempty(newSelectedRows)
        newIndices = [newSelectedRows(:), ones(length(newSelectedRows), 1)];
        set(paramsTable, 'UserData', newIndices);
    end
end

function updateAnalysisColumnsDisplay(fig)
    % Обновление отображения списка колонок для анализа
    state = get(fig, 'UserData');
    paramsTable = findobj(fig, 'Tag', 'paramsTable');
    
    if isempty(paramsTable)
        return
    end
    
    if isempty(state.parameters)
        set(paramsTable, 'Data', cell(0, 8));
        return
    end
    
    tableData = cell(length(state.parameters), 8);
    for i = 1:length(state.parameters)
        v = state.parameters{i};
        tableData{i, 1} = (isfield(v, 'visible') && v.visible) || ~isfield(v, 'visible');
        if isfield(v, 'groupName')
            tableData{i, 2} = v.groupName;
        elseif isfield(v, 'groupNumber')
            tableData{i, 2} = num2str(v.groupNumber);
        else
            tableData{i, 2} = '1';
        end
        tableData{i, 3} = v.column;
        tableData{i, 4} = v.filter;
        if isfield(v, 'ranges')
            tableData{i, 5} = v.ranges;
        else
            tableData{i, 5} = '';
        end
        tableData{i, 6} = v.label;
        tableData{i, 7} = v.color;
        tableData{i, 8} = v.lineWidth;
    end
    
    set(paramsTable, 'Data', tableData);
    set(fig, 'UserData', state);
end

function paramsTableEditCallback(fig, src, event)
    % Callback при редактировании таблицы параметров
    state = get(fig, 'UserData');
    paramsTable = findobj(fig, 'Tag', 'paramsTable');
    
    if isempty(paramsTable) || isempty(state.parameters)
        return
    end
    
    tableData = get(paramsTable, 'Data');
    editedRow = event.Indices(1);
    editedCol = event.Indices(2);
    
    if editedCol == 3 && editedRow <= length(state.parameters)
        newColumnName = tableData{editedRow, 3};
        if ischar(newColumnName) || isstring(newColumnName)
            newColumnName = char(newColumnName);
            if ~ismember(newColumnName, state.table.Properties.VariableNames)
                msgbox(sprintf('Column "%s" does not exist in the table', newColumnName), 'Warning', 'warn');
                tableData{editedRow, 3} = state.parameters{editedRow}.column;
                set(paramsTable, 'Data', tableData);
                return
            end
        end
    end
    
    for i = 1:min(length(state.parameters), size(tableData, 1))
        state.parameters{i}.visible = logical(tableData{i, 1});
        g = tableData{i, 2};
        if ischar(g) || isstring(g)
            state.parameters{i}.groupName = char(g);
        end
        if ischar(tableData{i, 3}) || isstring(tableData{i, 3})
            newColumnName = char(tableData{i, 3});
            if ismember(newColumnName, state.table.Properties.VariableNames)
                state.parameters{i}.column = newColumnName;
            end
        end
        if ischar(tableData{i, 4}) || isstring(tableData{i, 4})
            state.parameters{i}.filter = char(tableData{i, 4});
        end
        if ischar(tableData{i, 5}) || isstring(tableData{i, 5})
            state.parameters{i}.ranges = char(tableData{i, 5});
        end
        if ischar(tableData{i, 6}) || isstring(tableData{i, 6})
            state.parameters{i}.label = char(tableData{i, 6});
        end
        if ischar(tableData{i, 7}) || isstring(tableData{i, 7})
            state.parameters{i}.color = char(tableData{i, 7});
        end
        if isnumeric(tableData{i, 8}) && tableData{i, 8} > 0
            state.parameters{i}.lineWidth = tableData{i, 8};
        end
    end
    
    set(fig, 'UserData', state);
    updateFilteredDataStructure(fig);
end

function editFilterCallback(fig)
    paramsTable = findobj(fig, 'Tag', 'paramsTable');
    if isempty(paramsTable)
        return
    end
    
    state = get(fig, 'UserData');
    if isempty(state.parameters)
        msgbox('No parameters to edit', 'Warning', 'warn');
        return
    end
    
    selectedIndices = get(paramsTable, 'UserData');
    if isempty(selectedIndices)
        msgbox('Please select a row to edit filter', 'Warning', 'warn');
        return
    end
    
    selectedRows = unique(selectedIndices(:, 1));
    if isempty(selectedRows) || selectedRows(1) < 1 || selectedRows(1) > length(state.parameters)
        msgbox('Please select a valid row to edit filter', 'Warning', 'warn');
        return
    end
    
    selectedRow = selectedRows(1);
    
    currentFilter = '';
    if selectedRow <= length(state.parameters) && isfield(state.parameters{selectedRow}, 'filter')
        currentFilter = state.parameters{selectedRow}.filter;
        if isempty(currentFilter)
            currentFilter = '';
        end
    end
    
    createFilterEditDialog(fig, selectedRow, currentFilter);
end

function editColorCallback(fig)
    paramsTable = findobj(fig, 'Tag', 'paramsTable');
    if isempty(paramsTable)
        return
    end
    
    state = get(fig, 'UserData');
    if isempty(state.parameters)
        msgbox('No parameters to edit', 'Warning', 'warn');
        return
    end
    
    selectedIndices = get(paramsTable, 'UserData');
    if isempty(selectedIndices)
        msgbox('Please select a row to edit color', 'Warning', 'warn');
        return
    end
    
    selectedRows = unique(selectedIndices(:, 1));
    if isempty(selectedRows) || selectedRows(1) < 1 || selectedRows(1) > length(state.parameters)
        msgbox('Please select a valid row to edit color', 'Warning', 'warn');
        return
    end
    
    selectedRow = selectedRows(1);
    
    currentColor = '';
    if selectedRow <= length(state.parameters) && isfield(state.parameters{selectedRow}, 'color')
        currentColor = state.parameters{selectedRow}.color;
        if isempty(currentColor)
            currentColor = '';
        end
    end
    
    createColorEditDialog(fig, selectedRow, currentColor);
end

function createFilterEditDialog(fig, rowIndex, currentFilter)
    dialogWidth = 500;
    dialogHeight = 300;
    dialogFig = figure('Position', [100, 100, dialogWidth, dialogHeight], ...
        'Name', 'Edit Filter', ...
        'NumberTitle', 'off', ...
        'MenuBar', 'none', ...
        'Resize', 'off', ...
        'WindowStyle', 'modal');
    
    margin = 10;
    buttonHeight = 30;
    buttonWidth = 80;
    
    filterEdit = uicontrol('Parent', dialogFig, 'Style', 'edit', ...
        'Position', [margin, margin + buttonHeight + 10, dialogWidth - 2*margin, dialogHeight - 2*margin - buttonHeight - 20], ...
        'String', currentFilter, ...
        'Max', 10, ...
        'HorizontalAlignment', 'left', ...
        'Tag', 'filterEdit', ...
        'FontName', 'Courier New');
    
    applyBtn = uicontrol('Parent', dialogFig, 'Style', 'pushbutton', ...
        'Position', [dialogWidth - 2*margin - 2*buttonWidth - 10, margin, buttonWidth, buttonHeight], ...
        'String', 'Apply', ...
        'Callback', @(src,~) applyFilterEdit(src, fig, rowIndex));
    
    cancelBtn = uicontrol('Parent', dialogFig, 'Style', 'pushbutton', ...
        'Position', [dialogWidth - margin - buttonWidth, margin, buttonWidth, buttonHeight], ...
        'String', 'Cancel', ...
        'Callback', @(src,~) cancelFilterEdit(src));
    
    uicontrol(filterEdit);
end

function applyFilterEdit(src, fig, rowIndex)
    dialogFig = ancestor(src, 'figure');
    filterEdit = findobj(dialogFig, 'Tag', 'filterEdit');
    
    if isempty(filterEdit)
        close(dialogFig);
        return
    end
    
    newFilter = get(filterEdit, 'String');
    
    state = get(fig, 'UserData');
    if rowIndex >= 1 && rowIndex <= length(state.parameters)
        state.parameters{rowIndex}.filter = newFilter;
        set(fig, 'UserData', state);
        updateAnalysisColumnsDisplay(fig);
        updateFilteredDataStructure(fig);
    end
    
    close(dialogFig);
end

function cancelFilterEdit(src)
    dialogFig = ancestor(src, 'figure');
    close(dialogFig);
end

function createColorEditDialog(fig, rowIndex, currentColor)
    colors = getColors(30);
    
    dialogWidth = 400;
    buttonHeight = 30;
    margin = 10;
    buttonWidth = 80;
    colorButtonSize = 35;
    gridCols = 6;
    gridRows = 5;
    gridSpacing = 5;
    gridWidth = gridCols * colorButtonSize + (gridCols - 1) * gridSpacing;
    gridHeight = gridRows * colorButtonSize + (gridRows - 1) * gridSpacing;
    dialogHeight = gridHeight + buttonHeight + 3 * margin + 20;
    
    dialogFig = figure('Position', [100, 100, dialogWidth, dialogHeight], ...
        'Name', 'Edit Color', ...
        'NumberTitle', 'off', ...
        'MenuBar', 'none', ...
        'Resize', 'off', ...
        'WindowStyle', 'modal');
    
    gridStartX = (dialogWidth - gridWidth) / 2;
    gridStartY = dialogHeight - gridHeight - margin - 20;
    
    selectedColorHex = '';
    if ~isempty(currentColor)
        selectedColorHex = currentColor;
    end
    
    for row = 1:gridRows
        for col = 1:gridCols
            colorIdx = (row - 1) * gridCols + col;
            if colorIdx > 30
                break
            end
            
            colorHex = colors{colorIdx};
            colorRGB = hex2rgb(colorHex);
            
            xPos = gridStartX + (col - 1) * (colorButtonSize + gridSpacing);
            yPos = gridStartY + (gridRows - row) * (colorButtonSize + gridSpacing);
            
            isSelected = strcmp(colorHex, selectedColorHex);
            
            colorBtn = uicontrol('Parent', dialogFig, 'Style', 'pushbutton', ...
                'Position', [xPos, yPos, colorButtonSize, colorButtonSize], ...
                'BackgroundColor', colorRGB, ...
                'Tag', 'colorButton', ...
                'UserData', colorHex, ...
                'String', '', ...
                'Callback', @(src,~) selectColorButton(src, dialogFig, colorHex));
            
            if isSelected
                set(colorBtn, 'String', '✓', 'ForegroundColor', [1 1 1], 'FontSize', 16, 'FontWeight', 'bold');
            end
        end
    end
    
    applyBtn = uicontrol('Parent', dialogFig, 'Style', 'pushbutton', ...
        'Position', [dialogWidth - 2*margin - 2*buttonWidth - 10, margin, buttonWidth, buttonHeight], ...
        'String', 'Apply', ...
        'Callback', @(src,~) applyColorEdit(src, fig, rowIndex));
    
    cancelBtn = uicontrol('Parent', dialogFig, 'Style', 'pushbutton', ...
        'Position', [dialogWidth - margin - buttonWidth, margin, buttonWidth, buttonHeight], ...
        'String', 'Cancel', ...
        'Callback', @(src,~) cancelColorEdit(src));
    
    set(dialogFig, 'UserData', selectedColorHex);
end

function selectColorButton(src, dialogFig, colorHex)
    colorButtons = findobj(dialogFig, 'Tag', 'colorButton');
    for i = 1:length(colorButtons)
        set(colorButtons(i), 'String', '', 'ForegroundColor', [0 0 0]);
    end
    set(src, 'String', '✓', 'ForegroundColor', [1 1 1], 'FontSize', 16, 'FontWeight', 'bold');
    set(dialogFig, 'UserData', colorHex);
end

function applyColorEdit(src, fig, rowIndex)
    dialogFig = ancestor(src, 'figure');
    selectedColorHex = get(dialogFig, 'UserData');
    
    if isempty(selectedColorHex)
        close(dialogFig);
        return
    end
    
    state = get(fig, 'UserData');
    if rowIndex >= 1 && rowIndex <= length(state.parameters)
        state.parameters{rowIndex}.color = selectedColorHex;
        set(fig, 'UserData', state);
        updateAnalysisColumnsDisplay(fig);
        updateFilteredDataStructure(fig);
    end
    
    close(dialogFig);
end

function cancelColorEdit(src)
    dialogFig = ancestor(src, 'figure');
    close(dialogFig);
end

function rgb = hex2rgb(hexColor)
    hexColor = strrep(hexColor, '#', '');
    r = hex2dec(hexColor(1:2)) / 255;
    g = hex2dec(hexColor(3:4)) / 255;
    b = hex2dec(hexColor(5:6)) / 255;
    rgb = [r, g, b];
end


function plotBoxplotCallback(fig)
    state = get(fig, 'UserData');
    if isempty(state.table)
        return
    end
    
    % Получение параметров из UI
    paramsTable = findobj(fig, 'Tag', 'paramsTable');
    showStatsCheck = findobj(fig, 'Tag', 'showStatsCheck');
    showAllPvaluesCheck = findobj(fig, 'Tag', 'showAllPvaluesCheck');
    showFileIdsCheck = findobj(fig, 'Tag', 'showFileIdsCheck');
    showYValuesCheck = findobj(fig, 'Tag', 'showYValuesCheck');
    showLegendCheck = findobj(fig, 'Tag', 'showLegendCheck');
    yAxisPopup = findobj(fig, 'Tag', 'yAxisPopup');
    yAxisMinEdit = findobj(fig, 'Tag', 'yAxisMinEdit');
    yAxisMaxEdit = findobj(fig, 'Tag', 'yAxisMaxEdit');
    xAxisPopup = findobj(fig, 'Tag', 'xAxisPopup');
    xAxisMinEdit = findobj(fig, 'Tag', 'xAxisMinEdit');
    xAxisMaxEdit = findobj(fig, 'Tag', 'xAxisMaxEdit');
    titleEdit = findobj(fig, 'Tag', 'titleEdit');
    plotModePopup = findobj(fig, 'Tag', 'plotModePopup');
    
    try
        % Определяем режим визуализации
        if ~isempty(plotModePopup)
            selectedValue = get(plotModePopup, 'Value');
            if selectedValue == 2
                state.plotMode = 'Correlation';
            elseif selectedValue == 3
                state.plotMode = 'Histogram';
            elseif selectedValue == 4
                state.plotMode = 'CountBars';
            else
                state.plotMode = 'BoxPlot';
            end
        end
        
        state.showStatistics = get(showStatsCheck, 'Value');
        state.showAllPvalues = get(showAllPvaluesCheck, 'Value');
        if ~isempty(showFileIdsCheck)
            state.showFileIds = get(showFileIdsCheck, 'Value');
        end
        if ~isempty(showYValuesCheck)
            state.showYValues = get(showYValuesCheck, 'Value');
        end
        if ~isempty(showLegendCheck)
            state.showLegend = get(showLegendCheck, 'Value');
        end
        if get(yAxisPopup, 'Value') == 1
            state.yAxisRange = 'auto';
        else
            state.yAxisRange = 'manual';
        end
        if strcmp(state.yAxisRange, 'manual')
            state.yAxisMin = str2double(get(yAxisMinEdit, 'String'));
            state.yAxisMax = str2double(get(yAxisMaxEdit, 'String'));
        end
        if get(xAxisPopup, 'Value') == 1
            state.xAxisRange = 'auto';
        else
            state.xAxisRange = 'manual';
        end
        if strcmp(state.xAxisRange, 'manual')
            state.xAxisMin = str2double(get(xAxisMinEdit, 'String'));
            state.xAxisMax = str2double(get(xAxisMaxEdit, 'String'));
        end
        state.title = get(titleEdit, 'String');
        
        set(fig, 'UserData', state);
        
        % Создаем прогресс-бар
        figPos = get(fig, 'Position');
        if strcmp(state.plotMode, 'Correlation')
            wbName = 'Correlation Plot Generation';
        elseif strcmp(state.plotMode, 'Histogram')
            wbName = 'Histogram Generation';
        elseif strcmp(state.plotMode, 'CountBars')
            wbName = 'Count Bars Generation';
        else
            wbName = 'Boxplot Generation';
        end
        wb = waitbar(0, 'Initializing...', ...
            'Name', wbName, ...
            'WindowStyle', 'modal');
        wbPos = get(wb, 'Position');
        % Центрируем относительно главного окна
        set(wb, 'Position', [figPos(1) + figPos(3)/2 - wbPos(3)/2, ...
                             figPos(2) + figPos(4)/2 - wbPos(4)/2, ...
                             wbPos(3), wbPos(4)]);
        
        try
            % Этап 1/3: Сохранение состояния
            waitbar(1/3, wb, 'Saving state...');
            saveBoxplotStateToGlobalSettings(fig);
            
            % Этап 2/3: Подготовка данных
            waitbar(2/3, wb, 'Preparing data...');
            updateFilteredDataStructure(fig);
            
            % Этап 3/3: Построение графика
            waitbar(3/3, wb, 'Creating plot...');
            state = get(fig, 'UserData');
            if strcmp(state.plotMode, 'Correlation')
                createCorrelationFigure(fig, state);
            elseif strcmp(state.plotMode, 'Histogram')
                createHistogramFigure(fig, state);
            elseif strcmp(state.plotMode, 'CountBars')
                createCountBarsFigure(fig, state);
            else
                createBoxplotFigure(fig, state);
            end
            
            % Закрываем прогресс-бар
            close(wb);
        catch ME
            % Закрываем прогресс-бар при ошибке
            if exist('wb', 'var') && isvalid(wb)
                close(wb);
            end
            showError(sprintf('Ошибка при построении графика: %s', ME.message));
            debugState('plotFromTableGUI', 'Error: %s', ME.message);
        end
        
    catch ME
        showError(sprintf('Ошибка при построении графика: %s', ME.message));
        debugState('plotFromTableGUI', 'Error: %s', ME.message);
    end
end

function exportPlotCallback(fig)
    % Экспорт текущего графика в различные форматы
    
    % Находим панель с графиками
    plotPanel = findobj(fig, 'Tag', 'plotPanel');
    if isempty(plotPanel)
        warningMsg = 'Сначала постройте график';
        fprintf('WARNING: %s\n', warningMsg);
        msgbox(warningMsg, 'Warning', 'warn');
        return
    end
    
    % Проверяем, есть ли axes в панели
    axesInPanel = findobj(plotPanel, 'Type', 'axes');
    if isempty(axesInPanel)
        warningMsg = 'Сначала постройте график';
        fprintf('WARNING: %s\n', warningMsg);
        msgbox(warningMsg, 'Warning', 'warn');
        return
    end
    
    % Диалог выбора формата и пути сохранения
    [file, path] = uiputfile(...
        {'*.png', 'PNG Image (*.png)'; ...
         '*.pdf', 'PDF Document (*.pdf)'; ...
         '*.fig', 'MATLAB Figure (*.fig)'; ...
         '*.eps', 'EPS File (*.eps)'}, ...
        'Export Plot', 'boxplot.png');
    
    if isequal(file, 0)
        return
    end
    
    filePath = fullfile(path, file);
    [~, ~, ext] = fileparts(file);
    
    try
        % Создаем временную фигуру для экспорта
        exportFig = figure('Visible', 'off');
        copyobj(axesInPanel, exportFig);
        
        switch lower(ext)
            case '.png'
                print(exportFig, '-dpng', '-r300', filePath);
            case '.pdf'
                print(exportFig, '-dpdf', '-r300', filePath);
            case '.fig'
                savefig(exportFig, filePath);
            case '.eps'
                print(exportFig, '-depsc', '-r300', filePath);
            otherwise
                showError('Неподдерживаемый формат файла');
                close(exportFig);
                return
        end
        
        close(exportFig);
        
        % Сохраняем состояние в .meta файл рядом с экспортированным графиком
        try
            [filePathDir, fileName, ~] = fileparts(filePath);
            metaFilePath = fullfile(filePathDir, [fileName, '.meta']);
            saveStateToFile(fig, metaFilePath);
        catch ME_meta
            % Игнорируем ошибки сохранения .meta файла, не прерываем экспорт
            warning('Failed to save state file: %s', ME_meta.message);
        end
    catch ME
        showError(sprintf('Ошибка при экспорте: %s', ME.message));
        debugState('plotFromTableGUI', 'Export error: %s', ME.message);
        if exist('exportFig', 'var') && isvalid(exportFig)
            close(exportFig);
        end
    end
end

function updateStatsVisibility(fig)
    showStatsCheck = findobj(fig, 'Tag', 'showStatsCheck');
    showAllPvaluesCheck = findobj(fig, 'Tag', 'showAllPvaluesCheck');
    enabled = get(showStatsCheck, 'Value');
    if enabled
        set(showAllPvaluesCheck, 'Enable', 'on');
    else
        set(showAllPvaluesCheck, 'Enable', 'off');
    end
end

function updateYAxisControls(fig)
    yAxisPopup = findobj(fig, 'Tag', 'yAxisPopup');
    yAxisMinEdit = findobj(fig, 'Tag', 'yAxisMinEdit');
    yAxisMaxEdit = findobj(fig, 'Tag', 'yAxisMaxEdit');
    
    isManual = get(yAxisPopup, 'Value') == 2;
    if isManual
        set(yAxisMinEdit, 'Visible', 'on');
        set(yAxisMaxEdit, 'Visible', 'on');
    else
        set(yAxisMinEdit, 'Visible', 'off');
        set(yAxisMaxEdit, 'Visible', 'off');
    end
end

function updateXAxisControls(fig)
    xAxisPopup = findobj(fig, 'Tag', 'xAxisPopup');
    xAxisMinEdit = findobj(fig, 'Tag', 'xAxisMinEdit');
    xAxisMaxEdit = findobj(fig, 'Tag', 'xAxisMaxEdit');
    
    isManual = get(xAxisPopup, 'Value') == 2;
    if isManual
        set(xAxisMinEdit, 'Visible', 'on');
        set(xAxisMaxEdit, 'Visible', 'on');
    else
        set(xAxisMinEdit, 'Visible', 'off');
        set(xAxisMaxEdit, 'Visible', 'off');
    end
end

function initialPath = getBoxplotInitialPath()
    % Получает начальную папку из глобальных настроек boxplot_state.filePath
    global SettingsFilepath
    initialPath = pwd;
    
    if exist(SettingsFilepath, 'file')
        try
            data = load(SettingsFilepath);
            if isfield(data, 'boxplot_state') && isfield(data.boxplot_state, 'filePath')
                savedFilePath = data.boxplot_state.filePath;
                if ~isempty(savedFilePath) && exist(savedFilePath, 'file')
                    [initialPath, ~, ~] = fileparts(savedFilePath);
                end
            end
        catch
            % Игнорируем ошибки загрузки настроек
        end
    end
end

function saveBoxplotStateToGlobalSettings(fig)
    global SettingsFilepath
    state = get(fig, 'UserData');
    
    % Используем общую функцию для создания структуры состояния
    boxplot_state = createSavedStateFromState(state);
    
    % Сохраняем в глобальные настройки
    try
        if exist(SettingsFilepath, 'file')
            save(SettingsFilepath, 'boxplot_state', '-append');
        else
            save(SettingsFilepath, 'boxplot_state');
        end
    catch ME
        warning('Failed to save boxplot state to global settings: %s', ME.message);
    end
end

function loadBoxplotStateFromGlobalSettings(fig)
    global SettingsFilepath auto_open_last_file
    state = get(fig, 'UserData');
    
    % Проверяем, включено ли автоматическое открытие файлов
    if ~exist('auto_open_last_file', 'var') || ~auto_open_last_file
        return
    end
    
    if ~exist(SettingsFilepath, 'file')
        return
    end
    
    try
        data = load(SettingsFilepath);
        
        if ~isfield(data, 'boxplot_state')
            return
        end
        
        savedState = data.boxplot_state;
        
        % Используем общую функцию для загрузки состояния
        % metaFilePath пустой, так как файл данных ищется по исходному пути
        loadStateFromSavedState(fig, savedState, []);
    catch ME
        warning('Failed to load boxplot state from global settings: %s', ME.message);
    end
end

function updateUIFromState(fig)
    state = get(fig, 'UserData');
    
    % Обновляем чекбоксы и поля
    showStatsCheck = findobj(fig, 'Tag', 'showStatsCheck');
    if ~isempty(showStatsCheck)
        set(showStatsCheck, 'Value', state.showStatistics);
    end
    
    showAllPvaluesCheck = findobj(fig, 'Tag', 'showAllPvaluesCheck');
    if ~isempty(showAllPvaluesCheck)
        set(showAllPvaluesCheck, 'Value', state.showAllPvalues);
    end
    
    showFileIdsCheck = findobj(fig, 'Tag', 'showFileIdsCheck');
    if ~isempty(showFileIdsCheck)
        set(showFileIdsCheck, 'Value', state.showFileIds);
    end
    
    showYValuesCheck = findobj(fig, 'Tag', 'showYValuesCheck');
    if ~isempty(showYValuesCheck)
        set(showYValuesCheck, 'Value', state.showYValues);
    end
    
    showLegendCheck = findobj(fig, 'Tag', 'showLegendCheck');
    if ~isempty(showLegendCheck)
        set(showLegendCheck, 'Value', state.showLegend);
    end
    
    yAxisPopup = findobj(fig, 'Tag', 'yAxisPopup');
    if ~isempty(yAxisPopup)
        if strcmp(state.yAxisRange, 'auto')
            set(yAxisPopup, 'Value', 1);
        else
            set(yAxisPopup, 'Value', 2);
        end
    end
    
    yAxisMinEdit = findobj(fig, 'Tag', 'yAxisMinEdit');
    if ~isempty(yAxisMinEdit) && ~isempty(state.yAxisMin)
        set(yAxisMinEdit, 'String', num2str(state.yAxisMin));
    end
    
    yAxisMaxEdit = findobj(fig, 'Tag', 'yAxisMaxEdit');
    if ~isempty(yAxisMaxEdit) && ~isempty(state.yAxisMax)
        set(yAxisMaxEdit, 'String', num2str(state.yAxisMax));
    end
    
    xAxisPopup = findobj(fig, 'Tag', 'xAxisPopup');
    if ~isempty(xAxisPopup)
        if isfield(state, 'xAxisRange') && strcmp(state.xAxisRange, 'auto')
            set(xAxisPopup, 'Value', 1);
        elseif isfield(state, 'xAxisRange')
            set(xAxisPopup, 'Value', 2);
        end
    end
    
    xAxisMinEdit = findobj(fig, 'Tag', 'xAxisMinEdit');
    if ~isempty(xAxisMinEdit) && isfield(state, 'xAxisMin') && ~isempty(state.xAxisMin)
        set(xAxisMinEdit, 'String', num2str(state.xAxisMin));
    end
    
    xAxisMaxEdit = findobj(fig, 'Tag', 'xAxisMaxEdit');
    if ~isempty(xAxisMaxEdit) && isfield(state, 'xAxisMax') && ~isempty(state.xAxisMax)
        set(xAxisMaxEdit, 'String', num2str(state.xAxisMax));
    end
    
    titleEdit = findobj(fig, 'Tag', 'titleEdit');
    if ~isempty(titleEdit) && ~isempty(state.title)
        set(titleEdit, 'String', state.title);
    end
    
    % Обновляем выпадающий список режима
    plotModePopup = findobj(fig, 'Tag', 'plotModePopup');
    if ~isempty(plotModePopup)
        if isfield(state, 'plotMode')
            if strcmp(state.plotMode, 'Correlation')
                set(plotModePopup, 'Value', 2);
            elseif strcmp(state.plotMode, 'Histogram')
                set(plotModePopup, 'Value', 3);
            elseif strcmp(state.plotMode, 'CountBars')
                set(plotModePopup, 'Value', 4);
            else
                set(plotModePopup, 'Value', 1);
            end
        end
    end
    
    updateYAxisControls(fig);
    updateXAxisControls(fig);
    updateAnalysisColumnsDisplay(fig);
end

% ============================================================================
% Вспомогательные функции парсинга и обработки данных
% ============================================================================

function tableOut = convertTableColumns(tableIn)
    % convertTableColumns - Конвертация таблицы: определение типов колонок,
    % конвертация числовых cell-массивов в числовой формат и замена пустых ячеек на NaN
    % 
    % Входные параметры:
    %   tableIn - исходная таблица
    %
    % Выходные параметры:
    %   tableOut - таблица с конвертированными колонками
    
    varNames = tableIn.Properties.VariableNames;
    newTableData = cell(1, length(varNames));
    
    for i = 1:length(varNames)
        colName = varNames{i};
        columnData = tableIn{:, colName};
        
        if iscell(columnData) && ~isempty(columnData)
            if isNumericCellArray(columnData)
                % Числовой cell-массив: заменяем пустые ячейки на NaN и конвертируем
                for j = 1:length(columnData)
                    if isempty(columnData{j})
                        columnData{j} = NaN;
                    end
                end
                try
                    % Конвертируем cell-массив в числовой формат
                    numericData = nan(length(columnData), 1);
                    for j = 1:length(columnData)
                        value = columnData{j};
                        if isnumeric(value) && isscalar(value)
                            numericData(j) = double(value);
                        elseif islogical(value) && isscalar(value)
                            numericData(j) = double(value);
                        elseif ischar(value) || isstring(value)
                            numericData(j) = str2double(value);
                        elseif isempty(value)
                            numericData(j) = NaN;
                        end
                    end
                    newTableData{i} = numericData;
                catch
                    % Если конвертация не удалась, оставляем как есть
                    newTableData{i} = columnData;
                end
            else
                % Текстовой cell-массив: оставляем как есть
                newTableData{i} = columnData;
            end
        else
            % Уже не cell-массив: оставляем как есть
            newTableData{i} = columnData;
        end
    end
    
    % Создаем новую таблицу с правильными типами колонок, сохраняя порядок
    tableOut = table(newTableData{:}, 'VariableNames', varNames);
end

function updateFilteredDataStructure(fig)
    % updateFilteredDataStructure - Обновление структуры с отфильтрованными данными
    % Собирает структуру из оригинальной таблицы после применения фильтров
    % для каждого параметра. Использует индексы для уникальности ключей.
    
    state = get(fig, 'UserData');
    if isempty(state.table) || isempty(state.parameters)
        state.filteredData = struct();
        state.parameterToFieldName = {};
        set(fig, 'UserData', state);
        return
    end
    
    state.filteredData = struct();
    state.parameterToFieldName = cell(1, length(state.parameters));
    
    columnIndices = containers.Map();
    
    for i = 1:length(state.parameters)
        paramStruct = state.parameters{i};
        if isfield(paramStruct, 'visible') && ~paramStruct.visible
            continue
        end
        columnName = paramStruct.column;
        if ~ismember(columnName, state.table.Properties.VariableNames)
            continue
        end
        
        % Определяем уникальный ключ
        if isKey(columnIndices, columnName)
            index = columnIndices(columnName);
            columnIndices(columnName) = index + 1;
            fieldName = sprintf('%s_%d', columnName, index);
        else
            columnIndices(columnName) = 1;
            fieldName = columnName;
        end
        
        % Применяем фильтр
        filterStr = paramStruct.filter;
        if isempty(filterStr)
            filterStr = '';
        end
        
        % Получаем отфильтрованную таблицу
        filteredTable = [];
        if ~isempty(filterStr)
            parsedFilters = boxplotParseGroupFilters(filterStr);
            if ~isempty(parsedFilters)
                filteredTable = boxplotApplyGroupFilters(state.table, parsedFilters);
            end
        else
            % Нет фильтра - используем все данные
            filteredTable = state.table;
        end
        
        if isempty(filteredTable) || ~ismember(columnName, filteredTable.Properties.VariableNames)
            continue
        end
        
        % Парсим цвет один раз и сохраняем RGB
        parsedColor = [0.5 0.5 0.5]; % серый по умолчанию
        if ~isempty(paramStruct.color)
            colorStr = strtrim(paramStruct.color);
            if ~isempty(colorStr)
                try
                    if strncmp(colorStr, '#', 1)
                        % Формат #RRGGBB
                        r = hex2dec(colorStr(2:3)) / 255;
                        g = hex2dec(colorStr(4:5)) / 255;
                        b = hex2dec(colorStr(6:7)) / 255;
                        parsedColor = [r, g, b];
                    else
                        % Пробуем как RGB значения
                        rgb = str2num(colorStr);
                        if length(rgb) == 3 && all(rgb >= 0) && all(rgb <= 1)
                            parsedColor = rgb;
                        elseif length(rgb) == 3 && all(rgb >= 0) && all(rgb <= 255)
                            parsedColor = rgb / 255;
                        end
                    end
                catch
                    % Игнорируем ошибки парсинга цвета
                end
            end
        end
        
        if isfield(paramStruct, 'groupName')
            gn = paramStruct.groupName;
        elseif isfield(paramStruct, 'groupNumber')
            gn = num2str(paramStruct.groupNumber);
        else
            gn = '1';
        end
        if isempty(gn)
            gn = '1';
        end
        
        % Проверяем наличие разбиения по диапазонам
        rangesStr = '';
        if isfield(paramStruct, 'ranges')
            rangesStr = paramStruct.ranges;
        end
        if isempty(rangesStr)
            rangesStr = '';
        end
        
        % Парсим диапазоны
        parsedRanges = boxplotParseRanges(rangesStr);
        
        % Если диапазоны не указаны или парсинг не удался, работаем как раньше
        if isempty(parsedRanges) || isempty(parsedRanges.columnName) || isempty(parsedRanges.ranges)
            % Обычная обработка без разбиения по диапазонам
            columnData = filteredTable{:, columnName};
            if isnumeric(columnData)
                filteredData = double(columnData);
            else
                filteredData = [];
            end
            
            % Извлекаем File ID
            fileIds = [];
            if ismember('FileID', filteredTable.Properties.VariableNames)
                fileIds = filteredTable{:, 'FileID'};
            end
            
            % Рассчитываем статистику для отфильтрованных данных
            stats = statProc(filteredData);
            
            validFieldName = matlab.lang.makeValidName(fieldName);
            state.parameterToFieldName{i} = validFieldName;
            state.filteredData.(validFieldName) = struct(...
                'data', filteredData, ...
                'column', columnName, ...
                'label', paramStruct.label, ...
                'color', paramStruct.color, ...
                'parsedColor', parsedColor, ...
                'lineWidth', paramStruct.lineWidth, ...
                'groupName', gn, ...
                'filter', filterStr, ...
                'fieldName', validFieldName, ...
                'stats', stats, ...
                'fileIds', fileIds);
            
            % Выводим превью в консоль
            filterDisplay = filterStr;
            if isempty(filterDisplay)
                filterDisplay = '';
            end
            fprintf('%s: filter: ''%s'', size: %d, median: %.3f, std: %.3f\n', ...
                fieldName, filterDisplay, stats.count, stats.median, stats.std);
        else
            % Разбиение по диапазонам
            state = applyRangesSplit(state, i, fieldName, columnName, paramStruct, parsedColor, gn, filterStr, parsedRanges, filteredTable);
        end
    end
    
    set(fig, 'UserData', state);
end
