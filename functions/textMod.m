function textMod(x, y, text_in, lines_and_styles, line_name)
    lineStyle = lines_and_styles.(line_name);
    text(x, y, text_in, 'Color', lineStyle.LabelColor, 'FontSize', lineStyle.LabelFontSize, ...
        'BackgroundColor', lineStyle.LabelBackgroundColor, 'FontWeight', lineStyle.LabelFontWeight);
end