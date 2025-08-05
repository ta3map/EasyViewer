function addEventSettingsUicontrol()
    global add_event_settings SettingsFilepath
    global channelTable
    
    % Идентификатор (tag) для GUI фигуры
    figTag = 'EventCreation';
    
    % Поиск открытой фигуры с заданным идентификатором
    guiFig = findobj('Type', 'figure', 'Tag', figTag);
    
    if ~isempty(guiFig)
        % Делаем существующее окно текущим (активным)
        figure(guiFig);
        return
    end
    
    updatedData = get(channelTable, 'Data');   
    
    line_n = 8;  % Увеличиваем для дополнительных настроек peak_detection
    
    top = 440;  % Увеличиваем высоту окна
    shift = (top*0.96)/line_n;
    
    % Creating the graphical interface
    fDet = figure('Name', 'Manual events settings', 'Tag', figTag, 'NumberTitle', 'off', ...
        'MenuBar', 'none', 'Position', [100, 100, 300, 480], ...
        'Resize', 'off');

    x1pos = 10;
    x2pos = 150;
    
    line1 = top - shift*1;
    line2 = top - shift*2;
    line3 = top - shift*3;
    line4 = top - shift*4;
    line5 = top - shift*5;
    line6 = top - shift*6;
    line7 = top - shift*7;  % Для Min Peak Height
    line8 = top - shift*8;  % Для Max Peak Width

    % Checking if the settings file exists
    if exist(SettingsFilepath, 'file')
        % Loading settings
        load(SettingsFilepath, 'add_event_settings');
    end

    if isempty(add_event_settings)
        % Initializing default settings structure
        add_event_settings.signal_type = 'lfp';
        add_event_settings.mode = 'manual';
        add_event_settings.channel = 1;  % Безопасное значение по умолчанию
        add_event_settings.polarity = 'positive';
        add_event_settings.timeWindow = 10;
        add_event_settings.minPeakHeight = 10;
        add_event_settings.maxPeakWidth = 50;
    end
    
    if ~isfield(add_event_settings, 'signal_type')
        add_event_settings.signal_type = 'lfp';
    end
    
    % Добавляем новые поля если их нет (для обратной совместимости)
    if ~isfield(add_event_settings, 'minPeakHeight')
        add_event_settings.minPeakHeight = 10;
    end
    if ~isfield(add_event_settings, 'maxPeakWidth')
        add_event_settings.maxPeakWidth = 50;
    end
    
    ch_inx = add_event_settings.channel;    
    channelNames = updatedData(:, 1)';
    
    % Проверяем и корректируем индекс канала если он выходит за границы
    if ch_inx > length(channelNames) || ch_inx < 1
        warning('Channel index %d is out of bounds for available channels (1-%d). Setting to channel 1.', ch_inx, length(channelNames));
        ch_inx = 1;
        add_event_settings.channel = 1;
    end

    % Creating a list for selecting the signal type
    uicontrol('Style', 'text', 'Position', [x1pos, line1, 100, 22], 'String', 'Signal source:');
    signalTypeList = uicontrol('Style', 'popupmenu', 'Position', [x2pos, line1, 100, 22], 'String', {'lfp', 'CSD'}, 'Value', find(strcmp({'lfp', 'CSD'}, add_event_settings.signal_type)));
    
    % Creating a list for selecting the detection mode
    uicontrol('Style', 'text', 'Position', [x1pos, line2, 100, 22], 'String', 'Detection Mode:');
    modeList = uicontrol('Style', 'popupmenu', 'Position', [x2pos, line2, 100, 22], 'String', {'manual', 'locked', 'peak_detection'}, 'Value', find(strcmp({'manual', 'locked', 'peak_detection'}, add_event_settings.mode)), 'Callback', @modeChanged);

    % Creating a list with data channel numbers
    uicontrol('Style', 'text', 'Position', [x1pos, line3, 100, 22], 'String', 'Channel Number:');
    popupChannel = uicontrol('Style', 'popupmenu', 'String', channelNames, 'Value', ch_inx, 'Position', [x2pos, line3, 100, 22]);

    % Creating a list for selecting polarity
    uicontrol('Style', 'text', 'Position', [x1pos, line4, 100, 22], 'String', 'Polarity:');
    polarityList = uicontrol('Style', 'popupmenu', 'Position', [x2pos, line4, 100, 22], 'String', {'positive', 'negative'}, 'Value', find(strcmp({'positive', 'negative'}, add_event_settings.polarity)));

    % Box for selecting the time window of detection
    uicontrol('Style', 'text', 'Position', [x1pos, line5, 100, 22], 'String', 'Time Window (ms):');
    timeWindow = uicontrol('Style', 'edit', 'Position', [x2pos, line5, 100, 22], 'String', num2str(add_event_settings.timeWindow));

    % Peak detection parameters (показываются только для peak_detection режима)
    minPeakHeightText = uicontrol('Style', 'text', 'Position', [x1pos, line7, 100, 22], 'String', 'Min Peak Height:', 'Visible', 'off');
    minPeakHeightEdit = uicontrol('Style', 'edit', 'Position', [x2pos, line7, 100, 22], 'String', num2str(add_event_settings.minPeakHeight), 'Visible', 'off');

    maxPeakWidthText = uicontrol('Style', 'text', 'Position', [x1pos, line8, 100, 22], 'String', 'Max Peak Width (ms):', 'Visible', 'off');
    maxPeakWidthEdit = uicontrol('Style', 'edit', 'Position', [x2pos, line8, 100, 22], 'String', num2str(add_event_settings.maxPeakWidth), 'Visible', 'off');

    % Button to save settings
    saveButton = uicontrol('Style', 'pushbutton', 'Position', [x2pos, line6, 100, 22], 'String', 'Save', 'Callback', @saveSettings);

    % Initial call to set the state of controls
    modeChanged();
    
    % Callback function to handle mode change
    function modeChanged(~, ~)
        modeValue = get(modeList, 'Value');
        
        if modeValue == 1  % manual mode
            set([popupChannel, polarityList, timeWindow], 'Enable', 'off');
            set([minPeakHeightText, minPeakHeightEdit, maxPeakWidthText, maxPeakWidthEdit], 'Visible', 'off');
            
        elseif modeValue == 2  % locked mode
            set([popupChannel, polarityList, timeWindow], 'Enable', 'on');
            set([minPeakHeightText, minPeakHeightEdit, maxPeakWidthText, maxPeakWidthEdit], 'Visible', 'off');
            
        elseif modeValue == 3  % peak_detection mode
            set([popupChannel, polarityList, timeWindow], 'Enable', 'on');
            set([minPeakHeightText, minPeakHeightEdit, maxPeakWidthText, maxPeakWidthEdit], 'Visible', 'on');
        end
    end

    % Function to save settings and close the figure
    function saveSettings(~, ~)
        ch_inx = popupChannel.Value;
        
        settings.signal_type = get(signalTypeList, 'String');
        settings.signal_type = settings.signal_type{get(signalTypeList, 'Value')};
        
        settings.mode = get(modeList, 'String');
        settings.mode = settings.mode{get(modeList, 'Value')};
        settings.polarity = get(polarityList, 'String');
        settings.polarity = settings.polarity{get(polarityList, 'Value')};
        settings.channel = ch_inx;
        settings.timeWindow = str2double(get(timeWindow, 'String'));
        
        % Сохраняем новые параметры peak_detection
        settings.minPeakHeight = str2double(get(minPeakHeightEdit, 'String'));
        settings.maxPeakWidth = str2double(get(maxPeakWidthEdit, 'String'));

        % Saving settings
        add_event_settings = settings;      
        save(SettingsFilepath, 'add_event_settings', '-append');
        close(fDet);
    end
end
