function maxLevel = boxplotCalculateMaxBracketLevelForParams(testResults, paramsInGroup, showAllPvalues)
    % boxplotCalculateMaxBracketLevelForParams - Вычисление максимального уровня скобок
    % Определяет максимальный уровень вложенности скобок значимости для тестов между параметрами
    % 
    % Входные параметры:
    %   testResults - структура с результатами статистических тестов
    %   paramsInGroup - массив параметров в группе
    %   showAllPvalues - показывать ли все p-values или только значимые (<0.05)
    %
    % Выходные параметры:
    %   maxLevel - максимальный уровень скобок (или -1, если скобок нет)
    
    if isempty(testResults) || isempty(fieldnames(testResults))
        maxLevel = -1;
        return
    end
    
    % Собираем все пары для отображения
    significantPairs = struct('param1', {}, 'param2', {}, 'pvalue', {});
    testFields = fieldnames(testResults);
    
    for i = 1:length(testFields)
        testKey = testFields{i};
        testData = testResults.(testKey);
        pvalue = testData.pvalue;
        
        if showAllPvalues || pvalue < 0.05
            newPair = struct(...
                'param1', {testData.group1}, ...
                'param2', {testData.group2}, ...
                'pvalue', pvalue);
            significantPairs = [significantPairs; newPair];
        end
    end
    
    if isempty(significantPairs)
        maxLevel = -1;
        return
    end
    
    % Находим позиции параметров на оси X
    % Используем fieldName для сопоставления с testResults
    paramPositions = containers.Map();
    for i = 1:length(paramsInGroup)
        if isfield(paramsInGroup{i}, 'fieldName')
            paramPositions(paramsInGroup{i}.fieldName) = i;
        else
            % Fallback на column, если fieldName отсутствует
            paramPositions(paramsInGroup{i}.column) = i;
        end
    end
    
    % Определяем уровни для скобок
    levels = boxplotAssignBracketLevelsForParams(significantPairs, paramPositions);
    
    if isempty(levels)
        maxLevel = -1;
    else
        maxLevel = max(levels);
    end
end

