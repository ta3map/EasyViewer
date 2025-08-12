function measurementPropertiesGUI(measurement_index)
    % Окно свойств измерения - открывается при двойном клике на строку в таблице измерений
    
    global multiple_measurements
    
    if isempty(multiple_measurements) || measurement_index > length(multiple_measurements)
        fprintf('❌ Некорректный индекс измерения\n');
        return;
    end
    
    % Идентификатор (tag) для GUI фигуры
    figTag = sprintf('MeasurementProperties_%d', measurement_index);
    
    % Поиск открытой фигуры с заданным идентификатором
    guiFig = findobj('Type', 'figure', 'Tag', figTag);
    
    if ~isempty(guiFig)
        % Делаем существующее окно текущим (активным)
        figure(guiFig);
        return;
    end
    
    % Получаем текущие настройки измерения
    measurement = multiple_measurements(measurement_index);
    
    % Создание главного окна
    fig = figure('Name', sprintf('Properties - Measurement #%d', measurement_index), ...
        'Tag', figTag, 'NumberTitle', 'off', 'MenuBar', 'none', 'ToolBar', 'none', ...
        'Position', [200, 200, 400, 500], 'Resize', 'off', 'WindowStyle', 'modal', ...
        'CloseRequestFcn', @(src,~)closeRequest(src));
    
    % Позиционные переменные
    leftMargin = 20;
    topMargin = 450;
    labelWidth = 150;
    controlWidth = 200;
    controlHeight = 25;
    spacing = 35;
    
    currentY = topMargin;
    
    % === Функция измерения ===
    uicontrol(fig, 'Style', 'text', 'Position', [leftMargin, currentY, labelWidth, controlHeight], ...
        'String', 'Measurement Function:', 'HorizontalAlignment', 'left');
    hFunctionPopup = uicontrol(fig, 'Style', 'popupmenu', ...
        'Position', [leftMargin + labelWidth + 10, currentY, controlWidth, controlHeight], ...
        'String', {'Mean', 'Max', 'Min', 'Std', 'Peak', 'RMS', 'Slope'}, ...
        'Value', getFunctionIndex(measurement.function_type), ...
        'Callback', @(src,~)updateFunction(src, measurement_index));
    
    currentY = currentY - spacing;
    
    % === Цвет линии ===
    uicontrol(fig, 'Style', 'text', 'Position', [leftMargin, currentY, labelWidth, controlHeight], ...
        'String', 'Line Color:', 'HorizontalAlignment', 'left');
    hColorPopup = uicontrol(fig, 'Style', 'popupmenu', ...
        'Position', [leftMargin + labelWidth + 10, currentY, controlWidth, controlHeight], ...
        'String', {'Red', 'Green', 'Blue', 'Magenta', 'Cyan', 'Yellow', 'Black', 'White'}, ...
        'Value', getColorIndex(measurement.line_color), ...
        'Callback', @(src,~)updateColor(src, measurement_index));
    
    currentY = currentY - spacing;
    
    % === Стиль линии ===
    uicontrol(fig, 'Style', 'text', 'Position', [leftMargin, currentY, labelWidth, controlHeight], ...
        'String', 'Line Style:', 'HorizontalAlignment', 'left');
    hStylePopup = uicontrol(fig, 'Style', 'popupmenu', ...
        'Position', [leftMargin + labelWidth + 10, currentY, controlWidth, controlHeight], ...
        'String', {'Solid', 'Dashed', 'Dotted', 'Dash-Dot'}, ...
        'Value', getStyleIndex(measurement.line_style), ...
        'Callback', @(src,~)updateStyle(src, measurement_index));
    
    currentY = currentY - spacing;
    
    % === Толщина линии ===
    uicontrol(fig, 'Style', 'text', 'Position', [leftMargin, currentY, labelWidth, controlHeight], ...
        'String', 'Line Width:', 'HorizontalAlignment', 'left');
    hWidthEdit = uicontrol(fig, 'Style', 'edit', ...
        'Position', [leftMargin + labelWidth + 10, currentY, controlWidth, controlHeight], ...
        'String', num2str(measurement.line_width), ...
        'Callback', @(src,~)updateWidth(src, measurement_index));
    
    currentY = currentY - spacing;
    
    % === Текст подписи ===
    uicontrol(fig, 'Style', 'text', 'Position', [leftMargin, currentY, labelWidth, controlHeight], ...
        'String', 'Label Text:', 'HorizontalAlignment', 'left');
    hLabelEdit = uicontrol(fig, 'Style', 'edit', ...
        'Position', [leftMargin + labelWidth + 10, currentY, controlWidth, controlHeight], ...
        'String', measurement.label_text, ...
        'Callback', @(src,~)updateLabelText(src, measurement_index));
    
    currentY = currentY - spacing;
    
    % === Цвет фона подписи ===
    uicontrol(fig, 'Style', 'text', 'Position', [leftMargin, currentY, labelWidth, controlHeight], ...
        'String', 'Label Background:', 'HorizontalAlignment', 'left');
    hLabelBgPopup = uicontrol(fig, 'Style', 'popupmenu', ...
        'Position', [leftMargin + labelWidth + 10, currentY, controlWidth, controlHeight], ...
        'String', {'White', 'Black', 'Red', 'Green', 'Blue', 'Yellow', 'None'}, ...
        'Value', getBackgroundIndex(measurement.label_background), ...
        'Callback', @(src,~)updateLabelBackground(src, measurement_index));
    
    currentY = currentY - spacing;
    
    % === Размер шрифта ===
    uicontrol(fig, 'Style', 'text', 'Position', [leftMargin, currentY, labelWidth, controlHeight], ...
        'String', 'Font Size:', 'HorizontalAlignment', 'left');
    hFontSizeEdit = uicontrol(fig, 'Style', 'edit', ...
        'Position', [leftMargin + labelWidth + 10, currentY, controlWidth, controlHeight], ...
        'String', num2str(measurement.font_size), ...
        'Callback', @(src,~)updateFontSize(src, measurement_index));
    
    currentY = currentY - spacing * 2;
    
    % === Кнопки ===
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Apply', ...
        'Position', [leftMargin, currentY, 80, 30], ...
        'Callback', @(src,~)applyChanges(measurement_index));
    
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Cancel', ...
        'Position', [leftMargin + 100, currentY, 80, 30], ...
        'Callback', @(src,~)cancelChanges());
    
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Reset to Default', ...
        'Position', [leftMargin + 200, currentY, 120, 30], ...
        'Callback', @(src,~)resetToDefault(measurement_index));
    
    % === Вспомогательные функции ===
    
    function idx = getFunctionIndex(function_type)
        functions = {'Mean', 'Max', 'Min', 'Std', 'Peak', 'RMS', 'Slope'};
        idx = find(strcmp(functions, function_type), 1);
        if isempty(idx)
            idx = 1; % по умолчанию Mean
        end
    end
    
    function idx = getColorIndex(color)
        colors = {'r', 'g', 'b', 'm', 'c', 'y', 'k', 'w'};
        color_names = {'Red', 'Green', 'Blue', 'Magenta', 'Cyan', 'Yellow', 'Black', 'White'};
        idx = find(strcmp(colors, color), 1);
        if isempty(idx)
            idx = 1; % по умолчанию Red
        end
    end
    
    function idx = getStyleIndex(style)
        styles = {'-', '--', ':', '-.'};
        style_names = {'Solid', 'Dashed', 'Dotted', 'Dash-Dot'};
        idx = find(strcmp(styles, style), 1);
        if isempty(idx)
            idx = 1; % по умолчанию Solid
        end
    end
    
    function idx = getBackgroundIndex(bg)
        backgrounds = {'white', 'black', 'red', 'green', 'blue', 'yellow', 'none'};
        bg_names = {'White', 'Black', 'Red', 'Green', 'Blue', 'Yellow', 'None'};
        idx = find(strcmp(backgrounds, bg), 1);
        if isempty(idx)
            idx = 1; % по умолчанию White
        end
    end
    
    function updateFunction(src, idx)
        functions = {'Mean', 'Max', 'Min', 'Std', 'Peak', 'RMS', 'Slope'};
        multiple_measurements(idx).function_type = functions{get(src, 'Value')};
    end
    
    function updateColor(src, idx)
        colors = {'r', 'g', 'b', 'm', 'c', 'y', 'k', 'w'};
        multiple_measurements(idx).line_color = colors{get(src, 'Value')};
    end
    
    function updateStyle(src, idx)
        styles = {'-', '--', ':', '-.'};
        multiple_measurements(idx).line_style = styles{get(src, 'Value')};
    end
    
    function updateWidth(src, idx)
        new_width = str2double(get(src, 'String'));
        if ~isnan(new_width) && new_width > 0
            multiple_measurements(idx).line_width = new_width;
        else
            set(src, 'String', num2str(multiple_measurements(idx).line_width));
        end
    end
    
    function updateLabelText(src, idx)
        multiple_measurements(idx).label_text = get(src, 'String');
    end
    
    function updateLabelBackground(src, idx)
        backgrounds = {'white', 'black', 'red', 'green', 'blue', 'yellow', 'none'};
        multiple_measurements(idx).label_background = backgrounds{get(src, 'Value')};
    end
    
    function updateFontSize(src, idx)
        new_size = str2double(get(src, 'String'));
        if ~isnan(new_size) && new_size > 0
            multiple_measurements(idx).font_size = new_size;
        else
            set(src, 'String', num2str(multiple_measurements(idx).font_size));
        end
    end
    
    function applyChanges(idx)
        % Применяем изменения и закрываем окно
        fprintf('✓ Свойства измерения #%d применены\n', idx);
        close(fig);
    end
    
    function resetToDefault(idx)
        colors = {'r', 'g', 'b', 'm', 'c', 'y'};
        color_idx = mod(idx-1, length(colors)) + 1;
        
        % Сбрасываем к значениям по умолчанию
        multiple_measurements(idx).function_type = 'Mean';
        multiple_measurements(idx).line_color = colors{color_idx};
        multiple_measurements(idx).line_style = '-';
        multiple_measurements(idx).line_width = 2;
        multiple_measurements(idx).label_text = sprintf('M%d', idx);
        multiple_measurements(idx).label_background = 'white';
        multiple_measurements(idx).font_size = 10;
        
        % Обновляем элементы управления
        set(hFunctionPopup, 'Value', 1);
        set(hColorPopup, 'Value', color_idx);
        set(hStylePopup, 'Value', 1);
        set(hWidthEdit, 'String', '2');
        set(hLabelEdit, 'String', sprintf('M%d', idx));
        set(hLabelBgPopup, 'Value', 1);
        set(hFontSizeEdit, 'String', '10');
        
        fprintf('✓ Свойства измерения #%d сброшены к значениям по умолчанию\n', idx);
    end
    
    function closeRequest(src)
        % Обработчик закрытия окна
        delete(src);
    end
    
    function cancelChanges()
        % Отменяем изменения и закрываем окно
        fprintf('❌ Изменения отменены\n');
        close(fig);
    end
    
    % Ждем закрытия окна
    waitfor(fig);
end 