function addEventSettingsUicontrol()
    global add_event_settings
    
    % Creating the graphical interface
    fDet = figure('Name', 'Event Adding Settings', 'NumberTitle', 'off', 'MenuBar', 'none', 'Position', [100, 100, 300, 400]);
    x1pos = 10;
    x2pos = 150;
    
    line1 = 375;
    line2 = 325;
    line3 = 275;
    line4 = 225;
    line5 = 175;
    
    % Path to the settings file - replace with the necessary path
    settingsFilePath = fullfile(tempdir, 'last_opened_files.mat');   
    
    % Checking if the settings file exists
    if exist(settingsFilePath, 'file')
        % Loading settings
        load(settingsFilePath, 'add_event_settings');
    end
    
    if isempty(add_event_settings)
        % Initializing default settings structure
        add_event_settings.mode = 'freehand';
        add_event_settings.channel = 11;
        add_event_settings.polarity = 'positive';
        add_event_settings.timeWindow = 10;
    end
    
    % Creating a list for selecting the detection mode
    uicontrol('Style', 'text', 'Position', [x1pos, line1, 100, 22], 'String', 'Detection Mode:');
    modeList = uicontrol('Style', 'popupmenu', 'Position', [x2pos, line1, 100, 22], 'String', {'freehand', 'locked'}, 'Value', find(strcmp({'freehand', 'locked'}, add_event_settings.mode)));
    
    % Creating a list with data channel numbers
    uicontrol('Style', 'text', 'Position', [x1pos, line2, 100, 22], 'String', 'Channel Number:');
    channelList = uicontrol('Style', 'edit', 'Position', [x2pos, line2, 100, 22], 'String', num2str(add_event_settings.channel));

    % Creating a list for selecting polarity
    uicontrol('Style', 'text', 'Position', [x1pos, line3, 100, 22], 'String', 'Polarity:');
    polarityList = uicontrol('Style', 'popupmenu', 'Position', [x2pos, line3, 100, 22], 'String', {'positive', 'negative'}, 'Value', find(strcmp({'positive', 'negative'}, add_event_settings.polarity)));
    
    % Box for selecting the time window of detection
    uicontrol('Style', 'text', 'Position', [x1pos, line4, 100, 30], 'String', 'Time Window (ms):');
    timeWindow = uicontrol('Style', 'edit', 'Position', [x2pos, line4, 100, 22], 'String', num2str(add_event_settings.timeWindow));
    
    % Button to save settings
    saveButton = uicontrol('Style', 'pushbutton', 'Position', [x2pos, line5, 100, 22], 'String', 'Save', 'Callback', @saveSettings);
    
    % Function to save settings and close the figure
    function saveSettings(src, event)
%         settings.channel = str2double(get(channelList, 'String'));
%         settings.mode = get(modeList, 'String'){get(modeList, 'Value')};
%         settings.polarity = get(polarityList, 'String'){get(polarityList, 'Value')};
%         settings.timeWindow = str2double(get(timeWindow, 'String'));
        settings.mode = get(modeList, 'String');
        settings.mode = settings.mode{get(modeList, 'Value')};
        settings.polarity = get(polarityList, 'String');
        settings.polarity = settings.polarity{get(polarityList, 'Value')};
        settings.channel = str2double(get(channelList, 'String'));
        settings.timeWindow = str2double(get(timeWindow, 'String'));

        % Saving settings
        add_event_settings = settings;      
        save(settingsFilePath, 'add_event_settings', '-append');
        close(fDet);
    end
end