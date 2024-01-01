function CSDfigSettings()

    % Инициализация таблиц
    global channelNames csd_avaliable matFilePath
    
    
    label = 'CSD Displaying Settings';
    SubMeanFig = figure('Name', label, 'NumberTitle', 'off', ...
                'MenuBar', 'none', ... % Отключение стандартного меню
                'ToolBar', 'none',...
                'Position', [300  100  250  400]);
            
    if numel(channelNames)<2
        close(SubMeanFig);
    end
    tableData = [channelNames, num2cell(csd_avaliable)];
    position = [10, 50, 200, 350];
%     uicontrol('Style', 'text', 'String', label, 'Position', [position(1), position(2) + position(4) - 20, 100, 20], 'Parent', SubMeanFig);
    SubMeanSettings = uitable('Data', tableData, ...
            'ColumnName', {'Channel', 'Enabled'}, ...
            'ColumnFormat', {'char', 'logical'}, ...
            'ColumnEditable', [false true], ...
            'Position', position, 'Parent', SubMeanFig);
        
    % Button to save settings
    saveButton = uicontrol('Style', 'pushbutton', 'Position', [10, 10, 100, 22], 'String', 'Apply', 'Callback', @saveSettings);

    function saveSettings(src, ~)
        updatedData = get(SubMeanSettings, 'Data');
        csd_avaliable = [updatedData{:, 2}]';
        updatePlot();
        [path, name, ~] = fileparts(matFilePath);
        channelSettingsFilePath = fullfile(path, [name '_channelSettings.stn']);
        save(channelSettingsFilePath, 'csd_avaliable', '-append');
        close(SubMeanFig);
    end

end

