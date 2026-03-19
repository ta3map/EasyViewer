function textMod(x, y, text_in, lines_and_styles, line_name)
    lineStyle = lines_and_styles.(line_name);

    if ischar(text_in)
        textCells = cellstr(text_in);
    elseif isstring(text_in)
        textCells = cellstr(text_in);
    elseif isnumeric(text_in)
        textCells = cellstr(num2str(text_in));
    else
        textCells = text_in;
    end

    maxLen = min([numel(x), numel(y), numel(textCells)]);
    ax = gca;

    for i = 1:maxLen
        drawLabelWithBg(ax, x(i), y(i), textCells{i}, lineStyle, []);
    end
end