function draggable(ax, h, hT, direction)

    % Инициализация начальных координат
    set(h, 'ButtonDownFcn', @startDragFcn)
    fig = h.Parent.Parent;
    
    % Начало перетаскивания
    function startDragFcn(~,~)
        set(fig, 'WindowButtonMotionFcn', @draggingFcn)
        set(fig, 'WindowButtonUpFcn', @stopDragFcn)
    end

    % Процесс перетаскивания
    function draggingFcn(~,~)
%         global hT
        pt = h.Parent.CurrentPoint;
        switch direction
            case 'h' % Горизонтальное перетаскивание
                set(h, 'XData', [pt(1,1), pt(1,1)]);
                % Обновление текста маркера
                set(hT, 'Position', [pt(1,1), h.Parent.YLim(2), 0], 'String', sprintf('%.2f', pt(1,1)));
        end
    end

    % Остановка перетаскивания
    function stopDragFcn(~,~)
        set(fig, 'WindowButtonMotionFcn', '')
        set(fig, 'WindowButtonUpFcn', '')
        updateMarkersDiff(ax);
    end    
end