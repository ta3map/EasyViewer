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
        'ColumnName', {'Show', 'Group', 'Column', 'Filter', 'Label', 'Color', 'LineWidth'}, ...
        'ColumnEditable', [true, true, true, true, true, true, true], ...
        'ColumnFormat', {'logical', 'char', 'char', 'char', 'char', 'char', 'numeric'}, ...
        'ColumnWidth', {40, 70, 100, 80, 80, 70, 70}, ...
        'Data', cell(0, 7), ...
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
        'String', {'BoxPlot', 'Correlation', 'Histogram'}, ...
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
            state.parameters{end+1} = struct('column', colName, 'groupName', '1', 'filter', '', 'label', colName, 'color', colorHex, 'lineWidth', 1, 'visible', true);
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
        set(paramsTable, 'Data', cell(0, 7));
        return
    end
    
    tableData = cell(length(state.parameters), 7);
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
        tableData{i, 5} = v.label;
        tableData{i, 6} = v.color;
        tableData{i, 7} = v.lineWidth;
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
            state.parameters{i}.label = char(tableData{i, 5});
        end
        if ischar(tableData{i, 6}) || isstring(tableData{i, 6})
            state.parameters{i}.color = char(tableData{i, 6});
        end
        if isnumeric(tableData{i, 7}) && tableData{i, 7} > 0
            state.parameters{i}.lineWidth = tableData{i, 7};
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
        
        filteredData = [];
        fileIds = [];
        if ~isempty(filterStr)
            parsedFilters = boxplotParseGroupFilters(filterStr);
            if ~isempty(parsedFilters)
                filteredTable = boxplotApplyGroupFilters(state.table, parsedFilters);
                if ~isempty(filteredTable) && ismember(columnName, filteredTable.Properties.VariableNames)
                    columnData = filteredTable{:, columnName};
                    if isnumeric(columnData)
                        filteredData = double(columnData);
                    else
                        filteredData = [];
                    end
                    % Извлекаем File ID
                    if ismember('FileID', filteredTable.Properties.VariableNames)
                        fileIds = filteredTable{:, 'FileID'};
                    end
                end
            end
        else
            % Нет фильтра - используем все данные
            columnData = state.table{:, columnName};
            if isnumeric(columnData)
                filteredData = double(columnData);
            else
                filteredData = [];
            end
            % Извлекаем File ID
            if ismember('FileID', state.table.Properties.VariableNames)
                fileIds = state.table{:, 'FileID'};
            end
        end
        
        % Рассчитываем статистику для отфильтрованных данных
        stats = calculateVectorStatistics(filteredData);
        
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
    end
    
    set(fig, 'UserData', state);
end

function createCorrelationFigure(fig, state)
    % Построение корреляционных графиков
    % Группирует параметры по одинаковому фильтру и строит пары
    
    % Находим панель для графиков
    plotPanel = findobj(fig, 'Tag', 'plotPanel');
    
    % Очищаем содержимое панели
    delete(plotPanel.Children);
    
    % Проверяем наличие структуры с данными
    if isempty(state.filteredData) || isempty(fieldnames(state.filteredData))
        return
    end
    
    % Получаем все поля из структуры filteredData
    filteredDataFields = fieldnames(state.filteredData);
    
    groupNames = {};
    for i = 1:length(filteredDataFields)
        fieldName = filteredDataFields{i};
        paramData = state.filteredData.(fieldName);
        if isstruct(paramData) && isfield(paramData, 'groupName')
            groupNames{end+1} = paramData.groupName;
        else
            groupNames{end+1} = '1';
        end
    end
    uniqueGroupNames = unique(groupNames, 'stable');
    nPlotGroups = length(uniqueGroupNames);
    
    if nPlotGroups == 0
        return
    end
    
    t = tiledlayout(plotPanel, nPlotGroups, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    
    for plotGroupIdx = 1:nPlotGroups
        groupName = uniqueGroupNames{plotGroupIdx};
        
        paramsInGroup = {};
        for i = 1:length(filteredDataFields)
            fieldName = filteredDataFields{i};
            paramData = state.filteredData.(fieldName);
            if isstruct(paramData) && isfield(paramData, 'groupName') && strcmp(paramData.groupName, groupName)
                paramData.fieldName = fieldName;
                paramsInGroup{end+1} = paramData;
            end
        end
        
        if isempty(paramsInGroup)
            continue
        end
        
        % Создаем ось для этой группы
        ax = nexttile(t);
        hold(ax, 'on');
        
        % Группируем параметры внутри группы по фильтру
        filterGroups = containers.Map();
        for i = 1:length(paramsInGroup)
            paramData = paramsInGroup{i};
            filterKey = paramData.filter;
            if isempty(filterKey)
                filterKey = '';
            end
            
            if ~isKey(filterGroups, filterKey)
                filterGroups(filterKey) = {};
            end
            filterGroups(filterKey) = [filterGroups(filterKey), {paramData}];
        end
        
        filterKeys = keys(filterGroups);
        
        % Собираем уникальные Label для X и Y осей
        uniqueXLabels = {};
        uniqueYLabels = {};
        
        % Массивы для легенды
        legendHandles = {};
        legendLabels = {};
        
        % Обрабатываем каждую группу фильтров внутри этой группы
        for filterIdx = 1:length(filterKeys)
            filterKey = filterKeys{filterIdx};
            paramsInFilter = filterGroups(filterKey);
            
            % Формируем пары по порядку следования
            numParams = length(paramsInFilter);
            numPairs = floor(numParams / 2);
            
            % Строим пары на том же axes
            for pairIdx = 1:numPairs
                param1 = paramsInFilter{2*pairIdx - 1};
                param2 = paramsInFilter{2*pairIdx};
                
                % Собираем Label для X-оси (из param1)
                label1 = param1.label;
                if isempty(label1)
                    label1 = param1.column;
                end
                if ~ismember(label1, uniqueXLabels)
                    uniqueXLabels{end+1} = label1;
                end
                
                % Собираем Label для Y-оси (из param2)
                label2 = param2.label;
                if isempty(label2)
                    label2 = param2.column;
                end
                if ~ismember(label2, uniqueYLabels)
                    uniqueYLabels{end+1} = label2;
                end
                
                if isempty(param1.data) || isempty(param2.data)
                    continue
                end
            
            % Получаем данные из исходной таблицы с одинаковым фильтром
            % Если фильтр одинаковый, данные должны быть синхронизированы по строкам
            filterStr = param1.filter;
            if isempty(filterStr)
                filterStr = '';
            end
            
            % Применяем фильтр к исходной таблице один раз
            if ~isempty(filterStr)
                parsedFilters = boxplotParseGroupFilters(filterStr);
                if ~isempty(parsedFilters)
                    filteredTable = boxplotApplyGroupFilters(state.table, parsedFilters);
                else
                    filteredTable = state.table;
                end
            else
                filteredTable = state.table;
            end
            
            if isempty(filteredTable) || ...
               ~ismember(param1.column, filteredTable.Properties.VariableNames) || ...
               ~ismember(param2.column, filteredTable.Properties.VariableNames)
                continue
            end
            
            % Получаем данные из отфильтрованной таблицы
            xColumnData = filteredTable{:, param1.column};
            yColumnData = filteredTable{:, param2.column};
            if isnumeric(xColumnData)
                xData = double(xColumnData);
            else
                xData = [];
            end
            if isnumeric(yColumnData)
                yData = double(yColumnData);
            else
                yData = [];
            end
            
            % Получаем FileID если доступен
            fileIds = [];
            if ismember('FileID', filteredTable.Properties.VariableNames)
                fileIds = filteredTable{:, 'FileID'};
            end
            
            % Фильтруем NaN значения для синхронизации данных
            if ~isempty(xData) && ~isempty(yData)
                validMask = ~isnan(xData) & ~isnan(yData) & ~isinf(xData) & ~isinf(yData);
                xData = xData(validMask);
                yData = yData(validMask);
                if ~isempty(fileIds) && length(fileIds) == length(validMask)
                    fileIds = fileIds(validMask);
                end
            end
            
            if length(xData) < 2
                continue
            end
            
            % Получаем цвет X параметра
            pointColor = param1.parsedColor;
            lineColor = param1.parsedColor;
            
            % Scatter plot
            hScatter = scatter(ax, xData, yData, 50, pointColor, 'o', ...
                'MarkerFaceColor', pointColor, ...
                'MarkerEdgeColor', 'white', ...
                'LineWidth', 1, ...
                'MarkerFaceAlpha', 0.7);
            
            % Отображение File ID рядом с точками (если включено)
            if state.showFileIds && ~isempty(fileIds)
                plotFileIdsOnAxes(ax, xData, yData, fileIds, -0.01, 0.01);
            end
            
            % Отображение значений Y рядом с точками (если включено)
            if state.showYValues
                plotYValuesOnAxes(ax, xData, yData, yData, 0.01, 0.01, '(%.3f,%.3f)');
            end
            
            % Добавляем в легенду (только точки, цвет определяется по X параметру)
            pairLabel = sprintf('%s vs %s', label1, label2);
            legendHandles{end+1} = hScatter;
            legendLabels{end+1} = pairLabel;
            
            % Линия регрессии и статистика (только если showStatistics включен)
            if state.showStatistics
                % Вычисление корреляции
                R = corrcoef(xData, yData);
                if size(R, 1) == 2 && size(R, 2) == 2
                    corrCoeff = R(1, 2);
                    R2 = corrCoeff^2;
                else
                    corrCoeff = NaN;
                    R2 = NaN;
                end
                
                % Статистика регрессии для p-value
                pValue = NaN;
                if length(xData) >= 2
                    try
                        [b, bint, r, rint, stats] = regress(yData, [ones(length(xData), 1), xData]);
                        if length(stats) >= 3
                            pValue = stats(3);
                        end
                    catch
                        % Игнорируем ошибки регрессии
                    end
                end
                
                % Линия регрессии
                p = polyfit(xData, yData, 1);
                xFit = linspace(min(xData), max(xData), 100);
                yFit = polyval(p, xFit);
                plot(ax, xFit, yFit, 'Color', lineColor, 'LineWidth', 2, 'LineStyle', '--');
                
                % Отображение статистики рядом с линией регрессии
                if ~isnan(R2) && ~isnan(pValue)
                % Позиция текста - на середине линии регрессии
                xPos = (min(xData) + max(xData)) / 2;
                yPos = polyval(p, xPos);
                
                if state.showAllPvalues
                    statsText = sprintf('R²=%.3f, p=%.4f, n=%d', R2, pValue, length(xData));
                else
                    if pValue < 0.05
                        statsText = sprintf('R²=%.3f, p=%.4f*, n=%d', R2, pValue, length(xData));
                    else
                        statsText = sprintf('R²=%.3f, n=%d', R2, length(xData));
                    end
                end
                
                text(ax, xPos, yPos, statsText, ...
                    'HorizontalAlignment', 'center', ...
                    'VerticalAlignment', 'middle', ...
                    'FontSize', 9, ...
                    'BackgroundColor', 'white', ...
                    'EdgeColor', lineColor, ...
                    'LineWidth', 1, ...
                    'Interpreter', 'none');
                end
            end
            
        end
        
        % Если нечетное количество параметров, показываем последний отдельно на том же axes
        if mod(numParams, 2) == 1
            param = paramsInFilter{end};
            
            % Собираем Label для одиночного параметра (добавляем в X и Y)
            label = param.label;
            if isempty(label)
                label = param.column;
            end
            if ~ismember(label, uniqueXLabels)
                uniqueXLabels{end+1} = label;
            end
            if ~ismember(label, uniqueYLabels)
                uniqueYLabels{end+1} = label;
            end
            
            if ~isempty(param.data)
                data = param.data;
                
                if length(data) > 0
                    % Получаем fileIds из структуры paramData или из filteredTable
                    fileIds = [];
                    if isfield(param, 'fileIds') && ~isempty(param.fileIds) && length(param.fileIds) == length(data)
                        fileIds = param.fileIds;
                    else
                        % Если fileIds нет в структуре, получаем из filteredTable
                        filterStr = param.filter;
                        if isempty(filterStr)
                            filterStr = '';
                        end
                        
                        if ~isempty(filterStr)
                            parsedFilters = boxplotParseGroupFilters(filterStr);
                            if ~isempty(parsedFilters)
                                filteredTable = boxplotApplyGroupFilters(state.table, parsedFilters);
                            else
                                filteredTable = state.table;
                            end
                        else
                            filteredTable = state.table;
                        end
                        
                        if ~isempty(filteredTable) && ismember('FileID', filteredTable.Properties.VariableNames) && ismember(param.column, filteredTable.Properties.VariableNames)
                            columnData = filteredTable{:, param.column};
                            if isnumeric(columnData)
                                columnData = double(columnData);
                                validMask = ~isnan(columnData) & ~isinf(columnData);
                                fileIds = filteredTable{:, 'FileID'};
                                fileIds = fileIds(validMask);
                            end
                        end
                    end
                    
                    % Простой scatter plot по индексам на том же axes
                    xData = 1:length(data);
                    hScatterSingle = scatter(ax, xData, data, 50, param.parsedColor, 'o', ...
                        'MarkerFaceColor', param.parsedColor, ...
                        'MarkerEdgeColor', 'white', ...
                        'LineWidth', 1, ...
                        'MarkerFaceAlpha', 0.7);
                    
                    % Отображение File ID рядом с точками (если включено)
                    if state.showFileIds && ~isempty(fileIds) && length(fileIds) == length(data)
                        plotFileIdsOnAxes(ax, xData, data, fileIds, -0.01, 0.01);
                    end
                    
                    % Отображение значений Y рядом с точками (если включено)
                    if state.showYValues
                        plotYValuesOnAxes(ax, xData, data, data, 0.01, 0.01, '%.3f');
                    end
                    
                    % Добавляем в легенду
                    legendHandles{end+1} = hScatterSingle;
                    legendLabels{end+1} = label;
                end
            end
        end
        end
        
        % Добавляем легенду
        if state.showLegend && ~isempty(legendHandles)
            legend(ax, [legendHandles{:}], legendLabels, 'Location', 'best', 'Interpreter', 'none');
        end
        
        % Настройка диапазонов осей (после всех графиков на axes)
        if strcmp(state.yAxisRange, 'manual') && ~isempty(state.yAxisMin) && ~isempty(state.yAxisMax)
            ylim(ax, [state.yAxisMin, state.yAxisMax]);
        elseif strcmp(state.yAxisRange, 'auto')
            % Автоматический расчет пределов по всем данным на axes
            yLimits = ylim(ax);
            if ~isinf(yLimits(1)) && ~isinf(yLimits(2))
                ylim(ax, yLimits);
            end
        end
        
        if strcmp(state.xAxisRange, 'manual') && ~isempty(state.xAxisMin) && ~isempty(state.xAxisMax)
            xlim(ax, [state.xAxisMin, state.xAxisMax]);
        elseif strcmp(state.xAxisRange, 'auto')
            % Автоматический расчет пределов по всем данным на axes
            xLimits = xlim(ax);
            if ~isinf(xLimits(1)) && ~isinf(xLimits(2))
                xlim(ax, xLimits);
            end
        end
        
        % Подписи осей для группы (после обработки всех фильтров)
        % Используем уникальные Label
        if ~isempty(uniqueXLabels)
            xLabelText = strjoin(uniqueXLabels, ', ');
            xlabel(ax, xLabelText, 'Interpreter', 'none');
        else
            lbl = groupName;
            if isempty(lbl)
                lbl = '(no name)';
            end
            xlabel(ax, lbl, 'Interpreter', 'none');
        end
        
        if ~isempty(uniqueYLabels)
            yLabelText = strjoin(uniqueYLabels, ', ');
            ylabel(ax, yLabelText, 'Interpreter', 'none');
        else
            lbl = groupName;
            if isempty(lbl)
                lbl = '(no name)';
            end
            ylabel(ax, lbl, 'Interpreter', 'none');
        end
        
        % Сетка
        grid(ax, 'on');
    end
    
    % Добавляем общий заголовок через tiledlayout
    if nPlotGroups > 0
        title(t, state.title, 'FontSize', 14, 'FontWeight', 'bold', 'Interpreter', 'none');
        zoom(fig, 'on');
        pan(fig, 'on');
    end
end

function createHistogramFigure(fig, state)
    % Построение гистограмм
    % Группирует данные по groupName из параметров анализа (как в boxplot)
    
    % Находим панель для графиков
    plotPanel = findobj(fig, 'Tag', 'plotPanel');
    
    % Очищаем содержимое панели
    delete(plotPanel.Children);
    
    % Проверяем наличие структуры с данными
    if isempty(state.filteredData) || isempty(fieldnames(state.filteredData))
        return
    end
    
    % Проверяем наличие колонки Group в исходной таблице (для группировки данных внутри параметра)
    if ~ismember('Group', state.table.Properties.VariableNames)
        % Если нет колонки Group, просто строим гистограммы без группировки
        useGroupColumn = false;
    else
        useGroupColumn = true;
    end
    
    % Получаем все поля из структуры filteredData
    filteredDataFields = fieldnames(state.filteredData);
    
    groupNames = {};
    for i = 1:length(filteredDataFields)
        fieldName = filteredDataFields{i};
        paramData = state.filteredData.(fieldName);
        if isstruct(paramData) && isfield(paramData, 'groupName')
            groupNames{end+1} = paramData.groupName;
        else
            groupNames{end+1} = '1';
        end
    end
    uniqueGroupNames = unique(groupNames, 'stable');
    nPlotGroups = length(uniqueGroupNames);
    
    t = tiledlayout(plotPanel, nPlotGroups, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    
    for plotGroupIdx = 1:nPlotGroups
        groupName = uniqueGroupNames{plotGroupIdx};
        
        paramsInGroup = {};
        for i = 1:length(filteredDataFields)
            fieldName = filteredDataFields{i};
            paramData = state.filteredData.(fieldName);
            if isstruct(paramData) && isfield(paramData, 'groupName') && strcmp(paramData.groupName, groupName)
                paramData.fieldName = fieldName;
                paramsInGroup{end+1} = paramData;
            end
        end
        
        if isempty(paramsInGroup)
            continue
        end
        
        % Создаем ось через nexttile (tiledlayout автоматически управляет позицией)
        ax = nexttile(t);
        hold(ax, 'on');
        
        % Для каждого параметра в группе получаем данные, группируя по колонке Group из таблицы
        paramGroups = {};
        
        for p = 1:length(paramsInGroup)
            paramData = paramsInGroup{p};
            
            if isempty(paramData.data)
                continue
            end
            
            % Получаем фильтр для этого параметра
            filterStr = paramData.filter;
            if isempty(filterStr)
                filterStr = '';
            end
            
            % Применяем фильтр к исходной таблице
            if ~isempty(filterStr)
                parsedFilters = boxplotParseGroupFilters(filterStr);
                if ~isempty(parsedFilters)
                    filteredTable = boxplotApplyGroupFilters(state.table, parsedFilters);
                else
                    filteredTable = state.table;
                end
            else
                filteredTable = state.table;
            end
            
            if isempty(filteredTable) || ~ismember(paramData.column, filteredTable.Properties.VariableNames)
                continue
            end
            
            if useGroupColumn && ismember('Group', filteredTable.Properties.VariableNames)
                % Группируем данные по колонке Group из таблицы
                rawColumnData = filteredTable{:, paramData.column};
                if isnumeric(rawColumnData)
                    columnData = double(rawColumnData);
                else
                    columnData = [];
                end
                groupData = filteredTable{:, 'Group'};
                
                if isempty(columnData)
                    continue
                end
                
                % Группируем данные по Group
                uniqueGroups = unique(groupData);
                for g = 1:length(uniqueGroups)
                    groupValue = uniqueGroups(g);
                    groupMask = groupData == groupValue;
                    groupColumnData = columnData(groupMask);
                    
                    if isempty(groupColumnData)
                        continue
                    end
                    
                    paramGroup = struct();
                    paramGroup.data = groupColumnData;
                    paramGroup.column = paramData.column;
                    paramGroup.label = paramData.label;
                    paramGroup.parsedColor = paramData.parsedColor;
                    paramGroup.lineWidth = paramData.lineWidth;
                    paramGroup.groupValue = groupValue;
                    paramGroup.fieldName = paramData.fieldName;
                    paramGroups{end+1} = paramGroup;
                end
            else
                % Нет колонки Group - используем данные напрямую
                paramGroup = struct();
                paramGroup.data = paramData.data;
                paramGroup.column = paramData.column;
                paramGroup.label = paramData.label;
                paramGroup.parsedColor = paramData.parsedColor;
                paramGroup.lineWidth = paramData.lineWidth;
                paramGroup.groupValue = '';
                paramGroup.fieldName = paramData.fieldName;
                paramGroups{end+1} = paramGroup;
            end
        end
        
        if isempty(paramGroups)
            delete(ax);
            continue
        end
        
        % Собираем все данные для определения общего диапазона бинов
        allData = [];
        for g = 1:length(paramGroups)
            allData = [allData; paramGroups{g}.data];
        end
        
        if isempty(allData)
            delete(ax);
            continue
        end
        
        % Определяем диапазон и количество бинов
        if strcmp(state.xAxisRange, 'manual') && ~isempty(state.xAxisMin) && ~isempty(state.xAxisMax)
            % Если X-ось в manual режиме, используем лимиты X
            dataMin = state.xAxisMin;
            dataMax = state.xAxisMax;
            
            % Вычисляем количество бинов, кратное 10
            range = dataMax - dataMin;
            nBins = round(range);
            % Округляем до ближайшего кратного 10
            nBins = round(nBins / 10) * 10;
            if nBins < 10
                nBins = 10;
            end
        else
            % Автоматический режим: используем правило Стёрджеса
            n = length(allData);
            nBins = ceil(1 + log2(n));
            if nBins < 10
                nBins = 10;
            elseif nBins > 50
                nBins = 50;
            end
            
            % Определяем диапазон для бинов из данных
            dataMin = min(allData);
            dataMax = max(allData);
            if dataMin == dataMax
                if dataMin == 0
                    dataMin = -0.1;
                    dataMax = 0.1;
                else
                    offset = abs(dataMin) * 0.01;
                    dataMin = dataMin - offset;
                    dataMax = dataMax + offset;
                end
            end
        end
        
        binEdges = linspace(dataMin, dataMax, nBins + 1);
        
        % Строим гистограммы для каждой группы
        for g = 1:length(paramGroups)
            paramGroup = paramGroups{g};
            data = paramGroup.data;
            color = paramGroup.parsedColor;
            
            % Вычисляем гистограмму
            counts = histcounts(data, binEdges);
            binCenters = (binEdges(1:end-1) + binEdges(2:end)) / 2;
            
            % Строим столбцы гистограммы
            bar(ax, binCenters, counts, 'FaceColor', color, 'EdgeColor', color * 0.7, ...
                'FaceAlpha', 0.6, 'BarWidth', 0.8);
        end
        
        % Подписи осей
        if length(paramsInGroup) == 1
            label = paramsInGroup{1}.label;
            if isempty(label)
                label = paramsInGroup{1}.column;
            end
            xlabel(ax, label, 'Interpreter', 'none');
        else
            lbl = groupName;
            if isempty(lbl)
                lbl = '(no name)';
            end
            xlabel(ax, lbl, 'Interpreter', 'none');
        end
        ylabel(ax, 'N', 'Interpreter', 'none', 'rotation', 0);
        
        % Заголовок будет добавлен через tiledlayout после цикла
        
        % Настройка диапазона Y-оси
        if strcmp(state.yAxisRange, 'manual') && ~isempty(state.yAxisMin) && ~isempty(state.yAxisMax)
            ylim(ax, [state.yAxisMin, state.yAxisMax]);
        end
        
        % Настройка диапазона X-оси
        if strcmp(state.xAxisRange, 'manual') && ~isempty(state.xAxisMin) && ~isempty(state.xAxisMax)
            xlim(ax, [state.xAxisMin, state.xAxisMax]);
        end
        
        % Легенда (показываем источник данных - Column)
        if state.showLegend && length(paramGroups) > 0
            groupLabels = cell(length(paramGroups), 1);
            for g = 1:length(paramGroups)
                groupLabels{g} = paramGroups{g}.column;
            end
            legend(ax, groupLabels, 'Location', 'best', 'Interpreter', 'none');
        end
        
        % Сетка
        grid(ax, 'on');
    end
    
    % Добавляем общий заголовок через tiledlayout
    if nPlotGroups > 0
        title(t, state.title, 'FontSize', 14, 'FontWeight', 'bold', 'Interpreter', 'none');
        zoom(fig, 'on');
        pan(fig, 'on');
    end
end

function createBoxplotFigure(fig, state)
    % Построение графика с боксплотами
    % Использует структуру state.filteredData для получения данных
    
    % Дебаг в начале функции
    debugState('createBoxplotFigure', 'Entered function:');
    debugState('createBoxplotFigure', '  using filteredData structure');
    
    % Инициализация полей, если они отсутствуют (для совместимости со старыми состояниями)
    if ~isfield(state, 'showFileIds')
        state.showFileIds = false;
    end
    if ~isfield(state, 'showYValues')
        state.showYValues = false;
    end
    if ~isfield(state, 'showLegend')
        state.showLegend = true;
    end
    
    % Находим панель для графиков
    plotPanel = findobj(fig, 'Tag', 'plotPanel');
   
    % Очищаем содержимое панели
    delete(plotPanel.Children);
    
    % Проверяем наличие структуры с данными
    if isempty(state.filteredData) || isempty(fieldnames(state.filteredData))
        return
    end
    
    % Инициализируем структуру для статистических тестов
    statisticalTests = struct();
    
    % Получаем все поля из структуры filteredData
    filteredDataFields = fieldnames(state.filteredData);
    
    groupNames = {};
    for i = 1:length(filteredDataFields)
        fieldName = filteredDataFields{i};
        paramData = state.filteredData.(fieldName);
        if isstruct(paramData) && isfield(paramData, 'groupName')
            groupNames{end+1} = paramData.groupName;
        else
            groupNames{end+1} = '1';
        end
    end
    uniqueGroupNames = unique(groupNames, 'stable');
    nPlotGroups = length(uniqueGroupNames);
    
    t = tiledlayout(plotPanel, nPlotGroups, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    
    for plotGroupIdx = 1:nPlotGroups
        groupName = uniqueGroupNames{plotGroupIdx};
        
        paramsInGroup = {};
        for i = 1:length(filteredDataFields)
            fieldName = filteredDataFields{i};
            paramData = state.filteredData.(fieldName);
            if isstruct(paramData) && isfield(paramData, 'groupName') && strcmp(paramData.groupName, groupName)
                paramData.fieldName = fieldName;
                paramsInGroup{end+1} = paramData;
            end
        end
        
        % Создаем ось через nexttile (tiledlayout автоматически управляет позицией)
        ax = nexttile(t);
        hold(ax, 'on');
        
        % Строим боксплоты: один бокс на параметр (без объединения по displayLabel)
        allDataForGroup = [];
        groupLabelsForBoxplot = {};
        fileIdsForGroup = [];
        paramDataByFieldName = containers.Map();
        displayLabelsByFieldName = containers.Map(); % displayLabel для подписей оси X
        
        for p = 1:length(paramsInGroup)
            paramData = paramsInGroup{p};
            if isempty(paramData.data)
                continue
            end
            data = paramData.data;
            if ~isempty(paramData.label)
                displayLabel = paramData.label;
            else
                displayLabel = paramData.column;
            end
            
            allDataForGroup = [allDataForGroup; data];
            groupLabelsForBoxplot = [groupLabelsForBoxplot; repmat({paramData.fieldName}, length(data), 1)];
            if isfield(paramData, 'fileIds') && ~isempty(paramData.fileIds) && length(paramData.fileIds) == length(data)
                fileIdsForGroup = [fileIdsForGroup; paramData.fileIds(:)];
            else
                fileIdsForGroup = [fileIdsForGroup; NaN(length(data), 1)];
            end
            paramDataByFieldName(paramData.fieldName) = paramData;
            displayLabelsByFieldName(paramData.fieldName) = displayLabel;
        end
        
        % Построение боксплотов
        if ~isempty(allDataForGroup)
            boxplot(ax, allDataForGroup, groupLabelsForBoxplot, 'Symbol', '');
            hold(ax, 'on');
            
            uniqueGroupLabels = unique(groupLabelsForBoxplot, 'stable');
            fieldNameToPosition = containers.Map();
            for g = 1:length(uniqueGroupLabels)
                fieldNameToPosition(uniqueGroupLabels{g}) = g;
            end
            
            % Находим все patch объекты (боксы)
            allChildren = get(ax, 'Children');
            boxPatches = [];
            for i = 1:length(allChildren)
                if strcmp(get(allChildren(i), 'Type'), 'patch')
                    boxPatches = [boxPatches; allChildren(i)];
                end
            end
            
            % Сортируем patch объекты по их X координатам
            if ~isempty(boxPatches)
                xPositions = zeros(length(boxPatches), 1);
                for i = 1:length(boxPatches)
                    xData = get(boxPatches(i), 'XData');
                    if ~isempty(xData)
                        xPositions(i) = mean(xData);
                    else
                        % Если XData пуст, используем Vertices
                        vertices = get(boxPatches(i), 'Vertices');
                        if ~isempty(vertices)
                            xPositions(i) = mean(vertices(:, 1));
                        end
                    end
                end
                [~, sortIdx] = sort(xPositions);
                boxPatches = boxPatches(sortIdx);
            end
            
            % Находим все line объекты
            allLines = findobj(ax, 'Type', 'line');
            
            for g = 1:length(uniqueGroupLabels)
                fieldName = uniqueGroupLabels{g};
                paramDataForLabel = paramDataByFieldName(fieldName);
                color = paramDataForLabel.parsedColor;
                paramLineWidth = paramDataForLabel.lineWidth;
                
                if ~isempty(boxPatches) && g <= length(boxPatches)
                    set(boxPatches(g), 'FaceColor', color, 'EdgeColor', color * 0.7, 'LineWidth', paramLineWidth);
                end
                xPos = g;
                for i = 1:length(allLines)
                    xData = get(allLines(i), 'XData');
                    if ~isempty(xData)
                        xMean = mean(xData);
                        if abs(xMean - xPos) < 0.3
                            currentLineWidth = get(allLines(i), 'LineWidth');
                            if currentLineWidth > 1
                                set(allLines(i), 'Color', color * 0.5, 'LineWidth', paramLineWidth);
                            else
                                set(allLines(i), 'Color', color, 'LineWidth', paramLineWidth);
                            end
                        end
                    end
                end
            end
            
            % Точки данных с jitter, File ID, Y-значения, n=X
            for g = 1:length(uniqueGroupLabels)
                fieldName = uniqueGroupLabels{g};
                mask = strcmp(groupLabelsForBoxplot, fieldName);
                data = allDataForGroup(mask);
                fileIdsForLabel = fileIdsForGroup(mask);
                if isempty(data)
                    continue
                end
                paramDataForLabel = paramDataByFieldName(fieldName);
                color = paramDataForLabel.parsedColor;
                paramLineWidth = paramDataForLabel.lineWidth;
                x_pos = g;
                x_jitter = x_pos + 0.1 * (rand(size(data)) - 0.5);
                markerSize = paramLineWidth * 30;
                scatter(ax, x_jitter, data, markerSize, color, 'o', ...
                    'MarkerFaceColor', color, ...
                    'MarkerEdgeColor', 'white', ...
                    'LineWidth', paramLineWidth, ...
                    'MarkerFaceAlpha', 1);
                dataRange = max(data) - min(data);
                if dataRange == 0
                    dataRange = abs(max(data)) * 0.01;
                    if dataRange == 0
                        dataRange = 1;
                    end
                end
                if state.showFileIds && ~isempty(fileIdsForLabel)
                    plotFileIdsOnAxes(ax, x_jitter, data, fileIdsForLabel, -0.05, 0.01 * dataRange, true);
                end
                if state.showYValues
                    plotYValuesOnAxes(ax, x_jitter, data, data, 0.05, 0.01 * dataRange, '%.3f', true);
                end
                medianVal = paramDataForLabel.stats.median;
                if isnan(medianVal)
                    medianVal = median(data);
                end
                if state.showStatistics
                    s = paramDataForLabel.stats;
                    q25 = s.q25;
                    q75 = s.q75;
                    if ~isnan(q25) && ~isnan(q75)
                        statsStr = sprintf('n=%d\nM=%.3f\n[%.2f–%.2f]', length(data), medianVal, q25, q75);
                    else
                        statsStr = sprintf('n=%d\nM=%.3f\n—', length(data), medianVal);
                    end
                    text(ax, x_pos - 0.4, medianVal, statsStr, ...
                        'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle', ...
                        'FontSize', 9, 'Color', color, 'BackgroundColor', 'white', ...
                        'Interpreter', 'none');
                end
            end
            
            % Подписи оси X: displayLabel (дубликаты допустимы)
            tickLabels = cell(1, length(uniqueGroupLabels));
            for g = 1:length(uniqueGroupLabels)
                tickLabels{g} = displayLabelsByFieldName(uniqueGroupLabels{g});
            end
            set(ax, 'XTick', 1:length(uniqueGroupLabels), 'XTickLabel', tickLabels);
            
            % Вычисляем статистические тесты между параметрами на этом полотне
            if state.showStatistics && length(paramDataByFieldName) >= 2
                % Выполняем попарные тесты между параметрами
                paramKeys = keys(paramDataByFieldName);
                testResultsForGroup = struct();
                for i = 1:length(paramKeys)
                    for j = i+1:length(paramKeys)
                        param1 = paramKeys{i};
                        param2 = paramKeys{j};
                        
                        data1 = paramDataByFieldName(param1).data;
                        data2 = paramDataByFieldName(param2).data;
                        
                        if length(data1) > 0 && length(data2) > 0
                            try
                                [~, pvalue] = ttest2(data1, data2);
                                testKey = sprintf('%s_vs_%s', matlab.lang.makeValidName(param1), matlab.lang.makeValidName(param2));
                                testResultsForGroup.(testKey) = struct(...
                                    'pvalue', pvalue, ...
                                    'n1', length(data1), ...
                                    'n2', length(data2), ...
                                    'group1', param1, ...
                                    'group2', param2);
                            catch
                                % Игнорируем ошибки тестов
                            end
                        end
                    end
                end
                
                gnForKey = groupName;
                if isempty(gnForKey)
                    gnForKey = 'noname';
                end
                paramKeyValid = matlab.lang.makeValidName(sprintf('Group_%s', gnForKey));
                statisticalTests.(paramKeyValid) = testResultsForGroup;
                
                if ~isempty(testResultsForGroup) && ~isempty(fieldnames(testResultsForGroup))
                    gnDisp = groupName;
                    if isempty(gnDisp)
                        gnDisp = '(no name)';
                    end
                    fprintf('\n=== Statistical Tests for Group %s ===\n', gnDisp);
                    fprintf('%-30s %-30s %12s %8s %8s %12s\n', 'Parameter 1', 'Parameter 2', 'p-value', 'n1', 'n2', 'Significant');
                    fprintf('%s\n', repmat('-', 1, 100));
                    testFields = fieldnames(testResultsForGroup);
                    for i = 1:length(testFields)
                        testKey = testFields{i};
                        testData = testResultsForGroup.(testKey);
                        significant = testData.pvalue < 0.05;
                        sigStr = 'Yes';
                        if ~significant
                            sigStr = 'No';
                        end
                        fprintf('%-30s %-30s %12.6f %8d %8d %12s\n', ...
                            testData.group1, testData.group2, testData.pvalue, ...
                            testData.n1, testData.n2, sigStr);
                    end
                    fprintf('\n');
                end
            end
        end
        
        if length(paramsInGroup) == 1
            yLabelText = paramsInGroup{1}.column;
        else
            yLabelText = groupName;
            if isempty(yLabelText)
                yLabelText = '(no name)';
            end
        end
        ylabel(ax, yLabelText, 'Interpreter', 'none');
        if plotGroupIdx == nPlotGroups
            xlabel(ax, 'Groups', 'Interpreter', 'none');
        end
        
        % Настройка диапазона Y-оси
        if strcmp(state.yAxisRange, 'manual') && ~isempty(state.yAxisMin) && ~isempty(state.yAxisMax)
            ylim(ax, [state.yAxisMin, state.yAxisMax]);
        elseif strcmp(state.yAxisRange, 'auto')
            % Автоматический расчет пределов по процентилям 0.001 и 99.99
            if ~isempty(allDataForGroup)
                yMin = prctile(allDataForGroup, 0.001);
                yMax = prctile(allDataForGroup, 99.99);
                % Если все значения одинаковые, добавляем небольшой отступ
                if yMin == yMax
                    if yMin == 0
                        yMin = -0.1;
                        yMax = 0.1;
                    else
                        offset = abs(yMin) * 0.01;
                        yMin = yMin - offset;
                        yMax = yMax + offset;
                    end
                end
                ylim(ax, [yMin, yMax]);
            end
        end
        
        % Настройка диапазона X-оси
        if strcmp(state.xAxisRange, 'manual') && ~isempty(state.xAxisMin) && ~isempty(state.xAxisMax)
            xlim(ax, [state.xAxisMin, state.xAxisMax]);
        end
        
        if state.showStatistics
            gnForKey = groupName;
            if isempty(gnForKey)
                gnForKey = 'noname';
            end
            paramKeyValid = matlab.lang.makeValidName(sprintf('Group_%s', gnForKey));
            
            if isfield(statisticalTests, paramKeyValid)
                currentYLim = ylim(ax);
                
                % Вычисляем максимальный уровень скобок
                maxLevel = boxplotCalculateMaxBracketLevelForParams(statisticalTests.(paramKeyValid), fieldNameToPosition, state.showAllPvalues);
                
                % Рисуем скобки между параметрами
                boxplotAddSignificanceBracketsForParams(ax, fieldNameToPosition, ...
                    statisticalTests.(paramKeyValid), ...
                    state.showAllPvalues, currentYLim);
                
                % Обновляем пределы Y-оси чтобы вместить скобки
                if maxLevel >= 0
                    yRange = currentYLim(2) - currentYLim(1);
                    yBaseOffset = yRange * 0.05;
                    yLevelSpacing = yRange * 0.08;
                    yTextOffset = yRange * 0.015;
                    newYMax = currentYLim(2) + yBaseOffset + maxLevel * yLevelSpacing + yTextOffset;
                    ylim(ax, [currentYLim(1), newYMax]);
                end
            end
        end
        
    end
    
    % Добавляем общий заголовок через tiledlayout
    if nPlotGroups > 0
        title(t, state.title, 'FontSize', 14, 'FontWeight', 'bold', 'Interpreter', 'none');
        zoom(fig, 'on');
        pan(fig, 'on');
    end
end

function plotFileIdsOnAxes(ax, xPositions, yPositions, fileIds, xOffset, yOffset, useAbsoluteOffset)
    % plotFileIdsOnAxes - Отображение File IDs рядом с точками на графике
    % Входные параметры:
    %   ax - handle оси
    %   xPositions - массив X координат точек
    %   yPositions - массив Y координат точек
    %   fileIds - массив File IDs (может быть пустым)
    %   xOffset - смещение по X (относительно диапазона или абсолютное)
    %   yOffset - смещение по Y (относительно диапазона или абсолютное)
    %   useAbsoluteOffset - если true, смещения абсолютные; если false или не указано - относительные
    
    if nargin < 7
        useAbsoluteOffset = false;
    end
    
    if isempty(fileIds) || length(fileIds) ~= length(xPositions)
        return
    end
    
    if useAbsoluteOffset
        xOffsetFinal = xOffset;
        yOffsetFinal = yOffset;
    else
        xRange = max(xPositions) - min(xPositions);
        yRange = max(yPositions) - min(yPositions);
        
        if xRange == 0
            if length(xPositions) == 1
                xRange = abs(xPositions(1)) * 0.01;
            else
                xRange = 1;
            end
            if xRange == 0
                xRange = 1;
            end
        end
        
        if yRange == 0
            yRange = abs(max(yPositions)) * 0.01;
            if yRange == 0
                yRange = 1;
            end
        end
        
        xOffsetFinal = xOffset * xRange;
        yOffsetFinal = yOffset * yRange;
    end
    
    for i = 1:length(xPositions)
        if ~isnan(fileIds(i))
            text(ax, xPositions(i) + xOffsetFinal, yPositions(i) + yOffsetFinal, num2str(fileIds(i)), ...
                'HorizontalAlignment', 'right', ...
                'VerticalAlignment', 'bottom', ...
                'FontSize', 7, ...
                'Color', [1 1 1], ...
                'BackgroundColor', [0 0 0], ...
                'Interpreter', 'none');
        end
    end
end

function plotYValuesOnAxes(ax, xPositions, yPositions, yValues, xOffset, yOffset, formatStr, useAbsoluteOffset)
    % plotYValuesOnAxes - Отображение Y значений рядом с точками на графике
    % Входные параметры:
    %   ax - handle оси
    %   xPositions - массив X координат точек
    %   yPositions - массив Y координат точек
    %   yValues - массив Y значений для отображения (может быть равен yPositions)
    %   xOffset - смещение по X (относительно диапазона или абсолютное)
    %   yOffset - смещение по Y (относительно диапазона или абсолютное)
    %   formatStr - формат строки (например, '%.3f' или '(%.3f,%.3f)')
    %   useAbsoluteOffset - если true, смещения абсолютные; если false или не указано - относительные
    
    if nargin < 8
        useAbsoluteOffset = false;
    end
    
    if isempty(yValues) || length(yValues) ~= length(xPositions)
        return
    end
    
    if useAbsoluteOffset
        xOffsetFinal = xOffset;
        yOffsetFinal = yOffset;
    else
        xRange = max(xPositions) - min(xPositions);
        yRange = max(yPositions) - min(yPositions);
        
        if xRange == 0
            if length(xPositions) == 1
                xRange = abs(xPositions(1)) * 0.01;
            else
                xRange = 1;
            end
            if xRange == 0
                xRange = 1;
            end
        end
        
        if yRange == 0
            yRange = abs(max(yPositions)) * 0.01;
            if yRange == 0
                yRange = 1;
            end
        end
        
        xOffsetFinal = xOffset * xRange;
        yOffsetFinal = yOffset * yRange;
    end
    
    for i = 1:length(xPositions)
        if contains(formatStr, ',')
            % Формат для пар значений (x, y)
            textStr = sprintf(formatStr, xPositions(i), yPositions(i));
        else
            % Формат для одного значения
            textStr = sprintf(formatStr, yValues(i));
        end
        text(ax, xPositions(i) + xOffsetFinal, yPositions(i) + yOffsetFinal, textStr, ...
            'HorizontalAlignment', 'left', ...
            'VerticalAlignment', 'bottom', ...
            'FontSize', 7, ...
            'Color', [0 0 0], ...
            'BackgroundColor', [1 1 1], ...
            'Interpreter', 'none');
    end
end



