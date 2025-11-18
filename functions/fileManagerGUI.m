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
    end
    
    state.dbPath = initDbPath();
    
    fig = figure('Position', [100, 100, 620, 390], ...
        'Name', 'File Manager (SQL)', ...
        'NumberTitle', 'off', ...
        'MenuBar', 'none', ...
        'ToolBar', 'none', ...
        'Resize', 'off', ...
        'Tag', figTag);
    
    uicontrol('Style', 'text', ...
        'Position', [10, 355, 70, 20], ...
        'String', 'Проект:', ...
        'HorizontalAlignment', 'left');
    
    projectSelect = uicontrol('Style', 'popupmenu', ...
        'Position', [75, 350, 220, 25], ...
        'String', {'Загрузка...'}, ...
        'Callback', @switchProject);
    
    refreshBtn = uicontrol('Style', 'pushbutton', ...
        'Position', [305, 350, 80, 25], ...
        'String', 'Обновить', ...
        'Callback', @reloadProjects);
    
    addBtn = uicontrol('Style', 'pushbutton', ...
        'Position', [395, 350, 80, 25], ...
        'String', 'Добавить', ...
        'Callback', @addFilesToProject);
    
    deleteBtn = uicontrol('Style', 'pushbutton', ...
        'Position', [485, 350, 60, 25], ...
        'String', 'Удалить', ...
        'Callback', @removeSelectedFile);
    
    openBtn = uicontrol('Style', 'pushbutton', ...
        'Position', [555, 350, 55, 25], ...
        'String', 'Открыть', ...
        'Callback', @openSelectedFile);
    
    uicontrol('Style', 'text', ...
        'Position', [10, 325, 60, 18], ...
        'String', 'База:', ...
        'HorizontalAlignment', 'left');
    
    dbPathDisplay = uicontrol('Style', 'edit', ...
        'Position', [65, 322, 380, 22], ...
        'String', truncatePath(state.dbPath), ...
        'Enable', 'inactive', ...
        'HorizontalAlignment', 'left');
    
    dbBtn = uicontrol('Style', 'pushbutton', ...
        'Position', [455, 322, 155, 22], ...
        'String', 'Выбрать базу данных', ...
        'Callback', @chooseDbPath);
    
    fileTable = uitable('Position', [10, 10, 600, 330], ...
        'ColumnWidth', {150, 430}, ...
        'ColumnName', {'Имя файла', 'Путь'}, ...
        'ColumnEditable', [false, false]);
    fileTable.UserData = struct('lastClick', now, 'row', []);
    fileTable.CellSelectionCallback = @handleCellSelection;
    
    loadProjectsFromDb();
    
    function loadProjectsFromDb()
        if isempty(state.dbPath) || ~isfile(state.dbPath)
            set(dbPathDisplay, 'String', 'Не выбран файл базы');
            projectSelect.String = {'Нет проектов'};
            projectSelect.Value = 1;
            state.projects = [];
            state.files = [];
            updateTable([]);
            return
        end
        
        projects = fetchProjects();
        if isempty(projects)
            projectSelect.String = {'Нет проектов'};
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
    
    function reloadProjects(~, ~)
        state.selectedRow = [];
        loadProjectsFromDb();
    end
    
    function chooseDbPath(~, ~)
        startDir = fileparts(state.dbPath);
        if isempty(startDir) || ~isfolder(startDir)
            startDir = fileparts(defaultDbPath());
        end
        [file, path] = uigetfile('*.db', 'Выберите SQLite базу', startDir);
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
        files = fetchProjectFiles(projectId);
        state.files = files;
        state.selectedRow = [];
        updateTable(files);
    end
    
function addFilesToProject(~, ~)
        if isempty(state.currentProjectId)
            disp('Проект не выбран');
            return
        end
        [fileNames, basePath] = uigetfile({'*.*', 'Все файлы'}, 'Выберите файлы', 'MultiSelect', 'on');
        if isequal(fileNames, 0)
            return
        end
        if ischar(fileNames)
            fileNames = {fileNames};
        end
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
        unlinkFileFromProject(fileInfo.id, state.currentProjectId);
        loadFilesForProject(state.currentProjectId);
    end
    
    function openSelectedFile(varargin)
        if isempty(state.selectedRow)
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
        nowTime = now;
        if (nowTime - src.UserData.lastClick) * 24 * 60 * 60 < 0.4
            openSelectedFile();
        end
        src.UserData.lastClick = nowTime;
    end
    
    function updateTable(files)
        if isempty(files)
            fileTable.Data = {};
            return
        end
        names = {files.name}';
        paths = {files.path}';
        fileTable.Data = [names, paths];
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

function files = fetchProjectFiles(projectId)
    query = sprintf(['SELECT f.id, f.file_name, f.file_path, pf.group_id ' ...
        'FROM project_files pf ' ...
        'JOIN files f ON f.id = pf.file_id ' ...
        'WHERE pf.project_id = %d ORDER BY f.created_at DESC'], projectId);
    rows = sqlFetch(query);
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

function launchFile(filePath)
    if ~exist(filePath, 'file')
        fprintf('Файл не найден: %s\n', filePath);
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
            fprintf('Неизвестное расширение: %s\n', ext);
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
        warning('База данных не найдена: %s', dbPath);
        rows = {};
        return
    end
    conn = sqlite(dbPath, 'connect');
    try
        rows = fetch(conn, query);
        if istable(rows)
            rows = table2cell(rows);
        elseif isnumeric(rows) || islogical(rows)
            rows = num2cell(rows);
        end
    catch ME
        warning('SQL fetch error: %s', ME.message);
        rows = {};
    end
    close(conn);
end

function sqlExec(query)
    dbPath = getDbPath();
    if isempty(dbPath) || ~isfile(dbPath)
        warning('База данных не найдена: %s', dbPath);
        return
    end
    conn = sqlite(dbPath, 'connect');
    try
        exec(conn, query);
    catch ME
        warning('SQL exec error: %s', ME.message);
    end
    close(conn);
end

function dbPath = getDbPath()
    global FileManagerDbPath
    if isempty(FileManagerDbPath)
        FileManagerDbPath = initDbPath();
    end
    dbPath = FileManagerDbPath;
end

function path = defaultDbPath()
    currentFile = mfilename('fullpath');
    projectRoot = fileparts(fileparts(fileparts(currentFile)));
    path = fullfile(projectRoot, 'instance', 'app.db');
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
            data = load(SettingsFilepath, 'file_manager_project_id');
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
        warning('Не удалось сохранить выбранный проект: %s', ME.message);
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
        warning('Не удалось сохранить путь к базе: %s', ME.message);
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
