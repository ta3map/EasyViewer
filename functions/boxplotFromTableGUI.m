function boxplotFromTableGUI(filePath)
    % boxplotFromTableGUI - GUI для построения боксплотов из плоских таблиц
    % Поддерживает загрузку из MAT файлов (flatTable) и Excel файлов
    % Фильтрация данных через MATLAB формулы
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
    
    uicontrol('Parent', fig, 'Style', 'text', ...
        'Position', [margin, yPos, 380, lineHeight], ...
        'String', 'Analysis Columns', ...
        'FontSize', 11, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'left');
    
    yPos = yPos - lineHeight - 5;
    paramsTable = uitable('Parent', fig, ...
        'Position', [margin, yPos - 120, panelWidth - 2*margin, 120], ...
        'ColumnName', {'Group', 'Column', 'Filter', 'Label', 'Color', 'LineWidth'}, ...
        'ColumnEditable', [true, false, true, true, true, true], ...
        'ColumnWidth', {50, 100, 80, 80, 70, 70}, ...
        'Data', cell(0, 6), ...
        'Tag', 'paramsTable', ...
        'CellEditCallback', @(~,~) paramsTableEditCallback(fig));
    
    yPos = yPos - 125 - sectionSpacing;
    
    
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
        
        % Форматируем названия колонок
        state.table = formatTableColumnNames(state.table);
        
        state.filePath = filePath;
        state.parameters = {};
        state.nextGroupNumber = 1;
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
    
    % Нормализуем параметры - гарантируем наличие всех полей
    for i = 1:length(state.parameters)
        if ~isfield(state.parameters{i}, 'groupNumber')
            state.parameters{i}.groupNumber = 1;
        end
        if ~isfield(state.parameters{i}, 'filter')
            state.parameters{i}.filter = '';
        end
        if ~isfield(state.parameters{i}, 'label')
            state.parameters{i}.label = state.parameters{i}.column;
        end
        if ~isfield(state.parameters{i}, 'color')
            state.parameters{i}.color = '';
        end
        if ~isfield(state.parameters{i}, 'lineWidth')
            state.parameters{i}.lineWidth = 1;
        end
    end
    
    set(fig, 'UserData', state);
    updateAnalysisColumnsDisplay(fig);
end

function clearAnalysisColumns(fig)
    % Очистка поля анализа
    state = get(fig, 'UserData');
    state.parameters = {};
    state.nextGroupNumber = 1;
    set(fig, 'UserData', state);
    updateAnalysisColumnsDisplay(fig);
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
    yAxisPopup = findobj(fig, 'Tag', 'yAxisPopup');
    yAxisMinEdit = findobj(fig, 'Tag', 'yAxisMinEdit');
    yAxisMaxEdit = findobj(fig, 'Tag', 'yAxisMaxEdit');
    titleEdit = findobj(fig, 'Tag', 'titleEdit');
    
    try
        % Получение параметров
        parameters = state.parameters;
        
        
        % Собираем labels и colors из параметров
        groupLabels = containers.Map();
        groupColors = containers.Map();
        for i = 1:length(parameters)
            columnName = parameters{i}.column;
            if ~isempty(parameters{i}.label)
                groupLabels(columnName) = parameters{i}.label;
            end
            if ~isempty(parameters{i}.color)
                colorStr = strtrim(parameters{i}.color);
                if ~isempty(colorStr)
                    % Парсим цвет (может быть в формате #RRGGBB или RGB)
                    try
                        if strncmp(colorStr, '#', 1)
                            % Формат #RRGGBB
                            r = hex2dec(colorStr(2:3)) / 255;
                            g = hex2dec(colorStr(4:5)) / 255;
                            b = hex2dec(colorStr(6:7)) / 255;
                            groupColors(columnName) = [r, g, b];
                        else
                            % Пробуем как RGB значения
                            rgb = str2num(colorStr);
                            if length(rgb) == 3 && all(rgb >= 0) && all(rgb <= 1)
                                groupColors(columnName) = rgb;
                            elseif length(rgb) == 3 && all(rgb >= 0) && all(rgb <= 255)
                                groupColors(columnName) = rgb / 255;
                            end
                        end
                    catch
                        % Игнорируем ошибки парсинга цвета
                    end
                end
            end
        end
        
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
        
        % Не применяем фильтры здесь - они будут применяться индивидуально для каждого параметра
        
        % Расчет статистики и тесты не нужны на уровне всей таблицы
        groupStats = struct();
        statisticalTests = struct();
        
        % Дебаг перед построением
        debugState('boxplotFromTableGUI', 'Before createBoxplotFigure:');
        debugState('boxplotFromTableGUI', '  table size: %d x %d', height(state.table), width(state.table));
        debugState('boxplotFromTableGUI', '  parameters count: %d', length(parameters));
        for i = 1:length(parameters)
            debugState('boxplotFromTableGUI', '    param %d: column=%s', i, parameters{i}.column);
        end
        
        % Построение графика
        createBoxplotFigure(fig, state.table, parameters, groupStats, statisticalTests, ...
            groupLabels, groupColors, state);
        
    catch ME
        msgbox(sprintf('Ошибка при построении графика: %s', ME.message), 'Error', 'error');
        debugState('boxplotFromTableGUI', 'Error: %s', ME.message);
    end
end

function exportPlotCallback(fig)
    % Экспорт текущего графика в различные форматы
    
    % Находим панель с графиками
    plotPanel = findobj(fig, 'Tag', 'plotPanel');
    if isempty(plotPanel)
        msgbox('Сначала постройте график', 'Warning', 'warn');
        return
    end
    
    % Проверяем, есть ли axes в панели
    axesInPanel = findobj(plotPanel, 'Type', 'axes');
    if isempty(axesInPanel)
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
                msgbox('Неподдерживаемый формат файла', 'Error', 'error');
                close(exportFig);
                return
        end
        
        close(exportFig);
    catch ME
        msgbox(sprintf('Ошибка при экспорте: %s', ME.message), 'Error', 'error');
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
    % Парсинг фильтра: простое условие
    % Возвращает cell array структур с полями: condition, groupLabel
    
    if isempty(filtersStr)
        groupFilters = {};
        return
    end
    
    if ~ischar(filtersStr) && ~isstring(filtersStr)
        groupFilters = {};
        return
    end
    
    if isstring(filtersStr)
        filtersStr = char(filtersStr);
    end
    
    filtersStr = strtrim(filtersStr);
    
    if ~isempty(filtersStr)
        groupFilters{1} = struct('condition', filtersStr, 'groupLabel', 'Group1');
    else
        groupFilters = {};
    end
end

function filteredTable = applyGroupFilters(table, groupFilters)
    % Применение фильтров к таблице через eval
    % Создает колонку group_label с метками групп
    
    filteredTable = table;
    
    if isempty(groupFilters)
        % Если фильтров нет, возвращаем пустую таблицу
        filteredTable = table();
        return
    end
    
    filteredTable.group_label = repmat({''}, height(filteredTable), 1);
    
    % Создаем переменные из колонок таблицы локально (названия уже отформатированы)
    varNames = filteredTable.Properties.VariableNames;
    for i = 1:length(varNames)
        varName = varNames{i};
        eval(sprintf('%s = filteredTable{:, %d};', varName, i));
    end
    
    % Применяем фильтры для каждой группы
    for i = 1:length(groupFilters)
        filter = groupFilters{i};
        try
            % Выполняем условие через eval
            mask = eval(filter.condition);
            if islogical(mask) && length(mask) == height(filteredTable)
                % Присваиваем метку группы
                filteredTable.group_label(mask) = {filter.groupLabel};
            end
        catch ME
            warning('Ошибка при применении фильтра: %s', ME.message);
        end
    end
    
    % Оставляем только строки с метками групп
    hasLabel = ~cellfun(@isempty, filteredTable.group_label);
    filteredTable = filteredTable(hasLabel, :);
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
        diagnosis = [diagnosis sprintf('Условие %d:\n', i)];
        diagnosis = [diagnosis sprintf('  %s\n', filter.condition)];
        
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
    % parameters - массив структур с полями: column (название колонки)
    
    groupStats = struct();
    uniqueGroups = unique(table{:, groupColumn});
    
        for p = 1:length(parameters)
        paramStruct = parameters{p};
        columnName = paramStruct.column;
        
        if ~ismember(columnName, table.Properties.VariableNames)
            continue
        end
        
        paramStats = struct();
        for g = 1:length(uniqueGroups)
            groupLabel = uniqueGroups{g};
            if iscell(groupLabel)
                groupLabel = groupLabel{1};
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
        
        % Используем название колонки как ключ
        paramKey = columnName;
        groupStats.(matlab.lang.makeValidName(paramKey)) = paramStats;
    end
end

function testResults = performStatisticalTests(table, parameters, groupColumn)
    % Попарные t-test между параметрами на одном полотне (с одинаковым groupNumber)
    % parameters - массив структур с полями: groupNumber, column
    
    testResults = struct();
    
    % Группируем параметры по groupNumber
    groupNumbers = [];
    for i = 1:length(parameters)
        if isfield(parameters{i}, 'groupNumber')
            groupNumbers(end+1) = parameters{i}.groupNumber;
        else
            groupNumbers(end+1) = 1;
        end
    end
    uniqueGroupNumbers = unique(groupNumbers);
    
    % Для каждой группы полотен
    for groupNum = uniqueGroupNumbers
        % Находим все параметры в этой группе
        paramsInGroup = {};
        for i = 1:length(parameters)
            paramGroupNum = 1;
            if isfield(parameters{i}, 'groupNumber')
                paramGroupNum = parameters{i}.groupNumber;
            end
            if paramGroupNum == groupNum
                paramsInGroup{end+1} = parameters{i};
            end
        end
        
        % Если параметров меньше 2, тестов нет
        if length(paramsInGroup) < 2
            continue
        end
        
        % Тестируем все пары параметров на этом полотне
        for i = 1:length(paramsInGroup)
            for j = i+1:length(paramsInGroup)
                param1 = paramsInGroup{i};
                param2 = paramsInGroup{j};
                
                column1 = param1.column;
                column2 = param2.column;
                
                if ~ismember(column1, table.Properties.VariableNames) || ...
                   ~ismember(column2, table.Properties.VariableNames)
                    continue
                end
                
                data1 = table{:, column1};
                data2 = table{:, column2};
                
                data1 = data1(~isnan(data1) & ~isinf(data1));
                data2 = data2(~isnan(data2) & ~isinf(data2));
                
                if length(data1) > 0 && length(data2) > 0
                    try
                        [~, pvalue] = ttest2(data1, data2);
                        testKey = sprintf('%s_vs_%s', matlab.lang.makeValidName(column1), matlab.lang.makeValidName(column2));
                        paramKey = sprintf('Group%d', groupNum);
                        
                        if ~isfield(testResults, paramKey)
                            testResults.(paramKey) = struct();
                        end
                        
                        testResults.(paramKey).(testKey) = struct(...
                            'pvalue', pvalue, ...
                            'n1', length(data1), ...
                            'n2', length(data2), ...
                            'group1', column1, ...
                            'group2', column2);
                    catch
                        % Игнорируем ошибки тестов
                    end
                end
            end
        end
    end
end

function createBoxplotFigure(fig, table, parameters, groupStats, statisticalTests, ...
    groupLabels, groupColors, state)
    % Построение графика с боксплотами
    
    % Дебаг в начале функции
    debugState('createBoxplotFigure', 'Entered function:');
    debugState('createBoxplotFigure', '  table size: %d x %d', height(table), width(table));
    debugState('createBoxplotFigure', '  table columns: %s', strjoin(table.Properties.VariableNames, ', '));
    debugState('createBoxplotFigure', '  parameters count: %d', length(parameters));
    for i = 1:length(parameters)
        debugState('createBoxplotFigure', '    param %d: column=%s', i, parameters{i}.column);
    end
    
    % Находим панель для графиков
    plotPanel = findobj(fig, 'Tag', 'plotPanel');
   
    % Очищаем содержимое панели
    delete(plotPanel.Children);
    
    % Группируем параметры по groupNumber
    groupNumbers = [];
    for i = 1:length(parameters)
        if isfield(parameters{i}, 'groupNumber')
            groupNumbers(end+1) = parameters{i}.groupNumber;
        else
            groupNumbers(end+1) = 1;
            parameters{i}.groupNumber = 1;
        end
    end
    uniqueGroupNumbers = unique(groupNumbers);
    nPlotGroups = length(uniqueGroupNumbers);
    
    % Строим графики по группам
    for plotGroupIdx = 1:nPlotGroups
        groupNum = uniqueGroupNumbers(plotGroupIdx);
        
        % Находим все параметры с этим номером группы
        paramsInGroup = {};
        for i = 1:length(parameters)
            if parameters{i}.groupNumber == groupNum
                paramsInGroup{end+1} = parameters{i};
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
        
        % Строим боксплоты для всех параметров в группе
        allDataForGroup = [];
        groupLabelsForBoxplot = {};
        labelToColumnMap = containers.Map();
        labelToLineWidthMap = containers.Map();
        paramDataMap = containers.Map(); % Для статистики - объединенные данные каждого параметра
        
        for p = 1:length(paramsInGroup)
            paramStruct = paramsInGroup{p};
            columnName = paramStruct.column;
            
            if ~ismember(columnName, table.Properties.VariableNames)
                continue
            end
            
            % Вычисляем displayLabel один раз (поля уже нормализованы)
            paramLabel = paramStruct.label;
            displayLabel = columnName;
            if ~isempty(paramLabel)
                displayLabel = paramLabel;
            elseif ~isempty(groupLabels) && isKey(groupLabels, columnName)
                displayLabel = groupLabels(columnName);
            end
            
            % Применяем фильтр для этого параметра индивидуально (ОДИН РАЗ)
            allDataForParam = [];
            
            if ~isempty(paramStruct.filter)
                paramFilter = paramStruct.filter;
                parsedFilters = parseGroupFilters(paramFilter);
                if ~isempty(parsedFilters)
                    filteredTableForParam = applyGroupFilters(table, parsedFilters);
                    if isempty(filteredTableForParam)
                        continue
                    end
                    
                    % Получаем уникальные группы из отфильтрованной таблицы
                    uniqueGroupsForParam = unique(filteredTableForParam{:, 'group_label'});
                    
                    % Собираем данные из всех групп для этого параметра
                    for g = 1:length(uniqueGroupsForParam)
                        groupLabel = uniqueGroupsForParam{g};
                        if iscell(groupLabel)
                            groupLabel = groupLabel{1};
                        end
                        
                        mask = strcmp(filteredTableForParam{:, 'group_label'}, groupLabel);
                        data = filteredTableForParam{mask, columnName};
                        data = data(~isnan(data) & ~isinf(data));
                        
                        if ~isempty(data)
                            % Формируем метку: название колонки + группа (если групп больше одной)
                            if length(uniqueGroupsForParam) > 1
                                plotLabel = sprintf('%s (%s)', displayLabel, groupLabel);
                            else
                                plotLabel = displayLabel;
                            end
                            
                            allDataForGroup = [allDataForGroup; data];
                            groupLabelsForBoxplot = [groupLabelsForBoxplot; repmat({plotLabel}, length(data), 1)];
                            if ~isKey(labelToColumnMap, plotLabel)
                                labelToColumnMap(plotLabel) = columnName;
                            end
                            if ~isKey(labelToLineWidthMap, plotLabel)
                                labelToLineWidthMap(plotLabel) = paramStruct.lineWidth;
                            end
                            allDataForParam = [allDataForParam; data];
                        end
                    end
                end
            end
            
            % Если фильтр не применился или его нет - используем все данные
            if isempty(allDataForParam)
                data = table{:, columnName};
                data = data(~isnan(data) & ~isinf(data));
                if ~isempty(data)
                    allDataForGroup = [allDataForGroup; data];
                    groupLabelsForBoxplot = [groupLabelsForBoxplot; repmat({displayLabel}, length(data), 1)];
                    if ~isKey(labelToColumnMap, displayLabel)
                        labelToColumnMap(displayLabel) = columnName;
                    end
                    if ~isKey(labelToLineWidthMap, displayLabel)
                        labelToLineWidthMap(displayLabel) = paramStruct.lineWidth;
                    end
                    allDataForParam = data;
                end
            end
            
            % Сохраняем объединенные данные параметра для статистики
            if ~isempty(allDataForParam)
                paramDataMap(columnName) = allDataForParam;
            end
        end
        
        % Построение боксплотов
        if ~isempty(allDataForGroup)
            boxplot(ax, allDataForGroup, groupLabelsForBoxplot);
            hold(ax, 'on');
            
            % Применение цветов к боксплотам
            uniqueDisplayLabels = unique(groupLabelsForBoxplot, 'stable');
            
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
                
                % Находим цвет для параметра
                color = [0.5 0.5 0.5]; % серый по умолчанию
                if ~isempty(groupColors) && exist('labelToColumnMap', 'var') && isKey(labelToColumnMap, displayLabel)
                    columnNameForColor = labelToColumnMap(displayLabel);
                    if isKey(groupColors, columnNameForColor)
                        color = groupColors(columnNameForColor);
                    end
                end
                
                % Находим lineWidth для параметра
                paramLineWidth = 1; % по умолчанию
                if exist('labelToLineWidthMap', 'var') && isKey(labelToLineWidthMap, displayLabel)
                    paramLineWidth = labelToLineWidthMap(displayLabel);
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
                
                if ~isempty(data)
                    x_pos = g;
                    x_jitter = x_pos + 0.1 * (rand(size(data)) - 0.5);
                    
                    % Находим цвет для параметра
                    color = [0 0 0]; % черный по умолчанию
                    if ~isempty(groupColors) && exist('labelToColumnMap', 'var') && isKey(labelToColumnMap, displayLabel)
                        columnNameForColor = labelToColumnMap(displayLabel);
                        if isKey(groupColors, columnNameForColor)
                            color = groupColors(columnNameForColor);
                        end
                    end
                    
                    % Находим lineWidth для параметра
                    paramLineWidth = 1; % по умолчанию
                    if exist('labelToLineWidthMap', 'var') && isKey(labelToLineWidthMap, displayLabel)
                        paramLineWidth = labelToLineWidthMap(displayLabel);
                    end
                    
                    % Размер маркера = lineWidth * 30
                    markerSize = paramLineWidth * 30;
                    
                    % Scatter с заполненными кругами и белым обрамлением
                    scatter(ax, x_jitter, data, markerSize, color, 'o', ...
                        'MarkerFaceColor', color, ...
                        'MarkerEdgeColor', 'white', ...
                        'LineWidth', paramLineWidth, ...
                        'MarkerFaceAlpha', 1);
                    
                    % Аннотация n=X
                    medianVal = median(data);
                    text(ax, x_pos, medianVal, sprintf('n=%d', length(data)), ...
                        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
                        'FontSize', 9, 'BackgroundColor', 'white');
                end
            end
            
            % Вычисляем статистические тесты между параметрами на этом полотне
            if state.showStatistics && length(paramDataMap) >= 2
                % Выполняем попарные тесты между параметрами
                paramKeys = keys(paramDataMap);
                testResultsForGroup = struct();
                for i = 1:length(paramKeys)
                    for j = i+1:length(paramKeys)
                        param1 = paramKeys{i};
                        param2 = paramKeys{j};
                        
                        data1 = paramDataMap(param1);
                        data2 = paramDataMap(param2);
                        
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
                maxLevel = calculateMaxBracketLevelForParams(statisticalTests.(paramKeyValid), paramsInGroup, state.showAllPvalues);
                
                % Рисуем скобки между параметрами
                addSignificanceBracketsForParams(ax, paramsInGroup, ...
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

function maxLevel = calculateMaxBracketLevelForParams(testResults, paramsInGroup, showAllPvalues)
    % Вычисление максимального уровня скобок для тестов между параметрами
    
    if isempty(testResults) || isempty(fieldnames(testResults))
        maxLevel = -1;
        return
    end
    
    % Собираем все пары для отображения
    significantPairs = struct('param1', {}, 'param2', {}, 'pvalue', {});
    testFields = fieldnames(testResults);
    
    for i = 1:length(testFields)
        testKey = testFields{i};
        testData = testResults.(testKey);
        pvalue = testData.pvalue;
        
        if showAllPvalues || pvalue < 0.05
            newPair = struct(...
                'param1', {testData.group1}, ...
                'param2', {testData.group2}, ...
                'pvalue', pvalue);
            significantPairs = [significantPairs; newPair];
        end
    end
    
    if isempty(significantPairs)
        maxLevel = -1;
        return
    end
    
    % Находим позиции параметров на оси X
    paramPositions = containers.Map();
    for i = 1:length(paramsInGroup)
        paramPositions(paramsInGroup{i}.column) = i;
    end
    
    % Определяем уровни для скобок
    levels = assignBracketLevelsForParams(significantPairs, paramPositions);
    
    if isempty(levels)
        maxLevel = -1;
    else
        maxLevel = max(levels);
    end
end

function levels = assignBracketLevelsForParams(pairs, paramPositions)
    % Определение уровней для скобок между параметрами
    
    levels = zeros(length(pairs), 1);
    
    for i = 1:length(pairs)
        pair = pairs(i);
        param1 = pair.param1;
        param2 = pair.param2;
        
        if ~isKey(paramPositions, param1) || ~isKey(paramPositions, param2)
            levels(i) = 0;
            continue
        end
        
        pos1 = paramPositions(param1);
        pos2 = paramPositions(param2);
        
        level = 0;
        for j = 1:i-1
            otherPair = pairs(j);
            if ~isKey(paramPositions, otherPair.param1) || ~isKey(paramPositions, otherPair.param2)
                continue
            end
            
            otherPos1 = paramPositions(otherPair.param1);
            otherPos2 = paramPositions(otherPair.param2);
            
            if ~(pos2 < otherPos1 || pos1 > otherPos2)
                level = max(level, levels(j) + 1);
            end
        end
        
        levels(i) = level;
    end
end

function addSignificanceBracketsForParams(ax, paramsInGroup, testResults, showAllPvalues, yLimits)
    % Добавление скобок значимости между параметрами на график
    
    if isempty(testResults) || isempty(fieldnames(testResults))
        return
    end
    
    % Собираем все пары для отображения
    significantPairs = struct('param1', {}, 'param2', {}, 'pvalue', {}, 'stars', {});
    testFields = fieldnames(testResults);
    
    for i = 1:length(testFields)
        testKey = testFields{i};
        testData = testResults.(testKey);
        pvalue = testData.pvalue;
        
        if showAllPvalues || pvalue < 0.05
            newPair = struct(...
                'param1', {testData.group1}, ...
                'param2', {testData.group2}, ...
                'pvalue', pvalue, ...
                'stars', {pToStars(pvalue)});
            significantPairs = [significantPairs; newPair];
        end
    end
    
    if isempty(significantPairs)
        return
    end
    
    % Находим позиции параметров на оси X
    paramPositions = containers.Map();
    for i = 1:length(paramsInGroup)
        paramPositions(paramsInGroup{i}.column) = i;
    end
    
    % Определяем уровни для скобок
    levels = assignBracketLevelsForParams(significantPairs, paramPositions);
    
    % Параметры для позиционирования скобок
    yRange = yLimits(2) - yLimits(1);
    yBaseOffset = yRange * 0.05;
    yLevelSpacing = yRange * 0.08;
    yTextOffset = yRange * 0.015;
    bracketWallHeight = yRange * 0.03;
    
    % Рисуем скобки
    hold(ax, 'on');
    
    for i = 1:length(significantPairs)
        pair = significantPairs(i);
        level = levels(i);
        
        param1 = pair.param1;
        param2 = pair.param2;
        
        if ~isKey(paramPositions, param1) || ~isKey(paramPositions, param2)
            continue
        end
        
        pos1 = paramPositions(param1);
        pos2 = paramPositions(param2);
        
        yLine = yLimits(2) + yBaseOffset + level * yLevelSpacing;
        yWallBottom = yLine - bracketWallHeight;
        yText = yLine + yTextOffset;
        
        % Горизонтальная линия
        line(ax, [pos1, pos2], [yLine, yLine], 'Color', 'k', 'LineWidth', 1.5);
        
        % Вертикальные стенки
        line(ax, [pos1, pos1], [yLine, yWallBottom], 'Color', 'k', 'LineWidth', 1.5);
        line(ax, [pos2, pos2], [yLine, yWallBottom], 'Color', 'k', 'LineWidth', 1.5);
        
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
        
        text(ax, (pos1 + pos2) / 2, yText, annotationText, ...
            'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'bottom', ...
            'FontSize', 10, ...
            'Color', 'k', ...
            'BackgroundColor', [1, 1, 1, 0.9], ...
            'EdgeColor', 'k', ...
            'LineWidth', 1, ...
            'Margin', 2);
    end
end


function table = formatTableColumnNames(table)
    % Форматирует названия колонок таблицы для валидных имен переменных MATLAB
    % Транскрибирует кириллические буквы в латиницу, затем делает имя валидным
    % Использует transliterateColumnName для транскрипции
    
    originalNames = table.Properties.VariableNames;
    validNames = cell(size(originalNames));
    for i = 1:length(originalNames)
        validNames{i} = transliterateColumnName(originalNames{i});
    end
    table.Properties.VariableNames = validNames;
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

