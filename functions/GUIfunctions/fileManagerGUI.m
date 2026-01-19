function fileManagerGUI()
    global SettingsFilepath FileManagerDbPath
    figTag = 'fileManagerGUI';
    guiFig = findobj('Type', 'figure', 'Tag', figTag);
    if ~isempty(guiFig)
        figure(guiFig);
        return
    end
    
    persistent state
    if isempty(state)
        state = struct();
        state.projects = [];
        state.files = [];
        state.currentProjectId = [];
        clearSelection();
        state.dbPath = '';
        state.metadataFields = {};
        state.metadataData = struct();
        state.fieldNameMap = struct();
        state.selectedRows = [];
        state.selectedModule = [];
        state.moduleQueue = {};
    end
    
    if ~isfield(state, 'selectedColumn')
        state.selectedColumn = [];
    end
    if ~isfield(state, 'selectedFileId')
        state.selectedFileId = [];
    end
    if ~isfield(state, 'selectedRows')
        state.selectedRows = [];
    end
    if ~isfield(state, 'selectedModule')
        state.selectedModule = [];
    end
    if ~isfield(state, 'moduleQueue')
        state.moduleQueue = {};
    end
    
    state.dbPath = initDbPath();
    
    % Инициализация фильтра файлов (локальная переменная)
    currentFilter = struct('columnName', '', 'searchText', '');
    
    % Загружаем координаты элементов из JSON файла
    coordsFile = getGUIConfigPath('fileManagerGUI_coords.json');
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
    
    functionFolder = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(fileparts(functionFolder));
    moduleDir = fullfile(projectRoot, 'modules');
    if exist(moduleDir, 'dir')
        currentPath = strsplit(path, pathsep); %#ok<PATHNM>
        if ~any(strcmp(currentPath, moduleDir))
            addpath(moduleDir);
        end
    end
    
    % Функция обработки закрытия окна (определяем до создания окна)
    function closeFileManagerWindow(src, ~)
        delete(src);
        manageMainWindows('fileManagerGUI');
    end
    
    base_figure_position = coordsData.base_figure_position;
    fig = figure('Position', base_figure_position, ...
        'Name', 'File Manager (SQL)', ...
        'NumberTitle', 'off', ...
        'MenuBar', 'none', ...
        'ToolBar', 'none', ...
        'Resize', 'on', ...
        'Tag', figTag, ...
        'CloseRequestFcn', @closeFileManagerWindow);
    
    uicontrol('Style', 'text', ...
        'Position', getElementPosition('databaseText'), ...
        'String', 'Database', ...
        'HorizontalAlignment', 'left', ...
        'FontSize', 12, ...
        'FontWeight', 'bold', ...
        'Tag', 'databaseText');
    
    dbPathDisplay = uicontrol('Style', 'edit', ...
        'Position', getElementPosition('dbPathDisplay'), ...
        'String', truncatePath(state.dbPath), ...
        'Enable', 'inactive', ...
        'HorizontalAlignment', 'left', ...
        'Tag', 'dbPathDisplay');
    
    dbBtn = uicontrol('Style', 'pushbutton', ...
        'Position', getElementPosition('dbBtn'), ...
        'String', 'Select Database', ...
        'FontSize', 11, ...
        'Callback', @chooseDbPath, ...
        'Tag', 'dbBtn');
    
    createDbBtn = uicontrol('Style', 'pushbutton', ...
        'Position', getElementPosition('createDbBtn'), ...
        'String', 'New Database', ...
        'FontSize', 11, ...
        'Callback', @createNewDatabase, ...
        'Tag', 'createDbBtn');
    
    uicontrol('Style', 'text', ...
        'Position', getElementPosition('projectText'), ...
        'String', 'Project', ...
        'HorizontalAlignment', 'left', ...
        'FontSize', 12, ...
        'FontWeight', 'bold', ...
        'Tag', 'projectText');
    
    projectSelect = uicontrol('Style', 'popupmenu', ...
        'Position', getElementPosition('projectSelect'), ...
        'String', {'Loading...'}, ...
        'Callback', @switchProject, ...
        'Tag', 'projectSelect');
    
    projectActionsMenu = uicontrol('Style', 'popupmenu', ...
        'Position', getElementPosition('projectActionsMenu'), ...
        'String', {'Project Actions', 'New Project', 'Rename Project', 'Delete Project', 'Export Project', 'Import Project'}, ...
        'FontSize', 11, ...
        'Value', 1, ...
        'Callback', @handleProjectAction, ...
        'Tag', 'projectActionsMenu');

    fileActionsMenu = uicontrol('Style', 'popupmenu', ...
        'Position', getElementPosition('fileActionsMenu'), ...
        'String', {'File Actions', 'Add Files', 'Add Field', 'Delete Field', 'Filter Files', 'Clear Filter'}, ...
        'FontSize', 11, ...
        'Value', 1, ...
        'Callback', @handleFileAction, ...
        'Tag', 'fileActionsMenu');
    
    deleteBtn = uicontrol('Style', 'pushbutton', ...
        'Position', getElementPosition('deleteBtn'), ...
        'String', 'Remove', ...
        'FontSize', 11, ...
        'Callback', @removeSelectedFile, ...
        'Enable', 'off', ...
        'Tag', 'deleteBtn');
    
    openFileFolderBtn = uicontrol('Style', 'pushbutton', ...
        'Position', getElementPosition('openFileFolderBtn'), ...
        'String', 'File Folder', ...
        'FontSize', 11, ...
        'Callback', @openFileFolder, ...
        'Enable', 'off', ...
        'Tag', 'openFileFolderBtn');
    
    openBtn = uicontrol('Style', 'pushbutton', ...
        'Position', getElementPosition('openBtn'), ...
        'String', 'Open', ...
        'FontSize', 14, ...
        'Callback', @openSelectedFile, ...
        'Enable', 'off', ...
        'Tag', 'openBtn');
    
    moduleList = listModulesInDir();
    filterByModuleCheckbox = uicontrol('Style', 'checkbox', ...
        'Position', getElementPosition('filterByModuleCheckbox'), ...
        'String', 'Filter by module', ...
        'Value', 0, ...
        'Callback', @filterByModuleChanged, ...
        'Tag', 'filterByModuleCheckbox');
    
    uicontrol('Style', 'text', ...
        'Position', getElementPosition('analysisText'), ...
        'String', 'Analysis', ...
        'HorizontalAlignment', 'left', ...
        'FontSize', 12, ...
        'FontWeight', 'bold', ...
        'Tag', 'analysisText');
    
    moduleSelect = uicontrol('Style', 'popupmenu', ...
        'Position', getElementPosition('moduleSelect'), ...
        'String', moduleList, ...
        'Callback', @moduleSelectionChanged, ...
        'Tag', 'moduleSelect');
    
    if ~isempty(state.selectedModule)
        savedModuleIdx = find(strcmp(moduleList, state.selectedModule), 1);
        if ~isempty(savedModuleIdx)
            moduleSelect.Value = savedModuleIdx;
        end
    end
    
    addToQueueBtn = uicontrol('Style', 'pushbutton', ...
        'Position', getElementPosition('addToQueueBtn'), ...
        'String', 'Add to queue', ...
        'FontSize', 11, ...
        'Callback', @addModuleToQueue, ...
        'Tag', 'addToQueueBtn');
    
    moduleQueueTable = uitable('Position', getElementPosition('moduleQueueTable'), ...
        'ColumnWidth', {30, 290}, ...
        'ColumnName', {'#', 'Module Name'}, ...
        'ColumnEditable', [false, false], ...
        'Tag', 'moduleQueueTable', ...
        'Data', cell(0, 2));
    
    launchQueueBtn = uicontrol('Style', 'pushbutton', ...
        'Position', getElementPosition('launchQueueBtn'), ...
        'String', 'Launch Module', ...
        'FontSize', 11, ...
        'Callback', @callModulesCallback, ...
        'Enable', 'off', ...
        'Tag', 'launchQueueBtn');
    
    clearQueueBtn = uicontrol('Style', 'pushbutton', ...
        'Position', getElementPosition('clearQueueBtn'), ...
        'String', 'Clear queue', ...
        'FontSize', 11, ...
        'Callback', @clearModuleQueue, ...
        'Tag', 'clearQueueBtn');
    
    openAnalysisBtn = uicontrol('Style', 'pushbutton', ...
        'Position', getElementPosition('openAnalysisBtn'), ...
        'String', 'Open Result', ...
        'FontSize', 11, ...
        'Callback', @openSelectedAnalysis, ...
        'Enable', 'off', ...
        'Tag', 'openAnalysisBtn');
    
    openAnalysisFolderBtn = uicontrol('Style', 'pushbutton', ...
        'Position', getElementPosition('openAnalysisFolderBtn'), ...
        'String', 'Result Folder', ...
        'FontSize', 11, ...
        'Callback', @openAnalysisFolder, ...
        'Enable', 'off', ...
        'Tag', 'openAnalysisFolderBtn');
    
    deleteAnalysisBtn = uicontrol('Style', 'pushbutton', ...
        'Position', getElementPosition('deleteAnalysisBtn'), ...
        'String', 'Delete Result', ...
        'FontSize', 11, ...
        'Callback', @deleteSelectedAnalysis, ...
        'Enable', 'off', ...
        'Tag', 'deleteAnalysisBtn');

    rerunAnalysisBtn = uicontrol('Style', 'pushbutton', ...
        'Position', getElementPosition('rerunAnalysisBtn'), ...
        'String', 'Re-run Analysis', ...
        'FontSize', 11, ...
        'Callback', @rerunAnalysisCallback, ...
        'Enable', 'off', ...
        'Tag', 'rerunAnalysisBtn');

    fileTable = uitable('Position', getElementPosition('fileTable'), ...
        'ColumnWidth', {60, 120, 400}, ...
        'ColumnName', {'File ID', 'File Name', 'Path'}, ...
        'ColumnEditable', [false, false, false], ...
        'Tag', 'fileTable');
    
    uicontrol('Style', 'text', ...
        'Position', getElementPosition('resultsText'), ...
        'String', 'Results', ...
        'HorizontalAlignment', 'left', ...
        'FontSize', 12, ...
        'FontWeight', 'bold', ...
        'Tag', 'resultsText');
    
    analysisTable = uitable('Position', getElementPosition('analysisTable'), ...
        'ColumnWidth', {60, 110, 60}, ...
        'ColumnName', {'File ID', 'Report Path', 'Module'}, ...
        'ColumnEditable', [false, false, false], ...
        'Data', cell(0, 3), ...
        'Tag', 'analysisTable');
    analysisTable.UserData = struct('row', 1, 'multi', 1);
    analysisTable.CellSelectionCallback = @handleAnalysisSelection;
    
    metaAnalysisBtn = uicontrol('Style', 'pushbutton', ...
        'Position', getElementPosition('metaAnalysisBtn'), ...
        'String', 'Metadata Analysis', ...
        'FontSize', 11, ...
        'Callback', @metadataAnalysisCallback, ...
        'Tag', 'metaAnalysisBtn');
    
    tableModificationModules = {
        struct('moduleName', 'assignFolderIds', 'fieldName', 'folder_id', 'displayName', 'Assign Folder IDs'),
        struct('moduleName', 'assignFileTypeId', 'fieldName', 'file_extension', 'displayName', 'Assign File Extension'),
        struct('moduleName', 'assignStimulusPairId', 'fieldName', 'pair_id', 'displayName', 'Assign Stimulus Pair IDs'),
        struct('moduleName', 'calculateGabaAmpaOnsetDiff', 'fieldName', 'GABA-AMPA', 'displayName', 'Calculate GABA-AMPA Onset Difference')
    };
    
    tableModificationMenuStrings = {'Table Modifications'};
    for i = 1:numel(tableModificationModules)
        tableModificationMenuStrings{end+1} = tableModificationModules{i}.displayName;
    end
    
    tableModificationMenu = uicontrol('Style', 'popupmenu', ...
        'Position', getElementPosition('tableModificationMenu'), ...
        'String', tableModificationMenuStrings, ...
        'FontSize', 11, ...
        'Value', 1, ...
        'Callback', @handleTableModificationSelection, ...
        'Tag', 'tableModificationMenu', ...
        'UserData', tableModificationModules);
    
    resultsGalleryBtn = uicontrol('Style', 'pushbutton', ...
        'Position', getElementPosition('resultsGalleryBtn'), ...
        'String', 'Results Gallery', ...
        'FontSize', 11, ...
        'Callback', @openResultsGallery, ...
        'Tag', 'resultsGalleryBtn');

    fileTable.UserData = struct('row', [], 'col', [], 'vpos', [], 'hpos', []);
    fileTable.CellSelectionCallback = @handleCellSelection;
    fileTable.CellEditCallback = @handleCellEdit;
    
    fileTableCounter = uicontrol('Style', 'text', ...
        'Position', getElementPosition('fileTableCounter'), ...
        'String', 'Selected: 0', ...
        'HorizontalAlignment', 'left', ...
        'Tag', 'fileTableCounter');
    
    analysisTableCounter = uicontrol('Style', 'text', ...
        'Position', getElementPosition('analysisTableCounter'), ...
        'String', 'Selected: 0', ...
        'HorizontalAlignment', 'left', ...
        'Tag', 'analysisTableCounter');
    
    % Устанавливаем обработчик изменения размера окна
    set(fig, 'SizeChangedFcn', @(~,~) resizeComponentsCallback(fig, coordsFile));
    
    % Разворачиваем окно после успешной инициализации
    fig.WindowState = 'maximized';
    
    loadProjectsFromDb();
    updateQueueTable();
    
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
    
    function loadProjectsFromDb()
        if isempty(state.dbPath) || ~isfile(state.dbPath)
            set(dbPathDisplay, 'String', 'No database selected');
            projectSelect.String = {'No projects'};
            projectSelect.Value = 1;
            state.projects = [];
            state.files = [];
            clearSelection();
            updateTable([]);
            
            promptCreateDatabase();
            return
        end
        
        projects = fetchProjects();
        if isempty(projects)
            projectSelect.String = {'No projects'};
            projectSelect.Value = 1;
            state.projects = [];
            state.currentProjectId = [];
            clearSelection();
            updateTable([]);
            return
        end
        state.projects = projects;
        names = arrayfun(@(p) sprintf('%s (#%d)', p.name, p.id), projects, 'UniformOutput', false);
        projectSelect.String = names;
        savedId = readStoredProjectId();
        defaultIdx = 1;
        if ~isempty(savedId)
            match = find([projects.id] == savedId, 1);
            if ~isempty(match)
                defaultIdx = match;
                state.currentProjectId = savedId;
            end
        end
        projectSelect.Value = defaultIdx;
        selectProjectByIndex(defaultIdx);
    end
    
    function switchProject(src, ~)
        idx = src.Value;
        selectProjectByIndex(idx);
    end
    
    function handleProjectAction(src, ~)
        actionIdx = src.Value;
        if actionIdx == 1
            src.Value = 1;
            return
        end
        
        src.Value = 1;
        
        switch actionIdx
            case 2
                createNewProject();
            case 3
                renameProject();
            case 4
                deleteProject();
            case 5
                exportProject();
            case 6
                importProject();
        end
    end
    
    function renameProject(~, ~)
        if isempty(state.currentProjectId)
            msgbox('No project selected', 'Error', 'error');
            return
        end
        
        projectIdx = find([state.projects.id] == state.currentProjectId, 1);
        if isempty(projectIdx)
            msgbox('Project not found', 'Error', 'error');
            return
        end
        
        currentName = state.projects(projectIdx).name;
        prompt = {'Enter new project name:'};
        dlgTitle = 'Rename Project';
        defaultAnswer = {currentName};
        answer = inputdlg(prompt, dlgTitle, 1, defaultAnswer);
        if isempty(answer)
            return
        end
        
        newName = strtrim(answer{1});
        if isempty(newName)
            msgbox('Project name cannot be empty', 'Error', 'error');
            return
        end
        
        if strcmp(newName, currentName)
            return
        end
        
        autoBackupDatabase();
        
        try
            escapedNewName = escapeSql(newName);
            updateQuery = sprintf('UPDATE projects SET name = ''%s'', updated_at = CURRENT_TIMESTAMP WHERE id = %d', ...
                escapedNewName, state.currentProjectId);
            sqlExec(updateQuery);
            
            debugState('fileManagerGUI', 'renameProject: renamed project id=%d from "%s" to "%s"', ...
                state.currentProjectId, currentName, newName);
            
            loadProjectsFromDb();
            match = find([state.projects.id] == state.currentProjectId, 1);
            if ~isempty(match)
                projectSelect.Value = match;
                selectProjectByIndex(match);
            end
            
            msgbox('Project renamed successfully', 'Success', 'help');
        catch ME
            debugState('fileManagerGUI', 'renameProject: error - %s', ME.message);
            msgbox(sprintf('Failed to rename project: %s', ME.message), 'Error', 'error');
        end
    end
    
    function handleFileAction(src, ~)
        actionIdx = src.Value;
        if actionIdx == 1
            src.Value = 1;
            return
        end
        
        src.Value = 1;
        
        switch actionIdx
            case 2
                addFilesToProject();
            case 3
                addMetadataField();
            case 4
                deleteMetadataField();
            case 5
                showFileFilterDialog();
            case 6
                clearFileFilter();
        end
    end
    
    function promptCreateDatabase()
        choice = questdlg('No database found. Would you like to create a new database?', ...
            'Database Not Found', 'Create Database', 'Select Database', 'Cancel', 'Create Database');
        switch choice
            case 'Create Database'
                createNewDatabase();
            case 'Select Database'
                chooseDbPath();
            case 'Cancel'
        end
    end
    
    function createNewProject(~, ~)
        if isempty(state.dbPath) || ~isfile(state.dbPath)
            promptCreateDatabase();
            if isempty(state.dbPath) || ~isfile(state.dbPath)
                return
            end
        end
        prompt = {'Enter project name:'};
        dlgTitle = 'New Project';
        defaultAnswer = {'New Project'};
        answer = inputdlg(prompt, dlgTitle, 1, defaultAnswer);
        if isempty(answer)
            return
        end
        projectName = strtrim(answer{1});
        if isempty(projectName)
            msgbox('Project name cannot be empty', 'Error', 'error');
            return
        end
        newProjectId = insertProject(projectName);
        if isempty(newProjectId)
            msgbox('Failed to create project', 'Error', 'error');
            return
        end
        clearSelection();
        loadProjectsFromDb();
        match = find([state.projects.id] == newProjectId, 1);
        if ~isempty(match)
            projectSelect.Value = match;
            selectProjectByIndex(match);
        end
    end
    
    function deleteProject(~, ~)
        if isempty(state.currentProjectId)
            msgbox('No project selected', 'Error', 'error');
            return
        end
        
        projectIdx = find([state.projects.id] == state.currentProjectId, 1);
        if isempty(projectIdx)
            msgbox('Project not found', 'Error', 'error');
            return
        end
        
        projectName = state.projects(projectIdx).name;
        choice = questdlg(sprintf('Delete project "%s" and all its files, groups, and analysis results?', projectName), ...
            'Delete Project', 'Delete', 'Cancel', 'Cancel');
        if ~strcmp(choice, 'Delete')
            return
        end
        
        autoBackupDatabase();
        
        try
            deleteQuery = sprintf('DELETE FROM projects WHERE id = %d', state.currentProjectId);
            sqlExec(deleteQuery);
            
            debugState('fileManagerGUI', 'deleteProject: deleted project id=%d, name=%s', state.currentProjectId, projectName);
            
            clearSelection();
            loadProjectsFromDb();
            
            msgbox('Project deleted successfully', 'Success', 'help');
        catch ME
            debugState('fileManagerGUI', 'deleteProject: error - %s', ME.message);
            msgbox(sprintf('Failed to delete project: %s', ME.message), 'Error', 'error');
        end
    end
    
    function createNewDatabase(~, ~)
        startDir = fileparts(state.dbPath);
        if isempty(startDir) || ~isfolder(startDir)
            startDir = fileparts(defaultDbPath());
        end
        [file, path] = uiputfile('*.db', 'Create New SQLite Database', startDir);
        if isequal(file, 0)
            return
        end
        newPath = fullfile(path, file);
        
        if ~isfolder(path)
            msgbox('Selected directory does not exist', 'Error', 'error');
            return
        end
        
        conn = openSqliteConnection(newPath);
        if isempty(conn)
            msgbox('Failed to create database connection', 'Error', 'error');
            return
        end
        
        stmt = [];
        try
            stmt = conn.createStatement();
            
            stmt.executeUpdate(['CREATE TABLE IF NOT EXISTS projects (' ...
                'id INTEGER PRIMARY KEY, ' ...
                'name TEXT NOT NULL, ' ...
                'description TEXT, ' ...
                'created_at DATETIME DEFAULT CURRENT_TIMESTAMP, ' ...
                'updated_at DATETIME DEFAULT CURRENT_TIMESTAMP)']);
            
            stmt.executeUpdate(['CREATE TABLE IF NOT EXISTS groups (' ...
                'id INTEGER PRIMARY KEY, ' ...
                'project_id INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE, ' ...
                'name TEXT NOT NULL, ' ...
                'created_at DATETIME DEFAULT CURRENT_TIMESTAMP)']);
            
            stmt.executeUpdate(['CREATE TABLE IF NOT EXISTS group_metadata (' ...
                'id INTEGER PRIMARY KEY, ' ...
                'group_id INTEGER NOT NULL REFERENCES groups(id) ON DELETE CASCADE, ' ...
                'field_name TEXT NOT NULL, ' ...
                'field_value TEXT, ' ...
                'updated_at DATETIME DEFAULT CURRENT_TIMESTAMP, ' ...
                'UNIQUE(group_id, field_name))']);
            
            stmt.executeUpdate(['CREATE TABLE IF NOT EXISTS files (' ...
                'id INTEGER PRIMARY KEY, ' ...
                'file_path TEXT NOT NULL, ' ...
                'file_name TEXT NOT NULL, ' ...
                'created_at DATETIME DEFAULT CURRENT_TIMESTAMP, ' ...
                'UNIQUE(file_path, file_name))']);
            
            stmt.executeUpdate(['CREATE TABLE IF NOT EXISTS project_files (' ...
                'project_id INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE, ' ...
                'file_id INTEGER NOT NULL REFERENCES files(id) ON DELETE CASCADE, ' ...
                'group_id INTEGER REFERENCES groups(id) ON DELETE SET NULL, ' ...
                'created_at DATETIME DEFAULT CURRENT_TIMESTAMP, ' ...
                'PRIMARY KEY (project_id, file_id))']);
            
            stmt.executeUpdate(['CREATE TABLE IF NOT EXISTS file_metadata (' ...
                'id INTEGER PRIMARY KEY, ' ...
                'file_id INTEGER REFERENCES files(id) ON DELETE SET NULL, ' ...
                'field_name TEXT NOT NULL, ' ...
                'field_value TEXT, ' ...
                'updated_at DATETIME DEFAULT CURRENT_TIMESTAMP, ' ...
                'UNIQUE(file_id, field_name))']);
            
            stmt.executeUpdate(['CREATE TABLE IF NOT EXISTS analysis_results (' ...
                'id INTEGER PRIMARY KEY, ' ...
                'file_id INTEGER REFERENCES files(id) ON DELETE SET NULL, ' ...
                'module_name TEXT NOT NULL, ' ...
                'module_display_name TEXT, ' ...
                'module_description TEXT, ' ...
                'analysis_timestamp BIGINT NOT NULL, ' ...
                'report_path TEXT NOT NULL, ' ...
                'parameters_json TEXT, ' ...
                'created_at DATETIME DEFAULT CURRENT_TIMESTAMP)']);
            
            stmt.executeUpdate(['CREATE TABLE IF NOT EXISTS analysis_scripts (' ...
                'id INTEGER PRIMARY KEY, ' ...
                'name TEXT NOT NULL, ' ...
                'script_path TEXT NOT NULL, ' ...
                'description TEXT, ' ...
                'UNIQUE(script_path))']);
            
            stmt.executeUpdate(['CREATE TABLE IF NOT EXISTS result_scripts (' ...
                'result_id INTEGER NOT NULL REFERENCES analysis_results(id) ON DELETE CASCADE, ' ...
                'script_id INTEGER NOT NULL REFERENCES analysis_scripts(id) ON DELETE CASCADE, ' ...
                'PRIMARY KEY (result_id, script_id))']);
            
            closeJdbcResource(stmt);
            closeJdbcResource(conn);
            
            state.dbPath = newPath;
            FileManagerDbPath = newPath;
            storeDbPath(newPath);
            set(dbPathDisplay, 'String', truncatePath(newPath));
            clearSelection();
            loadProjectsFromDb();
            
            msgbox('Database created successfully', 'Success', 'help');
        catch ME
            closeJdbcResource(stmt);
            closeJdbcResource(conn);
            msgbox(sprintf('Failed to initialize database: %s', ME.message), 'Error', 'error');
        end
    end
    
    function chooseDbPath(~, ~)
        startDir = fileparts(state.dbPath);
        if isempty(startDir) || ~isfolder(startDir)
            startDir = fileparts(defaultDbPath());
        end
        [file, path] = uigetfile('*.db', 'Select SQLite Database', startDir);
        if isequal(file, 0)
            return
        end
        newPath = fullfile(path, file);
            state.dbPath = newPath;
            FileManagerDbPath = newPath;
            storeDbPath(newPath);
            set(dbPathDisplay, 'String', truncatePath(newPath));
            clearSelection();
            loadProjectsFromDb();
    end
    
    function selectProjectByIndex(idx)
        if isempty(state.projects)
            return
        end
        idx = max(1, min(idx, numel(state.projects)));
        project = state.projects(idx);
        state.currentProjectId = project.id;
        storeCurrentProjectId(project.id);
        loadFilesForProject(project.id);
        set(fig, 'Name', ['File Manager: ', project.name]);
    end
    
    function loadFilesForProject(projectId)
        dbPath = getDbPath();
        if isempty(dbPath) || ~isfile(dbPath)
            state.files = [];
            clearSelection();
            updateTable([]);
            return
        end
        conn = openSqliteConnection(dbPath);
        if isempty(conn)
            state.files = [];
            clearSelection();
            updateTable([]);
            return
        end
        try
            files = fetchProjectFilesWithConn(conn, projectId);
            state.files = files;
            state.selectedRow = resolveRowBySelectedId(files);
            if isempty(state.selectedRow)
                clearSelection();
            end
            loadMetadataForProjectWithConn(conn, projectId);
            updateTable(files);
        catch ME
            warning('Failed to load project files: %s', ME.message);
            state.files = [];
            clearSelection();
            updateTable([]);
        end
        closeJdbcResource(conn);
    end
    
    function loadMetadataForProjectWithConn(conn, projectId)
        if isempty(state.files)
            state.metadataFields = {};
            state.metadataData = struct();
            state.fieldNameMap = struct();
            return
        end
        
        fileIds = [state.files.id];
        if isempty(fileIds)
            state.metadataFields = {};
            state.metadataData = struct();
            state.fieldNameMap = struct();
            return
        end
        
        idsStr = sprintf('%d,', fileIds);
        idsStr = idsStr(1:end-1);
        query = sprintf(['SELECT file_id, field_name, field_value ' ...
            'FROM file_metadata ' ...
            'WHERE file_id IN (%s)'], idsStr);
        rows = sqlFetchWithConn(conn, query);
        
        metadataMap = struct();
        allFields = {};
        fieldNameMap = struct();
        
        if ~isempty(rows)
            for i = 1:size(rows, 1)
                fileId = rows{i, 1};
                originalFieldName = rows{i, 2};
                fieldValue = rows{i, 3};
                if isempty(fieldValue)
                    fieldValue = '';
                end
                
                safeFieldName = makeSafeFieldName(originalFieldName);
                
                if ~isfield(fieldNameMap, safeFieldName)
                    fieldNameMap.(safeFieldName) = originalFieldName;
                end
                
                fileIdStr = sprintf('f%d', fileId);
                if ~isfield(metadataMap, fileIdStr)
                    metadataMap.(fileIdStr) = struct();
                end
                metadataMap.(fileIdStr).(safeFieldName) = fieldValue;
                
                if ~any(strcmp(allFields, originalFieldName))
                    allFields{end+1} = originalFieldName;
                end
            end
        end
        
        state.metadataFields = allFields;
        state.metadataData = metadataMap;
        state.fieldNameMap = fieldNameMap;
    end
    
    function addMetadataField(~, ~)
        if isempty(state.currentProjectId)
            msgbox('No project selected', 'Error', 'error');
            return
        end
        if isempty(state.files)
            msgbox('No files in project', 'Error', 'error');
            return
        end
        
        prompt = {'Enter field name:'};
        dlgTitle = 'Add Metadata Field';
        defaultAnswer = {''};
        answer = inputdlg(prompt, dlgTitle, 1, defaultAnswer);
        if isempty(answer)
            debugState('fileManagerGUI', 'addMetadataField: user cancelled input');
            return
        end
        originalFieldName = strtrim(answer{1});
        if isempty(originalFieldName)
            msgbox('Field name cannot be empty', 'Error', 'error');
            return
        end
        
        if any(strcmp(state.metadataFields, originalFieldName))
            msgbox('Field already exists', 'Error', 'error');
            debugState('fileManagerGUI', 'addMetadataField: field "%s" already exists', originalFieldName);
            return
        end
        
        safeFieldName = makeSafeFieldName(originalFieldName);
        debugState('fileManagerGUI', 'addMetadataField: adding field "%s" (safe: "%s") to %d files', ...
            originalFieldName, safeFieldName, numel(state.files));
        
        state.metadataFields{end+1} = originalFieldName;
        if ~isfield(state.fieldNameMap, safeFieldName)
            state.fieldNameMap.(safeFieldName) = originalFieldName;
        end
        
        for i = 1:numel(state.files)
            fileId = state.files(i).id;
            fileIdStr = sprintf('f%d', fileId);
            if ~isfield(state.metadataData, fileIdStr)
                state.metadataData.(fileIdStr) = struct();
            end
            state.metadataData.(fileIdStr).(safeFieldName) = '';
        end
        
        debugState('fileManagerGUI', 'addMetadataField: saving field "%s" to database for first file', originalFieldName);
        if ~isempty(state.files)
            syncMetadataForFile(state.files(1).id);
        end
        
        updateTable(state.files);
        debugState('fileManagerGUI', 'addMetadataField: field "%s" added successfully', originalFieldName);
    end
    
    function deleteMetadataField(~, ~)
        if isempty(state.metadataFields)
            msgbox('No metadata fields to delete', 'Error', 'error');
            return
        end
        
        [fieldIdx, ok] = listdlg('ListString', state.metadataFields, ...
            'SelectionMode', 'single', ...
            'PromptString', 'Select field to delete:', ...
            'Name', 'Delete Metadata Field', ...
            'ListSize', [300, 200]);
        
        if ~ok || isempty(fieldIdx)
            return
        end
        
        fieldName = state.metadataFields{fieldIdx};
        choice = questdlg(sprintf('Delete metadata field "%s"?', fieldName), ...
            'Delete Field', 'Delete', 'Cancel', 'Cancel');
        if ~strcmp(choice, 'Delete')
            return
        end
        
        autoBackupDatabase();
        
        safeFieldName = makeSafeFieldName(fieldName);
        state.metadataFields(fieldIdx) = [];
        if isfield(state.fieldNameMap, safeFieldName)
            state.fieldNameMap = rmfield(state.fieldNameMap, safeFieldName);
        end
        
        fileKeys = fieldnames(state.metadataData);
        for i = 1:numel(fileKeys)
            key = fileKeys{i};
            if isfield(state.metadataData.(key), safeFieldName)
                state.metadataData.(key) = rmfield(state.metadataData.(key), safeFieldName);
            end
        end
        
        deleteQuery = sprintf('DELETE FROM file_metadata WHERE field_name = ''%s''', escapeSql(fieldName));
        sqlExec(deleteQuery);
        
        state.selectedColumn = [];
        updateTable(state.files);
    end
    
    function syncMetadataForFile(fileId)
        if isempty(state.currentProjectId) || isempty(fileId)
            return
        end
        
        autoBackupDatabase();
        
        fileIdStr = sprintf('f%d', fileId);
        if ~isfield(state.metadataData, fileIdStr)
            return
        end
        
        fileMeta = state.metadataData.(fileIdStr);
        safeFieldNames = fieldnames(fileMeta);
        
        debugState('fileManagerGUI', 'Saving metadata to database for file_id=%d', fileId);
        for j = 1:numel(safeFieldNames)
            safeFieldName = safeFieldNames{j};
            originalFieldName = getOriginalFieldName(safeFieldName, state);
            fieldValue = fileMeta.(safeFieldName);
            if isempty(fieldValue)
                fieldValue = '';
            end
            saveFileMetadata(fileId, originalFieldName, fieldValue);
        end
    end
    
    function handleCellEdit(src, event)
        if isempty(event.Indices)
            return
        end
        rowIdx = event.Indices(1);
        colIdx = event.Indices(2);
        
        if rowIdx < 1 || rowIdx > numel(state.files)
            return
        end
        
        if colIdx < 1 || colIdx > numel(src.ColumnName)
            return
        end
        
        originalFieldName = src.ColumnName{colIdx};
        if any(strcmp(originalFieldName, {'File ID', 'File Name', 'Path'}))
            return
        end
        
        if ~any(strcmp(state.metadataFields, originalFieldName))
            debugState('fileManagerGUI', 'handleCellEdit: field "%s" not found in metadataFields', originalFieldName);
            return
        end
        
        fileId = state.files(rowIdx).id;
        safeFieldName = makeSafeFieldName(originalFieldName);
        newValue = event.NewData;
        if isempty(newValue)
            newValue = '';
        end
        
        debugState('fileManagerGUI', 'handleCellEdit: file_id=%d, field="%s", value="%s"', fileId, originalFieldName, newValue);
        
        fileIdStr = sprintf('f%d', fileId);
        if ~isfield(state.metadataData, fileIdStr)
            state.metadataData.(fileIdStr) = struct();
        end
        state.metadataData.(fileIdStr).(safeFieldName) = newValue;
        
        if ~isfield(state.fieldNameMap, safeFieldName)
            state.fieldNameMap.(safeFieldName) = originalFieldName;
        end
        
        syncMetadataForFile(fileId);
    end
    
    function addFilesToProject(~, ~)
        if isempty(state.currentProjectId)
            disp('No project selected');
            return
        end
        [fileNames, basePath] = uigetfile({'*.*', 'All files'}, 'Select files', 'MultiSelect', 'on');
        if isequal(fileNames, 0)
            return
        end
        if ischar(fileNames)
            fileNames = {fileNames};
        end
        autoBackupDatabase();
        for k = 1:numel(fileNames)
            fullPath = fullfile(basePath, fileNames{k});
            ensureFileInProject(fullPath, state.currentProjectId);
        end
        loadFilesForProject(state.currentProjectId);
    end
    
    function removeSelectedFile(~, ~)
        if isempty(state.selectedRow)
            return
        end
        rowIdx = state.selectedRow;
        if rowIdx < 1 || rowIdx > numel(state.files)
            return
        end
        fileInfo = state.files(rowIdx);
        choice = questdlg(sprintf('Remove file "%s" from project?', fileInfo.name), ...
            'Remove File', 'Remove', 'Cancel', 'Cancel');
        if ~strcmp(choice, 'Remove')
            return
        end
        autoBackupDatabase();
        unlinkFileFromProject(fileInfo.id, state.currentProjectId);
        loadFilesForProject(state.currentProjectId);
    end
    
    function openSelectedFile(varargin)
        if isempty(state.selectedRow)
            return
        end
        if ~isfield(state, 'files') || isempty(state.files)
            return
        end
        rowIdx = state.selectedRow;
        if rowIdx < 1 || rowIdx > numel(state.files)
            return
        end
        launchFile(state.files(rowIdx).path);
    end
    
    function openFileFolder(~, ~)
        if isempty(state.selectedRow)
            return
        end
        if ~isfield(state, 'files') || isempty(state.files)
            return
        end
        rowIdx = state.selectedRow;
        if rowIdx < 1 || rowIdx > numel(state.files)
            return
        end
        filePath = state.files(rowIdx).path;
        if exist(filePath, 'file')
            folder = fileparts(filePath);
            if exist(folder, 'dir')
                winopen(folder);
            else
                msgbox(sprintf('Folder not found: %s', folder), 'Error', 'error');
            end
        else
            msgbox(sprintf('File not found: %s', filePath), 'Error', 'error');
        end
    end
    
    function addModuleToQueue(~, ~)
        moduleName = get(moduleSelect, 'String');
        moduleIdx = get(moduleSelect, 'Value');
        moduleAction = moduleName{moduleIdx};
        
        state.moduleQueue{end + 1} = moduleAction;
        updateQueueTable();
    end
    
    function clearModuleQueue(~, ~)
        state.moduleQueue = {};
        updateQueueTable();
    end
    
    function updateQueueTable()
        if ~exist('moduleQueueTable', 'var') || ~ishandle(moduleQueueTable)
            return
        end
        
        queueData = cell(numel(state.moduleQueue), 2);
        for i = 1:numel(state.moduleQueue)
            queueData{i, 1} = i;
            queueData{i, 2} = state.moduleQueue{i};
        end
        moduleQueueTable.Data = queueData;
        
        if exist('launchQueueBtn', 'var') && ishandle(launchQueueBtn)
            if ~isempty(state.moduleQueue)
                set(launchQueueBtn, 'Enable', 'on');
            else
                set(launchQueueBtn, 'Enable', 'off');
            end
        end
    end
    
    function callModulesCallback(~, ~)
        if ~isfield(state, 'selectedRows') || isempty(state.selectedRows)
            return
        end
        if isempty(state.moduleQueue)
            return
        end
        
        tableData = fileTable.Data;
        if isempty(tableData)
            return
        end
        
        rows = state.selectedRows(:)';
        rows = rows(rows >= 1 & rows <= size(tableData, 1));
        
        if isempty(rows)
            return
        end
        
        selectedFileIds = cellfun(@(id) id, tableData(rows, 1));
        
        filesToProcess = [];
        for i = 1:numel(selectedFileIds)
            fileId = selectedFileIds(i);
            fileIdx = find([state.files.id] == fileId, 1);
            if ~isempty(fileIdx)
                filesToProcess = [filesToProcess; state.files(fileIdx)];
            end
        end
        
        if isempty(filesToProcess)
            return
        end
        
        totalModules = numel(state.moduleQueue);
        totalFiles = numel(filesToProcess);
        totalTasks = totalModules * totalFiles;
        
        progressBar = waitbar(0, 'Initializing modules...', 'Name', 'Processing Modules');
        
        completedTasks = 0;
        
        try
            % Внешний цикл: для каждого модуля в очереди
            for moduleIdx = 1:numel(state.moduleQueue)
                moduleAction = state.moduleQueue{moduleIdx};
                
                % Показываем GUI для редактирования параметров модуля один раз перед обработкой всех файлов
                paramsApplied = false;
                try
                    params = editModuleParamsGUI(moduleAction);
                    if ~isempty(fieldnames(params))
                        paramsApplied = true;
                    end
                catch ME
                    debugState('fileManagerGUI', 'Failed to open parameter editor: %s', ME.message);
                end
                
                if ~paramsApplied
                    completedTasks = completedTasks + totalFiles;
                    if ishandle(progressBar)
                        progress = completedTasks / totalTasks;
                        waitbar(progress, progressBar, sprintf('Module %d/%d: Skipped', moduleIdx, totalModules));
                    end
                    continue
                end
                
                % Внутренний цикл: обработка всех выбранных файлов
                for idx = 1:numel(filesToProcess)
                    file = filesToProcess(idx);
                    filePath = file.path;
                    fileId = file.id;
                    
                    if ishandle(progressBar)
                        progress = completedTasks / totalTasks;
                        waitbar(progress, progressBar, sprintf('Module %d/%d: %s (%d/%d files)', ...
                            moduleIdx, totalModules, moduleAction, idx, totalFiles));
                    end
                    
                    debugState('fileManagerGUI', 'Module %s %d/%d: %s', moduleAction, idx, numel(filesToProcess), filePath);
                    updateAnalysisHistory(fileId, moduleAction);
                    result = callModules(moduleAction, filePath, fileId, params);
                    if ~isempty(result) && isstruct(result) && numel(result) == 1
                        % Добавляем стандартные поля
                        result.file_id = fileId;
                        result.file_name = file.name;
                        result.module_name = moduleAction;
                        
                        % Извлечение и сохранение метаданных из результата
                        result = extractAndSaveMetadata(result, fileId);
                        
                        % Сохраняем .meta файл
                        result = saveMetaFileFromResult(result, filePath);
                        
                        logAnalysisResult(fileId, result);
                        updateAnalysisTable(fileId);
                    end
                    
                    completedTasks = completedTasks + 1;
                end
            end
            
            if ishandle(progressBar)
                waitbar(1.0, progressBar, 'Completed!');
                pause(0.5);
                close(progressBar);
            end
        catch ME
            if ishandle(progressBar)
                close(progressBar);
            end
            rethrow(ME);
        end
        
        % Очистка очереди после выполнения
        state.moduleQueue = {};
        updateQueueTable();
    end
    
    function result = callModules(action, filePath, fileId, params)
        result = [];
        if nargin < 2
            filePath = '';
        end
        if nargin < 3
            fileId = [];
        end
        if nargin < 4
            params = [];
        end
        
        if isempty(params)
            global timeUnitFactor
            if isempty(timeUnitFactor)
                timeUnitFactor = 1;
            end
            params = loadModuleParams(action, timeUnitFactor);
        end
        
        try
            macroFunc = str2func(action);
            result = macroFunc(filePath, fileId, params);
        catch ME
            debugState('fileManagerGUI', 'Module call failed: %s (%s)', action, ME.message);
        end
    end
    
    function result = saveMetaFileFromResult(result, filePath)
        if isempty(result) || ~isstruct(result)
            return
        end
        
        % Определяем путь к .meta файлу
        metaPath = '';
        
        if isfield(result, 'report_path') && ~isempty(result.report_path)
            % Если report_path существует, заменяем расширение на .meta
            [folder, baseName, ~] = fileparts(result.report_path);
            metaPath = fullfile(folder, [baseName, '.meta']);
        else
            % Если report_path отсутствует, создаем на основе исходного filePath
            [folder, baseName, ~] = fileparts(filePath);
            moduleName = '';
            if isfield(result, 'module_name') && ~isempty(result.module_name)
                moduleName = result.module_name;
            end
            if ~isempty(moduleName)
                metaPath = fullfile(folder, [baseName, '_', moduleName, '.meta']);
            else
                metaPath = fullfile(folder, [baseName, '.meta']);
            end
        end
        
        if isempty(metaPath)
            debugState('fileManagerGUI', 'saveMetaFileFromResult: failed to determine meta file path');
            return
        end
        
        try
            % Сохраняем все поля из result в .meta файл
            save(metaPath, '-struct', 'result', '-mat');
            
            % Обновляем data_path в result
            result.data_path = metaPath;
            
            debugState('fileManagerGUI', 'saveMetaFileFromResult: saved .meta file to %s', metaPath);
        catch ME
            debugState('fileManagerGUI', 'saveMetaFileFromResult: error saving .meta file: %s', ME.message);
            warning('Failed to save .meta file: %s', ME.message);
        end
    end
    
    function modules = listModulesInDir()
        modules = {};
        if ~exist(moduleDir, 'dir')
            return
        end
        moduleFiles = dir(fullfile(moduleDir, '*.m'));
        if isempty(moduleFiles)
            return
        end
        names = cell(1, numel(moduleFiles));
        for k = 1:numel(moduleFiles)
            [~, base] = fileparts(moduleFiles(k).name);
            names{k} = base;
        end
        modules = unique(names);
    end

    
    function updateAnalysisTable(fileId)
        if ~exist('analysisTable', 'var') || ~ishandle(analysisTable)
            return
        end
        if isempty(fileId)
            analysisTable.Data = {};
            analysisTable.UserData.row = 1;
            analysisTable.UserData.multi = 1;
            updateAnalysisTableCounter(0);
            return
        end
        filterByModule = true;
        if exist('filterByModuleCheckbox', 'var') && ishandle(filterByModuleCheckbox)
            filterByModule = get(filterByModuleCheckbox, 'Value');
        end
        if numel(fileId) > 1
            idsStr = sprintf('%d,', fileId);
            idsStr(end) = [];
            whereClause = sprintf('file_id IN (%s)', idsStr);
        else
            whereClause = sprintf('file_id = %d', fileId);
        end
        if filterByModule
            moduleName = [];
            if ishandle(moduleSelect)
                modules = get(moduleSelect, 'String');
                if ~isempty(modules)
                    if iscell(modules)
                        moduleIdx = min(get(moduleSelect, 'Value'), numel(modules));
                        moduleName = modules{moduleIdx};
                    else
                        moduleName = modules;
                    end
                end
            end
            if ~isempty(moduleName)
                query = sprintf(['SELECT file_id, report_path, module_name FROM analysis_results ' ...
                    'WHERE %s AND module_name = ''%s'' ORDER BY analysis_timestamp DESC'], ...
                    whereClause, escapeSql(moduleName));
            else
                query = sprintf(['SELECT file_id, report_path, module_name FROM analysis_results ' ...
                    'WHERE %s ORDER BY analysis_timestamp DESC'], whereClause);
            end
        else
            query = sprintf(['SELECT file_id, report_path, module_name FROM analysis_results ' ...
                'WHERE %s ORDER BY analysis_timestamp DESC'], whereClause);
        end
        rows = sqlFetch(query);
        if isempty(rows)
            analysisTable.Data = {};
            analysisTable.UserData.row = 1;
            analysisTable.UserData.multi = 1;
            updateAnalysisTableCounter(0);
        else
            analysisTable.Data = rows;
            analysisTable.UserData.row = min(analysisTable.UserData.row, size(rows, 1));
            analysisTable.UserData.multi = analysisTable.UserData.row;
            if isfield(analysisTable.UserData, 'multi') && ~isempty(analysisTable.UserData.multi) && numel(analysisTable.UserData.multi) > 0
                updateAnalysisTableCounter(numel(analysisTable.UserData.multi));
            else
                updateAnalysisTableCounter(0);
            end
        end
    end

    function openSelectedAnalysis(~, ~)
        if ~ishandle(analysisTable)
            return
        end
        data = analysisTable.Data;
        if isempty(data)
            return
        end
        selected = getSelectedAnalysisRows(size(data, 1));
        reportPath = data{selected(1), 2};
        openReportFile(reportPath);
    end
    
    function openAnalysisFolder(~, ~)
        if ~ishandle(analysisTable)
            return
        end
        data = analysisTable.Data;
        if isempty(data)
            return
        end
        selected = getSelectedAnalysisRows(size(data, 1));
        reportPath = data{selected(1), 2};
        openReportFolder(reportPath);
    end
    
    function deleteSelectedAnalysis(~, ~)
        if ~ishandle(analysisTable)
            return
        end
        data = analysisTable.Data;
        if isempty(data)
            return
        end
        selectedRows = getSelectedAnalysisRows(size(data, 1));
        if isempty(selectedRows)
            return
        end
        try
            reportPaths = cellfun(@(v) normalizePath(v), data(selectedRows, 2), 'UniformOutput', false);
            deleteAnalysisResults(reportPaths, @() updateAnalysisTableAfterDelete());
        catch ME
            msgbox(sprintf('Failed to delete result: %s', ME.message), 'Error', 'error');
        end
    end
    
    function updateAnalysisTableAfterDelete()
        if isfield(state, 'selectedFileIds') && ~isempty(state.selectedFileIds)
            updateAnalysisTable(state.selectedFileIds);
        else
            updateAnalysisTable([]);
        end
    end
    
    function rerunAnalysisCallback(~, ~)
        if ~ishandle(analysisTable)
            msgbox('Analysis table not available', 'Error', 'error');
            return
        end
        
        data = analysisTable.Data;
        if isempty(data)
            msgbox('No analysis results available', 'Info', 'help');
            return
        end
        
        % Получаем выбранные строки из таблицы анализа
        selectedRows = getSelectedAnalysisRows(size(data, 1));
        if isempty(selectedRows)
            msgbox('No analysis results selected', 'Info', 'help');
            return
        end
        
        % Формируем очередь задач для повторного анализа
        rerunQueue = {};
        for i = 1:numel(selectedRows)
            rowIdx = selectedRows(i);
            if rowIdx < 1 || rowIdx > size(data, 1)
                continue
            end
            
            fileId = data{rowIdx, 1};
            reportPath = data{rowIdx, 2};
            moduleName = data{rowIdx, 3};
            
            % Получаем путь к файлу из базы данных
            fileQuery = sprintf('SELECT file_path, file_name FROM files WHERE id = %d', fileId);
            fileRows = sqlFetch(fileQuery);
            if isempty(fileRows)
                warning('Re-run analysis: file not found for file_id=%d', fileId);
                continue
            end
            
            filePath = fileRows{1, 1};
            fileName = fileRows{1, 2};
            
            % Определяем путь к .meta файлу
            metaPath = replaceFileExt(reportPath, '.meta');
            
            if ~exist(metaPath, 'file')
                warning('Re-run analysis: .meta file not found: %s', metaPath);
                continue
            end
            
            % Добавляем задачу в очередь
            rerunQueue{end + 1} = struct(...
                'fileId', fileId, ...
                'filePath', filePath, ...
                'fileName', fileName, ...
                'moduleName', moduleName, ...
                'metaPath', metaPath, ...
                'reportPath', reportPath);
        end
        
        if isempty(rerunQueue)
            msgbox('No valid analysis results to re-run', 'Info', 'help');
            return
        end
        
        % Выполняем задачи из очереди последовательно
        successCount = 0;
        totalCount = numel(rerunQueue);
        
        for i = 1:totalCount
            task = rerunQueue{i};
            
            try
                % Загружаем переменную params из .meta файла
                try
                    metaData = load(task.metaPath, '-mat');
                catch ME
                    warning('Re-run analysis: skipping result %d/%d - failed to load .meta file: %s', ...
                        i, totalCount, ME.message);
                    continue
                end
                
                % Извлекаем parameters
                if ~isfield(metaData, 'parameters')
                    warning('Re-run analysis: skipping result %d/%d - no parameters in .meta file for file_id=%d, module=%s', ...
                        i, totalCount, task.fileId, task.moduleName);
                    continue
                end
                
                params = metaData.parameters;
                
                debugState('fileManagerGUI', 'Re-run analysis %d/%d: module=%s, file=%s', ...
                    i, totalCount, task.moduleName, task.filePath);
                
                result = callModules(task.moduleName, task.filePath, task.fileId, params);
                if ~isempty(result) && isstruct(result) && numel(result) == 1
                    result.file_id = task.fileId;
                    result.file_name = task.fileName;
                    result.module_name = task.moduleName;
                    
                    % Извлечение и сохранение метаданных из результата
                    result = extractAndSaveMetadata(result, task.fileId);
                    
                    result = saveMetaFileFromResult(result, task.filePath);
                    logAnalysisResult(task.fileId, result);
                    updateAnalysisTable(task.fileId);
                    successCount = successCount + 1;
                else
                    warning('Re-run analysis: module %s returned empty result for file_id=%d', task.moduleName, task.fileId);
                end
            catch ME
                warning('Re-run analysis: error processing result %d/%d: %s', i, totalCount, ME.message);
            end
        end
        
        fprintf('Re-run analysis completed: %d successful out of %d total\n', successCount, totalCount);
    end
    
    function metadataAnalysisCallback(~, ~)
        if ~ishandle(analysisTable)
            return
        end
        data = analysisTable.Data;
        if isempty(data)
            return
        end
        allRows = 1:size(data, 1);
        reportPaths = cellfun(@(v) normalizePath(v), data(allRows, 2), 'UniformOutput', false);
        fileIds = cellfun(@(v) v, data(allRows, 1), 'UniformOutput', false);
        validIndices = ~cellfun(@isempty, reportPaths);
        validPaths = reportPaths(validIndices);
        validFileIds = fileIds(validIndices);
        if isempty(validPaths)
            return
        end
        metaPaths = cellfun(@(p) replaceFileExt(p, '.meta'), validPaths, 'UniformOutput', false);
        fileIdArray = cellfun(@(id) id, validFileIds);
        
        % Extract file table data for selected files
        fileTableData = [];
        fileTableColumns = {};
        if ~ishandle(fileTable) || isempty(fileTable.Data)
            metadataAnalysis(metaPaths, fileIdArray);
            return
        end
        
        % Find rows in fileTable matching fileIds
        fileTableFileIds = fileTable.Data(:, 1);
        matchingRows = [];
        for i = 1:numel(fileIdArray)
            fileId = fileIdArray(i);
            for j = 1:numel(fileTableFileIds)
                if isequal(fileTableFileIds{j}, fileId)
                    matchingRows(end+1) = j;
                    break
                end
            end
        end
        
        if ~isempty(matchingRows)
            fileTableData = fileTable.Data(matchingRows, :);
            fileTableColumns = fileTable.ColumnName;
        end
        
        metadataAnalysis(metaPaths, fileIdArray, fileTableData, fileTableColumns);
    end
    
    function handleTableModificationSelection(src, ~)
        selectionIdx = src.Value;
        if selectionIdx == 1
            src.Value = 1;
            return
        end
        src.Value = 1;
        
        userData = get(src, 'UserData');
        moduleConfig = userData{selectionIdx - 1};
        
        selectedRows = state.selectedRows;
        if isempty(selectedRows)
            selectedRows = 1:numel(state.files);
        end
        
        selectedFiles = state.files(selectedRows);
        wb = waitbar(0, 'Preparing files...', 'Name', moduleConfig.displayName);
        
        waitbar(0.05, wb, 'Building table...');
        dataTable = buildFileTableForModule(selectedFiles);
        
        waitbar(0.1, wb, 'Running module...');
        moduleFunc = str2func(moduleConfig.moduleName);
        dataTable = moduleFunc(dataTable);
        
        waitbar(0.2, wb, 'Processing results...');
        metadataColumns = extractMetadataColumns(dataTable);
        
        fileIds = [selectedFiles.id]';
        
        waitbar(0.3, wb, sprintf('Saving %d field(s)...', numel(metadataColumns)));
        saveModuleResults(dataTable, metadataColumns, fileIds, wb);
        
        waitbar(0.9, wb, 'Updating state...');
        updateStateFromModuleResults(dataTable, metadataColumns, fileIds);
        
        waitbar(0.95, wb, 'Updating table...');
        updateTable(state.files);
        
        waitbar(1.0, wb, 'Completed!');
        close(wb);
    end
    
    function dataTable = buildFileTableForModule(selectedFiles)
        numFiles = numel(selectedFiles);
        fileTableData = cell(numFiles, 3);
        for i = 1:numFiles
            fileTableData{i, 1} = selectedFiles(i).id;
            fileTableData{i, 2} = selectedFiles(i).name;
            fileTableData{i, 3} = selectedFiles(i).path;
        end
        fileTableColumns = {'File ID', 'File Name', 'Path'};
        
        for i = 1:numel(state.metadataFields)
            originalFieldName = state.metadataFields{i};
            safeFieldName = makeSafeFieldName(originalFieldName);
            fileTableColumns{end+1} = originalFieldName;
            
            values = cell(numFiles, 1);
            for j = 1:numFiles
                fileId = selectedFiles(j).id;
                fileIdStr = sprintf('f%d', fileId);
                if isfield(state.metadataData, fileIdStr) && isfield(state.metadataData.(fileIdStr), safeFieldName)
                    values{j} = state.metadataData.(fileIdStr).(safeFieldName);
                else
                    values{j} = '';
                end
            end
            fileTableData = [fileTableData, values];
        end
        
        dataTable = cell2table(fileTableData, 'VariableNames', fileTableColumns);
    end
    
    function metadataColumns = extractMetadataColumns(dataTable)
        systemColumns = {'File ID', 'File Name', 'Path', 'Analysis History'};
        allColumns = dataTable.Properties.VariableNames;
        metadataColumns = setdiff(allColumns, systemColumns);
    end
    
    function saveModuleResults(dataTable, metadataColumns, fileIds, wb)
        totalFiles = numel(fileIds);
        numFields = numel(metadataColumns);
        
        for colIdx = 1:numFields
            fieldName = metadataColumns{colIdx};
            progress = 0.3 + 0.5 * (colIdx / numFields);
            waitbar(progress, wb, sprintf('Saving %s (%d/%d)...', fieldName, colIdx, numFields));
            
            registerMetadataField(fieldName);
            
            columnData = dataTable.(fieldName);
            fieldValues = cell(totalFiles, 1);
            for i = 1:totalFiles
                fieldValues{i} = columnData(i);
            end
            
            saveFileMetadataBatch(fileIds, fieldName, fieldValues);
        end
    end
    
    function registerMetadataField(fieldName)
        if ~any(strcmp(state.metadataFields, fieldName))
            state.metadataFields{end+1} = fieldName;
            safeFieldName = makeSafeFieldName(fieldName);
            if ~isfield(state.fieldNameMap, safeFieldName)
                state.fieldNameMap.(safeFieldName) = fieldName;
            end
        end
    end
    
    function updateStateFromModuleResults(dataTable, metadataColumns, fileIds)
        for colIdx = 1:numel(metadataColumns)
            fieldName = metadataColumns{colIdx};
            safeFieldName = makeSafeFieldName(fieldName);
            columnData = dataTable.(fieldName);
            
            for i = 1:numel(fileIds)
                fileId = fileIds(i);
                fieldValue = columnData(i);
                fieldValueStr = convertFieldValueToString(fieldValue);
                
                fileIdStr = sprintf('f%d', fileId);
                if ~isfield(state.metadataData, fileIdStr)
                    state.metadataData.(fileIdStr) = struct();
                end
                state.metadataData.(fileIdStr).(safeFieldName) = fieldValueStr;
            end
        end
    end
    
    function fieldValueStr = convertFieldValueToString(fieldValue)
        if isempty(fieldValue)
            fieldValueStr = '';
        elseif iscell(fieldValue)
            if isempty(fieldValue{1})
                fieldValueStr = '';
            elseif isnumeric(fieldValue{1})
                fieldValueStr = num2str(fieldValue{1});
            else
                fieldValueStr = char(fieldValue{1});
            end
        elseif isnumeric(fieldValue)
            fieldValueStr = num2str(fieldValue);
        elseif islogical(fieldValue)
            if fieldValue
                fieldValueStr = 'true';
            else
                fieldValueStr = 'false';
            end
        else
            fieldValueStr = char(fieldValue);
        end
    end
    
    function value = getNestedField(struct, path)
        if isempty(path) || ~ischar(path) && ~isstring(path)
            value = '';
            return
        end
        
        path = char(path);
        parts = strsplit(path, '.');
        
        current = struct;
        for i = 1:numel(parts)
            part = parts{i};
            if isstruct(current) && isfield(current, part)
                current = current.(part);
            else
                value = '';
                return
            end
        end
        
        value = current;
    end
    
    function metadata = extractFieldsFromResult(result, fieldPaths)
        metadata = struct();
        
        if isempty(fieldPaths)
            return
        end
        
        if ischar(fieldPaths) || isstring(fieldPaths)
            fieldPaths = {char(fieldPaths)};
        elseif ~iscell(fieldPaths)
            return
        end
        
        for i = 1:numel(fieldPaths)
            fieldPath = fieldPaths{i};
            if isempty(fieldPath) || (~ischar(fieldPath) && ~isstring(fieldPath))
                continue
            end
            
            fieldPath = char(fieldPath);
            value = getNestedField(result, fieldPath);
            
            if isempty(value) && ~isnumeric(value) && ~islogical(value)
                continue
            end
            
            parts = strsplit(fieldPath, '.');
            metadataFieldName = parts{end};
            
            if isnumeric(value) && numel(value) > 1
                for j = 1:numel(value)
                    fieldName = sprintf('%s_%d', metadataFieldName, j);
                    metadata.(fieldName) = value(j);
                end
            elseif iscell(value) && numel(value) > 1
                for j = 1:numel(value)
                    fieldName = sprintf('%s_%d', metadataFieldName, j);
                    metadata.(fieldName) = value{j};
                end
            else
                metadata.(metadataFieldName) = value;
            end
        end
    end
    
    function result = extractAndSaveMetadata(result, fileId)
        if isempty(result) || ~isstruct(result) || numel(result) ~= 1
            return
        end
        
        if ~isfield(result, 'tableResultInsert') || isempty(result.tableResultInsert)
            return
        end
        
        extractedMetadata = extractFieldsFromResult(result, result.tableResultInsert);
        if ~isempty(fieldnames(extractedMetadata))
            saveExtractedMetadata(fileId, extractedMetadata);
            updateTable(state.files);
        end
        
        result = rmfield(result, 'tableResultInsert');
    end
    
    function saveExtractedMetadata(fileId, metadata)
        if isempty(metadata) || isempty(fieldnames(metadata))
            return
        end
        
        fieldNames = fieldnames(metadata);
        numFields = numel(fieldNames);
        
        for i = 1:numFields
            fieldName = fieldNames{i};
            fieldValue = metadata.(fieldName);
            
            registerMetadataField(fieldName);
            
            fieldValueStr = convertFieldValueToString(fieldValue);
            fieldValues = {fieldValueStr};
            
            saveFileMetadataBatch(fileId, fieldName, fieldValues);
            
            safeFieldName = makeSafeFieldName(fieldName);
            fileIdStr = sprintf('f%d', fileId);
            if ~isfield(state.metadataData, fileIdStr)
                state.metadataData.(fileIdStr) = struct();
            end
            state.metadataData.(fileIdStr).(safeFieldName) = fieldValueStr;
        end
    end
    
    function openResultsGallery(~, ~)
        resultsGalleryGUI();
    end
    
    
    function moduleSelectionChanged(~, ~)
        moduleIdx = get(moduleSelect, 'Value');
        moduleList = get(moduleSelect, 'String');
        if iscell(moduleList) && moduleIdx >= 1 && moduleIdx <= numel(moduleList)
            state.selectedModule = moduleList{moduleIdx};
        end
        if isfield(state, 'selectedFileIds') && ~isempty(state.selectedFileIds)
            updateAnalysisTable(state.selectedFileIds);
        else
            updateAnalysisTable([]);
        end
    end
    
    function filterByModuleChanged(~, ~)
        if isfield(state, 'selectedFileIds') && ~isempty(state.selectedFileIds)
            updateAnalysisTable(state.selectedFileIds);
        else
            updateAnalysisTable([]);
        end
    end
    
    function handleAnalysisSelection(src, event)
        if isempty(event.Indices)
            src.UserData.row = 1;
            src.UserData.multi = 1;
            updateAnalysisTableCounter(0);
            return
        end
        rows = unique(event.Indices(:, 1));
        src.UserData.row = rows(1);
        src.UserData.multi = rows;
        updateAnalysisTableCounter(numel(rows));
    end
    
    function rows = getSelectedAnalysisRows(maxRows)
        rows = [];
        if ~ishandle(analysisTable)
            return
        end
        ud = analysisTable.UserData;
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
    
    function handleCellSelection(src, event)
        if isempty(event.Indices)
            clearSelection();
            src.UserData.row = [];
            src.UserData.col = [];
            src.UserData.vpos = [];
            src.UserData.hpos = [];
            updateFileTableCounter(0);
            debugState('fileManagerGUI', 'Selection cleared');
            return
        end
        rows = unique(event.Indices(:, 1));
        rowIdx = rows(1);
        colIdx = event.Indices(1, 2);
        state.selectedRow = rowIdx;
        state.selectedRows = rows(:)';
        
        tableData = fileTable.Data;
        if ~isempty(tableData) && max(rows) <= size(tableData, 1)
            state.selectedFileIds = cellfun(@(id) id, tableData(rows, 1));
        else
            state.selectedFileIds = [];
        end
        
        state.selectedColumn = colIdx;
        updateFileTableCounter(numel(state.selectedRows));
        
        if rowIdx >= 1 && rowIdx <= size(tableData, 1) && ~isempty(tableData)
            state.selectedFileId = tableData{rowIdx, 1};
            updateAnalysisTable(state.selectedFileIds);
        else
            state.selectedFileId = [];
            state.selectedFileIds = [];
            updateAnalysisTable([]);
        end
        src.UserData.row = rowIdx;
        src.UserData.col = colIdx;
        try
            jScroll = findjobj(src);
            if ~isempty(jScroll)
                src.UserData.vpos = jScroll.getVerticalScrollBar.getValue();
                src.UserData.hpos = jScroll.getHorizontalScrollBar.getValue();
                debugState('fileManagerGUI', 'Selection stored row=%d col=%d vpos=%d hpos=%d', rowIdx, colIdx, src.UserData.vpos, src.UserData.hpos);
            end
        catch
            debugState('fileManagerGUI', 'Selection store failed (row=%d col=%d)', rowIdx, colIdx);
        end
    end
    
    function storeTableState()
        if ~ishandle(fileTable)
            debugState('fileManagerGUI', 'storeTableState skipped: table handle invalid');
            return
        end
        if isempty(fileTable.UserData)
            fileTable.UserData = struct('row', [], 'col', [], 'vpos', [], 'hpos', []);
        end
        currentRow = state.selectedRow;
        if isempty(currentRow) && isfield(fileTable.UserData, 'row')
            currentRow = fileTable.UserData.row;
        end
        if ~isempty(currentRow)
            fileTable.UserData.row = currentRow;
        end
        currentCol = state.selectedColumn;
        if isempty(currentCol) && isfield(fileTable.UserData, 'col')
            currentCol = fileTable.UserData.col;
        end
        if ~isempty(currentCol)
            fileTable.UserData.col = currentCol;
        end
        try
            jScroll = findjobj(fileTable);
            if ~isempty(jScroll)
                fileTable.UserData.vpos = jScroll.getVerticalScrollBar.getValue();
                fileTable.UserData.hpos = jScroll.getHorizontalScrollBar.getValue();
                debugState('fileManagerGUI', 'Stored state row=%s col=%s vpos=%s hpos=%s', ...
                    mat2str(currentRow), mat2str(currentCol), mat2str(fileTable.UserData.vpos), mat2str(fileTable.UserData.hpos));
            end
        catch
            debugState('fileManagerGUI', 'storeTableState failed for row=%s col=%s', mat2str(currentRow), mat2str(currentCol));
        end
    end

    function restoreTableState()
        if ~ishandle(fileTable)
            debugState('fileManagerGUI', 'restoreTableState skipped: table handle invalid');
            return
        end
        userData = fileTable.UserData;
        rowCount = size(fileTable.Data, 1);
        colCount = size(fileTable.Data, 2);
        if rowCount == 0
            clearSelection();
            fileTable.UserData.row = [];
            fileTable.UserData.col = [];
            fileTable.UserData.vpos = [];
            fileTable.UserData.hpos = [];
            debugState('fileManagerGUI', 'restoreTableState: no rows');
            return
        end
        if isempty(userData) || ~isfield(userData, 'row') || isempty(userData.row)
            clearSelection();
            debugState('fileManagerGUI', 'restoreTableState: no stored row, rows=%d', rowCount);
        else
            state.selectedRow = min(max(1, userData.row), rowCount);
            targetCol = [];
            if isfield(userData, 'col') && ~isempty(userData.col)
                targetCol = min(max(1, userData.col), max(1, colCount));
            end
            state.selectedColumn = targetCol;
            if ~isempty(state.files) && state.selectedRow >= 1 && state.selectedRow <= numel(state.files)
                state.selectedFileId = state.files(state.selectedRow).id;
            else
                state.selectedFileId = [];
            end
            debugState('fileManagerGUI', 'restoreTableState: target row=%d col=%s rows=%d cols=%d', ...
                state.selectedRow, mat2str(state.selectedColumn), rowCount, colCount);
        end
        try
            jScroll = findjobj(fileTable);
            if ~isempty(jScroll)
                if isfield(userData, 'vpos') && ~isempty(userData.vpos)
                    jScroll.getVerticalScrollBar.setValue(userData.vpos);
                    debugState('fileManagerGUI', 'restoreTableState applied vpos=%d', userData.vpos);
                end
                if isfield(userData, 'hpos') && ~isempty(userData.hpos)
                    jScroll.getHorizontalScrollBar.setValue(userData.hpos);
                    debugState('fileManagerGUI', 'restoreTableState applied hpos=%d', userData.hpos);
                end
                if ~isempty(state.selectedRow)
                    jTable = jScroll.getViewport.getView();
                    colIdx = state.selectedColumn;
                    if isempty(colIdx)
                        colIdx = 1;
                    end
                    colIdx = min(max(1, colIdx), max(1, colCount));
                    jTable.changeSelection(state.selectedRow-1, colIdx-1, false, false);
                    fileTable.UserData.col = colIdx;
                    debugState('fileManagerGUI', 'restoreTableState applied selection row=%d col=%d', state.selectedRow, colIdx);
                end
            end
        catch
            debugState('fileManagerGUI', 'restoreTableState failed for row=%s col=%s', ...
                mat2str(state.selectedRow), mat2str(state.selectedColumn));
        end
    end

    function updateTable(files)
        storeTableState();
        if isempty(files)
            fileTable.Data = {};
            fileTable.ColumnName = {'File ID', 'File Name', 'Path'};
            fileTable.ColumnEditable = [false, false, false];
            fileTable.ColumnWidth = {60, 150, 400};
            clearSelection();
            fileTable.UserData.row = [];
            fileTable.UserData.col = [];
            fileTable.UserData.vpos = [];
            fileTable.UserData.hpos = [];
            return
        end
        
        ids = num2cell([files.id]');
        names = {files.name}';
        paths = {files.path}';
        
        columnNames = {'File ID', 'File Name', 'Path'};
        columnEditable = [false, false, false];
        columnWidths = {60, 120, 400};
        
        data = [ids, names, paths];
        
        for i = 1:numel(state.metadataFields)
            originalFieldName = state.metadataFields{i};
            safeFieldName = makeSafeFieldName(originalFieldName);
            columnNames{end+1} = originalFieldName;
            columnEditable(end+1) = true;
            columnWidths{end+1} = 120;
            
            values = cell(numel(files), 1);
            for j = 1:numel(files)
                fileId = files(j).id;
                fileIdStr = sprintf('f%d', fileId);
                if isfield(state.metadataData, fileIdStr) && isfield(state.metadataData.(fileIdStr), safeFieldName)
                    values{j} = state.metadataData.(fileIdStr).(safeFieldName);
                else
                    values{j} = '';
                end
            end
            data = [data, values];
        end
        
        fileTable.ColumnName = columnNames;
        fileTable.ColumnEditable = columnEditable;
        fileTable.ColumnWidth = columnWidths;
        fileTable.Data = data;
        restoreTableState();
        if ~isempty(state.selectedRows)
            updateFileTableCounter(numel(state.selectedRows));
        end
    end

    function clearSelection()
        state.selectedRow = [];
        state.selectedColumn = [];
        state.selectedFileId = [];
        state.selectedRows = [];
        state.selectedFileIds = [];
        updateFileTableCounter(0);
        if exist('analysisTable', 'var')
            updateAnalysisTable([]);
        end
    end
    
    function updateFileTableCounter(count)
        if exist('fileTableCounter', 'var') && ishandle(fileTableCounter)
            set(fileTableCounter, 'String', sprintf('Files selected: %d', count));
        end
        enableState = count > 0;
        
        % Проверяем расширение для кнопки Open (только если выбрана одна строка)
        openBtnEnabled = false;
        if count == 1 && isfield(state, 'selectedRow') && ~isempty(state.selectedRow) && isfield(state, 'files') && ~isempty(state.files)
            rowIdx = state.selectedRow;
            if rowIdx >= 1 && rowIdx <= numel(state.files)
                filePath = state.files(rowIdx).path;
                [~, ~, ext] = fileparts(filePath);
                supportedExtensions = {'.mat', '.ev'};
                openBtnEnabled = any(strcmpi(ext, supportedExtensions));
            end
        end
        
        if exist('openFileFolderBtn', 'var') && ishandle(openFileFolderBtn)
            set(openFileFolderBtn, 'Enable', onOff(enableState));
        end
        if exist('openBtn', 'var') && ishandle(openBtn)
            set(openBtn, 'Enable', onOff(openBtnEnabled));
        end
        if exist('deleteBtn', 'var') && ishandle(deleteBtn)
            set(deleteBtn, 'Enable', onOff(enableState));
        end
        if exist('rerunAnalysisBtn', 'var') && ishandle(rerunAnalysisBtn)
            set(rerunAnalysisBtn, 'Enable', onOff(enableState));
        end
    end
    
    function updateAnalysisTableCounter(count)
        if exist('analysisTableCounter', 'var') && ishandle(analysisTableCounter)
            set(analysisTableCounter, 'String', sprintf('Results selected: %d', count));
        end
        enableState = count > 0;
        if exist('openAnalysisFolderBtn', 'var') && ishandle(openAnalysisFolderBtn)
            set(openAnalysisFolderBtn, 'Enable', onOff(enableState));
        end
        if exist('openAnalysisBtn', 'var') && ishandle(openAnalysisBtn)
            set(openAnalysisBtn, 'Enable', onOff(enableState));
        end
        if exist('deleteAnalysisBtn', 'var') && ishandle(deleteAnalysisBtn)
            set(deleteAnalysisBtn, 'Enable', onOff(enableState));
        end
    end
    
    function state = onOff(enable)
        if enable
            state = 'on';
        else
            state = 'off';
        end
    end

    function rowIdx = resolveRowBySelectedId(files)
        rowIdx = [];
        if isempty(files)
            return
        end
        if ~isfield(state, 'selectedFileId') || isempty(state.selectedFileId)
            return
        end
        ids = [files.id];
        match = find(ids == state.selectedFileId, 1);
        if ~isempty(match)
            rowIdx = match;
        end
    end
    
    function exportProject(~, ~)
        if isempty(state.currentProjectId)
            msgbox('No project selected', 'Error', 'error');
            return
        end
        
        projectIdx = find([state.projects.id] == state.currentProjectId, 1);
        if isempty(projectIdx)
            msgbox('Project not found', 'Error', 'error');
            return
        end
        projectName = state.projects(projectIdx).name;
        safeProjectName = regexprep(projectName, '[<>:"/\\|?*]', '_');
        
        formatChoice = questdlg('Select export format:', 'Export Project', 'Database (.db)', 'Excel (.xlsx)', 'Flat Table (.mat)', 'Database (.db)');
        if isempty(formatChoice) || strcmp(formatChoice, 'Cancel')
            return
        end
        
        startDir = fileparts(state.dbPath);
        if isempty(startDir) || ~isfolder(startDir)
            startDir = fileparts(defaultDbPath());
        end
        
        if strcmp(formatChoice, 'Database (.db)')
            defaultFileName = [safeProjectName, '.db'];
            defaultPath = fullfile(startDir, defaultFileName);
            [file, path] = uiputfile('*.db', 'Export Project to Database', defaultPath);
            if isequal(file, 0)
                return
            end
            targetPath = fullfile(path, file);
            exportProjectToDatabase(state.currentProjectId, targetPath);
        elseif strcmp(formatChoice, 'Excel (.xlsx)')
            defaultFileName = [safeProjectName, '.xlsx'];
            defaultPath = fullfile(startDir, defaultFileName);
            [file, path] = uiputfile('*.xlsx', 'Export Project to Excel', defaultPath);
            if isequal(file, 0)
                return
            end
            excelPath = fullfile(path, file);
            exportProjectToExcel(state.currentProjectId, excelPath);
        else
            defaultFileName = [safeProjectName, '.mat'];
            defaultPath = fullfile(startDir, defaultFileName);
            [file, path] = uiputfile('*.mat', 'Export Project to Flat Table', defaultPath);
            if isequal(file, 0)
                return
            end
            matPath = fullfile(path, file);
            exportProjectToFlatTable(matPath);
        end
    end
    
    function exportProjectToDatabase(projectId, targetDbPath)
        debugState('fileManagerGUI', 'exportProjectToDatabase: starting export project_id=%d to %s', projectId, targetDbPath);
        wb = waitbar(0, 'Initializing export...', 'Name', 'Export Project');
        sourceDbPath = getDbPath();
        if isempty(sourceDbPath) || ~isfile(sourceDbPath)
            close(wb);
            debugState('fileManagerGUI', 'exportProjectToDatabase: source database not found: %s', sourceDbPath);
            msgbox('Source database not found', 'Error', 'error');
            return
        end
        
        waitbar(0.1, wb, 'Connecting to databases...');
        sourceConn = openSqliteConnection(sourceDbPath);
        if isempty(sourceConn)
            close(wb);
            debugState('fileManagerGUI', 'exportProjectToDatabase: failed to connect to source database: %s', sourceDbPath);
            msgbox('Failed to connect to source database', 'Error', 'error');
            return
        end
        
        targetConn = openSqliteConnection(targetDbPath);
        if isempty(targetConn)
            closeJdbcResource(sourceConn);
            close(wb);
            debugState('fileManagerGUI', 'exportProjectToDatabase: failed to connect to target database: %s', targetDbPath);
            msgbox('Failed to connect to target database', 'Error', 'error');
            return
        end
        
        stmt = [];
        try
            waitbar(0.15, wb, 'Creating database schema...');
            stmt = targetConn.createStatement();
            
            stmt.executeUpdate(['CREATE TABLE IF NOT EXISTS projects (' ...
                'id INTEGER PRIMARY KEY, ' ...
                'name TEXT NOT NULL, ' ...
                'description TEXT, ' ...
                'created_at DATETIME DEFAULT CURRENT_TIMESTAMP, ' ...
                'updated_at DATETIME DEFAULT CURRENT_TIMESTAMP)']);
            
            stmt.executeUpdate(['CREATE TABLE IF NOT EXISTS groups (' ...
                'id INTEGER PRIMARY KEY, ' ...
                'project_id INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE, ' ...
                'name TEXT NOT NULL, ' ...
                'created_at DATETIME DEFAULT CURRENT_TIMESTAMP)']);
            
            stmt.executeUpdate(['CREATE TABLE IF NOT EXISTS group_metadata (' ...
                'id INTEGER PRIMARY KEY, ' ...
                'group_id INTEGER NOT NULL REFERENCES groups(id) ON DELETE CASCADE, ' ...
                'field_name TEXT NOT NULL, ' ...
                'field_value TEXT, ' ...
                'updated_at DATETIME DEFAULT CURRENT_TIMESTAMP, ' ...
                'UNIQUE(group_id, field_name))']);
            
            stmt.executeUpdate(['CREATE TABLE IF NOT EXISTS files (' ...
                'id INTEGER PRIMARY KEY, ' ...
                'file_path TEXT NOT NULL, ' ...
                'file_name TEXT NOT NULL, ' ...
                'created_at DATETIME DEFAULT CURRENT_TIMESTAMP, ' ...
                'UNIQUE(file_path, file_name))']);
            
            stmt.executeUpdate(['CREATE TABLE IF NOT EXISTS project_files (' ...
                'project_id INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE, ' ...
                'file_id INTEGER NOT NULL REFERENCES files(id) ON DELETE CASCADE, ' ...
                'group_id INTEGER REFERENCES groups(id) ON DELETE SET NULL, ' ...
                'created_at DATETIME DEFAULT CURRENT_TIMESTAMP, ' ...
                'PRIMARY KEY (project_id, file_id))']);
            
            stmt.executeUpdate(['CREATE TABLE IF NOT EXISTS file_metadata (' ...
                'id INTEGER PRIMARY KEY, ' ...
                'file_id INTEGER REFERENCES files(id) ON DELETE SET NULL, ' ...
                'field_name TEXT NOT NULL, ' ...
                'field_value TEXT, ' ...
                'updated_at DATETIME DEFAULT CURRENT_TIMESTAMP, ' ...
                'UNIQUE(file_id, field_name))']);
            
            stmt.executeUpdate(['CREATE TABLE IF NOT EXISTS analysis_results (' ...
                'id INTEGER PRIMARY KEY, ' ...
                'file_id INTEGER REFERENCES files(id) ON DELETE SET NULL, ' ...
                'module_name TEXT NOT NULL, ' ...
                'module_display_name TEXT, ' ...
                'module_description TEXT, ' ...
                'analysis_timestamp BIGINT NOT NULL, ' ...
                'report_path TEXT NOT NULL, ' ...
                'parameters_json TEXT, ' ...
                'created_at DATETIME DEFAULT CURRENT_TIMESTAMP)']);
            
            stmt.executeUpdate(['CREATE TABLE IF NOT EXISTS analysis_scripts (' ...
                'id INTEGER PRIMARY KEY, ' ...
                'name TEXT NOT NULL, ' ...
                'script_path TEXT NOT NULL, ' ...
                'description TEXT, ' ...
                'UNIQUE(script_path))']);
            
            stmt.executeUpdate(['CREATE TABLE IF NOT EXISTS result_scripts (' ...
                'result_id INTEGER NOT NULL REFERENCES analysis_results(id) ON DELETE CASCADE, ' ...
                'script_id INTEGER NOT NULL REFERENCES analysis_scripts(id) ON DELETE CASCADE, ' ...
                'PRIMARY KEY (result_id, script_id))']);
            
            closeJdbcResource(stmt);
            
            waitbar(0.3, wb, 'Fetching project data...');
            debugState('fileManagerGUI', 'exportProjectToDatabase: fetching project data');
            projectRows = sqlFetchWithConn(sourceConn, sprintf('SELECT id, name, description, created_at, updated_at FROM projects WHERE id = %d', projectId));
            if isempty(projectRows)
                closeJdbcResource(sourceConn);
                closeJdbcResource(targetConn);
                debugState('fileManagerGUI', 'exportProjectToDatabase: project not found: id=%d', projectId);
                msgbox('Project not found', 'Error', 'error');
                return
            end
            
            escapedName = escapeSql(projectRows{1, 2});
            escapedDesc = escapeSql(projectRows{1, 3});
            escapedCreated = escapeSql(projectRows{1, 4});
            escapedUpdated = escapeSql(projectRows{1, 5});
            
            waitbar(0.4, wb, 'Exporting project...');
            insertProject = sprintf(['INSERT OR REPLACE INTO projects (id, name, description, created_at, updated_at) ' ...
                'VALUES (%d, ''%s'', ''%s'', ''%s'', ''%s'')'], ...
                projectRows{1, 1}, escapedName, escapedDesc, escapedCreated, escapedUpdated);
            debugState('fileManagerGUI', 'exportProjectToDatabase: inserting project id=%d', projectRows{1, 1});
            sqlExecWithConn(targetConn, insertProject);
            
            waitbar(0.5, wb, 'Exporting groups...');
            debugState('fileManagerGUI', 'exportProjectToDatabase: fetching groups');
            groupsRows = sqlFetchWithConn(sourceConn, sprintf('SELECT id, project_id, name, created_at FROM groups WHERE project_id = %d', projectId));
            for i = 1:size(groupsRows, 1)
                waitbar(0.5 + 0.1 * (i / max(1, size(groupsRows, 1))), wb, sprintf('Exporting groups %d/%d...', i, size(groupsRows, 1)));
                escapedGroupName = escapeSql(groupsRows{i, 3});
                escapedGroupCreated = escapeSql(groupsRows{i, 4});
                insertGroup = sprintf(['INSERT OR REPLACE INTO groups (id, project_id, name, created_at) ' ...
                    'VALUES (%d, %d, ''%s'', ''%s'')'], ...
                    groupsRows{i, 1}, groupsRows{i, 2}, escapedGroupName, escapedGroupCreated);
                sqlExecWithConn(targetConn, insertGroup);
            end
            
            if ~isempty(groupsRows)
                groupIds = cellfun(@(idx) groupsRows{idx, 1}, num2cell(1:size(groupsRows, 1)));
                idsStr = sprintf('%d,', groupIds);
                idsStr = idsStr(1:end-1);
                groupMetaRows = sqlFetchWithConn(sourceConn, sprintf('SELECT id, group_id, field_name, field_value, updated_at FROM group_metadata WHERE group_id IN (%s)', idsStr));
                for i = 1:size(groupMetaRows, 1)
                    escapedFieldName = escapeSql(groupMetaRows{i, 3});
                    escapedFieldValue = escapeSql(groupMetaRows{i, 4});
                    if isempty(escapedFieldValue)
                        escapedFieldValue = '';
                    end
                    escapedUpdated = escapeSql(groupMetaRows{i, 5});
                    insertGroupMeta = sprintf(['INSERT OR REPLACE INTO group_metadata (id, group_id, field_name, field_value, updated_at) ' ...
                        'VALUES (%d, %d, ''%s'', ''%s'', ''%s'')'], ...
                        groupMetaRows{i, 1}, groupMetaRows{i, 2}, escapedFieldName, escapedFieldValue, escapedUpdated);
                    sqlExecWithConn(targetConn, insertGroupMeta);
                end
            end
            
            waitbar(0.65, wb, 'Exporting files...');
            debugState('fileManagerGUI', 'exportProjectToDatabase: fetching files');
            fileIdsRows = sqlFetchWithConn(sourceConn, sprintf('SELECT file_id FROM project_files WHERE project_id = %d', projectId));
            if ~isempty(fileIdsRows)
                fileIds = cellfun(@(idx) fileIdsRows{idx, 1}, num2cell(1:size(fileIdsRows, 1)));
                idsStr = sprintf('%d,', fileIds);
                idsStr = idsStr(1:end-1);
                debugState('fileManagerGUI', 'exportProjectToDatabase: found %d files', numel(fileIds));
                
                filesRows = sqlFetchWithConn(sourceConn, sprintf('SELECT id, file_path, file_name, created_at FROM files WHERE id IN (%s)', idsStr));
                for i = 1:size(filesRows, 1)
                    waitbar(0.65 + 0.1 * (i / max(1, size(filesRows, 1))), wb, sprintf('Exporting files %d/%d...', i, size(filesRows, 1)));
                    escapedPath = escapeSql(filesRows{i, 2});
                    escapedName = escapeSql(filesRows{i, 3});
                    escapedCreated = escapeSql(filesRows{i, 4});
                    insertFile = sprintf(['INSERT OR REPLACE INTO files (id, file_path, file_name, created_at) ' ...
                        'VALUES (%d, ''%s'', ''%s'', ''%s'')'], ...
                        filesRows{i, 1}, escapedPath, escapedName, escapedCreated);
                    sqlExecWithConn(targetConn, insertFile);
                end
                
                projectFilesRows = sqlFetchWithConn(sourceConn, sprintf('SELECT project_id, file_id, group_id, created_at FROM project_files WHERE project_id = %d', projectId));
                for i = 1:size(projectFilesRows, 1)
                    escapedCreated = escapeSql(projectFilesRows{i, 4});
                    groupIdVal = projectFilesRows{i, 3};
                    if isempty(groupIdVal)
                        insertPF = sprintf(['INSERT OR REPLACE INTO project_files (project_id, file_id, group_id, created_at) ' ...
                            'VALUES (%d, %d, NULL, ''%s'')'], ...
                            projectFilesRows{i, 1}, projectFilesRows{i, 2}, escapedCreated);
                    else
                        insertPF = sprintf(['INSERT OR REPLACE INTO project_files (project_id, file_id, group_id, created_at) ' ...
                            'VALUES (%d, %d, %d, ''%s'')'], ...
                            projectFilesRows{i, 1}, projectFilesRows{i, 2}, groupIdVal, escapedCreated);
                    end
                    sqlExecWithConn(targetConn, insertPF);
                end
                
                fileMetaRows = sqlFetchWithConn(sourceConn, sprintf('SELECT id, file_id, field_name, field_value, updated_at FROM file_metadata WHERE file_id IN (%s)', idsStr));
                for i = 1:size(fileMetaRows, 1)
                    escapedFieldName = escapeSql(fileMetaRows{i, 3});
                    escapedFieldValue = escapeSql(fileMetaRows{i, 4});
                    if isempty(escapedFieldValue)
                        escapedFieldValue = '';
                    end
                    escapedUpdated = escapeSql(fileMetaRows{i, 5});
                    insertFileMeta = sprintf(['INSERT OR REPLACE INTO file_metadata (id, file_id, field_name, field_value, updated_at) ' ...
                        'VALUES (%d, %d, ''%s'', ''%s'', ''%s'')'], ...
                        fileMetaRows{i, 1}, fileMetaRows{i, 2}, escapedFieldName, escapedFieldValue, escapedUpdated);
                    sqlExecWithConn(targetConn, insertFileMeta);
                end
                
                waitbar(0.8, wb, 'Exporting analysis results...');
                debugState('fileManagerGUI', 'exportProjectToDatabase: fetching analysis results');
                analysisRows = sqlFetchWithConn(sourceConn, sprintf('SELECT id, file_id, module_name, module_display_name, module_description, analysis_timestamp, report_path, parameters_json, created_at FROM analysis_results WHERE file_id IN (%s)', idsStr));
                debugState('fileManagerGUI', 'exportProjectToDatabase: found %d analysis results', size(analysisRows, 1));
                for i = 1:size(analysisRows, 1)
                    waitbar(0.8 + 0.15 * (i / max(1, size(analysisRows, 1))), wb, sprintf('Exporting results %d/%d...', i, size(analysisRows, 1)));
                    escapedModuleName = escapeSql(analysisRows{i, 3});
                    escapedModuleDisplay = escapeSql(analysisRows{i, 4});
                    if isempty(escapedModuleDisplay)
                        escapedModuleDisplay = '';
                    end
                    escapedModuleDesc = escapeSql(analysisRows{i, 5});
                    if isempty(escapedModuleDesc)
                        escapedModuleDesc = '';
                    end
                    escapedReportPath = escapeSql(analysisRows{i, 7});
                    escapedParams = escapeSql(analysisRows{i, 8});
                    if isempty(escapedParams)
                        escapedParams = '';
                    end
                    escapedCreated = escapeSql(analysisRows{i, 9});
                    insertAnalysis = sprintf(['INSERT OR REPLACE INTO analysis_results (id, file_id, module_name, module_display_name, module_description, analysis_timestamp, report_path, parameters_json, created_at) ' ...
                        'VALUES (%d, %d, ''%s'', ''%s'', ''%s'', %d, ''%s'', ''%s'', ''%s'')'], ...
                        analysisRows{i, 1}, analysisRows{i, 2}, escapedModuleName, escapedModuleDisplay, escapedModuleDesc, analysisRows{i, 6}, escapedReportPath, escapedParams, escapedCreated);
                    sqlExecWithConn(targetConn, insertAnalysis);
                end
            end
            
            waitbar(1.0, wb, 'Export completed!');
            closeJdbcResource(sourceConn);
            closeJdbcResource(targetConn);
            close(wb);
            debugState('fileManagerGUI', 'exportProjectToDatabase: export completed successfully');
            msgbox('Project exported successfully', 'Success', 'help');
        catch ME
            closeJdbcResource(stmt);
            closeJdbcResource(sourceConn);
            closeJdbcResource(targetConn);
            if exist('wb', 'var') && ishandle(wb)
                close(wb);
            end
            debugState('fileManagerGUI', 'exportProjectToDatabase: error - %s', ME.message);
            if ~isempty(ME.stack)
                for k = 1:numel(ME.stack)
                    debugState('fileManagerGUI', 'exportProjectToDatabase: stack %d: %s at line %d', k, ME.stack(k).file, ME.stack(k).line);
                end
            end
            msgbox(sprintf('Failed to export project: %s', ME.message), 'Error', 'error');
        end
    end
    
    function exportProjectToExcel(projectId, excelPath)
        wb = waitbar(0, 'Initializing export...', 'Name', 'Export Project to Excel');
        if ~exist('fileTable', 'var') || ~ishandle(fileTable)
            close(wb);
            msgbox('File table not available', 'Error', 'error');
            return
        end
        
        fileData = fileTable.Data;
        fileColumnNames = fileTable.ColumnName;
        
        if isempty(fileData)
            close(wb);
            msgbox('No files to export', 'Error', 'error');
            return
        end
        
        try
            waitbar(0.3, wb, 'Preparing file data...');
            if iscell(fileColumnNames)
                excelData = [fileColumnNames(:)'; fileData];
            else
                excelData = [fileColumnNames; fileData];
            end
            waitbar(0.5, wb, 'Writing Files sheet...');
            writecell(excelData, excelPath, 'Sheet', 'Files');
            
            if ~isempty(state.files)
                waitbar(0.7, wb, 'Fetching analysis results...');
                fileIds = [state.files.id];
                if ~isempty(fileIds)
                    idsStr = sprintf('%d,', fileIds);
                    idsStr = idsStr(1:end-1);
                    query = sprintf(['SELECT file_id, report_path, module_name FROM analysis_results ' ...
                        'WHERE file_id IN (%s) ORDER BY analysis_timestamp DESC'], idsStr);
                    resultsRows = sqlFetch(query);
                    
                    if ~isempty(resultsRows)
                        waitbar(0.9, wb, 'Writing Results sheet...');
                        resultsHeaders = {'File ID', 'Report Path', 'Module'};
                        resultsData = [resultsHeaders(:)'; resultsRows];
                        writecell(resultsData, excelPath, 'Sheet', 'Results');
                    end
                end
            end
            
            waitbar(1.0, wb, 'Export completed!');
            close(wb);
            msgbox('Project exported successfully', 'Success', 'help');
        catch ME
            if exist('wb', 'var') && ishandle(wb)
                close(wb);
            end
            msgbox(sprintf('Failed to export project: %s', ME.message), 'Error', 'error');
        end
    end
    
    function result = showFieldSelectionDialogForExport(allFields)
        result = struct('fields', {}, 'displayNames', {}, 'formats', containers.Map());
        
        fig = figure('Position', [300, 300, 600, 400], ...
            'Name', 'Select Fields for Export', ...
            'NumberTitle', 'off', ...
            'MenuBar', 'none', ...
            'Resize', 'on');
        
        numFields = numel(allFields);
        formatColumn = cell(numFields, 1);
        for i = 1:numFields
            formatColumn{i} = 'Text';
        end
        
        data = [allFields', num2cell(true(numFields, 1)), formatColumn];
        
        columnEditable = [true, true, true];
        columnFormat = {'char', 'logical', {'Text', 'Number', 'Logical', 'Date', 'DateTime'}};
        
        fieldTable = uitable('Parent', fig, ...
            'Position', [10, 50, 580, 310], ...
            'Data', data, ...
            'ColumnName', {'Field Name', 'Select', 'Format'}, ...
            'ColumnEditable', columnEditable, ...
            'ColumnWidth', {300, 80, 150}, ...
            'ColumnFormat', columnFormat);
        
        selectAllBtn = uicontrol('Parent', fig, ...
            'Style', 'pushbutton', ...
            'Position', [10, 10, 120, 30], ...
            'String', 'Select All', ...
            'Callback', @(src,evt) selectAllFieldsCallback(fieldTable, allFields, true));
        
        deselectAllBtn = uicontrol('Parent', fig, ...
            'Style', 'pushbutton', ...
            'Position', [140, 10, 120, 30], ...
            'String', 'Deselect All', ...
            'Callback', @(src,evt) selectAllFieldsCallback(fieldTable, allFields, false));
        
        okBtn = uicontrol('Parent', fig, ...
            'Style', 'pushbutton', ...
            'Position', [450, 10, 70, 30], ...
            'String', 'OK', ...
            'Callback', @(src,evt) uiresume(fig));
        
        cancelBtn = uicontrol('Parent', fig, ...
            'Style', 'pushbutton', ...
            'Position', [530, 10, 60, 30], ...
            'String', 'Cancel', ...
            'Callback', @(src,evt) close(fig));
        
        uiwait(fig);
        
        if ishandle(fig)
            data = fieldTable.Data;
            selectedIndices = cellfun(@(x) islogical(x) && x, data(:, 2));
            selectedFields = allFields(selectedIndices);
            
            displayNames = {};
            selectedCount = 0;
            for i = 1:numFields
                if selectedIndices(i)
                    selectedCount = selectedCount + 1;
                    displayName = data{i, 1};
                    if isempty(displayName) || ~ischar(displayName) || strcmp(strtrim(displayName), allFields{i})
                        displayNames{selectedCount} = allFields{i};
                    else
                        displayNames{selectedCount} = strtrim(displayName);
                    end
                end
            end
            
            formats = containers.Map();
            for i = 1:numFields
                if selectedIndices(i)
                    formatValue = data{i, 3};
                    if ischar(formatValue)
                        formatLower = lower(formatValue);
                        if strcmp(formatLower, 'number')
                            formats(allFields{i}) = 'number';
                        elseif strcmp(formatLower, 'logical')
                            formats(allFields{i}) = 'logical';
                        elseif strcmp(formatLower, 'date')
                            formats(allFields{i}) = 'date';
                        elseif strcmp(formatLower, 'datetime')
                            formats(allFields{i}) = 'datetime';
                        else
                            formats(allFields{i}) = 'text';
                        end
                    else
                        formats(allFields{i}) = 'text';
                    end
                end
            end
            
            result = struct('fields', {selectedFields}, 'displayNames', {displayNames}, 'formats', formats);
            close(fig);
        end
    end
    
    function selectAllFieldsCallback(table, allFields, select)
        data = table.Data;
        for i = 1:numel(allFields)
            data{i, 2} = select;
        end
        table.Data = data;
    end
    
    function convertedValue = convertFieldValueByFormat(value, formatType)
        if isempty(formatType) || strcmp(formatType, 'text')
            convertedValue = value;
            return
        end
        
        if strcmp(formatType, 'number')
            if ischar(value) || isstring(value)
                if isempty(value)
                    convertedValue = NaN;
                else
                    numValue = str2double(value);
                    if ~isnan(numValue)
                        convertedValue = numValue;
                    else
                        convertedValue = value;
                    end
                end
            elseif isnumeric(value)
                convertedValue = value;
            else
                convertedValue = value;
            end
        elseif strcmp(formatType, 'logical')
            if ischar(value) || isstring(value)
                if isempty(value)
                    convertedValue = false;
                else
                    valueLower = lower(strtrim(char(value)));
                    if strcmp(valueLower, 'true') || strcmp(valueLower, '1') || strcmp(valueLower, 'yes') || strcmp(valueLower, 'on')
                        convertedValue = true;
                    elseif strcmp(valueLower, 'false') || strcmp(valueLower, '0') || strcmp(valueLower, 'no') || strcmp(valueLower, 'off')
                        convertedValue = false;
                    else
                        numValue = str2double(value);
                        if ~isnan(numValue)
                            convertedValue = logical(numValue ~= 0);
                        else
                            convertedValue = false;
                        end
                    end
                end
            elseif isnumeric(value)
                convertedValue = logical(value ~= 0);
            elseif islogical(value)
                convertedValue = value;
            else
                convertedValue = value;
            end
        elseif strcmp(formatType, 'date') || strcmp(formatType, 'datetime')
            if ischar(value) || isstring(value)
                if isempty(value)
                    convertedValue = NaN;
                else
                    try
                        dateValue = datenum(value);
                        if ~isnan(dateValue)
                            convertedValue = dateValue;
                        else
                            convertedValue = value;
                        end
                    catch
                        convertedValue = value;
                    end
                end
            elseif isnumeric(value)
                convertedValue = value;
            else
                convertedValue = value;
            end
        else
            convertedValue = value;
        end
    end
    
    function exportProjectToFlatTable(matPath)
        wb = waitbar(0, 'Initializing export...', 'Name', 'Export Project to Flat Table');
        
        if isempty(state.files)
            close(wb);
            msgbox('No files to export', 'Error', 'error');
            return
        end
        
        try
            waitbar(0.1, wb, 'Building table...');
            fullTable = buildFileTableForModule(state.files);
            
            if isempty(fullTable)
                close(wb);
                msgbox('Failed to create table', 'Error', 'error');
                return
            end
            
            close(wb);
            
            allFields = fullTable.Properties.VariableNames;
            selectionResult = showFieldSelectionDialogForExport(allFields);
            
            if isempty(selectionResult) || isempty(selectionResult.fields)
                return
            end
            
            wb = waitbar(0, 'Processing export...', 'Name', 'Export Project to Flat Table');
            
            selectedFields = selectionResult.fields;
            displayNames = selectionResult.displayNames;
            formats = selectionResult.formats;
            
            waitbar(0.2, wb, 'Converting field formats...');
            
            numRows = height(fullTable);
            numSelectedFields = numel(selectedFields);
            columnData = cell(1, numSelectedFields);
            
            for fieldIdx = 1:numSelectedFields
                fieldName = selectedFields{fieldIdx};
                formatType = 'text';
                if formats.isKey(fieldName)
                    formatType = formats(fieldName);
                end
                
                originalColumn = fullTable.(fieldName);
                convertedColumn = cell(numRows, 1);
                
                for rowIdx = 1:numRows
                    if iscell(originalColumn)
                        value = originalColumn{rowIdx};
                    else
                        value = originalColumn(rowIdx);
                    end
                    convertedColumn{rowIdx} = convertFieldValueByFormat(value, formatType);
                end
                
                columnData{fieldIdx} = convertedColumn;
            end
            
            waitbar(0.6, wb, 'Creating final table...');
            
            if numel(displayNames) == numSelectedFields
                columnNames = displayNames;
            else
                columnNames = selectedFields;
            end
            
            flatTable = table(columnData{:}, 'VariableNames', columnNames);
            
            waitbar(0.8, wb, 'Saving MAT file...');
            save(matPath, 'flatTable', '-v7.3');
            
            waitbar(0.9, wb, 'Saving Excel file...');
            [excelPath, excelName, ~] = fileparts(matPath);
            excelPath = fullfile(excelPath, [excelName, '.xlsx']);
            try
                writetable(flatTable, excelPath);
            catch ME
                debugState('fileManagerGUI', 'exportProjectToFlatTable: Failed to save Excel file: %s', ME.message);
            end
            
            waitbar(1.0, wb, 'Export completed!');
            close(wb);
            msgbox('Project exported successfully', 'Success', 'help');
        catch ME
            if exist('wb', 'var') && ishandle(wb)
                close(wb);
            end
            debugState('fileManagerGUI', 'exportProjectToFlatTable: error - %s', ME.message);
            msgbox(sprintf('Failed to export project: %s', ME.message), 'Error', 'error');
        end
    end
    
    function importProject(~, ~)
        formatChoice = questdlg('Select import format:', 'Import Project', 'Database (.db)', 'Excel (.xlsx)', 'Cancel', 'Database (.db)');
        if isempty(formatChoice) || strcmp(formatChoice, 'Cancel')
            return
        end
        
        startDir = fileparts(state.dbPath);
        if isempty(startDir) || ~isfolder(startDir)
            startDir = fileparts(defaultDbPath());
        end
        
        if strcmp(formatChoice, 'Database (.db)')
            [file, path] = uigetfile('*.db', 'Import Project from Database', startDir);
            if isequal(file, 0)
                return
            end
            sourcePath = fullfile(path, file);
            importProjectFromDatabase(sourcePath);
        else
            [file, path] = uigetfile('*.xlsx', 'Import Project from Excel', startDir);
            if isequal(file, 0)
                return
            end
            excelPath = fullfile(path, file);
            importProjectFromExcel(excelPath);
        end
    end
    
    function importProjectFromDatabase(sourceDbPath)
        debugState('fileManagerGUI', 'importProjectFromDatabase: starting import from %s', sourceDbPath);
        wb = waitbar(0, 'Initializing import...', 'Name', 'Import Project from Database');
        
        if isempty(state.dbPath) || ~isfile(state.dbPath)
            close(wb);
            msgbox('Current database not found', 'Error', 'error');
            return
        end
        
        waitbar(0.1, wb, 'Connecting to source database...');
        sourceConn = openSqliteConnection(sourceDbPath);
        if isempty(sourceConn)
            close(wb);
            debugState('fileManagerGUI', 'importProjectFromDatabase: failed to connect to source database');
            msgbox('Failed to connect to source database', 'Error', 'error');
            return
        end
        
        try
            waitbar(0.2, wb, 'Fetching projects...');
            projectsRows = sqlFetchWithConn(sourceConn, 'SELECT id, name FROM projects ORDER BY created_at DESC');
            if isempty(projectsRows)
                closeJdbcResource(sourceConn);
                close(wb);
                msgbox('No projects found in source database', 'Error', 'error');
                return
            end
            
            if size(projectsRows, 1) > 1
                close(wb);
                projectNames = cell(size(projectsRows, 1), 1);
                for i = 1:size(projectsRows, 1)
                    projectNames{i} = sprintf('%s (#%d)', projectsRows{i, 2}, projectsRows{i, 1});
                end
                [selection, ok] = listdlg('ListString', projectNames, ...
                    'SelectionMode', 'single', ...
                    'PromptString', 'Select project to import:', ...
                    'Name', 'Import Project', ...
                    'ListSize', [300, 200]);
                if ~ok || isempty(selection)
                    closeJdbcResource(sourceConn);
                    return
                end
                sourceProjectId = projectsRows{selection, 1};
                sourceProjectName = projectsRows{selection, 2};
                wb = waitbar(0, 'Starting import...', 'Name', 'Import Project from Database');
            else
                sourceProjectId = projectsRows{1, 1};
                sourceProjectName = projectsRows{1, 2};
            end
            
            debugState('fileManagerGUI', 'importProjectFromDatabase: importing project id=%d, name=%s', sourceProjectId, sourceProjectName);
            
            waitbar(0.3, wb, 'Connecting to target database...');
            targetConn = openSqliteConnection(state.dbPath);
            if isempty(targetConn)
                closeJdbcResource(sourceConn);
                close(wb);
                debugState('fileManagerGUI', 'importProjectFromDatabase: failed to connect to target database');
                msgbox('Failed to connect to current database', 'Error', 'error');
                return
            end
            
            waitbar(0.4, wb, 'Creating project...');
            projectName = sourceProjectName;
            existingProjects = sqlFetchWithConn(targetConn, sprintf('SELECT name FROM projects WHERE name = ''%s''', escapeSql(projectName)));
            if ~isempty(existingProjects)
                projectName = [sourceProjectName, '_imported'];
            end
            
            newProjectId = insertProjectWithConn(targetConn, projectName);
            if isempty(newProjectId)
                closeJdbcResource(sourceConn);
                closeJdbcResource(targetConn);
                close(wb);
                msgbox('Failed to create project', 'Error', 'error');
                return
            end
            
            debugState('fileManagerGUI', 'importProjectFromDatabase: created new project id=%d, name=%s', newProjectId, projectName);
            
            waitbar(0.5, wb, 'Importing groups...');
            groupsRows = sqlFetchWithConn(sourceConn, sprintf('SELECT id, project_id, name, created_at FROM groups WHERE project_id = %d', sourceProjectId));
            groupIdMap = containers.Map('KeyType', 'double', 'ValueType', 'double');
            
            for i = 1:size(groupsRows, 1)
                waitbar(0.5 + 0.1 * (i / max(1, size(groupsRows, 1))), wb, sprintf('Importing groups %d/%d...', i, size(groupsRows, 1)));
                oldGroupId = groupsRows{i, 1};
                escapedGroupName = escapeSql(groupsRows{i, 3});
                escapedGroupCreated = escapeSql(groupsRows{i, 4});
                insertGroup = sprintf(['INSERT INTO groups (project_id, name, created_at) ' ...
                    'VALUES (%d, ''%s'', ''%s'')'], ...
                    newProjectId, escapedGroupName, escapedGroupCreated);
                sqlExecWithConn(targetConn, insertGroup);
                newGroupId = sqlFetchWithConn(targetConn, sprintf('SELECT id FROM groups WHERE project_id = %d AND name = ''%s'' ORDER BY created_at DESC LIMIT 1', newProjectId, escapedGroupName));
                if ~isempty(newGroupId)
                    groupIdMap(oldGroupId) = newGroupId{1, 1};
                end
            end
            
            if ~isempty(groupsRows)
                oldGroupIds = cellfun(@(idx) groupsRows{idx, 1}, num2cell(1:size(groupsRows, 1)));
                idsStr = sprintf('%d,', oldGroupIds);
                idsStr = idsStr(1:end-1);
                groupMetaRows = sqlFetchWithConn(sourceConn, sprintf('SELECT id, group_id, field_name, field_value, updated_at FROM group_metadata WHERE group_id IN (%s)', idsStr));
                for i = 1:size(groupMetaRows, 1)
                    oldGroupId = groupMetaRows{i, 2};
                    if isKey(groupIdMap, oldGroupId)
                        newGroupId = groupIdMap(oldGroupId);
                        escapedFieldName = escapeSql(groupMetaRows{i, 3});
                        escapedFieldValue = escapeSql(groupMetaRows{i, 4});
                        if isempty(escapedFieldValue)
                            escapedFieldValue = '';
                        end
                        escapedUpdated = escapeSql(groupMetaRows{i, 5});
                        insertGroupMeta = sprintf(['INSERT OR REPLACE INTO group_metadata (group_id, field_name, field_value, updated_at) ' ...
                            'VALUES (%d, ''%s'', ''%s'', ''%s'')'], ...
                            newGroupId, escapedFieldName, escapedFieldValue, escapedUpdated);
                        sqlExecWithConn(targetConn, insertGroupMeta);
                    end
                end
            end
            
            waitbar(0.65, wb, 'Importing files...');
            fileIdsRows = sqlFetchWithConn(sourceConn, sprintf('SELECT file_id FROM project_files WHERE project_id = %d', sourceProjectId));
            if ~isempty(fileIdsRows)
                fileIds = cellfun(@(idx) fileIdsRows{idx, 1}, num2cell(1:size(fileIdsRows, 1)));
                idsStr = sprintf('%d,', fileIds);
                idsStr = idsStr(1:end-1);
                
                filesRows = sqlFetchWithConn(sourceConn, sprintf('SELECT id, file_path, file_name, created_at FROM files WHERE id IN (%s)', idsStr));
                fileIdMap = containers.Map('KeyType', 'double', 'ValueType', 'double');
                
                for i = 1:size(filesRows, 1)
                    waitbar(0.65 + 0.15 * (i / max(1, size(filesRows, 1))), wb, sprintf('Importing files %d/%d...', i, size(filesRows, 1)));
                    oldFileId = filesRows{i, 1};
                    escapedPath = escapeSql(filesRows{i, 2});
                    escapedName = escapeSql(filesRows{i, 3});
                    escapedCreated = escapeSql(filesRows{i, 4});
                    
                    existingFile = sqlFetchWithConn(targetConn, sprintf('SELECT id FROM files WHERE file_path = ''%s'' LIMIT 1', escapedPath));
                    if ~isempty(existingFile)
                        newFileId = existingFile{1, 1};
                    else
                        insertFile = sprintf(['INSERT INTO files (file_path, file_name, created_at) ' ...
                            'VALUES (''%s'', ''%s'', ''%s'')'], ...
                            escapedPath, escapedName, escapedCreated);
                        sqlExecWithConn(targetConn, insertFile);
                        newFileIdRow = sqlFetchWithConn(targetConn, sprintf('SELECT id FROM files WHERE file_path = ''%s'' LIMIT 1', escapedPath));
                        if ~isempty(newFileIdRow)
                            newFileId = newFileIdRow{1, 1};
                        else
                            continue
                        end
                    end
                    fileIdMap(oldFileId) = newFileId;
                end
                
                projectFilesRows = sqlFetchWithConn(sourceConn, sprintf('SELECT project_id, file_id, group_id, created_at FROM project_files WHERE project_id = %d', sourceProjectId));
                for i = 1:size(projectFilesRows, 1)
                    oldFileId = projectFilesRows{i, 2};
                    if isKey(fileIdMap, oldFileId)
                        newFileId = fileIdMap(oldFileId);
                        oldGroupId = projectFilesRows{i, 3};
                        escapedCreated = escapeSql(projectFilesRows{i, 4});
                        
                        if ~isempty(oldGroupId) && isKey(groupIdMap, oldGroupId)
                            newGroupId = groupIdMap(oldGroupId);
                            insertPF = sprintf(['INSERT OR IGNORE INTO project_files (project_id, file_id, group_id, created_at) ' ...
                                'VALUES (%d, %d, %d, ''%s'')'], ...
                                newProjectId, newFileId, newGroupId, escapedCreated);
                        else
                            insertPF = sprintf(['INSERT OR IGNORE INTO project_files (project_id, file_id, group_id, created_at) ' ...
                                'VALUES (%d, %d, NULL, ''%s'')'], ...
                                newProjectId, newFileId, escapedCreated);
                        end
                        sqlExecWithConn(targetConn, insertPF);
                    end
                end
                
                fileMetaRows = sqlFetchWithConn(sourceConn, sprintf('SELECT id, file_id, field_name, field_value, updated_at FROM file_metadata WHERE file_id IN (%s)', idsStr));
                for i = 1:size(fileMetaRows, 1)
                    oldFileId = fileMetaRows{i, 2};
                    if isKey(fileIdMap, oldFileId)
                        newFileId = fileIdMap(oldFileId);
                        escapedFieldName = escapeSql(fileMetaRows{i, 3});
                        escapedFieldValue = escapeSql(fileMetaRows{i, 4});
                        if isempty(escapedFieldValue)
                            escapedFieldValue = '';
                        end
                        escapedUpdated = escapeSql(fileMetaRows{i, 5});
                        insertFileMeta = sprintf(['INSERT OR REPLACE INTO file_metadata (file_id, field_name, field_value, updated_at) ' ...
                            'VALUES (%d, ''%s'', ''%s'', ''%s'')'], ...
                            newFileId, escapedFieldName, escapedFieldValue, escapedUpdated);
                        sqlExecWithConn(targetConn, insertFileMeta);
                    end
                end
                
                waitbar(0.85, wb, 'Importing analysis results...');
                analysisRows = sqlFetchWithConn(sourceConn, sprintf('SELECT id, file_id, module_name, module_display_name, module_description, analysis_timestamp, report_path, parameters_json, created_at FROM analysis_results WHERE file_id IN (%s)', idsStr));
                for i = 1:size(analysisRows, 1)
                    waitbar(0.85 + 0.1 * (i / max(1, size(analysisRows, 1))), wb, sprintf('Importing results %d/%d...', i, size(analysisRows, 1)));
                    oldFileId = analysisRows{i, 2};
                    if isKey(fileIdMap, oldFileId)
                        newFileId = fileIdMap(oldFileId);
                        escapedModuleName = escapeSql(analysisRows{i, 3});
                        escapedModuleDisplay = escapeSql(analysisRows{i, 4});
                        if isempty(escapedModuleDisplay)
                            escapedModuleDisplay = '';
                        end
                        escapedModuleDesc = escapeSql(analysisRows{i, 5});
                        if isempty(escapedModuleDesc)
                            escapedModuleDesc = '';
                        end
                        reportPath = analysisRows{i, 7};
                        if isAnalysisResultExistsByPath(targetConn, reportPath)
                            continue
                        end
                        escapedReportPath = escapeSql(reportPath);
                        escapedParams = escapeSql(analysisRows{i, 8});
                        if isempty(escapedParams)
                            escapedParams = '';
                        end
                        escapedCreated = escapeSql(analysisRows{i, 9});
                        insertAnalysis = sprintf(['INSERT INTO analysis_results (file_id, module_name, module_display_name, module_description, analysis_timestamp, report_path, parameters_json, created_at) ' ...
                            'VALUES (%d, ''%s'', ''%s'', ''%s'', %d, ''%s'', ''%s'', ''%s'')'], ...
                            newFileId, escapedModuleName, escapedModuleDisplay, escapedModuleDesc, analysisRows{i, 6}, escapedReportPath, escapedParams, escapedCreated);
                        sqlExecWithConn(targetConn, insertAnalysis);
                    end
                end
            end
            
            waitbar(1.0, wb, 'Import completed!');
            closeJdbcResource(sourceConn);
            closeJdbcResource(targetConn);
            close(wb);
            
            debugState('fileManagerGUI', 'importProjectFromDatabase: import completed successfully');
            loadProjectsFromDb();
            match = find([state.projects.id] == newProjectId, 1);
            if ~isempty(match)
                projectSelect.Value = match;
                selectProjectByIndex(match);
            end
            msgbox('Project imported successfully', 'Success', 'help');
        catch ME
            closeJdbcResource(sourceConn);
            if exist('wb', 'var') && ishandle(wb)
                close(wb);
            end
            debugState('fileManagerGUI', 'importProjectFromDatabase: error - %s', ME.message);
            if ~isempty(ME.stack)
                for k = 1:numel(ME.stack)
                    debugState('fileManagerGUI', 'importProjectFromDatabase: stack %d: %s at line %d', k, ME.stack(k).file, ME.stack(k).line);
                end
            end
            msgbox(sprintf('Failed to import project: %s', ME.message), 'Error', 'error');
        end
    end
    
    function importProjectFromExcel(excelPath)
        debugState('fileManagerGUI', 'importProjectFromExcel: starting import from %s', excelPath);
        wb = waitbar(0, 'Initializing import...', 'Name', 'Import Project from Excel');
        
        if isempty(state.dbPath) || ~isfile(state.dbPath)
            close(wb);
            msgbox('Current database not found', 'Error', 'error');
            return
        end
        
        try
            waitbar(0.1, wb, 'Reading Excel file...');
            filesData = readcell(excelPath, 'Sheet', 'Files');
            if isempty(filesData) || size(filesData, 1) < 2
                close(wb);
                msgbox('No data found in Files sheet', 'Error', 'error');
                return
            end
            
            waitbar(0.2, wb, 'Processing file data...');
            headers = filesData(1, :);
            data = filesData(2:end, :);
            
            pathColIdx = find(strcmp(headers, 'Path'), 1);
            nameColIdx = find(strcmp(headers, 'File Name'), 1);
            
            if isempty(pathColIdx) || isempty(nameColIdx)
                close(wb);
                msgbox('Required columns not found: Path, File Name', 'Error', 'error');
                return
            end
            
            waitbar(0.3, wb, 'Creating project...');
            [~, excelFileName, ~] = fileparts(excelPath);
            projectName = excelFileName;
            existingProjects = sqlFetch(sprintf('SELECT name FROM projects WHERE name = ''%s''', escapeSql(projectName)));
            if ~isempty(existingProjects)
                projectName = [excelFileName, '_imported'];
            end
            
            newProjectId = insertProject(projectName);
            if isempty(newProjectId)
                close(wb);
                msgbox('Failed to create project', 'Error', 'error');
                return
            end
            
            debugState('fileManagerGUI', 'importProjectFromExcel: created new project id=%d, name=%s', newProjectId, projectName);
            
            waitbar(0.4, wb, 'Importing files...');
            fileIdMap = containers.Map('KeyType', 'double', 'ValueType', 'double');
            importedCount = 0;
            skippedCount = 0;
            
            for i = 1:size(data, 1)
                waitbar(0.4 + 0.4 * (i / max(1, size(data, 1))), wb, sprintf('Importing file %d/%d...', i, size(data, 1)));
                filePath = data{i, pathColIdx};
                if isempty(filePath) || ~ischar(filePath) && ~isstring(filePath)
                    continue
                end
                filePath = char(filePath);
                
                if ~exist(filePath, 'file')
                    debugState('fileManagerGUI', 'importProjectFromExcel: file not found, skipping: %s', filePath);
                    skippedCount = skippedCount + 1;
                    continue
                end
                
                ensureFileInProject(filePath, newProjectId);
                record = sqlFetch(sprintf('SELECT id FROM files WHERE file_path = ''%s'' LIMIT 1', escapeSql(filePath)));
                if ~isempty(record)
                    newFileId = record{1};
                    oldFileId = data{i, 1};
                    if ~isempty(oldFileId) && isnumeric(oldFileId)
                        fileIdMap(oldFileId) = newFileId;
                    end
                    
                    for j = 1:numel(headers)
                        if j == pathColIdx || j == nameColIdx || strcmp(headers{j}, 'File ID')
                            continue
                        end
                        fieldName = headers{j};
                        fieldValue = data{i, j};
                        if isempty(fieldValue)
                            fieldValue = '';
                        elseif isnumeric(fieldValue)
                            fieldValue = num2str(fieldValue);
                        elseif islogical(fieldValue)
                            if fieldValue
                                fieldValue = 'true';
                            else
                                fieldValue = 'false';
                            end
                        elseif isdatetime(fieldValue)
                            fieldValue = datestr(fieldValue);
                        elseif isduration(fieldValue)
                            fieldValue = char(fieldValue);
                        end
                        if ischar(fieldValue) || isstring(fieldValue)
                            saveFileMetadata(newFileId, fieldName, char(fieldValue));
                        end
                    end
                    importedCount = importedCount + 1;
                end
            end
            
            try
                waitbar(0.85, wb, 'Importing analysis results...');
                resultsData = readcell(excelPath, 'Sheet', 'Results');
                if ~isempty(resultsData) && size(resultsData, 1) > 1
                    resultsHeaders = resultsData(1, :);
                    resultsRows = resultsData(2:end, :);
                    
                    fileIdColIdx = find(strcmp(resultsHeaders, 'File ID'), 1);
                    reportPathColIdx = find(strcmp(resultsHeaders, 'Report Path'), 1);
                    moduleColIdx = find(strcmp(resultsHeaders, 'Module'), 1);
                    
                    if ~isempty(fileIdColIdx) && ~isempty(reportPathColIdx) && ~isempty(moduleColIdx)
                        for i = 1:size(resultsRows, 1)
                            waitbar(0.85 + 0.1 * (i / max(1, size(resultsRows, 1))), wb, sprintf('Importing results %d/%d...', i, size(resultsRows, 1)));
                            oldFileId = resultsRows{i, fileIdColIdx};
                            if isempty(oldFileId) || ~isnumeric(oldFileId)
                                continue
                            end
                            if isKey(fileIdMap, oldFileId)
                                newFileId = fileIdMap(oldFileId);
                                reportPath = resultsRows{i, reportPathColIdx};
                                moduleName = resultsRows{i, moduleColIdx};
                                if isempty(reportPath) || isempty(moduleName)
                                    continue
                                end
                                
                                escapedModuleName = escapeSql(char(moduleName));
                                if isAnalysisResultExistsByPath([], reportPath)
                                    continue
                                end
                                escapedReportPath = escapeSql(char(reportPath));
                                timestamp = round(now * 86400000);
                                insertAnalysis = sprintf(['INSERT INTO analysis_results (file_id, module_name, report_path, analysis_timestamp, created_at) ' ...
                                    'VALUES (%d, ''%s'', ''%s'', %d, CURRENT_TIMESTAMP)'], ...
                                    newFileId, escapedModuleName, escapedReportPath, timestamp);
                                sqlExec(insertAnalysis);
                            end
                        end
                    end
                end
            catch
                debugState('fileManagerGUI', 'importProjectFromExcel: failed to read Results sheet, skipping');
            end
            
            waitbar(1.0, wb, 'Import completed!');
            debugState('fileManagerGUI', 'importProjectFromExcel: imported %d files, skipped %d files', importedCount, skippedCount);
            close(wb);
            loadProjectsFromDb();
            match = find([state.projects.id] == newProjectId, 1);
            if ~isempty(match)
                projectSelect.Value = match;
                selectProjectByIndex(match);
            end
            msgbox(sprintf('Project imported successfully. Imported: %d files, Skipped: %d files', importedCount, skippedCount), 'Success', 'help');
        catch ME
            if exist('wb', 'var') && ishandle(wb)
                close(wb);
            end
            debugState('fileManagerGUI', 'importProjectFromExcel: error - %s', ME.message);
            if ~isempty(ME.stack)
                for k = 1:numel(ME.stack)
                    debugState('fileManagerGUI', 'importProjectFromExcel: stack %d: %s at line %d', k, ME.stack(k).file, ME.stack(k).line);
                end
            end
            msgbox(sprintf('Failed to import project: %s', ME.message), 'Error', 'error');
        end
    end
    
    function showFileFilterDialog()
        dialogWidth = 500;
        dialogHeight = 200;
        screenSize = get(0, 'ScreenSize');
        dialogX = (screenSize(3) - dialogWidth) / 2;
        dialogY = (screenSize(4) - dialogHeight) / 2;
        
        dialogFig = figure('Position', [dialogX, dialogY, dialogWidth, dialogHeight], ...
            'Name', 'Filter Files', ...
            'NumberTitle', 'off', ...
            'MenuBar', 'none', ...
            'Resize', 'off', ...
            'WindowStyle', 'modal');
        
        margin = 15;
        buttonHeight = 30;
        buttonWidth = 80;
        labelHeight = 20;
        editHeight = 25;
        spacing = 10;
        
        yPos = dialogHeight - margin - labelHeight;
        
        uicontrol('Parent', dialogFig, 'Style', 'text', ...
            'Position', [margin, yPos, 100, labelHeight], ...
            'String', 'Column:', ...
            'HorizontalAlignment', 'left', ...
            'FontSize', 11);
        
        columnList = {'File ID', 'File Name', 'Path'};
        if ~isempty(state.metadataFields)
            columnList = [columnList, state.metadataFields];
        end
        
        currentColumnIdx = 1;
        if ~isempty(currentFilter.columnName)
            matchIdx = find(strcmp(columnList, currentFilter.columnName), 1);
            if ~isempty(matchIdx)
                currentColumnIdx = matchIdx;
            end
        end
        
        columnPopup = uicontrol('Parent', dialogFig, 'Style', 'popupmenu', ...
            'Position', [margin + 110, yPos - 2, dialogWidth - 2*margin - 110, editHeight], ...
            'String', columnList, ...
            'Value', currentColumnIdx, ...
            'FontSize', 11);
        
        yPos = yPos - labelHeight - spacing - editHeight;
        
        uicontrol('Parent', dialogFig, 'Style', 'text', ...
            'Position', [margin, yPos, 100, labelHeight], ...
            'String', 'Search text:', ...
            'HorizontalAlignment', 'left', ...
            'FontSize', 11);
        
        searchEdit = uicontrol('Parent', dialogFig, 'Style', 'edit', ...
            'Position', [margin + 110, yPos - 2, dialogWidth - 2*margin - 110, editHeight], ...
            'String', currentFilter.searchText, ...
            'FontSize', 11, ...
            'HorizontalAlignment', 'left');
        
        yPos = margin;
        
        applyBtn = uicontrol('Parent', dialogFig, 'Style', 'pushbutton', ...
            'Position', [dialogWidth - 3*buttonWidth - 2*spacing - 2*margin, yPos, buttonWidth, buttonHeight], ...
            'String', 'Apply', ...
            'FontSize', 11, ...
            'Callback', @(src,evt) applyFilterCallback());
        
        clearBtn = uicontrol('Parent', dialogFig, 'Style', 'pushbutton', ...
            'Position', [dialogWidth - 2*buttonWidth - spacing - margin, yPos, buttonWidth, buttonHeight], ...
            'String', 'Clear', ...
            'FontSize', 11, ...
            'Callback', @(src,evt) clearFilterCallback());
        
        cancelBtn = uicontrol('Parent', dialogFig, 'Style', 'pushbutton', ...
            'Position', [dialogWidth - buttonWidth - margin, yPos, buttonWidth, buttonHeight], ...
            'String', 'Cancel', ...
            'FontSize', 11, ...
            'Callback', @(src,evt) close(dialogFig));
        
        uicontrol(searchEdit);
        
        function applyFilterCallback()
            columnIdx = get(columnPopup, 'Value');
            columnName = columnList{columnIdx};
            searchText = get(searchEdit, 'String');
            applyFileFilter(columnName, searchText);
            close(dialogFig);
        end
        
        function clearFilterCallback()
            clearFileFilter();
            close(dialogFig);
        end
        
        uiwait(dialogFig);
    end
    
    function applyFileFilter(columnName, searchText)
        if isempty(columnName) || isempty(searchText)
            currentFilter.columnName = '';
            currentFilter.searchText = '';
            updateTable(state.files);
            return
        end
        
        currentFilter.columnName = columnName;
        currentFilter.searchText = searchText;
        
        if isempty(state.files)
            updateTable([]);
            return
        end
        
        filteredFiles = [];
        
        for i = 1:numel(state.files)
            file = state.files(i);
            match = false;
            
            if strcmp(columnName, 'File ID')
                fileIdStr = num2str(file.id);
                if contains(fileIdStr, searchText, 'IgnoreCase', true)
                    match = true;
                end
            elseif strcmp(columnName, 'File Name')
                if contains(file.name, searchText, 'IgnoreCase', true)
                    match = true;
                end
            elseif strcmp(columnName, 'Path')
                if contains(file.path, searchText, 'IgnoreCase', true)
                    match = true;
                end
            else
                safeFieldName = makeSafeFieldName(columnName);
                fileIdStr = sprintf('f%d', file.id);
                if isfield(state.metadataData, fileIdStr) && isfield(state.metadataData.(fileIdStr), safeFieldName)
                    fieldValue = state.metadataData.(fileIdStr).(safeFieldName);
                    if ischar(fieldValue) || isstring(fieldValue)
                        if contains(char(fieldValue), searchText, 'IgnoreCase', true)
                            match = true;
                        end
                    else
                        fieldValueStr = num2str(fieldValue);
                        if contains(fieldValueStr, searchText, 'IgnoreCase', true)
                            match = true;
                        end
                    end
                end
            end
            
            if match
                filteredFiles = [filteredFiles; file];
            end
        end
        
        updateTable(filteredFiles);
    end
    
    function clearFileFilter()
        currentFilter.columnName = '';
        currentFilter.searchText = '';
        updateTable(state.files);
    end
end

function shortPath = truncatePath(fullPath)
    if isempty(fullPath)
        shortPath = '';
        return
    end
    maxLen = 45;
    if numel(fullPath) <= maxLen
        shortPath = fullPath;
        return
    end
    shortPath = ['...', fullPath(end-maxLen+4:end)];
end


function projects = fetchProjects()
    rows = sqlFetch('SELECT id, name FROM projects ORDER BY created_at DESC');
    if isempty(rows)
        projects = [];
        return
    end
    count = size(rows, 1);
    projects = repmat(struct('id', 0, 'name', ''), count, 1);
    for i = 1:count
        projects(i).id = rows{i, 1};
        projects(i).name = rows{i, 2};
    end
end

function projectId = insertProject(projectName)
    projectId = [];
    if isempty(projectName)
        return
    end
    escapedName = escapeSql(projectName);
    query = sprintf('INSERT INTO projects (name, created_at) VALUES (''%s'', CURRENT_TIMESTAMP)', escapedName);
    sqlExec(query);
    result = sqlFetch(sprintf('SELECT id FROM projects WHERE name = ''%s'' ORDER BY created_at DESC LIMIT 1', escapedName));
    if ~isempty(result)
        projectId = result{1};
    end
end

function projectId = insertProjectWithConn(conn, projectName)
    projectId = [];
    if isempty(projectName) || isempty(conn)
        return
    end
    escapedName = escapeSql(projectName);
    query = sprintf('INSERT INTO projects (name, created_at) VALUES (''%s'', CURRENT_TIMESTAMP)', escapedName);
    sqlExecWithConn(conn, query);
    result = sqlFetchWithConn(conn, sprintf('SELECT id FROM projects WHERE name = ''%s'' ORDER BY created_at DESC LIMIT 1', escapedName));
    if ~isempty(result)
        projectId = result{1, 1};
    end
end

function files = fetchProjectFilesWithConn(conn, projectId)
    query = sprintf(['SELECT f.id, f.file_name, f.file_path, pf.group_id ' ...
        'FROM project_files pf ' ...
        'JOIN files f ON f.id = pf.file_id ' ...
        'WHERE pf.project_id = %d ORDER BY f.created_at DESC'], projectId);
    rows = sqlFetchWithConn(conn, query);
    if isempty(rows)
        files = [];
        return
    end
    count = size(rows, 1);
    files = repmat(struct('id', 0, 'name', '', 'path', '', 'group_id', []), count, 1);
    for i = 1:count
        files(i).id = rows{i, 1};
        files(i).name = rows{i, 2};
        files(i).path = rows{i, 3};
        files(i).group_id = rows{i, 4};
    end
end

function ensureFileInProject(filePath, projectId)
    filePath = char(filePath);
    record = sqlFetch(sprintf('SELECT id FROM files WHERE file_path = ''%s'' LIMIT 1', escapeSql(filePath)));
    if isempty(record)
        [~, name, ext] = fileparts(filePath);
        fileName = [name, ext];
        insertFile = sprintf('INSERT INTO files (file_path, file_name, created_at) VALUES (''%s'', ''%s'', CURRENT_TIMESTAMP)', ...
            escapeSql(filePath), escapeSql(fileName));
        sqlExec(insertFile);
        record = sqlFetch(sprintf('SELECT id FROM files WHERE file_path = ''%s'' LIMIT 1', escapeSql(filePath)));
    end
    fileId = record{1};
    existsLink = sqlFetch(sprintf('SELECT 1 FROM project_files WHERE project_id = %d AND file_id = %d LIMIT 1', projectId, fileId));
    if ~isempty(existsLink)
        return
    end
    insertLink = sprintf('INSERT INTO project_files (project_id, file_id, created_at) VALUES (%d, %d, CURRENT_TIMESTAMP)', ...
        projectId, fileId);
    sqlExec(insertLink);
end

function unlinkFileFromProject(fileId, projectId)
    if isempty(fileId) || isempty(projectId)
        return
    end
    deleteLink = sprintf('DELETE FROM project_files WHERE project_id = %d AND file_id = %d', projectId, fileId);
    sqlExec(deleteLink);
    usageCount = sqlFetch(sprintf('SELECT COUNT(*) FROM project_files WHERE file_id = %d', fileId));
    if isempty(usageCount)
        return
    end
    countValue = usageCount{1};
    if countValue > 0
        return
    end
    sqlExec(sprintf('DELETE FROM files WHERE id = %d', fileId));
end

    function safeName = makeSafeFieldName(originalName)
        if isempty(originalName)
            safeName = 'field';
            return
        end
        
        safeName = originalName;
        safeName = regexprep(safeName, '[^a-zA-Z0-9_]', '_');
        
        if ~isempty(safeName) && ~isletter(safeName(1))
            safeName = ['f_', safeName];
        end
        
        if isempty(safeName)
            safeName = 'field';
        end
    end
    
    function originalName = getOriginalFieldName(safeFieldName, stateVar)
        if ~isfield(stateVar, 'fieldNameMap') || ~isfield(stateVar.fieldNameMap, safeFieldName)
            originalName = safeFieldName;
            return
        end
        originalName = stateVar.fieldNameMap.(safeFieldName);
    end

function saveFileMetadata(fileId, fieldName, fieldValue)
    if isempty(fileId) || isempty(fieldName)
        return
    end
    if isempty(fieldValue)
        fieldValue = '';
    end
    
    escapedFieldName = escapeSql(fieldName);
    escapedFieldValue = escapeSql(fieldValue);
    
    exists = sqlFetch(sprintf(['SELECT id FROM file_metadata ' ...
        'WHERE file_id = %d AND field_name = ''%s'' LIMIT 1'], fileId, escapedFieldName));
    
    if ~isempty(exists)
        query = sprintf(['UPDATE file_metadata SET field_value = ''%s'', updated_at = CURRENT_TIMESTAMP ' ...
            'WHERE file_id = %d AND field_name = ''%s'''], escapedFieldValue, fileId, escapedFieldName);
    else
        query = sprintf(['INSERT INTO file_metadata (file_id, field_name, field_value, updated_at) ' ...
            'VALUES (%d, ''%s'', ''%s'', CURRENT_TIMESTAMP)'], fileId, escapedFieldName, escapedFieldValue);
    end
    
    sqlExec(query);
end

function metadata = launchFile(filePath)
    metadata = [];
    if ~exist(filePath, 'file')
        debugState('fileManagerGUI', 'File not found: %s', filePath);
        return
    end
    [~, ~, ext] = fileparts(filePath);
    global event_calling
    global zav_calling wb table_calling events event_inx event_title_string
    global lastOpenedFiles SettingsFilepath
    
    if ~exist('lastOpenedFiles', 'var') || isempty(lastOpenedFiles)
        lastOpenedFiles = {};
    end
    
    lastOpenedFiles{end + 1} = filePath;
    
    try
        save(SettingsFilepath, 'lastOpenedFiles', '-append');
    catch ME
        warning('Failed to save last opened file path: %s', ME.message);
    end
    
    debugState('fileManagerGUI', 'Please wait...');
    global event_amplitudes event_channels event_widths event_prominences event_metadata event_comments events_exist
    events = [];
    event_amplitudes = [];
    event_channels = [];
    event_widths = [];
    event_prominences = [];
    event_metadata = [];
    event_comments = {};
    event_title_string = 'Events';
    event_inx = 1;
    events_exist = false;
    
    switch lower(ext)
        case '.ev'
            metadata = event_calling();
        case '.mat'
            metadata = zav_calling(filePath);
            table_calling();
        otherwise
            debugState('fileManagerGUI', 'Unknown extension: %s', ext);
    end
    debugState('fileManagerGUI', 'File loaded.');
    try
        close(wb);
    catch
    end
end


function autoBackupDatabase()
    dbPath = getDbPath();
    if isempty(dbPath) || ~isfile(dbPath)
        return
    end
    
    [dbFolder, dbName, dbExt] = fileparts(dbPath);
    if isempty(dbFolder)
        return
    end
    
    backupFolder = fullfile(dbFolder, 'backups');
    if ~isfolder(backupFolder)
        try
            mkdir(backupFolder);
        catch ME
            warning('Failed to create backup folder: %s', ME.message);
            return
        end
    end
    
    timestamp = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
    backupName = sprintf('%s_backup_%s%s', dbName, timestamp, dbExt);
    backupPath = fullfile(backupFolder, backupName);
    
    try
        copyfile(dbPath, backupPath, 'f');
        debugState('fileManagerGUI', 'Backup created: %s', backupName);
        
        backupPattern = fullfile(backupFolder, [dbName, '_backup_*', dbExt]);
        backupFiles = dir(backupPattern);
        if numel(backupFiles) > 3
            [~, sortIdx] = sort([backupFiles.datenum], 'descend');
            for i = 4:numel(backupFiles)
                oldBackupPath = fullfile(backupFolder, backupFiles(sortIdx(i)).name);
                try
                    delete(oldBackupPath);
                catch ME
                    warning('Failed to delete old backup: %s', ME.message);
                end
            end
        end
    catch ME
        warning('Failed to create database backup: %s', ME.message);
    end
end

function storeCurrentProjectId(projectId)
    global SettingsFilepath
    try
        if exist(SettingsFilepath, 'file')
            data = load(SettingsFilepath);
        else
            data = struct();
        end
        data.file_manager_project_id = projectId;
        save(SettingsFilepath, '-struct', 'data');
    catch ME
        warning('Failed to save selected project: %s', ME.message);
    end
end

function exists = isAnalysisResultExistsByPath(conn, reportPath)
    exists = false;
    if isempty(reportPath)
        return
    end
    reportPath = char(reportPath);
    escapedPath = escapeSql(reportPath);
    query = sprintf('SELECT 1 FROM analysis_results WHERE report_path = ''%s'' LIMIT 1', escapedPath);
    if isempty(conn)
        rows = sqlFetch(query);
    else
        rows = sqlFetchWithConn(conn, query);
    end
    exists = ~isempty(rows);
end
