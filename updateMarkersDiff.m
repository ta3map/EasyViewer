function updateMarkersDiff(ax, fig)
% Функция для обновления разницы времени между маркерами

    % Находим все маркеры в ax
    markers = findobj(ax, 'Tag', 'Draggable');
    
    % Получаем XData каждого маркера для сортировки
    xData = arrayfun(@(m) m.XData(1), markers);
    
    % Сортируем маркеры по XData
    [~, sortIndex] = sort(xData);
    markers = markers(sortIndex);

    % Находим и очищаем предыдущие тексты разницы времени
    delete(findobj(ax, 'Tag', 'DiffText'));

    % Вычисляем и отображаем разницу времени между маркерами
    for i = 2:length(markers)
        xPrev = markers(i-1).XData(1);
        xCurr = markers(i).XData(1);
        diffTime = abs(xCurr - xPrev);

        % Располагаем текст разницы времени между маркерами
        textMean = (xPrev + xCurr) / 2;
        text(ax, textMean, ax.YLim(2), sprintf('%.2f', diffTime), ...
        'VerticalAlignment', 'bottom', ...
        'HorizontalAlignment', 'center', ...
        'Tag', 'DiffText', ...
        'Color', 'blue', ...
        'BackgroundColor', 'yellow', ... % Задний фон текста
        'EdgeColor', 'red', ... % Цвет рамки
        'FontWeight', 'bold'); % Увеличиваем толщину шрифта для повышения видимости

    end
end
