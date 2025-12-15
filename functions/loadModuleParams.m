function params = loadModuleParams(moduleName, timeUnitFactor)
    % Загружает параметры модуля из JSON файла
    % moduleName - имя модуля (без расширения)
    % timeUnitFactor - множитель для параметров с суффиксом _s
    
    [functionFolder, ~, ~] = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(functionFolder);
    moduleFolder = fullfile(projectRoot, 'modules');
    jsonPath = fullfile(moduleFolder, [moduleName, '.json']);
    jsonText = fileread(jsonPath);
    jsonParams = jsondecode(jsonText);
    
    % Автоматическое присваивание параметров из JSON
    params = struct();
    jsonSections = fieldnames(jsonParams);
    for i = 1:length(jsonSections)
        sectionName = jsonSections{i};
        sectionFields = fieldnames(jsonParams.(sectionName));
        for j = 1:length(sectionFields)
            fieldName = sectionFields{j};
            value = jsonParams.(sectionName).(fieldName);
            
            % Обработка параметров, зависящих от timeUnitFactor (суффикс _s)
            % Масштабируем значение, но сохраняем оригинальное имя поля
            if endsWith(fieldName, '_s')
                params.(fieldName) = value * timeUnitFactor;
            else
                params.(fieldName) = value;
            end
        end
    end
end

