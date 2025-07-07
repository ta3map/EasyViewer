function xlineMod(x, lines_and_styles, line_name)
    if ~isempty(x)
        lineStyle = lines_and_styles.(line_name);
        xline(x, 'Color', lineStyle.LineColor, 'LineStyle', lineStyle.LineStyle, 'LineWidth', lineStyle.LineWidth);
    end
end