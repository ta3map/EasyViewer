function filteredTable = boxplotApplyGroupFilters(table, groupFilters)
    % boxplotApplyGroupFilters - Применение фильтров к таблице через eval
    % Создает колонку group_label с метками групп на основе условий фильтрации
    % 
    % Входные параметры:
    %   table - таблица данных
    %   groupFilters - cell array структур с полями: condition, groupLabel
    %
    % Выходные параметры:
    %   filteredTable - отфильтрованная таблица с колонкой group_label
    
    filteredTable = table;
    
    if isempty(groupFilters)
        % Если фильтров нет, возвращаем пустую таблицу
        filteredTable = table();
        return
    end
    
    filteredTable.group_label = repmat({''}, height(filteredTable), 1);
    
    % Создаем переменные из колонок таблицы локально (названия уже отформатированы)
    varNames = filteredTable.Properties.VariableNames;
    for i = 1:length(varNames)
        varName = varNames{i};
        eval(sprintf('%s = filteredTable{:, %d};', varName, i));
    end
    
    % Применяем фильтры для каждой группы
    for i = 1:length(groupFilters)
        filter = groupFilters{i};
        try
            % Выполняем условие через eval
            mask = eval(filter.condition);
            if islogical(mask) && length(mask) == height(filteredTable)
                % Присваиваем метку группы
                filteredTable.group_label(mask) = {filter.groupLabel};
            end
        catch ME
            warning('Ошибка при применении фильтра: %s', ME.message);
        end
    end
    
    % Оставляем только строки с метками групп
    hasLabel = ~cellfun(@isempty, filteredTable.group_label);
    filteredTable = filteredTable(hasLabel, :);
end

