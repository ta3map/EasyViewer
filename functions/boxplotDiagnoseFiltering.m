function diagnosis = boxplotDiagnoseFiltering(table, groupFilters)
    % boxplotDiagnoseFiltering - Диагностика фильтрации данных
    % Подробный вывод результатов применения фильтров для отладки
    % 
    % Входные параметры:
    %   table - таблица данных
    %   groupFilters - cell array структур с полями: condition, groupLabel
    %
    % Выходные параметры:
    %   diagnosis - строка с диагностической информацией
    
    diagnosis = sprintf('Всего строк в данных: %d\n', height(table));
    diagnosis = [diagnosis sprintf('Колонки в данных: %s\n\n', strjoin(table.Properties.VariableNames, ', '))];
    
    for i = 1:length(groupFilters)
        filter = groupFilters{i};
        diagnosis = [diagnosis sprintf('Условие %d:\n', i)];
        diagnosis = [diagnosis sprintf('  %s\n', filter.condition)];
        
        try
            % Создаем переменные из колонок
            varNames = table.Properties.VariableNames;
            for j = 1:length(varNames)
                varName = matlab.lang.makeValidName(varNames{j});
                assignin('caller', varName, table{:, j});
            end
            
            % Выполняем условие
            mask = eval(filter.condition);
            if islogical(mask) && length(mask) == height(table)
                count = sum(mask);
                diagnosis = [diagnosis sprintf('  Строк в группе: %d из %d\n\n', count, height(table))];
            else
                diagnosis = [diagnosis sprintf('  Ошибка: условие вернуло неверный результат\n\n')];
            end
        catch ME
            diagnosis = [diagnosis sprintf('  Ошибка: %s\n\n', ME.message)];
        end
    end
end

