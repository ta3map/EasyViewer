function boxplotFromTableGUI(filePath)
    % boxplotFromTableGUI - GUI для построения боксплотов из плоских таблиц
    % Поддерживает загрузку из MAT файлов (flatTable) и Excel файлов
    % Фильтрация данных через MATLAB формулы
    % 
    % Optional input:
    %   filePath - path to MAT file (with flatTable) or Excel file to load automatically
    
    % Загружаем глобальные настройки
    loadGlobalSettings();
    global SettingsFilepath
    
    if nargin < 1
        filePath = '';
    end
    
    figTag = 'boxplotFromTableGUI';
    guiFig = findobj('Type', 'figure', 'Tag', figTag);
    if ~isempty(guiFig)
        fig = guiFig;
        figure(fig);
        % If filePath provided and GUI already open, load the file
        if ~isempty(filePath)
            loadFileInGUI(fig, filePath);
        end
        return
    end
    
    % Создание главного окна
    fig = figure('Position', [10, 10, 1200, 650], ...
        'Name', 'Boxplot from Table', ...
        'NumberTitle', 'off', ...
        'MenuBar', 'none', ...
        'ToolBar', 'figure', ...
        'Resize', 'on', ...
        'Tag', figTag);
    
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
    state.yAxisRange = 'auto';
    state.yAxisMin = [];
    state.yAxisMax = [];
    state.title = 'Boxplot Comparison';
    state.filteredData = struct(); % Структура с отфильтрованными данными для каждого параметра
    state.plotMode = 'BoxPlot'; % Режим визуализации: 'BoxPlot' или 'Correlation'
    
    set(fig, 'UserData', state);
    
    % Создание UI элементов
    createUI(fig);
    
    % Загрузка координат если есть
    loadCoords(fig);
    
    % Загрузка состояния из глобальных настроек
    loadBoxplotStateFromGlobalSettings(fig);
    
    % Если передан путь к файлу, загружаем его автоматически (имеет приоритет)
    if ~isempty(filePath)
        loadFileInGUI(fig, filePath);
    end
end

function createUI(fig)
    state = get(fig, 'UserData');
    
    % Левая панель - настройки
    panelWidth = 400;
    figHeight = 900;
    margin = 10;
    lineHeight = 25;
    sectionSpacing = 10;
    buttonHeight = 35;
    
    % Загрузка данных
    loadActionPopup = uicontrol('Parent', fig, 'Style', 'popupmenu', ...
        'Position', [margin, 610, 150, 30], ...
        'String', {'Load File', 'Load State'}, ...
        'Tag', 'loadActionPopup', ...
        'Callback', @(~,~) loadActionCallback(fig));
    
    saveStateBtn = uicontrol('Parent', fig, 'Style', 'pushbutton', ...
        'Position', [160, 610, 90, 30], ...
        'String', 'Save State', ...
        'Callback', @(~,~) saveStateCallback(fig));
    
    filePathText = uicontrol('Parent', fig, 'Style', 'text', ...
        'Position', [250, 610, 140, 30], ...
        'String', 'No file loaded', ...
        'HorizontalAlignment', 'left', ...
        'Tag', 'filePathText');
    
    uicontrol('Parent', fig, 'Style', 'text', ...
        'Position', [margin, 570, 200, lineHeight], ...
        'String', 'Available Columns', ...
        'FontSize', 10, ...
        'HorizontalAlignment', 'left');
    
    columnsList = uicontrol('Parent', fig, 'Style', 'listbox', ...
        'Position', [margin, 505, panelWidth - 2*margin, 65], ...
        'String', {}, ...
        'Tag', 'columnsList', ...
        'Max', 2, ...
        'Callback', @(~,~) columnSelectedCallback(fig));
    
    addToAnalysisBtn = uicontrol('Parent', fig, 'Style', 'pushbutton', ...
        'Position', [margin, 500, 180, 25], ...
        'String', 'Add to Analysis', ...
        'Callback', @(~,~) addColumnToAnalysis(fig));
    
    clearAnalysisBtn = uicontrol('Parent', fig, 'Style', 'pushbutton', ...
        'Position', [190, 500, 180, 25], ...
        'String', 'Clear Analysis', ...
        'Callback', @(~,~) clearAnalysisColumns(fig));
    
    % Настройка анализа
    uicontrol('Parent', fig, 'Style', 'text', ...
        'Position', [margin, 460, 380, lineHeight], ...
        'String', 'Analysis Columns', ...
        'FontSize', 11, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'left');
    
    paramsTable = uitable('Parent', fig, ...
        'Position', [margin, 335, panelWidth - 2*margin, 120], ...
        'ColumnName', {'Group', 'Column', 'Filter', 'Label', 'Color', 'LineWidth'}, ...
        'ColumnEditable', [true, false, false, true, true, true], ...
        'ColumnWidth', {50, 100, 80, 80, 70, 70}, ...
        'Data', cell(0, 6), ...
        'Tag', 'paramsTable', ...
        'CellEditCallback', @(~,~) paramsTableEditCallback(fig), ...
        'CellSelectionCallback', @paramsTableSelectionCallback);
    
    editFilterBtn = uicontrol('Parent', fig, 'Style', 'pushbutton', ...
        'Position', [margin, 310, 180, 25], ...
        'String', 'Edit Filter', ...
        'Callback', @(~,~) editFilterCallback(fig));
    
    uicontrol('Parent', fig, 'Style', 'text', ...
        'Position', [margin, 275, 200, lineHeight], ...
        'String', 'Data Preview', ...
        'FontSize', 11, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'left');
    
    dataTable = uitable('Parent', fig, ...
        'Position', [margin, 200, panelWidth - 2*margin, 80], ...
        'ColumnEditable', false, ...
        'Tag', 'dataTable', ...
        'Data', cell(0, 1), ...
        'ColumnName', {'Value'});
    
    % Параметры визуализации
    uicontrol('Parent', fig, 'Style', 'text', ...
        'Position', [margin, 170, 200, lineHeight], ...
        'String', 'Visualization Options', ...
        'FontSize', 11, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'left');
    
    showStatsCheck = uicontrol('Parent', fig, 'Style', 'checkbox', ...
        'Position', [margin, 145, 200, 20], ...
        'String', 'Show Statistics', ...
        'Value', 1, ...
        'Tag', 'showStatsCheck', ...
        'Callback', @(~,~) updateStatsVisibility(fig));
    
    showAllPvaluesCheck = uicontrol('Parent', fig, 'Style', 'checkbox', ...
        'Position', [220, 145, 200, 20], ...
        'String', 'Show All P-values', ...
        'Value', 1, ...
        'Tag', 'showAllPvaluesCheck');
    
    showFileIdsCheck = uicontrol('Parent', fig, 'Style', 'checkbox', ...
        'Position', [margin, 115, 200, 20], ...
        'String', 'Show File IDs', ...
        'Value', 0, ...
        'Tag', 'showFileIdsCheck');
    
    showYValuesCheck = uicontrol('Parent', fig, 'Style', 'checkbox', ...
        'Position', [220, 115, 200, 20], ...
        'String', 'Show Y Values', ...
        'Value', 0, ...
        'Tag', 'showYValuesCheck');
    
    % Y-ось
    uicontrol('Parent', fig, 'Style', 'text', ...
        'Position', [margin, 85, 100, lineHeight], ...
        'String', 'Y-axis Range:', ...
        'FontSize', 10, ...
        'HorizontalAlignment', 'left');
    
    yAxisPopup = uicontrol('Parent', fig, 'Style', 'popupmenu', ...
        'Position', [110, 85, 150, 25], ...
        'String', {'Auto', 'Manual'}, ...
        'Tag', 'yAxisPopup', ...
        'Callback', @(~,~) updateYAxisControls(fig));
    
    yAxisMinEdit = uicontrol('Parent', fig, 'Style', 'edit', ...
        'Position', [270, 85, 60, 25], ...
        'String', '', ...
        'Visible', 'off', ...
        'Tag', 'yAxisMinEdit');
    
    yAxisMaxEdit = uicontrol('Parent', fig, 'Style', 'edit', ...
        'Position', [340, 85, 60, 25], ...
        'String', '', ...
        'Visible', 'off', ...
        'Tag', 'yAxisMaxEdit');
    
    % Заголовок
    uicontrol('Parent', fig, 'Style', 'text', ...
        'Position', [margin, 50, 100, lineHeight], ...
        'String', 'Title:', ...
        'FontSize', 10, ...
        'HorizontalAlignment', 'left');
    
    titleEdit = uicontrol('Parent', fig, 'Style', 'edit', ...
        'Position', [110, 50, 280, 25], ...
        'String', 'Boxplot Comparison', ...
        'Tag', 'titleEdit');
    
    % Режим визуализации (выпадающий список на месте кнопки Plot)
    plotModePopup = uicontrol('Parent', fig, 'Style', 'popupmenu', ...
        'Position', [margin, margin, 150, buttonHeight], ...
        'String', {'BoxPlot', 'Correlation'}, ...
        'Tag', 'plotModePopup', ...
        'Value', 1);
    
    % Кнопки (размещаем внизу с отступом)
    plotBtn = uicontrol('Parent', fig, 'Style', 'pushbutton', ...
        'Position', [margin + 160, margin, 150, buttonHeight], ...
        'String', 'Plot', ...
        'FontSize', 11, ...
        'Callback', @(~,~) plotBoxplotCallback(fig));
    
    exportBtn = uicontrol('Parent', fig, 'Style', 'pushbutton', ...
        'Position', [margin + 320, margin, 75, buttonHeight], ...
        'String', 'Export', ...
        'FontSize', 11, ...
        'Callback', @(~,~) exportPlotCallback(fig));
    
    % Область для графика
    plotPanel = uipanel('Parent', fig, ...
        'Position', [panelWidth/fig.Position(3), 0, 1 - panelWidth/fig.Position(3), 1], ...
        'Tag', 'plotPanel');
end

function loadFileCallback(fig)
    % Получаем начальную папку из глобальных настроек
    initialPath = getBoxplotInitialPath();
    
    % Сохраняем текущую директорию
    oldDir = pwd;
    
    try
        % Переходим в папку из настроек
        if exist(initialPath, 'dir')
            cd(initialPath);
        end
        
        [file, path] = uigetfile({'*.mat;*.xlsx;*.xls', 'Data Files (*.mat, *.xlsx, *.xls)'; ...
                                  '*.mat', 'MAT Files (*.mat)'; ...
                                  '*.xlsx;*.xls', 'Excel Files (*.xlsx, *.xls)'}, ...
                                 'Select Data File');
        
        % Возвращаемся в исходную директорию
        cd(oldDir);
        
        if isequal(file, 0)
            return
        end
        
        filePath = fullfile(path, file);
        loadFileInGUI(fig, filePath);
    catch ME
        % В случае ошибки возвращаемся в исходную директорию
        try
            cd(oldDir);
        catch
        end
        rethrow(ME);
    end
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

function saveStateCallback(fig)
    % Сохранение состояния в .meta файл
    state = get(fig, 'UserData');
    
    if isempty(state.filePath)
        errorMsg = 'Сначала загрузите файл с данными';
        fprintf('ERROR: %s\n', errorMsg);
        msgbox(errorMsg, 'Error', 'error');
        return
    end
    
    % Получаем начальную папку из глобальных настроек
    initialPath = getBoxplotInitialPath();
    
    % Сохраняем текущую директорию
    oldDir = pwd;
    
    try
        % Переходим в папку из настроек
        if exist(initialPath, 'dir')
            cd(initialPath);
        end
        
        [file, path] = uiputfile('*.meta', 'Save State', 'boxplot_state.meta');
        
        % Возвращаемся в исходную директорию
        cd(oldDir);
        
        if isequal(file, 0)
            return
        end
        
        filePath = fullfile(path, file);
    catch ME
        % В случае ошибки возвращаемся в исходную директорию
        try
            cd(oldDir);
        catch
        end
        rethrow(ME);
    end
    
    try
        % Сохраняем только необходимые поля для восстановления
        savedState = struct();
        savedState.filePath = state.filePath;
        savedState.parameters = state.parameters;
        savedState.nextGroupNumber = state.nextGroupNumber;
        savedState.showStatistics = state.showStatistics;
        savedState.showAllPvalues = state.showAllPvalues;
        savedState.showFileIds = state.showFileIds;
        savedState.showYValues = state.showYValues;
        savedState.yAxisRange = state.yAxisRange;
        savedState.yAxisMin = state.yAxisMin;
        savedState.yAxisMax = state.yAxisMax;
        savedState.title = state.title;
        savedState.plotMode = state.plotMode;
        
        save(filePath, 'savedState', '-mat');
        fprintf('State saved to: %s\n', filePath);
        
        % Сохраняем также в глобальные настройки
        saveBoxplotStateToGlobalSettings(fig);
    catch ME
        errorMsg = sprintf('Ошибка при сохранении: %s', ME.message);
        fprintf('ERROR: %s\n', errorMsg);
        msgbox(errorMsg, 'Error', 'error');
    end
end

function loadStateCallback(fig)
    % Загрузка состояния из .meta файла
    % Получаем начальную папку из глобальных настроек
    initialPath = getBoxplotInitialPath();
    
    % Сохраняем текущую директорию
    oldDir = pwd;
    
    try
        % Переходим в папку из настроек
        if exist(initialPath, 'dir')
            cd(initialPath);
        end
        
        [file, path] = uigetfile('*.meta', 'Load State');
        
        % Возвращаемся в исходную директорию
        cd(oldDir);
        
        if isequal(file, 0)
            return
        end
        
        filePath = fullfile(path, file);
    catch ME
        % В случае ошибки возвращаемся в исходную директорию
        try
            cd(oldDir);
        catch
        end
        rethrow(ME);
    end
    
    try
        data = load(filePath, '-mat');
        
        if ~isfield(data, 'savedState')
            errorMsg = 'Invalid state file format';
            fprintf('ERROR: %s\n', errorMsg);
            msgbox(errorMsg, 'Error', 'error');
            return
        end
        
        savedState = data.savedState;
        
        % Восстанавливаем состояние через вызовы функций
        % 1. Загружаем данные
        if isfield(savedState, 'filePath') && ~isempty(savedState.filePath)
            dataFilePath = savedState.filePath;
            
            if ~exist(dataFilePath, 'file')
                [statePath, ~, ~] = fileparts(filePath);
                
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
                        errorMsg = sprintf('Data file not found: %s\nAlso checked: %s', savedState.filePath, alternativePath);
                        fprintf('ERROR: %s\n', errorMsg);
                        msgbox(errorMsg, 'Error', 'error');
                        return
                    end
                else
                    errorMsg = sprintf('Data file not found: %s', savedState.filePath);
                    fprintf('ERROR: %s\n', errorMsg);
                    msgbox(errorMsg, 'Error', 'error');
                    return
                end
            end
            
            loadFileInGUI(fig, dataFilePath);
        else
            errorMsg = 'State file does not contain filePath';
            fprintf('ERROR: %s\n', errorMsg);
            msgbox(errorMsg, 'Error', 'error');
            return
        end
        
        % 2. Восстанавливаем параметры и настройки
        state = get(fig, 'UserData');
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
        if isfield(savedState, 'yAxisRange')
            state.yAxisRange = savedState.yAxisRange;
        end
        if isfield(savedState, 'yAxisMin')
            state.yAxisMin = savedState.yAxisMin;
        end
        if isfield(savedState, 'yAxisMax')
            state.yAxisMax = savedState.yAxisMax;
        end
        if isfield(savedState, 'title')
            state.title = savedState.title;
        end
        if isfield(savedState, 'plotMode')
            state.plotMode = savedState.plotMode;
        else
            state.plotMode = 'BoxPlot';
        end
        
        set(fig, 'UserData', state);
        
        % 3. Обновляем UI
        updateAnalysisColumnsDisplay(fig);
        
        % Обновляем выпадающий список режима
        plotModePopup = findobj(fig, 'Tag', 'plotModePopup');
        if ~isempty(plotModePopup)
            if strcmp(state.plotMode, 'Correlation')
                set(plotModePopup, 'Value', 2);
            else
                set(plotModePopup, 'Value', 1);
            end
        end
        
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
        
        titleEdit = findobj(fig, 'Tag', 'titleEdit');
        if ~isempty(titleEdit) && ~isempty(state.title)
            set(titleEdit, 'String', state.title);
        end
        
        updateYAxisControls(fig);
        
        % 4. Обновляем структуру filteredData
        updateFilteredDataStructure(fig);
        
        % 5. Синхронизируем с глобальными настройками
        saveBoxplotStateToGlobalSettings(fig);
        
        fprintf('State loaded from: %s\n', filePath);
    catch ME
        errorMsg = sprintf('Ошибка при загрузке: %s', ME.message);
        fprintf('ERROR: %s\n', errorMsg);
        msgbox(errorMsg, 'Error', 'error');
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
                errorMsg = 'MAT file does not contain variable "flatTable"';
                fprintf('ERROR: %s\n', errorMsg);
                msgbox(errorMsg, 'Error', 'error');
                return
            end
        elseif any(strcmpi(ext, {'.xlsx', '.xls'}))
            state.table = readtable(filePath);
        else
            errorMsg = 'Unsupported file format';
            fprintf('ERROR: %s\n', errorMsg);
            msgbox(errorMsg, 'Error', 'error');
            return
        end
        
        % Форматируем названия колонок
        state.table = boxplotFormatTableColumnNames(state.table);
        
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
        errorMsg = sprintf('Error loading file: %s', ME.message);
        fprintf('ERROR: %s\n', errorMsg);
        msgbox(errorMsg, 'Error', 'error');
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
    numStatsRows = 8; % n, mean, median, std, Q25, Q75, min, max
    statsLabels = {'n', 'mean', 'median', 'std', 'Q25', 'Q75', 'min', 'max'};
    
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

function paramsTableEditCallback(fig)
    % Callback при редактировании таблицы параметров
    state = get(fig, 'UserData');
    paramsTable = findobj(fig, 'Tag', 'paramsTable');
    
    if isempty(paramsTable) || isempty(state.parameters)
        return
    end
    
    tableData = get(paramsTable, 'Data');
    
    % Обновляем state.parameters из таблицы
    for i = 1:min(length(state.parameters), size(tableData, 1))
        % Group number
        newGroupNumber = tableData{i, 1};
        if isnumeric(newGroupNumber) && newGroupNumber > 0
            state.parameters{i}.groupNumber = newGroupNumber;
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
    yAxisPopup = findobj(fig, 'Tag', 'yAxisPopup');
    yAxisMinEdit = findobj(fig, 'Tag', 'yAxisMinEdit');
    yAxisMaxEdit = findobj(fig, 'Tag', 'yAxisMaxEdit');
    titleEdit = findobj(fig, 'Tag', 'titleEdit');
    plotModePopup = findobj(fig, 'Tag', 'plotModePopup');
    
    try
        % Определяем режим визуализации
        if ~isempty(plotModePopup)
            selectedValue = get(plotModePopup, 'Value');
            if selectedValue == 2
                state.plotMode = 'Correlation';
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
        if get(yAxisPopup, 'Value') == 1
            state.yAxisRange = 'auto';
        else
            state.yAxisRange = 'manual';
        end
        if strcmp(state.yAxisRange, 'manual')
            state.yAxisMin = str2double(get(yAxisMinEdit, 'String'));
            state.yAxisMax = str2double(get(yAxisMaxEdit, 'String'));
        end
        state.title = get(titleEdit, 'String');
        
        set(fig, 'UserData', state);
        
        % Создаем прогресс-бар
        figPos = get(fig, 'Position');
        if strcmp(state.plotMode, 'Correlation')
            wbName = 'Correlation Plot Generation';
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
            errorMsg = sprintf('Ошибка при построении графика: %s', ME.message);
            fprintf('ERROR: %s\n', errorMsg);
            msgbox(errorMsg, 'Error', 'error');
            debugState('boxplotFromTableGUI', 'Error: %s', ME.message);
        end
        
    catch ME
        errorMsg = sprintf('Ошибка при построении графика: %s', ME.message);
        fprintf('ERROR: %s\n', errorMsg);
        msgbox(errorMsg, 'Error', 'error');
        debugState('boxplotFromTableGUI', 'Error: %s', ME.message);
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
                errorMsg = 'Неподдерживаемый формат файла';
                fprintf('ERROR: %s\n', errorMsg);
                msgbox(errorMsg, 'Error', 'error');
                close(exportFig);
                return
        end
        
        close(exportFig);
    catch ME
        errorMsg = sprintf('Ошибка при экспорте: %s', ME.message);
        fprintf('ERROR: %s\n', errorMsg);
        msgbox(errorMsg, 'Error', 'error');
        debugState('boxplotFromTableGUI', 'Export error: %s', ME.message);
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

function loadCoords(fig)
    coordsFile = fullfile(fileparts(mfilename('fullpath')), '..', 'boxplotFromTableGUI_coords.json');
    if exist(coordsFile, 'file')
        try
            coords = jsondecode(fileread(coordsFile));
            if isfield(coords, 'position')
                fig.Position = coords.position;
            end
        catch
            % Игнорируем ошибки загрузки координат
        end
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
    
    % Создаем структуру для сохранения (исключаем большие данные)
    boxplot_state = struct();
    boxplot_state.filePath = state.filePath;
    boxplot_state.parameters = state.parameters;
    boxplot_state.nextGroupNumber = state.nextGroupNumber;
    boxplot_state.showStatistics = state.showStatistics;
    boxplot_state.showAllPvalues = state.showAllPvalues;
    boxplot_state.showFileIds = state.showFileIds;
    boxplot_state.showYValues = state.showYValues;
    boxplot_state.yAxisRange = state.yAxisRange;
    boxplot_state.yAxisMin = state.yAxisMin;
    boxplot_state.yAxisMax = state.yAxisMax;
    boxplot_state.title = state.title;
    boxplot_state.plotMode = state.plotMode;
    
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
        
        % Сохраняем параметры перед загрузкой файла (loadFileInGUI очищает их)
        savedParameters = {};
        savedNextGroupNumber = 1;
        if isfield(savedState, 'parameters')
            savedParameters = savedState.parameters;
        end
        if isfield(savedState, 'nextGroupNumber')
            savedNextGroupNumber = savedState.nextGroupNumber;
        end
        
        % 1. Сначала загружаем файл если есть
        if isfield(savedState, 'filePath') && ...
           ~isempty(savedState.filePath) && ...
           exist(savedState.filePath, 'file')
            loadFileInGUI(fig, savedState.filePath);
        end
        
        % 2. Восстанавливаем параметры и настройки после загрузки файла
        state = get(fig, 'UserData');
        state.parameters = savedParameters;
        state.nextGroupNumber = savedNextGroupNumber;
        
        if isfield(savedState, 'showStatistics')
            state.showStatistics = savedState.showStatistics;
        end
        if isfield(savedState, 'showAllPvalues')
            state.showAllPvalues = savedState.showAllPvalues;
        end
        if isfield(savedState, 'showFileIds')
            state.showFileIds = savedState.showFileIds;
        end
        if isfield(savedState, 'showYValues')
            state.showYValues = savedState.showYValues;
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
        if isfield(savedState, 'title')
            state.title = savedState.title;
        end
        if isfield(savedState, 'plotMode')
            state.plotMode = savedState.plotMode;
        else
            state.plotMode = 'BoxPlot';
        end
        
        set(fig, 'UserData', state);
        
        % 3. Обновляем UI
        updateAnalysisColumnsDisplay(fig);
        updateUIFromState(fig);
        
        % 4. Обновляем структуру filteredData
        updateFilteredDataStructure(fig);
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
    
    titleEdit = findobj(fig, 'Tag', 'titleEdit');
    if ~isempty(titleEdit) && ~isempty(state.title)
        set(titleEdit, 'String', state.title);
    end
    
    % Обновляем выпадающий список режима
    plotModePopup = findobj(fig, 'Tag', 'plotModePopup');
    if ~isempty(plotModePopup)
        if isfield(state, 'plotMode') && strcmp(state.plotMode, 'Correlation')
            set(plotModePopup, 'Value', 2);
        else
            set(plotModePopup, 'Value', 1);
        end
    end
    
    updateYAxisControls(fig);
    updateAnalysisColumnsDisplay(fig);
end

% ============================================================================
% Вспомогательные функции парсинга и обработки данных
% ============================================================================


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
                    filteredData = filteredTable{:, columnName};
                    validIndices = ~isnan(filteredData) & ~isinf(filteredData);
                    filteredData = filteredData(validIndices);
                    % Извлекаем File ID для валидных строк
                    if ismember('FileID', filteredTable.Properties.VariableNames)
                        fileIds = filteredTable{validIndices, 'FileID'};
                    end
                end
            end
        else
            % Нет фильтра - используем все данные
            filteredData = state.table{:, columnName};
            validIndices = ~isnan(filteredData) & ~isinf(filteredData);
            filteredData = filteredData(validIndices);
            % Извлекаем File ID для валидных строк
            if ismember('FileID', state.table.Properties.VariableNames)
                fileIds = state.table{validIndices, 'FileID'};
            end
        end
        
        % Рассчитываем статистику для отфильтрованных данных
        stats = struct();
        if ~isempty(filteredData)
            stats.mean = mean(filteredData);
            stats.std = std(filteredData);
            stats.median = median(filteredData);
            stats.q25 = prctile(filteredData, 25);
            stats.q75 = prctile(filteredData, 75);
            stats.min = min(filteredData);
            stats.max = max(filteredData);
            stats.count = length(filteredData);
        else
            stats.mean = NaN;
            stats.std = NaN;
            stats.median = NaN;
            stats.q25 = NaN;
            stats.q75 = NaN;
            stats.min = NaN;
            stats.max = NaN;
            stats.count = 0;
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
    
    % Группируем параметры по фильтру
    filterGroups = containers.Map();
    for i = 1:length(filteredDataFields)
        fieldName = filteredDataFields{i};
        paramData = state.filteredData.(fieldName);
        if ~isstruct(paramData)
            continue
        end
        
        filterKey = paramData.filter;
        if isempty(filterKey)
            filterKey = '';
        end
        
        if ~isKey(filterGroups, filterKey)
            filterGroups(filterKey) = {};
        end
        paramData.fieldName = fieldName;
        filterGroups(filterKey) = [filterGroups(filterKey), {paramData}];
    end
    
    % Подсчитываем общее количество графиков (пар + одиночные)
    totalPlots = 0;
    filterKeys = keys(filterGroups);
    for i = 1:length(filterKeys)
        filterKey = filterKeys{i};
        paramsInFilter = filterGroups(filterKey);
        numParams = length(paramsInFilter);
        % Количество пар
        numPairs = floor(numParams / 2);
        totalPlots = totalPlots + numPairs;
        % Если нечетное количество, добавляем одиночный график
        if mod(numParams, 2) == 1
            totalPlots = totalPlots + 1;
        end
    end
    
    if totalPlots == 0
        return
    end
    
    % Вычисляем позиции для subplots
    margin = 0.05;
    spacing = 0.03;
    totalHeight = 1 - 2*margin;
    subplotHeight = (totalHeight - (totalPlots - 1) * spacing) / totalPlots;
    
    plotIdx = 1;
    
    % Обрабатываем каждую группу фильтров
    for filterIdx = 1:length(filterKeys)
        filterKey = filterKeys{filterIdx};
        paramsInFilter = filterGroups(filterKey);
        
        % Формируем пары по порядку следования
        numParams = length(paramsInFilter);
        numPairs = floor(numParams / 2);
        
        % Строим пары
        for pairIdx = 1:numPairs
            param1 = paramsInFilter{2*pairIdx - 1};
            param2 = paramsInFilter{2*pairIdx};
            
            if isempty(param1.data) || isempty(param2.data)
                continue
            end
            
            % Вычисляем позицию subplot
            subplotBottom = 1 - margin - plotIdx * subplotHeight - (plotIdx - 1) * spacing;
            subplotPosition = [0.1, subplotBottom, 0.85, subplotHeight];
            
            ax = axes('Parent', plotPanel, 'Position', subplotPosition);
            hold(ax, 'on');
            
            % Получаем данные
            xData = param1.data;
            yData = param2.data;
            
            % Синхронизируем размеры данных (берем минимум)
            minLength = min(length(xData), length(yData));
            xData = xData(1:minLength);
            yData = yData(1:minLength);
            
            % Удаляем NaN и Inf
            validIndices = ~isnan(xData) & ~isnan(yData) & ~isinf(xData) & ~isinf(yData);
            xData = xData(validIndices);
            yData = yData(validIndices);
            
            if length(xData) < 2
                delete(ax);
                continue
            end
            
            % Получаем цвета и метки
            color1 = param1.parsedColor;
            color2 = param2.parsedColor;
            % Используем средний цвет для точек
            pointColor = (color1 + color2) / 2;
            lineColor = color1;
            
            label1 = param1.label;
            if isempty(label1)
                label1 = param1.column;
            end
            label2 = param2.label;
            if isempty(label2)
                label2 = param2.column;
            end
            
            % Scatter plot
            scatter(ax, xData, yData, 50, pointColor, 'o', ...
                'MarkerFaceColor', pointColor, ...
                'MarkerEdgeColor', 'white', ...
                'LineWidth', 1, ...
                'MarkerFaceAlpha', 0.7);
            
            % Линия регрессии
            p = polyfit(xData, yData, 1);
            xFit = linspace(min(xData), max(xData), 100);
            yFit = polyval(p, xFit);
            plot(ax, xFit, yFit, 'Color', lineColor, 'LineWidth', 2, 'LineStyle', '--');
            
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
            
            % Подписи осей
            xlabel(ax, label1);
            ylabel(ax, label2);
            
            % Заголовок с корреляцией
            if ~isnan(corrCoeff) && ~isnan(pValue)
                titleStr = sprintf('R=%.3f, R²=%.3f, p=%.4f, n=%d', corrCoeff, R2, pValue, length(xData));
            else
                titleStr = sprintf('n=%d', length(xData));
            end
            title(ax, titleStr, 'FontSize', 10);
            
            % Сетка
            grid(ax, 'on');
            
            plotIdx = plotIdx + 1;
        end
        
        % Если нечетное количество параметров, показываем последний отдельно
        if mod(numParams, 2) == 1
            param = paramsInFilter{end};
            
            if ~isempty(param.data)
                % Вычисляем позицию subplot
                subplotBottom = 1 - margin - plotIdx * subplotHeight - (plotIdx - 1) * spacing;
                subplotPosition = [0.1, subplotBottom, 0.85, subplotHeight];
                
                ax = axes('Parent', plotPanel, 'Position', subplotPosition);
                hold(ax, 'on');
                
                data = param.data;
                validIndices = ~isnan(data) & ~isinf(data);
                data = data(validIndices);
                
                if length(data) > 0
                    label = param.label;
                    if isempty(label)
                        label = param.column;
                    end
                    
                    % Простой scatter plot по индексам
                    scatter(ax, 1:length(data), data, 50, param.parsedColor, 'o', ...
                        'MarkerFaceColor', param.parsedColor, ...
                        'MarkerEdgeColor', 'white', ...
                        'LineWidth', 1, ...
                        'MarkerFaceAlpha', 0.7);
                    
                    xlabel(ax, 'Index');
                    ylabel(ax, label);
                    title(ax, sprintf('Single parameter: n=%d', length(data)), 'FontSize', 10);
                    grid(ax, 'on');
                else
                    delete(ax);
                end
                
                plotIdx = plotIdx + 1;
            end
        end
    end
    
    % Добавляем общий заголовок для первого subplot
    allAxes = findobj(plotPanel, 'Type', 'axes');
    if ~isempty(allAxes)
        title(allAxes(1), state.title, 'FontSize', 14, 'FontWeight', 'bold');
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
        
        % Вычисляем позицию для subplot внутри панели
        margin = 0.05;
        spacing = 0.03; % увеличен на 10% (было 0.02)
        totalHeight = 1 - 2*margin;
        subplotHeight = (totalHeight - (nPlotGroups - 1) * spacing) / nPlotGroups;
        subplotBottom = 1 - margin - plotGroupIdx * subplotHeight - (plotGroupIdx - 1) * spacing;
        subplotPosition = [0.1, subplotBottom, 0.85, subplotHeight];
        
        ax = axes('Parent', plotPanel, 'Position', subplotPosition);
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
                                    'BackgroundColor', [0 0 0]);
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
                                'BackgroundColor', [1 1 1]);
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
                        'FontSize', 9, 'BackgroundColor', 'white');
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
        ylabel(ax, yLabelText);
        if plotGroupIdx == nPlotGroups
            xlabel(ax, 'Groups');
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
        
        % Добавляем заголовок для первого subplot
        if plotGroupIdx == 1
            title(ax, state.title, 'FontSize', 14, 'FontWeight', 'bold');
        end
    end
    
    % Активация инструментов для всех axes в панели
    allAxes = findobj(plotPanel, 'Type', 'axes');
    if ~isempty(allAxes)
        zoom(fig, 'on');
        pan(fig, 'on');
    end
end



