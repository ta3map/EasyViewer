function saveMUADialog(spks, hd, matFilePath, events, lfpVar, std_coef, Fs, time, matFileName, autodetection_settings, add_event_settings, EV_version, eventsFilePath, sourceFilePath)
    channel_names = {};
    if isstruct(hd) && isfield(hd, 'recChNames') && ~isempty(hd.recChNames)
        if iscell(hd.recChNames)
            channel_names = hd.recChNames(:)';
        else
            channel_names = cellstr(hd.recChNames);
        end
    end

    spksToSave = spks;
    [basePath, baseName, ~] = fileparts(matFilePath);
    hasEventsForWindowFilter = ~isempty(events);
    defaultExt = '.mua';
    if ~hasEventsForWindowFilter
        defaultExt = '.spks';
    end
    defaultMuaPath = fullfile(basePath, [baseName '_mua' defaultExt]);
    [defaultMuaFolder, defaultMuaName, defaultMuaExt] = fileparts(defaultMuaPath);
    if isempty(defaultMuaFolder)
        defaultMuaFolder = basePath;
    end
    if isempty(defaultMuaExt)
        defaultMuaName = [defaultMuaName '.mua'];
    else
        defaultMuaName = [defaultMuaName defaultMuaExt];
    end
    aroundEventsEnabled = hasEventsForWindowFilter;
    thresholdFilterEnabled = true;
    windowMs = 600;
    selectedMuaPath = defaultMuaPath;
    saveAccepted = false;
    selectedMuaChannels = 1:numel(spks);
    maskMuaEnabled = false;

    dlg = dialog('Name', 'Save MUA', 'Position', [400 280 580 330], 'WindowStyle', 'modal');
    uicontrol(dlg, 'Style', 'text', 'Position', [20 295 520 20], ...
        'String', 'Save MUA', 'HorizontalAlignment', 'left', 'FontWeight', 'bold');

    thresholdCb = uicontrol(dlg, 'Style', 'checkbox', 'Position', [20 262 240 24], ...
        'String', 'apply current MUA threshold', 'Value', thresholdFilterEnabled);
    aroundCb = uicontrol(dlg, 'Style', 'checkbox', 'Position', [20 232 150 24], ...
        'String', 'around events', 'Value', aroundEventsEnabled);
    uicontrol(dlg, 'Style', 'pushbutton', 'Position', [330 232 230 24], ...
        'String', 'Select MUA channels', 'Callback', @selectMuaChannels);
    windowEdit = uicontrol(dlg, 'Style', 'edit', 'Position', [20 198 80 24], ...
        'String', num2str(windowMs), 'Visible', onOff(aroundEventsEnabled), ...
        'BackgroundColor', 'white');
    uicontrol(dlg, 'Style', 'text', 'Position', [110 198 120 24], ...
        'String', 'ms window', 'HorizontalAlignment', 'left', 'Visible', onOff(aroundEventsEnabled), 'Tag', 'window_label');

    uicontrol(dlg, 'Style', 'text', 'Position', [20 168 120 20], ...
        'String', 'Folder:', 'HorizontalAlignment', 'left');
    folderEdit = uicontrol(dlg, 'Style', 'edit', 'Position', [20 135 430 26], ...
        'String', defaultMuaFolder, 'HorizontalAlignment', 'left', ...
        'BackgroundColor', 'white', 'Enable', 'on');
    uicontrol(dlg, 'Style', 'pushbutton', 'Position', [460 135 100 26], ...
        'String', 'Browse...', 'Callback', @browseMuaFolder);

    uicontrol(dlg, 'Style', 'text', 'Position', [20 108 120 20], ...
        'String', 'File name:', 'HorizontalAlignment', 'left');
    fileNameEdit = uicontrol(dlg, 'Style', 'edit', 'Position', [20 75 530 26], ...
        'String', defaultMuaName, 'HorizontalAlignment', 'left', ...
        'BackgroundColor', 'white', 'Enable', 'on');

    uicontrol(dlg, 'Style', 'pushbutton', 'Position', [360 15 90 30], ...
        'String', 'Save', 'Callback', @confirmSave);
    uicontrol(dlg, 'Style', 'pushbutton', 'Position', [460 15 90 30], ...
        'String', 'Cancel', 'Callback', @cancelSave);

    if ~hasEventsForWindowFilter
        set(aroundCb, 'Value', 0, 'Visible', 'off');
        set(windowEdit, 'Visible', 'off');
        set(findobj(dlg, 'Tag', 'window_label'), 'Visible', 'off');
    end
    set(aroundCb, 'Callback', @toggleAroundEvents);
    uiwait(dlg);

    if ~saveAccepted
        if isvalid(dlg)
            delete(dlg);
        end
        return;
    end

    keepChannelsMask = false(numel(spksToSave), 1);
    keepChannelsMask(selectedMuaChannels) = true;
    for ch = 1:numel(spksToSave)
        if ~keepChannelsMask(ch)
            spksToSave(ch).tStamp = [];
            spksToSave(ch).ampl = [];
        end
    end

    if thresholdFilterEnabled
        for ch = 1:numel(spksToSave)
            if isempty(spksToSave(ch).tStamp)
                continue;
            end
            if ch > numel(lfpVar)
                continue;
            end
            thresholdMask = abs(double(spksToSave(ch).ampl(:))) >= (lfpVar(ch) * std_coef);
            spksToSave(ch).tStamp = spksToSave(ch).tStamp(thresholdMask);
            spksToSave(ch).ampl = spksToSave(ch).ampl(thresholdMask);
        end
    end

    if aroundEventsEnabled && hasEventsForWindowFilter && maskMuaEnabled
        eventsToSave = events(:);
        eventIndicesToSave = nearestTimeIndices(eventsToSave, time);
        halfWindowSec = (windowMs / 1000) / 2;
        windowStarts = events(:) - halfWindowSec;
        windowEnds = events(:) + halfWindowSec;
        [windowStarts, order] = sort(windowStarts);
        windowEnds = windowEnds(order);
        mergedStarts = windowStarts(1);
        mergedEnds = windowEnds(1);
        for iWin = 2:numel(windowStarts)
            if windowStarts(iWin) <= mergedEnds(end)
                mergedEnds(end) = max(mergedEnds(end), windowEnds(iWin));
            else
                mergedStarts(end + 1, 1) = windowStarts(iWin);
                mergedEnds(end + 1, 1) = windowEnds(iWin);
            end
        end
        for ch = 1:numel(spksToSave)
            if isempty(spksToSave(ch).tStamp)
                continue;
            end
            ts = spksToSave(ch).tStamp;
            tSec = double(ts(:)) / 1000;
            keepMask = false(size(tSec));
            for iWin = 1:numel(mergedStarts)
                keepMask = keepMask | (tSec >= mergedStarts(iWin) & tSec <= mergedEnds(iWin));
            end
            spksToSave(ch).tStamp = ts(keepMask);
            spksToSave(ch).ampl = spksToSave(ch).ampl(keepMask);
            if isfield(spksToSave(ch), 'shape') && ~isempty(spksToSave(ch).shape)
                sh = spksToSave(ch).shape;
                if numel(sh) == numel(ts)
                    spksToSave(ch).shape = sh(keepMask);
                end
            end
        end
        saveMUAEventsToFile(spksToSave, Fs, matFilePath, ...
            'dialogTitle', 'Save MUA (.mua)', ...
            'defaultFileNameSuffix', '_mua', ...
            'fileExtension', '.mua', ...
            'filepath', selectedMuaPath, ...
            'max_index', length(time), ...
            'matFileName', matFileName, ...
            'autodetection_settings', autodetection_settings, ...
            'add_event_settings', add_event_settings, ...
            'EV_version', EV_version, ...
            'channel_names', channel_names, ...
            'events', eventsToSave, ...
            'events_index', eventIndicesToSave, ...
            'events_filepath', eventsFilePath, ...
            'original_filepath', sourceFilePath);
    elseif aroundEventsEnabled && hasEventsForWindowFilter
        halfWindowSec = (windowMs / 1000) / 2;
        nEv = numel(events);
        nCh = numel(spksToSave);
        base = spksToSave(1);
        base.tStamp = [];
        base.ampl = [];
        if isfield(base, 'shape')
            base.shape = [];
        end
        spks_events = cell(nEv, 1);
        for iEv = 1:nEv
            trialSpk = repmat(base, nCh, 1);
            w0 = events(iEv) - halfWindowSec;
            w1 = events(iEv) + halfWindowSec;
            anchorSec = events(iEv);
            for ch = 1:nCh
                ts = spksToSave(ch).tStamp;
                if isempty(ts)
                    continue;
                end
                tsec = double(ts(:)) / 1000;
                m = tsec >= w0 & tsec <= w1;
                trialSpk(ch).tStamp = ts(m) - anchorSec * 1000;
                trialSpk(ch).ampl = spksToSave(ch).ampl(m);
                if isfield(spksToSave(ch), 'shape') && ~isempty(spksToSave(ch).shape)
                    sh = spksToSave(ch).shape;
                    if numel(sh) == numel(spksToSave(ch).tStamp)
                        trialSpk(ch).shape = sh(m);
                    end
                end
            end
            spks_events{iEv} = trialSpk;
        end
        event_times_sec = events(:);
        eventIndicesToSave = nearestTimeIndices(event_times_sec, time);
        saveMUAEventsToFile([], Fs, matFilePath, ...
            'dialogTitle', 'Save MUA (.mua)', ...
            'defaultFileNameSuffix', '_mua', ...
            'fileExtension', '.mua', ...
            'filepath', selectedMuaPath, ...
            'channel_names', channel_names, ...
            'spks_events', spks_events, ...
            'event_times_sec', event_times_sec, ...
            'events', event_times_sec, ...
            'events_index', eventIndicesToSave, ...
            'events_filepath', eventsFilePath, ...
            'original_filepath', sourceFilePath);
    else
        saveMUAEventsToFile(spksToSave, Fs, matFilePath, ...
            'dialogTitle', 'Save MUA (.spks)', ...
            'defaultFileNameSuffix', '_spks', ...
            'fileExtension', '.spks', ...
            'filepath', selectedMuaPath, ...
            'max_index', length(time), ...
            'matFileName', matFileName, ...
            'autodetection_settings', autodetection_settings, ...
            'add_event_settings', add_event_settings, ...
            'EV_version', EV_version, ...
            'channel_names', channel_names, ...
            'events_filepath', eventsFilePath, ...
            'original_filepath', sourceFilePath);
    end

    if isvalid(dlg)
        delete(dlg);
    end

    function toggleAroundEvents(~, ~)
        aroundEventsEnabled = get(aroundCb, 'Value') == 1;
        set(windowEdit, 'Visible', onOff(aroundEventsEnabled));
        set(findobj(dlg, 'Tag', 'window_label'), 'Visible', onOff(aroundEventsEnabled));
        updateFileNameExtension();
    end

    function browseMuaFolder(~, ~)
        startDir = strtrim(get(folderEdit, 'String'));
        if isempty(startDir) || ~isfolder(startDir)
            startDir = pwd;
        end
        picked = uigetdir(startDir, 'Select folder for MUA');
        if isequal(picked, 0)
            return;
        end
        set(folderEdit, 'String', picked);
    end

    function selectMuaChannels(~, ~)
        channelLabels = arrayfun(@(ch) sprintf('Channel %d', ch), 1:numel(spks), 'UniformOutput', false);
        [chosenIdx, ok] = listdlg( ...
            'ListString', channelLabels, ...
            'SelectionMode', 'multiple', ...
            'InitialValue', selectedMuaChannels, ...
            'PromptString', 'Select channels for MUA save:', ...
            'ListSize', [260 320]);
        if ok && ~isempty(chosenIdx)
            selectedMuaChannels = chosenIdx(:)';
        end
    end

    function confirmSave(~, ~)
        folderStr = strtrim(get(folderEdit, 'String'));
        nameStr = strtrim(get(fileNameEdit, 'String'));
        if isempty(folderStr) || isempty(nameStr)
            return;
        end
        [~, ~, ext] = fileparts(nameStr);
        if isempty(ext)
            if hasEventsForWindowFilter && aroundEventsEnabled
                nameStr = [nameStr '.mua'];
            else
                nameStr = [nameStr '.spks'];
            end
        end
        selectedMuaPath = fullfile(folderStr, nameStr);
        aroundEventsEnabled = get(aroundCb, 'Value') == 1;
        maskMuaEnabled = hasEventsForWindowFilter && aroundEventsEnabled;
        thresholdFilterEnabled = get(thresholdCb, 'Value') == 1;
        windowMs = str2double(get(windowEdit, 'String'));
        if ~isfinite(windowMs) || windowMs <= 0
            windowMs = 600;
        end
        saveAccepted = true;
        uiresume(dlg);
    end

    function cancelSave(~, ~)
        saveAccepted = false;
        uiresume(dlg);
    end

    function state = onOff(flag)
        options = {'off', 'on'};
        state = options{1 + (flag ~= 0)};
    end

    function updateFileNameExtension()
        currentName = strtrim(get(fileNameEdit, 'String'));
        if isempty(currentName)
            return;
        end
        [nameOnly, ext] = strtok(currentName, '.');
        if isempty(nameOnly)
            return;
        end
        if isempty(ext)
            if hasEventsForWindowFilter && aroundEventsEnabled
                set(fileNameEdit, 'String', [nameOnly '.mua']);
            else
                set(fileNameEdit, 'String', [nameOnly '.spks']);
            end
            return;
        end
        if hasEventsForWindowFilter && aroundEventsEnabled
            set(fileNameEdit, 'String', [nameOnly '.mua']);
        else
            set(fileNameEdit, 'String', [nameOnly '.spks']);
        end
    end

    function eventIndices = nearestTimeIndices(eventTimes, timeVec)
        eventIndices = zeros(numel(eventTimes), 1);
        for iEv = 1:numel(eventTimes)
            [~, idx] = min(abs(timeVec(:) - eventTimes(iEv)));
            eventIndices(iEv) = idx;
        end
    end
end
