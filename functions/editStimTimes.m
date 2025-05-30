function editStimTimes()
    % Function to edit stimulation times in the global variable 'stims'
    % Provides a GUI to add, delete, shift, and edit stimulation times.
    % Enhancements:
    % 1. Uses timeUnitFactor and selectedUnit for unit conversion and display.
    % 2. Combined "Select All" and "Deselect All" into a toggle button.
    % 3. Removed "Update Display" button; updatePlot() is called after changes.

    % Global variables
    global stims time timeUnitFactor selectedUnit 

    % Tag for GUI figure
    figTag = 'editStimTimes';

    % Check if the figure already exists
    guiFig = findobj('Type', 'figure', 'Tag', figTag);
    if ~isempty(guiFig)
        figure(guiFig);
        return;
    end

    % Create the figure
    fig = figure('Name', 'Edit Stimulation Times', 'NumberTitle', 'off', ...
                 'Position', [100, 100, 600, 500], 'Resize', 'off', ...
                 'MenuBar', 'none', 'ToolBar', 'none', ...
                 'Tag', figTag, 'WindowStyle', 'normal', ...
                 'KeyPressFcn', @figureKeyPressCallback);

    % Generate stimulus strings with numbering and unit conversion
    stimStrings = arrayfun(@(idx, stimTime) ...
        sprintf('%d: %.3f %s', idx, stimTime * timeUnitFactor, selectedUnit), ...
        (1:length(stims))', stims, 'UniformOutput', false);

    % Stimulus Times Listbox
    uicontrol('Style', 'text', 'Position', [50, 460, 500, 20], ...
              'String', ['Current Stimulus Times (' selectedUnit '):']);
    stimListbox = uicontrol('Style', 'listbox', 'Position', [50, 200, 500, 230], ...
                            'String', stimStrings, 'Max', 2, 'Min', 0, ...
                            'KeyPressFcn', @listboxKeyPressCallback);

    % Buttons and controls
    % Toggle Select/Deselect All button (moved position)
    isAllSelected = false;
    toggleSelectButton = uicontrol('Style', 'pushbutton', 'Position', [50, 430, 160, 30], ...
                                   'String', 'Select All', 'Callback', @toggleSelectAll);

    % Delete selected stimuli
    uicontrol('Style', 'pushbutton', 'Position', [50, 160, 100, 30], ...
              'String', 'Delete Selected', 'Callback', @deleteSelected);

    % Shift selected stimuli
    uicontrol('Style', 'pushbutton', 'Position', [170, 160, 100, 30], ...
              'String', 'Shift Selected', 'Callback', @shiftSelected);

    % Edit time of selected stimulus
    uicontrol('Style', 'pushbutton', 'Position', [290, 160, 100, 30], ...
              'String', 'Edit Time', 'Callback', @editTime);

    % Add new stimulus
    uicontrol('Style', 'pushbutton', 'Position', [410, 160, 100, 30], ...
              'String', 'Add Stimulus', 'Callback', @addStimulus);

    % Add periodic stimuli
    uicontrol('Style', 'pushbutton', 'Position', [50, 120, 150, 30], ...
              'String', 'Add Periodic Stimuli', 'Callback', @addPeriodicStimuli);

    % Function callbacks

    function listboxKeyPressCallback(src, event)
        if strcmp(event.Key, 'a') && ismember('control', event.Modifier)
            % Ctrl+A pressed
            set(src, 'Value', 1:length(stims));
            set(toggleSelectButton, 'String', 'Deselect All');
            isAllSelected = true;
        end
    end

    function figureKeyPressCallback(~, event)
        if strcmp(event.Key, 'a') && ismember('control', event.Modifier)
            % Ctrl+A pressed
            set(stimListbox, 'Value', 1:length(stims));
            set(toggleSelectButton, 'String', 'Deselect All');
            isAllSelected = true;
        end
    end

    function toggleSelectAll(~, ~)
        if isAllSelected
            % Deselect all items
            set(stimListbox, 'Value', []);
            set(toggleSelectButton, 'String', 'Select All');
            isAllSelected = false;
        else
            % Select all items
            set(stimListbox, 'Value', 1:length(stims));
            set(toggleSelectButton, 'String', 'Deselect All');
            isAllSelected = true;
        end
    end

    function deleteSelected(~, ~)
        % Get selected indices
        selectedIndices = get(stimListbox, 'Value');
        if isempty(selectedIndices)
            errordlg('No stimuli selected for deletion.', 'Error');
            return;
        end
        % Confirm deletion
        choice = questdlg('Are you sure you want to delete the selected stimuli?', ...
            'Confirm Deletion', 'Yes', 'No', 'No');
        if strcmp(choice, 'Yes')
            % Delete the selected stimuli
            stims(selectedIndices) = [];
            % Call the updatePlot function
            updatePlot();
            % Close the GUI window after successful operation
            close(fig);
        end
    end

    function shiftSelected(~, ~)
        % Get selected indices
        selectedIndices = get(stimListbox, 'Value');
        if isempty(selectedIndices)
            errordlg('No stimuli selected for shifting.', 'Error');
            return;
        end
        % Prompt for shift amount in selectedUnit
        promptMsg = ['Enter time shift in ' selectedUnit ' (positive or negative):'];
        answer = inputdlg(promptMsg, 'Shift Stimuli', 1, {'0'});
        if isempty(answer)
            return;
        end
        shiftAmount = str2double(answer{1});
        if isnan(shiftAmount)
            errordlg('Invalid shift amount.', 'Error');
            return;
        end
        % Convert shiftAmount to seconds
        shiftAmountSec = shiftAmount / timeUnitFactor;
        % Shift the selected stimuli
        stims(selectedIndices) = stims(selectedIndices) + shiftAmountSec;
        % Ensure that stims remain within valid time range
        stims(stims < 0) = 0; % Assuming time cannot be negative
        % Call the updatePlot function
        updatePlot();
        % Close the GUI window after successful operation
        close(fig);
    end

    function editTime(~, ~)
        % Get selected index (only one)
        selectedIndices = get(stimListbox, 'Value');
        if length(selectedIndices) ~= 1
            errordlg('Please select a single stimulus to edit.', 'Error');
            return;
        end
        % Prompt for new time in selectedUnit
        promptMsg = ['Enter new time for the selected stimulus (in ' selectedUnit '):'];
        currentValue = stims(selectedIndices) * timeUnitFactor;
        answer = inputdlg(promptMsg, 'Edit Stimulus Time', 1, {num2str(currentValue)});
        if isempty(answer)
            return;
        end
        newTime = str2double(answer{1});
        if isnan(newTime)
            errordlg('Invalid time entered.', 'Error');
            return;
        end
        % Convert newTime to seconds
        newTimeSec = newTime / timeUnitFactor;
        % Update the stimulus time
        stims(selectedIndices) = newTimeSec;
        % Call the updatePlot function
        updatePlot();
        % Close the GUI window after successful operation
        close(fig);
    end

    function addStimulus(~, ~)
        % Prompt for new stimulus time in selectedUnit
        promptMsg = ['Enter time for new stimulus (in ' selectedUnit '):'];
        answer = inputdlg(promptMsg, 'Add Stimulus', 1, {'0'});
        if isempty(answer)
            return;
        end
        newTime = str2double(answer{1});
        if isnan(newTime)
            errordlg('Invalid time entered.', 'Error');
            return;
        end
        % Convert newTime to seconds
        newTimeSec = newTime / timeUnitFactor;
        % Add the new stimulus
        stims = [stims; newTimeSec];
        % Sort the stims array
        [stims, ~] = sort(stims);
        % Call the updatePlot function
        updatePlot();
        % Close the GUI window after successful operation
        close(fig);
    end

    function addPeriodicStimuli(~, ~)
        % Prompt for start time, end time, interval in selectedUnit
        if isempty(time)
            errordlg('Global variable ''time'' is not defined.', 'Error');
            return;
        end
        prompt = {['Start Time (' selectedUnit '):'], ...
                  ['End Time (' selectedUnit '):'], ...
                  ['Interval between stimuli (' selectedUnit '):']};
        defaultValues = {'0', num2str(time(end) * timeUnitFactor), '1'};
        answer = inputdlg(prompt, 'Add Periodic Stimuli', 1, defaultValues);
        if isempty(answer)
            return;
        end
        startTime = str2double(answer{1});
        endTime = str2double(answer{2});
        interval = str2double(answer{3});
        if any(isnan([startTime, endTime, interval])) || interval <= 0
            errordlg('Invalid parameters entered.', 'Error');
            return;
        end
        % Convert times to seconds
        startTimeSec = startTime / timeUnitFactor;
        endTimeSec = endTime / timeUnitFactor;
        intervalSec = interval / timeUnitFactor;
        % Generate stimuli times
        newStims = (startTimeSec:intervalSec:endTimeSec)';
        % Add to stims
        stims = [stims; newStims];
        % Sort the stims array
        [stims, ~] = sort(stims);
        % Call the updatePlot function
        updatePlot();
        % Close the GUI window after successful operation
        close(fig);
    end

end
