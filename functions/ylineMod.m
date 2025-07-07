function ylineMod(y, lines_and_styles, line_name)
    lineStyle = lines_and_styles.(line_name);
    yline(y, 'Color', lineStyle.LineColor, 'LineStyle', lineStyle.LineStyle, 'LineWidth', lineStyle.LineWidth);
end