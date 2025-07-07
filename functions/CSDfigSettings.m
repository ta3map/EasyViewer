function CSDfigSettings()

    min_coef = 98;
    max_coef = 200;
    slider_max = 100;

    % Идентификатор (tag) для GUI фигуры
    figTag = 'CSDfigSettings';
    
    % Поиск открытой фигуры с заданным идентификатором
    guiFig = findobj('Type', 'figure', 'Tag', figTag);
    
    if ~isempty(guiFig)
        % Делаем существующее окно текущим (активным)
        figure(guiFig);
        return
    end
    
    % Инициализация таблиц
    global channelNames csd_avaliable matFilePath csd_smooth_coef csd_contrast_coef
    
    label = 'CSD Displaying Settings';
    CSDfigSettingsFig = figure('Name', label, 'Tag', figTag, 'NumberTitle', 'off', ...
                'MenuBar', 'none', ... % Отключение стандартного меню
                'ToolBar', 'none', ...
                'Position', [300  100  350  400], ...
                'Resize', 'off',  'WindowStyle', 'modal');
            
    if numel(channelNames) < 2
        close(CSDfigSettingsFig);
    end
    
    tableData = [channelNames; num2cell(csd_avaliable)]';
    position = [10, 50, 200, 350];
    hTable = uitable('Data', tableData, ...
            'ColumnName', {'Channel', 'Enabled'}, ...
            'ColumnFormat', {'char', 'logical'}, ...
            'ColumnEditable', [false true], ...
            'Position', position, 'Parent', CSDfigSettingsFig);
        
    % Кнопка для нажатия всех каналов
    uicontrol('Style', 'pushbutton', 'String', 'Select ALL', 'Position', [220, 350, 110, 25], 'Callback', @selectAll);
    % Кнопка для отжатия всех каналов
    uicontrol('Style', 'pushbutton', 'String', 'Deselect ALL', 'Position', [220, 320, 110, 25], 'Callback', @deselectAll);
    
    % Поле для выбора значения contrast_coef
    uicontrol('Style', 'text', 'String', 'Contrast Coef:', 'Position', [220, 290, 100, 15], 'HorizontalAlignment', 'left');
    
    % Calculate the initial slider value based on the csd_contrast_coef
    initial_slider_value = slider_inverse_formula(csd_contrast_coef, min_coef, max_coef, slider_max);
    
    % Слайдер для выбора значения csd_contrast_coef
    csdContrastSlider = uicontrol('Style', 'slider', 'Min', 0, 'Max', slider_max, 'Value', initial_slider_value, ...
                                  'Position', [220, 270, 100, 20], 'Callback', @slider_callback);
    
    % Поле для отображения значения csd_contrast_coef
    csdContrastCoeffEdit = uicontrol('Style', 'edit', 'String', num2str(csd_contrast_coef), 'Position', [220, 240, 100, 20], 'BackgroundColor', 'white', 'Enable', 'inactive');
    
    % Поле для выбора значения csd_smooth_coef
    uicontrol('Style', 'text', 'String', 'Smooth Coef:', 'Position', [220, 150, 100, 15], 'HorizontalAlignment', 'left');
    csdSmoothCoefEdit = uicontrol('Style', 'edit', 'String', num2str(csd_smooth_coef), 'Position', [220, 130, 100, 20], 'BackgroundColor', 'white');
    
    % Button to save settings
    uicontrol('Style', 'pushbutton', 'Position', [220, 50, 100, 25], 'String', 'Apply', 'Callback', @saveSettings);
    
    uiwait(CSDfigSettingsFig);
    
    function selectAll(~, ~)
        hTable.Data(:,2) = num2cell(true(size(hTable.Data(:,2))));
    end
    
    function deselectAll(~, ~)
        hTable.Data(:,2) = num2cell(false(size(hTable.Data(:,2))));
    end
    
    function slider_callback(~, ~)
        slider_value = csdContrastSlider.Value;
        % Update csd_contrast_coef based on the slider value
        csd_contrast_coef = slider_formula(slider_value, min_coef, max_coef, slider_max);
        set(csdContrastCoeffEdit, 'String', num2str(csd_contrast_coef));
    end
    
function csd_contrast_coef = slider_formula(slider_value, min_coef, max_coef, slider_max)
    % min_coef - минимальное значение диапазона csd_contrast_coef
    % max_coef - максимальное значение диапазона csd_contrast_coef
    % slider_max - максимальное значение диапазона слайдера
    csd_contrast_coef = min_coef + ((max_coef - min_coef) * slider_value / slider_max);
end

function slider_value = slider_inverse_formula(csd_contrast_coef, min_coef, max_coef, slider_max)
    % min_coef - минимальное значение диапазона csd_contrast_coef
    % max_coef - максимальное значение диапазона csd_contrast_coef
    % slider_max - максимальное значение диапазона слайдера
    slider_value = round((slider_max * (csd_contrast_coef - min_coef) / (max_coef - min_coef)));
end
    function saveSettings(~, ~)
        updatedData = get(hTable, 'Data');
        csd_avaliable = np_flatten([updatedData{:, 2}]);
        % Update csd_contrast_coef from the slider value
        slider_value = csdContrastSlider.Value;
        csd_contrast_coef = slider_formula(slider_value, min_coef, max_coef, slider_max);
        csd_smooth_coef = str2double(get(csdSmoothCoefEdit, 'String')); % Обновление значения коэффициента
        updatePlot();
        [path, name, ~] = fileparts(matFilePath);
        channelSettingsFilePath = fullfile(path, [name '_channelSettings.stn']);
        save(channelSettingsFilePath, 'csd_avaliable', 'csd_smooth_coef', 'csd_contrast_coef', '-append');
        uiresume(CSDfigSettingsFig);
        close(CSDfigSettingsFig);
    end

end
