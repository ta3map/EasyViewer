function fig = plotEvents(fig, events, calcResult)
    % Отображение событий на графике средних данных
    % fig - handle фигуры
    % events - структура с событиями (times, amplitudes, channels)
    % calcResult - результат расчета средних данных
    
    if isempty(events.times) || events.numEvents == 0
        return;
    end
    
    figure(fig);
    ax = findobj(fig, 'Type', 'axes', '-not', 'Tag', 'legend');
    ax = ax(1);
    axes(ax);
    hold on;
    
    timeAxis = calcResult.timeAxisScaled;
    offsets = zeros(1, length(calcResult.activeChannels));
    for p = 1:length(calcResult.activeChannels)
        offsets(p) = -(p-1) * calcResult.shiftCoeff;
    end
    
    % Определяем направление стрелки в зависимости от полярности
    if isfield(events, 'polarity') && strcmpi(events.polarity, 'positive')
        arrowChar = char(8593); % ↑ стрелка вверх
    else
        arrowChar = char(8595); % ↓ стрелка вниз
    end
    
    % Получаем базовые линии для каждого канала
    baseline_medians = [];
    if isfield(calcResult, 'baseline_medians')
        baseline_medians = calcResult.baseline_medians;
    end
    
    % Отображаем события стрелками
    for i = 1:length(events.times)
        event_time = events.times(i);
        if event_time >= timeAxis(1) && event_time <= timeAxis(end)
            % Определяем Y позицию на основе канала события
            if isfield(events, 'channels') && ~isempty(events.channels) && i <= length(events.channels)
                channelIdx = events.channels(i);
                % Находим индекс канала в activeChannels
                activeChIdx = find(calcResult.activeChannels == channelIdx, 1);
                if ~isempty(activeChIdx) && activeChIdx <= length(offsets)
                    yPos = offsets(activeChIdx);
                    % Добавляем базовую линию если доступна
                    if ~isempty(baseline_medians) && activeChIdx <= length(baseline_medians)
                        yPos = yPos + baseline_medians(activeChIdx);
                    end
                else
                    yPos = 0;
                end
            else
                yPos = 0;
            end
            
            text(event_time, yPos, arrowChar, ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'middle', ...
                'FontSize', 12, ...
                'Color', 'r', ...
                'FontWeight', 'bold');
        end
    end
    
    hold off;
end

