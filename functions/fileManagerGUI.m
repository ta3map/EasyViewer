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
    
    state.dbPath = initDbPath();
    
    moduleDir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'modules');
    if exist(moduleDir, 'dir')
        currentPath = strsplit(path, pathsep); %#ok<PATHNM>
        if ~any(strcmp(currentPath, moduleDir))
            addpath(moduleDir);
        end
    end
    
    fig = figure('Position', [100, 100, 1275, 585], ...
        'Name', 'File Manager (SQL)', ...
        'NumberTitle', 'off', ...
        'MenuBar', 'none', ...
        'ToolBar', 'none', ...
        'Resize', 'off', ...
        'Tag', figTag);
    
    uicontrol('Style', 'text', ...
        'Position', [10, 550, 100, 30], ...
        'String', 'Database', ...
        'HorizontalAlignment', 'left', ...
        'FontSize', 12, ...
        'FontWeight', 'bold');
    
    dbPathDisplay = uicontrol('Style', 'edit', ...
        'Position', [65, 525, 300, 33], ...
        'String', truncatePath(state.dbPath), ...
        'Enable', 'inactive', ...
        'HorizontalAlignment', 'left');
    
    createDbBtn = uicontrol('Style', 'pushbutton', ...
        'Position', [375, 525, 120, 33], ...
        'String', 'Create New Database', ...
        'Callback', @createNewDatabase);
    
    dbBtn = uicontrol('Style', 'pushbutton', ...
        'Position', [505, 525, 120, 33], ...
        'String', 'Select Database', ...
        'Callback', @chooseDbPath);
    
    uicontrol('Style', 'text', ...
        'Position', [10, 488, 70, 30], ...
        'String', 'Project', ...
        'HorizontalAlignment', 'left', ...
        'FontSize', 12, ...
        'FontWeight', 'bold');
    
    projectSelect = uicontrol('Style', 'popupmenu', ...
        'Position', [75, 463, 220, 38], ...
        'String', {'Loading...'}, ...
        'Callback', @switchProject);
    
    newProjectBtn = uicontrol('Style', 'pushbutton', ...
        'Position', [305, 463, 100, 38], ...
        'String', 'Create New Project', ...
        'Callback', @createNewProject);

    addBtn = uicontrol('Style', 'pushbutton', ...
        'Position', [415, 463, 100, 38], ...
        'String', 'Add Files to Project', ...
        'Callback', @addFilesToProject);
    
    deleteFieldBtn = uicontrol('Style', 'pushbutton', ...
        'Position', [535, 463, 100, 38], ...
        'String', 'Delete Field', ...
        'Callback', @deleteMetadataField);
    
    addFieldBtn = uicontrol('Style', 'pushbutton', ...
        'Position', [645, 463, 100, 38], ...
        'String', 'Add Field', ...
        'Callback', @addMetadataField);
    
    deleteBtn = uicontrol('Style', 'pushbutton', ...
        'Position', [765, 321, 100, 38], ...
        'String', 'Remove Selected File', ...
        'Callback', @removeSelectedFile, ...
        'Enable', 'off');
    
    openFileFolderBtn = uicontrol('Style', 'pushbutton', ...
        'Position', [765, 283, 100, 38], ...
        'String', 'Open Folder', ...
        'Callback', @openFileFolder, ...
        'Enable', 'off');
    
    openBtn = uicontrol('Style', 'pushbutton', ...
        'Position', [765, 165, 100, 76], ...
        'String', 'Open Selected File', ...
        'Callback', @openSelectedFile, ...
        'Enable', 'off');
    
    moduleList = listModulesInDir();
    if isempty(moduleList)
        moduleList = {'autoMeanStimulus'};
    end
    filterByModuleCheckbox = uicontrol('Style', 'checkbox', ...
        'Position', [930, 398, 180, 30], ...
        'String', 'Filter by module', ...
        'Value', 0, ...
        'Callback', @filterByModuleChanged);
    
    uicontrol('Style', 'text', ...
        'Position', [930, 550, 180, 30], ...
        'String', 'Analysis', ...
        'HorizontalAlignment', 'left', ...
        'FontSize', 12, ...
        'FontWeight', 'bold');
    
    moduleSelect = uicontrol('Style', 'popupmenu', ...
        'Position', [930, 513, 180, 38], ...
        'String', moduleList, ...
        'Callback', @moduleSelectionChanged);
    
    if ~isempty(state.selectedModule)
        savedModuleIdx = find(strcmp(moduleList, state.selectedModule), 1);
        if ~isempty(savedModuleIdx)
            moduleSelect.Value = savedModuleIdx;
        end
    end
    
    runModuleBtn = uicontrol('Style', 'pushbutton', ...
        'Position', [1120, 513, 150, 38], ...
        'String', 'Launch Module', ...
        'Callback', @callModulesCallback);
    
    
    openAnalysisBtn = uicontrol('Style', 'pushbutton', ...
        'Position', [930, 353, 150, 38], ...
        'String', 'Open Result', ...
        'Callback', @openSelectedAnalysis, ...
        'Enable', 'off');
    
    openAnalysisFolderBtn = uicontrol('Style', 'pushbutton', ...
        'Position', [1090, 353, 150, 38], ...
        'String', 'Open Folder', ...
        'Callback', @openAnalysisFolder, ...
        'Enable', 'off');
    
    deleteAnalysisBtn = uicontrol('Style', 'pushbutton', ...
        'Position', [930, 308, 345, 38], ...
        'String', 'Delete Result', ...
        'Callback', @deleteSelectedAnalysis, ...
        'Enable', 'off');

    fileTable = uitable('Position', [10, 15, 751, 435], ...
        'ColumnWidth', {60, 120, 400}, ...
        'ColumnName', {'File ID', 'File Name', 'Path'}, ...
        'ColumnEditable', [false, false, false]);
    
    uicontrol('Style', 'text', ...
        'Position', [930, 430, 100, 25], ...
        'String', 'Results', ...
        'HorizontalAlignment', 'left', ...
        'FontSize', 12, ...
        'FontWeight', 'bold');
    
    analysisTable = uitable('Position', [930, 68, 345, 234], ...
        'ColumnWidth', {60, 110, 60}, ...
        'ColumnName', {'File ID', 'Report Path', 'Module'}, ...
        'ColumnEditable', [false, false, false], ...
        'Data', cell(0, 3));
    analysisTable.UserData = struct('row', 1, 'multi', 1);
    analysisTable.CellSelectionCallback = @handleAnalysisSelection;
    
    metaAnalysisBtn = uicontrol('Style', 'pushbutton', ...
        'Position', [930, 15, 345, 38], ...
        'String', 'Metadata Analysis', ...
        'Callback', @metadataAnalysisCallback);

    fileTable.UserData = struct('row', [], 'col', [], 'vpos', [], 'hpos', []);
    fileTable.CellSelectionCallback = @handleCellSelection;
    fileTable.CellEditCallback = @handleCellEdit;
    
    fileTableCounter = uicontrol('Style', 'text', ...
        'Position', [10, 445, 200, 20], ...
        'String', 'Selected: 0', ...
        'HorizontalAlignment', 'left');
    
    analysisTableCounter = uicontrol('Style', 'text', ...
        'Position', [930, 282, 200, 20], ...
        'String', 'Selected: 0', ...
        'HorizontalAlignment', 'left');
    
    loadProjectsFromDb();
    
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
        dlgTitle = 'Create New Project';
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
            return
        end
        originalFieldName = strtrim(answer{1});
        if isempty(originalFieldName)
            msgbox('Field name cannot be empty', 'Error', 'error');
            return
        end
        
        if any(strcmp(state.metadataFields, originalFieldName))
            msgbox('Field already exists', 'Error', 'error');
            return
        end
        
        safeFieldName = makeSafeFieldName(originalFieldName);
        
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
        
        updateTable(state.files);
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
        
        if colIdx <= 2
            return
        end
        
        metadataColIdx = colIdx - 2;
        if metadataColIdx > numel(state.metadataFields)
            return
        end
        
        fileId = state.files(rowIdx).id;
        originalFieldName = state.metadataFields{metadataColIdx};
        safeFieldName = makeSafeFieldName(originalFieldName);
        newValue = event.NewData;
        if isempty(newValue)
            newValue = '';
        end
        
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
    
    function callModulesCallback(~, ~)
        if ~isfield(state, 'selectedRows') || isempty(state.selectedRows)
            return
        end
        rows = state.selectedRows(:)';
        moduleName = get(moduleSelect, 'String');
        moduleIdx = get(moduleSelect, 'Value');
        moduleAction = moduleName{moduleIdx};
        
        % Показываем GUI для редактирования параметров модуля один раз перед обработкой всех файлов
        try
            editModuleParamsGUI(moduleAction);
        catch ME
            debugState('fileManagerGUI', 'Failed to open parameter editor: %s', ME.message);
            % Продолжаем выполнение с параметрами по умолчанию
        end
        
        % Обработка всех выбранных файлов
        for idx = 1:numel(rows)
            rowIdx = rows(idx);
            if rowIdx < 1 || rowIdx > numel(state.files)
                continue
            end
            filePath = state.files(rowIdx).path;
            fileId = state.files(rowIdx).id;
            debugState('fileManagerGUI', 'Module %s %d/%d: %s', moduleAction, idx, numel(rows), filePath);
            result = callModules(moduleAction, filePath, fileId);
            if ~isempty(result) && isstruct(result)
                updateAnalysisTable(state.files(rowIdx).id);
            end
        end
    end
    
    function result = callModules(action, filePath, fileId)
        result = [];
        if nargin < 2
            filePath = '';
        end
        if nargin < 3
            fileId = [];
        end
        try
            macroFunc = str2func(action);
            if nargin(macroFunc) >= 2
                result = macroFunc(filePath, fileId);
            else
                result = macroFunc(filePath);
            end
        catch ME
            debugState('fileManagerGUI', 'Module call failed: %s (%s)', action, ME.message);
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
            if ~ishandle(moduleSelect)
                moduleName = 'autoMeanStimulus';
            else
                modules = get(moduleSelect, 'String');
                if isempty(modules)
                    moduleName = 'autoMeanStimulus';
                elseif iscell(modules)
                    moduleIdx = min(get(moduleSelect, 'Value'), numel(modules));
                    moduleName = modules{moduleIdx};
                else
                    moduleName = modules;
                end
            end
            query = sprintf(['SELECT file_id, report_path, module_name FROM analysis_results ' ...
                'WHERE %s AND module_name = ''%s'' ORDER BY analysis_timestamp DESC'], ...
                whereClause, escapeSql(moduleName));
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
        reportPath = normalizePath(data{selected(1), 2});
        if isempty(reportPath)
            return
        end
        if exist(reportPath, 'file')
            winopen(reportPath);
        else
            msgbox(sprintf('File not found: %s', reportPath), 'Error', 'error');
        end
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
        reportPath = normalizePath(data{selected(1), 2});
        if isempty(reportPath)
            return
        end
        if exist(reportPath, 'file')
            folder = fileparts(reportPath);
            if exist(folder, 'dir')
                winopen(folder);
            else
                msgbox(sprintf('Folder not found: %s', folder), 'Error', 'error');
            end
        else
            msgbox(sprintf('File not found: %s', reportPath), 'Error', 'error');
        end
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
            validPaths = reportPaths(~cellfun(@isempty, reportPaths));
            if isempty(validPaths)
                return
            end
            choice = questdlg(sprintf('Delete %d selected analysis result(s)?', numel(validPaths)), ...
                'Confirm Delete', 'Delete', 'Cancel', 'Cancel');
            if ~strcmp(choice, 'Delete')
                return
            end
            deleteFiles(validPaths);
            deleteRecords(validPaths);
            if isfield(state, 'selectedFileIds') && ~isempty(state.selectedFileIds)
                updateAnalysisTable(state.selectedFileIds);
            else
                updateAnalysisTable([]);
            end
        catch ME
            msgbox(sprintf('Failed to delete result: %s', ME.message), 'Error', 'error');
        end
    end
    
    function metadataAnalysisCallback(~, ~)
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
        reportPaths = cellfun(@(v) normalizePath(v), data(selectedRows, 2), 'UniformOutput', false);
        fileIds = cellfun(@(v) v, data(selectedRows, 1), 'UniformOutput', false);
        validIndices = ~cellfun(@isempty, reportPaths);
        validPaths = reportPaths(validIndices);
        validFileIds = fileIds(validIndices);
        if isempty(validPaths)
            return
        end
        metaPaths = cellfun(@(p) replaceFileExt(p, '.meta'), validPaths, 'UniformOutput', false);
        fileIdArray = cellfun(@(id) id, validFileIds);
        metadataAnalysis(metaPaths, fileIdArray);
    end
    
    function deleteFiles(paths)
        for i = 1:numel(paths)
            deleteIfExists(paths{i});
            metaPath = replaceFileExt(paths{i}, '.meta');
            deleteIfExists(metaPath);
        end
    end
    
    function deleteRecords(paths)
        if isempty(paths)
            return
        end
        dbPath = getDbPath();
        if isempty(dbPath) || ~isfile(dbPath)
            return
        end
        conn = openSqliteConnection(dbPath);
        if isempty(conn)
            return
        end
        try
            escaped = cellfun(@(p) ['''' escapeSql(p) ''''], paths, 'UniformOutput', false);
            inClause = strjoin(escaped, ',');
            query = sprintf('DELETE FROM analysis_results WHERE report_path IN (%s)', inClause);
            sqlExecWithConn(conn, query);
        catch ME
            warning('Failed to delete records: %s', ME.message);
        end
        closeJdbcResource(conn);
    end
    
    function deleteIfExists(pathStr)
        if exist(pathStr, 'file')
            delete(pathStr);
        end
    end
    
    function newPath = replaceFileExt(pathStr, newExt)
        [folder, name, ~] = fileparts(pathStr);
        newPath = fullfile(folder, [name, newExt]);
    end

    function pathStr = normalizePath(value)
        if isempty(value)
            pathStr = '';
        elseif isstring(value)
            pathStr = char(value);
        elseif iscell(value)
            pathStr = normalizePath(value{1});
        else
            pathStr = char(value);
        end
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
        state.selectedFileIds = arrayfun(@(idx) state.files(idx).id, state.selectedRows(state.selectedRows >= 1 & state.selectedRows <= numel(state.files)));
        state.selectedColumn = colIdx;
        updateFileTableCounter(numel(state.selectedRows));
        if rowIdx >= 1 && rowIdx <= numel(state.files)
            state.selectedFileId = state.files(rowIdx).id;
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
        if exist('openFileFolderBtn', 'var') && ishandle(openFileFolderBtn)
            set(openFileFolderBtn, 'Enable', onOff(enableState));
        end
        if exist('openBtn', 'var') && ishandle(openBtn)
            set(openBtn, 'Enable', onOff(enableState));
        end
        if exist('deleteBtn', 'var') && ishandle(deleteBtn)
            set(deleteBtn, 'Enable', onOff(enableState));
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


function projectId = readStoredProjectId()
    global SettingsFilepath
    projectId = [];
    try
        if exist(SettingsFilepath, 'file')
            data = load(SettingsFilepath);
            if isfield(data, 'file_manager_project_id')
                projectId = data.file_manager_project_id;
            end
        end
    catch
        projectId = [];
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

