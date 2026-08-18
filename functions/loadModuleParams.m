function params = loadModuleParams(moduleName, timeUnitFactor)
    % Загружает параметры модуля из JSON файла
    % moduleName - имя модуля (без расширения)
    % timeUnitFactor - не используется, оставлен для совместимости
    % Все параметры возвращаются в секундах (как в JSON)
    % Если JSON файл не найден, возвращает пустую структуру
    
    params = struct();
    
    moduleFolder = fullfile(getAppRoot(), 'modules');
    jsonPath = fullfile(moduleFolder, [moduleName, '.json']);
    
    if ~exist(jsonPath, 'file')
        return
    end
    
    try
        jsonText = fileread(jsonPath);
        jsonParams = jsondecode(jsonText);
        
        % Автоматическое присваивание параметров из JSON (всегда в секундах)
        jsonSections = fieldnames(jsonParams);
        for i = 1:length(jsonSections)
            sectionName = jsonSections{i};
            sectionFields = fieldnames(jsonParams.(sectionName));
            for j = 1:length(sectionFields)
                fieldName = sectionFields{j};
                value = jsonParams.(sectionName).(fieldName);
                params.(fieldName) = value;
            end
        end
    catch ME
        warning('Failed to load module parameters from %s: %s', jsonPath, ME.message);
    end
end

