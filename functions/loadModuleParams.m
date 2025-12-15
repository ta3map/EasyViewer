function params = loadModuleParams(moduleName, timeUnitFactor)
    % Загружает параметры модуля из JSON файла
    % moduleName - имя модуля (без расширения)
    % timeUnitFactor - не используется, оставлен для совместимости
    % Все параметры возвращаются в секундах (как в JSON)
    
    [functionFolder, ~, ~] = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(functionFolder);
    moduleFolder = fullfile(projectRoot, 'modules');
    jsonPath = fullfile(moduleFolder, [moduleName, '.json']);
    jsonText = fileread(jsonPath);
    jsonParams = jsondecode(jsonText);
    
    % Автоматическое присваивание параметров из JSON (всегда в секундах)
    params = struct();
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
end

