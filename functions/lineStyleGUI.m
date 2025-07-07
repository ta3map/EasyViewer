function lineStyleGUI()
    
    global lines_and_styles SettingsFilepath
    
    % Идентификатор (tag) для GUI фигуры
    figTag = 'lineStyleGUI';
    if activateOrCreateFigure(figTag)
        return
    end
    
    % Create the figure
    fig = figure('Name', 'Line Style', 'Tag', figTag, ...
        'NumberTitle', 'off', ...
        'MenuBar', 'none', 'ToolBar', 'none',...
        'Position', [100, 100, 500, 430]);
    
    % Axes for displaying the line
    ax = axes('Parent', fig, 'Position', [0.3, 0.3, 0.65, 0.65]);
    hLine = line(ax, [0 1], [0.5 0.5], 'Color', 'b', 'LineWidth', 2, 'LineStyle', '-');
    hText = text(ax, 0.5, 0.6, 'Test Label', 'Color', 'k', 'FontSize', 12, ...
        'BackgroundColor', 'none', 'FontWeight', 'normal', 'HorizontalAlignment', 'center');
    axis off
    
    % The start of element position
    x_ground = 50;

    % Create UI controls for selecting line
    x_pos = x_ground + 350;
    uicontrol('Style', 'text', 'Position', [20, x_pos, 80, 20], 'String', 'Select Line');
    lineSelectList = uicontrol('Style', 'popupmenu', 'Position', [20, x_pos-20, 100, 20], ...
        'String', {'stimulus_lines', 'events_lines'}, 'Callback', @selectLine);
    
    % Create UI controls for line style
    x_pos = x_ground+300;
    uicontrol('Style', 'text', 'Position', [20, x_pos, 80, 20], 'String', 'Line Color');
    colorList = uicontrol('Style', 'popupmenu', 'Position', [20, x_pos-20, 100, 20], ...
        'String', {'Red', 'Green', 'Blue', 'Black', 'Yellow'}, 'Callback', @updateLine);
    
    x_pos = x_ground+250;
    uicontrol('Style', 'text', 'Position', [20, x_pos, 80, 20], 'String', 'Line Style');
    styleList = uicontrol('Style', 'popupmenu', 'Position', [20, x_pos-20, 100, 20], ...
        'String', {'-', '--', ':', '-.'}, 'Callback', @updateLine);
    
    x_pos = x_ground+200;
    uicontrol('Style', 'text', 'Position', [20, x_pos, 80, 20], 'String', 'Line Width');
    widthList = uicontrol('Style', 'popupmenu', 'Position', [20, x_pos-20, 100, 20], ...
        'String', {'1', '2', '3', '4', '5'}, 'Callback', @updateLine);
    
    % Create UI controls for text label style
    x_pos = x_ground+150;
    uicontrol('Style', 'text', 'Position', [20, x_pos, 80, 20], 'String', 'Text Color');
    textColorList = uicontrol('Style', 'popupmenu', 'Position', [20, x_pos-20, 100, 20], ...
        'String', {'Red', 'Green', 'Blue', 'Black', 'Yellow'}, 'Callback', @updateText);
    
    x_pos = x_ground+100;
    uicontrol('Style', 'text', 'Position', [20, x_pos, 80, 20], 'String', 'Font Size');
    fontSizeList = uicontrol('Style', 'popupmenu', 'Position', [20, x_pos-20, 100, 20], ...
        'String', {'8', '10', '12', '14', '16'}, 'Callback', @updateText);
    
    x_pos = x_ground+50;
    uicontrol('Style', 'text', 'Position', [20, x_pos, 100, 20], 'String', 'Background Color');
    bgColorList = uicontrol('Style', 'popupmenu', 'Position', [20, x_pos-20, 100, 20], ...
        'String', {'None', 'Red', 'Green', 'Blue', 'Yellow'}, 'Callback', @updateText);
    
    x_pos = x_ground;
    uicontrol('Style', 'text', 'Position', [20, x_pos, 80, 20], 'String', 'Font Weight');
    fontWeightList = uicontrol('Style', 'popupmenu', 'Position', [20, x_pos-20, 100, 20], ...
        'String', {'Normal', 'Bold'}, 'Callback', @updateText);
    
    % Button to save changes to the structure
    x_pos = x_ground;
    uicontrol('Style', 'pushbutton', 'Position', [380, x_pos-25, 100, 30], 'String', 'Apply', 'Callback', @applyChanges);
    
    % Variable to keep track of selected line
    selectedLine = 'stimulus_lines';
    
    % Callback functions to update line and text
    function selectLine(source, ~)
        options = get(source, 'String');
        selectedLine = options{get(source, 'Value')};
        
        % Update the GUI elements to match the selected line's current style
        lineStyle = lines_and_styles.(selectedLine);
        
        set(colorList, 'Value', find(strcmp({'r', 'g', 'b', 'k', 'y'}, lineStyle.LineColor)));
        set(styleList, 'Value', find(strcmp({'-', '--', ':', '-.'}, lineStyle.LineStyle)));
        set(widthList, 'Value', find([1, 2, 3, 4, 5] == lineStyle.LineWidth));
        
        set(textColorList, 'Value', find(strcmp({'r', 'g', 'b', 'k', 'y'}, lineStyle.LabelColor)));
        set(fontSizeList, 'Value', find([8, 10, 12, 14, 16] == lineStyle.LabelFontSize));
        set(bgColorList, 'Value', find(strcmp({'none', 'r', 'g', 'b', 'y'}, lineStyle.LabelBackgroundColor)));
        set(fontWeightList, 'Value', find(strcmp({'normal', 'bold'}, lineStyle.LabelFontWeight)));
        
        % Apply these styles to the line and text on the plot
        updateLine();
        updateText();
    end
    
    function updateLine(~, ~)
        colors = {'r', 'g', 'b', 'k', 'y'};
        lineStyles = {'-', '--', ':', '-.'};
        lineWidths = [1, 2, 3, 4, 5];
        
        color = colors{get(colorList, 'Value')};
        style = lineStyles{get(styleList, 'Value')};
        width = lineWidths(get(widthList, 'Value'));
        
        set(hLine, 'Color', color, 'LineStyle', style, 'LineWidth', width);
    end

    function updateText(~, ~)
        colors = {'r', 'g', 'b', 'k', 'y'};
        fontSizes = [8, 10, 12, 14, 16];
        bgColors = {'none', 'r', 'g', 'b', 'y'};
        fontWeights = {'normal', 'bold'};
        
        color = colors{get(textColorList, 'Value')};
        size = fontSizes(get(fontSizeList, 'Value'));
        bgColor = bgColors{get(bgColorList, 'Value')};
        weight = fontWeights{get(fontWeightList, 'Value')};
        
        set(hText, 'Color', color, 'FontSize', size, 'BackgroundColor', bgColor, 'FontWeight', weight);
    end
    
    function applyChanges(~, ~)
        colors = {'r', 'g', 'b', 'k', 'y'};
        lineStyles = {'-', '--', ':', '-.'};
        lineWidths = [1, 2, 3, 4, 5];
        fontSizes = [8, 10, 12, 14, 16];
        bgColors = {'none', 'r', 'g', 'b', 'y'};
        fontWeights = {'normal', 'bold'};
        
        lines_and_styles.(selectedLine).LineColor = colors{get(colorList, 'Value')};
        lines_and_styles.(selectedLine).LineStyle = lineStyles{get(styleList, 'Value')};
        lines_and_styles.(selectedLine).LineWidth = lineWidths(get(widthList, 'Value'));
        
        lines_and_styles.(selectedLine).LabelColor = colors{get(textColorList, 'Value')};
        lines_and_styles.(selectedLine).LabelFontSize = fontSizes(get(fontSizeList, 'Value'));
        lines_and_styles.(selectedLine).LabelBackgroundColor = bgColors{get(bgColorList, 'Value')};
        lines_and_styles.(selectedLine).LabelFontWeight = fontWeights{get(fontWeightList, 'Value')};
        
        save(SettingsFilepath, 'lines_and_styles', '-append')
        updatePlot()
        close(fig)
    end
    
    selectLine(lineSelectList); % Initialize the GUI with the first line's settings
    
end