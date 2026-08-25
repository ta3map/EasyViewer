function resultsGalleryGUI()
    global table_minimized
    
    figTag = 'resultsGalleryGUI';
    guiFig = findobj('Type', 'figure', 'Tag', figTag);
    if ~isempty(guiFig)
        figure(guiFig);
        return
    end
    
    persistent state
    if isempty(state)
        state = struct();
        state.currentProjectId = [];
        state.dbPath = '';
        state.searchText = '';
        state.sortBy = 'path';
        state.sortOrder = 'asc';
        state.filterModule = '';
    end
    
    if isempty(table_minimized)
        table_minimized = false;
    end
    
    state.dbPath = getDbPath();
    state.currentProjectId = readStoredProjectId();
    
    if isempty(state.dbPath) || ~isfile(state.dbPath)
        msgbox('No database selected. Please select a database in File Manager.', 'Error', 'error');
        return
    end
    
    if isempty(state.currentProjectId)
        msgbox('No project selected. Please select a project in File Manager.', 'Error', 'error');
        return
    end
    
    projectName = getProjectName(state.currentProjectId);
    if isempty(projectName)
        msgbox('Project not found', 'Error', 'error');
        return
    end
    
    % Загружаем координаты элементов из JSON файла
    coordsFile = getGUIConfigPath('resultsGalleryGUI_coords.json');
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
            if ~strcmp(tag, 'previewPanel') && ~strcmp(tag, 'previewPanel_position_a') && ~strcmp(tag, 'previewPanel_position_b')
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
    
    % Загружаем относительные позиции для таблицы и панели в двух состояниях
    resultsTable_position_a_rel = coordsData.elements.resultsTable_position_a;
    resultsTable_position_b_rel = coordsData.elements.resultsTable_position_b;
    previewPanel_position_a = coordsData.elements.previewPanel_position_a;
    previewPanel_position_b = coordsData.elements.previewPanel_position_b;
    
    function closeResultsGalleryWindow(src, ~)
        delete(src);
        manageMainWindows('resultsGalleryGUI');
    end
    
    base_figure_position = coordsData.base_figure_position;
    fig = figure('Position', base_figure_position, ...
        'Name', sprintf('Results Gallery: %s', projectName), ...
        'NumberTitle', 'off', ...
        'MenuBar', 'none', ...
        'ToolBar', 'none', ...
        'Resize', 'on', ...
        'Tag', figTag, ...
        'CloseRequestFcn', @closeResultsGalleryWindow);
    
    uicontrol('Style', 'text', ...
        'Position', getElementPosition('projectNameText'), ...
        'String', sprintf('Project: %s', projectName), ...
        'HorizontalAlignment', 'left', ...
        'FontSize', 11, ...
        'FontWeight', 'bold', ...
        'Tag', 'projectNameText');
    
    uicontrol('Style', 'text', ...
        'Position', getElementPosition('searchText'), ...
        'String', 'Search:', ...
        'HorizontalAlignment', 'left', ...
        'FontSize', 10, ...
        'Tag', 'searchText');
    
    searchEdit = uicontrol('Style', 'edit', ...
        'Position', getElementPosition('searchEdit'), ...
        'String', state.searchText, ...
        'FontSize', 10, ...
        'Callback', @searchChanged, ...
        'Tag', 'searchEdit');
    
    uicontrol('Style', 'text', ...
        'Position', getElementPosition('sortByText'), ...
        'String', 'Sort by:', ...
        'HorizontalAlignment', 'left', ...
        'FontSize', 10, ...
        'Tag', 'sortByText');
    
    sortSelect = uicontrol('Style', 'popupmenu', ...
        'Position', getElementPosition('sortSelect'), ...
        'String', {'Report Path (A-Z)', 'Report Path (Z-A)', 'Date Created (Newest)', 'Date Created (Oldest)', 'Module Name (A-Z)', 'Module Name (Z-A)'}, ...
        'FontSize', 10, ...
        'Callback', @sortChanged, ...
        'Tag', 'sortSelect');
    
    if strcmp(state.sortBy, 'path') && strcmp(state.sortOrder, 'asc')
        set(sortSelect, 'Value', 1);
    elseif strcmp(state.sortBy, 'path') && strcmp(state.sortOrder, 'desc')
        set(sortSelect, 'Value', 2);
    elseif strcmp(state.sortBy, 'date') && strcmp(state.sortOrder, 'desc')
        set(sortSelect, 'Value', 3);
    elseif strcmp(state.sortBy, 'date') && strcmp(state.sortOrder, 'asc')
        set(sortSelect, 'Value', 4);
    elseif strcmp(state.sortBy, 'module') && strcmp(state.sortOrder, 'asc')
        set(sortSelect, 'Value', 5);
    elseif strcmp(state.sortBy, 'module') && strcmp(state.sortOrder, 'desc')
        set(sortSelect, 'Value', 6);
    else
        set(sortSelect, 'Value', 1);
    end
    
    uicontrol('Style', 'text', ...
        'Position', getElementPosition('moduleFilterText'), ...
        'String', 'Module:', ...
        'HorizontalAlignment', 'left', ...
        'FontSize', 10, ...
        'Tag', 'moduleFilterText');
    
    moduleFilterSelect = uicontrol('Style', 'popupmenu', ...
        'Position', getElementPosition('moduleFilterSelect'), ...
        'String', {'All Modules'}, ...
        'FontSize', 10, ...
        'Callback', @moduleFilterChanged, ...
        'Tag', 'moduleFilterSelect');
    
    base_figure_position = coordsData.base_figure_position;
    if table_minimized
        initialTablePos = [
            resultsTable_position_b_rel(1) * base_figure_position(3),
            resultsTable_position_b_rel(2) * base_figure_position(4),
            resultsTable_position_b_rel(3) * base_figure_position(3),
            resultsTable_position_b_rel(4) * base_figure_position(4)
        ];
        initialPanelPos = previewPanel_position_b;
    else
        initialTablePos = [
            resultsTable_position_a_rel(1) * base_figure_position(3),
            resultsTable_position_a_rel(2) * base_figure_position(4),
            resultsTable_position_a_rel(3) * base_figure_position(3),
            resultsTable_position_a_rel(4) * base_figure_position(4)
        ];
        initialPanelPos = previewPanel_position_a;
    end
    
    resultsTable = uitable('Position', initialTablePos, ...
        'ColumnWidth', {60, 200, 150, 450, 100}, ...
        'ColumnName', {'File ID', 'File Name', 'Module Name', 'Report Path', 'Created Date'}, ...
        'ColumnEditable', [false, false, false, false, false], ...
        'Data', cell(0, 5), ...
        'Tag', 'resultsTable');
    resultsTable.UserData = struct('row', 1, 'multi', 1);
    resultsTable.CellSelectionCallback = @handleTableSelection;
    
    previewPanel = uipanel('Parent', fig, ...
        'Position', initialPanelPos, ...
        'Tag', 'previewPanel');
    
    openBtn = uicontrol('Style', 'pushbutton', ...
        'Position', getElementPosition('openBtn'), ...
        'String', 'Open', ...
        'FontSize', 11, ...
        'Callback', @openSelectedResult, ...
        'Enable', 'off', ...
        'Tag', 'openBtn');
    
    openFolderBtn = uicontrol('Style', 'pushbutton', ...
        'Position', getElementPosition('openFolderBtn'), ...
        'String', 'Open Folder', ...
        'FontSize', 11, ...
        'Callback', @openResultFolder, ...
        'Enable', 'off', ...
        'Tag', 'openFolderBtn');
    
    deleteBtn = uicontrol('Style', 'pushbutton', ...
        'Position', getElementPosition('deleteBtn'), ...
        'String', 'Delete', ...
        'FontSize', 11, ...
        'Callback', @deleteSelectedResult, ...
        'Enable', 'off', ...
        'Tag', 'deleteBtn');
    
    addResultBtn = uicontrol('Style', 'pushbutton', ...
        'Position', getElementPosition('addResultBtn'), ...
        'String', 'Add Result', ...
        'FontSize', 11, ...
        'Callback', @addResultManually, ...
        'Tag', 'addResultBtn');
    
    totalText = uicontrol('Style', 'text', ...
        'Position', getElementPosition('totalText'), ...
        'String', 'Selected: 0 / Total: 0', ...
        'HorizontalAlignment', 'left', ...
        'FontSize', 10, ...
        'Tag', 'totalText');
    
    refreshBtn = uicontrol('Style', 'pushbutton', ...
        'Position', getElementPosition('refreshBtn'), ...
        'String', 'Refresh', ...
        'FontSize', 10, ...
        'Callback', @refreshTable, ...
        'Tag', 'refreshBtn');
    
    assetsPath = getAssetsPath();
    
    panButton = uicontrol('Style', 'pushbutton', ...
        'Position', getElementPosition('pan_btn'), ...
        'String', 'Pan', ...
        'FontSize', 10, ...
        'Callback', @panButtonCallback, ...
        'Tag', 'pan_btn');
    btnIcon(panButton, fullfile(assetsPath, 'pan_btn.png'), false);
    
    zoomButton = uicontrol('Style', 'pushbutton', ...
        'Position', getElementPosition('zoom_btn'), ...
        'String', 'Zoom', ...
        'FontSize', 10, ...
        'Callback', @zoomButtonCallback, ...
        'Tag', 'zoom_btn');
    btnIcon(zoomButton, fullfile(assetsPath, 'zoom_btn.png'), false);
    
    if table_minimized
        toggleBtnString = '>';
    else
        toggleBtnString = '<';
    end
    
    tableToggleBtn = uicontrol('Style', 'pushbutton', ...
        'Position', getElementPosition('table_toggle_btn'), ...
        'String', toggleBtnString, ...
        'FontSize', 12, ...
        'Callback', @toggleTableCallback, ...
        'Tag', 'table_toggle_btn');
    
    % Устанавливаем обработчик изменения размера окна
    set(fig, 'SizeChangedFcn', @(~,~) resizeComponentsCallback(fig, coordsFile));
    
    % Разворачиваем окно после успешной инициализации
    fig.WindowState = 'maximized';
    
    updateModuleFilterList();
    loadResults();
    
    % Функция обратного вызова для изменения размера
    function resizeComponentsCallback(figHandle, coordsFile)
        try
            if exist(coordsFile, 'file')
                coordsData = jsondecode(fileread(coordsFile));
                base_figure_position = coordsData.base_figure_position;
                ResizeElements(figHandle, coordsFile, base_figure_position);
                
                % Применяем текущее состояние таблицы после изменения размера
                currentFigPos = get(figHandle, 'Position');
                if table_minimized
                    tablePos = [
                        resultsTable_position_b_rel(1) * currentFigPos(3),
                        resultsTable_position_b_rel(2) * currentFigPos(4),
                        resultsTable_position_b_rel(3) * currentFigPos(3),
                        resultsTable_position_b_rel(4) * currentFigPos(4)
                    ];
                    panelPos = previewPanel_position_b;
                    set(resultsTable, 'Position', tablePos);
                    set(previewPanel, 'Position', panelPos);
                else
                    tablePos = [
                        resultsTable_position_a_rel(1) * currentFigPos(3),
                        resultsTable_position_a_rel(2) * currentFigPos(4),
                        resultsTable_position_a_rel(3) * currentFigPos(3),
                        resultsTable_position_a_rel(4) * currentFigPos(4)
                    ];
                    panelPos = previewPanel_position_a;
                    set(resultsTable, 'Position', tablePos);
                    set(previewPanel, 'Position', panelPos);
                end
            end
        catch ME
            warning('Error scaling elements: %s', ME.message);
        end
    end
    
    function toggleTableSize()
        currentFigPos = get(fig, 'Position');
        
        if table_minimized
            relTablePos = resultsTable_position_a_rel;
            tablePos = [
                relTablePos(1) * currentFigPos(3),
                relTablePos(2) * currentFigPos(4),
                relTablePos(3) * currentFigPos(3),
                relTablePos(4) * currentFigPos(4)
            ];
            panelPos = previewPanel_position_a;
            set(tableToggleBtn, 'String', '<');
        else
            relTablePos = resultsTable_position_b_rel;
            tablePos = [
                relTablePos(1) * currentFigPos(3),
                relTablePos(2) * currentFigPos(4),
                relTablePos(3) * currentFigPos(3),
                relTablePos(4) * currentFigPos(4)
            ];
            panelPos = previewPanel_position_b;
            set(tableToggleBtn, 'String', '>');
        end
        
        set(resultsTable, 'Position', tablePos);
        set(previewPanel, 'Position', panelPos);
        
        table_minimized = ~table_minimized;
    end
    
    function toggleTableCallback(~, ~)
        toggleTableSize();
    end
    
    function loadResults()
        if isempty(state.currentProjectId)
            resultsTable.Data = {};
            updateCounter(0, 0);
            return
        end
        
        dbPath = getDbPath();
        if isempty(dbPath) || ~isfile(dbPath)
            resultsTable.Data = {};
            updateCounter(0, 0);
            return
        end
        
        conn = openSqliteConnection(dbPath);
        if isempty(conn)
            resultsTable.Data = {};
            updateCounter(0, 0);
            return
        end
        
        try
            query = buildQuery();
            rows = sqlFetchWithConn(conn, query);
            
            if isempty(rows)
                resultsTable.Data = {};
                updateCounter(0, 0);
            else
                formattedData = formatTableData(rows);
                resultsTable.Data = formattedData;
                updateCounter(0, size(formattedData, 1));
            end
        catch ME
            warning('Failed to load results: %s', ME.message);
            resultsTable.Data = {};
            updateCounter(0, 0);
        end
        
        closeJdbcResource(conn);
    end
    
    function query = buildQuery()
        baseQuery = ['SELECT ar.id, ar.file_id, COALESCE(f.file_name, ''Unknown'') as file_name, ar.module_name, ar.report_path, ar.created_at ' ...
            'FROM analysis_results ar ' ...
            'LEFT JOIN files f ON f.id = ar.file_id ' ...
            'LEFT JOIN project_files pf ON pf.file_id = f.id AND pf.project_id = %d ' ...
            'WHERE (pf.project_id = %d OR ar.file_id IS NULL)'];
        
        whereClause = sprintf(baseQuery, state.currentProjectId, state.currentProjectId);
        
        if ~isempty(state.searchText)
            searchPattern = ['%%' escapeSql(state.searchText) '%%'];
            searchCondition = sprintf(' AND (COALESCE(f.file_name, '''') LIKE ''%s'' OR ar.module_name LIKE ''%s'')', ...
                searchPattern, searchPattern);
            whereClause = [whereClause searchCondition];
        end
        
        if ~isempty(state.filterModule)
            moduleCondition = sprintf(' AND ar.module_name = ''%s''', escapeSql(state.filterModule));
            whereClause = [whereClause moduleCondition];
        end
        
        orderClause = buildOrderClause();
        query = [whereClause ' ' orderClause];
    end
    
    function orderClause = buildOrderClause()
        switch state.sortBy
            case 'date'
                if strcmp(state.sortOrder, 'desc')
                    orderClause = 'ORDER BY ar.created_at DESC';
                else
                    orderClause = 'ORDER BY ar.created_at ASC';
                end
            case 'module'
                if strcmp(state.sortOrder, 'asc')
                    orderClause = 'ORDER BY ar.module_name ASC';
                else
                    orderClause = 'ORDER BY ar.module_name DESC';
                end
            case 'path'
                if strcmp(state.sortOrder, 'asc')
                    orderClause = 'ORDER BY ar.report_path ASC';
                else
                    orderClause = 'ORDER BY ar.report_path DESC';
                end
            otherwise
                orderClause = 'ORDER BY ar.report_path ASC';
        end
    end
    
    function data = formatTableData(rows)
        data = cell(size(rows, 1), 5);
        for i = 1:size(rows, 1)
            data{i, 1} = rows{i, 2};
            if isempty(rows{i, 3}) || (isnumeric(rows{i, 3}) && isnan(rows{i, 3}))
                data{i, 2} = 'Unknown';
            else
                data{i, 2} = rows{i, 3};
            end
            data{i, 3} = rows{i, 4};
            data{i, 4} = rows{i, 5};
            createdDate = rows{i, 6};
            if ischar(createdDate) || isstring(createdDate)
                data{i, 5} = createdDate;
            else
                data{i, 5} = datestr(createdDate);
            end
        end
    end
    
    function searchChanged(src, ~)
        state.searchText = get(src, 'String');
        loadResults();
    end
    
    function sortChanged(src, ~)
        idx = get(src, 'Value');
        switch idx
            case 1
                state.sortBy = 'path';
                state.sortOrder = 'asc';
            case 2
                state.sortBy = 'path';
                state.sortOrder = 'desc';
            case 3
                state.sortBy = 'date';
                state.sortOrder = 'desc';
            case 4
                state.sortBy = 'date';
                state.sortOrder = 'asc';
            case 5
                state.sortBy = 'module';
                state.sortOrder = 'asc';
            case 6
                state.sortBy = 'module';
                state.sortOrder = 'desc';
        end
        loadResults();
    end
    
    function updateModuleFilterList()
        if isempty(state.currentProjectId)
            set(moduleFilterSelect, 'String', {'All Modules'});
            set(moduleFilterSelect, 'Value', 1);
            return
        end
        
        dbPath = getDbPath();
        if isempty(dbPath) || ~isfile(dbPath)
            set(moduleFilterSelect, 'String', {'All Modules'});
            set(moduleFilterSelect, 'Value', 1);
            return
        end
        
        conn = openSqliteConnection(dbPath);
        if isempty(conn)
            set(moduleFilterSelect, 'String', {'All Modules'});
            set(moduleFilterSelect, 'Value', 1);
            return
        end
        
        try
            query = sprintf(['SELECT DISTINCT ar.module_name ' ...
                'FROM analysis_results ar ' ...
                'LEFT JOIN files f ON f.id = ar.file_id ' ...
                'LEFT JOIN project_files pf ON pf.file_id = f.id AND pf.project_id = %d ' ...
                'WHERE (pf.project_id = %d OR ar.file_id IS NULL) ' ...
                'AND ar.module_name IS NOT NULL ' ...
                'ORDER BY ar.module_name ASC'], ...
                state.currentProjectId, state.currentProjectId);
            
            rows = sqlFetchWithConn(conn, query);
            
            if isempty(rows)
                moduleList = {'All Modules'};
            else
                moduleList = cell(1, size(rows, 1) + 1);
                moduleList{1} = 'All Modules';
                for i = 1:size(rows, 1)
                    moduleList{i + 1} = rows{i, 1};
                end
            end
            
            set(moduleFilterSelect, 'String', moduleList);
            
            currentModule = state.filterModule;
            if isempty(currentModule)
                set(moduleFilterSelect, 'Value', 1);
            else
                moduleIdx = find(strcmp(moduleList, currentModule), 1);
                if isempty(moduleIdx)
                    set(moduleFilterSelect, 'Value', 1);
                    state.filterModule = '';
                else
                    set(moduleFilterSelect, 'Value', moduleIdx);
                end
            end
        catch ME
            warning('Failed to load modules: %s', ME.message);
            set(moduleFilterSelect, 'String', {'All Modules'});
            set(moduleFilterSelect, 'Value', 1);
        end
        
        closeJdbcResource(conn);
    end
    
    function moduleFilterChanged(src, ~)
        modules = get(src, 'String');
        idx = get(src, 'Value');
        
        if iscell(modules) && idx <= numel(modules)
            selectedModule = modules{idx};
            if strcmp(selectedModule, 'All Modules')
                state.filterModule = '';
            else
                state.filterModule = selectedModule;
            end
        else
            state.filterModule = '';
        end
        
        loadResults();
    end
    
    function handleTableSelection(src, event)
        if isempty(event.Indices)
            src.UserData.row = 1;
            src.UserData.multi = 1;
            updateCounter(0, size(src.Data, 1));
            set(openBtn, 'Enable', 'off');
            set(openFolderBtn, 'Enable', 'off');
            set(deleteBtn, 'Enable', 'off');
            previewPanel = findobj(fig, 'Tag', 'previewPanel');
            if ~isempty(previewPanel)
                delete(previewPanel.Children);
            end
            zoom(fig, 'off');
            pan(fig, 'off');
            return
        end
        rows = unique(event.Indices(:, 1));
        src.UserData.row = rows(1);
        src.UserData.multi = rows;
        updateCounter(numel(rows), size(src.Data, 1));
        set(openBtn, 'Enable', 'on');
        set(openFolderBtn, 'Enable', 'on');
        set(deleteBtn, 'Enable', 'on');
        
        previewPanel = findobj(fig, 'Tag', 'previewPanel');
        if ~isempty(previewPanel) && ~isempty(src.Data)
            delete(previewPanel.Children);
            reportPath = src.Data{rows(1), 4};
            if ~isempty(reportPath)
                ax = openResultPreview(reportPath, previewPanel);
                if ~isempty(ax) && isvalid(ax)
                    activatePreviewTools(ax);
                end
            end
        end
    end
    
    function zoomButtonCallback(src, ~)
        previewPanel = findobj(fig, 'Tag', 'previewPanel');
        if isempty(previewPanel)
            return
        end
        axesList = findobj(previewPanel, 'Type', 'axes');
        if isempty(axesList)
            return
        end
        pan(fig, 'off');
        zoom(fig, 'on');
        for i = 1:length(axesList)
            zoom(axesList(i), 'on');
        end
    end
    
    function panButtonCallback(src, ~)
        previewPanel = findobj(fig, 'Tag', 'previewPanel');
        if isempty(previewPanel)
            return
        end
        axesList = findobj(previewPanel, 'Type', 'axes');
        if isempty(axesList)
            return
        end
        zoom(fig, 'off');
        pan(fig, 'on');
        for i = 1:length(axesList)
            pan(axesList(i), 'on');
        end
    end
    
    function activatePreviewTools(ax)
        if isempty(ax) || ~isvalid(ax)
            return
        end
        zoom(fig, 'off');
        pan(fig, 'off');
    end
    
    function updateCounter(selected, total)
        set(totalText, 'String', sprintf('Selected: %d / Total: %d', selected, total));
    end
    
    function openSelectedResult(~, ~)
        if ~ishandle(resultsTable)
            return
        end
        data = resultsTable.Data;
        if isempty(data)
            return
        end
        selected = getSelectedRows(size(data, 1));
        if isempty(selected)
            return
        end
        reportPath = data{selected(1), 4};
        openReportFile(reportPath);
    end
    
    function openResultFolder(~, ~)
        if ~ishandle(resultsTable)
            return
        end
        data = resultsTable.Data;
        if isempty(data)
            return
        end
        selected = getSelectedRows(size(data, 1));
        if isempty(selected)
            return
        end
        reportPath = data{selected(1), 4};
        openReportFolder(reportPath);
    end
    
    function deleteSelectedResult(~, ~)
        if ~ishandle(resultsTable)
            return
        end
        data = resultsTable.Data;
        if isempty(data)
            return
        end
        selectedRows = getSelectedRows(size(data, 1));
        if isempty(selectedRows)
            return
        end
        try
            reportPaths = cellfun(@(v) normalizePath(v), data(selectedRows, 4), 'UniformOutput', false);
            deleteAnalysisResults(reportPaths, @loadResults);
        catch ME
            msgbox(sprintf('Failed to delete result: %s', ME.message), 'Error', 'error');
        end
    end
    
    function refreshTable(~, ~)
        state.currentProjectId = readStoredProjectId();
        if ~isempty(state.currentProjectId)
            projectName = getProjectName(state.currentProjectId);
            if ~isempty(projectName)
                set(fig, 'Name', sprintf('Results Gallery: %s', projectName));
            end
        end
        updateModuleFilterList();
        loadResults();
    end
    
    function rows = getSelectedRows(maxRows)
        rows = [];
        if ~ishandle(resultsTable)
            return
        end
        ud = resultsTable.UserData;
        if isfield(ud, 'multi') && ~isempty(ud.multi)
            rows = ud.multi;
        elseif isfield(ud, 'row') && ~isempty(ud.row)
            rows = ud.row;
        end
        rows = rows(rows >= 1 & rows <= maxRows);
        if isempty(rows)
            rows = min(max(1, ud.row), maxRows);
        end
    end
    
    
    function addResultManually(~, ~)
        [file, path] = uigetfile({'*.*', 'All files'}, 'Select report file');
        if isequal(file, 0)
            return
        end
        reportPath = fullfile(path, file);
        
        prompt = {'Module name:'};
        dlgTitle = 'Add Analysis Result';
        defaultAnswer = {''};
        answer = inputdlg(prompt, dlgTitle, 1, defaultAnswer);
        if isempty(answer)
            return
        end
        
        moduleName = strtrim(answer{1});
        if isempty(moduleName)
            return
        end
        
        result = struct();
        result.module_name = moduleName;
        result.report_path = reportPath;
        
        logAnalysisResult([], result);
        loadResults();
    end
end

function projectName = getProjectName(projectId)
    projectName = [];
    if isempty(projectId)
        return
    end
    rows = sqlFetch(sprintf('SELECT name FROM projects WHERE id = %d', projectId));
    if ~isempty(rows)
        projectName = rows{1};
    end
end

