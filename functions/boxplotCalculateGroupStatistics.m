function groupStats = boxplotCalculateGroupStatistics(table, parameters, groupColumn)
    % boxplotCalculateGroupStatistics - Расчет статистики для каждой группы и параметра
    % 
    % Входные параметры:
    %   table - таблица данных
    %   parameters - массив структур с полями: column (название колонки)
    %   groupColumn - название колонки с метками групп
    %
    % Выходные параметры:
    %   groupStats - структура со статистикой для каждого параметра и группы
    
    groupStats = struct();
    uniqueGroups = unique(table{:, groupColumn});
    
    for p = 1:length(parameters)
        paramStruct = parameters{p};
        columnName = paramStruct.column;
        
        if ~ismember(columnName, table.Properties.VariableNames)
            continue
        end
        
        paramStats = struct();
        for g = 1:length(uniqueGroups)
            groupLabel = uniqueGroups{g};
            if iscell(groupLabel)
                groupLabel = groupLabel{1};
            end
            
            mask = strcmp(table{:, 'group_label'}, groupLabel);
            data = table{mask, columnName};
            data = data(~isnan(data) & ~isinf(data));
            
            if ~isempty(data)
                paramStats.(matlab.lang.makeValidName(groupLabel)) = struct(...
                    'mean', mean(data), ...
                    'std', std(data), ...
                    'median', median(data), ...
                    'q25', prctile(data, 25), ...
                    'q75', prctile(data, 75), ...
                    'count', length(data));
            end
        end
        
        % Используем название колонки как ключ
        paramKey = columnName;
        groupStats.(matlab.lang.makeValidName(paramKey)) = paramStats;
    end
end

