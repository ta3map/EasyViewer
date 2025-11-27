function params = loadModuleParams(moduleName, timeUnitFactor)
    % Загружает параметры модуля из JSON файла
    % moduleName - имя модуля (без расширения)
    % timeUnitFactor - множитель для параметров с суффиксом _s
    
    [moduleFolder, ~, ~] = fileparts(mfilename('fullpath'));
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
            if endsWith(fieldName, '_s')
                paramName = fieldName(1:end-2); % убираем '_s'
                params.(paramName) = value * timeUnitFactor;
            else
                params.(fieldName) = value;
            end
        end
    end
end

