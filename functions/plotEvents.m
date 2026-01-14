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
    
    % Отображаем точки онсетов
    if isfield(events, 'onset_times') && isfield(events, 'onset_values') && ...
       ~isempty(events.onset_times) && ~isempty(events.onset_values)
        num_onsets = 0;
        for i = 1:length(events.times)
            if i <= length(events.onset_times) && ~isnan(events.onset_times(i)) && ~isnan(events.onset_values(i))
                onset_time = events.onset_times(i);
                onset_value = events.onset_values(i);
                
                if onset_time >= timeAxis(1) && onset_time <= timeAxis(end)
                    % Определяем Y позицию на основе канала и значения онсета
                    if isfield(events, 'channels') && ~isempty(events.channels) && i <= length(events.channels)
                        channelIdx = events.channels(i);
                        activeChIdx = find(calcResult.activeChannels == channelIdx, 1);
                        if ~isempty(activeChIdx) && activeChIdx <= length(offsets)
                            % onset_value должен быть в той же системе координат, что и отрисованные трейсы
                            yPos = offsets(activeChIdx);
                            yPos = yPos + onset_value;
                        else
                            yPos = onset_value;
                        end
                    else
                        yPos = onset_value;
                    end
                    
                    % Отображаем точку онсета текстом
                    text(onset_time, yPos, '•', ...
                        'HorizontalAlignment', 'center', ...
                        'VerticalAlignment', 'middle', ...
                        'FontSize', 12, ...
                        'Color', 'r', ...
                        'FontWeight', 'bold');
                    num_onsets = num_onsets + 1;
                end
            end
        end
        if num_onsets > 0
            debugState('plotEvents', 'Displayed %d onset markers', num_onsets);
        end
    end
    
    hold off;
end

