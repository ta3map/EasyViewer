function activeChannels = CSDSettingsGUI()

    activeChannels = [];
    contrastCoefMin = 10;
    contrastCoefMax = 250;
    slider_max = 100;

    global channelNames csd_avaliable matFilePath csd_smooth_coef csd_contrast_coef
    global csd_contrast_is_display csd_split_by_channel_gaps

    % Идентификатор (tag) для GUI фигуры
    figTag = 'CSDSettingsGUI';
    
    % Поиск открытой фигуры с заданным идентификатором
    guiFig = findobj('Type', 'figure', 'Tag', figTag);
    
    if ~isempty(guiFig)
        % Делаем существующее окно текущим (активным)
        figure(guiFig);
        activeChannels = find(csd_avaliable);
        return
    end
    
    csd_contrast_coef = normalizeCsdContrastCoef(csd_contrast_coef);
    csd_contrast_is_display = true;
    
    label = 'CSD Displaying Settings';
    CSDSettingsFig = figure('Name', label, 'Tag', figTag, 'NumberTitle', 'off', ...
                'MenuBar', 'none', ... % Отключение стандартного меню
                'ToolBar', 'none', ...
                'Position', [300  100  350  400], ...
                'Resize', 'off',  'WindowStyle', 'modal');
            
    if numel(channelNames) < 2
        close(CSDSettingsFig);
    end
    
    tableData = [channelNames; num2cell(csd_avaliable)]';
    position = [10, 50, 200, 350];
    hTable = uitable('Data', tableData, ...
            'ColumnName', {'Channel', 'Enabled'}, ...
            'ColumnFormat', {'char', 'logical'}, ...
            'ColumnEditable', [false true], ...
            'Position', position, 'Parent', CSDSettingsFig);
        
    % Кнопка для нажатия всех каналов
    uicontrol('Style', 'pushbutton', 'String', 'Select ALL', 'Position', [220, 350, 110, 25], 'Callback', @selectAll);
    % Кнопка для отжатия всех каналов
    uicontrol('Style', 'pushbutton', 'String', 'Deselect ALL', 'Position', [220, 320, 110, 25], 'Callback', @deselectAll);
    
    uicontrol('Style', 'text', 'String', 'Contrast, %:', 'Position', [220, 290, 100, 15], 'HorizontalAlignment', 'left');
    
    initial_slider_value = slider_inverse_formula(csd_contrast_coef, contrastCoefMin, contrastCoefMax, slider_max);
    
    csdContrastSlider = uicontrol('Style', 'slider', 'Min', 0, 'Max', slider_max, 'Value', initial_slider_value, ...
                                  'Position', [220, 270, 100, 20], 'Callback', @slider_callback);
    
    csdContrastCoeffEdit = uicontrol('Style', 'edit', 'String', num2str(csd_contrast_coef, '%.3g'), 'Position', [220, 240, 100, 20], 'BackgroundColor', 'white', 'Enable', 'inactive');
    
    splitCheckbox = uicontrol('Style', 'checkbox', 'String', 'Split channel groups', ...
        'Position', [220, 200, 120, 20], 'Value', logical(csd_split_by_channel_gaps), ...
        'HorizontalAlignment', 'left');
    
    % Поле для выбора значения csd_smooth_coef
    uicontrol('Style', 'text', 'String', 'Smooth Coef:', 'Position', [220, 150, 100, 15], 'HorizontalAlignment', 'left');
    csdSmoothCoefEdit = uicontrol('Style', 'edit', 'String', num2str(csd_smooth_coef), 'Position', [220, 130, 100, 20], 'BackgroundColor', 'white');

    % Button to save settings
    uicontrol('Style', 'pushbutton', 'Position', [220, 50, 100, 25], 'String', 'Apply', 'Callback', @saveSettings);
    
    uiwait(CSDSettingsFig);
    
    function selectAll(~, ~)
        hTable.Data(:,2) = num2cell(true(size(hTable.Data(:,2))));
    end
    
    function deselectAll(~, ~)
        hTable.Data(:,2) = num2cell(false(size(hTable.Data(:,2))));
    end
    
    function slider_callback(~, ~)
        slider_value = csdContrastSlider.Value;
        csd_contrast_coef = slider_formula(slider_value, contrastCoefMin, contrastCoefMax, slider_max);
        set(csdContrastCoeffEdit, 'String', num2str(csd_contrast_coef, '%.3g'));
    end
    
function outCoef = slider_formula(slider_value, min_coef, max_coef, slider_max_local)
    outCoef = min_coef + ((max_coef - min_coef) * slider_value / slider_max_local);
end

function slider_value = slider_inverse_formula(inCoef, min_coef, max_coef, slider_max_local)
    slider_value = round((slider_max_local * (inCoef - min_coef) / (max_coef - min_coef)));
    slider_value = min(max(slider_value, 0), slider_max_local);
end
    function saveSettings(~, ~)
        updatedData = get(hTable, 'Data');
        csd_avaliable = np_flatten([updatedData{:, 2}]);
        activeChannels = find(csd_avaliable);
        slider_value = csdContrastSlider.Value;
        csd_contrast_coef = normalizeCsdContrastCoef(slider_formula(slider_value, contrastCoefMin, contrastCoefMax, slider_max));
        csd_contrast_is_display = true;
        csd_smooth_coef = str2double(get(csdSmoothCoefEdit, 'String'));
        csd_split_by_channel_gaps = logical(get(splitCheckbox, 'Value'));
        updatePlot();
        saveChannelSettings('csd_avaliable', 'csd_smooth_coef', 'csd_contrast_coef', 'csd_contrast_is_display', 'csd_split_by_channel_gaps');
        uiresume(CSDSettingsFig);
        close(CSDSettingsFig);
    end

end
