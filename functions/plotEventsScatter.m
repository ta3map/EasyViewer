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
        % colors_in содержит цвета для активных каналов в том же порядке, что и activeChannels
        channelColorsList = calcResult.colors_in;
        activeChannels = calcResult.activeChannels;
        
        % Создаем маппинг глобальный индекс канала -> цвет
        for i = 1:length(events.times)
            if i <= length(events.channels)
                channelIdx = events.channels(i);
                % Находим позицию канала в activeChannels
                activeChIdx = find(activeChannels == channelIdx, 1);
                if ~isempty(activeChIdx) && activeChIdx <= length(channelColorsList)
                    channelColors{i} = channelColorsList{activeChIdx};
                else
                    channelColors{i} = 'r'; % по умолчанию красный
                end
            else
                channelColors{i} = 'r';
            end
        end
    else
        % Если нет информации о каналах, используем красный цвет
        channelColors = repmat({'r'}, 1, length(events.times));
    end
    
    % Построение scatter-plot с цветами каналов и прозрачностью
    if length(channelColors) == length(eventTimes)
        % Используем разные цвета для каждого события с прозрачностью
        for i = 1:length(eventTimes)
            scatter(scatterAx, eventTimes(i), eventIndices(i), 45, 'filled', ...
                'MarkerFaceColor', channelColors{i}, 'MarkerFaceAlpha', 0.6);
        end
    else
        % Fallback: один цвет для всех
        scatter(scatterAx, eventTimes, eventIndices, 45, 'filled', ...
            'MarkerFaceColor', 'r', 'MarkerFaceAlpha', 0.6);
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
    
    debugState('plotEventsScatter', 'Scatter plot completed');
end

