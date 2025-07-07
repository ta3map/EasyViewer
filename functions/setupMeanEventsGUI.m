function setupMeanEventsGUI()
    global t_mean_profile
    
    % Set a default value for t_mean_profile if it is not defined
    if isempty(t_mean_profile)
        t_mean_profile = 0; % Default averaging time in sec
    end

    % Identifier (tag) for the GUI figure
    figTag = 'OptionsMeanEvents';
    if activateOrCreateFigure(figTag)
        return
    end

    % Create and configure the main window
    fig = figure('Name', 'Options Mean Events', 'Tag', figTag, ...
        'NumberTitle', 'off', 'MenuBar', 'none', 'ToolBar', 'none', ...
        'Position', [100, 100, 450, 200], 'Resize', 'off', 'WindowStyle', 'modal');

    %-------------------------%
    % Create UI elements below
    %-------------------------%
    
    % Create a static text label for the averaging time
    uicontrol('Parent', fig, 'Style', 'text', 'String', 'Profile Time (sec):', ...
        'Position', [130, 150, 200, 20], 'HorizontalAlignment', 'center', 'FontSize', 11);
    
    % Create an edit box to display and modify the current averaging time
    editPos = [180, 100, 90, 30];  % [x, y, width, height]
    hEdit = uicontrol('Parent', fig, 'Style', 'edit', 'String', num2str(t_mean_profile, '%.2f'), ...
        'Position', editPos, 'FontSize', 12, 'Callback', @editCallback);
    
    % Create the decrease button "<"
    decButtonPos = [120, 100, 50, 30];
    uicontrol('Parent', fig, 'Style', 'pushbutton', 'String', '<', ...
        'Position', decButtonPos, 'FontSize', 12, 'Callback', @decreaseTime);
    
    % Create the increase button ">"
    incButtonPos = [280, 100, 50, 30];
    uicontrol('Parent', fig, 'Style', 'pushbutton', 'String', '>', ...
        'Position', incButtonPos, 'FontSize', 12, 'Callback', @increaseTime);
    
    % Create the OK button to close the window
    okButtonPos = [180, 50, 90, 30];
    uicontrol('Parent', fig, 'Style', 'pushbutton', 'String', 'OK', ...
        'Position', okButtonPos, 'FontSize', 12, 'Callback', @okCallback);
    
    %-------------------------%
    % Nested callback functions
    %-------------------------%

    % Callback for the edit box: updates t_mean_profile when user enters a value
    function editCallback(src, ~)
        % Get the string from the edit box and convert it to a number
        newVal = str2double(get(src, 'String'));
        if isnan(newVal)
            % If conversion fails, revert to the previous value and show an error dialog
            set(src, 'String', num2str(t_mean_profile, '%.2f'));
            errordlg('Please enter a valid number', 'Invalid Input');
        else
            t_mean_profile = newVal;
        end
    end

    % Callback for the decrease button: subtracts 0.01 sec from t_mean_profile
    function decreaseTime(~, ~)
        t_mean_profile = t_mean_profile - 0.01;
        set(hEdit, 'String', num2str(t_mean_profile, '%.2f'));
    end

    % Callback for the increase button: adds 0.01 sec to t_mean_profile
    function increaseTime(~, ~)
        t_mean_profile = t_mean_profile + 0.01;
        set(hEdit, 'String', num2str(t_mean_profile, '%.2f'));
    end

    % Callback for the OK button: closes the GUI window
    function okCallback(~, ~)
        close(fig);
    end

end
