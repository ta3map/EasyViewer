function editStimulusTimesGUI()
    % Function to edit stimulus times with comprehensive GUI interface
    % Allows user to shift, edit, and delete stimulus times
    
    % Global variables
    global stims timeUnitFactor selectedUnit saveChannelSettingsFunc
    global time matFilePath lastOpenedFiles events SettingsFilepath

    % Check if stims exist
    % Identifier (tag) for GUI figure
    figTag = 'editStimulusTimesGUI';
    
    % Search for open figure with given identifier
    guiFig = findobj('Type', 'figure', 'Tag', figTag);
    
    if ~isempty(guiFig)
        % Make existing window current (active)
        figure(guiFig);
        return
    end
    
    % Initialize GUI
    hFig = figure('Name', 'Edit Stimulus Times', 'NumberTitle', 'off', ...
                  'Position', [100, 100, 450, 550], 'Resize', 'off', ...
                  'NumberTitle', 'off', 'MenuBar', 'none', 'ToolBar', 'none', ...
                  'Tag', figTag, 'WindowStyle', 'normal');

    % Create UI elements
    uicontrol('Style', 'text', 'Position', [20, 510, 410, 20], ...
              'String', ['Edit Stimulus Times (' selectedUnit '):'], ...
              'HorizontalAlignment', 'left', 'FontWeight', 'bold');

    % Table for stimulus times
    stimTable = uitable('Parent', hFig, ...
                        'Position', [20, 220, 410, 280], ...
                        'Data', buildStimData(stims), ...
                        'ColumnName', {['Time (' selectedUnit ')'], 'Selected'}, ...
                        'ColumnFormat', {'char', 'logical'}, ...
                        'ColumnEditable', [true true], ...
                        'ColumnWidth', {280, 80});

    % Selection control buttons
    selectAllButton = uicontrol('Style', 'pushbutton', 'Position', [20, 180, 120, 30], ...
                                'String', 'Deselect All', 'Callback', @toggleSelectAll);
    
    deleteButton = uicontrol('Style', 'pushbutton', 'Position', [150, 180, 120, 30], ...
                             'String', 'Delete Selected', 'Callback', @deleteSelected);
    
    addStimulusButton = uicontrol('Style', 'pushbutton', 'Position', [280, 180, 120, 30], ...
                                  'String', 'Add Stimulus', 'Callback', @addStimulusTime);

    % Shift operation section
    uicontrol('Style', 'text', 'Position', [20, 140, 200, 20], ...
              'String', ['Shift selected times by (' selectedUnit '):'], ...
              'HorizontalAlignment', 'left', 'FontWeight', 'bold');
    shiftEdit = uicontrol('Style', 'edit', 'Position', [20, 120, 100, 20], 'String', '0');
    uicontrol('Style', 'pushbutton', 'Position', [130, 118, 80, 24], ...
              'String', 'Check', 'Callback', @performShift);

    % Import mode dropdown
    importModeOptions = {'From file (add)', 'From memory (add)', 'From file (replace)', 'From memory (replace)'};
    savedMode = loadImportMode();
    savedModeIndex = find(strcmp(importModeOptions, savedMode), 1);
    if isempty(savedModeIndex)
        savedModeIndex = 1;
    end
    
    uicontrol('Style', 'text', 'Position', [20, 100, 150, 20], ...
              'String', 'Import mode:', 'HorizontalAlignment', 'left');
    importModePopup = uicontrol('Style', 'popupmenu', 'Position', [20, 80, 200, 25], ...
                                'String', importModeOptions, ...
                                'Value', savedModeIndex, ...
                                'Callback', @saveImportMode);
    
    % Action buttons
    uicontrol('Style', 'pushbutton', 'Position', [230, 78, 100, 30], ...
              'String', 'Import', 'Callback', @importStimuli);

    uicontrol('Style', 'pushbutton', 'Position', [20, 40, 100, 30], ...
              'String', 'Reset', 'Callback', @resetChanges);

    uicontrol('Style', 'pushbutton', 'Position', [130, 40, 100, 30], ...
              'String', 'Cancel', 'Callback', @cancelChanges);

    uicontrol('Style', 'pushbutton', 'Position', [240, 40, 100, 30], ...
              'String', 'Apply', 'Callback', @applyChanges);
    
    uicontrol('Style', 'pushbutton', 'Position', [350, 40, 80, 30], ...
              'String', 'Close', 'Callback', @closeWindow);

    % Track selection state for toggle button and original data
    allSelected = true;
    originalStims = stims; % Keep original data for reset functionality
    currentShiftValue = 0; % Track current shift value

    function data = buildStimData(stimArray)
        numCurrentStims = length(stimArray);
        data = cell(numCurrentStims, 2);
        for idx = 1:numCurrentStims
            data{idx, 1} = formatStimValue(stimArray(idx) * timeUnitFactor);
            data{idx, 2} = true;
        end
    end

    function updateTableWithStims(stimArray)
        set(stimTable, 'Data', buildStimData(stimArray));
        if isempty(stimArray)
            set(selectAllButton, 'String', 'Select All');
            allSelected = false;
        else
            set(selectAllButton, 'String', 'Deselect All');
            allSelected = true;
        end
    end

    function toggleSelectAll(~, ~)
        tableData = get(stimTable, 'Data');
        if allSelected
            % Deselect all
            tableData(:, 2) = {false};
            set(selectAllButton, 'String', 'Select All');
            allSelected = false;
        else
            % Select all
            tableData(:, 2) = {true};
            set(selectAllButton, 'String', 'Deselect All');
            allSelected = true;
        end
        set(stimTable, 'Data', tableData);
    end

    function deleteSelected(~, ~)
        tableData = get(stimTable, 'Data');
        selectedMask = [tableData{:, 2}];
        selectedIndices = find(selectedMask);
        
        if isempty(selectedIndices)
            fprintf('No stimuli selected for deletion.\n');
            return;
        end
        
        % Confirm deletion
        answer = questdlg(sprintf('Delete %d selected stimulus times?', length(selectedIndices)), ...
                         'Confirm Deletion', 'Yes', 'No', 'No');
        if strcmp(answer, 'Yes')
            % Remove selected rows from table
            tableData(selectedIndices, :) = [];
            
            set(stimTable, 'Data', tableData);
            
            % Update selection button state
            if size(tableData, 1) == 0
                set(selectAllButton, 'String', 'Select All');
                allSelected = false;
            end
        end
    end

    function performShift(~, ~)
        % Get shift amount
        shiftStr = get(shiftEdit, 'String');
        shiftAmount = str2double(shiftStr);
        
        if isnan(shiftAmount)
            shiftAmount = 0; % Default to 0 if invalid input
        end
        
        % Calculate relative shift (difference from previous value)
        deltaShift = shiftAmount - currentShiftValue;
        currentShiftValue = shiftAmount;
        
        % Get current table data and selection state
        tableData = get(stimTable, 'Data');
        selectedMask = [tableData{:, 2}];
        selectedIndices = find(selectedMask);
        
        % Apply relative shift to selected rows
        for i = selectedIndices
            currentTime = toNumericTime(tableData{i, 1});
            newTime = currentTime + deltaShift;
            if newTime < 0
                newTime = 0;
            end
            tableData{i, 1} = formatStimValue(newTime);
        end
        
        set(stimTable, 'Data', tableData);
    end

    function applyChanges(~, ~)
        % Get all data from table
        tableData = get(stimTable, 'Data');
        
        % Extract times from table and convert to seconds
        if isempty(tableData)
            newStimTimes = [];
        else
            numericTimes = cellfun(@toNumericTime, tableData(:, 1));
            newStimTimes = numericTimes / timeUnitFactor;
        end
        
        % Validate times (must be non-negative)
        if any(newStimTimes < 0)
            fprintf('Stimulus times cannot be negative.\n');
            return;
        end
        
        % Update global stims variable
        stims = newStimTimes(:); % Ensure column vector
        
        % Sort stims to maintain order
        [stims, ~] = sort(stims);
        
        % Save channel settings to preserve shifted stimulus times
        saveChannelSettingsFunc();
        
        % Update plot
        updatePlot();
        
        % Reset collective shift input
        set(shiftEdit, 'String', '0');
        currentShiftValue = 0;
    end

    function resetChanges(~, ~)
        % Reset to original data
        stims_temp = originalStims;
        
        updateTableWithStims(stims_temp);
        set(shiftEdit, 'String', '0');
        currentShiftValue = 0; % Reset shift tracking
        
        % Reset selection button
        set(selectAllButton, 'String', 'Deselect All');
        allSelected = true;
    end

    function cancelChanges(~, ~)
        close(hFig);
    end
    
    function closeWindow(~, ~)
        close(hFig);
    end
    
    function strValue = formatStimValue(value)
        strValue = sprintf('%.3f', value);
    end
    
    function numericValue = toNumericTime(value)
        if isnumeric(value)
            numericValue = value;
        else
            numericValue = str2double(value);
        end
        
        if isnan(numericValue)
            numericValue = 0;
        end
    end

    function addStimulusTime(~, ~)
        prompt = {['Enter stimulus time (' selectedUnit '):']};
        answer = inputdlg(prompt, 'Add Stimulus', 1, {'0'});
        if isempty(answer)
            return;
        end
        
        newTime = str2double(answer{1});
        if isnan(newTime) || newTime < 0
            fprintf('Invalid stimulus time.\n');
            return;
        end
        
        tableData = get(stimTable, 'Data');
        tableData(end + 1, :) = {formatStimValue(newTime), true};
        set(stimTable, 'Data', tableData);
        
        set(selectAllButton, 'String', 'Deselect All');
        allSelected = true;
    end

    function importStimuli(~, ~)
        if isempty(time)
            fprintf('Cannot import stimuli: time vector is empty.\n');
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
                    % fallback to pwd
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
            
            newStims = time(eventIndices(:));
            sourceName = fileName;
        else
            if isempty(events)
                fprintf('No events in memory. Please load events first.\n');
                return;
            end
            
            newStims = events(:);
            sourceName = 'memory';
        end
        
        if isReplace
            newStimsSorted = sort(newStims);
        else
            tableData = get(stimTable, 'Data');
            if isempty(tableData)
                currentStims = [];
            else
                numericTimes = cellfun(@toNumericTime, tableData(:, 1));
                currentStims = numericTimes / timeUnitFactor;
            end
            
            allStims = [currentStims(:); newStims(:)];
            allStims = unique(allStims);
            newStimsSorted = sort(allStims);
        end
        
        updateTableWithStims(newStimsSorted);
        currentShiftValue = 0;
        set(shiftEdit, 'String', '0');
        
        fprintf('Imported %d stimuli from %s (click Apply to save changes)\n', numel(newStims), sourceName);
    end
    
    function saveImportMode(~, ~)
        modeIndex = get(importModePopup, 'Value');
        modeOptions = get(importModePopup, 'String');
        selectedMode = modeOptions{modeIndex};
        
        try
            if exist(SettingsFilepath, 'file')
                stimulus_import_mode = selectedMode;
                save(SettingsFilepath, 'stimulus_import_mode', '-append');
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
                data = load(SettingsFilepath, 'stimulus_import_mode');
                if isfield(data, 'stimulus_import_mode')
                    mode = data.stimulus_import_mode;
                end
            end
        catch
            mode = 'From file (add)';
        end
    end

end 