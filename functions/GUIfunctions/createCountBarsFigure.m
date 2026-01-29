function createCountBarsFigure(fig, state)
    % Построение графика с барами количества элементов
    % Использует структуру state.filteredData для получения данных
    % Бары показывают количество элементов для каждого параметра
    
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
        
        % Собираем данные для баров: количество элементов для каждого параметра
        xPositions = [];
        counts = [];
        colors = [];
        displayLabels = {};
        
        for p = 1:length(paramsInGroup)
            paramData = paramsInGroup{p};
            
            % Вычисляем количество элементов
            if isfield(paramData, 'stats') && isfield(paramData.stats, 'count')
                count = paramData.stats.count - paramData.stats.nanCount;
            else
                if ~isempty(paramData.data)
                    count = length(paramData.data(~isnan(paramData.data)));
                else
                    count = 0;
                end
            end
            
            % Определяем displayLabel
            if ~isempty(paramData.label)
                displayLabel = paramData.label;
            else
                displayLabel = paramData.column;
            end
            
            % Сохраняем данные для построения баров
            xPositions(end+1) = length(xPositions) + 1;
            counts(end+1) = count;
            colors(end+1, :) = paramData.parsedColor;
            displayLabels{end+1} = displayLabel;
        end
        
        % Построение баров
        if ~isempty(xPositions) && ~isempty(counts)
            % Используем bar() для построения вертикальных баров
            % Бары автоматически идут от нуля до значения количества
            barHandle = bar(ax, xPositions, counts, 'FaceColor', 'flat', 'CData', colors, ...
                'EdgeColor', 'none', 'BarWidth', 0.6);
            
            % Подписи оси X: displayLabel (как в боксплотах)
            set(ax, 'XTick', xPositions, 'XTickLabel', displayLabels, 'TickLabelInterpreter', 'none');
            
            % Добавляем значения количества на бары, если включена статистика
            if state.showStatistics
                for i = 1:length(xPositions)
                    if counts(i) > 0
                        text(ax, xPositions(i), counts(i), sprintf('n=%d', counts(i)), ...
                            'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
                            'FontSize', 9, 'Color', colors(i, :), ...
                            'Interpreter', 'none');
                    end
                end
            end
        end
        
        % Подписи осей
        ylabel(ax, 'Count', 'Interpreter', 'none');
        setSubplotGroupTitle(ax, groupName, nPlotGroups);
        if plotGroupIdx == nPlotGroups
            xlabel(ax, 'Groups', 'Interpreter', 'none');
        end
        
        % Настройка диапазона Y-оси
        if strcmp(state.yAxisRange, 'manual') && ~isempty(state.yAxisMin) && ~isempty(state.yAxisMax)
            ylim(ax, [state.yAxisMin, state.yAxisMax]);
        elseif strcmp(state.yAxisRange, 'auto')
            % Автоматический расчет пределов
            if ~isempty(counts) && max(counts) > 0
                yMax = max(counts) * 1.1;
                ylim(ax, [0, yMax]);
            else
                ylim(ax, [0, 1]);
            end
        end
        
        % Настройка диапазона X-оси
        if strcmp(state.xAxisRange, 'manual') && ~isempty(state.xAxisMin) && ~isempty(state.xAxisMax)
            xlim(ax, [state.xAxisMin, state.xAxisMax]);
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
