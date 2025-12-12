function testResults = boxplotPerformStatisticalTests(table, parameters, groupColumn)
    % boxplotPerformStatisticalTests - Выполнение попарных t-test между параметрами
    % Тестирует все пары параметров на одном полотне (с одинаковым groupNumber)
    % 
    % Входные параметры:
    %   table - таблица данных
    %   parameters - массив структур с полями: groupNumber, column
    %   groupColumn - название колонки с метками групп (не используется, но оставлено для совместимости)
    %
    % Выходные параметры:
    %   testResults - структура с результатами статистических тестов
    
    testResults = struct();
    
    % Группируем параметры по groupNumber
    groupNumbers = [];
    for i = 1:length(parameters)
        if isfield(parameters{i}, 'groupNumber')
            groupNumbers(end+1) = parameters{i}.groupNumber;
        else
            groupNumbers(end+1) = 1;
        end
    end
    uniqueGroupNumbers = unique(groupNumbers);
    
    % Для каждой группы полотен
    for groupNum = uniqueGroupNumbers
        % Находим все параметры в этой группе
        paramsInGroup = {};
        for i = 1:length(parameters)
            paramGroupNum = 1;
            if isfield(parameters{i}, 'groupNumber')
                paramGroupNum = parameters{i}.groupNumber;
            end
            if paramGroupNum == groupNum
                paramsInGroup{end+1} = parameters{i};
            end
        end
        
        % Если параметров меньше 2, тестов нет
        if length(paramsInGroup) < 2
            continue
        end
        
        % Тестируем все пары параметров на этом полотне
        for i = 1:length(paramsInGroup)
            for j = i+1:length(paramsInGroup)
                param1 = paramsInGroup{i};
                param2 = paramsInGroup{j};
                
                column1 = param1.column;
                column2 = param2.column;
                
                if ~ismember(column1, table.Properties.VariableNames) || ...
                   ~ismember(column2, table.Properties.VariableNames)
                    continue
                end
                
                data1 = table{:, column1};
                data2 = table{:, column2};
                
                data1 = data1(~isnan(data1) & ~isinf(data1));
                data2 = data2(~isnan(data2) & ~isinf(data2));
                
                if length(data1) > 0 && length(data2) > 0
                    try
                        [~, pvalue] = ttest2(data1, data2);
                        testKey = sprintf('%s_vs_%s', matlab.lang.makeValidName(column1), matlab.lang.makeValidName(column2));
                        paramKey = sprintf('Group%d', groupNum);
                        
                        if ~isfield(testResults, paramKey)
                            testResults.(paramKey) = struct();
                        end
                        
                        testResults.(paramKey).(testKey) = struct(...
                            'pvalue', pvalue, ...
                            'n1', length(data1), ...
                            'n2', length(data2), ...
                            'group1', column1, ...
                            'group2', column2);
                    catch
                        % Игнорируем ошибки тестов
                    end
                end
            end
        end
    end
end

