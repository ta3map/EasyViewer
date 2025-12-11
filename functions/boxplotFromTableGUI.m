function boxplotFromTableGUI(filePath)
    % boxplotFromTableGUI - GUI для построения боксплотов из плоских таблиц
    % Поддерживает загрузку из MAT файлов (flatTable) и Excel файлов
    % Фильтрация данных через MATLAB формулы в формате: A: условие1; B: условие2
    % 
    % Optional input:
    %   filePath - path to MAT file (with flatTable) or Excel file to load automatically
    
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
    fig = figure('Position', [100, 100, 1200, 900], ...
        'Name', 'Boxplot from Table', ...
        'NumberTitle', 'off', ...
        'MenuBar', 'none', ...
        'ToolBar', 'none', ...
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
    state.showStatistics = true;
    state.showAllPvalues = true;
    state.yAxisRange = 'auto';
    state.yAxisMin = [];
    state.yAxisMax = [];
    state.title = 'Boxplot Comparison';
    
    set(fig, 'UserData', state);
    
    % Создание UI элементов
    createUI(fig);
    
    % Загрузка координат если есть
    loadCoords(fig);
    
    % Если передан путь к файлу, загружаем его автоматически
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
    
    % Текущая Y позиция (сверху вниз)
    yPos = figHeight - margin;
    
    % Загрузка данных
    yPos = yPos - lineHeight;
    uicontrol('Parent', fig, 'Style', 'text', ...
        'Position', [margin, yPos, 200, lineHeight], ...
        'String', 'Data Loading', ...
        'FontSize', 11, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'left');
    
    yPos = yPos - lineHeight - 5;
    loadBtn = uicontrol('Parent', fig, 'Style', 'pushbutton', ...
        'Position', [margin, yPos, 150, 30], ...
        'String', 'Load File', ...
        'Callback', @(~,~) loadFileCallback(fig));
    
    filePathText = uicontrol('Parent', fig, 'Style', 'text', ...
        'Position', [170, yPos, 220, 30], ...
        'String', 'No file loaded', ...
        'HorizontalAlignment', 'left', ...
        'Tag', 'filePathText');
    
    yPos = yPos - 35 - sectionSpacing;
    uicontrol('Parent', fig, 'Style', 'text', ...
        'Position', [margin, yPos, 200, lineHeight], ...
        'String', 'Available Columns', ...
        'FontSize', 10, ...
        'HorizontalAlignment', 'left');
    
    yPos = yPos - lineHeight - 5;
    columnsList = uicontrol('Parent', fig, 'Style', 'listbox', ...
        'Position', [margin, yPos - 80, panelWidth - 2*margin, 80], ...
        'String', {}, ...
        'Tag', 'columnsList', ...
        'Max', 2, ...
        'Callback', @(~,~) columnSelectedCallback(fig));
    
    yPos = yPos - 85 - 5;
    addToAnalysisBtn = uicontrol('Parent', fig, 'Style', 'pushbutton', ...
        'Position', [margin, yPos, 180, 25], ...
        'String', 'Add to Analysis', ...
        'Callback', @(~,~) addColumnToAnalysis(fig));
    
    clearAnalysisBtn = uicontrol('Parent', fig, 'Style', 'pushbutton', ...
        'Position', [190, yPos, 180, 25], ...
        'String', 'Clear Analysis', ...
        'Callback', @(~,~) clearAnalysisColumns(fig));
    
    yPos = yPos - 30 - sectionSpacing;
    
    % Настройка анализа
    uicontrol('Parent', fig, 'Style', 'text', ...
        'Position', [margin, yPos, 380, lineHeight], ...
        'String', 'Analysis Columns', ...
        'FontSize', 11, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'left');
    
    yPos = yPos - lineHeight - 5;
    paramsTextarea = uicontrol('Parent', fig, 'Style', 'edit', ...
        'Position', [margin, yPos - 40, panelWidth - 2*margin, 40], ...
        'String', '', ...
        'Max', 10, 'Min', 0, ...
        'Enable', 'off', ...
        'HorizontalAlignment', 'left', ...
        'Tag', 'paramsTextarea');
    
    yPos = yPos - 45 - sectionSpacing;
    
    uicontrol('Parent', fig, 'Style', 'text', ...
        'Position', [margin, yPos, 200, lineHeight], ...
        'String', 'Column Data Preview', ...
        'FontSize', 10, ...
        'HorizontalAlignment', 'left');
    
    yPos = yPos - lineHeight - 5;
    dataTable = uitable('Parent', fig, ...
        'Position', [margin, yPos - 80, panelWidth - 2*margin, 80], ...
        'ColumnEditable', false, ...
        'Tag', 'dataTable', ...
        'Data', cell(0, 1), ...
        'ColumnName', {'Value'});
    
    yPos = yPos - 85 - sectionSpacing;
    
    % Настройка фильтров
    uicontrol('Parent', fig, 'Style', 'text', ...
        'Position', [margin, yPos, 380, lineHeight], ...
        'String', 'Group Filters (A: condition1; B: condition2)', ...
        'FontSize', 11, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'left');
    
    yPos = yPos - lineHeight - 5;
    filtersTextarea = uicontrol('Parent', fig, 'Style', 'edit', ...
        'Position', [margin, yPos - 80, panelWidth - 2*margin, 80], ...
        'String', '', ...
        'Max', 10, 'Min', 0, ...
        'HorizontalAlignment', 'left', ...
        'Tag', 'filtersTextarea');
    
    yPos = yPos - 85 - 5;
    checkFiltersBtn = uicontrol('Parent', fig, 'Style', 'pushbutton', ...
        'Position', [margin, yPos, 150, 25], ...
        'String', 'Check Filters', ...
        'Callback', @(~,~) checkFiltersCallback(fig));
    
    yPos = yPos - 25 - sectionSpacing;
    
    % Кастомные подписи
    uicontrol('Parent', fig, 'Style', 'text', ...
        'Position', [margin, yPos, 200, lineHeight], ...
        'String', 'Group Labels (A:Label1,B:Label2)', ...
        'FontSize', 10, ...
        'HorizontalAlignment', 'left');
    
    yPos = yPos - lineHeight - 5;
    labelsTextarea = uicontrol('Parent', fig, 'Style', 'edit', ...
        'Position', [margin, yPos, panelWidth - 2*margin, 20], ...
        'String', '', ...
        'Max', 2, 'Min', 0, ...
        'HorizontalAlignment', 'left', ...
        'Tag', 'labelsTextarea');
    
    yPos = yPos - 25 - sectionSpacing;
    
    % Цвета групп
    uicontrol('Parent', fig, 'Style', 'text', ...
        'Position', [margin, yPos, 200, lineHeight], ...
        'String', 'Group Colors (A:#FF0000,B:#00FF00)', ...
        'FontSize', 10, ...
        'HorizontalAlignment', 'left');
    
    yPos = yPos - lineHeight - 5;
    colorsTextarea = uicontrol('Parent', fig, 'Style', 'edit', ...
        'Position', [margin, yPos, panelWidth - 2*margin, 20], ...
        'String', '', ...
        'Max', 2, 'Min', 0, ...
        'HorizontalAlignment', 'left', ...
        'Tag', 'colorsTextarea');
    
    yPos = yPos - 25 - sectionSpacing;
    
    % Параметры визуализации
    uicontrol('Parent', fig, 'Style', 'text', ...
        'Position', [margin, yPos, 200, lineHeight], ...
        'String', 'Visualization Options', ...
        'FontSize', 11, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'left');
    
    yPos = yPos - lineHeight - 5;
    showStatsCheck = uicontrol('Parent', fig, 'Style', 'checkbox', ...
        'Position', [margin, yPos, 200, 20], ...
        'String', 'Show Statistics', ...
        'Value', 1, ...
        'Tag', 'showStatsCheck', ...
        'Callback', @(~,~) updateStatsVisibility(fig));
    
    showAllPvaluesCheck = uicontrol('Parent', fig, 'Style', 'checkbox', ...
        'Position', [220, yPos, 200, 20], ...
        'String', 'Show All P-values', ...
        'Value', 1, ...
        'Tag', 'showAllPvaluesCheck');
    
    yPos = yPos - 25 - 5;
    
    % Y-ось
    uicontrol('Parent', fig, 'Style', 'text', ...
        'Position', [margin, yPos, 100, lineHeight], ...
        'String', 'Y-axis Range:', ...
        'FontSize', 10, ...
        'HorizontalAlignment', 'left');
    
    yAxisPopup = uicontrol('Parent', fig, 'Style', 'popupmenu', ...
        'Position', [110, yPos, 150, 25], ...
        'String', {'Auto', 'Manual'}, ...
        'Tag', 'yAxisPopup', ...
        'Callback', @(~,~) updateYAxisControls(fig));
    
    yAxisMinEdit = uicontrol('Parent', fig, 'Style', 'edit', ...
        'Position', [270, yPos, 60, 25], ...
        'String', '', ...
        'Visible', 'off', ...
        'Tag', 'yAxisMinEdit');
    
    yAxisMaxEdit = uicontrol('Parent', fig, 'Style', 'edit', ...
        'Position', [340, yPos, 60, 25], ...
        'String', '', ...
        'Visible', 'off', ...
        'Tag', 'yAxisMaxEdit');
    
    yPos = yPos - 30 - 5;
    
    % Заголовок
    uicontrol('Parent', fig, 'Style', 'text', ...
        'Position', [margin, yPos, 100, lineHeight], ...
        'String', 'Title:', ...
        'FontSize', 10, ...
        'HorizontalAlignment', 'left');
    
    titleEdit = uicontrol('Parent', fig, 'Style', 'edit', ...
        'Position', [110, yPos, 280, 25], ...
        'String', 'Boxplot Comparison', ...
        'Tag', 'titleEdit');
    
    yPos = yPos - 30 - sectionSpacing;
    
    % Кнопки (размещаем внизу с отступом)
    buttonY = margin + buttonHeight;
    plotBtn = uicontrol('Parent', fig, 'Style', 'pushbutton', ...
        'Position', [margin, margin, 150, buttonHeight], ...
        'String', 'Plot', ...
        'FontSize', 11, ...
        'Callback', @(~,~) plotBoxplotCallback(fig));
    
    exportBtn = uicontrol('Parent', fig, 'Style', 'pushbutton', ...
        'Position', [160, margin, 150, buttonHeight], ...
        'String', 'Export Plot', ...
        'FontSize', 11, ...
        'Callback', @(~,~) exportPlotCallback(fig));
    
    % Область для графика
    plotPanel = uipanel('Parent', fig, ...
        'Position', [panelWidth/fig.Position(3), 0, 1 - panelWidth/fig.Position(3), 1], ...
        'Tag', 'plotPanel');
end

function loadFileCallback(fig)
    [file, path] = uigetfile({'*.mat;*.xlsx;*.xls', 'Data Files (*.mat, *.xlsx, *.xls)'; ...
                              '*.mat', 'MAT Files (*.mat)'; ...
                              '*.xlsx;*.xls', 'Excel Files (*.xlsx, *.xls)'}, ...
                             'Select Data File');
    
    if isequal(file, 0)
        return
    end
    
    filePath = fullfile(path, file);
    loadFileInGUI(fig, filePath);
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
                msgbox('MAT file does not contain variable "flatTable"', 'Error', 'error');
                return
            end
        elseif any(strcmpi(ext, {'.xlsx', '.xls'}))
            state.table = readtable(filePath);
        else
            msgbox('Unsupported file format', 'Error', 'error');
            return
        end
        
        state.filePath = filePath;
        state.parameters = {};
        set(fig, 'UserData', state);
        
        % Update UI
        filePathText = findobj(fig, 'Tag', 'filePathText');
        if ~isempty(filePathText)
            set(filePathText, 'String', truncatePath(filePath));
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
        
        msgbox(sprintf('File loaded: %d rows, %d columns', ...
            height(state.table), width(state.table)), 'Success', 'help');
    catch ME
        msgbox(sprintf('Error loading file: %s', ME.message), 'Error', 'error');
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

function addColumnToAnalysis(fig)
    % Добавление выбранных колонок в поле анализа
    state = get(fig, 'UserData');
    if isempty(state.table)
        msgbox('Сначала загрузите файл с данными', 'Warning', 'warn');
        return
    end
    
    columnsList = findobj(fig, 'Tag', 'columnsList');
    paramsTextarea = findobj(fig, 'Tag', 'paramsTextarea');
    filtersTextarea = findobj(fig, 'Tag', 'filtersTextarea');
    
    if isempty(columnsList) || isempty(paramsTextarea)
        return
    end
    
    selectedIdx = get(columnsList, 'Value');
    columnNames = get(columnsList, 'String');
    
    if isempty(selectedIdx) || isempty(columnNames)
        msgbox('Выберите колонку из списка', 'Warning', 'warn');
        return
    end
    
    % Обработка множественного выбора
    if ~isnumeric(selectedIdx)
        selectedIdx = double(selectedIdx);
    end
    
    % Определяем следующую букву алфавита
    usedLetters = {};
    for i = 1:length(state.parameters)
        if ~isempty(state.parameters{i}.group)
            usedLetters{end+1} = state.parameters{i}.group;
        end
    end
    usedLetters = unique(usedLetters);
    
    % Находим следующую свободную букву
    nextLetter = 'A';
    if ~isempty(usedLetters)
        for i = 1:26
            letter = char('A' + i - 1);
            if ~ismember(letter, usedLetters)
                nextLetter = letter;
                break
            end
        end
    end
    
    % Добавляем выбранные колонки с буквой
    for i = 1:length(selectedIdx)
        if selectedIdx(i) <= length(columnNames)
            colName = columnNames{selectedIdx(i)};
            % Проверяем, не добавлена ли уже эта колонка
            exists = false;
            for k = 1:length(state.parameters)
                if strcmp(state.parameters{k}.column, colName)
                    exists = true;
                    break
                end
            end
            if ~exists
                state.parameters{end+1} = struct('group', nextLetter, 'column', colName);
                % Переходим к следующей букве
                nextLetter = char(nextLetter + 1);
            end
        end
    end
    
    set(fig, 'UserData', state);
    updateAnalysisColumnsDisplay(fig);
end

function clearAnalysisColumns(fig)
    % Очистка поля анализа
    state = get(fig, 'UserData');
    state.parameters = {};
    set(fig, 'UserData', state);
    updateAnalysisColumnsDisplay(fig);
end

function updateAnalysisColumnsDisplay(fig)
    % Обновление отображения списка колонок для анализа
    state = get(fig, 'UserData');
    paramsTextarea = findobj(fig, 'Tag', 'paramsTextarea');
    filtersTextarea = findobj(fig, 'Tag', 'filtersTextarea');
    
    if isempty(paramsTextarea)
        return
    end
    
    if isempty(state.parameters)
        set(paramsTextarea, 'String', '');
        return
    end
    
    % Формируем строки для отображения
    displayLines = cell(length(state.parameters), 1);
    for i = 1:length(state.parameters)
        displayLines{i} = sprintf('%s: %s', state.parameters{i}.group, state.parameters{i}.column);
    end
    
    set(paramsTextarea, 'String', strjoin(displayLines, '\n'));
end

function checkFiltersCallback(fig)
    state = get(fig, 'UserData');
    if isempty(state.table)
        msgbox('Сначала загрузите файл с данными', 'Warning', 'warn');
        return
    end
    
    filtersTextarea = findobj(fig, 'Tag', 'filtersTextarea');
    filtersStr = get(filtersTextarea, 'String');
    
    try
        groupFilters = parseGroupFilters(filtersStr);
        diagnosis = diagnoseFiltering(state.table, groupFilters);
        
        % Показываем диагностику в отдельном окне
        diagFig = figure('Position', [200, 200, 600, 400], ...
            'Name', 'Диагностика фильтрации', ...
            'NumberTitle', 'off', ...
            'MenuBar', 'none');
        
        uicontrol('Parent', diagFig, 'Style', 'edit', ...
            'Position', [10, 10, 580, 380], ...
            'String', diagnosis, ...
            'Max', 100, 'Min', 0, ...
            'HorizontalAlignment', 'left', ...
            'Enable', 'inactive');
    catch ME
        msgbox(sprintf('Ошибка при проверке фильтров: %s', ME.message), 'Error', 'error');
    end
end

function plotBoxplotCallback(fig)
    state = get(fig, 'UserData');
    if isempty(state.table)
        msgbox('Сначала загрузите файл с данными', 'Warning', 'warn');
        return
    end
    
    % Получение параметров из UI
    filtersTextarea = findobj(fig, 'Tag', 'filtersTextarea');
    paramsTextarea = findobj(fig, 'Tag', 'paramsTextarea');
    labelsTextarea = findobj(fig, 'Tag', 'labelsTextarea');
    colorsTextarea = findobj(fig, 'Tag', 'colorsTextarea');
    showStatsCheck = findobj(fig, 'Tag', 'showStatsCheck');
    showAllPvaluesCheck = findobj(fig, 'Tag', 'showAllPvaluesCheck');
    yAxisPopup = findobj(fig, 'Tag', 'yAxisPopup');
    yAxisMinEdit = findobj(fig, 'Tag', 'yAxisMinEdit');
    yAxisMaxEdit = findobj(fig, 'Tag', 'yAxisMaxEdit');
    titleEdit = findobj(fig, 'Tag', 'titleEdit');
    
    try
        % Получение параметров
        groupFilters = parseGroupFilters(get(filtersTextarea, 'String'));
        parameters = state.parameters;
        
        groupLabels = parseGroupLabels(get(labelsTextarea, 'String'));
        groupColors = parseGroupColors(get(colorsTextarea, 'String'));
        
        state.showStatistics = get(showStatsCheck, 'Value');
        state.showAllPvalues = get(showAllPvaluesCheck, 'Value');
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
        
        % Применение фильтров
        filteredTable = applyGroupFilters(state.table, groupFilters);
        if isempty(filteredTable)
            msgbox('После фильтрации не осталось данных', 'Warning', 'warn');
            return
        end
        
        % Расчет статистики
        groupStats = calculateGroupStatistics(filteredTable, parameters, 'group_label');
        
        % Статистические тесты
        statisticalTests = struct();
        if state.showStatistics
            statisticalTests = performStatisticalTests(filteredTable, parameters, 'group_label');
        end
        
        % Дебаг перед построением
        debugState('boxplotFromTableGUI', 'Before createBoxplotFigure:');
        debugState('boxplotFromTableGUI', '  filteredTable size: %d x %d', height(filteredTable), width(filteredTable));
        debugState('boxplotFromTableGUI', '  parameters count: %d', length(parameters));
        for i = 1:length(parameters)
            debugState('boxplotFromTableGUI', '    param %d: group=%s, column=%s', i, parameters{i}.group, parameters{i}.column);
        end
        debugState('boxplotFromTableGUI', '  unique groups in table: %s', strjoin(unique(filteredTable{:, 'group_label'}), ', '));
        
        % Построение графика
        createBoxplotFigure(filteredTable, parameters, groupStats, statisticalTests, ...
            groupLabels, groupColors, state);
        
    catch ME
        msgbox(sprintf('Ошибка при построении графика: %s', ME.message), 'Error', 'error');
        debugState('boxplotFromTableGUI', 'Error: %s', ME.message);
    end
end

function exportPlotCallback(fig)
    % Экспорт текущего графика в различные форматы
    
    % Находим последнее открытое окно с графиком
    allFigs = findobj('Type', 'figure');
    plotFig = [];
    
    for i = 1:length(allFigs)
        if ~isempty(allFigs(i).Children) && any(strcmp(get(allFigs(i).Children, 'Type'), 'axes'))
            % Проверяем, что это не главное GUI окно
            if ~strcmp(get(allFigs(i), 'Tag'), 'boxplotFromTableGUI')
                plotFig = allFigs(i);
                break
            end
        end
    end
    
    if isempty(plotFig)
        msgbox('Сначала постройте график', 'Warning', 'warn');
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
        figure(plotFig); % Делаем окно активным
        
        switch lower(ext)
            case '.png'
                print(plotFig, '-dpng', '-r300', filePath);
            case '.pdf'
                print(plotFig, '-dpdf', '-r300', filePath);
            case '.fig'
                savefig(plotFig, filePath);
            case '.eps'
                print(plotFig, '-depsc', '-r300', filePath);
            otherwise
                msgbox('Неподдерживаемый формат файла', 'Error', 'error');
                return
        end
        
        msgbox(sprintf('График сохранен: %s', filePath), 'Success', 'help');
    catch ME
        msgbox(sprintf('Ошибка при экспорте: %s', ME.message), 'Error', 'error');
        debugState('boxplotFromTableGUI', 'Export error: %s', ME.message);
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

function pathStr = truncatePath(fullPath)
    if length(fullPath) > 50
        [~, name, ext] = fileparts(fullPath);
        pathStr = ['...' filesep name ext];
    else
        pathStr = fullPath;
    end
end

% ============================================================================
% Вспомогательные функции парсинга и обработки данных
% ============================================================================

function groupFilters = parseGroupFilters(filtersStr)
    % Парсинг фильтров групп в формате: A: условие1; B: условие2
    % Возвращает cell array структур с полями: letter, condition
    
    if isempty(filtersStr) || ~ischar(filtersStr)
        groupFilters = {};
        return
    end
    
    % Поиск паттернов "буква:"
    pattern = '([A-Z]):\s*(.*?)(?=(?:[A-Z]:|$))';
    matches = regexp(filtersStr, pattern, 'tokens');
    
    groupFilters = {};
    for i = 1:length(matches)
        letter = matches{i}{1};
        condition = strtrim(matches{i}{2});
        if ~isempty(condition)
            groupFilters{end+1} = struct('letter', letter, 'condition', condition);
        end
    end
end

function filteredTable = applyGroupFilters(table, groupFilters)
    % Применение фильтров к таблице через eval
    % Создает колонку group_label с метками групп
    
    filteredTable = table;
    
    if isempty(groupFilters)
        % Если фильтров нет, все данные в одной группе
        filteredTable.group_label = repmat({'All'}, height(filteredTable), 1);
        return
    end
    
    filteredTable.group_label = repmat({''}, height(filteredTable), 1);
    
    % Создаем переменные из колонок таблицы
    varNames = filteredTable.Properties.VariableNames;
    for i = 1:length(varNames)
        varName = matlab.lang.makeValidName(varNames{i});
        assignin('caller', varName, filteredTable{:, i});
    end
    
    % Применяем фильтры для каждой группы
    for i = 1:length(groupFilters)
        filter = groupFilters{i};
        try
            % Выполняем условие через eval
            mask = eval(filter.condition);
            if islogical(mask) && length(mask) == height(filteredTable)
                % Присваиваем метку группы
                filteredTable.group_label(mask) = {filter.letter};
            end
        catch ME
            warning('Ошибка при применении фильтра для группы %s: %s', filter.letter, ME.message);
        end
    end
    
    % Оставляем только строки с метками групп
    hasLabel = ~cellfun(@isempty, filteredTable.group_label);
    filteredTable = filteredTable(hasLabel, :);
end


function groupLabels = parseGroupLabels(labelsStr)
    % Парсинг кастомных подписей групп: A:Подпись1,B:Подпись2
    
    groupLabels = containers.Map();
    
    if isempty(labelsStr)
        return
    end
    
    if ischar(labelsStr)
        % Разделяем по запятым или переносам строк
        parts = strsplit(labelsStr, {',', '\n', '\r\n', '\r'}, 'CollapseDelimiters', true);
    else
        parts = labelsStr;
    end
    
    for i = 1:length(parts)
        part = strtrim(parts{i});
        if contains(part, ':')
            splitPart = strsplit(part, ':', 'CollapseDelimiters', false);
            if length(splitPart) >= 2
                letter = strtrim(splitPart{1});
                label = strtrim(strjoin(splitPart(2:end), ':'));
                if ~isempty(letter) && ~isempty(label)
                    groupLabels(letter) = label;
                end
            end
        end
    end
end

function groupColors = parseGroupColors(colorsStr)
    % Парсинг цветов групп: A:#FF0000,B:#00FF00
    
    groupColors = containers.Map();
    
    if isempty(colorsStr)
        return
    end
    
    if ischar(colorsStr)
        parts = strsplit(colorsStr, {',', '\n', '\r\n', '\r'}, 'CollapseDelimiters', true);
    else
        parts = colorsStr;
    end
    
    for i = 1:length(parts)
        part = strtrim(parts{i});
        if contains(part, ':')
            splitPart = strsplit(part, ':', 'CollapseDelimiters', false);
            if length(splitPart) >= 2
                letter = strtrim(splitPart{1});
                hexColor = strtrim(splitPart{2});
                if ~isempty(letter) && ~isempty(hexColor)
                    rgbColor = hex2rgb(hexColor);
                    if ~isempty(rgbColor)
                        groupColors(letter) = rgbColor;
                    end
                end
            end
        end
    end
end

function rgb = hex2rgb(hex)
    % Конвертация HEX цвета в RGB
    hex = strrep(hex, '#', '');
    if length(hex) == 6
        r = hex2dec(hex(1:2)) / 255;
        g = hex2dec(hex(3:4)) / 255;
        b = hex2dec(hex(5:6)) / 255;
        rgb = [r, g, b];
    else
        rgb = [];
    end
end

function diagnosis = diagnoseFiltering(table, groupFilters)
    % Диагностика фильтрации - подробный вывод результатов
    
    diagnosis = sprintf('Всего строк в данных: %d\n', height(table));
    diagnosis = [diagnosis sprintf('Колонки в данных: %s\n\n', strjoin(table.Properties.VariableNames, ', '))];
    
    for i = 1:length(groupFilters)
        filter = groupFilters{i};
        diagnosis = [diagnosis sprintf('Группа %s:\n', filter.letter)];
        diagnosis = [diagnosis sprintf('  Условие: %s\n', filter.condition)];
        
        try
            % Создаем переменные из колонок
            varNames = table.Properties.VariableNames;
            for j = 1:length(varNames)
                varName = matlab.lang.makeValidName(varNames{j});
                assignin('caller', varName, table{:, j});
            end
            
            % Выполняем условие
            mask = eval(filter.condition);
            if islogical(mask) && length(mask) == height(table)
                count = sum(mask);
                diagnosis = [diagnosis sprintf('  Строк в группе: %d из %d\n\n', count, height(table))];
            else
                diagnosis = [diagnosis sprintf('  Ошибка: условие вернуло неверный результат\n\n')];
            end
        catch ME
            diagnosis = [diagnosis sprintf('  Ошибка: %s\n\n', ME.message)];
        end
    end
end

function groupStats = calculateGroupStatistics(table, parameters, groupColumn)
    % Расчет статистики для каждой группы и параметра
    % parameters - массив структур с полями: group (буква группы или пусто), column (название колонки)
    
    groupStats = struct();
    uniqueGroups = unique(table{:, groupColumn});
    
    for p = 1:length(parameters)
        paramStruct = parameters{p};
        columnName = paramStruct.column;
        groupFilter = paramStruct.group;
        
        if ~ismember(columnName, table.Properties.VariableNames)
            continue
        end
        
        paramStats = struct();
        for g = 1:length(uniqueGroups)
            groupLabel = uniqueGroups{g};
            if iscell(groupLabel)
                groupLabel = groupLabel{1};
            end
            
            % Используем только указанную группу (если указана)
            if ~isempty(groupFilter) && ~strcmp(groupLabel, groupFilter)
                continue
            end
            
            mask = strcmp(table{:, 'group_label'}, groupLabel);
            data = table{mask, columnName};
            data = data(~isnan(data) & ~isinf(data));
            
            if ~isempty(data)
                paramStats.(matlab.lang.makeValidName(groupLabel)) = struct(...
                    'mean', mean(data), ...
                    'std', std(data), ...
                    'median', median(data), ...
                    'q25', prctile(data, 25), ...
                    'q75', prctile(data, 75), ...
                    'count', length(data));
            end
        end
        
        % Используем название колонки как ключ с группой
        if ~isempty(groupFilter)
            paramKey = sprintf('%s_%s', groupFilter, columnName);
        else
            paramKey = columnName;
        end
        groupStats.(matlab.lang.makeValidName(paramKey)) = paramStats;
    end
end

function testResults = performStatisticalTests(table, parameters, groupColumn)
    % Попарные t-test между группами для каждого параметра
    % parameters - массив структур с полями: group (буква группы или пусто), column (название колонки)
    
    testResults = struct();
    uniqueGroups = unique(table{:, groupColumn});
    
    if length(uniqueGroups) < 2
        return
    end
    
    for p = 1:length(parameters)
        paramStruct = parameters{p};
        columnName = paramStruct.column;
        groupFilter = paramStruct.group;
        
        if ~ismember(columnName, table.Properties.VariableNames)
            continue
        end
        
        paramResults = struct();
        for i = 1:length(uniqueGroups)
            for j = i+1:length(uniqueGroups)
                group1 = uniqueGroups{i};
                group2 = uniqueGroups{j};
                
                if iscell(group1), group1 = group1{1}; end
                if iscell(group2), group2 = group2{1}; end
                
                % Пропускаем пары, не содержащие указанную группу
                if ~strcmp(group1, groupFilter) && ~strcmp(group2, groupFilter)
                    continue
                end
                
                mask1 = strcmp(table{:, groupColumn}, group1);
                mask2 = strcmp(table{:, groupColumn}, group2);
                
                data1 = table{mask1, columnName};
                data2 = table{mask2, columnName};
                
                data1 = data1(~isnan(data1) & ~isinf(data1));
                data2 = data2(~isnan(data2) & ~isinf(data2));
                
                if length(data1) > 0 && length(data2) > 0
                    try
                        [~, pvalue] = ttest2(data1, data2);
                        testKey = sprintf('%s_vs_%s', matlab.lang.makeValidName(group1), matlab.lang.makeValidName(group2));
                        paramResults.(testKey) = struct(...
                            'pvalue', pvalue, ...
                            'n1', length(data1), ...
                            'n2', length(data2), ...
                            'group1', group1, ...
                            'group2', group2);
                    catch
                        % Игнорируем ошибки тестов
                    end
                end
            end
        end
        
        % Используем название колонки как ключ с группой
        if ~isempty(groupFilter)
            paramKey = sprintf('%s_%s', groupFilter, columnName);
        else
            paramKey = columnName;
        end
        testResults.(matlab.lang.makeValidName(paramKey)) = paramResults;
    end
end

function createBoxplotFigure(table, parameters, groupStats, statisticalTests, ...
    groupLabels, groupColors, state)
    % Построение графика с боксплотами
    
    % Дебаг в начале функции
    debugState('createBoxplotFigure', 'Entered function:');
    debugState('createBoxplotFigure', '  table size: %d x %d', height(table), width(table));
    debugState('createBoxplotFigure', '  table columns: %s', strjoin(table.Properties.VariableNames, ', '));
    debugState('createBoxplotFigure', '  parameters count: %d', length(parameters));
    for i = 1:length(parameters)
        debugState('createBoxplotFigure', '    param %d: group=%s, column=%s', i, parameters{i}.group, parameters{i}.column);
    end
    if ismember('group_label', table.Properties.VariableNames)
        uniqueGroups = unique(table{:, 'group_label'});
        debugState('createBoxplotFigure', '  unique groups: %s', strjoin(uniqueGroups, ', '));
    else
        debugState('createBoxplotFigure', '  WARNING: group_label column not found!');
    end
    
    nParams = length(parameters);
    fig = figure('Position', [150, 50, 800, 200 + nParams * 400], ...
        'Name', state.title, ...
        'NumberTitle', 'off');
    
    uniqueGroups = unique(table{:, 'group_label'});
    nGroups = length(uniqueGroups);
    
    % Сортировка групп по буквам
    groupLetters = cell(nGroups, 1);
    for i = 1:nGroups
        if iscell(uniqueGroups{i})
            groupLetters{i} = uniqueGroups{i}{1};
        else
            groupLetters{i} = uniqueGroups{i};
        end
    end
    [~, sortIdx] = sort(groupLetters);
    sortedGroups = uniqueGroups(sortIdx);
    
    for p = 1:nParams
        paramStruct = parameters{p};
        columnName = paramStruct.column;
        groupFilter = paramStruct.group;
        
        if ~ismember(columnName, table.Properties.VariableNames)
            continue
        end
        
        subplot(nParams, 1, p);
        hold on;
        
        % Собираем данные для каждой группы
        allData = [];
        groupLabelsForBoxplot = {};
        
        % Проверяем, есть ли указанная группа в таблице
        groupFound = false;
        for g = 1:nGroups
            groupLabel = sortedGroups{g};
            if iscell(groupLabel)
                groupLabel = groupLabel{1};
            end
            if strcmp(groupLabel, groupFilter)
                groupFound = true;
                break
            end
        end
        
        debugState('createBoxplotFigure', '  Parameter %d: groupFilter=%s, groupFound=%d', p, groupFilter, groupFound);
        
        for g = 1:nGroups
            groupLabel = sortedGroups{g};
            if iscell(groupLabel)
                groupLabel = groupLabel{1};
            end
            
            % Если группа указана и не найдена в таблице, используем все данные
            if ~isempty(groupFilter) && ~groupFound
                % Используем все группы - группа из параметра не найдена
            elseif ~isempty(groupFilter) && ~strcmp(groupLabel, groupFilter)
                continue
            end
            
            % Используем кастомную подпись если есть
            displayLabel = groupLabel;
            if ~isempty(groupLabels) && isKey(groupLabels, groupLabel)
                displayLabel = groupLabels(groupLabel);
            end
            
            mask = strcmp(table{:, 'group_label'}, groupLabel);
            data = table{mask, columnName};
            data = data(~isnan(data) & ~isinf(data));
            
            debugState('createBoxplotFigure', '    Group %s: found %d data points', groupLabel, length(data));
            
            if ~isempty(data)
                allData = [allData; data];
                groupLabelsForBoxplot = [groupLabelsForBoxplot; repmat({displayLabel}, length(data), 1)];
            end
        end
        
        debugState('createBoxplotFigure', '  Total data points collected: %d', length(allData));
        
        % Построение боксплотов
        if ~isempty(allData)
            boxplot(allData, groupLabelsForBoxplot);
            hold on;
            
            % Добавление точек данных с jitter
            uniqueDisplayLabels = unique(groupLabelsForBoxplot, 'stable');
            for g = 1:length(uniqueDisplayLabels)
                displayLabel = uniqueDisplayLabels{g};
                mask = strcmp(groupLabelsForBoxplot, displayLabel);
                data = allData(mask);
                
                if ~isempty(data)
                    x_pos = g;
                    x_jitter = x_pos + 0.1 * (rand(size(data)) - 0.5);
                    
                    % Находим оригинальную группу для цвета
                    color = [0 0 0]; % черный по умолчанию
                    if ~isempty(groupColors)
                        % Ищем группу по displayLabel
                        for origGroup = sortedGroups
                            if iscell(origGroup{1})
                                origGroupLabel = origGroup{1}{1};
                            else
                                origGroupLabel = origGroup{1};
                            end
                            
                            checkDisplayLabel = origGroupLabel;
                            if ~isempty(groupLabels) && isKey(groupLabels, origGroupLabel)
                                checkDisplayLabel = groupLabels(origGroupLabel);
                            end
                            
                            if strcmp(checkDisplayLabel, displayLabel) && isKey(groupColors, origGroupLabel)
                                color = groupColors(origGroupLabel);
                                break
                            end
                        end
                    end
                    
                    scatter(x_jitter, data, 20, color, '.', 'MarkerFaceAlpha', 0.6);
                    
                    % Аннотация n=X
                    medianVal = median(data);
                    text(x_pos, medianVal, sprintf('n=%d', length(data)), ...
                        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
                        'FontSize', 9, 'BackgroundColor', 'white');
                end
            end
        end
        
        % Формируем название для оси Y
        if ~isempty(groupFilter)
            yLabelText = sprintf('%s (%s)', columnName, groupFilter);
        else
            yLabelText = columnName;
        end
        ylabel(yLabelText);
        if p == nParams
            xlabel('Groups');
        end
        
        % Настройка диапазона Y-оси
        if strcmp(state.yAxisRange, 'manual') && ~isempty(state.yAxisMin) && ~isempty(state.yAxisMax)
            ylim([state.yAxisMin, state.yAxisMax]);
        elseif strcmp(state.yAxisRange, 'auto')
            % Автоматический расчет пределов по процентилям 0.001 и 99.99
            if ~isempty(allData)
                yMin = prctile(allData, 0.001);
                yMax = prctile(allData, 99.99);
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
                ylim([yMin, yMax]);
            end
        end
        
        % Скобки значимости (если статистика включена)
        if ~isempty(groupFilter)
            paramKey = sprintf('%s_%s', groupFilter, columnName);
        else
            paramKey = columnName;
        end
        paramKeyValid = matlab.lang.makeValidName(paramKey);
        
        if state.showStatistics && isfield(statisticalTests, paramKeyValid)
            currentAxes = gca;
            currentYLim = ylim(currentAxes);
            addSignificanceBrackets(currentAxes, sortedGroups, ...
                statisticalTests.(paramKeyValid), ...
                state.showAllPvalues, currentYLim);
            
            % Обновляем пределы Y-оси чтобы вместить скобки
            maxLevel = 0;
            if ~isempty(fieldnames(statisticalTests.(paramKeyValid)))
                testFields = fieldnames(statisticalTests.(paramKeyValid));
                for tf = 1:length(testFields)
                    testData = statisticalTests.(paramKeyValid).(testFields{tf});
                    if state.showAllPvalues || testData.pvalue < 0.05
                        maxLevel = maxLevel + 1;
                    end
                end
            end
            
            if maxLevel > 0
                yRange = currentYLim(2) - currentYLim(1);
                yBaseOffset = yRange * 0.05;
                yLevelSpacing = yRange * 0.08;
                yTextOffset = yRange * 0.015;
                newYMax = currentYLim(2) + yBaseOffset + (maxLevel - 1) * yLevelSpacing + yTextOffset;
                ylim(currentAxes, [currentYLim(1), newYMax]);
            end
        end
    end
    
    sgtitle(state.title, 'FontSize', 14, 'FontWeight', 'bold');
end

function addSignificanceBrackets(ax, groups, testResults, showAllPvalues, yLimits)
    % Добавление скобок значимости на график
    % groups - отсортированные группы
    % testResults - структура с результатами тестов
    % showAllPvalues - показывать все p-values или только значимые
    % yLimits - текущие пределы Y-оси [ymin, ymax]
    
    if isempty(testResults) || isempty(fieldnames(testResults))
        return
    end
    
    % Собираем все пары для отображения
    significantPairs = struct('group1', {}, 'group2', {}, 'pvalue', {}, 'stars', {});
    testFields = fieldnames(testResults);
    
    for i = 1:length(testFields)
        testKey = testFields{i};
        testData = testResults.(testKey);
        pvalue = testData.pvalue;
        
        if showAllPvalues || pvalue < 0.05
            newPair = struct(...
                'group1', {testData.group1}, ...
                'group2', {testData.group2}, ...
                'pvalue', pvalue, ...
                'stars', {pToStars(pvalue)});
            significantPairs = [significantPairs; newPair];
        end
    end
    
    if isempty(significantPairs)
        return
    end
    
    % Находим позиции групп на оси X
    groupPositions = containers.Map();
    for i = 1:length(groups)
        if iscell(groups{i})
            groupLabel = groups{i}{1};
        else
            groupLabel = groups{i};
        end
        groupPositions(groupLabel) = i;
    end
    
    % Определяем уровни для скобок (чтобы не пересекались)
    levels = assignBracketLevels(significantPairs, groupPositions);
    
    % Параметры для позиционирования скобок
    yRange = yLimits(2) - yLimits(1);
    yBaseOffset = yRange * 0.05;
    yLevelSpacing = yRange * 0.08;
    yTextOffset = yRange * 0.015;
    bracketWallHeight = yRange * 0.03;
    
    % Рисуем скобки
    axes(ax);
    hold on;
    
    for i = 1:length(significantPairs)
        pair = significantPairs(i);
        level = levels(i);
        
        group1Label = pair.group1;
        group2Label = pair.group2;
        
        if iscell(group1Label)
            group1Label = group1Label{1};
        end
        if iscell(group2Label)
            group2Label = group2Label{1};
        end
        
        if ~isKey(groupPositions, group1Label) || ~isKey(groupPositions, group2Label)
            continue
        end
        
        pos1 = groupPositions(group1Label);
        pos2 = groupPositions(group2Label);
        
        yLine = yLimits(2) + yBaseOffset + level * yLevelSpacing;
        yWallBottom = yLine - bracketWallHeight;
        yText = yLine + yTextOffset;
        
        % Горизонтальная линия
        line([pos1, pos2], [yLine, yLine], 'Color', 'k', 'LineWidth', 1.5);
        
        % Вертикальные стенки
        line([pos1, pos1], [yLine, yWallBottom], 'Color', 'k', 'LineWidth', 1.5);
        line([pos2, pos2], [yLine, yWallBottom], 'Color', 'k', 'LineWidth', 1.5);
        
        % Текст с p-value
        if pair.pvalue >= 0.001
            ptext = sprintf('p=%.3f', pair.pvalue);
        else
            ptext = 'p<0.001';
        end
        
        starsStr = pair.stars;
        if iscell(starsStr)
            starsStr = starsStr{1};
        end
        
        annotationText = sprintf('%s %s', ptext, starsStr);
        
        text((pos1 + pos2) / 2, yText, annotationText, ...
            'HorizontalAlignment', 'center', ...
            'FontSize', 10, ...
            'Color', 'k', ...
            'BackgroundColor', 'white', ...
            'EdgeColor', 'k', ...
            'LineWidth', 1);
    end
end

function levels = assignBracketLevels(pairs, groupPositions)
    % Определение уровней для скобок, чтобы они не пересекались
    
    levels = zeros(length(pairs), 1);
    
    for i = 1:length(pairs)
        pair = pairs(i);
        
        group1Label = pair.group1;
        group2Label = pair.group2;
        
        if iscell(group1Label)
            group1Label = group1Label{1};
        end
        if iscell(group2Label)
            group2Label = group2Label{1};
        end
        
        if ~isKey(groupPositions, group1Label) || ~isKey(groupPositions, group2Label)
            levels(i) = 0;
            continue
        end
        
        pos1 = groupPositions(group1Label);
        pos2 = groupPositions(group2Label);
        
        level = 0;
        % Проверяем пересечения с уже размещенными скобками
        for j = 1:i-1
            otherPair = pairs(j);
            
            otherGroup1Label = otherPair.group1;
            otherGroup2Label = otherPair.group2;
            
            if iscell(otherGroup1Label)
                otherGroup1Label = otherGroup1Label{1};
            end
            if iscell(otherGroup2Label)
                otherGroup2Label = otherGroup2Label{1};
            end
            
            if ~isKey(groupPositions, otherGroup1Label) || ~isKey(groupPositions, otherGroup2Label)
                continue
            end
            
            otherPos1 = groupPositions(otherGroup1Label);
            otherPos2 = groupPositions(otherGroup2Label);
            
            % Проверяем пересечение: скобки пересекаются если их диапазоны перекрываются
            if ~(pos2 < otherPos1 || pos1 > otherPos2)
                level = max(level, levels(j) + 1);
            end
        end
        
        levels(i) = level;
    end
end

function stars = pToStars(p)
    % Конвертация p-value в звездочки
    if ~isfinite(p)
        stars = '';
    elseif p < 0.001
        stars = '***';
    elseif p < 0.01
        stars = '**';
    elseif p < 0.05
        stars = '*';
    else
        stars = 'ns';
    end
end

