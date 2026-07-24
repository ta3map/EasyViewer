function convertToZavGUI(formatKey)
    global SettingsFilepath zav_calling import_settings

    formatKey = lower(string(formatKey));
    if ~(formatKey == "abf" || formatKey == "nlx" || formatKey == "oep")
        error('Unsupported format key: %s', formatKey);
    end

    figTag = ['convertToZavGUI_' char(formatKey)];
    guiFig = findobj('Type', 'figure', 'Tag', figTag);
    if ~isempty(guiFig)
        figure(guiFig);
        return;
    end

    cfg = getFormatConfig(formatKey);
    queueSettingsKey = char(formatKey);
    queueData = struct('items', [], 'lastSelectedItemId', '', 'nextId', 1);
    selectedItemIdx = 0;
    active_folder = userpath;

    mua_std_coef = cfg.defaultMuaStdCoef;
    lfp_Fs = cfg.defaultNewFs;
    detectMua = cfg.defaultDetectMua;
    doResample = cfg.defaultDoResample;
    queueRunStartedAt = [];
    lastProgressSaveTic = [];

    loadInitialState();

    fig = figure('Name', cfg.windowTitle, 'Position', [60, 60, 1200, 700], 'NumberTitle', 'off', ...
        'MenuBar', 'none', 'ToolBar', 'none', 'Resize', 'off', 'Tag', figTag);

    uicontrol('Parent', fig, 'Style', 'text', 'String', 'Sources queue', ...
        'Position', [20, 655, 260, 22], 'HorizontalAlignment', 'left', 'FontWeight', 'bold');

    sourceList = uicontrol('Parent', fig, 'Style', 'listbox', 'String', {'(queue is empty)'}, ...
        'Position', [20, 210, 420, 440], 'Callback', @sourceSelectionChanged);

    uicontrol('Parent', fig, 'Style', 'pushbutton', 'String', cfg.selectButtonText, ...
        'Position', [20, 170, 200, 30], 'Callback', @addSource);

    uicontrol('Parent', fig, 'Style', 'pushbutton', 'String', 'Reset status', ...
        'Position', [240, 170, 200, 30], 'Callback', @clearStatus);

    uicontrol('Parent', fig, 'Style', 'pushbutton', 'String', 'Clear queue', ...
        'Position', [20, 106, 420, 30], 'Callback', @clearQueue);

    itemStatusLabel = uicontrol('Parent', fig, 'Style', 'text', 'String', 'Status: -', ...
        'Position', [20, 140, 420, 22], 'HorizontalAlignment', 'left');

    queueProgressLabel = uicontrol('Parent', fig, 'Style', 'text', 'String', 'Progress: 0/0 done', ...
        'Position', [20, 82, 420, 22], 'HorizontalAlignment', 'left');

    sourceNameLabel = uicontrol('Parent', fig, 'Style', 'text', 'String', 'Source: -', ...
        'Position', [470, 655, 700, 22], 'HorizontalAlignment', 'left', 'FontWeight', 'bold');

    FsOrigLabel = uicontrol('Parent', fig, 'Style', 'text', 'String', 'Fs (Hz): -', ...
        'Position', [470, 630, 400, 22], 'HorizontalAlignment', 'left');

    channelPanel = uipanel('Parent', fig, 'Title', 'Channels', 'Position', [0.39, 0.28, 0.58, 0.58]);

    uicontrol('Parent', channelPanel, 'Style', 'pushbutton', 'String', 'Select All', ...
        'Units', 'normalized', 'Position', [0.02, 0.92, 0.13, 0.06], 'Callback', @selectAllChannels);
    uicontrol('Parent', channelPanel, 'Style', 'pushbutton', 'String', 'Deselect All', ...
        'Units', 'normalized', 'Position', [0.16, 0.92, 0.13, 0.06], 'Callback', @deselectAllChannels);
    if cfg.hasDeselectEmpty
        uicontrol('Parent', channelPanel, 'Style', 'pushbutton', 'String', 'Deselect empty channels', ...
            'Units', 'normalized', 'Position', [0.30, 0.92, 0.22, 0.06], 'Callback', @deselectEmptyChannels);
    end

    channelTable = uitable('Parent', channelPanel, 'Data', {}, 'ColumnName', {'Use', 'Channel Name'}, ...
        'ColumnEditable', [true, false], 'Units', 'normalized', 'Position', [0, 0, 1, 0.92], ...
        'CellEditCallback', @channelSelectionCallback);

    uicontrol('Parent', fig, 'Style', 'text', 'String', 'Output file:', ...
        'Position', [470, 178, 120, 22], 'HorizontalAlignment', 'left');
    outputPathEdit = uicontrol('Parent', fig, 'Style', 'edit', 'String', '-', ...
        'Position', [560, 176, 610, 26], 'HorizontalAlignment', 'left', 'Callback', @outputPathEditCallback);
    uicontrol('Parent', fig, 'Style', 'pushbutton', 'String', 'Change output...', ...
        'Position', [470, 145, 160, 28], 'Callback', @changeOutputPath);

    uicontrol('Parent', fig, 'Style', 'checkbox', 'String', 'Detect MUA', ...
        'Position', [470, 100, 120, 24], 'Value', detectMua, 'Callback', @detectMuaCallback);
    uicontrol('Parent', fig, 'Style', 'text', 'String', 'MUA Threshold (n*STD):', ...
        'Position', [600, 100, 160, 22], 'HorizontalAlignment', 'right');
    muaCoefUI = uicontrol('Parent', fig, 'Style', 'edit', 'String', num2str(mua_std_coef), ...
        'Position', [770, 100, 70, 24], 'Callback', @muaCoefUICallback);

    uicontrol('Parent', fig, 'Style', 'text', 'String', 'New Fs (Hz):', ...
        'Position', [850, 100, 100, 22], 'HorizontalAlignment', 'right');
    lfpFsUI = uicontrol('Parent', fig, 'Style', 'edit', 'String', num2str(lfp_Fs), ...
        'Position', [960, 100, 70, 24], 'Callback', @lfpFsUICallback);

    uicontrol('Parent', fig, 'Style', 'checkbox', 'String', 'Resample LFP', ...
        'Position', [1040, 100, 120, 24], 'Value', doResample, 'Callback', @doResampleCallback);

    openSelectedBtn = uicontrol('Parent', fig, 'Style', 'pushbutton', 'String', 'Open selected', ...
        'Position', [470, 48, 180, 36], 'Enable', 'off', 'Callback', @openSelected);
    uicontrol('Parent', fig, 'Style', 'pushbutton', 'String', 'Start Conversion', ...
        'Position', [990, 48, 180, 36], 'Callback', @startConversion);

    refreshQueueList();
    restoreSelectedItem();
    refreshQueueProgressLabel();

    function cfgOut = getFormatConfig(key)
        cfgOut = struct();
        switch key
            case "abf"
                cfgOut.windowTitle = 'Convert ABF to ZAV';
                cfgOut.selectButtonText = 'Select ABF File';
                cfgOut.emptySourceLabel = 'No file selected';
                cfgOut.sourceType = "file";
                cfgOut.defaultMuaStdCoef = 1;
                cfgOut.defaultNewFs = 1000;
                cfgOut.defaultDetectMua = false;
                cfgOut.defaultDoResample = true;
                cfgOut.hasDeselectEmpty = false;
            case "nlx"
                cfgOut.windowTitle = 'Convert Neuralynx to ZAV';
                cfgOut.selectButtonText = 'Select Neuralynx Folder';
                cfgOut.emptySourceLabel = 'No folder selected';
                cfgOut.sourceType = "folder";
                cfgOut.defaultMuaStdCoef = 3;
                cfgOut.defaultNewFs = 1000;
                cfgOut.defaultDetectMua = false;
                cfgOut.defaultDoResample = true;
                cfgOut.hasDeselectEmpty = true;
            case "oep"
                cfgOut.windowTitle = 'Convert OEP to ZAV';
                cfgOut.selectButtonText = 'Select OEP Folder';
                cfgOut.emptySourceLabel = 'No folder selected';
                cfgOut.sourceType = "folder";
                cfgOut.defaultMuaStdCoef = 3;
                cfgOut.defaultNewFs = 1000;
                cfgOut.defaultDetectMua = true;
                cfgOut.defaultDoResample = true;
                cfgOut.hasDeselectEmpty = false;
        end
    end

    function loadInitialState()
        try
            d = load(SettingsFilepath);
            if isfield(d, 'lastOpenedFolders') && ~isempty(d.lastOpenedFolders)
                active_folder = d.lastOpenedFolders{end};
            elseif isfield(d, 'lastOpenedFiles') && ~isempty(d.lastOpenedFiles)
                active_folder = fileparts(d.lastOpenedFiles{end});
            end
        catch
        end

        if isfield(import_settings, 'convert_queue') && isfield(import_settings.convert_queue, queueSettingsKey)
            queueData = import_settings.convert_queue.(queueSettingsKey);
            if ~isfield(queueData, 'nextId')
                queueData.nextId = numel(queueData.items) + 1;
            end
            if ~isfield(queueData, 'lastSelectedItemId')
                queueData.lastSelectedItemId = '';
            end
            if isfield(queueData, 'items')
                for i = 1:numel(queueData.items)
                    if ~isfield(queueData.items(i), 'itemWeightBytes') || isempty(queueData.items(i).itemWeightBytes)
                        queueData.items(i).itemWeightBytes = 1;
                    end
                    if ~isfield(queueData.items(i), 'progress') || isempty(queueData.items(i).progress)
                        queueData.items(i).progress = 0;
                    end
                end
            end
        end

        if formatKey == "abf" && isfield(import_settings, 'abf2zav')
            settings = import_settings.abf2zav;
            if isfield(settings, 'doResample')
                doResample = settings.doResample;
            end
        end
    end

    function saveQueueState()
        if ~isfield(import_settings, 'convert_queue')
            import_settings.convert_queue = struct();
        end
        import_settings.convert_queue.(queueSettingsKey) = queueData;
        save(SettingsFilepath, 'import_settings', '-append');
    end

    function saveAbfImportSettings(item)
        if formatKey ~= "abf"
            return;
        end
        if ~isfield(import_settings, 'abf2zav')
            import_settings.abf2zav = struct();
        end
        import_settings.abf2zav.filePath = item.sourcePath;
        import_settings.abf2zav.doResample = doResample;
        import_settings.abf2zav.selectedChannels = item.selectedChannels;
        save(SettingsFilepath, 'import_settings', '-append');
    end

    function addSource(~, ~)
        [sourcePath, cancelled] = pickSource();
        if cancelled
            return;
        end
        [item, err] = buildQueueItem(sourcePath);
        if ~isempty(err)
            warndlg(err, 'Source error');
            return;
        end
        queueData.items = [queueData.items; item];
        queueData.lastSelectedItemId = item.id;
        queueData.nextId = queueData.nextId + 1;
        saveQueueState();
        refreshQueueList();
        selectQueueItemById(item.id);
    end

    function [sourcePath, cancelled] = pickSource()
        sourcePath = '';
        cancelled = false;
        if cfg.sourceType == "file"
            [file, path] = uigetfile('*.abf', 'Select ABF File', active_folder);
            if isequal(file, 0)
                cancelled = true;
                return;
            end
            sourcePath = fullfile(path, file);
            active_folder = path;
            return;
        end
        if formatKey == "nlx"
            selectedFolder = uigetdir(active_folder, 'Select Neuralynx Folder');
        else
            selectedFolder = uigetdir(active_folder, 'Select OpenEphys Folder');
        end
        if isequal(selectedFolder, 0)
            cancelled = true;
            return;
        end
        sourcePath = selectedFolder;
        active_folder = selectedFolder;
    end

    function [item, err] = buildQueueItem(sourcePath)
        item = struct();
        err = '';
        [channels, sourceFs, meta, err] = readSourceMetadata(sourcePath);
        if ~isempty(err)
            return;
        end
        selectedChannels = channels;
        outputPath = buildDefaultOutputName(sourcePath);
        if formatKey == "abf" && isfield(import_settings, 'abf2zav') && isfield(import_settings.abf2zav, 'selectedChannels')
            saved = import_settings.abf2zav.selectedChannels;
            if ~isempty(saved)
                selectedChannels = intersect(channels, saved, 'stable');
                if isempty(selectedChannels)
                    selectedChannels = channels;
                end
            end
        end
        item.id = sprintf('%s_%d', char(formatKey), queueData.nextId);
        item.sourcePath = sourcePath;
        item.sourceType = char(cfg.sourceType);
        item.displayName = getSourceDisplayName(sourcePath);
        item.status = 'pending';
        item.errorMessage = '';
        item.outputPath = outputPath;
        item.availableChannels = channels;
        item.selectedChannels = selectedChannels;
        item.sourceFs = sourceFs;
        item.formatMeta = meta;
        item.progress = 0;
        item.itemWeightBytes = estimateSourceWeightBytes(sourcePath, meta);
    end

    function itemWeightBytes = estimateSourceWeightBytes(sourcePath, meta)
        itemWeightBytes = 1;
        switch formatKey
            case "abf"
                fileInfo = dir(sourcePath);
                if ~isempty(fileInfo)
                    itemWeightBytes = max(fileInfo(1).bytes, 1);
                end
            case "nlx"
                if isfield(meta, 'channelBytes') && ~isempty(meta.channelBytes)
                    itemWeightBytes = max(sum(meta.channelBytes), 1);
                end
            case "oep"
                continuousFiles = collectContinuousDatFiles(sourcePath);
                if ~isempty(continuousFiles)
                    totalBytes = 0;
                    for i = 1:numel(continuousFiles)
                        totalBytes = totalBytes + continuousFiles(i).bytes;
                    end
                    itemWeightBytes = max(totalBytes, 1);
                end
        end
    end

    function files = collectContinuousDatFiles(rootPath)
        files = struct('folder', {}, 'name', {}, 'bytes', {}, 'date', {}, 'datenum', {}, 'isdir', {});
        stack = {rootPath};
        while ~isempty(stack)
            currentPath = stack{end};
            stack(end) = [];
            dirEntries = dir(currentPath);
            for i = 1:numel(dirEntries)
                entry = dirEntries(i);
                if entry.isdir
                    if strcmp(entry.name, '.') || strcmp(entry.name, '..')
                        continue;
                    end
                    stack{end + 1} = fullfile(currentPath, entry.name);
                    continue;
                end
                if strcmpi(entry.name, 'continuous.dat')
                    files(end + 1) = entry; %#ok<AGROW>
                end
            end
        end
    end

    function [channels, sourceFs, meta, err] = readSourceMetadata(sourcePath)
        channels = {};
        sourceFs = [];
        meta = struct();
        err = '';
        try
            switch formatKey
                case "abf"
                    [~, ~, hd_abf] = abfload(sourcePath, 'stop', 1, 'doDispInfo', false);
                    channels = hd_abf.recChNames;
                    sourceFs = 1e6 / hd_abf.si;
                case "oep"
                    metadataTable = readOpenEphysMetadata(sourcePath);
                    if isempty(metadataTable)
                        err = 'OpenEphys metadata is empty';
                        return;
                    end
                    channels = metadataTable.Channel_Names{1}';
                    sourceFs = metadataTable.Sample_Rate{1};
                case "nlx"
                    folderPath = sourcePath;
                    if folderPath(end) ~= '\'
                        folderPath(end + 1) = '\';
                    end
                    dirCnt = dir(folderPath);
                    ncsFiles = struct('f', {}, 'chNum', {}, 'chName', {}, 'bytes', {});
                    for t = 1:length(dirCnt)
                        if ((~dirCnt(t).isdir) && (length(dirCnt(t).name) > 3))
                            if isequal(dirCnt(t).name(end - 3:end), '.ncs')
                                fileName = dirCnt(t).name(1:end-4);
                                numMatch = regexp(fileName, '\d+$', 'match');
                                if ~isempty(numMatch)
                                    ch = str2double(numMatch{1});
                                    if ~isnan(ch)
                                        ncsFiles(end + 1).f = fullfile(folderPath, dirCnt(t).name);
                                        ncsFiles(end).chNum = ch;
                                        ncsFiles(end).chName = fileName;
                                        ncsFiles(end).bytes = dirCnt(t).bytes;
                                    end
                                end
                            end
                        end
                    end
                    [~, sortIdx] = sort([ncsFiles.chNum]);
                    ncsFiles = ncsFiles(sortIdx);
                    if isempty(ncsFiles)
                        err = 'No .ncs files found in selected folder';
                        return;
                    end
                    channels = {ncsFiles.chName}';
                    meta.channelNumbers = [ncsFiles.chNum]';
                    meta.channelFilePaths = {ncsFiles.f}';
                    meta.channelBytes = [ncsFiles.bytes]';
                    cscHd = Nlx2MatCSC(ncsFiles(1).f, [0 0 0 0 0], 1, 1, []);
                    sourceFs = NlxParametr(cscHd, 'SamplingFrequency');
            end
        catch ME
            err = ME.message;
        end
    end

    function refreshQueueList()
        if isempty(queueData.items)
            set(sourceList, 'String', {'(queue is empty)'}, 'Value', 1);
            selectedItemIdx = 0;
            renderSelectedItem();
            return;
        end
        labels = cell(numel(queueData.items), 1);
        for i = 1:numel(queueData.items)
            it = queueData.items(i);
            labels{i} = sprintf('[%s] %s', upper(it.status), it.displayName);
        end
        if selectedItemIdx < 1 || selectedItemIdx > numel(queueData.items)
            selectedItemIdx = 1;
        end
        set(sourceList, 'String', labels, 'Value', selectedItemIdx);
        renderSelectedItem();
    end

    function restoreSelectedItem()
        if isempty(queueData.items)
            return;
        end
        selectedItemIdx = 1;
        if ~isempty(queueData.lastSelectedItemId)
            for i = 1:numel(queueData.items)
                if strcmp(queueData.items(i).id, queueData.lastSelectedItemId)
                    selectedItemIdx = i;
                end
            end
        end
        set(sourceList, 'Value', selectedItemIdx);
        renderSelectedItem();
    end

    function sourceSelectionChanged(~, ~)
        if isempty(queueData.items)
            selectedItemIdx = 0;
            renderSelectedItem();
            return;
        end
        selectedItemIdx = get(sourceList, 'Value');
        queueData.lastSelectedItemId = queueData.items(selectedItemIdx).id;
        saveQueueState();
        renderSelectedItem();
    end

    function selectQueueItemById(itemId)
        for i = 1:numel(queueData.items)
            if strcmp(queueData.items(i).id, itemId)
                selectedItemIdx = i;
                set(sourceList, 'Value', i);
                renderSelectedItem();
                return;
            end
        end
    end

    function renderSelectedItem()
        if selectedItemIdx < 1 || selectedItemIdx > numel(queueData.items)
            set(sourceNameLabel, 'String', 'Source: -');
            set(FsOrigLabel, 'String', 'Fs (Hz): -');
            set(outputPathEdit, 'String', '-');
            set(itemStatusLabel, 'String', 'Status: -');
            set(channelTable, 'Data', {});
            set(channelPanel, 'Title', 'Channels');
            set(openSelectedBtn, 'Enable', 'off');
            return;
        end
        item = queueData.items(selectedItemIdx);
        set(sourceNameLabel, 'String', ['Source: ' item.sourcePath]);
        if ~isempty(item.sourceFs)
            set(FsOrigLabel, 'String', ['Fs (Hz): ' num2str(item.sourceFs)]);
        else
            set(FsOrigLabel, 'String', 'Fs (Hz): N/A');
        end
        set(outputPathEdit, 'String', item.outputPath);
        statusText = ['Status: ' upper(item.status)];
        if ~isempty(item.errorMessage)
            statusText = [statusText ' | ' item.errorMessage];
        end
        set(itemStatusLabel, 'String', statusText);
        set(channelPanel, 'Title', ['Channels - ' item.displayName]);
        if strcmp(item.status, 'done')
            set(openSelectedBtn, 'Enable', 'on');
        else
            set(openSelectedBtn, 'Enable', 'off');
        end

        channelData = cell(numel(item.availableChannels), 2);
        for i = 1:numel(item.availableChannels)
            channelData{i, 1} = any(strcmp(item.availableChannels{i}, item.selectedChannels));
            channelData{i, 2} = item.availableChannels{i};
        end
        set(channelTable, 'Data', channelData);
    end

    function clearQueue(~, ~)
        choice = questdlg('Clear all sources from queue?', 'Confirm clear queue', 'Yes', 'No', 'No');
        if ~strcmp(choice, 'Yes')
            return;
        end
        queueData.items = [];
        queueData.lastSelectedItemId = '';
        saveQueueState();
        refreshQueueList();
        refreshQueueProgressLabel();
    end

    function clearStatus(~, ~)
        if isempty(queueData.items) || selectedItemIdx < 1 || selectedItemIdx > numel(queueData.items)
            return;
        end
        queueData.items(selectedItemIdx).status = 'pending';
        queueData.items(selectedItemIdx).errorMessage = '';
        queueData.items(selectedItemIdx).progress = 0;
        saveQueueState();
        refreshQueueList();
        set(sourceList, 'Value', selectedItemIdx);
        refreshQueueProgressLabel();
    end

    function refreshQueueProgressLabel()
        total = numel(queueData.items);
        doneCount = 0;
        failedCount = 0;
        [overallProgress, etaText] = calculateOverallProgressAndEta();
        for i = 1:total
            if strcmp(queueData.items(i).status, 'done')
                doneCount = doneCount + 1;
            end
            if strcmp(queueData.items(i).status, 'failed')
                failedCount = failedCount + 1;
            end
        end
        set(queueProgressLabel, 'String', sprintf('Progress: %d/%d done, %d failed, %.1f%%%s', ...
            doneCount, total, failedCount, overallProgress * 100, etaText));
    end

    function [overallProgress, etaText] = calculateOverallProgressAndEta()
        totalWeight = 0;
        completedWeight = 0;
        runningContribution = 0;
        for i = 1:numel(queueData.items)
            itemWeight = 1;
            if isfield(queueData.items(i), 'itemWeightBytes') && ~isempty(queueData.items(i).itemWeightBytes)
                itemWeight = max(queueData.items(i).itemWeightBytes, 1);
            end
            totalWeight = totalWeight + itemWeight;
            if strcmp(queueData.items(i).status, 'done')
                completedWeight = completedWeight + itemWeight;
            end
            if strcmp(queueData.items(i).status, 'running')
                runningContribution = runningContribution + itemWeight * min(max(queueData.items(i).progress, 0), 1);
            end
        end
        totalWeight = max(totalWeight, 1);
        overallProgress = min(max((completedWeight + runningContribution) / totalWeight, 0), 1);

        etaText = '';
        if ~isempty(queueRunStartedAt) && overallProgress > 0 && overallProgress < 1
            elapsedSec = toc(queueRunStartedAt);
            etaSec = elapsedSec * (1 - overallProgress) / max(overallProgress, eps);
            etaText = sprintf('~%d min %d s', floor(etaSec / 60), round(rem(etaSec, 60)));
        end
    end

    function channelSelectionCallback(src, ~)
        if selectedItemIdx < 1 || selectedItemIdx > numel(queueData.items)
            return;
        end
        channelData = get(src, 'Data');
        selectedChannelIndices = find([channelData{:, 1}]);
        queueData.items(selectedItemIdx).selectedChannels = queueData.items(selectedItemIdx).availableChannels(selectedChannelIndices);
        if strcmp(queueData.items(selectedItemIdx).status, 'done')
            queueData.items(selectedItemIdx).status = 'pending';
            queueData.items(selectedItemIdx).progress = 0;
        end
        saveQueueState();
        if formatKey == "abf"
            saveAbfImportSettings(queueData.items(selectedItemIdx));
        end
        refreshQueueList();
        set(sourceList, 'Value', selectedItemIdx);
    end

    function selectAllChannels(~, ~)
        if selectedItemIdx < 1 || selectedItemIdx > numel(queueData.items)
            return;
        end
        channelData = get(channelTable, 'Data');
        if isempty(channelData)
            return;
        end
        for i = 1:size(channelData, 1)
            channelData{i, 1} = true;
        end
        set(channelTable, 'Data', channelData);
        queueData.items(selectedItemIdx).selectedChannels = queueData.items(selectedItemIdx).availableChannels;
        saveQueueState();
    end

    function deselectAllChannels(~, ~)
        if selectedItemIdx < 1 || selectedItemIdx > numel(queueData.items)
            return;
        end
        channelData = get(channelTable, 'Data');
        if isempty(channelData)
            return;
        end
        for i = 1:size(channelData, 1)
            channelData{i, 1} = false;
        end
        set(channelTable, 'Data', channelData);
        queueData.items(selectedItemIdx).selectedChannels = {};
        saveQueueState();
    end

    function deselectEmptyChannels(~, ~)
        if formatKey ~= "nlx" || selectedItemIdx < 1 || selectedItemIdx > numel(queueData.items)
            return;
        end
        if ~isfield(queueData.items(selectedItemIdx).formatMeta, 'channelBytes')
            return;
        end
        channelBytes = queueData.items(selectedItemIdx).formatMeta.channelBytes;
        channelData = get(channelTable, 'Data');
        if isempty(channelData)
            return;
        end
        emptyThreshold = 16 * 1024;
        for i = 1:min(size(channelData, 1), numel(channelBytes))
            if channelBytes(i) <= emptyThreshold
                channelData{i, 1} = false;
            end
        end
        set(channelTable, 'Data', channelData);
        selectedChannelIndices = find([channelData{:, 1}]);
        queueData.items(selectedItemIdx).selectedChannels = queueData.items(selectedItemIdx).availableChannels(selectedChannelIndices);
        saveQueueState();
    end

    function detectMuaCallback(source, ~)
        detectMua = get(source, 'Value');
    end

    function openSelected(~, ~)
        if selectedItemIdx < 1 || selectedItemIdx > numel(queueData.items)
            return;
        end
        item = queueData.items(selectedItemIdx);
        if ~strcmp(item.status, 'done')
            return;
        end
        zav_calling(item.outputPath);
    end

    function muaCoefUICallback(source, ~)
        mua_std_coef = str2double(get(source, 'String'));
        if isnan(mua_std_coef) || mua_std_coef <= 0
            warndlg('Please enter a valid positive number for MUA threshold.', 'Invalid Input');
            set(source, 'String', num2str(cfg.defaultMuaStdCoef));
            mua_std_coef = cfg.defaultMuaStdCoef;
        end
    end

    function lfpFsUICallback(source, ~)
        lfp_Fs = str2double(get(source, 'String'));
        if isnan(lfp_Fs) || lfp_Fs <= 0
            warndlg('Please enter a valid positive number for LFP Fs.', 'Invalid Input');
            set(source, 'String', num2str(cfg.defaultNewFs));
            lfp_Fs = cfg.defaultNewFs;
        end
    end

    function doResampleCallback(source, ~)
        doResample = get(source, 'Value');
    end

    function changeOutputPath(~, ~)
        if selectedItemIdx < 1 || selectedItemIdx > numel(queueData.items)
            return;
        end
        item = queueData.items(selectedItemIdx);
        [file, path] = uiputfile('*.mat', 'Save ZAV File As', item.outputPath);
        if isequal(file, 0)
            return;
        end
        queueData.items(selectedItemIdx).outputPath = fullfile(path, file);
        if strcmp(queueData.items(selectedItemIdx).status, 'done')
            queueData.items(selectedItemIdx).status = 'pending';
            queueData.items(selectedItemIdx).progress = 0;
        end
        active_folder = path;
        saveQueueState();
        renderSelectedItem();
        refreshQueueList();
        set(sourceList, 'Value', selectedItemIdx);
    end

    function outputPathEditCallback(source, ~)
        if selectedItemIdx < 1 || selectedItemIdx > numel(queueData.items)
            set(source, 'String', '-');
            return;
        end
        newPath = strtrim(get(source, 'String'));
        if isempty(newPath)
            set(source, 'String', queueData.items(selectedItemIdx).outputPath);
            return;
        end
        queueData.items(selectedItemIdx).outputPath = newPath;
        if strcmp(queueData.items(selectedItemIdx).status, 'done')
            queueData.items(selectedItemIdx).status = 'pending';
            queueData.items(selectedItemIdx).progress = 0;
        end
        saveQueueState();
        refreshQueueList();
        set(sourceList, 'Value', selectedItemIdx);
    end

    function startConversion(~, ~)
        if isempty(queueData.items)
            warndlg('Queue is empty.', 'No Sources');
            return;
        end

        queueRunStartedAt = tic;
        lastProgressSaveTic = tic;
        lastOpenedZav = '';
        for i = 1:numel(queueData.items)
            if ~(strcmp(queueData.items(i).status, 'pending') || strcmp(queueData.items(i).status, 'failed'))
                continue;
            end
            if isempty(queueData.items(i).selectedChannels)
                queueData.items(i).status = 'failed';
                queueData.items(i).errorMessage = 'No channels selected';
                queueData.items(i).progress = 0;
                saveQueueState();
                continue;
            end

            queueData.items(i).status = 'running';
            queueData.items(i).errorMessage = '';
            queueData.items(i).progress = 0;
            queueData.lastSelectedItemId = queueData.items(i).id;
            saveQueueState();
            refreshQueueList();
            selectQueueItemById(queueData.items(i).id);
            refreshQueueProgressLabel();

            hWaitBar = createCancelableWaitbar(0, sprintf('Converting %d/%d...', i, numel(queueData.items)), cfg.windowTitle);
            try
                runItemConversion(i, hWaitBar);
                queueData.items(i).status = 'done';
                queueData.items(i).progress = 1;
                queueData.items(i).errorMessage = '';
                lastOpenedZav = queueData.items(i).outputPath;
            catch ME
                queueData.items(i).status = 'failed';
                queueData.items(i).progress = 0;
                if strcmp(ME.identifier, 'EasyViewer:UserCancel')
                    queueData.items(i).errorMessage = 'Stopped by user';
                else
                    queueData.items(i).errorMessage = ME.message;
                end
            end
            if exist('hWaitBar', 'var')
                deleteCancelableWaitbar(hWaitBar);
            end
            saveQueueState();
            if strcmp(queueData.items(i).status, 'done')
                savePostActionsForItem(i);
            end
            refreshQueueList();
            refreshQueueProgressLabel();
            if strcmp(queueData.items(i).errorMessage, 'Stopped by user')
                break;
            end
        end

        renderSelectedItem();
    end

    function outputName = buildDefaultOutputName(sourcePath)
        if formatKey == "abf"
            [~, sourceName, ~] = fileparts(sourcePath);
            outputName = fullfile(active_folder, [sourceName, '_converted.mat']);
            return;
        end
        sourcePathClean = sourcePath;
        if sourcePathClean(end) == '\' || sourcePathClean(end) == '/'
            sourcePathClean = sourcePathClean(1:end-1);
        end
        [~, folderName, ~] = fileparts(sourcePathClean);
        if formatKey == "nlx"
            outputName = fullfile(fileparts(sourcePathClean), [folderName, '.mat']);
            return;
        end
        outputName = fullfile(active_folder, [folderName, '.mat']);
    end

    function runItemConversion(itemIdx, hWaitBar)
        item = queueData.items(itemIdx);
        selectedChannelIndices = find(ismember(item.availableChannels, item.selectedChannels));
        outputPath = item.outputPath;
        progressCallback = @(progressStruct)handleBackendProgress(itemIdx, progressStruct, hWaitBar);

        switch formatKey
            case "abf"
                collectSweeps = true;
                abf_to_zav(item.sourcePath, outputPath, lfp_Fs, detectMua, doResample, collectSweeps, item.selectedChannels, mua_std_coef, hWaitBar, progressCallback);
            case "oep"
                oep_to_zav_streaming(item.sourcePath, outputPath, item.sourceFs, lfp_Fs, detectMua, mua_std_coef, doResample, item.availableChannels, selectedChannelIndices, hWaitBar, progressCallback);
            case "nlx"
                channels_list = item.formatMeta.channelNumbers(selectedChannelIndices);
                ncsFilePaths = item.formatMeta.channelFilePaths(selectedChannelIndices);
                nlx_to_zav_streaming(item.sourcePath, outputPath, channels_list, ncsFilePaths, lfp_Fs, detectMua, mua_std_coef, doResample, hWaitBar, progressCallback);
        end
    end

    function handleBackendProgress(itemIdx, progressStruct, hWaitBar)
        if itemIdx < 1 || itemIdx > numel(queueData.items)
            return;
        end
        if ~isfield(progressStruct, 'itemProgress')
            return;
        end
        queueData.items(itemIdx).progress = min(max(progressStruct.itemProgress, 0), 1);
        [overallProgress, etaText] = calculateOverallProgressAndEta();
        assertWaitbarNotCanceled(hWaitBar);
        if isgraphics(hWaitBar)
            backendMessage = '';
            if isfield(progressStruct, 'message') && ~isempty(progressStruct.message)
                backendMessage = progressStruct.message;
            elseif isfield(progressStruct, 'stage') && ~isempty(progressStruct.stage)
                backendMessage = progressStruct.stage;
            end

            if isempty(backendMessage)
                if isempty(etaText)
                    waitbar(queueData.items(itemIdx).progress, hWaitBar, '...');
                else
                    waitbar(queueData.items(itemIdx).progress, hWaitBar, etaText);
                end
            else
                % Replace only local ETA tail from backend text.
                messageNoLocalEta = regexprep(backendMessage, '\s*~\d+\s*min\s*\d+\s*s\s*left\s*$', '');
                if isempty(etaText)
                    waitbar(queueData.items(itemIdx).progress, hWaitBar, strtrim(messageNoLocalEta));
                else
                    waitbar(queueData.items(itemIdx).progress, hWaitBar, ...
                        sprintf('%s %s (%.1f%%)', strtrim(messageNoLocalEta), etaText, overallProgress * 100));
                end
            end
        end
        assertWaitbarNotCanceled(hWaitBar);
        refreshQueueProgressLabel();
        renderSelectedItem();
        if isempty(lastProgressSaveTic)
            lastProgressSaveTic = tic;
        end
        if toc(lastProgressSaveTic) >= 1 || queueData.items(itemIdx).progress >= 1
            saveQueueState();
            lastProgressSaveTic = tic;
        end
    end

    function savePostActionsForItem(itemIdx)
        item = queueData.items(itemIdx);
        if formatKey == "abf"
            lastOpenedFiles = {item.outputPath};
            save(SettingsFilepath, 'lastOpenedFiles', '-append');
            saveAbfImportSettings(item);
            return;
        end

        lastOpenedFolders = {item.sourcePath};
        if exist(SettingsFilepath, 'file')
            save(SettingsFilepath, 'lastOpenedFolders', '-append');
        else
            save(SettingsFilepath, 'lastOpenedFolders');
        end

        if formatKey == "nlx"
            lastOpenedFiles = {item.outputPath};
            save(SettingsFilepath, 'lastOpenedFiles', '-append');
        end
    end

    function name = getSourceDisplayName(sourcePath)
        [~, name, ext] = fileparts(sourcePath);
        if cfg.sourceType == "file"
            name = [name ext];
        end
    end
end
