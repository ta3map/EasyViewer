function SubMeanFigSettings()

    % Инициализация таблиц
    global channelNames mean_group_ch matFilePath
    
    
    label = 'Average subtraction settings';
    SubMeanFig = figure('Name', label, 'NumberTitle', 'off', ...
                'MenuBar', 'none', ... % Отключение стандартного меню
                'ToolBar', 'none',...
                'Position', [300  100  350  400]);
            
    if numel(channelNames)<2
        close(SubMeanFig);
    end
    tableData = [channelNames, num2cell(mean_group_ch)];
    position = [10, 50, 200, 350];
%     uicontrol('Style', 'text', 'String', label, 'Position', [position(1), position(2) + position(4) - 20, 100, 20], 'Parent', SubMeanFig);
    hTable = uitable('Data', tableData, ...
            'ColumnName', {'Channel', 'Enabled'}, ...
            'ColumnFormat', {'char', 'logical'}, ...
            'ColumnEditable', [false true], ...
            'Position', position, 'Parent', SubMeanFig);
    
    % Кнопка для нажатия всех каналов
    uicontrol('Style', 'pushbutton', 'String', 'Select ALL', 'Position', [220, 350, 110, 25], 'Callback', @selectAll);
    % Кнопка для отжатия всех каналов
    uicontrol('Style', 'pushbutton', 'String', 'Deselect ALL', 'Position', [220, 320, 110, 25], 'Callback', @deselectAll);
    
    % Button to save settings
    saveButton = uicontrol('Style', 'pushbutton', 'Position', [220, 250, 100, 25], 'String', 'Apply', 'Callback', @saveSettings);
    
    function selectAll(~, ~)
        hTable.Data(:,2) = num2cell(true(size(hTable.Data(:,2))));
    end
    
    function deselectAll(~, ~)
        hTable.Data(:,2) = num2cell(false(size(hTable.Data(:,2))));
    end
    
    function saveSettings(src, ~)
        updatedData = get(hTable, 'Data');
        mean_group_ch = [updatedData{:, 2}]';
        updatePlot();
        [path, name, ~] = fileparts(matFilePath);
        channelSettingsFilePath = fullfile(path, [name '_channelSettings.stn']);
        save(channelSettingsFilePath, 'mean_group_ch', '-append');
        close(SubMeanFig);
    end

end

