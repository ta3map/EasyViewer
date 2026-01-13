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
        'ColumnName', {'Group', 'Column', 'Filter', 'Label', 'Color', 'LineWidth'}, ...
        'ColumnEditable', [true, true, true, true, true, true], ...
        'ColumnWidth', {50, 100, 80, 80, 70, 70}, ...
        'Data', cell(0, 6), ...
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
        
        % Заменяем пустые ячейки на NaN
        state.table = replaceEmptyCellsWithNaN(state.table);
        
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
    
    % Получаем все поля из state.filteredData в порядке их создания
    filteredFields = fieldnames(state.filteredData);
    if isempty(filteredFields)
        return
    end
    
    % Собираем данные для всех выделенных строк
    allColumnData = {};
    columnNames = {};
    allParamData = {}; % Сохраняем paramData для статистики
    
    for rowIdx = selectedRows(:)'
        if rowIdx < 1 || rowIdx > length(state.parameters)
            continue
        end
        
        if rowIdx > length(filteredFields)
            continue
        end
        
        param = state.parameters{rowIdx};
        fieldName = filteredFields{rowIdx};
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
            state.parameters{end+1} = struct('column', colName, 'groupNumber', 1, 'filter', '', 'label', colName, 'color', colorHex, 'lineWidth', 1);
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
        set(paramsTable, 'Data', cell(0, 6));
        return
    end
    
    % Формируем данные для таблицы (поля уже нормализованы)
    tableData = cell(length(state.parameters), 6);
    for i = 1:length(state.parameters)
        tableData{i, 1} = state.parameters{i}.groupNumber;
        tableData{i, 2} = state.parameters{i}.column;
        tableData{i, 3} = state.parameters{i}.filter;
        tableData{i, 4} = state.parameters{i}.label;
        tableData{i, 5} = state.parameters{i}.color;
        tableData{i, 6} = state.parameters{i}.lineWidth;
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
    
    % Если редактировалась колонка Column (индекс 2), проверяем существование колонки
    if editedCol == 2 && editedRow <= length(state.parameters)
        newColumnName = tableData{editedRow, 2};
        if ischar(newColumnName) || isstring(newColumnName)
            newColumnName = char(newColumnName);
            if ~ismember(newColumnName, state.table.Properties.VariableNames)
                msgbox(sprintf('Column "%s" does not exist in the table', newColumnName), 'Warning', 'warn');
                tableData{editedRow, 2} = state.parameters{editedRow}.column;
                set(paramsTable, 'Data', tableData);
                return
            end
        end
    end
    
    % Обновляем state.parameters из таблицы
    for i = 1:min(length(state.parameters), size(tableData, 1))
        % Group number
        newGroupNumber = tableData{i, 1};
        if isnumeric(newGroupNumber) && newGroupNumber > 0
            state.parameters{i}.groupNumber = newGroupNumber;
        end
        % Column
        if ischar(tableData{i, 2}) || isstring(tableData{i, 2})
            newColumnName = char(tableData{i, 2});
            if ismember(newColumnName, state.table.Properties.VariableNames)
                state.parameters{i}.column = newColumnName;
            end
        end
        % Filter
        if ischar(tableData{i, 3}) || isstring(tableData{i, 3})
            state.parameters{i}.filter = char(tableData{i, 3});
        end
        % Label
        if ischar(tableData{i, 4}) || isstring(tableData{i, 4})
            state.parameters{i}.label = char(tableData{i, 4});
        end
        % Color
        if ischar(tableData{i, 5}) || isstring(tableData{i, 5})
            state.parameters{i}.color = char(tableData{i, 5});
        end
        % LineWidth
        if isnumeric(tableData{i, 6}) && tableData{i, 6} > 0
            state.parameters{i}.lineWidth = tableData{i, 6};
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

function tableOut = replaceEmptyCellsWithNaN(tableIn)
    % replaceEmptyCellsWithNaN - Заменяет все пустые ячейки в таблице на NaN
    tableOut = tableIn;
    varNames = tableOut.Properties.VariableNames;
    
    for i = 1:length(varNames)
        colName = varNames{i};
        columnData = tableOut{:, colName};
        
        if iscell(columnData)
            for j = 1:length(columnData)
                if isempty(columnData{j})
                    columnData{j} = NaN;
                end
            end
            tableOut{:, colName} = columnData;
        end
    end
end

function numericData = convertTableColumnToNumeric(columnData)
    % convertTableColumnToNumeric - Конвертация данных колонки таблицы в числовой формат
    % Принимает данные любого типа и возвращает числовой массив (double)
    % Строковые значения конвертируются через str2double (неконвертируемые → NaN)
    % Cell arrays обрабатываются: если внутри числа - извлекаются, если строки - конвертируются
    
    if isnumeric(columnData)
        numericData = double(columnData);
    elseif islogical(columnData)
        numericData = double(columnData);
    elseif iscell(columnData)
        numericData = nan(length(columnData), 1);
        for i = 1:length(columnData)
            value = columnData{i};
            if isnumeric(value) && isscalar(value)
                numericData(i) = double(value);
            elseif islogical(value) && isscalar(value)
                numericData(i) = double(value);
            elseif ischar(value) || isstring(value)
                numericData(i) = str2double(value);
            elseif isempty(value)
                numericData(i) = NaN;
            end
        end
    else
        numericData = str2double(columnData);
    end
end

function updateFilteredDataStructure(fig)
    % updateFilteredDataStructure - Обновление структуры с отфильтрованными данными
    % Собирает структуру из оригинальной таблицы после применения фильтров
    % для каждого параметра. Использует индексы для уникальности ключей.
    
    state = get(fig, 'UserData');
    if isempty(state.table) || isempty(state.parameters)
        state.filteredData = struct();
        set(fig, 'UserData', state);
        return
    end
    
    % Очищаем структуру
    state.filteredData = struct();
    
    % Счетчики для индексации (сколько раз уже встретили этот параметр)
    columnIndices = containers.Map();
    
    % Обрабатываем каждый параметр
    for i = 1:length(state.parameters)
        paramStruct = state.parameters{i};
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
                    filteredData = convertTableColumnToNumeric(filteredTable{:, columnName});
                    % Извлекаем File ID
                    if ismember('FileID', filteredTable.Properties.VariableNames)
                        fileIds = filteredTable{:, 'FileID'};
                    end
                end
            end
        else
            % Нет фильтра - используем все данные
            filteredData = convertTableColumnToNumeric(state.table{:, columnName});
            % Извлекаем File ID
            if ismember('FileID', state.table.Properties.VariableNames)
                fileIds = state.table{:, 'FileID'};
            end
        end
        
        % Рассчитываем статистику для отфильтрованных данных
        stats = struct();
        if ~isempty(filteredData)
            stats.count = length(filteredData);
            stats.nanCount = sum(isnan(filteredData) | isinf(filteredData));
            validData = filteredData(~isnan(filteredData) & ~isinf(filteredData));
            if ~isempty(validData)
                stats.mean = mean(validData);
                stats.std = std(validData);
                stats.median = median(validData);
                stats.q25 = prctile(validData, 25);
                stats.q75 = prctile(validData, 75);
                stats.min = min(validData);
                stats.max = max(validData);
            else
                stats.mean = NaN;
                stats.std = NaN;
                stats.median = NaN;
                stats.q25 = NaN;
                stats.q75 = NaN;
                stats.min = NaN;
                stats.max = NaN;
            end
        else
            stats.mean = NaN;
            stats.std = NaN;
            stats.median = NaN;
            stats.q25 = NaN;
            stats.q75 = NaN;
            stats.min = NaN;
            stats.max = NaN;
            stats.count = 0;
            stats.nanCount = 0;
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
        
        % Сохраняем в структуру с метаданными, статистикой и распарсенным цветом
        validFieldName = matlab.lang.makeValidName(fieldName);
        state.filteredData.(validFieldName) = struct(...
            'data', filteredData, ...
            'column', columnName, ...
            'label', paramStruct.label, ...
            'color', paramStruct.color, ...
            'parsedColor', parsedColor, ...
            'lineWidth', paramStruct.lineWidth, ...
            'groupNumber', paramStruct.groupNumber, ...
            'filter', filterStr, ...
            'fieldName', fieldName, ...
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
    
    % Группируем параметры по groupNumber
    groupNumbers = [];
    for i = 1:length(filteredDataFields)
        fieldName = filteredDataFields{i};
        paramData = state.filteredData.(fieldName);
        if isstruct(paramData)
            groupNumbers(end+1) = paramData.groupNumber;
        else
            groupNumbers(end+1) = 1;
        end
    end
    uniqueGroupNumbers = unique(groupNumbers);
    nPlotGroups = length(uniqueGroupNumbers);
    
    if nPlotGroups == 0
        return
    end
    
    % Создаем tiledlayout для автоматического управления расположением осей
    t = tiledlayout(plotPanel, nPlotGroups, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    
    % Обрабатываем каждую группу
    for plotGroupIdx = 1:nPlotGroups
        groupNum = uniqueGroupNumbers(plotGroupIdx);
        
        % Находим все параметры с этим номером группы
        paramsInGroup = {};
        for i = 1:length(filteredDataFields)
            fieldName = filteredDataFields{i};
            paramData = state.filteredData.(fieldName);
            if isstruct(paramData) && paramData.groupNumber == groupNum
                paramData.fieldName = fieldName;
                paramsInGroup{end+1} = paramData;
            elseif isstruct(paramData) && paramData.groupNumber == 1 && groupNum == 1
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
            xData = convertTableColumnToNumeric(filteredTable{:, param1.column});
            yData = convertTableColumnToNumeric(filteredTable{:, param2.column});
            
            % Получаем FileID если доступен
            fileIds = [];
            if ismember('FileID', filteredTable.Properties.VariableNames)
                fileIds = filteredTable{:, 'FileID'};
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
                xRange = max(xData) - min(xData);
                yRange = max(yData) - min(yData);
                if xRange == 0
                    xRange = abs(max(xData)) * 0.01;
                    if xRange == 0
                        xRange = 1;
                    end
                end
                if yRange == 0
                    yRange = abs(max(yData)) * 0.01;
                    if yRange == 0
                        yRange = 1;
                    end
                end
                for i = 1:length(xData)
                    if ~isnan(fileIds(i))
                        text(ax, xData(i) - 0.01 * xRange, yData(i) + 0.01 * yRange, num2str(fileIds(i)), ...
                            'HorizontalAlignment', 'right', ...
                            'VerticalAlignment', 'bottom', ...
                            'FontSize', 7, ...
                            'Color', [1 1 1], ...
                            'BackgroundColor', [0 0 0], ...
                            'Interpreter', 'none');
                    end
                end
            end
            
            % Отображение значений Y рядом с точками (если включено)
            if state.showYValues
                xRange = max(xData) - min(xData);
                yRange = max(yData) - min(yData);
                if xRange == 0
                    xRange = abs(max(xData)) * 0.01;
                    if xRange == 0
                        xRange = 1;
                    end
                end
                if yRange == 0
                    yRange = abs(max(yData)) * 0.01;
                    if yRange == 0
                        yRange = 1;
                    end
                end
                for i = 1:length(xData)
                    text(ax, xData(i) + 0.01 * xRange, yData(i) + 0.01 * yRange, sprintf('(%.3f,%.3f)', xData(i), yData(i)), ...
                        'HorizontalAlignment', 'left', ...
                        'VerticalAlignment', 'bottom', ...
                        'FontSize', 7, ...
                        'Color', [0 0 0], ...
                        'BackgroundColor', [1 1 1], ...
                        'Interpreter', 'none');
                end
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
                    % Простой scatter plot по индексам на том же axes
                    hScatterSingle = scatter(ax, 1:length(data), data, 50, param.parsedColor, 'o', ...
                        'MarkerFaceColor', param.parsedColor, ...
                        'MarkerEdgeColor', 'white', ...
                        'LineWidth', 1, ...
                        'MarkerFaceAlpha', 0.7);
                    
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
            xlabel(ax, sprintf('Group %d', groupNum), 'Interpreter', 'none');
        end
        
        if ~isempty(uniqueYLabels)
            yLabelText = strjoin(uniqueYLabels, ', ');
            ylabel(ax, yLabelText, 'Interpreter', 'none');
        else
            ylabel(ax, sprintf('Group %d', groupNum), 'Interpreter', 'none');
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
    % Группирует данные по groupNumber из параметров анализа (как в boxplot)
    
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
    
    % Группируем параметры по groupNumber (как в boxplot)
    groupNumbers = [];
    for i = 1:length(filteredDataFields)
        fieldName = filteredDataFields{i};
        paramData = state.filteredData.(fieldName);
        if isstruct(paramData)
            groupNumbers(end+1) = paramData.groupNumber;
        else
            groupNumbers(end+1) = 1;
        end
    end
    uniqueGroupNumbers = unique(groupNumbers);
    nPlotGroups = length(uniqueGroupNumbers);
    
    % Создаем tiledlayout для автоматического управления расположением осей
    t = tiledlayout(plotPanel, nPlotGroups, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    
    % Строим графики по группам (как в boxplot)
    for plotGroupIdx = 1:nPlotGroups
        groupNum = uniqueGroupNumbers(plotGroupIdx);
        
        % Находим все параметры с этим номером группы
        paramsInGroup = {};
        for i = 1:length(filteredDataFields)
            fieldName = filteredDataFields{i};
            paramData = state.filteredData.(fieldName);
            if isstruct(paramData) && paramData.groupNumber == groupNum
                paramData.fieldName = fieldName;
                paramsInGroup{end+1} = paramData;
            elseif isstruct(paramData) && paramData.groupNumber == 1 && groupNum == 1
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
                columnData = convertTableColumnToNumeric(filteredTable{:, paramData.column});
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
            xlabel(ax, sprintf('Group %d', groupNum), 'Interpreter', 'none');
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
    
    % Группируем параметры по groupNumber
    groupNumbers = [];
    for i = 1:length(filteredDataFields)
        fieldName = filteredDataFields{i};
        paramData = state.filteredData.(fieldName);
        if isstruct(paramData)
            groupNumbers(end+1) = paramData.groupNumber;
        else
            groupNumbers(end+1) = 1;
        end
    end
    uniqueGroupNumbers = unique(groupNumbers);
    nPlotGroups = length(uniqueGroupNumbers);
    
    % Создаем tiledlayout для автоматического управления расположением осей
    t = tiledlayout(plotPanel, nPlotGroups, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    
    % Строим графики по группам
    for plotGroupIdx = 1:nPlotGroups
        groupNum = uniqueGroupNumbers(plotGroupIdx);
        
        % Находим все параметры с этим номером группы из структуры filteredData
        paramsInGroup = {};
        for i = 1:length(filteredDataFields)
            fieldName = filteredDataFields{i};
            paramData = state.filteredData.(fieldName);
            if isstruct(paramData) && paramData.groupNumber == groupNum
                % Добавляем fieldName в структуру для использования в метках
                paramData.fieldName = fieldName;
                paramsInGroup{end+1} = paramData;
            elseif isstruct(paramData) && paramData.groupNumber == 1 && groupNum == 1
                % Добавляем fieldName в структуру для использования в метках
                paramData.fieldName = fieldName;
                paramsInGroup{end+1} = paramData;
            end
        end
        
        % Создаем ось через nexttile (tiledlayout автоматически управляет позицией)
        ax = nexttile(t);
        hold(ax, 'on');
        
        % Строим боксплоты для всех параметров в группе используя структуру filteredData
        allDataForGroup = [];
        groupLabelsForBoxplot = {};
        fileIdsForGroup = []; % Массив File ID, параллельный allDataForGroup
        paramDataByFieldName = containers.Map(); % Map для доступа к paramData по fieldName
        displayLabelToFieldName = containers.Map(); % Map для связи displayLabel -> fieldName
        
        for p = 1:length(paramsInGroup)
            paramData = paramsInGroup{p};
            
            if isempty(paramData.data)
                continue
            end
            
            % Получаем данные из структуры
            data = paramData.data;
            
            % Получаем метку - используем label или column
            if ~isempty(paramData.label)
                displayLabel = paramData.label;
            else
                displayLabel = paramData.column;
            end
            
            % Получаем цвет и lineWidth из структуры (уже распарсены)
            color = paramData.parsedColor;
            paramLineWidth = paramData.lineWidth;
            
            % Добавляем данные
            if ~isempty(data)
                allDataForGroup = [allDataForGroup; data];
                groupLabelsForBoxplot = [groupLabelsForBoxplot; repmat({displayLabel}, length(data), 1)];
                
                % Добавляем File ID для каждой точки
                if isfield(paramData, 'fileIds') && ~isempty(paramData.fileIds) && length(paramData.fileIds) == length(data)
                    fileIdsForGroup = [fileIdsForGroup; paramData.fileIds(:)];
                else
                    % Если File ID нет, заполняем NaN
                    fileIdsForGroup = [fileIdsForGroup; NaN(length(data), 1)];
                end
                
                % Сохраняем paramData по fieldName
                paramDataByFieldName(paramData.fieldName) = paramData;
                
                % Сохраняем связь displayLabel -> fieldName (берем первый fieldName для каждого displayLabel)
                if ~isKey(displayLabelToFieldName, displayLabel)
                    displayLabelToFieldName(displayLabel) = paramData.fieldName;
                end
            end
        end
        
        % Построение боксплотов
        if ~isempty(allDataForGroup)
            boxplot(ax, allDataForGroup, groupLabelsForBoxplot, 'Symbol', '');
            hold(ax, 'on');
            
            % Применение цветов к боксплотам
            uniqueDisplayLabels = unique(groupLabelsForBoxplot, 'stable');
            
            % Создаем Map fieldNameToPosition по порядку displayLabel
            fieldNameToPosition = containers.Map();
            for g = 1:length(uniqueDisplayLabels)
                displayLabel = uniqueDisplayLabels{g};
                % Находим все fieldName с этим displayLabel
                fieldNames = keys(paramDataByFieldName);
                for f = 1:length(fieldNames)
                    fieldName = fieldNames{f};
                    paramData = paramDataByFieldName(fieldName);
                    paramDisplayLabel = paramData.label;
                    if isempty(paramDisplayLabel)
                        paramDisplayLabel = paramData.column;
                    end
                    if strcmp(paramDisplayLabel, displayLabel)
                        fieldNameToPosition(fieldName) = g;
                    end
                end
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
            
            for g = 1:length(uniqueDisplayLabels)
                displayLabel = uniqueDisplayLabels{g};
                
                % Получаем paramData из Map
                color = [0.5 0.5 0.5]; % серый по умолчанию
                paramLineWidth = 1; % по умолчанию
                if isKey(displayLabelToFieldName, displayLabel)
                    fieldName = displayLabelToFieldName(displayLabel);
                    if isKey(paramDataByFieldName, fieldName)
                        paramDataForLabel = paramDataByFieldName(fieldName);
                        color = paramDataForLabel.parsedColor;
                        paramLineWidth = paramDataForLabel.lineWidth;
                    end
                end
                
                % Применяем цвет к боксу (patch) - по порядку после сортировки
                if ~isempty(boxPatches) && g <= length(boxPatches)
                    set(boxPatches(g), 'FaceColor', color, 'EdgeColor', color * 0.7, 'LineWidth', paramLineWidth);
                end
                
                % Применяем цвет и толщину к линиям по их позиции X
                xPos = g;
                for i = 1:length(allLines)
                    xData = get(allLines(i), 'XData');
                    if ~isempty(xData)
                        % Проверяем, относится ли линия к этой позиции
                        xMean = mean(xData);
                        if abs(xMean - xPos) < 0.3
                            currentLineWidth = get(allLines(i), 'LineWidth');
                            if currentLineWidth > 1
                                % Это медиана
                                set(allLines(i), 'Color', color * 0.5, 'LineWidth', paramLineWidth);
                            else
                                % Это усы или другие линии
                                set(allLines(i), 'Color', color, 'LineWidth', paramLineWidth);
                            end
                        end
                    end
                end
            end
            
            % Добавление точек данных с jitter
            for g = 1:length(uniqueDisplayLabels)
                displayLabel = uniqueDisplayLabels{g};
                mask = strcmp(groupLabelsForBoxplot, displayLabel);
                data = allDataForGroup(mask);
                fileIdsForLabel = fileIdsForGroup(mask);
                
                if ~isempty(data)
                    x_pos = g;
                    x_jitter = x_pos + 0.1 * (rand(size(data)) - 0.5);
                    
                    % Получаем paramData из Map
                    color = [0 0 0]; % черный по умолчанию
                    paramLineWidth = 1; % по умолчанию
                    paramDataForLabel = [];
                    if isKey(displayLabelToFieldName, displayLabel)
                        fieldName = displayLabelToFieldName(displayLabel);
                        if isKey(paramDataByFieldName, fieldName)
                            paramDataForLabel = paramDataByFieldName(fieldName);
                            color = paramDataForLabel.parsedColor;
                            paramLineWidth = paramDataForLabel.lineWidth;
                        end
                    end
                    
                    % Размер маркера = lineWidth * 30
                    markerSize = paramLineWidth * 30;
                    
                    % Scatter с заполненными кругами и белым обрамлением
                    scatter(ax, x_jitter, data, markerSize, color, 'o', ...
                        'MarkerFaceColor', color, ...
                        'MarkerEdgeColor', 'white', ...
                        'LineWidth', paramLineWidth, ...
                        'MarkerFaceAlpha', 1);
                    
                    % Отображение File ID рядом с точками (если включено)
                    if state.showFileIds && ~isempty(fileIdsForLabel)
                        dataRange = max(data) - min(data);
                        if dataRange == 0
                            dataRange = abs(max(data)) * 0.01;
                            if dataRange == 0
                                dataRange = 1;
                            end
                        end
                        for i = 1:length(data)
                            if ~isnan(fileIdsForLabel(i))
                                text(ax, x_jitter(i) - 0.05, data(i) + 0.01 * dataRange, num2str(fileIdsForLabel(i)), ...
                                    'HorizontalAlignment', 'right', ...
                                    'VerticalAlignment', 'bottom', ...
                                    'FontSize', 7, ...
                                    'Color', [1 1 1], ...
                                    'BackgroundColor', [0 0 0], ...
                                    'Interpreter', 'none');
                            end
                        end
                    end
                    
                    % Отображение значений Y рядом с точками (если включено)
                    if state.showYValues
                        dataRange = max(data) - min(data);
                        if dataRange == 0
                            dataRange = abs(max(data)) * 0.01;
                            if dataRange == 0
                                dataRange = 1;
                            end
                        end
                        for i = 1:length(data)
                            text(ax, x_jitter(i) + 0.05, data(i) + 0.01 * dataRange, sprintf('%.3f', data(i)), ...
                                'HorizontalAlignment', 'left', ...
                                'VerticalAlignment', 'bottom', ...
                                'FontSize', 7, ...
                                'Color', [0 0 0], ...
                                'BackgroundColor', [1 1 1], ...
                                'Interpreter', 'none');
                        end
                    end
                    
                    % Аннотация n=X (используем медиану из stats)
                    medianVal = NaN;
                    if ~isempty(paramDataForLabel)
                        medianVal = paramDataForLabel.stats.median;
                    end
                    if isnan(medianVal)
                        medianVal = median(data);
                    end
                    text(ax, x_pos, medianVal, sprintf('n=%d', length(data)), ...
                        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
                        'FontSize', 9, 'BackgroundColor', 'white', ...
                        'Interpreter', 'none');
                end
            end
            
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
                
                % Сохраняем результаты тестов для этого полотна
                paramKey = sprintf('Group%d', groupNum);
                paramKeyValid = matlab.lang.makeValidName(paramKey);
                statisticalTests.(paramKeyValid) = testResultsForGroup;
                
                % Вывод статистических тестов в консоль
                if ~isempty(testResultsForGroup) && ~isempty(fieldnames(testResultsForGroup))
                    fprintf('\n=== Statistical Tests for Group %d ===\n', groupNum);
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
        
        % Формируем название для оси Y
        if length(paramsInGroup) == 1
            yLabelText = paramsInGroup{1}.column;
        else
            yLabelText = sprintf('Group %d', groupNum);
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
        
        % Скобки значимости (если статистика включена) - между параметрами на полотне
        if state.showStatistics
            paramKey = sprintf('Group%d', groupNum);
            paramKeyValid = matlab.lang.makeValidName(paramKey);
            
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



