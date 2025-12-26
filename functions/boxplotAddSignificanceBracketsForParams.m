function boxplotAddSignificanceBracketsForParams(ax, paramsInGroup, testResults, showAllPvalues, yLimits)
    % boxplotAddSignificanceBracketsForParams - Добавление скобок значимости между параметрами на график
    % Рисует скобки значимости с p-values между параметрами на графике
    % 
    % Входные параметры:
    %   ax - axes объект для рисования
    %   paramsInGroup - массив параметров в группе
    %   testResults - структура с результатами статистических тестов
    %   showAllPvalues - показывать ли все p-values или только значимые (<0.05)
    %   yLimits - пределы Y-оси [yMin, yMax]
    
    if isempty(testResults) || isempty(fieldnames(testResults))
        return
    end
    
    % Собираем все пары для отображения
    significantPairs = struct('param1', {}, 'param2', {}, 'pvalue', {}, 'stars', {});
    testFields = fieldnames(testResults);
    
    for i = 1:length(testFields)
        testKey = testFields{i};
        testData = testResults.(testKey);
        pvalue = testData.pvalue;
        
        if showAllPvalues || pvalue < 0.05
            newPair = struct(...
                'param1', {testData.group1}, ...
                'param2', {testData.group2}, ...
                'pvalue', pvalue, ...
                'stars', {boxplotPToStars(pvalue)});
            significantPairs = [significantPairs; newPair];
        end
    end
    
    if isempty(significantPairs)
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
    
    % Параметры для позиционирования скобок
    yRange = yLimits(2) - yLimits(1);
    yBaseOffset = yRange * 0.05;
    yLevelSpacing = yRange * 0.08;
    yTextOffset = yRange * 0.015;
    bracketWallHeight = yRange * 0.03;
    
    % Рисуем скобки
    hold(ax, 'on');
    
    for i = 1:length(significantPairs)
        pair = significantPairs(i);
        level = levels(i);
        
        param1 = pair.param1;
        param2 = pair.param2;
        
        if ~isKey(paramPositions, param1) || ~isKey(paramPositions, param2)
            continue
        end
        
        pos1 = paramPositions(param1);
        pos2 = paramPositions(param2);
        
        yLine = yLimits(2) + yBaseOffset + level * yLevelSpacing;
        yWallBottom = yLine - bracketWallHeight;
        yText = yLine + yTextOffset;
        
        % Горизонтальная линия
        line(ax, [pos1, pos2], [yLine, yLine], 'Color', 'k', 'LineWidth', 1.5);
        
        % Вертикальные стенки
        line(ax, [pos1, pos1], [yLine, yWallBottom], 'Color', 'k', 'LineWidth', 1.5);
        line(ax, [pos2, pos2], [yLine, yWallBottom], 'Color', 'k', 'LineWidth', 1.5);
        
        % Текст с p-value
        if pair.pvalue >= 0.001
            ptext = sprintf('p=%.3f', pair.pvalue);
        else
            ptext = 'p<0.001';
        end
        
        starsStr = pair.stars;
        if iscell(starsStr)
            starsStr = starsStr{1};
        end
        
        annotationText = sprintf('%s %s', ptext, starsStr);
        
        text(ax, (pos1 + pos2) / 2, yText, annotationText, ...
            'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'bottom', ...
            'FontSize', 10, ...
            'Color', 'k', ...
            'BackgroundColor', [1, 1, 1, 0.9], ...
            'EdgeColor', 'k', ...
            'LineWidth', 1, ...
            'Margin', 2);
    end
end

