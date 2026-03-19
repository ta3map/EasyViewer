function xlineMod(x, lines_and_styles, line_name)
    if ~isempty(x)
        lineStyle = lines_and_styles.(line_name);
        lineAlpha = 1;
        if isfield(lineStyle, 'LineAlpha')
            lineAlpha = lineStyle.LineAlpha;
        end

        if lineAlpha >= 1
            xline(x, 'Color', lineStyle.LineColor, 'LineStyle', lineStyle.LineStyle, 'LineWidth', lineStyle.LineWidth);
            return;
        end

        ax = gca;
        yLimits = ylim(ax);
        xLimits = xlim(ax);
        xSpan = max(eps, xLimits(2) - xLimits(1));
        stripeWidth = xSpan * 0.0008 * lineStyle.LineWidth;
        lineColor = toRgbColor(lineStyle.LineColor);

        for i = 1:numel(x)
            x1 = x(i) - stripeWidth / 2;
            x2 = x(i) + stripeWidth / 2;
            patch(ax, [x1 x2 x2 x1], [yLimits(1) yLimits(1) yLimits(2) yLimits(2)], lineColor, ...
                'FaceAlpha', lineAlpha, 'EdgeColor', 'none', 'HitTest', 'off');
        end
    end
end

function rgb = toRgbColor(colorValue)
    if isnumeric(colorValue) && numel(colorValue) == 3
        rgb = colorValue;
        return;
    end

    switch colorValue
        case 'r'
            rgb = [1 0 0];
        case 'g'
            rgb = [0 1 0];
        case 'b'
            rgb = [0 0 1];
        case 'k'
            rgb = [0 0 0];
        case 'y'
            rgb = [1 1 0];
        case 'm'
            rgb = [1 0 1];
        case 'c'
            rgb = [0 1 1];
        case 'w'
            rgb = [1 1 1];
        otherwise
            rgb = [0 0 0];
    end
end