function fileManagerGUI()
    loadGlobalSettings();
    global SettingsFilepath auto_open_last_file

    figTag = 'fileManagerGUI';
    existingFig = findobj('Type', 'figure', 'Tag', figTag);
    if ~isempty(existingFig)
        figure(existingFig);
        return
    end

    state = struct();
    state.table = table();
    state.xlsxPath = '';
    state.pathColumn = '';
    state.selectedRows = [];
    state.fileTimestamp = 0;

    fig = figure( ...
        'Name', 'File Manager', ...
        'NumberTitle', 'off', ...
        'MenuBar', 'none', ...
        'ToolBar', 'none', ...
        'Resize', 'on', ...
        'Units', 'pixels', ...
        'Position', [100, 100, 1100, 600], ...
        'Tag', figTag, ...
        'WindowKeyPressFcn', @keyPressCallback, ...
        'CloseRequestFcn', @closeFileManagerWindow);

    uicontrol('Parent', fig, ...
        'Style', 'pushbutton', ...
        'Units', 'normalized', ...
        'Position', [0.01, 0.93, 0.10, 0.05], ...
        'String', 'Select Table', ...
        'Callback', @selectTableCallback);

    uicontrol('Parent', fig, ...
        'Style', 'pushbutton', ...
        'Units', 'normalized', ...
        'Position', [0.12, 0.93, 0.10, 0.05], ...
        'String', 'New Table', ...
        'Callback', @newTableCallback);

    uicontrol('Parent', fig, ...
        'Style', 'pushbutton', ...
        'Units', 'normalized', ...
        'Position', [0.23, 0.93, 0.09, 0.05], ...
        'String', 'Add Files', ...
        'Callback', @addFilesCallback);

    uicontrol('Parent', fig, ...
        'Style', 'pushbutton', ...
        'Units', 'normalized', ...
        'Position', [0.33, 0.93, 0.10, 0.05], ...
        'String', 'Delete Rows', ...
        'Callback', @deleteRowsCallback);

    uicontrol('Parent', fig, ...
        'Style', 'pushbutton', ...
        'Units', 'normalized', ...
        'Position', [0.44, 0.93, 0.07, 0.05], ...
        'String', 'Save', ...
        'Callback', @saveTableCallback);

    uicontrol('Parent', fig, ...
        'Style', 'pushbutton', ...
        'Units', 'normalized', ...
        'Position', [0.52, 0.93, 0.08, 0.05], ...
        'String', 'Excel', ...
        'Callback', @openTableInExcel);

    uicontrol('Parent', fig, ...
        'Style', 'text', ...
        'Units', 'normalized', ...
        'Position', [0.61, 0.93, 0.09, 0.05], ...
        'String', 'Path column:', ...
        'HorizontalAlignment', 'right');

    pathColumnPopup = uicontrol('Parent', fig, ...
        'Style', 'popupmenu', ...
        'Units', 'normalized', ...
        'Position', [0.71, 0.93, 0.11, 0.05], ...
        'String', {'(none)'}, ...
        'Enable', 'off', ...
        'Callback', @pathColumnChanged);

    uicontrol('Parent', fig, ...
        'Style', 'pushbutton', ...
        'Units', 'normalized', ...
        'Position', [0.83, 0.93, 0.07, 0.05], ...
        'String', 'Open', ...
        'Callback', @openSelectedFile);

    uicontrol('Parent', fig, ...
        'Style', 'pushbutton', ...
        'Units', 'normalized', ...
        'Position', [0.91, 0.93, 0.08, 0.05], ...
        'String', 'Open Folder', ...
        'Callback', @openSelectedFolder);

    filePathLabel = uicontrol('Parent', fig, ...
        'Style', 'text', ...
        'Units', 'normalized', ...
        'Position', [0.01, 0.88, 0.98, 0.04], ...
        'String', 'No table selected', ...
        'HorizontalAlignment', 'left');

    fileTable = uitable('Parent', fig, ...
        'Units', 'normalized', ...
        'Position', [0.01, 0.02, 0.98, 0.85], ...
        'ColumnEditable', false, ...
        'CellSelectionCallback', @handleCellSelection, ...
        'Data', cell(0, 0));

    drawnow;
    disableTableEnterAdvance();
    autoOpenLastTable();

    refreshTimer = timer( ...
        'ExecutionMode', 'fixedSpacing', ...
        'Period', 2, ...
        'BusyMode', 'drop', ...
        'TimerFcn', @checkExternalTableUpdate);
    start(refreshTimer);

    function closeFileManagerWindow(src, ~)
        stop(refreshTimer);
        delete(refreshTimer);
        delete(src);
        manageMainWindows('fileManagerGUI');
    end

    function keyPressCallback(~, event)
        if strcmp(event.Key, 'return')
            openSelectedFile();
        end
    end

    function disableTableEnterAdvance()
        jScroll = findjobj(fileTable);
        jTable = jScroll.getViewport.getView();
        enterKey = javax.swing.KeyStroke.getKeyStroke(java.awt.event.KeyEvent.VK_ENTER, 0);
        jTable.getInputMap(javax.swing.JComponent.WHEN_FOCUSED).put(enterKey, 'none');
        jTable.getInputMap(javax.swing.JComponent.WHEN_ANCESTOR_OF_FOCUSED_COMPONENT).put(enterKey, 'none');
    end

    function startDir = dialogStartDir()
        startDir = fileparts(state.xlsxPath);
        if exist(startDir, 'dir')
            startDir = [startDir, filesep];
            return
        end
        settings = loadFileManagerSettings();
        startDir = fileparts(settings.lastTablePath);
        if exist(startDir, 'dir')
            startDir = [startDir, filesep];
            return
        end
        startDir = [pwd, filesep];
    end

    function markFileTimestamp()
        info = dir(state.xlsxPath);
        state.fileTimestamp = 0;
        if ~isempty(info)
            state.fileTimestamp = info.datenum;
        end
    end

    function checkExternalTableUpdate(~, ~)
        if isempty(state.xlsxPath)
            return
        end
        info = dir(state.xlsxPath);
        if isempty(info) || info.datenum == state.fileTimestamp
            return
        end
        try
            loadedTable = readtable(state.xlsxPath);
        catch
            return
        end
        applyLoadedTable(state.xlsxPath, loadedTable, state.pathColumn);
        set(filePathLabel, 'String', ['Updated: ', state.xlsxPath]);
    end

    function applyLoadedTable(xlsxPath, loadedTable, preferredPathColumn)
        loadedTable = toStringTable(loadedTable);
        columnNames = loadedTable.Properties.VariableNames;
        state.table = loadedTable;
        state.xlsxPath = xlsxPath;
        state.selectedRows = [];
        pathIdx = 1;
        matchIdx = find(strcmp(columnNames, preferredPathColumn), 1);
        pathIdx = [matchIdx, 1];
        pathIdx = pathIdx(1);
        state.pathColumn = columnNames{pathIdx};
        set(pathColumnPopup, 'String', columnNames, 'Value', pathIdx, 'Enable', 'on');
        set(filePathLabel, 'String', xlsxPath);
        refreshTableView();
        markFileTimestamp();
        rememberCurrentTable();
    end

    function selectTableCallback(~, ~)
        [fileName, pathName] = uigetfile({'*.xlsx', 'Excel files (*.xlsx)'}, 'Select Excel table', dialogStartDir());
        if isequal(fileName, 0)
            return
        end
        xlsxPath = fullfile(pathName, fileName);
        applyLoadedTable(xlsxPath, readtable(xlsxPath), '');
    end

    function newTableCallback(~, ~)
        defaultPath = fullfile(dialogStartDir(), 'file_list.xlsx');
        [fileName, pathName] = uiputfile({'*.xlsx', 'Excel files (*.xlsx)'}, 'Create new table', defaultPath);
        if isequal(fileName, 0)
            return
        end
        xlsxPath = fullfile(pathName, fileName);
        newTbl = table(string.empty(0, 1), 'VariableNames', {'file_path'});
        writetable(newTbl, xlsxPath);
        applyLoadedTable(xlsxPath, newTbl, 'file_path');
    end

    function addFilesCallback(~, ~)
        if isempty(state.pathColumn)
            return
        end
        [fileNames, pathName] = uigetfile( ...
            {'*.mat;*.ev;*.abf;*.*', 'Data files (*.mat, *.ev, *.abf)'; '*.*', 'All files (*.*)'}, ...
            'Add files', ...
            dialogStartDir(), ...
            'MultiSelect', 'on');
        if isequal(fileNames, 0)
            return
        end
        fileNames = cellstr(fileNames);
        fileNames = fileNames(:);
        nNew = numel(fileNames);
        columnNames = state.table.Properties.VariableNames;
        nCols = numel(columnNames);
        block = table('Size', [nNew, nCols], ...
            'VariableTypes', repmat({'string'}, 1, nCols), ...
            'VariableNames', columnNames);
        block.(state.pathColumn) = string(fullfile(pathName, fileNames));
        state.table = [state.table; block];
        state.selectedRows = [];
        refreshTableView();
    end

    function deleteRowsCallback(~, ~)
        rows = state.selectedRows;
        if isempty(rows)
            return
        end
        state.table(rows, :) = [];
        state.selectedRows = [];
        refreshTableView();
    end

    function saveTableCallback(~, ~)
        if isempty(state.xlsxPath)
            return
        end
        if ~saveTableToDisk()
            return
        end
        set(filePathLabel, 'String', ['Saved: ', state.xlsxPath]);
        rememberCurrentTable();
    end

    function openTableInExcel(~, ~)
        if isempty(state.xlsxPath)
            return
        end
        if isExcelFileLocked(state.xlsxPath)
            winopen(state.xlsxPath);
            set(filePathLabel, 'String', ['Already open in Excel: ', state.xlsxPath]);
            return
        end
        if ~saveTableToDisk()
            return
        end
        rememberCurrentTable();
        winopen(state.xlsxPath);
    end

    function ok = saveTableToDisk()
        ok = false;
        if isExcelFileLocked(state.xlsxPath)
            msgbox( ...
                sprintf(['Table is open in Excel:\n%s\n\n' ...
                'Close it in Excel and save again, or save from Excel — File Manager will refresh automatically.'], ...
                state.xlsxPath), ...
                'File Manager', 'warn');
            return
        end
        try
            columnWidths = fileTable.ColumnWidth;
            writetable(state.table, state.xlsxPath);
            writeExcelColumnWidths(state.xlsxPath, columnWidths);
            markFileTimestamp();
            ok = true;
        catch ME
            msgbox(sprintf('Failed to save table:\n%s', ME.message), 'File Manager', 'error');
        end
    end

    function pathColumnChanged(~, ~)
        columnNames = get(pathColumnPopup, 'String');
        state.pathColumn = columnNames{get(pathColumnPopup, 'Value')};
        rememberCurrentTable();
    end

    function refreshTableView()
        columnNames = state.table.Properties.VariableNames;
        nRows = height(state.table);
        nCols = width(state.table);
        cellData = cell(nRows, nCols);
        for c = 1:nCols
            cellData(:, c) = cellstr(state.table.(columnNames{c}));
        end
        set(fileTable, ...
            'Data', cellData, ...
            'ColumnName', columnNames, ...
            'ColumnWidth', readExcelColumnWidths(state.xlsxPath, nCols));
    end

    function handleCellSelection(~, event)
        state.selectedRows = [];
        if isempty(event.Indices)
            return
        end
        state.selectedRows = unique(event.Indices(:, 1), 'stable');
    end

    function filePath = selectedFilePath()
        colData = state.table.(state.pathColumn);
        filePath = char(strtrim(colData(state.selectedRows(1))));
    end

    function openSelectedFile(~, ~)
        if isempty(state.selectedRows)
            return
        end
        launchFile(selectedFilePath());
    end

    function openSelectedFolder(~, ~)
        if isempty(state.selectedRows)
            return
        end
        winopen(fileparts(selectedFilePath()));
    end

    function rememberCurrentTable()
        fileManager_settings = struct( ...
            'lastTablePath', state.xlsxPath, ...
            'pathColumn', state.pathColumn);
        if exist(SettingsFilepath, 'file')
            save(SettingsFilepath, 'fileManager_settings', '-append');
        else
            save(SettingsFilepath, 'fileManager_settings');
        end
    end

    function autoOpenLastTable()
        if isempty(auto_open_last_file) || ~auto_open_last_file
            return
        end
        settings = loadFileManagerSettings();
        lastPath = settings.lastTablePath;
        if isempty(lastPath) || exist(lastPath, 'file') ~= 2
            return
        end
        applyLoadedTable(lastPath, readtable(lastPath), settings.pathColumn);
    end
end

function settings = loadFileManagerSettings()
    global SettingsFilepath
    settings = struct('lastTablePath', '', 'pathColumn', '');
    if isempty(SettingsFilepath) || exist(SettingsFilepath, 'file') ~= 2
        return
    end
    d = load(SettingsFilepath);
    if ~isfield(d, 'fileManager_settings')
        return
    end
    settings = d.fileManager_settings;
    if ~isfield(settings, 'lastTablePath')
        settings.lastTablePath = '';
    end
    if ~isfield(settings, 'pathColumn')
        settings.pathColumn = '';
    end
end

function locked = isExcelFileLocked(xlsxPath)
    [folder, name, ext] = fileparts(xlsxPath);
    lockPath = fullfile(folder, ['~$', name, ext]);
    locked = exist(lockPath, 'file') == 2;
end

function T = toStringTable(T)
    columnNames = T.Properties.VariableNames;
    for i = 1:numel(columnNames)
        T.(columnNames{i}) = string(T.(columnNames{i}));
    end
end

function columnWidths = readExcelColumnWidths(xlsxPath, nCols)
    defaultWidthPx = 100;
    columnWidths = num2cell(repmat(defaultWidthPx, 1, nCols));
    if isempty(xlsxPath) || exist(xlsxPath, 'file') ~= 2
        return
    end
    tmpDir = tempname;
    mkdir(tmpDir);
    try
        unzip(xlsxPath, tmpDir);
        sheetFile = fullfile(tmpDir, 'xl', 'worksheets', 'sheet1.xml');
        if exist(sheetFile, 'file') ~= 2
            rmdir(tmpDir, 's');
            return
        end
        xmlText = fileread(sheetFile);
        colTags = regexp(xmlText, '<col\s[^>]*/?>', 'match');
        excelWidths = nan(1, nCols);
        for i = 1:numel(colTags)
            tag = colTags{i};
            minTok = regexp(tag, 'min="(\d+)"', 'tokens', 'once');
            maxTok = regexp(tag, 'max="(\d+)"', 'tokens', 'once');
            widthTok = regexp(tag, 'width="([0-9.]+)"', 'tokens', 'once');
            if isempty(minTok) || isempty(maxTok) || isempty(widthTok)
                continue
            end
            colMin = str2double(minTok{1});
            colMax = str2double(maxTok{1});
            colWidth = str2double(widthTok{1});
            idx = colMin:min(colMax, nCols);
            excelWidths(idx) = colWidth;
        end
        for c = 1:nCols
            w = excelWidths(c);
            if isnan(w)
                w = 8.43;
            end
            columnWidths{c} = max(40, round(w * 7 + 5));
        end
        rmdir(tmpDir, 's');
    catch
        if exist(tmpDir, 'dir')
            rmdir(tmpDir, 's');
        end
    end
end

function writeExcelColumnWidths(xlsxPath, columnWidths)
    if isempty(xlsxPath) || exist(xlsxPath, 'file') ~= 2 || isempty(columnWidths)
        return
    end
    tmpDir = tempname;
    mkdir(tmpDir);
    try
        unzip(xlsxPath, tmpDir);
        sheetFile = fullfile(tmpDir, 'xl', 'worksheets', 'sheet1.xml');
        if exist(sheetFile, 'file') ~= 2
            rmdir(tmpDir, 's');
            return
        end
        xmlText = fileread(sheetFile);
        xmlText = regexprep(xmlText, '<cols>[\s\S]*?</cols>', '');
        nCols = numel(columnWidths);
        colParts = cell(1, nCols);
        for c = 1:nCols
            px = columnWidths{c};
            if ~(isnumeric(px) && isfinite(px))
                px = 100;
            end
            excelWidth = max(1, (px - 5) / 7);
            colParts{c} = sprintf('<col min="%d" max="%d" width="%.4f" customWidth="1"/>', c, c, excelWidth);
        end
        colsXml = ['<cols>', colParts{:}, '</cols>'];
        xmlText = regexprep(xmlText, '<sheetData', [colsXml, '<sheetData'], 'once');
        fid = fopen(sheetFile, 'w');
        fwrite(fid, xmlText, 'char');
        fclose(fid);
        packXlsxFromDir(tmpDir, xlsxPath);
        rmdir(tmpDir, 's');
    catch
        if exist(tmpDir, 'dir')
            rmdir(tmpDir, 's');
        end
    end
end

function packXlsxFromDir(tmpDir, xlsxPath)
    zipPath = [tempname, '.zip'];
    entries = dir(tmpDir);
    names = {entries(~ismember({entries.name}, {'.', '..'})).name};
    oldPwd = pwd;
    cd(tmpDir);
    try
        zip(zipPath, names);
        cd(oldPwd);
    catch ME
        cd(oldPwd);
        rethrow(ME);
    end
    copyfile(zipPath, xlsxPath, 'f');
    delete(zipPath);
end

function launchFile(filePath)
    [~, ~, ext] = fileparts(filePath);
    switch lower(ext)
        case {'.ev', '.mat', '.abf'}
            signalViewerGUI(filePath);
        otherwise
            winopen(filePath);
    end
end
