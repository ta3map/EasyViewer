function handles = updateXMarkersPool(ax, handles, xVals, Ylims, lines_and_styles, lineName)
%UPDATEXMARKERSPOOL Grow/hide pool of vertical event/stim markers.

lineStyle = lines_and_styles.(lineName);
lineAlpha = 1;
if isfield(lineStyle, 'LineAlpha')
    lineAlpha = lineStyle.LineAlpha;
end
lineColor = toRgbColorPool(lineStyle.LineColor);
nNeed = numel(xVals);
nHave = numel(handles);

for i = (nNeed + 1):nHave
    if isgraphics(handles(i))
        set(handles(i), 'Visible', 'off');
    end
end

if nNeed == 0
    return;
end

axXlim = get(ax, 'XLim');
xSpanAx = max(eps, axXlim(2) - axXlim(1));
stripeWidth = max(eps, xSpanAx * 0.0008 * lineStyle.LineWidth);

for i = 1:nNeed
    if i > nHave || ~isgraphics(handles(i))
        if lineAlpha >= 1
            h = plot(ax, [xVals(i) xVals(i)], Ylims, ...
                'Color', lineColor, ...
                'LineStyle', lineStyle.LineStyle, ...
                'LineWidth', lineStyle.LineWidth, ...
                'HitTest', 'off', ...
                'Tag', ['overlay_' lineName]);
        else
            x1 = xVals(i) - stripeWidth / 2;
            x2 = xVals(i) + stripeWidth / 2;
            h = patch(ax, [x1 x2 x2 x1], [Ylims(1) Ylims(1) Ylims(2) Ylims(2)], lineColor, ...
                'FaceAlpha', lineAlpha, 'EdgeColor', 'none', 'HitTest', 'off', ...
                'Tag', ['overlay_' lineName]);
        end
        if i > nHave
            handles(end + 1) = h; %#ok<AGROW>
        else
            handles(i) = h;
        end
        continue;
    end
    h = handles(i);
    isPatch = strcmp(get(h, 'Type'), 'patch');
    wantPatch = lineAlpha < 1;
    if isPatch ~= wantPatch
        delete(h);
        if wantPatch
            x1 = xVals(i) - stripeWidth / 2;
            x2 = xVals(i) + stripeWidth / 2;
            handles(i) = patch(ax, [x1 x2 x2 x1], [Ylims(1) Ylims(1) Ylims(2) Ylims(2)], lineColor, ...
                'FaceAlpha', lineAlpha, 'EdgeColor', 'none', 'HitTest', 'off', ...
                'Tag', ['overlay_' lineName]);
        else
            handles(i) = plot(ax, [xVals(i) xVals(i)], Ylims, ...
                'Color', lineColor, ...
                'LineStyle', lineStyle.LineStyle, ...
                'LineWidth', lineStyle.LineWidth, ...
                'HitTest', 'off', ...
                'Tag', ['overlay_' lineName]);
        end
        continue;
    end
    if wantPatch
        x1 = xVals(i) - stripeWidth / 2;
        x2 = xVals(i) + stripeWidth / 2;
        set(h, 'XData', [x1 x2 x2 x1], 'YData', [Ylims(1) Ylims(1) Ylims(2) Ylims(2)], ...
            'FaceColor', lineColor, 'FaceAlpha', lineAlpha, 'Visible', 'on');
    else
        set(h, 'XData', [xVals(i) xVals(i)], 'YData', Ylims, ...
            'Color', lineColor, 'LineStyle', lineStyle.LineStyle, ...
            'LineWidth', lineStyle.LineWidth, 'Visible', 'on');
    end
end
end

function rgb = toRgbColorPool(colorValue)
if isnumeric(colorValue) && numel(colorValue) == 3
    rgb = colorValue(:)';
    return;
end
switch colorValue
    case 'r', rgb = [1 0 0];
    case 'g', rgb = [0 1 0];
    case 'b', rgb = [0 0 1];
    case 'k', rgb = [0 0 0];
    case 'y', rgb = [1 1 0];
    case 'm', rgb = [1 0 1];
    case 'c', rgb = [0 1 1];
    case 'w', rgb = [1 1 1];
    otherwise, rgb = [0 0 0];
end
end
