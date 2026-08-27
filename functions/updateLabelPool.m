function [texts, rects] = updateLabelPool(ax, texts, rects, xs, ys, strings, lineStyle, callbacks)
%UPDATELABELPOOL Grow/hide pool of drawLabelWithBg-like text+rect labels.

nNeed = numel(xs);
nHave = numel(texts);

for i = (nNeed + 1):nHave
    if i <= numel(texts) && isgraphics(texts(i))
        set(texts(i), 'Visible', 'off');
    end
    if i <= numel(rects) && isgraphics(rects(i))
        set(rects(i), 'Visible', 'off');
    end
end

if nNeed == 0
    return;
end

if numel(rects) < nHave
    rects(nHave) = gobjects(1);
end

for i = 1:nNeed
    cb = [];
    if nargin >= 8 && ~isempty(callbacks) && numel(callbacks) >= i
        cb = callbacks{i};
    end
    needNew = i > nHave || ~isgraphics(texts(i));
    if needNew
        h = drawLabelWithBg(ax, xs(i), ys(i), strings{i}, lineStyle, cb);
        if i > numel(texts)
            texts(end + 1) = h.text; %#ok<AGROW>
            rects(end + 1) = gobjects(1); %#ok<AGROW>
            if ~isempty(h.rect) && isgraphics(h.rect)
                rects(end) = h.rect;
            end
        else
            texts(i) = h.text;
            rects(i) = gobjects(1);
            if ~isempty(h.rect) && isgraphics(h.rect)
                rects(i) = h.rect;
            end
        end
        continue;
    end
    set(texts(i), 'Position', [xs(i), ys(i), 0], 'String', strings{i}, ...
        'Color', lineStyle.LabelColor, 'FontSize', lineStyle.LabelFontSize, ...
        'FontWeight', lineStyle.LabelFontWeight, 'Visible', 'on');
    if ~isempty(cb)
        set(texts(i), 'HitTest', 'on', 'ButtonDownFcn', cb);
    else
        set(texts(i), 'HitTest', 'off', 'ButtonDownFcn', '');
    end
    if i <= numel(rects) && isgraphics(rects(i))
        if ischar(lineStyle.LabelBackgroundColor) && strcmp(lineStyle.LabelBackgroundColor, 'none')
            set(rects(i), 'Visible', 'off');
        else
            ext = get(texts(i), 'Extent');
            padX = ext(3) * 0.06;
            padY = ext(4) * 0.15;
            x1 = ext(1) - padX;
            y1 = ext(2) - padY;
            x2 = ext(1) + ext(3) + padX;
            y2 = ext(2) + ext(4) + padY;
            set(rects(i), 'XData', [x1 x2 x2 x1], 'YData', [y1 y1 y2 y2], ...
                'FaceColor', lineStyle.LabelBackgroundColor, 'Visible', 'on');
            if ~isempty(cb)
                set(rects(i), 'HitTest', 'on', 'ButtonDownFcn', cb);
            end
        end
    end
end
end
