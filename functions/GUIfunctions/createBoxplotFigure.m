function createBoxplotFigure(fig, state)
    % Построение графика с боксплотами
    % Использует структуру state.filteredData для получения данных
    
    % Дебаг в начале функции
    debugState('createBoxplotFigure', 'Entered function:');
    debugState('createBoxplotFigure', '  using filteredData structure');
    
    % Инициализация полей, если они отсутствуют (для совместимости со старыми состояниями)
    if ~isfield(state, 'showFileIds')
        state.showFileIds = false;
    end
    if ~isfield(state, 'showYValues')
        state.showYValues = false;
    end
    if ~isfield(state, 'showLegend')
        state.showLegend = true;
    end
    
    % Находим панель для графиков
    plotPanel = findobj(fig, 'Tag', 'plotPanel');
   
    % Очищаем содержимое панели
    delete(plotPanel.Children);
    
    % Проверяем наличие структуры с данными
    if isempty(state.filteredData) || isempty(fieldnames(state.filteredData))
        return
    end
    
    % Инициализируем структуру для статистических тестов
    statisticalTests = struct();
    
    % Получаем все поля из структуры filteredData
    filteredDataFields = fieldnames(state.filteredData);
    
    groupNames = {};
    for i = 1:length(filteredDataFields)
        fieldName = filteredDataFields{i};
        paramData = state.filteredData.(fieldName);
        if isstruct(paramData) && isfield(paramData, 'groupName')
            groupNames{end+1} = paramData.groupName;
        else
            groupNames{end+1} = '1';
        end
    end
    uniqueGroupNames = unique(groupNames, 'stable');
    nPlotGroups = length(uniqueGroupNames);
    
    t = tiledlayout(plotPanel, nPlotGroups, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    
    for plotGroupIdx = 1:nPlotGroups
        groupName = uniqueGroupNames{plotGroupIdx};
        
        paramsInGroup = {};
        for i = 1:length(filteredDataFields)
            fieldName = filteredDataFields{i};
            paramData = state.filteredData.(fieldName);
            if isstruct(paramData) && isfield(paramData, 'groupName') && strcmp(paramData.groupName, groupName)
                paramData.fieldName = fieldName;
                paramsInGroup{end+1} = paramData;
            end
        end
        
        % Создаем ось через nexttile (tiledlayout автоматически управляет позицией)
        ax = nexttile(t);
        hold(ax, 'on');
        
        % Строим боксплоты: один бокс на параметр (без объединения по displayLabel)
        allDataForGroup = [];
        groupLabelsForBoxplot = {};
        fileIdsForGroup = [];
        paramDataByFieldName = containers.Map();
        displayLabelsByFieldName = containers.Map(); % displayLabel для подписей оси X
        
        for p = 1:length(paramsInGroup)
            paramData = paramsInGroup{p};
            if isempty(paramData.data)
                continue
            end
            data = paramData.data;
            if ~isempty(paramData.label)
                displayLabel = paramData.label;
            else
                displayLabel = paramData.column;
            end
            
            allDataForGroup = [allDataForGroup; data];
            groupLabelsForBoxplot = [groupLabelsForBoxplot; repmat({paramData.fieldName}, length(data), 1)];
            if isfield(paramData, 'fileIds') && ~isempty(paramData.fileIds) && length(paramData.fileIds) == length(data)
                fileIdsForGroup = [fileIdsForGroup; paramData.fileIds(:)];
            else
                fileIdsForGroup = [fileIdsForGroup; NaN(length(data), 1)];
            end
            paramDataByFieldName(paramData.fieldName) = paramData;
            displayLabelsByFieldName(paramData.fieldName) = displayLabel;
        end
        
        % Построение боксплотов
        if ~isempty(allDataForGroup)
            boxplot(ax, allDataForGroup, groupLabelsForBoxplot, 'Symbol', '');
            hold(ax, 'on');
            
            uniqueGroupLabels = unique(groupLabelsForBoxplot, 'stable');
            fieldNameToPosition = containers.Map();
            for g = 1:length(uniqueGroupLabels)
                fieldNameToPosition(uniqueGroupLabels{g}) = g;
            end
            
            % Находим все patch объекты (боксы)
            allChildren = get(ax, 'Children');
            boxPatches = [];
            for i = 1:length(allChildren)
                if strcmp(get(allChildren(i), 'Type'), 'patch')
                    boxPatches = [boxPatches; allChildren(i)];
                end
            end
            
            % Сортируем patch объекты по их X координатам
            if ~isempty(boxPatches)
                xPositions = zeros(length(boxPatches), 1);
                for i = 1:length(boxPatches)
                    xData = get(boxPatches(i), 'XData');
                    if ~isempty(xData)
                        xPositions(i) = mean(xData);
                    else
                        % Если XData пуст, используем Vertices
                        vertices = get(boxPatches(i), 'Vertices');
                        if ~isempty(vertices)
                            xPositions(i) = mean(vertices(:, 1));
                        end
                    end
                end
                [~, sortIdx] = sort(xPositions);
                boxPatches = boxPatches(sortIdx);
            end
            
            % Находим все line объекты
            allLines = findobj(ax, 'Type', 'line');
            
            for g = 1:length(uniqueGroupLabels)
                fieldName = uniqueGroupLabels{g};
                paramDataForLabel = paramDataByFieldName(fieldName);
                color = paramDataForLabel.parsedColor;
                paramLineWidth = paramDataForLabel.lineWidth;
                
                if ~isempty(boxPatches) && g <= length(boxPatches)
                    set(boxPatches(g), 'FaceColor', color, 'EdgeColor', color * 0.7, 'LineWidth', paramLineWidth);
                end
                xPos = g;
                for i = 1:length(allLines)
                    xData = get(allLines(i), 'XData');
                    if ~isempty(xData)
                        xMean = mean(xData);
                        if abs(xMean - xPos) < 0.3
                            currentLineWidth = get(allLines(i), 'LineWidth');
                            if currentLineWidth > 1
                                set(allLines(i), 'Color', color * 0.5, 'LineWidth', paramLineWidth);
                            else
                                set(allLines(i), 'Color', color, 'LineWidth', paramLineWidth);
                            end
                        end
                    end
                end
            end
            
            % Точки данных с jitter, File ID, Y-значения, n=X
            for g = 1:length(uniqueGroupLabels)
                fieldName = uniqueGroupLabels{g};
                mask = strcmp(groupLabelsForBoxplot, fieldName);
                data = allDataForGroup(mask);
                fileIdsForLabel = fileIdsForGroup(mask);
                if isempty(data)
                    continue
                end
                paramDataForLabel = paramDataByFieldName(fieldName);
                color = paramDataForLabel.parsedColor;
                paramLineWidth = paramDataForLabel.lineWidth;
                x_pos = g;
                x_jitter = x_pos + 0.1 * (rand(size(data)) - 0.5);
                markerSize = paramLineWidth * 30;
                scatter(ax, x_jitter, data, markerSize, color, 'o', ...
                    'MarkerFaceColor', color, ...
                    'MarkerEdgeColor', 'white', ...
                    'LineWidth', paramLineWidth, ...
                    'MarkerFaceAlpha', 1);
                dataRange = max(data) - min(data);
                if dataRange == 0
                    dataRange = abs(max(data)) * 0.01;
                    if dataRange == 0
                        dataRange = 1;
                    end
                end
                if state.showFileIds && ~isempty(fileIdsForLabel)
                    plotFileIdsOnAxes(ax, x_jitter, data, fileIdsForLabel, -0.05, 0.01 * dataRange, true);
                end
                if state.showYValues
                    plotYValuesOnAxes(ax, x_jitter, data, data, 0.05, 0.01 * dataRange, '%.3f', true);
                end
                medianVal = paramDataForLabel.stats.median;
                if isnan(medianVal)
                    medianVal = median(data);
                end
                if state.showStatistics
                    s = paramDataForLabel.stats;
                    q25 = s.q25;
                    q75 = s.q75;
                    if ~isnan(q25) && ~isnan(q75)
                        statsStr = sprintf('n=%d\nM=%.3f\n[%.2f–%.2f]', length(data), medianVal, q25, q75);
                    else
                        statsStr = sprintf('n=%d\nM=%.3f\n—', length(data), medianVal);
                    end
                    text(ax, x_pos - 0.4, medianVal, statsStr, ...
                        'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle', ...
                        'FontSize', 9, 'Color', color, 'BackgroundColor', 'white', ...
                        'Interpreter', 'none');
                end
            end
            
            % Подписи оси X: displayLabel (дубликаты допустимы)
            tickLabels = cell(1, length(uniqueGroupLabels));
            for g = 1:length(uniqueGroupLabels)
                tickLabels{g} = displayLabelsByFieldName(uniqueGroupLabels{g});
            end
            set(ax, 'XTick', 1:length(uniqueGroupLabels), 'XTickLabel', tickLabels);
            
            % Вычисляем статистические тесты между параметрами на этом полотне
            if state.showStatistics && length(paramDataByFieldName) >= 2
                % Выполняем попарные тесты между параметрами
                paramKeys = keys(paramDataByFieldName);
                testResultsForGroup = struct();
                for i = 1:length(paramKeys)
                    for j = i+1:length(paramKeys)
                        param1 = paramKeys{i};
                        param2 = paramKeys{j};
                        
                        data1 = paramDataByFieldName(param1).data;
                        data2 = paramDataByFieldName(param2).data;
                        
                        if length(data1) > 0 && length(data2) > 0
                            try
                                [~, pvalue] = ttest2(data1, data2);
                                testKey = sprintf('%s_vs_%s', matlab.lang.makeValidName(param1), matlab.lang.makeValidName(param2));
                                testResultsForGroup.(testKey) = struct(...
                                    'pvalue', pvalue, ...
                                    'n1', length(data1), ...
                                    'n2', length(data2), ...
                                    'group1', param1, ...
                                    'group2', param2);
                            catch
                                % Игнорируем ошибки тестов
                            end
                        end
                    end
                end
                
                gnForKey = groupName;
                if isempty(gnForKey)
                    gnForKey = 'noname';
                end
                paramKeyValid = matlab.lang.makeValidName(sprintf('Group_%s', gnForKey));
                statisticalTests.(paramKeyValid) = testResultsForGroup;
                
                if ~isempty(testResultsForGroup) && ~isempty(fieldnames(testResultsForGroup))
                    gnDisp = groupName;
                    if isempty(gnDisp)
                        gnDisp = '(no name)';
                    end
                    fprintf('\n=== Statistical Tests for Group %s ===\n', gnDisp);
                    fprintf('%-30s %-30s %12s %8s %8s %12s\n', 'Parameter 1', 'Parameter 2', 'p-value', 'n1', 'n2', 'Significant');
                    fprintf('%s\n', repmat('-', 1, 100));
                    testFields = fieldnames(testResultsForGroup);
                    for i = 1:length(testFields)
                        testKey = testFields{i};
                        testData = testResultsForGroup.(testKey);
                        significant = testData.pvalue < 0.05;
                        sigStr = 'Yes';
                        if ~significant
                            sigStr = 'No';
                        end
                        fprintf('%-30s %-30s %12.6f %8d %8d %12s\n', ...
                            testData.group1, testData.group2, testData.pvalue, ...
                            testData.n1, testData.n2, sigStr);
                    end
                    fprintf('\n');
                end
            end
        end
        
        yLabelText = groupName;
        if isempty(yLabelText)
            yLabelText = '(no name)';
        end
        ylabel(ax, yLabelText, 'Interpreter', 'none');
        if plotGroupIdx == nPlotGroups
            xlabel(ax, 'Groups', 'Interpreter', 'none');
        end
        
        % Настройка диапазона Y-оси
        if strcmp(state.yAxisRange, 'manual') && ~isempty(state.yAxisMin) && ~isempty(state.yAxisMax)
            ylim(ax, [state.yAxisMin, state.yAxisMax]);
        elseif strcmp(state.yAxisRange, 'auto')
            % Автоматический расчет пределов по процентилям 0.001 и 99.99
            if ~isempty(allDataForGroup)
                yMin = prctile(allDataForGroup, 0.001);
                yMax = prctile(allDataForGroup, 99.99);
                % Если все значения одинаковые, добавляем небольшой отступ
                if yMin == yMax
                    if yMin == 0
                        yMin = -0.1;
                        yMax = 0.1;
                    else
                        offset = abs(yMin) * 0.01;
                        yMin = yMin - offset;
                        yMax = yMax + offset;
                    end
                end
                ylim(ax, [yMin, yMax]);
            end
        end
        
        % Настройка диапазона X-оси
        if strcmp(state.xAxisRange, 'manual') && ~isempty(state.xAxisMin) && ~isempty(state.xAxisMax)
            xlim(ax, [state.xAxisMin, state.xAxisMax]);
        end
        
        if state.showStatistics
            gnForKey = groupName;
            if isempty(gnForKey)
                gnForKey = 'noname';
            end
            paramKeyValid = matlab.lang.makeValidName(sprintf('Group_%s', gnForKey));
            
            if isfield(statisticalTests, paramKeyValid)
                currentYLim = ylim(ax);
                
                % Вычисляем максимальный уровень скобок
                maxLevel = boxplotCalculateMaxBracketLevelForParams(statisticalTests.(paramKeyValid), fieldNameToPosition, state.showAllPvalues);
                
                % Рисуем скобки между параметрами
                boxplotAddSignificanceBracketsForParams(ax, fieldNameToPosition, ...
                    statisticalTests.(paramKeyValid), ...
                    state.showAllPvalues, currentYLim);
                
                % Обновляем пределы Y-оси чтобы вместить скобки
                if maxLevel >= 0
                    yRange = currentYLim(2) - currentYLim(1);
                    yBaseOffset = yRange * 0.05;
                    yLevelSpacing = yRange * 0.08;
                    yTextOffset = yRange * 0.015;
                    newYMax = currentYLim(2) + yBaseOffset + maxLevel * yLevelSpacing + yTextOffset;
                    ylim(ax, [currentYLim(1), newYMax]);
                end
            end
        end
        
    end
    
    % Добавляем общий заголовок через tiledlayout
    if nPlotGroups > 0
        title(t, state.title, 'FontSize', 14, 'FontWeight', 'bold', 'Interpreter', 'none');
        zoom(fig, 'on');
        pan(fig, 'on');
    end
end
