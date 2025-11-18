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
        state.selectedRow = [];
        state.dbPath = '';
        state.metadataFields = {};
        state.metadataData = struct();
        state.fieldNameMap = struct();
    end
    
    state.dbPath = initDbPath();
    
    fig = figure('Position', [100, 100, 945, 390], ...
        'Name', 'File Manager (SQL)', ...
        'NumberTitle', 'off', ...
        'MenuBar', 'none', ...
        'ToolBar', 'none', ...
        'Resize', 'off', ...
        'Tag', figTag);
    
    uicontrol('Style', 'text', ...
        'Position', [10, 355, 70, 20], ...
        'String', 'Project:', ...
        'HorizontalAlignment', 'left');
    
    projectSelect = uicontrol('Style', 'popupmenu', ...
        'Position', [75, 350, 220, 25], ...
        'String', {'Loading...'}, ...
        'Callback', @switchProject);
    
    newProjectBtn = uicontrol('Style', 'pushbutton', ...
        'Position', [305, 350, 100, 25], ...
        'String', 'Create New Project', ...
        'Callback', @createNewProject);

    addBtn = uicontrol('Style', 'pushbutton', ...
        'Position', [415, 350, 100, 25], ...
        'String', 'Add Files to Project', ...
        'Callback', @addFilesToProject);
    
    deleteBtn = uicontrol('Style', 'pushbutton', ...
        'Position', [525, 350, 100, 25], ...
        'String', 'Remove Selected File', ...
        'Callback', @removeSelectedFile);
    
    openBtn = uicontrol('Style', 'pushbutton', ...
        'Position', [635, 350, 100, 25], ...
        'String', 'Open Selected File', ...
        'Callback', @openSelectedFile);
    
    uicontrol('Style', 'text', ...
        'Position', [10, 325, 60, 18], ...
        'String', 'Database:', ...
        'HorizontalAlignment', 'left');
    
    dbPathDisplay = uicontrol('Style', 'edit', ...
        'Position', [65, 322, 300, 22], ...
        'String', truncatePath(state.dbPath), ...
        'Enable', 'inactive', ...
        'HorizontalAlignment', 'left');
    
    createDbBtn = uicontrol('Style', 'pushbutton', ...
        'Position', [375, 322, 120, 22], ...
        'String', 'Create New Database', ...
        'Callback', @createNewDatabase);
    
    dbBtn = uicontrol('Style', 'pushbutton', ...
        'Position', [505, 322, 120, 22], ...
        'String', 'Select Database', ...
        'Callback', @chooseDbPath);
    
    fileTable = uitable('Position', [10, 10, 925, 300], ...
        'ColumnWidth', {150, 665}, ...
        'ColumnName', {'File Name', 'Path'}, ...
        'ColumnEditable', [false, false]);
    fileTable.UserData = struct('row', []);
    fileTable.CellSelectionCallback = @handleCellSelection;
    fileTable.CellEditCallback = @handleCellEdit;
    
    addFieldBtn = uicontrol('Style', 'pushbutton', ...
        'Position', [745, 350, 90, 25], ...
        'String', 'Add Field', ...
        'Callback', @addMetadataField);
    
    loadProjectsFromDb();
    
    function loadProjectsFromDb()
        if isempty(state.dbPath) || ~isfile(state.dbPath)
            set(dbPathDisplay, 'String', 'No database selected');
            projectSelect.String = {'No projects'};
            projectSelect.Value = 1;
            state.projects = [];
            state.files = [];
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
        state.selectedRow = [];
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
            state.selectedRow = [];
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
        state.selectedRow = [];
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
            state.selectedRow = [];
            updateTable([]);
            return
        end
        conn = openSqliteConnection(dbPath);
        if isempty(conn)
            state.files = [];
            state.selectedRow = [];
            updateTable([]);
            return
        end
        try
            files = fetchProjectFilesWithConn(conn, projectId);
            state.files = files;
            state.selectedRow = [];
            loadMetadataForProjectWithConn(conn, projectId);
            updateTable(files);
        catch ME
            warning('Failed to load project files: %s', ME.message);
            state.files = [];
            state.selectedRow = [];
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
        
        fprintf('[%s] Saving metadata to database for file_id=%d\n', datestr(now, 'HH:MM:SS'), fileId);
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
        autoBackupDatabase();
        fileInfo = state.files(rowIdx);
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
    
    function handleCellSelection(src, event)
        if isempty(event.Indices)
            state.selectedRow = [];
            src.UserData.row = [];
            return
        end
        rowIdx = event.Indices(1);
        state.selectedRow = rowIdx;
        src.UserData.row = rowIdx;
    end
    
    function updateTable(files)
        if isempty(files)
            fileTable.Data = {};
            fileTable.ColumnName = {'File Name', 'Path'};
            fileTable.ColumnEditable = [false, false];
            fileTable.ColumnWidth = {150, 665};
            return
        end
        
        names = {files.name}';
        paths = {files.path}';
        
        columnNames = {'File Name', 'Path'};
        columnEditable = [false, false];
        columnWidths = {150, 400};
        
        data = [names, paths];
        
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

function path = initDbPath()
    global FileManagerDbPath
    stored = readStoredDbPath();
    if ~isempty(stored) && isfile(stored)
        FileManagerDbPath = stored;
        path = stored;
        return
    end
    defaultPath = defaultDbPath();
    if isfile(defaultPath)
        FileManagerDbPath = defaultPath;
        storeDbPath(defaultPath);
        path = defaultPath;
    else
        FileManagerDbPath = '';
        path = '';
    end
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

function launchFile(filePath)
    if ~exist(filePath, 'file')
        fprintf('File not found: %s\n', filePath);
        return
    end
    [~, ~, ext] = fileparts(filePath);
    global event_calling outside_calling_filepath
    global zav_calling wb table_calling events event_inx event_title_string
    outside_calling_filepath = filePath;
    fprintf('Please wait...\n');
    switch lower(ext)
        case '.ev'
            event_calling();
        case '.mat'
            zav_calling();
            events = [];
            event_title_string = 'Events';
            table_calling();
            event_inx = 1;
        otherwise
            fprintf('Unknown extension: %s\n', ext);
    end
    fprintf('File loaded.\n');
    try
        close(wb);
    catch
    end
end

function rows = sqlFetch(query)
    dbPath = getDbPath();
    if isempty(dbPath) || ~isfile(dbPath)
        warning('Database not found: %s', dbPath);
        rows = {};
        return
    end
    conn = openSqliteConnection(dbPath);
    if isempty(conn)
        rows = {};
        return
    end
    rows = sqlFetchWithConn(conn, query);
    closeJdbcResource(conn);
end

function rows = sqlFetchWithConn(conn, query)
    rows = {};
    if isempty(conn)
        return
    end
    stmt = [];
    rs = [];
    try
        stmt = conn.createStatement();
        rs = stmt.executeQuery(query);
        rows = jdbcResultToCell(rs);
    catch ME
        warning('SQL fetch error: %s', ME.message);
        rows = {};
    end
    closeJdbcResource(rs);
    closeJdbcResource(stmt);
end

function sqlExec(query)
    dbPath = getDbPath();
    if isempty(dbPath) || ~isfile(dbPath)
        warning('Database not found: %s', dbPath);
        return
    end
    conn = openSqliteConnection(dbPath);
    if isempty(conn)
        return
    end
    stmt = [];
    try
        stmt = conn.createStatement();
        stmt.executeUpdate(query);
    catch ME
        warning('SQL exec error: %s', ME.message);
    end
    closeJdbcResource(stmt);
    closeJdbcResource(conn);
end

function dbPath = getDbPath()
    global FileManagerDbPath
    if isempty(FileManagerDbPath)
        FileManagerDbPath = initDbPath();
    end
    dbPath = FileManagerDbPath;
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
        fprintf('[%s] Backup created: %s\n', datestr(now, 'HH:MM:SS'), backupName);
        
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

function path = defaultDbPath()
    currentFile = mfilename('fullpath');
    projectRoot = fileparts(fileparts(fileparts(currentFile)));
    path = fullfile(projectRoot, 'instance', 'app.db');
end

function conn = openSqliteConnection(dbPath)
    persistent driverInstance driverLoaded
    conn = [];
    if isempty(dbPath)
        return
    end
    driverPath = fullfile(fileparts(mfilename('fullpath')), 'sqlite-jdbc.jar');
    driverPath = char(java.io.File(driverPath).getAbsolutePath());
    
    if isempty(driverLoaded) || ~driverLoaded || isempty(driverInstance)
        if ~jdbcDriverLoaded(driverPath)
            return
        end
        try
            fileUrl = java.io.File(driverPath).toURI().toURL();
            urlArray = javaArray('java.net.URL', 1);
            urlArray(1) = fileUrl;
            driverLoader = java.net.URLClassLoader.newInstance(urlArray);
            driverClass = driverLoader.loadClass('org.sqlite.JDBC');
            driverInstance = driverClass.newInstance();
            driverLoaded = true;
            fprintf('[%s] SQLite driver loaded via URLClassLoader\n', datestr(now, 'HH:MM:SS'));
        catch ME
            warning('Failed to load SQLite driver: %s', ME.message);
            driverLoaded = false;
            driverInstance = [];
            return
        end
    end
    
    try
        dbUrl = ['jdbc:sqlite:' strrep(dbPath, '\', '/')];
        props = java.util.Properties();
        conn = driverInstance.connect(dbUrl, props);
    catch ME
        warning('SQLite connection error: %s', ME.message);
        fprintf('[%s] Connection failed: %s\n', datestr(now, 'HH:MM:SS'), ME.message);
        conn = [];
        driverLoaded = false;
        driverInstance = [];
    end
end

function loaded = jdbcDriverLoaded(driverPath)
    loaded = false;
    driverPath = char(driverPath);
    if ~isfile(driverPath)
        warning('JDBC driver not found: %s', driverPath);
        return
    end
    loaded = true;
end

function rows = jdbcResultToCell(resultSet)
    rows = {};
    if isempty(resultSet)
        return
    end
    try
        meta = resultSet.getMetaData();
        colCount = double(meta.getColumnCount());
        data = cell(0, colCount);
        rowIdx = 1;
        while resultSet.next()
            row = cell(1, colCount);
            for col = 1:colCount
                value = getResultSetValue(resultSet, meta, col);
                row{col} = value;
            end
            data(rowIdx, :) = row;
            rowIdx = rowIdx + 1;
        end
        rows = data;
    catch ME
        warning('SQL result reading error: %s', ME.message);
        rows = {};
    end
end

function value = getResultSetValue(resultSet, meta, col)
    value = [];
    try
        typeName = char(meta.getColumnTypeName(col));
        switch lower(typeName)
            case {'integer', 'int', 'bigint'}
                val = resultSet.getLong(col);
                if resultSet.wasNull()
                    value = [];
                else
                    value = double(val);
                end
            case {'real', 'double', 'float', 'numeric'}
                val = resultSet.getDouble(col);
                if resultSet.wasNull()
                    value = [];
                else
                    value = double(val);
                end
            case {'text', 'varchar', 'char'}
                val = resultSet.getString(col);
                if isempty(val) || resultSet.wasNull()
                    value = [];
                else
                    value = char(val);
                end
            case {'blob'}
                val = resultSet.getBytes(col);
                if isempty(val) || resultSet.wasNull()
                    value = [];
                else
                    value = val;
                end
            otherwise
                val = resultSet.getString(col);
                if isempty(val) || resultSet.wasNull()
                    value = [];
                else
                    value = char(val);
                end
        end
    catch
        try
            obj = resultSet.getObject(col);
            if isempty(obj) || resultSet.wasNull()
                value = [];
            else
                value = char(obj.toString());
            end
        catch
            value = [];
        end
    end
end

function value = convertJdbcValue(javaValue)
    if isempty(javaValue)
        value = [];
        return
    end
    if isa(javaValue, 'java.lang.Integer') || isa(javaValue, 'java.lang.Long') || isa(javaValue, 'java.lang.Short')
        value = double(javaValue);
    elseif isa(javaValue, 'java.math.BigDecimal')
        value = double(javaValue.doubleValue());
    elseif isa(javaValue, 'java.lang.Double')
        value = double(javaValue);
    elseif isa(javaValue, 'java.lang.Boolean')
        value = logical(javaValue);
    elseif isa(javaValue, 'java.lang.String')
        value = char(javaValue);
    else
        value = char(javaValue.toString());
    end
end

function closeJdbcResource(object)
    if isempty(object)
        return
    end
    try
        object.close();
    catch
    end
end

function text = escapeSql(text)
    if isempty(text)
        return
    end
    text = strrep(text, '''', '''''');
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

function storeDbPath(dbPath)
    global SettingsFilepath
    try
        if exist(SettingsFilepath, 'file')
            data = load(SettingsFilepath);
        else
            data = struct();
        end
        data.file_manager_db_path = dbPath;
        save(SettingsFilepath, '-struct', 'data');
    catch ME
        warning('Failed to save database path: %s', ME.message);
    end
end

function path = readStoredDbPath()
    global SettingsFilepath
    path = '';
    try
        if exist(SettingsFilepath, 'file')
            data = load(SettingsFilepath, 'file_manager_db_path');
            if isfield(data, 'file_manager_db_path')
                path = data.file_manager_db_path;
            end
        end
    catch
        path = '';
    end
end
