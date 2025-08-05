function editStimulusTimesGUI()
    % Function to edit stimulus times with comprehensive GUI interface
    % Allows user to shift, edit, and delete stimulus times
    
    % Global variables
    global stims timeUnitFactor selectedUnit saveChannelSettingsFunc

    % Check if stims exist
    if isempty(stims)
        errordlg('No stimulus times available to shift.', 'Error');
        return;
    end

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
                  'Tag', figTag, 'WindowStyle', 'modal');

    % Prepare data for table
    numStims = length(stims);
    stimData = cell(numStims, 2);
    for i = 1:numStims
        stimData{i, 1} = stims(i) * timeUnitFactor; % Time in current units
        stimData{i, 2} = true; % Selected by default
    end

    % Create UI elements
    uicontrol('Style', 'text', 'Position', [20, 510, 410, 20], ...
              'String', ['Edit Stimulus Times (' selectedUnit '):'], ...
              'HorizontalAlignment', 'left', 'FontWeight', 'bold');

    % Table for stimulus times
    stimTable = uitable('Parent', hFig, ...
                        'Position', [20, 220, 410, 280], ...
                        'Data', stimData, ...
                        'ColumnName', {['Time (' selectedUnit ')'], 'Selected'}, ...
                        'ColumnFormat', {'numeric', 'logical'}, ...
                        'ColumnEditable', [true true], ...
                        'ColumnWidth', {280, 80});

    % Selection control buttons
    selectAllButton = uicontrol('Style', 'pushbutton', 'Position', [20, 180, 120, 30], ...
                                'String', 'Deselect All', 'Callback', @toggleSelectAll);
    
    deleteButton = uicontrol('Style', 'pushbutton', 'Position', [150, 180, 120, 30], ...
                             'String', 'Delete Selected', 'Callback', @deleteSelected);

    % Shift operation section
    uicontrol('Style', 'text', 'Position', [20, 140, 200, 20], ...
              'String', ['Shift selected times by (' selectedUnit '):'], ...
              'HorizontalAlignment', 'left', 'FontWeight', 'bold');
    shiftEdit = uicontrol('Style', 'edit', 'Position', [20, 120, 100, 20], 'String', '0', 'Callback', @performShift);

    % Action buttons
    uicontrol('Style', 'pushbutton', 'Position', [20, 70, 100, 30], ...
              'String', 'Apply', 'Callback', @applyChanges);

    uicontrol('Style', 'pushbutton', 'Position', [130, 70, 100, 30], ...
              'String', 'Reset', 'Callback', @resetChanges);

    uicontrol('Style', 'pushbutton', 'Position', [240, 70, 100, 30], ...
              'String', 'Cancel', 'Callback', @cancelChanges);

    % Track selection state for toggle button and original data
    allSelected = true;
    originalStims = stims; % Keep original data for reset functionality
    originalStimData = stimData; % Keep original table data for reset functionality
    currentShiftValue = 0; % Track current shift value

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
            errordlg('No stimuli selected for deletion.', 'Error');
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
            currentTime = tableData{i, 1};
            newTime = currentTime + deltaShift;
            if newTime < 0
                newTime = 0;
            end
            tableData{i, 1} = newTime;
        end
        
        set(stimTable, 'Data', tableData);
    end

    function applyChanges(~, ~)
        % Get all data from table
        tableData = get(stimTable, 'Data');
        
        if isempty(tableData)
            errordlg('No stimulus times to apply.', 'Error');
            return;
        end
        
        % Extract times from table and convert to seconds
        newStimTimes = [tableData{:, 1}] / timeUnitFactor;
        
        % Validate times (must be non-negative)
        if any(newStimTimes < 0)
            errordlg('Stimulus times cannot be negative.', 'Error');
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
        
        % Close GUI
        close(hFig);
    end

    function resetChanges(~, ~)
        % Reset to original data
        stims_temp = originalStims;
        
        % Regenerate table data
        numStims = length(stims_temp);
        stimData = cell(numStims, 2);
        for i = 1:numStims
            stimData{i, 1} = stims_temp(i) * timeUnitFactor; % Time in current units
            stimData{i, 2} = true; % Selected by default
        end
        
        % Update original stimData for reset functionality
        originalStimData = stimData;
        
        set(stimTable, 'Data', stimData);
        set(shiftEdit, 'String', '0');
        currentShiftValue = 0; % Reset shift tracking
        
        % Reset selection button
        set(selectAllButton, 'String', 'Deselect All');
        allSelected = true;
    end

    function cancelChanges(~, ~)
        close(hFig);
    end

end 