function createHistogramFigure(fig, state)
    % Построение гистограмм
    % Группирует данные по groupName из параметров анализа (как в boxplot)
    
    % Находим панель для графиков
    plotPanel = findobj(fig, 'Tag', 'plotPanel');
    
    % Очищаем содержимое панели
    delete(plotPanel.Children);
    
    % Проверяем наличие структуры с данными
    if isempty(state.filteredData) || isempty(fieldnames(state.filteredData))
        return
    end
    
    % Проверяем наличие колонки Group в исходной таблице (для группировки данных внутри параметра)
    if ~ismember('Group', state.table.Properties.VariableNames)
        % Если нет колонки Group, просто строим гистограммы без группировки
        useGroupColumn = false;
    else
        useGroupColumn = true;
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
        
        % Создаем ось через nexttile (tiledlayout автоматически управляет позицией)
        ax = nexttile(t);
        hold(ax, 'on');
        
        % Для каждого параметра в группе получаем данные, группируя по колонке Group из таблицы
        paramGroups = {};
        
        for p = 1:length(paramsInGroup)
            paramData = paramsInGroup{p};
            
            if isempty(paramData.data)
                continue
            end
            
            % Получаем фильтр для этого параметра
            filterStr = paramData.filter;
            if isempty(filterStr)
                filterStr = '';
            end
            
            % Применяем фильтр к исходной таблице
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
            
            if isempty(filteredTable) || ~ismember(paramData.column, filteredTable.Properties.VariableNames)
                continue
            end
            
            if useGroupColumn && ismember('Group', filteredTable.Properties.VariableNames)
                % Группируем данные по колонке Group из таблицы
                rawColumnData = filteredTable{:, paramData.column};
                if isnumeric(rawColumnData)
                    columnData = double(rawColumnData);
                else
                    columnData = [];
                end
                groupData = filteredTable{:, 'Group'};
                
                if isempty(columnData)
                    continue
                end
                
                % Группируем данные по Group
                uniqueGroups = unique(groupData);
                for g = 1:length(uniqueGroups)
                    groupValue = uniqueGroups(g);
                    groupMask = groupData == groupValue;
                    groupColumnData = columnData(groupMask);
                    
                    if isempty(groupColumnData)
                        continue
                    end
                    
                    paramGroup = struct();
                    paramGroup.data = groupColumnData;
                    paramGroup.column = paramData.column;
                    paramGroup.label = paramData.label;
                    paramGroup.parsedColor = paramData.parsedColor;
                    paramGroup.lineWidth = paramData.lineWidth;
                    paramGroup.groupValue = groupValue;
                    paramGroup.fieldName = paramData.fieldName;
                    paramGroups{end+1} = paramGroup;
                end
            else
                % Нет колонки Group - используем данные напрямую
                paramGroup = struct();
                paramGroup.data = paramData.data;
                paramGroup.column = paramData.column;
                paramGroup.label = paramData.label;
                paramGroup.parsedColor = paramData.parsedColor;
                paramGroup.lineWidth = paramData.lineWidth;
                paramGroup.groupValue = '';
                paramGroup.fieldName = paramData.fieldName;
                paramGroups{end+1} = paramGroup;
            end
        end
        
        if isempty(paramGroups)
            delete(ax);
            continue
        end
        
        % Собираем все данные для определения общего диапазона бинов
        allData = [];
        for g = 1:length(paramGroups)
            allData = [allData; paramGroups{g}.data];
        end
        
        if isempty(allData)
            delete(ax);
            continue
        end
        
        % Определяем диапазон и количество бинов
        if strcmp(state.xAxisRange, 'manual') && ~isempty(state.xAxisMin) && ~isempty(state.xAxisMax)
            % Если X-ось в manual режиме, используем лимиты X
            dataMin = state.xAxisMin;
            dataMax = state.xAxisMax;
            
            % Вычисляем количество бинов, кратное 10
            range = dataMax - dataMin;
            nBins = round(range);
            % Округляем до ближайшего кратного 10
            nBins = round(nBins / 10) * 10;
            if nBins < 10
                nBins = 10;
            end
        else
            % Автоматический режим: используем правило Стёрджеса
            n = length(allData);
            nBins = ceil(1 + log2(n));
            if nBins < 10
                nBins = 10;
            elseif nBins > 50
                nBins = 50;
            end
            
            % Определяем диапазон для бинов из данных
            dataMin = min(allData);
            dataMax = max(allData);
            if dataMin == dataMax
                if dataMin == 0
                    dataMin = -0.1;
                    dataMax = 0.1;
                else
                    offset = abs(dataMin) * 0.01;
                    dataMin = dataMin - offset;
                    dataMax = dataMax + offset;
                end
            end
        end
        
        binEdges = linspace(dataMin, dataMax, nBins + 1);
        
        % Строим гистограммы для каждой группы
        for g = 1:length(paramGroups)
            paramGroup = paramGroups{g};
            data = paramGroup.data;
            color = paramGroup.parsedColor;
            
            % Вычисляем гистограмму
            counts = histcounts(data, binEdges);
            binCenters = (binEdges(1:end-1) + binEdges(2:end)) / 2;
            
            % Строим столбцы гистограммы
            bar(ax, binCenters, counts, 'FaceColor', color, 'EdgeColor', color * 0.7, ...
                'FaceAlpha', 0.6, 'BarWidth', 0.8);
        end
        
        % Подписи осей
        if length(paramsInGroup) == 1
            label = paramsInGroup{1}.label;
            if isempty(label)
                label = paramsInGroup{1}.column;
            end
            xlabel(ax, label, 'Interpreter', 'none');
        else
            lbl = groupName;
            if isempty(lbl)
                lbl = '(no name)';
            end
            xlabel(ax, lbl, 'Interpreter', 'none');
        end
        ylabel(ax, 'N', 'Interpreter', 'none', 'rotation', 0);
        
        % Заголовок будет добавлен через tiledlayout после цикла
        
        % Настройка диапазона Y-оси
        if strcmp(state.yAxisRange, 'manual') && ~isempty(state.yAxisMin) && ~isempty(state.yAxisMax)
            ylim(ax, [state.yAxisMin, state.yAxisMax]);
        end
        
        % Настройка диапазона X-оси
        if strcmp(state.xAxisRange, 'manual') && ~isempty(state.xAxisMin) && ~isempty(state.xAxisMax)
            xlim(ax, [state.xAxisMin, state.xAxisMax]);
        end
        
        % Легенда (показываем источник данных - Column)
        if state.showLegend && length(paramGroups) > 0
            groupLabels = cell(length(paramGroups), 1);
            for g = 1:length(paramGroups)
                groupLabels{g} = paramGroups{g}.column;
            end
            legend(ax, groupLabels, 'Location', 'best', 'Interpreter', 'none');
        end
        
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
