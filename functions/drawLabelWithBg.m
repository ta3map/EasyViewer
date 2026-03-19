function h = drawLabelWithBg(ax, x, y, textValue, lineStyle, clickCallback)
    if nargin < 6
        clickCallback = [];
    end

    h = struct('rect', [], 'text', []);

    h.text = text(ax, x, y, textValue, ...
        'Color', lineStyle.LabelColor, ...
        'FontSize', lineStyle.LabelFontSize, ...
        'FontWeight', lineStyle.LabelFontWeight, ...
        'BackgroundColor', 'none', ...
        'Units', 'data', ...
        'HorizontalAlignment', 'left', ...
        'VerticalAlignment', 'middle', ...
        'Visible', 'off');

    if ~strcmp(lineStyle.LabelBackgroundColor, 'none')
        ext = get(h.text, 'Extent');
        padX = ext(3) * 0.06;
        padY = ext(4) * 0.15;

        x1 = ext(1) - padX;
        y1 = ext(2) - padY;
        x2 = ext(1) + ext(3) + padX;
        y2 = ext(2) + ext(4) + padY;
        h.rect = patch(ax, [x1 x2 x2 x1], [y1 y1 y2 y2], lineStyle.LabelBackgroundColor, ...
            'FaceAlpha', 0.28, 'EdgeColor', 'none', 'HitTest', 'off');
    end

    set(h.text, 'Visible', 'on');
    if ~isempty(clickCallback)
        set(h.text, 'HitTest', 'on', 'ButtonDownFcn', clickCallback);
    end
end
