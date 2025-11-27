function params = editModuleParamsGUI(moduleName)
    % GUI для редактирования параметров модуля из JSON файла
    % moduleName - имя модуля (без расширения)
    % Возвращает структуру params или пустую структуру, если пользователь отменил
    
    params = struct();
    
    % Загрузка JSON файла
    [moduleFolder, ~, ~] = fileparts(mfilename('fullpath'));
    jsonPath = fullfile(moduleFolder, [moduleName, '.json']);
    
    if ~exist(jsonPath, 'file')
        msgbox(sprintf('JSON file not found: %s', jsonPath), 'Error', 'error');
        return;
    end
    
    jsonText = fileread(jsonPath);
    jsonParams = jsondecode(jsonText);
    
    % Подготовка данных для таблицы
    data = {};
    rowNames = {};
    columnNames = {'Section', 'Parameter', 'Value', 'Type'};
    
    % Сбор всех параметров из JSON
    jsonSections = fieldnames(jsonParams);
    for i = 1:length(jsonSections)
        sectionName = jsonSections{i};
        sectionFields = fieldnames(jsonParams.(sectionName));
        for j = 1:length(sectionFields)
            fieldName = sectionFields{j};
            value = jsonParams.(sectionName).(fieldName);
            
            % Определение типа значения
            if islogical(value)
                valueType = 'logical';
                valueStr = mat2str(value);
            elseif isnumeric(value) && isscalar(value)
                valueType = 'numeric';
                valueStr = mat2str(value);
            elseif isnumeric(value) && numel(value) > 1
                valueType = 'array';
                valueStr = mat2str(value);
            elseif ischar(value) || isstring(value)
                valueType = 'string';
                if isstring(value)
                    valueStr = char(value);
                else
                    valueStr = value;
                end
            else
                valueType = 'other';
                valueStr = mat2str(value);
            end
            
            data{end+1, 1} = sectionName;
            data{end, 2} = fieldName;
            data{end, 3} = valueStr;
            data{end, 4} = valueType;
        end
    end
    
    % Создание GUI (модальное окно)
    fig = figure('Position', [300, 300, 700, 500], ...
        'Name', sprintf('Edit Parameters: %s', moduleName), ...
        'NumberTitle', 'off', ...
        'MenuBar', 'none', ...
        'Resize', 'on', ...
        'WindowStyle', 'modal', ...
        'CloseRequestFcn', @closeCallback);
    
    % Таблица с параметрами
    table = uitable('Parent', fig, ...
        'Position', [10, 50, 680, 400], ...
        'Data', data, ...
        'ColumnName', columnNames, ...
        'ColumnEditable', [false, false, true, false], ...
        'ColumnWidth', {120, 200, 250, 80});
    
    % Кнопки
    uicontrol('Style', 'pushbutton', ...
        'Position', [10, 10, 100, 30], ...
        'String', 'Apply', ...
        'Callback', @applyCallback);
    
    uicontrol('Style', 'pushbutton', ...
        'Position', [120, 10, 100, 30], ...
        'String', 'Cancel', ...
        'Callback', @cancelCallback);
    
    uicontrol('Style', 'pushbutton', ...
        'Position', [230, 10, 100, 30], ...
        'String', 'Reset', ...
        'Callback', @resetCallback);
    
    % Переменные для хранения состояния
    userData = struct();
    userData.jsonParams = jsonParams;
    userData.jsonPath = jsonPath;
    userData.moduleName = moduleName;
    userData.applied = false;
    fig.UserData = userData;
    
    % Ожидание закрытия окна
    uiwait(fig);
    
    % Получение результата
    applied = false;
    if ishandle(fig) && isfield(fig.UserData, 'applied')
        applied = fig.UserData.applied;
    end
    
    if applied
        % Загружаем обновленный JSON и преобразуем в params
        updatedJsonText = fileread(jsonPath);
        updatedJsonParams = jsondecode(updatedJsonText);
        
        % Получаем timeUnitFactor для преобразования параметров с _s
        global timeUnitFactor
        if isempty(timeUnitFactor)
            timeUnitFactor = 1;
        end
        
        % Преобразуем JSON в params структуру
        params = struct();
        jsonSections = fieldnames(updatedJsonParams);
        for i = 1:length(jsonSections)
            sectionName = jsonSections{i};
            sectionFields = fieldnames(updatedJsonParams.(sectionName));
            for j = 1:length(sectionFields)
                fieldName = sectionFields{j};
                value = updatedJsonParams.(sectionName).(fieldName);
                
                if endsWith(fieldName, '_s')
                    paramName = fieldName(1:end-2);
                    params.(paramName) = value * timeUnitFactor;
                else
                    params.(fieldName) = value;
                end
            end
        end
    end
    
    function applyCallback(~, ~)
        % Получение данных из таблицы
        tableData = get(table, 'Data');
        
        % Восстановление структуры JSON из таблицы
        newJsonParams = struct();
        for i = 1:size(tableData, 1)
            sectionName = tableData{i, 1};
            fieldName = tableData{i, 2};
            valueStr = tableData{i, 3};
            valueType = tableData{i, 4};
            
            % Преобразование строки обратно в значение
            try
                switch valueType
                    case 'logical'
                        value = str2num(valueStr); %#ok<ST2NM>
                        if isempty(value)
                            value = strcmpi(valueStr, 'true');
                        end
                    case 'numeric'
                        value = str2num(valueStr); %#ok<ST2NM>
                    case 'array'
                        value = str2num(valueStr); %#ok<ST2NM>
                    case 'string'
                        value = valueStr;
                    otherwise
                        value = str2num(valueStr); %#ok<ST2NM>
                        if isempty(value)
                            value = valueStr;
                        end
                end
                
                if ~isfield(newJsonParams, sectionName)
                    newJsonParams.(sectionName) = struct();
                end
                newJsonParams.(sectionName).(fieldName) = value;
            catch ME
                msgbox(sprintf('Error parsing value for %s.%s: %s', sectionName, fieldName, ME.message), ...
                    'Error', 'error');
                return;
            end
        end
        
        % Сохранение в JSON файл
        try
            jsonText = jsonencode(newJsonParams, 'PrettyPrint', true);
            fid = fopen(jsonPath, 'w', 'n', 'UTF-8');
            if fid == -1
                msgbox(sprintf('Failed to open file for writing: %s', jsonPath), 'Error', 'error');
                return;
            end
            fprintf(fid, '%s', jsonText);
            fclose(fid);
            
            fig.UserData.applied = true;
            uiresume(fig);
            delete(fig);
        catch ME
            msgbox(sprintf('Failed to save JSON file: %s', ME.message), 'Error', 'error');
        end
    end
    
    function cancelCallback(~, ~)
        uiresume(fig);
        delete(fig);
    end
    
    function resetCallback(~, ~)
        % Восстановление исходных данных
        originalData = {};
        jsonSections = fieldnames(fig.UserData.jsonParams);
        for i = 1:length(jsonSections)
            sectionName = jsonSections{i};
            sectionFields = fieldnames(fig.UserData.jsonParams.(sectionName));
            for j = 1:length(sectionFields)
                fieldName = sectionFields{j};
                value = fig.UserData.jsonParams.(sectionName).(fieldName);
                
                if islogical(value)
                    valueType = 'logical';
                    valueStr = mat2str(value);
                elseif isnumeric(value) && isscalar(value)
                    valueType = 'numeric';
                    valueStr = mat2str(value);
                elseif isnumeric(value) && numel(value) > 1
                    valueType = 'array';
                    valueStr = mat2str(value);
                elseif ischar(value) || isstring(value)
                    valueType = 'string';
                    if isstring(value)
                        valueStr = char(value);
                    else
                        valueStr = value;
                    end
                else
                    valueType = 'other';
                    valueStr = mat2str(value);
                end
                
                originalData{end+1, 1} = sectionName;
                originalData{end, 2} = fieldName;
                originalData{end, 3} = valueStr;
                originalData{end, 4} = valueType;
            end
        end
        set(table, 'Data', originalData);
    end
    
    function closeCallback(~, ~)
        uiresume(fig);
    end
end

