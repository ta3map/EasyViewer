function h = drawLabelWithBg(ax, x, y, textValue, lineStyle, clickCallback, horizontalAlignment)
    if nargin < 6
        clickCallback = [];
    end
    if nargin < 7 || isempty(horizontalAlignment)
        horizontalAlignment = 'left';
    end

    h = struct('rect', [], 'text', []);
    listeners = [];

    h.text = text(ax, x, y, textValue, ...
        'Color', lineStyle.LabelColor, ...
        'FontSize', lineStyle.LabelFontSize, ...
        'FontWeight', lineStyle.LabelFontWeight, ...
        'BackgroundColor', 'none', ...
        'Units', 'data', ...
        'HorizontalAlignment', horizontalAlignment, ...
        'VerticalAlignment', 'middle', ...
        'Visible', 'off');

    if ~strcmp(lineStyle.LabelBackgroundColor, 'none')
        h.rect = patch(ax, [0 0 0 0], [0 0 0 0], lineStyle.LabelBackgroundColor, ...
            'FaceAlpha', 0.28, 'EdgeColor', 'none');
        updateBgRect();
        listeners = [ ...
            addlistener(ax, 'XLim', 'PostSet', @(~,~) updateBgRect()), ...
            addlistener(ax, 'YLim', 'PostSet', @(~,~) updateBgRect()) ...
        ];
        setappdata(h.text, 'drawLabelWithBgListeners', listeners);
    end

    set(h.text, 'Visible', 'on');
    if ~isempty(clickCallback)
        set(h.text, 'HitTest', 'on', 'ButtonDownFcn', clickCallback);
        if ~isempty(h.rect) && isgraphics(h.rect)
            set(h.rect, 'HitTest', 'on', 'ButtonDownFcn', clickCallback);
        end
    end

    function updateBgRect()
        if isempty(h.rect) || ~isgraphics(h.rect) || isempty(h.text) || ~isgraphics(h.text)
            return;
        end
        ext = get(h.text, 'Extent');
        padX = ext(3) * 0.06;
        padY = ext(4) * 0.15;
        x1 = ext(1) - padX;
        y1 = ext(2) - padY;
        x2 = ext(1) + ext(3) + padX;
        y2 = ext(2) + ext(4) + padY;
        set(h.rect, 'XData', [x1 x2 x2 x1], 'YData', [y1 y1 y2 y2]);
    end
end
