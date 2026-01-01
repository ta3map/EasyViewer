function showGlobalSettings()
    % SHOWGLOBALSETTINGS Отображает все глобальные настройки приложения
    % Окно только для просмотра, без возможности редактирования
    
    global SettingsFilepath auto_open_last_file
    
    % Загружаем глобальные настройки
    loadGlobalSettings();
    
    % Проверяем, не открыто ли уже окно
    existingFig = findobj('Tag', 'GlobalSettingsViewer');
    if ~isempty(existingFig)
        figure(existingFig);
        return;
    end
    
    % Загружаем все настройки из файла
    if isempty(SettingsFilepath)
        SettingsFilepath = fullfile(tempdir, 'ev_settings.mat');
    end
    
    % Получаем размеры экрана для центрирования окна
    screenSize = get(0, 'ScreenSize');
    windowWidth = 600;
    windowHeight = 700;
    
    % Центрируем окно на экране
    xPos = (screenSize(3) - windowWidth) / 2;
    yPos = (screenSize(4) - windowHeight) / 2;
    
    fig = figure('Name', 'Global Settings', ...
                 'NumberTitle', 'off', ...
                 'MenuBar', 'none', ...
                 'ToolBar', 'none', ...
                 'Position', [xPos, yPos, windowWidth, windowHeight], ...
                 'Resize', 'off', ...
                 'Tag', 'GlobalSettingsViewer', ...
                 'CloseRequestFcn', @closeWindow);
    
    % Заголовок
    uicontrol('Parent', fig, 'Style', 'text', ...
              'String', 'GLOBAL SETTINGS', ...
              'Position', [25, 660, 550, 25], ...
              'HorizontalAlignment', 'left', ...
              'FontWeight', 'bold', ...
              'FontSize', 12, ...
              'ForegroundColor', [0, 0.4, 0.8]);
    
    % Информация о файле настроек
    uicontrol('Parent', fig, 'Style', 'text', ...
              'String', ['Settings file: ' SettingsFilepath], ...
              'Position', [25, 640, 550, 20], ...
              'HorizontalAlignment', 'left', ...
              'FontSize', 9, ...
              'ForegroundColor', [0.5, 0.5, 0.5]);
    
    % Загружаем данные из файла
    if exist(SettingsFilepath, 'file')
        try
            d = load(SettingsFilepath);
        catch
            d = struct();
        end
    else
        d = struct();
    end
    
    % Автоматически формируем таблицу из всех полей структуры
    tableData = buildSettingsTable(d);
    
    % Создаем таблицу (уменьшенная высота для места под чекбокс)
    table = uitable('Parent', fig, ...
                    'Data', tableData, ...
                    'ColumnName', {'Setting', 'State'}, ...
                    'ColumnWidth', {250, 300}, ...
                    'Position', [25, 160, 550, 480], ...
                    'ColumnEditable', [false, false], ...
                    'RowName', []);
    
    % Загружаем значение настройки auto_open_last_file
    autoOpenValue = true;
    if exist('auto_open_last_file', 'var') && ~isempty(auto_open_last_file)
        autoOpenValue = auto_open_last_file;
    elseif isfield(d, 'auto_open_last_file')
        autoOpenValue = d.auto_open_last_file;
    end
    
    % Чекбокс для настройки автоматического открытия последнего файла
    autoOpenCheckbox = uicontrol('Parent', fig, ...
                                 'Style', 'checkbox', ...
                                 'String', 'Auto open last file on startup', ...
                                 'Position', [25, 60, 300, 25], ...
                                 'Value', autoOpenValue, ...
                                 'Callback', @autoOpenCheckboxCallback, ...
                                 'FontSize', 10);
    
    % Reset to Defaults button
    resetBtn = uicontrol('Parent', fig, 'Style', 'pushbutton', ...
                         'String', 'Reset to Defaults', ...
                         'Position', [25, 20, 150, 35], ...
                         'Callback', @resetToDefaults, ...
                         'FontSize', 11);
    
    % Close button
    closeBtn = uicontrol('Parent', fig, 'Style', 'pushbutton', ...
                         'String', 'Close', ...
                         'Position', [250, 20, 100, 35], ...
                         'Callback', @closeWindow, ...
                         'FontSize', 11);
    
    function autoOpenCheckboxCallback(src, ~)
        % Сохраняем настройку при изменении чекбокса
        auto_open_last_file = get(src, 'Value');
        try
            if exist(SettingsFilepath, 'file')
                save(SettingsFilepath, 'auto_open_last_file', '-append');
            else
                loadGlobalSettings();
                save(SettingsFilepath, 'auto_open_last_file', '-append');
            end
        catch ME
            warning('Error saving auto_open_last_file setting: %s', ME.message);
        end
    end
    
    function resetToDefaults(~, ~)
        % Сбрасывает все глобальные настройки к значениям по умолчанию
        choice = questdlg('Are you sure you want to reset all global settings to default values? This action cannot be undone.', ...
                          'Reset to Defaults', ...
                          'Yes', 'No', 'No');
        if strcmp(choice, 'Yes')
            try
                % Удаляем файл настроек
                if exist(SettingsFilepath, 'file')
                    delete(SettingsFilepath);
                end
                
                % Перезагружаем настройки (создастся новый файл с настройками по умолчанию)
                loadGlobalSettings();
                
                % Обновляем таблицу
                if exist(SettingsFilepath, 'file')
                    d = load(SettingsFilepath);
                else
                    d = struct();
                end
                tableData = buildSettingsTable(d);
                set(table, 'Data', tableData);
                
                % Обновляем чекбокс
                if exist('auto_open_last_file', 'var') && ~isempty(auto_open_last_file)
                    set(autoOpenCheckbox, 'Value', auto_open_last_file);
                else
                    set(autoOpenCheckbox, 'Value', true);
                end
                
                fprintf('Global settings reset to default values\n');
            catch ME
                warning('Error resetting global settings: %s', ME.message);
            end
        end
    end
    
    function closeWindow(~, ~)
        delete(fig);
    end
end

function tableData = buildSettingsTable(d)
    % BUILDINGSETTINGSTABLE Автоматически формирует таблицу настроек из структуры
    % Обрабатывает все поля структуры и форматирует их значения
    
    tableData = {};
    fieldNames = fieldnames(d);
    
    % Сортируем поля по алфавиту для удобства
    fieldNames = sort(fieldNames);
    
    for i = 1:length(fieldNames)
        fieldName = fieldNames{i};
        value = d.(fieldName);
        
        % Форматируем имя настройки
        displayName = formatSettingName(fieldName);
        
        % Форматируем значение (полностью агностически)
        displayValue = formatValue(value);
        
        tableData{end+1, 1} = displayName;
        tableData{end, 2} = displayValue;
    end
end

function displayName = formatSettingName(fieldName)
    % FORMATSETTINGNAME Форматирует имя поля в читаемый вид
    % Заменяет подчеркивания на пробелы и делает первую букву заглавной
    
    displayName = fieldName;
    displayName = strrep(displayName, '_', ' ');
    
    % Делаем первую букву заглавной
    if ~isempty(displayName)
        displayName(1) = upper(displayName(1));
    end
    
    % Делаем заглавными первые буквы после пробелов
    spaceIndices = find(displayName == ' ');
    for idx = spaceIndices
        if idx < length(displayName)
            displayName(idx + 1) = upper(displayName(idx + 1));
        end
    end
end

function str = formatValue(value)
    % FORMATVALUE Полностью агностическое форматирование значения любого типа
    
    if isempty(value)
        str = 'empty';
        return;
    end
    
    % Числовые типы
    if isnumeric(value)
        str = formatNumeric(value);
        return;
    end
    
    % Логические типы
    if islogical(value)
        str = formatLogical(value);
        return;
    end
    
    % Строковые типы
    if ischar(value) || isstring(value)
        str = formatString(value);
        return;
    end
    
    % Структуры
    if isstruct(value)
        str = formatStruct(value);
        return;
    end
    
    % Ячейки
    if iscell(value)
        str = formatCell(value);
        return;
    end
    
    % Остальные типы
    str = sprintf('[%s]', class(value));
end

function str = formatNumeric(value)
    % Форматирование числовых значений
    if isscalar(value)
        str = num2str(value);
    elseif isvector(value)
        if length(value) <= 10
            str = mat2str(value);
        else
            str = sprintf('[1x%d vector]', length(value));
        end
    else
        str = sprintf('[%dx%d %s]', size(value, 1), size(value, 2), class(value));
    end
end

function str = formatLogical(value)
    % Форматирование логических значений
    if isscalar(value)
        str = mat2str(value);
    else
        str = sprintf('[%dx%d logical]', size(value, 1), size(value, 2));
    end
end

function str = formatString(value)
    % Форматирование строковых значений
    str = char(value);
    if length(str) > 50
        str = [str(1:47) '...'];
    end
end

function str = formatStruct(value)
    % Форматирование структур
    fields = fieldnames(value);
    if isempty(fields)
        str = 'empty struct';
    else
        str = sprintf('struct with %d fields', length(fields));
    end
end

function str = formatCell(value)
    % Форматирование ячеек
    if isempty(value)
        str = 'empty cell';
    elseif isvector(value) && length(value) <= 5
        % Пытаемся показать содержимое для небольших ячеек
        cellStrs = cell(size(value));
        for i = 1:length(value)
            cellStrs{i} = formatValue(value{i});
            if length(cellStrs{i}) > 20
                cellStrs{i} = [cellStrs{i}(1:17) '...'];
            end
        end
        str = ['{' strjoin(cellStrs, ', ') '}'];
    else
        str = sprintf('{%dx%d cell}', size(value, 1), size(value, 2));
    end
end
