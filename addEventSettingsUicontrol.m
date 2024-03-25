function addEventSettingsUicontrol()
    global add_event_settings SettingsFilepath
    global channelTable
    updatedData = get(channelTable, 'Data');   
    
    shift = 150;
    % Creating the graphical interface
    fDet = figure('Name', 'Event Creation Settings', 'NumberTitle', 'off', ...
        'MenuBar', 'none', 'Position', [100, 100, 300, 400-shift], ...
        'Resize', 'off');
    
    x1pos = 10;
    x2pos = 150;
    
    line1 = 375 - shift;
    line2 = 325 - shift;
    line3 = 275 - shift;
    line4 = 225 - shift;
    line5 = 175 - shift;

    
    % Checking if the settings file exists
    if exist(SettingsFilepath, 'file')
        % Loading settings
        load(SettingsFilepath, 'add_event_settings');
    end
    
    if isempty(add_event_settings)
        % Initializing default settings structure
        add_event_settings.mode = 'manual';
        add_event_settings.channel = 11;
        add_event_settings.polarity = 'positive';
        add_event_settings.timeWindow = 10;
    end
    
    ch_inx = add_event_settings.channel;    
%     ch_label = updatedData(ch_inx, 1)';
    channelNames = updatedData(:, 1)';
    
    % Creating a list for selecting the detection mode
    uicontrol('Style', 'text', 'Position', [x1pos, line1, 100, 22], 'String', 'Detection Mode:');
    modeList = uicontrol('Style', 'popupmenu', 'Position', [x2pos, line1, 100, 22], 'String', {'manual', 'locked'}, 'Value', find(strcmp({'manual', 'locked'}, add_event_settings.mode)));
    
    % Creating a list with data channel numbers
    uicontrol('Style', 'text', 'Position', [x1pos, line2, 100, 22], 'String', 'Channel Number:');
%     channelList = uicontrol('Style', 'edit', 'Position', [x2pos, line2, 40, 22], 'String', num2str(add_event_settings.channel), 'Callback', @channelChanged);
%     channelName = uicontrol('Style', 'text', 'Position', [x2pos+50, line2, 100, 22], 'String', ch_label);
    
    % Выпадающий список для выбора канала
    popupChannel = uicontrol('Style', 'popupmenu',...
                      'String', channelNames,...
                      'Value',ch_inx,...
                      'Position', [x2pos, line2, 100, 22]);
                  
    % Creating a list for selecting polarity
    uicontrol('Style', 'text', 'Position', [x1pos, line3, 100, 22], 'String', 'Polarity:');
    polarityList = uicontrol('Style', 'popupmenu', 'Position', [x2pos, line3, 100, 22], 'String', {'positive', 'negative'}, 'Value', find(strcmp({'positive', 'negative'}, add_event_settings.polarity)));
    
    % Box for selecting the time window of detection
    uicontrol('Style', 'text', 'Position', [x1pos, line4, 100, 30], 'String', 'Time Window (ms):');
    timeWindow = uicontrol('Style', 'edit', 'Position', [x2pos, line4, 100, 22], 'String', num2str(add_event_settings.timeWindow));
    
    % Button to save settings
    saveButton = uicontrol('Style', 'pushbutton', 'Position', [x2pos, line5, 100, 22], 'String', 'Save', 'Callback', @saveSettings);
    
%     function channelChanged(~,~)
%         ch_inx = str2double(get(channelList, 'String')); 
%         ch_label = updatedData(ch_inx, 1)';
%         set(channelName, 'String', ch_label);
%     end

    % Function to save settings and close the figure
    function saveSettings(src, event)
        ch_inx = popupChannel.Value;
        
        settings.mode = get(modeList, 'String');
        settings.mode = settings.mode{get(modeList, 'Value')};
        settings.polarity = get(polarityList, 'String');
        settings.polarity = settings.polarity{get(polarityList, 'Value')};
        settings.channel = ch_inx;
        settings.timeWindow = str2double(get(timeWindow, 'String'));

        % Saving settings
        add_event_settings = settings;      
        save(SettingsFilepath, 'add_event_settings', '-append');
        close(fDet);
    end
end