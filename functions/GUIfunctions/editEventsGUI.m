function editEventsGUI()
    % Function to edit events with comprehensive GUI interface
    % Allows user to shift, edit, and delete events with all their properties
    
    % Global variables
    global events event_indices timeUnitFactor selectedUnit
    global time matFilePath lastOpenedFiles SettingsFilepath
    global matFileName EV_version autodetection_settings add_event_settings
    global event_comments event_amplitudes event_channels event_widths
    global event_prominences event_metadata events_exist
    global table_calling updatePlotFunc
    
    % Identifier (tag) for GUI figure
    figTag = 'editEventsGUI';
    
    % Search for open figure with given identifier
    guiFig = findobj('Type', 'figure', 'Tag', figTag);
    
    if ~isempty(guiFig)
        % Make existing window current (active)
        figure(guiFig);
        return
    end
    
    % Check if events exist
    if isempty(events) || ~events_exist
        fprintf('No events available. Please load events first.\n');
        return
    end
    
    % Initialize GUI - larger window to accommodate more columns
    hFig = figure('Name', 'Edit Events', 'NumberTitle', 'off', ...
                  'Position', [100, 100, 900, 600], 'Resize', 'off', ...
                  'NumberTitle', 'off', 'MenuBar', 'none', 'ToolBar', 'none', ...
                  'Tag', figTag, 'WindowStyle', 'normal');

    % Create UI elements
    uicontrol('Style', 'text', 'Position', [20, 560, 860, 20], ...
              'String', ['Edit Events (' selectedUnit '):'], ...
              'HorizontalAlignment', 'left', 'FontWeight', 'bold');

    % Table for events with all properties
    eventTable = uitable('Parent', hFig, ...
                        'Position', [20, 240, 860, 310], ...
                        'Data', buildEventData(), ...
                        'ColumnName', {'N', ['Time (' selectedUnit ')'], 'Comment', 'Amplitude', 'Channel', 'Width', 'Prominence', 'Selected'}, ...
                        'ColumnFormat', {'numeric', 'char', 'char', 'char', 'numeric', 'char', 'char', 'logical'}, ...
                        'ColumnEditable', [false true true true true true true false], ...
                        'ColumnWidth', {40, 120, 140, 90, 70, 90, 90, 60}, ...
                        'RowName', {}, ...
                        'CellSelectionCallback', @onCellSelection);

    % Selection control buttons
    selectAllButton = uicontrol('Style', 'pushbutton', 'Position', [20, 200, 120, 30], ...
                                'String', 'Deselect All', 'Callback', @toggleSelectAll);
    
    deleteButton = uicontrol('Style', 'pushbutton', 'Position', [150, 200, 120, 30], ...
                             'String', 'Delete Selected', 'Callback', @deleteSelected);
    
    addEventButton = uicontrol('Style', 'pushbutton', 'Position', [280, 200, 120, 30], ...
                               'String', 'Add Event', 'Callback', @addEvent);

    % Shift operation section
    uicontrol('Style', 'text', 'Position', [20, 160, 200, 20], ...
              'String', ['Shift selected times by (' selectedUnit '):'], ...
              'HorizontalAlignment', 'left', 'FontWeight', 'bold');
    shiftEdit = uicontrol('Style', 'edit', 'Position', [20, 140, 100, 20], 'String', '0');
    uicontrol('Style', 'pushbutton', 'Position', [130, 138, 80, 24], ...
              'String', 'Check', 'Callback', @performShift);

    % Import mode dropdown
    importModeOptions = {'From file (add)', 'From memory (add)', 'From file (replace)', 'From memory (replace)'};
    savedMode = loadImportMode();
    savedModeIndex = find(strcmp(importModeOptions, savedMode), 1);
    if isempty(savedModeIndex)
        savedModeIndex = 1;
    end
    
    uicontrol('Style', 'text', 'Position', [20, 120, 150, 20], ...
              'String', 'Import mode:', 'HorizontalAlignment', 'left');
    importModePopup = uicontrol('Style', 'popupmenu', 'Position', [20, 100, 200, 25], ...
                                'String', importModeOptions, ...
                                'Value', savedModeIndex, ...
                                'Callback', @saveImportMode);
    
    % Action buttons
    uicontrol('Style', 'pushbutton', 'Position', [230, 98, 100, 30], ...
              'String', 'Import', 'Callback', @importEvents);

    % Export mode dropdown
    exportModeOptions = {'To file', 'To memory (add)', 'To memory (replace)'};
    savedExportMode = loadExportMode();
    savedExportModeIndex = find(strcmp(exportModeOptions, savedExportMode), 1);
    if isempty(savedExportModeIndex)
        savedExportModeIndex = 1;
    end
    
    uicontrol('Style', 'text', 'Position', [20, 80, 150, 20], ...
              'String', 'Export mode:', 'HorizontalAlignment', 'left');
    exportModePopup = uicontrol('Style', 'popupmenu', 'Position', [20, 60, 200, 25], ...
                                'String', exportModeOptions, ...
                                'Value', savedExportModeIndex, ...
                                'Callback', @saveExportMode);
    
    uicontrol('Style', 'pushbutton', 'Position', [230, 58, 100, 30], ...
              'String', 'Export', 'Callback', @exportEvents);

    uicontrol('Style', 'pushbutton', 'Position', [20, 20, 100, 25], ...
              'String', 'Reset', 'Callback', @resetChanges);

    uicontrol('Style', 'pushbutton', 'Position', [130, 20, 100, 25], ...
              'String', 'Apply', 'Callback', @applyChanges);
    
    uicontrol('Style', 'pushbutton', 'Position', [240, 20, 100, 25], ...
              'String', 'Close', 'Callback', @closeWindow);

    % Track selection state for toggle button and original data
    selected_rows = [];
    allSelected = false;
    originalEvents = events;
    originalEventIndices = event_indices;
    if isempty(originalEventIndices) || length(originalEventIndices) ~= length(events)
        [~, originalEventIndices] = min(abs(time(:) - events(:)'), [], 1);
        originalEventIndices = originalEventIndices(:);
    end
    originalComments = event_comments;
    originalAmplitudes = event_amplitudes;
    originalChannels = event_channels;
    originalWidths = event_widths;
    originalProminences = event_prominences;
    originalMetadata = event_metadata;
    currentShiftValue = 0;

    function data = buildEventData()
        numEvents = length(events);
        data = cell(numEvents, 8);
        for idx = 1:numEvents
            data{idx, 1} = idx;
            data{idx, 2} = formatValue(events(idx) * timeUnitFactor);
            data{idx, 3} = getComment(idx);
            data{idx, 4} = formatValue(getAmplitude(idx));
            data{idx, 5} = getChannel(idx);
            data{idx, 6} = formatValue(getWidth(idx));
            data{idx, 7} = formatValue(getProminence(idx));
            data{idx, 8} = false;
        end
    end

    function comment = getComment(idx)
        if ~isempty(event_comments) && idx <= length(event_comments)
            comment = event_comments{idx};
        else
            comment = '...';
        end
    end

    function amp = getAmplitude(idx)
        if ~isempty(event_amplitudes) && idx <= length(event_amplitudes)
            amp = event_amplitudes(idx);
        else
            amp = NaN;
        end
    end

    function ch = getChannel(idx)
        if ~isempty(event_channels) && idx <= size(event_channels, 1)
            if size(event_channels, 2) == 1
                ch = event_channels(idx);
            else
                ch = event_channels(idx, 1);
            end
        else
            ch = 1;
        end
    end

    function w = getWidth(idx)
        if ~isempty(event_widths) && idx <= length(event_widths)
            w = event_widths(idx);
        else
            w = NaN;
        end
    end

    function p = getProminence(idx)
        if ~isempty(event_prominences) && idx <= length(event_prominences)
            p = event_prominences(idx);
        else
            p = NaN;
        end
    end

    function updateTableWithEvents()
        set(eventTable, 'Data', buildEventData());
        selected_rows = [];
        allSelected = false;
        set(selectAllButton, 'String', 'Select All');
    end

    function toggleSelectAll(~, ~)
        tableData = get(eventTable, 'Data');
        if isempty(tableData)
            return;
        end
        if allSelected
            selected_rows = [];
            tableData(:, 8) = {false};
            set(selectAllButton, 'String', 'Select All');
            allSelected = false;
        else
            selected_rows = (1:size(tableData, 1));
            tableData(:, 8) = {true};
            set(selectAllButton, 'String', 'Deselect All');
            allSelected = true;
        end
        set(eventTable, 'Data', tableData);
    end

    function onCellSelection(~, eventData)
        if isempty(eventData.Indices)
            return;
        end
        selected_rows = unique(eventData.Indices(:, 1))';
        tableData = get(eventTable, 'Data');
        tableData(:, 8) = {false};
        for i = selected_rows
            tableData{i, 8} = true;
        end
        set(eventTable, 'Data', tableData);
        allSelected = (numel(selected_rows) == size(tableData, 1));
        if allSelected
            set(selectAllButton, 'String', 'Deselect All');
        else
            set(selectAllButton, 'String', 'Select All');
        end
    end

    function deleteSelected(~, ~)
        if isempty(selected_rows)
            fprintf('No events selected for deletion.\n');
            return;
        end
        
        answer = questdlg(sprintf('Delete %d selected events?', length(selected_rows)), ...
                         'Confirm Deletion', 'Yes', 'No', 'No');
        if strcmp(answer, 'Yes')
            tableData = get(eventTable, 'Data');
            tableData(selected_rows, :) = [];
            for i = 1:size(tableData, 1)
                tableData{i, 1} = i;
            end
            selected_rows = [];
            allSelected = false;
            set(selectAllButton, 'String', 'Select All');
            set(eventTable, 'Data', tableData);
        end
    end

    function performShift(~, ~)
        if isempty(selected_rows)
            return;
        end
        
        shiftStr = get(shiftEdit, 'String');
        shiftAmount = str2double(shiftStr);
        
        if isnan(shiftAmount)
            shiftAmount = 0;
        end
        
        deltaShift = shiftAmount - currentShiftValue;
        currentShiftValue = shiftAmount;
        
        tableData = get(eventTable, 'Data');
        for i = selected_rows(:)'
            currentTime = toNumericValue(tableData{i, 2});
            newTime = currentTime + deltaShift;
            if newTime < 0
                newTime = 0;
            end
            tableData{i, 2} = formatValue(newTime);
        end
        
        set(eventTable, 'Data', tableData);
    end

    function applyChanges(~, ~)
        tableData = get(eventTable, 'Data');
        
        if isempty(tableData)
            events = [];
            event_indices = [];
            event_comments = {};
            event_amplitudes = [];
            event_channels = [];
            event_widths = [];
            event_prominences = [];
            event_metadata = [];
            events_exist = false;
        else
            numEvents = size(tableData, 1);
            numericTimes = cellfun(@toNumericValue, tableData(:, 2));
            newEventTimes = numericTimes / timeUnitFactor;
            
            if any(newEventTimes < 0)
                fprintf('Event times cannot be negative.\n');
                return;
            end
            
            [sortedTimes, sortIdx] = sort(newEventTimes);
            events = sortedTimes(:);
            
            newComments = cell(numEvents, 1);
            newAmplitudes = NaN(numEvents, 1);
            newChannels = ones(numEvents, 1);
            newWidths = NaN(numEvents, 1);
            newProminences = NaN(numEvents, 1);
            newMetadata = createDefaultEventMetadata('manual_edit', numEvents);
            
            for i = 1:numEvents
                origIdx = sortIdx(i);
                newComments{i} = tableData{origIdx, 3};
                newAmplitudes(i) = toNumericValue(tableData{origIdx, 4});
                newChannels(i) = toNumericValue(tableData{origIdx, 5});
                newWidths(i) = toNumericValue(tableData{origIdx, 6});
                newProminences(i) = toNumericValue(tableData{origIdx, 7});
            end
            
            event_comments = newComments;
            event_amplitudes = newAmplitudes;
            event_channels = newChannels;
            event_widths = newWidths;
            event_prominences = newProminences;
            event_metadata = newMetadata;
            [~, event_indices] = min(abs(time(:) - events(:)'), [], 1);
            event_indices = event_indices(:);
            events_exist = true;
        end
        
        if exist('table_calling', 'var') && ~isempty(table_calling)
            try
                table_calling();
            catch ME
                warning('Failed to update event table: %s', ME.message);
            end
        end
        
        if exist('updatePlotFunc', 'var') && ~isempty(updatePlotFunc)
            try
                updatePlotFunc();
            catch ME
                warning('Failed to update plot: %s', ME.message);
            end
        end
        
        set(shiftEdit, 'String', '0');
        currentShiftValue = 0;
    end

    function resetChanges(~, ~)
        events = originalEvents;
        event_indices = originalEventIndices;
        event_comments = originalComments;
        event_amplitudes = originalAmplitudes;
        event_channels = originalChannels;
        event_widths = originalWidths;
        event_prominences = originalProminences;
        event_metadata = originalMetadata;
        
        updateTableWithEvents();
        set(shiftEdit, 'String', '0');
        currentShiftValue = 0;
    end

    function closeWindow(~, ~)
        close(hFig);
    end
    
    function strValue = formatValue(value)
        if isnan(value)
            strValue = 'NaN';
        else
            strValue = sprintf('%.3f', value);
        end
    end
    
    function numericValue = toNumericValue(value)
        if isnumeric(value)
            numericValue = value;
        else
            if ischar(value) && strcmpi(value, 'NaN')
                numericValue = NaN;
            else
                numericValue = str2double(value);
            end
        end
        
        if isnan(numericValue) && ~ischar(value)
            numericValue = 0;
        end
    end

    function addEvent(~, ~)
        prompt = {['Enter event time (' selectedUnit '):'], 'Comment:', 'Amplitude:', 'Channel:', 'Width:', 'Prominence:'};
        defaultValues = {'0', '...', 'NaN', '1', 'NaN', 'NaN'};
        answer = inputdlg(prompt, 'Add Event', 1, defaultValues);
        if isempty(answer)
            return;
        end
        
        newTime = str2double(answer{1});
        if isnan(newTime) || newTime < 0
            fprintf('Invalid event time.\n');
            return;
        end
        
        tableData = get(eventTable, 'Data');
        newComment = answer{2};
        newAmp = toNumericValue(answer{3});
        newCh = toNumericValue(answer{4});
        newW = toNumericValue(answer{5});
        newP = toNumericValue(answer{6});
        
        newRowNum = size(tableData, 1) + 1;
        tableData(newRowNum, :) = {newRowNum, formatValue(newTime), newComment, formatValue(newAmp), newCh, formatValue(newW), formatValue(newP), false};
        set(eventTable, 'Data', tableData);
    end

    function importEvents(~, ~)
        if isempty(time)
            fprintf('Cannot import events: time vector is empty.\n');
            return;
        end
        
        modeIndex = get(importModePopup, 'Value');
        modeOptions = get(importModePopup, 'String');
        selectedMode = modeOptions{modeIndex};
        
        isFromFile = contains(selectedMode, 'file');
        isReplace = contains(selectedMode, 'replace');
        
        if isFromFile
            initialDir = pwd;
            if ~isempty(matFilePath)
                initialDir = fileparts(matFilePath);
            elseif ~isempty(lastOpenedFiles)
                try
                    initialDir = fileparts(lastOpenedFiles{end});
                catch
                end
            end
            
            [fileName, filePath] = uigetfile({'*.ev;*.mean', 'Event files (*.ev, *.mean)'; ...
                                              '*.ev', 'Event files (*.ev)'; ...
                                              '*.mean', 'Mean files (*.mean)'}, ...
                                             'Select events file', initialDir);
            if isequal(fileName, 0)
                return;
            end
            
            fullPath = fullfile(filePath, fileName);
            try
                loadedData = load(fullPath, '-mat');
            catch ME
                fprintf('Error loading events file: %s\n', ME.message);
                return;
            end
            
            if ~isfield(loadedData, 'manlDet') || isempty(loadedData.manlDet)
                fprintf('Selected file does not contain events.\n');
                return;
            end
            
            eventStruct = loadedData.manlDet;
            if ~isstruct(eventStruct)
                fprintf('Invalid events structure.\n');
                return;
            end
            
            eventIndices = round([eventStruct.t]);
            eventIndices = eventIndices(~isnan(eventIndices));
            validMask = eventIndices >= 1 & eventIndices <= numel(time);
            eventIndices = eventIndices(validMask);
            
            if isempty(eventIndices)
                fprintf('No valid events found in the selected file.\n');
                return;
            end
            
            newEventTimes = time(eventIndices(:));
            
            numNewEvents = length(newEventTimes);
            newComments = repmat({'...'}, numNewEvents, 1);
            newAmplitudes = NaN(numNewEvents, 1);
            newChannels = ones(numNewEvents, 1);
            newWidths = NaN(numNewEvents, 1);
            newProminences = NaN(numNewEvents, 1);
            newMetadata = createDefaultEventMetadata('imported', numNewEvents);
            
            if isfield(loadedData, 'event_comments') && length(loadedData.event_comments) == numNewEvents
                newComments = loadedData.event_comments(:);
            end
            
            if isfield(eventStruct, 'amplitude')
                newAmplitudes = [eventStruct.amplitude]';
            end
            
            if isfield(eventStruct, 'channels')
                firstCh = eventStruct(1).channels;
                if isscalar(firstCh)
                    newChannels = [eventStruct.channels]';
                else
                    maxCh = max(cellfun(@length, {eventStruct.channels}));
                    newChannels = NaN(numNewEvents, maxCh);
                    for i = 1:numNewEvents
                        chs = eventStruct(i).channels;
                        newChannels(i, 1:length(chs)) = chs;
                    end
                    newChannels = newChannels(:, 1);
                end
            elseif isfield(eventStruct, 'ch')
                newChannels = [eventStruct.ch]';
            end
            
            if isfield(eventStruct, 'width')
                newWidths = [eventStruct.width]';
            end
            
            if isfield(eventStruct, 'prominence')
                newProminences = [eventStruct.prominence]';
            end
            
            if isfield(eventStruct, 'metadata')
                newMetadata = [eventStruct.metadata]';
            end
            
            sourceName = fileName;
        else
            if isempty(events)
                fprintf('No events in memory. Please load events first.\n');
                return;
            end
            
            newEventTimes = events(:);
            newComments = event_comments(:);
            newAmplitudes = event_amplitudes(:);
            if size(event_channels, 2) == 1
                newChannels = event_channels(:);
            else
                newChannels = event_channels(:, 1);
            end
            newWidths = event_widths(:);
            newProminences = event_prominences(:);
            newMetadata = event_metadata(:);
            sourceName = 'memory';
        end
        
        if isReplace
            events = newEventTimes;
            event_comments = newComments;
            event_amplitudes = newAmplitudes;
            event_channels = newChannels;
            event_widths = newWidths;
            event_prominences = newProminences;
            event_metadata = newMetadata;
        else
            tableData = get(eventTable, 'Data');
            if isempty(tableData)
                currentTimes = [];
                currentComments = {};
                currentAmplitudes = [];
                currentChannels = [];
                currentWidths = [];
                currentProminences = [];
                currentMetadata = [];
            else
                numericTimes = cellfun(@toNumericValue, tableData(:, 2));
                currentTimes = numericTimes / timeUnitFactor;
                currentComments = tableData(:, 3);
                currentAmplitudes = cellfun(@toNumericValue, tableData(:, 4));
                currentChannels = cellfun(@toNumericValue, tableData(:, 5));
                currentWidths = cellfun(@toNumericValue, tableData(:, 6));
                currentProminences = cellfun(@toNumericValue, tableData(:, 7));
                currentMetadata = createDefaultEventMetadata('manual_edit', size(tableData, 1));
            end
            
            allTimes = [currentTimes(:); newEventTimes(:)];
            [sortedTimes, sortIdx] = sort(allTimes);
            [uniqueTimes, uniqueIdx] = unique(sortedTimes, 'stable');
            
            events = uniqueTimes(:);
            numEvents = length(events);
            
            allComments = [currentComments(:); newComments(:)];
            event_comments = allComments(sortIdx(uniqueIdx));
            
            allAmplitudes = [currentAmplitudes(:); newAmplitudes(:)];
            event_amplitudes = allAmplitudes(sortIdx(uniqueIdx));
            
            allChannels = [currentChannels(:); newChannels(:)];
            event_channels = allChannels(sortIdx(uniqueIdx));
            
            allWidths = [currentWidths(:); newWidths(:)];
            event_widths = allWidths(sortIdx(uniqueIdx));
            
            allProminences = [currentProminences(:); newProminences(:)];
            event_prominences = allProminences(sortIdx(uniqueIdx));
            
            allMetadata = [currentMetadata(:); newMetadata(:)];
            event_metadata = allMetadata(sortIdx(uniqueIdx));
        end
        
        updateTableWithEvents();
        currentShiftValue = 0;
        set(shiftEdit, 'String', '0');
        
        fprintf('Imported %d events from %s (click Apply to save changes)\n', numel(newEventTimes), sourceName);
    end
    
    function saveImportMode(~, ~)
        modeIndex = get(importModePopup, 'Value');
        modeOptions = get(importModePopup, 'String');
        selectedMode = modeOptions{modeIndex};
        
        try
            if exist(SettingsFilepath, 'file')
                event_import_mode = selectedMode;
                save(SettingsFilepath, 'event_import_mode', '-append');
            else
                warning('Settings file does not exist. Cannot save import mode.');
            end
        catch ME
            warning('Failed to save import mode: %s', ME.message);
        end
    end
    
    function mode = loadImportMode()
        mode = 'From file (add)';
        try
            if exist(SettingsFilepath, 'file')
                data = load(SettingsFilepath, 'event_import_mode');
                if isfield(data, 'event_import_mode')
                    mode = data.event_import_mode;
                end
            end
        catch
            mode = 'From file (add)';
        end
    end

    function saveExportMode(~, ~)
        modeIndex = get(exportModePopup, 'Value');
        modeOptions = get(exportModePopup, 'String');
        selectedMode = modeOptions{modeIndex};
        
        try
            if exist(SettingsFilepath, 'file')
                event_export_mode = selectedMode;
                save(SettingsFilepath, 'event_export_mode', '-append');
            else
                warning('Settings file does not exist. Cannot save export mode.');
            end
        catch ME
            warning('Failed to save export mode: %s', ME.message);
        end
    end
    
    function mode = loadExportMode()
        mode = 'To file';
        try
            if exist(SettingsFilepath, 'file')
                data = load(SettingsFilepath, 'event_export_mode');
                if isfield(data, 'event_export_mode')
                    mode = data.event_export_mode;
                end
            end
        catch
            mode = 'To file';
        end
    end

    function exportEvents(~, ~)
        if isempty(time)
            fprintf('Cannot export events: time vector is empty.\n');
            return;
        end
        
        tableData = get(eventTable, 'Data');
        if isempty(tableData)
            fprintf('No events to export.\n');
            return;
        end
        
        numericTimes = cellfun(@toNumericValue, tableData(:, 2));
        eventTimes = numericTimes / timeUnitFactor;
        
        if isempty(eventTimes)
            fprintf('No valid event times to export.\n');
            return;
        end
        
        numEvents = length(eventTimes);
        eventComments = tableData(:, 3);
        eventAmplitudes = cellfun(@toNumericValue, tableData(:, 4));
        eventChannels = cellfun(@toNumericValue, tableData(:, 5));
        eventWidths = cellfun(@toNumericValue, tableData(:, 6));
        eventProminences = cellfun(@toNumericValue, tableData(:, 7));
        eventMetadata = createDefaultEventMetadata('exported', numEvents);
        
        modeIndex = get(exportModePopup, 'Value');
        modeOptions = get(exportModePopup, 'String');
        selectedMode = modeOptions{modeIndex};
        
        isToFile = strcmp(selectedMode, 'To file');
        isReplace = contains(selectedMode, 'replace');
        
        if isToFile
            [~, eventIndicesForExport] = min(abs(time(:) - eventTimes(:)'), [], 1);
            eventIndicesForExport = eventIndicesForExport(:);
            saveEventsToFile(eventTimes, time, matFilePath, ...
                'event_indices', eventIndicesForExport, ...
                'event_comments', eventComments, ...
                'event_amplitudes', eventAmplitudes, ...
                'event_channels', eventChannels, ...
                'event_widths', eventWidths, ...
                'event_prominences', eventProminences, ...
                'event_metadata', eventMetadata, ...
                'dialogTitle', 'Save Events', ...
                'defaultFileNameSuffix', '_events', ...
                'matFileName', matFileName, ...
                'autodetection_settings', autodetection_settings, ...
                'add_event_settings', add_event_settings, ...
                'EV_version', EV_version);
        else
            if isReplace
                [sortedTimes, sortIdx] = sort(eventTimes);
                events = sortedTimes(:);
                event_comments = eventComments(sortIdx);
                event_amplitudes = eventAmplitudes(sortIdx);
                event_channels = eventChannels(sortIdx);
                event_widths = eventWidths(sortIdx);
                event_prominences = eventProminences(sortIdx);
                event_metadata = eventMetadata(sortIdx);
                [~, event_indices] = min(abs(time(:) - events(:)'), [], 1);
                event_indices = event_indices(:);
                events_exist = true;
            else
                if isempty(events)
                    [sortedTimes, sortIdx] = sort(eventTimes);
                    events = sortedTimes(:);
                    event_comments = eventComments(sortIdx);
                    event_amplitudes = eventAmplitudes(sortIdx);
                    event_channels = eventChannels(sortIdx);
                    event_widths = eventWidths(sortIdx);
                    event_prominences = eventProminences(sortIdx);
                    event_metadata = eventMetadata(sortIdx);
                else
                    existingEvents = events(:);
                    existingComments = event_comments;
                    existingAmplitudes = event_amplitudes;
                    existingChannels = event_channels;
                    existingWidths = event_widths;
                    existingProminences = event_prominences;
                    existingMetadata = event_metadata;
                    
                    allEvents = [existingEvents; eventTimes(:)];
                    [sortedEvents, sortIdx] = sort(allEvents);
                    [uniqueEvents, uniqueIdx] = unique(sortedEvents, 'stable');
                    
                    events = uniqueEvents(:);
                    
                    allComments = [existingComments(:); eventComments(:)];
                    event_comments = allComments(sortIdx(uniqueIdx));
                    
                    allAmplitudes = [existingAmplitudes(:); eventAmplitudes(:)];
                    event_amplitudes = allAmplitudes(sortIdx(uniqueIdx));
                    
                    if size(existingChannels, 2) == 1
                        allChannels = [existingChannels(:); eventChannels(:)];
                    else
                        allChannels = [existingChannels(:, 1); eventChannels(:)];
                    end
                    event_channels = allChannels(sortIdx(uniqueIdx));
                    
                    allWidths = [existingWidths(:); eventWidths(:)];
                    event_widths = allWidths(sortIdx(uniqueIdx));
                    
                    allProminences = [existingProminences(:); eventProminences(:)];
                    event_prominences = allProminences(sortIdx(uniqueIdx));
                    
                    allMetadata = [existingMetadata(:); eventMetadata(:)];
                    event_metadata = allMetadata(sortIdx(uniqueIdx));
                end
                [~, event_indices] = min(abs(time(:) - events(:)'), [], 1);
                event_indices = event_indices(:);
                events_exist = true;
            end
            
            if exist('table_calling', 'var') && ~isempty(table_calling)
                try
                    table_calling();
                catch ME
                    warning('Failed to update event table: %s', ME.message);
                end
            end
            
            if exist('updatePlotFunc', 'var') && ~isempty(updatePlotFunc)
                try
                    updatePlotFunc();
                catch ME
                    warning('Failed to update plot: %s', ME.message);
                end
            end
            
            fprintf('Exported %d events to memory (%s)\n', numEvents, selectedMode);
        end
    end

end

