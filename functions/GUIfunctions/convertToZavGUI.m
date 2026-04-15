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

    sourcePath = '';
    zavFilePath = '';
    active_folder = userpath;
    availableChannels = {};
    selectedChannels = {};
    channelNumbers = [];
    channelFilePaths = {};
    channelBytes = [];
    sourceFs = [];

    mua_std_coef = cfg.defaultMuaStdCoef;
    lfp_Fs = cfg.defaultNewFs;
    detectMua = cfg.defaultDetectMua;
    doResample = cfg.defaultDoResample;
    openAfter = true;

    loadInitialState();

    fig = figure('Name', cfg.windowTitle, 'Position', [100, 100, 600, 600], 'NumberTitle', 'off', ...
        'MenuBar', 'none', 'ToolBar', 'none', 'Resize', 'off', 'Tag', figTag);

    leftMargin = 20;
    topMargin = 550;
    btnWidth = 150;
    btnHeight = 25;
    spacing = 10;
    secondcolumnshift = 170;

    uicontrol('Parent', fig, 'Style', 'pushbutton', 'String', cfg.selectButtonText, ...
        'Position', [leftMargin, topMargin, btnWidth, btnHeight], 'Callback', @selectSource);

    sourcePathLabel = uicontrol('Parent', fig, 'Style', 'text', 'String', cfg.emptySourceLabel, ...
        'Position', [leftMargin + btnWidth + spacing, topMargin, 400, btnHeight], 'HorizontalAlignment', 'left');

    shiftdown = btnHeight + 20;
    FsOrigLabel = uicontrol('Parent', fig, 'Style', 'text', 'String', '...', ...
        'Position', [leftMargin + btnWidth + spacing, topMargin - shiftdown, 400, btnHeight], 'HorizontalAlignment', 'left');

    shiftdown = 80;
    uicontrol('Parent', fig, 'Style', 'checkbox', 'String', 'Detect MUA', ...
        'Position', [leftMargin, topMargin - (btnHeight + spacing) + 30 - shiftdown, btnWidth, btnHeight], ...
        'Value', detectMua, 'Callback', @detectMuaCallback);

    uicontrol('Parent', fig, 'Style', 'text', 'String', 'MUA Threshold (n*STD):', ...
        'Position', [leftMargin, topMargin - (btnHeight + spacing) - shiftdown, 150, btnHeight], 'HorizontalAlignment', 'right');

    muaCoefUI = uicontrol('Parent', fig, 'Style', 'edit', 'String', num2str(mua_std_coef), ...
        'Position', [leftMargin + secondcolumnshift, topMargin - (btnHeight + spacing) - shiftdown, 50, btnHeight], 'Callback', @muaCoefUICallback);

    shiftdown = 120;
    uicontrol('Parent', fig, 'Style', 'text', 'String', 'New Fs (Hz):', ...
        'Position', [leftMargin, topMargin - 2 * (btnHeight + spacing) - shiftdown, 150, btnHeight], 'HorizontalAlignment', 'right');

    lfpFsUI = uicontrol('Parent', fig, 'Style', 'edit', 'String', num2str(lfp_Fs), ...
        'Position', [leftMargin + secondcolumnshift, topMargin - 2 * (btnHeight + spacing) - shiftdown, 50, btnHeight], 'Callback', @lfpFsUICallback);

    doResampleToggle = uicontrol('Parent', fig, 'Style', 'checkbox', 'String', 'Resample LFP', ...
        'Position', [leftMargin, topMargin - 2 * (btnHeight + spacing) + 30 - shiftdown, 100, btnHeight], ...
        'Value', doResample, 'Callback', @doResampleCallback);

    channelPanel = uipanel('Parent', fig, 'Title', 'Select Channels', 'Position', [0.05, 0.1, 0.9, 0.45]);

    uicontrol('Parent', channelPanel, 'Style', 'pushbutton', 'String', 'Select All', ...
        'Units', 'normalized', 'Position', [0.02, 0.92, 0.15, 0.06], 'Callback', @selectAllChannels);

    uicontrol('Parent', channelPanel, 'Style', 'pushbutton', 'String', 'Deselect All', ...
        'Units', 'normalized', 'Position', [0.18, 0.92, 0.15, 0.06], 'Callback', @deselectAllChannels);

    if cfg.hasDeselectEmpty
        uicontrol('Parent', channelPanel, 'Style', 'pushbutton', 'String', 'Deselect empty channels', ...
            'Units', 'normalized', 'Position', [0.34, 0.92, 0.22, 0.06], 'Callback', @deselectEmptyChannels);
    end

    channelTable = uitable('Parent', channelPanel, 'Data', {}, 'ColumnName', {'Use', 'Channel Name'}, ...
        'ColumnEditable', [true, false], 'Units', 'normalized', 'Position', [0, 0, 1, 0.92], 'CellEditCallback', @channelSelectionCallback);

    uicontrol('Parent', fig, 'Style', 'checkbox', 'String', 'Open after conversion', ...
        'Position', [leftMargin, 20, btnWidth, btnHeight], 'Value', openAfter, 'Callback', @openafterConvCallback);

    uicontrol('Parent', fig, 'Style', 'pushbutton', 'String', 'Start Conversion', ...
        'Position', [leftMargin + secondcolumnshift, 20, btnWidth, btnHeight], 'Callback', @startConversion);

    set(doResampleToggle, 'Value', doResample);
    set(muaCoefUI, 'String', num2str(mua_std_coef));
    set(lfpFsUI, 'String', num2str(lfp_Fs));

    if ~isempty(sourcePath)
        set(sourcePathLabel, 'String', sourcePath);
        if (cfg.sourceType == "file" && exist(sourcePath, 'file')) || (cfg.sourceType == "folder" && exist(sourcePath, 'dir'))
            extractChannels();
        end
    end

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

        if formatKey == "abf" && isfield(import_settings, 'abf2zav')
            settings = import_settings.abf2zav;
            if isfield(settings, 'filePath') && ~isempty(settings.filePath)
                sourcePath = settings.filePath;
            end
            if isfield(settings, 'doResample')
                doResample = settings.doResample;
            end
            if isfield(settings, 'selectedChannels')
                selectedChannels = settings.selectedChannels;
            end
        end
    end

    function saveAbfImportSettings()
        if formatKey ~= "abf"
            return;
        end
        if ~isfield(import_settings, 'abf2zav')
            import_settings.abf2zav = struct();
        end
        import_settings.abf2zav.filePath = sourcePath;
        import_settings.abf2zav.doResample = doResample;
        import_settings.abf2zav.selectedChannels = selectedChannels;
        save(SettingsFilepath, 'import_settings', '-append');
    end

    function selectSource(~, ~)
        if cfg.sourceType == "file"
            [file, path] = uigetfile('*.abf', 'Select ABF File', active_folder);
            if isequal(file, 0)
                clearSourceSelection();
                return;
            end
            sourcePath = fullfile(path, file);
            active_folder = path;
        else
            if formatKey == "nlx"
                selectedFolder = uigetdir(active_folder, 'Select Neuralynx Folder');
            else
                selectedFolder = uigetdir(active_folder, 'Select OpenEphys Folder');
            end
            if isequal(selectedFolder, 0)
                clearSourceSelection();
                return;
            end
            sourcePath = selectedFolder;
            active_folder = selectedFolder;
        end

        set(sourcePathLabel, 'String', sourcePath);
        extractChannels();
        saveAbfImportSettings();
    end

    function clearSourceSelection()
        sourcePath = '';
        set(sourcePathLabel, 'String', cfg.emptySourceLabel);
        set(channelTable, 'Data', {});
        availableChannels = {};
        selectedChannels = {};
        channelNumbers = [];
        channelFilePaths = {};
        channelBytes = [];
        sourceFs = [];
        set(FsOrigLabel, 'String', '...');
    end

    function extractChannels()
        switch formatKey
            case "abf"
                [~, ~, hd_abf] = abfload(sourcePath, 'stop', 1, 'doDispInfo', false);
                availableChannels = hd_abf.recChNames;
                sourceFs = 1e6 / hd_abf.si;

            case "oep"
                metadataTable = readOpenEphysMetadata(sourcePath);
                if isempty(metadataTable)
                    error('OpenEphys metadata is empty');
                end
                availableChannels = metadataTable.Channel_Names{1}';
                sourceFs = metadataTable.Sample_Rate{1};

            case "nlx"
                if sourcePath(end) ~= '\'
                    sourcePath(end + 1) = '\';
                end
                dirCnt = dir(sourcePath);
                ncsFiles = struct('f', {}, 'chNum', {}, 'chName', {}, 'bytes', {});
                for t = 1:length(dirCnt)
                    if ((~dirCnt(t).isdir) && (length(dirCnt(t).name) > 3))
                        if isequal(dirCnt(t).name(end - 3:end), '.ncs')
                            fileName = dirCnt(t).name(1:end-4);
                            numMatch = regexp(fileName, '\d+$', 'match');
                            if ~isempty(numMatch)
                                ch = str2double(numMatch{1});
                                if ~isnan(ch)
                                    ncsFiles(end + 1).f = fullfile(sourcePath, dirCnt(t).name);
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
                    error('No .ncs files found in selected folder');
                end
                availableChannels = {ncsFiles.chName}';
                channelNumbers = [ncsFiles.chNum]';
                channelFilePaths = {ncsFiles.f}';
                channelBytes = [ncsFiles.bytes]';
                cscHd = Nlx2MatCSC(ncsFiles(1).f, [0 0 0 0 0], 1, 1, []);
                sourceFs = NlxParametr(cscHd, 'SamplingFrequency');
        end

        channelData = cell(numel(availableChannels), 2);
        for i = 1:numel(availableChannels)
            channelData{i, 1} = true;
            channelData{i, 2} = availableChannels{i};
        end
        set(channelTable, 'Data', channelData);
        selectedChannels = availableChannels;

        if ~isempty(sourceFs)
            set(FsOrigLabel, 'String', ['Fs (Hz): ', num2str(sourceFs)]);
        else
            set(FsOrigLabel, 'String', 'Fs (Hz): N/A');
        end

        if formatKey == "abf" && ~isempty(import_settings) && isfield(import_settings, 'abf2zav')
            savedSelectedChannels = import_settings.abf2zav.selectedChannels;
            if ~isempty(savedSelectedChannels)
                channelData = get(channelTable, 'Data');
                for i = 1:size(channelData, 1)
                    channelData{i, 1} = any(strcmp(channelData{i, 2}, savedSelectedChannels));
                end
                set(channelTable, 'Data', channelData);
                selectedChannelIndices = find([channelData{:, 1}]);
                selectedChannels = availableChannels(selectedChannelIndices);
            end
        end
    end

    function channelSelectionCallback(src, ~)
        channelData = get(src, 'Data');
        selectedChannelIndices = find([channelData{:, 1}]);
        selectedChannels = availableChannels(selectedChannelIndices);
        saveAbfImportSettings();
    end

    function selectAllChannels(~, ~)
        channelData = get(channelTable, 'Data');
        if isempty(channelData)
            return;
        end
        for i = 1:size(channelData, 1)
            channelData{i, 1} = true;
        end
        set(channelTable, 'Data', channelData);
        selectedChannels = availableChannels;
        saveAbfImportSettings();
    end

    function deselectAllChannels(~, ~)
        channelData = get(channelTable, 'Data');
        if isempty(channelData)
            return;
        end
        for i = 1:size(channelData, 1)
            channelData{i, 1} = false;
        end
        set(channelTable, 'Data', channelData);
        selectedChannels = {};
        saveAbfImportSettings();
    end

    function deselectEmptyChannels(~, ~)
        if formatKey ~= "nlx" || isempty(channelBytes)
            return;
        end
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
        selectedChannels = availableChannels(selectedChannelIndices);
    end

    function detectMuaCallback(source, ~)
        detectMua = get(source, 'Value');
    end

    function openafterConvCallback(source, ~)
        openAfter = get(source, 'Value');
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
        saveAbfImportSettings();
    end

    function startConversion(~, ~)
        if isempty(sourcePath)
            warndlg(cfg.emptySourceLabel, 'No Source Selected');
            return;
        end

        channelData = get(channelTable, 'Data');
        selectedChannelIndices = find([channelData{:, 1}]);
        if isempty(selectedChannelIndices)
            warndlg('Please select at least one channel.', 'No Channels Selected');
            return;
        end
        selectedChannels = availableChannels(selectedChannelIndices);

        defaultOutputName = buildDefaultOutputName();
        [file, path] = uiputfile('*.mat', 'Save ZAV File As', defaultOutputName);
        if isequal(file, 0)
            return;
        end
        zavFilePath = fullfile(path, file);
        active_folder = path;

        if formatKey == "abf"
            settingsFilePath = [zavFilePath(1:end-4), '_channelSettings.stn'];
            if exist(settingsFilePath, 'file')
                delete(settingsFilePath);
            end
        end

        hWaitBar = waitbar(0, 'Initializing conversion...', 'Name', cfg.windowTitle);
        try
            runConversion(selectedChannelIndices, hWaitBar);
            savePostActions();
            if isvalid(hWaitBar)
                close(hWaitBar);
            end
            close(fig);
            if openAfter
                zav_calling(zavFilePath);
            end
        catch ME
            if exist('hWaitBar', 'var') && isvalid(hWaitBar)
                close(hWaitBar);
            end
            warndlg(['An error occurred during conversion: ', ME.message], 'Conversion Error');
        end
    end

    function outputName = buildDefaultOutputName()
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

    function runConversion(selectedChannelIndices, hWaitBar)
        switch formatKey
            case "abf"
                collectSweeps = true;
                abf_to_zav(sourcePath, zavFilePath, lfp_Fs, detectMua, doResample, collectSweeps, selectedChannels, mua_std_coef, hWaitBar);
            case "oep"
                oep_to_zav_streaming(sourcePath, zavFilePath, sourceFs, lfp_Fs, detectMua, mua_std_coef, doResample, availableChannels, selectedChannelIndices, hWaitBar);
            case "nlx"
                channels_list = channelNumbers(selectedChannelIndices);
                ncsFilePaths = channelFilePaths(selectedChannelIndices);
                nlx_to_zav_streaming(sourcePath, zavFilePath, channels_list, ncsFilePaths, lfp_Fs, detectMua, mua_std_coef, doResample, hWaitBar);
        end
    end

    function savePostActions()
        if formatKey == "abf"
            lastOpenedFiles = {zavFilePath};
            save(SettingsFilepath, 'lastOpenedFiles', '-append');
            saveAbfImportSettings();
            return;
        end

        lastOpenedFolders = {sourcePath};
        if exist(SettingsFilepath, 'file')
            save(SettingsFilepath, 'lastOpenedFolders', '-append');
        else
            save(SettingsFilepath, 'lastOpenedFolders');
        end

        if formatKey == "nlx"
            lastOpenedFiles = {zavFilePath};
            save(SettingsFilepath, 'lastOpenedFiles', '-append');
        end
    end
end
