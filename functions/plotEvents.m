function fig = plotEvents(fig, events, calcResult)
    % Отображение событий на графике средних данных
    % fig - handle фигуры
    % events - структура с событиями (times, amplitudes, channels)
    % calcResult - результат расчета средних данных
    
    if isempty(events.peak_times) || events.numEvents == 0
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
    
    % Создаем маппинг каналов для быстрого доступа
    channelMap = containers.Map('KeyType', 'double', 'ValueType', 'double');
    for i = 1:length(calcResult.activeChannels)
        channelMap(calcResult.activeChannels(i)) = i;
    end
    
    % Собираем все данные за один проход
    peak_x = [];
    peak_y = [];
    onset_x = [];
    onset_y = [];
    decay_x = [];
    decay_y = [];
    line_x = [];
    line_y = [];
    
    numEvents = length(events.peak_times);
    hasChannels = isfield(events, 'channels') && ~isempty(events.channels);
    
    for i = 1:numEvents
        % Определяем смещение канала
        y_offset = 0;
        if hasChannels && i <= length(events.channels)
            channelIdx = events.channels(i);
            if channelMap.isKey(channelIdx)
                activeChIdx = channelMap(channelIdx);
                if activeChIdx <= length(offsets)
                    y_offset = offsets(activeChIdx);
                end
            end
        end
        
        % Точки пиков
        if isfield(events, 'peaks') && i <= length(events.peaks) && ~isnan(events.peaks(i))
            event_time = events.peak_times(i);
            if event_time >= timeAxis(1) && event_time <= timeAxis(end)
                peak_x(end+1) = event_time;
                peak_y(end+1) = y_offset + events.peaks(i);
            end
        end
        
        % Точки онсетов
        if isfield(events, 'onset_times') && isfield(events, 'onset_values') && ...
           i <= length(events.onset_times) && ~isnan(events.onset_times(i)) && ~isnan(events.onset_values(i))
            onset_time = events.onset_times(i);
            if onset_time >= timeAxis(1) && onset_time <= timeAxis(end)
                onset_x(end+1) = onset_time;
                onset_y(end+1) = y_offset + events.onset_values(i);
            end
        end
        
        % Точки спада
        if isfield(events, 'decay_times') && isfield(events, 'decay_values') && ...
           i <= length(events.decay_times) && ~isnan(events.decay_times(i)) && ~isnan(events.decay_values(i))
            decay_time = events.decay_times(i);
            if decay_time >= timeAxis(1) && decay_time <= timeAxis(end)
                decay_x(end+1) = decay_time;
                decay_y(end+1) = y_offset + events.decay_values(i);
            end
        end
        
        % Касательные линии роста
        if isfield(events, 'tangent_x1') && isfield(events, 'tangent_y1') && ...
           isfield(events, 'tangent_x2') && isfield(events, 'tangent_y2') && ...
           i <= length(events.tangent_x1) && i <= length(events.tangent_x2) && ...
           ~isnan(events.tangent_x1(i)) && ~isnan(events.tangent_y1(i)) && ...
           ~isnan(events.tangent_x2(i)) && ~isnan(events.tangent_y2(i))
            x1 = events.tangent_x1(i);
            x2 = events.tangent_x2(i);
            if x1 >= timeAxis(1) && x1 <= timeAxis(end) && x2 >= timeAxis(1) && x2 <= timeAxis(end)
                line_x(end+1, :) = [x1, x2];
                line_y(end+1, :) = [events.tangent_y1(i) + y_offset, events.tangent_y2(i) + y_offset];
            end
        end
        
        % Касательные линии спада
        if isfield(events, 'decay_tangent_x1') && isfield(events, 'decay_tangent_y1') && ...
           isfield(events, 'decay_tangent_x2') && isfield(events, 'decay_tangent_y2') && ...
           i <= length(events.decay_tangent_x1) && i <= length(events.decay_tangent_x2) && ...
           ~isnan(events.decay_tangent_x1(i)) && ~isnan(events.decay_tangent_y1(i)) && ...
           ~isnan(events.decay_tangent_x2(i)) && ~isnan(events.decay_tangent_y2(i))
            x1 = events.decay_tangent_x1(i);
            x2 = events.decay_tangent_x2(i);
            if x1 >= timeAxis(1) && x1 <= timeAxis(end) && x2 >= timeAxis(1) && x2 <= timeAxis(end)
                line_x(end+1, :) = [x1, x2];
                line_y(end+1, :) = [events.decay_tangent_y1(i) + y_offset, events.decay_tangent_y2(i) + y_offset];
            end
        end
    end
    
    % Отображаем точки пиков (серо-красные)
    if ~isempty(peak_x)
        scatter(peak_x, peak_y, 20, ...
            'MarkerFaceColor', [0.7 0.4 0.4], ...
            'MarkerEdgeColor', [0.7 0.4 0.4]);
    end
    
    % Отображаем точки онсетов (серо-желтые)
    if ~isempty(onset_x)
        scatter(onset_x, onset_y, 20, ...
            'MarkerFaceColor', [0.7 0.65 0.5], ...
            'MarkerEdgeColor', [0.7 0.65 0.5]);
    end
    
    % Отображаем точки спада (лазурно-серые)
    if ~isempty(decay_x)
        scatter(decay_x, decay_y, 20, ...
            'MarkerFaceColor', [0.5 0.7 0.8], ...
            'MarkerEdgeColor', [0.5 0.7 0.8]);
    end
    
    % Отображаем все линии одной командой
    if ~isempty(line_x)
        plot(line_x', line_y', ...
            'Color', [0.5 0.7 0.8], ...
            'LineWidth', 0.8, ...
            'LineStyle', '--');
    end
    
    hold off;
end

