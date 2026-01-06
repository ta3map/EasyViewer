function resultsGalleryGUI()
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
        state.sortBy = 'date';
        state.sortOrder = 'desc';
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
    coordsFile = fullfile(fileparts(mfilename('fullpath')), '..', 'configs', 'window_coords', 'resultsGalleryGUI_coords.json');
    if exist(coordsFile, 'file')
        coordsData = jsondecode(fileread(coordsFile));
    else
        error('Coordinates file not found: %s', coordsFile);
    end
    
    % Вспомогательная функция для получения координат элемента
    function pos = getElementPosition(tag)
        if isfield(coordsData.elements, tag)
            pos = coordsData.elements.(tag);
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
    
    base_figure_position = coordsData.base_figure_position;
    fig = figure('Position', base_figure_position, ...
        'Name', sprintf('Results Gallery: %s', projectName), ...
        'NumberTitle', 'off', ...
        'MenuBar', 'none', ...
        'ToolBar', 'none', ...
        'Resize', 'on', ...
        'Tag', figTag);
    
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
        'String', {'Date Created (Newest)', 'Date Created (Oldest)', 'Module Name (A-Z)', 'Module Name (Z-A)'}, ...
        'FontSize', 10, ...
        'Callback', @sortChanged, ...
        'Tag', 'sortSelect');
    
    resultsTable = uitable('Position', getElementPosition('resultsTable'), ...
        'ColumnWidth', {60, 200, 150, 450, 100}, ...
        'ColumnName', {'File ID', 'File Name', 'Module Name', 'Report Path', 'Created Date'}, ...
        'ColumnEditable', [false, false, false, false, false], ...
        'Data', cell(0, 5), ...
        'Tag', 'resultsTable');
    resultsTable.UserData = struct('row', 1, 'multi', 1);
    resultsTable.CellSelectionCallback = @handleTableSelection;
    
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
    
    counterText = uicontrol('Style', 'text', ...
        'Position', getElementPosition('counterText'), ...
        'String', 'Selected: 0', ...
        'HorizontalAlignment', 'left', ...
        'FontSize', 10, ...
        'Tag', 'counterText');
    
    totalText = uicontrol('Style', 'text', ...
        'Position', getElementPosition('totalText'), ...
        'String', 'Total: 0', ...
        'HorizontalAlignment', 'left', ...
        'FontSize', 10, ...
        'Tag', 'totalText');
    
    refreshBtn = uicontrol('Style', 'pushbutton', ...
        'Position', getElementPosition('refreshBtn'), ...
        'String', 'Refresh', ...
        'FontSize', 10, ...
        'Callback', @refreshTable, ...
        'Tag', 'refreshBtn');
    
    % Устанавливаем обработчик изменения размера окна
    set(fig, 'SizeChangedFcn', @(~,~) resizeComponentsCallback(fig, coordsFile));
    
    % Разворачиваем окно после успешной инициализации
    fig.WindowState = 'maximized';
    
    loadResults();
    
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
            otherwise
                orderClause = 'ORDER BY ar.created_at DESC';
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
                state.sortBy = 'date';
                state.sortOrder = 'desc';
            case 2
                state.sortBy = 'date';
                state.sortOrder = 'asc';
            case 3
                state.sortBy = 'module';
                state.sortOrder = 'asc';
            case 4
                state.sortBy = 'module';
                state.sortOrder = 'desc';
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
            return
        end
        rows = unique(event.Indices(:, 1));
        src.UserData.row = rows(1);
        src.UserData.multi = rows;
        updateCounter(numel(rows), size(src.Data, 1));
        set(openBtn, 'Enable', 'on');
        set(openFolderBtn, 'Enable', 'on');
        set(deleteBtn, 'Enable', 'on');
    end
    
    function updateCounter(selected, total)
        set(counterText, 'String', sprintf('Selected: %d', selected));
        set(totalText, 'String', sprintf('Total: %d', total));
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

