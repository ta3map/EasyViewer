function createCorrelationFigure(fig, state)
    % Построение корреляционных графиков
    % Группирует параметры по одинаковому фильтру и строит пары
    
    % Находим панель для графиков
    plotPanel = findobj(fig, 'Tag', 'plotPanel');
    
    % Очищаем содержимое панели
    delete(plotPanel.Children);
    
    % Проверяем наличие структуры с данными
    if isempty(state.filteredData) || isempty(fieldnames(state.filteredData))
        return
    end
    
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
    
    if nPlotGroups == 0
        return
    end
    
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
        
        if isempty(paramsInGroup)
            continue
        end
        
        % Создаем ось для этой группы
        ax = nexttile(t);
        hold(ax, 'on');
        
        % Группируем параметры внутри группы по фильтру
        filterGroups = containers.Map();
        for i = 1:length(paramsInGroup)
            paramData = paramsInGroup{i};
            filterKey = paramData.filter;
            if isempty(filterKey)
                filterKey = '';
            end
            
            if ~isKey(filterGroups, filterKey)
                filterGroups(filterKey) = {};
            end
            filterGroups(filterKey) = [filterGroups(filterKey), {paramData}];
        end
        
        filterKeys = keys(filterGroups);
        
        % Собираем уникальные Label для X и Y осей
        uniqueXLabels = {};
        uniqueYLabels = {};
        
        % Массивы для легенды
        legendHandles = {};
        legendLabels = {};
        
        % Обрабатываем каждую группу фильтров внутри этой группы
        for filterIdx = 1:length(filterKeys)
            filterKey = filterKeys{filterIdx};
            paramsInFilter = filterGroups(filterKey);
            
            % Формируем пары по порядку следования
            numParams = length(paramsInFilter);
            numPairs = floor(numParams / 2);
            
            % Строим пары на том же axes
            for pairIdx = 1:numPairs
                param1 = paramsInFilter{2*pairIdx - 1};
                param2 = paramsInFilter{2*pairIdx};
                
                % Собираем Label для X-оси (из param1)
                label1 = param1.label;
                if isempty(label1)
                    label1 = param1.column;
                end
                if ~ismember(label1, uniqueXLabels)
                    uniqueXLabels{end+1} = label1;
                end
                
                % Собираем Column для Y-оси (из param2)
                if isfield(param2, 'column') && ~isempty(param2.column)
                    col2 = param2.column;
                    if ~ismember(col2, uniqueYLabels)
                        uniqueYLabels{end+1} = col2;
                    end
                end
                
                if isempty(param1.data) || isempty(param2.data)
                    continue
                end
            
            % Получаем данные из исходной таблицы с одинаковым фильтром
            % Если фильтр одинаковый, данные должны быть синхронизированы по строкам
            filterStr = param1.filter;
            if isempty(filterStr)
                filterStr = '';
            end
            
            % Применяем фильтр к исходной таблице один раз
            if ~isempty(filterStr)
                parsedFilters = boxplotParseGroupFilters(filterStr);
                if ~isempty(parsedFilters)
                    filteredTable = boxplotApplyGroupFilters(state.table, parsedFilters);
                else
                    filteredTable = state.table;
                end
            else
                filteredTable = state.table;
            end
            
            if isempty(filteredTable) || ...
               ~ismember(param1.column, filteredTable.Properties.VariableNames) || ...
               ~ismember(param2.column, filteredTable.Properties.VariableNames)
                continue
            end
            
            % Получаем данные из отфильтрованной таблицы
            xColumnData = filteredTable{:, param1.column};
            yColumnData = filteredTable{:, param2.column};
            if isnumeric(xColumnData)
                xData = double(xColumnData);
            else
                xData = [];
            end
            if isnumeric(yColumnData)
                yData = double(yColumnData);
            else
                yData = [];
            end
            
            % Получаем FileID если доступен
            fileIds = [];
            if ismember('FileID', filteredTable.Properties.VariableNames)
                fileIds = filteredTable{:, 'FileID'};
            end
            
            % Фильтруем NaN значения для синхронизации данных
            if ~isempty(xData) && ~isempty(yData)
                validMask = ~isnan(xData) & ~isnan(yData) & ~isinf(xData) & ~isinf(yData);
                xData = xData(validMask);
                yData = yData(validMask);
                if ~isempty(fileIds) && length(fileIds) == length(validMask)
                    fileIds = fileIds(validMask);
                end
            end
            
            if length(xData) < 2
                continue
            end
            
            % Получаем цвет X параметра
            pointColor = param1.parsedColor;
            lineColor = param1.parsedColor;
            
            % Scatter plot
            hScatter = scatter(ax, xData, yData, 50, pointColor, 'o', ...
                'MarkerFaceColor', pointColor, ...
                'MarkerEdgeColor', 'white', ...
                'LineWidth', 1, ...
                'MarkerFaceAlpha', 0.7);
            
            % Отображение File ID рядом с точками (если включено)
            if state.showFileIds && ~isempty(fileIds)
                plotFileIdsOnAxes(ax, xData, yData, fileIds, -0.01, 0.01);
            end
            
            % Отображение значений Y рядом с точками (если включено)
            if state.showYValues
                plotYValuesOnAxes(ax, xData, yData, yData, 0.01, 0.01, '(%.3f,%.3f)');
            end
            
            % Добавляем в легенду (только точки, цвет определяется по X параметру)
            pairLabel = sprintf('%s vs %s', label1, label2);
            legendHandles{end+1} = hScatter;
            legendLabels{end+1} = pairLabel;
            
            % Линия регрессии и статистика (только если showStatistics включен)
            if state.showStatistics
                % Вычисление корреляции
                R = corrcoef(xData, yData);
                if size(R, 1) == 2 && size(R, 2) == 2
                    corrCoeff = R(1, 2);
                    R2 = corrCoeff^2;
                else
                    corrCoeff = NaN;
                    R2 = NaN;
                end
                
                % Статистика регрессии для p-value
                pValue = NaN;
                if length(xData) >= 2
                    try
                        [b, bint, r, rint, stats] = regress(yData, [ones(length(xData), 1), xData]);
                        if length(stats) >= 3
                            pValue = stats(3);
                        end
                    catch
                        % Игнорируем ошибки регрессии
                    end
                end
                
                % Линия регрессии
                p = polyfit(xData, yData, 1);
                xFit = linspace(min(xData), max(xData), 100);
                yFit = polyval(p, xFit);
                plot(ax, xFit, yFit, 'Color', lineColor, 'LineWidth', 2, 'LineStyle', '--');
                
                % Отображение статистики рядом с линией регрессии
                if ~isnan(R2) && ~isnan(pValue)
                % Позиция текста - на середине линии регрессии
                xPos = (min(xData) + max(xData)) / 2;
                yPos = polyval(p, xPos);
                
                if state.showAllPvalues
                    statsText = sprintf('R²=%.3f, p=%.4f, n=%d', R2, pValue, length(xData));
                else
                    if pValue < 0.05
                        statsText = sprintf('R²=%.3f, p=%.4f*, n=%d', R2, pValue, length(xData));
                    else
                        statsText = sprintf('R²=%.3f, n=%d', R2, length(xData));
                    end
                end
                
                text(ax, xPos, yPos, statsText, ...
                    'HorizontalAlignment', 'center', ...
                    'VerticalAlignment', 'middle', ...
                    'FontSize', 9, ...
                    'BackgroundColor', 'white', ...
                    'EdgeColor', lineColor, ...
                    'LineWidth', 1, ...
                    'Interpreter', 'none');
                end
            end
            
        end
        
        % Если нечетное количество параметров, показываем последний отдельно на том же axes
        if mod(numParams, 2) == 1
            param = paramsInFilter{end};
            
            % Собираем Label для X-оси и Column для Y-оси одиночного параметра
            label = param.label;
            if isempty(label)
                label = param.column;
            end
            if ~ismember(label, uniqueXLabels)
                uniqueXLabels{end+1} = label;
            end
            % Для Y-оси используем column
            if isfield(param, 'column') && ~isempty(param.column)
                col = param.column;
                if ~ismember(col, uniqueYLabels)
                    uniqueYLabels{end+1} = col;
                end
            end
            
            if ~isempty(param.data)
                data = param.data;
                
                if length(data) > 0
                    % Получаем fileIds из структуры paramData или из filteredTable
                    fileIds = [];
                    if isfield(param, 'fileIds') && ~isempty(param.fileIds) && length(param.fileIds) == length(data)
                        fileIds = param.fileIds;
                    else
                        % Если fileIds нет в структуре, получаем из filteredTable
                        filterStr = param.filter;
                        if isempty(filterStr)
                            filterStr = '';
                        end
                        
                        if ~isempty(filterStr)
                            parsedFilters = boxplotParseGroupFilters(filterStr);
                            if ~isempty(parsedFilters)
                                filteredTable = boxplotApplyGroupFilters(state.table, parsedFilters);
                            else
                                filteredTable = state.table;
                            end
                        else
                            filteredTable = state.table;
                        end
                        
                        if ~isempty(filteredTable) && ismember('FileID', filteredTable.Properties.VariableNames) && ismember(param.column, filteredTable.Properties.VariableNames)
                            columnData = filteredTable{:, param.column};
                            if isnumeric(columnData)
                                columnData = double(columnData);
                                validMask = ~isnan(columnData) & ~isinf(columnData);
                                fileIds = filteredTable{:, 'FileID'};
                                fileIds = fileIds(validMask);
                            end
                        end
                    end
                    
                    % Простой scatter plot по индексам на том же axes
                    xData = 1:length(data);
                    hScatterSingle = scatter(ax, xData, data, 50, param.parsedColor, 'o', ...
                        'MarkerFaceColor', param.parsedColor, ...
                        'MarkerEdgeColor', 'white', ...
                        'LineWidth', 1, ...
                        'MarkerFaceAlpha', 0.7);
                    
                    % Отображение File ID рядом с точками (если включено)
                    if state.showFileIds && ~isempty(fileIds) && length(fileIds) == length(data)
                        plotFileIdsOnAxes(ax, xData, data, fileIds, -0.01, 0.01);
                    end
                    
                    % Отображение значений Y рядом с точками (если включено)
                    if state.showYValues
                        plotYValuesOnAxes(ax, xData, data, data, 0.01, 0.01, '%.3f');
                    end
                    
                    % Добавляем в легенду
                    legendHandles{end+1} = hScatterSingle;
                    legendLabels{end+1} = label;
                end
            end
        end
        end
        
        % Добавляем легенду
        if state.showLegend && ~isempty(legendHandles)
            legend(ax, [legendHandles{:}], legendLabels, 'Location', 'best', 'Interpreter', 'none');
        end
        
        % Настройка диапазонов осей (после всех графиков на axes)
        if strcmp(state.yAxisRange, 'manual') && ~isempty(state.yAxisMin) && ~isempty(state.yAxisMax)
            ylim(ax, [state.yAxisMin, state.yAxisMax]);
        elseif strcmp(state.yAxisRange, 'auto')
            % Автоматический расчет пределов по всем данным на axes
            yLimits = ylim(ax);
            if ~isinf(yLimits(1)) && ~isinf(yLimits(2))
                ylim(ax, yLimits);
            end
        end
        
        if strcmp(state.xAxisRange, 'manual') && ~isempty(state.xAxisMin) && ~isempty(state.xAxisMax)
            xlim(ax, [state.xAxisMin, state.xAxisMax]);
        elseif strcmp(state.xAxisRange, 'auto')
            % Автоматический расчет пределов по всем данным на axes
            xLimits = xlim(ax);
            if ~isinf(xLimits(1)) && ~isinf(xLimits(2))
                xlim(ax, xLimits);
            end
        end
        
        % Подписи осей для группы (после обработки всех фильтров)
        % Используем уникальные Label
        if ~isempty(uniqueXLabels)
            xLabelText = strjoin(uniqueXLabels, ', ');
            xlabel(ax, xLabelText, 'Interpreter', 'none');
        else
            lbl = groupName;
            if isempty(lbl)
                lbl = '(no name)';
            end
            xlabel(ax, lbl, 'Interpreter', 'none');
        end
        
        if ~isempty(uniqueYLabels)
            yLabelText = strjoin(uniqueYLabels, ', ');
        else
            yLabelText = '';
        end
        ylabel(ax, yLabelText, 'Interpreter', 'none');
        setSubplotGroupTitle(ax, groupName, nPlotGroups);
        
        % Сетка
        grid(ax, 'on');
    end
    
    % Добавляем общий заголовок через tiledlayout
    if nPlotGroups > 0
        title(t, state.title, 'FontSize', 14, 'FontWeight', 'bold', 'Interpreter', 'none');
        zoom(fig, 'on');
        pan(fig, 'on');
    end
end
