function plotEventsScatter(fig, events, calcResult)
    % Добавляет scatter-plot событий в фигуру
    % fig - handle фигуры
    % events - структура с событиями
    % calcResult - результат расчета средних данных
    
    figure(fig);
    
    if isempty(events.times)
        debugState('plotEventsScatter', 'events.times is empty, returning');
        return;
    end
    
    debugState('plotEventsScatter', 'Number of events: %d', length(events.times));
    
    % Находим tiledlayout в фигуре
    t = findobj(fig, 'Type', 'tiledlayout');
    if isempty(t)
        debugState('plotEventsScatter', 'tiledlayout not found, returning');
        return;
    end
    
    % Получаем пределы X из calcResult (они уже установлены из opts.xLimits)
    xLimits = calcResult.xLimits;
    debugState('plotEventsScatter', 'X limits from calcResult.xLimits: [%.3f, %.3f]', xLimits(1), xLimits(2));
    
    % Используем nexttile для добавления тайла для scatter-plot (последний тайл)
    scatterAx = nexttile(t);
    debugState('plotEventsScatter', 'Created scatter axis, position: [%.3f, %.3f, %.3f, %.3f]', ...
        scatterAx.Position(1), scatterAx.Position(2), scatterAx.Position(3), scatterAx.Position(4));
    
    % Убеждаемся, что ось видима и активна
    set(scatterAx, 'Visible', 'on');
    axes(scatterAx); % Активируем ось
    hold(scatterAx, 'on');
    
    % Подготовка данных для scatter-plot
    % Номер исходного события/стимула, к которому принадлежит обнаруженное событие
    if isfield(events, 'eventIndices') && ~isempty(events.eventIndices)
        eventIndices = events.eventIndices;
        debugState('plotEventsScatter', 'Using eventIndices from events structure, count: %d', length(eventIndices));
    else
        % Если нет информации о событии, используем порядковый номер
        eventIndices = 1:length(events.times);
        debugState('plotEventsScatter', 'Using sequential indices, count: %d', length(eventIndices));
    end
    
    % Время событий
    eventTimes = events.times;
    debugState('plotEventsScatter', 'Event times range: [%.3f, %.3f]', min(eventTimes), max(eventTimes));
    debugState('plotEventsScatter', 'Event indices range: [%d, %d]', min(eventIndices), max(eventIndices));
    
    % Получаем цвета каналов из calcResult
    channelColors = {};
    if isfield(calcResult, 'colors_in') && isfield(calcResult, 'activeChannels') && isfield(events, 'channels') && ~isempty(events.channels)
        channelColorsList = calcResult.colors_in;
        activeChannels = calcResult.activeChannels;
        
        for i = 1:length(events.times)
            if i <= length(events.channels)
                channelIdx = events.channels(i);
                activeChIdx = find(activeChannels == channelIdx, 1);
                if ~isempty(activeChIdx) && activeChIdx <= length(channelColorsList)
                    colorCell = channelColorsList(activeChIdx);
                    channelColors{i} = colorCell{:};
                end
            end
        end
    end
    
    % Построение scatter-plot с цветами каналов и прозрачностью
    if length(channelColors) == length(eventTimes)
        for i = 1:length(eventTimes)
            scatter(scatterAx, eventTimes(i), eventIndices(i), 45, 'filled', ...
                'MarkerFaceColor', channelColors{i}, 'MarkerFaceAlpha', 0.6);
        end
    end
    debugState('plotEventsScatter', 'Scatter plot created');
    
    % Настройка осей
    xlim(scatterAx, xLimits);
    if ~isempty(eventIndices)
        ylim(scatterAx, [min(eventIndices) - 0.5, max(eventIndices) + 0.5]);
    end
    xlabel(scatterAx, 'Time');
    ylabel(scatterAx, 'Original Event Index');
    title(scatterAx, 'Events Timeline');
    grid(scatterAx, 'on');
    
    % Вертикальная линия на нуле
    xline(scatterAx, 0, 'r:', 'LineWidth', 1);
    
    % Отображаем точки онсетов
    if isfield(events, 'onset_times') && isfield(events, 'onset_values') && ...
       ~isempty(events.onset_times) && ~isempty(events.onset_values) && ...
       length(events.onset_times) == length(events.times)
        for i = 1:length(events.times)
            if i <= length(events.onset_times) && ~isnan(events.onset_times(i))
                onset_time = events.onset_times(i);
                if onset_time >= xLimits(1) && onset_time <= xLimits(2)
                    onset_color = 'g';
                    if length(channelColors) == length(events.times) && i <= length(channelColors)
                        onset_color = channelColors{i};
                    end
                    scatter(scatterAx, onset_time, eventIndices(i), 45, '*', ...
                        'MarkerFaceColor', onset_color, 'MarkerEdgeColor', onset_color);
                end
            end
        end
    end
    
    debugState('plotEventsScatter', 'Scatter plot completed');
end

