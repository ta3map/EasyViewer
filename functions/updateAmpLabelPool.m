function [texts, scatters] = updateAmpLabelPool(ax, texts, scatters, tickX, tickY, markX, markY, strings, colors)
%UPDATEAMPLABELPOOL Grow/hide pool of amplitude tick text + underscore markers.

nNeed = numel(tickX);
nHave = numel(texts);

for i = (nNeed + 1):nHave
    if i <= numel(texts) && isgraphics(texts(i))
        set(texts(i), 'Visible', 'off');
    end
    if i <= numel(scatters) && isgraphics(scatters(i))
        set(scatters(i), 'Visible', 'off');
    end
end

if nNeed == 0
    return;
end

for i = 1:nNeed
    color = colors{i};
    if i > numel(texts) || ~isgraphics(texts(i))
        hT = text(ax, tickX(i), tickY(i), strings{i}, ...
            'Color', color, 'BackgroundColor', 'w', 'Visible', 'on');
        if i > numel(texts)
            texts(end + 1) = hT; %#ok<AGROW>
        else
            texts(i) = hT;
        end
    else
        set(texts(i), 'Position', [tickX(i), tickY(i), 0], 'String', strings{i}, ...
            'Color', color, 'BackgroundColor', 'w', 'Visible', 'on');
    end

    if i > numel(scatters) || ~isgraphics(scatters(i))
        hS = scatter(ax, markX(i), markY(i), [], 'Marker', '_', ...
            'MarkerEdgeColor', color, 'Visible', 'on');
        if i > numel(scatters)
            scatters(end + 1) = hS; %#ok<AGROW>
        else
            scatters(i) = hS;
        end
    else
        set(scatters(i), 'XData', markX(i), 'YData', markY(i), ...
            'MarkerEdgeColor', color, 'Visible', 'on');
    end
end

end
