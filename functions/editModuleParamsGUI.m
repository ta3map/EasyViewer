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
        
        allFields = extractAllFields(metaData);
        if isempty(allFields)
            msgbox('No fields found in .meta file', 'Error', 'error');
            return;
        end
        
        selectedFields = showFieldSelectionDialog(allFields);
        if isempty(selectedFields)
            return;
        end
        
        tableData = get(table, 'Data');
        updatedCount = 0;
        
        for i = 1:length(selectedFields)
            fieldPath = selectedFields{i};
            value = getFieldValue(metaData, fieldPath);
            
            if isempty(value)
                continue;
            end
            
            fieldName = fieldPath;
            if contains(fieldPath, '.')
                parts = strsplit(fieldPath, '.');
                fieldName = parts{end};
            end
            
            for j = 1:size(tableData, 1)
                if strcmp(tableData{j, 2}, fieldName)
                    valueStr = convertValueToString(value);
                    tableData{j, 3} = valueStr;
                    updatedCount = updatedCount + 1;
                    break;
                end
            end
        end
        
        set(table, 'Data', tableData);
        if updatedCount > 0
            msgbox(sprintf('Imported %d parameter(s) from .meta file', updatedCount), 'Import Complete', 'help');
        else
            msgbox('No matching parameters found in module', 'Import Complete', 'help');
        end
    end
    
    function fields = extractAllFields(structData)
        fields = {};
        fieldNames = fieldnames(structData);
        for i = 1:numel(fieldNames)
            fieldName = fieldNames{i};
            fields = extractFieldsRecursive(structData.(fieldName), fieldName, fields);
        end
    end
    
    function fields = extractFieldsRecursive(value, prefix, fields)
        if isstruct(value)
            if numel(value) == 1
                fieldNames = fieldnames(value);
                for i = 1:numel(fieldNames)
                    subFieldName = fieldNames{i};
                    newPrefix = sprintf('%s.%s', prefix, subFieldName);
                    fields = extractFieldsRecursive(value.(subFieldName), newPrefix, fields);
                end
            else
                fields{end+1} = prefix;
            end
        elseif iscell(value) && numel(value) > 0 && isstruct(value{1})
            if numel(value) == 1
                fieldNames = fieldnames(value{1});
                for i = 1:numel(fieldNames)
                    subFieldName = fieldNames{i};
                    newPrefix = sprintf('%s.%s', prefix, subFieldName);
                    fields = extractFieldsRecursive(value{1}.(subFieldName), newPrefix, fields);
                end
            else
                fields{end+1} = prefix;
            end
        else
            fields{end+1} = prefix;
        end
    end
    
    function value = getFieldValue(structData, fieldPath)
        parts = strsplit(fieldPath, '.');
        value = structData;
        for i = 1:numel(parts)
            if isstruct(value) && numel(value) == 1 && isfield(value, parts{i})
                value = value.(parts{i});
            elseif isstruct(value) && numel(value) > 1 && isfield(value(1), parts{i})
                value = [value.(parts{i})];
            elseif iscell(value) && numel(value) > 0 && isstruct(value{1}) && isfield(value{1}, parts{i})
                value = cellfun(@(x) x.(parts{i}), value, 'UniformOutput', false);
            else
                value = [];
                return;
            end
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
    
    function selectedFields = showFieldSelectionDialog(allFields)
        selectedFields = [];
        
        dlg = figure('Position', [400, 400, 500, 400], ...
            'Name', 'Select Parameters to Import', ...
            'NumberTitle', 'off', ...
            'MenuBar', 'none', ...
            'Resize', 'on', ...
            'WindowStyle', 'modal');
        
        data = [allFields', num2cell(false(numel(allFields), 1))];
        fieldTable = uitable('Parent', dlg, ...
            'Position', [10, 50, 480, 310], ...
            'Data', data, ...
            'ColumnName', {'Field Name', 'Select'}, ...
            'ColumnEditable', [false, true], ...
            'ColumnWidth', {350, 80}, ...
            'ColumnFormat', {'char', 'logical'});
        
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
            'Position', [350, 10, 70, 30], ...
            'String', 'OK', ...
            'Callback', @(src,evt) uiresume(dlg));
        
        uicontrol('Parent', dlg, ...
            'Style', 'pushbutton', ...
            'Position', [430, 10, 60, 30], ...
            'String', 'Cancel', ...
            'Callback', @(src,evt) close(dlg));
        
        uiwait(dlg);
        
        if ishandle(dlg)
            data = fieldTable.Data;
            selectedIndices = cellfun(@(x) islogical(x) && x, data(:, 2));
            selectedFields = allFields(selectedIndices);
            close(dlg);
        end
    end
    
    function selectAllCallback(table, allFields, select)
        data = table.Data;
        for i = 1:numel(allFields)
            data{i, 2} = select;
        end
        table.Data = data;
    end
    
    function closeCallback(~, ~)
        appliedResult = false;
        uiresume(fig);
        delete(fig);
    end
end

