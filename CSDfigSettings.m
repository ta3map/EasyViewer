
function CSDfigSettings()

    % Инициализация таблиц
    global channelNames csd_avaliable matFilePath csd_resample_coef csd_smooth_coef csd_contrast_coef
        
    label = 'CSD Displaying Settings';
    SubMeanFig = figure('Name', label, 'NumberTitle', 'off', ...
                'MenuBar', 'none', ... % Отключение стандартного меню
                'ToolBar', 'none',...
                'Position', [300  100  350  400]);
            
    if numel(channelNames)<2
        close(SubMeanFig);
    end
    tableData = [channelNames, num2cell(csd_avaliable)];
    position = [10, 50, 200, 350];
    hTable = uitable('Data', tableData, ...
            'ColumnName', {'Channel', 'Enabled'}, ...
            'ColumnFormat', {'char', 'logical'}, ...
            'ColumnEditable', [false true], ...
            'Position', position, 'Parent', SubMeanFig);
        
    % Кнопка для нажатия всех каналов
    uicontrol('Style', 'pushbutton', 'String', 'Select ALL', 'Position', [220, 350, 110, 25], 'Callback', @selectAll);
    % Кнопка для отжатия всех каналов
    uicontrol('Style', 'pushbutton', 'String', 'Deselect ALL', 'Position', [220, 320, 110, 25], 'Callback', @deselectAll);
    
    % Поле для выбора значения contrast_coef
    uicontrol('Style', 'text', 'String', 'Contrast Coef:', 'Position', [220, 290, 100, 15], 'HorizontalAlignment', 'left');
    csdContrastCoeffEdit = uicontrol('Style', 'edit', 'String', num2str(csd_contrast_coef), 'Position', [220, 270, 100, 20], 'BackgroundColor', 'white');
    
    % Поле для выбора значения csd_smooth_coef
    uicontrol('Style', 'text', 'String', 'Smooth Coef:', 'Position', [220, 250, 100, 15], 'HorizontalAlignment', 'left');
    csdSmoothCoefEdit = uicontrol('Style', 'edit', 'String', num2str(csd_smooth_coef), 'Position', [220, 230, 100, 20], 'BackgroundColor', 'white');
    
    % Button to save settings
    saveButton = uicontrol('Style', 'pushbutton', 'Position', [220, 150, 100, 25], 'String', 'Apply', 'Callback', @saveSettings);
    
    function selectAll(~, ~)
        hTable.Data(:,2) = num2cell(true(size(hTable.Data(:,2))));
    end
    
    function deselectAll(~, ~)
        hTable.Data(:,2) = num2cell(false(size(hTable.Data(:,2))));
    end
    
    function saveSettings(src, ~)
        updatedData = get(hTable, 'Data');
        csd_avaliable = [updatedData{:, 2}]';
        csd_contrast_coef = str2double(get(csdContrastCoeffEdit, 'String')); % Обновление значения коэффициента
        csd_smooth_coef = str2double(get(csdSmoothCoefEdit, 'String')); % Обновление значения коэффициента
        updatePlot();
        [path, name, ~] = fileparts(matFilePath);
        channelSettingsFilePath = fullfile(path, [name '_channelSettings.stn']);
        save(channelSettingsFilePath, 'csd_avaliable', 'csd_smooth_coef', 'csd_contrast_coef', '-append');
        close(SubMeanFig);
    end

end
