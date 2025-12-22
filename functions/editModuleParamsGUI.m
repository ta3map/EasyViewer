function params = editModuleParamsGUI(moduleName)
    % GUI для редактирования параметров модуля из JSON файла
    % moduleName - имя модуля (без расширения)
    % Возвращает структуру params или пустую структуру, если пользователь отменил
    
    params = struct();
    
    % Загрузка JSON файла
    [functionFolder, ~, ~] = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(functionFolder);
    moduleFolder = fullfile(projectRoot, 'modules');
    jsonPath = fullfile(moduleFolder, [moduleName, '.json']);
    
    if ~exist(jsonPath, 'file')
        msgbox(sprintf('JSON file not found: %s', jsonPath), 'Error', 'error');
        return;
    end
    
    jsonText = fileread(jsonPath);
    jsonParams = jsondecode(jsonText);
    
    % Проверка и создание секции output с параметрами по умолчанию
    if ~isfield(jsonParams, 'output')
        jsonParams.output = struct();
    end
    if ~isfield(jsonParams.output, 'AddTimestamp')
        jsonParams.output.AddTimestamp = false;
    end
    if ~isfield(jsonParams.output, 'ResultSuffix')
        jsonParams.output.ResultSuffix = '';
    end
    
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
    
    uicontrol('Style', 'pushbutton', ...
        'Position', [340, 10, 120, 30], ...
        'String', 'Import from .meta', ...
        'Callback', @importFromMetaCallback);
    
    % Переменные для хранения состояния
    userData = struct();
    userData.jsonParams = jsonParams;
    userData.jsonPath = jsonPath;
    userData.moduleName = moduleName;
    userData.applied = false;
    fig.UserData = userData;
    
    % Переменная для сохранения результата после удаления фигуры
    appliedResult = false;
    
    % Ожидание закрытия окна
    uiwait(fig);
    
    % Получение результата
    applied = appliedResult;
    
    if applied
        % Загружаем обновленный JSON и преобразуем в params
        updatedJsonText = fileread(jsonPath);
        updatedJsonParams = jsondecode(updatedJsonText);
        
        % Преобразуем JSON в params структуру (всегда в секундах)
        params = struct();
        jsonSections = fieldnames(updatedJsonParams);
        for i = 1:length(jsonSections)
            sectionName = jsonSections{i};
            sectionFields = fieldnames(updatedJsonParams.(sectionName));
            for j = 1:length(sectionFields)
                fieldName = sectionFields{j};
                value = updatedJsonParams.(sectionName).(fieldName);
                params.(fieldName) = value;
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
                        else
                            value = logical(value);
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
            
            appliedResult = true;
            fig.UserData.applied = true;
            uiresume(fig);
            delete(fig);
        catch ME
            msgbox(sprintf('Failed to save JSON file: %s', ME.message), 'Error', 'error');
        end
    end
    
    function cancelCallback(~, ~)
        appliedResult = false;
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
    
    function importFromMetaCallback(~, ~)
        [filename, pathname] = uigetfile('*.meta', 'Select .meta file');
        if isequal(filename, 0)
            return;
        end
        
        metaPath = fullfile(pathname, filename);
        if ~exist(metaPath, 'file')
            msgbox(sprintf('File not found: %s', metaPath), 'Error', 'error');
            return;
        end
        
        try
            metaData = load(metaPath, '-mat');
        catch ME
            msgbox(sprintf('Failed to load .meta file: %s', ME.message), 'Error', 'error');
            return;
        end
        
        % Проверяем наличие переменной params
        if ~isfield(metaData, 'params')
            msgbox('No params variable found in .meta file', 'Error', 'error');
            return;
        end
        
        paramsFromMeta = metaData.params;
        
        % Получаем список параметров модуля из таблицы
        tableData = get(table, 'Data');
        moduleParamNames = {};
        for i = 1:size(tableData, 1)
            moduleParamNames{end+1} = tableData{i, 2};
        end
        
        % Извлекаем только те поля из params, которые есть в параметрах модуля
        availableFields = {};
        availableValues = {};
        if isstruct(paramsFromMeta)
            paramFields = fieldnames(paramsFromMeta);
            for i = 1:length(paramFields)
                fieldName = paramFields{i};
                if any(strcmp(moduleParamNames, fieldName))
                    availableFields{end+1} = fieldName;
                    availableValues{end+1} = convertValueToString(paramsFromMeta.(fieldName));
                end
            end
        end
        
        if isempty(availableFields)
            msgbox('No matching parameters found in .meta file', 'Import Complete', 'help');
            return;
        end
        
        % Показываем диалог выбора только для совпадающих параметров
        selectedFields = showFieldSelectionDialog(availableFields, availableValues);
        if isempty(selectedFields)
            return;
        end
        
        % Обновляем параметры в таблице
        updatedCount = 0;
        for i = 1:length(selectedFields)
            fieldName = selectedFields{i};
            if isfield(paramsFromMeta, fieldName)
                value = paramsFromMeta.(fieldName);
                
                for j = 1:size(tableData, 1)
                    if strcmp(tableData{j, 2}, fieldName)
                        valueStr = convertValueToString(value);
                        tableData{j, 3} = valueStr;
                        updatedCount = updatedCount + 1;
                        break;
                    end
                end
            end
        end
        
        set(table, 'Data', tableData);
        if updatedCount > 0
            msgbox(sprintf('Imported %d parameter(s) from .meta file', updatedCount), 'Import Complete', 'help');
        end
    end
    
    function valueStr = convertValueToString(value)
        if islogical(value)
            valueStr = mat2str(value);
        elseif isnumeric(value)
            valueStr = mat2str(value);
        elseif ischar(value) || isstring(value)
            if isstring(value)
                valueStr = char(value);
            else
                valueStr = value;
            end
        else
            valueStr = mat2str(value);
        end
    end
    
    function selectedFields = showFieldSelectionDialog(allFields, allValues)
        selectedFields = [];
        
        dlg = figure('Position', [400, 400, 600, 400], ...
            'Name', 'Select Parameters to Import', ...
            'NumberTitle', 'off', ...
            'MenuBar', 'none', ...
            'Resize', 'on', ...
            'WindowStyle', 'modal');
        
        data = [allFields', allValues', num2cell(false(numel(allFields), 1))];
        fieldTable = uitable('Parent', dlg, ...
            'Position', [10, 50, 580, 310], ...
            'Data', data, ...
            'ColumnName', {'Parameter', 'Value', 'Select'}, ...
            'ColumnEditable', [false, false, true], ...
            'ColumnWidth', {200, 300, 60}, ...
            'ColumnFormat', {'char', 'char', 'logical'});
        
        uicontrol('Parent', dlg, ...
            'Style', 'pushbutton', ...
            'Position', [10, 10, 120, 30], ...
            'String', 'Select All', ...
            'Callback', @(src,evt) selectAllCallback(fieldTable, allFields, true));
        
        uicontrol('Parent', dlg, ...
            'Style', 'pushbutton', ...
            'Position', [140, 10, 120, 30], ...
            'String', 'Deselect All', ...
            'Callback', @(src,evt) selectAllCallback(fieldTable, allFields, false));
        
        uicontrol('Parent', dlg, ...
            'Style', 'pushbutton', ...
            'Position', [450, 10, 70, 30], ...
            'String', 'OK', ...
            'Callback', @(src,evt) uiresume(dlg));
        
        uicontrol('Parent', dlg, ...
            'Style', 'pushbutton', ...
            'Position', [530, 10, 60, 30], ...
            'String', 'Cancel', ...
            'Callback', @(src,evt) close(dlg));
        
        uiwait(dlg);
        
        if ishandle(dlg)
            data = fieldTable.Data;
            selectedIndices = cellfun(@(x) islogical(x) && x, data(:, 3));
            selectedFields = allFields(selectedIndices);
            close(dlg);
        end
    end
    
    function selectAllCallback(table, allFields, select)
        data = table.Data;
        for i = 1:numel(allFields)
            data{i, 3} = select;
        end
        table.Data = data;
    end
    
    function closeCallback(~, ~)
        appliedResult = false;
        uiresume(fig);
        delete(fig);
    end
end

