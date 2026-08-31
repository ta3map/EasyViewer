function lineStyleGUI(selectedLineArg)
    
    global lines_and_styles SettingsFilepath
    if nargin < 1
        selectedLineArg = '';
    end
    isFixedSelectedLine = ismember(selectedLineArg, {'stimulus_lines', 'events_lines'});
    
    % Идентификатор (tag) для GUI фигуры
    figTag = 'lineStyleGUI';
    figTitle = 'Line Style';
    if isFixedSelectedLine
        figTag = ['lineStyleGUI_' selectedLineArg];
        if strcmp(selectedLineArg, 'stimulus_lines')
            figTitle = 'Stimulus Style Settings';
        else
            figTitle = 'Event Style Settings';
        end
    end
    if activateOrCreateFigure(figTag)
        return
    end
    
    % Create the figure
    fig = figure('Name', figTitle, 'Tag', figTag, ...
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
    x_ground = 30;

    % Create UI controls for selecting line
    x_pos = x_ground + 350;
    lineSelectLabel = uicontrol('Style', 'text', 'Position', [20, x_pos, 80, 20], 'String', 'Select Line');
    lineSelectList = uicontrol('Style', 'popupmenu', 'Position', [20, x_pos-20, 100, 20], ...
        'String', {'stimulus_lines', 'events_lines'}, 'Callback', @selectLine);
    if isFixedSelectedLine
        set(lineSelectLabel, 'Visible', 'off');
        set(lineSelectList, 'Visible', 'off');
    end
    
    % Create UI controls for line style
    x_pos = x_ground+375;
    uicontrol('Style', 'text', 'Position', [20, x_pos, 80, 20], 'String', 'Line Color');
    colorList = uicontrol('Style', 'popupmenu', 'Position', [20, x_pos-20, 100, 20], ...
        'String', {'Red', 'Green', 'Blue', 'Black', 'Yellow'}, 'Callback', @onLineColorListChanged);
    lineColorPreview = uicontrol('Style', 'text', 'Position', [125, x_pos-20, 20, 20], 'String', '', 'BackgroundColor', [1 0 0]);
    uicontrol('Style', 'pushbutton', 'Position', [150, x_pos-20, 70, 20], 'String', 'Palette...', 'Callback', @chooseLineColorFromPalette);
    
    x_pos = x_ground+325;
    uicontrol('Style', 'text', 'Position', [20, x_pos, 80, 20], 'String', 'Line Style');
    styleList = uicontrol('Style', 'popupmenu', 'Position', [20, x_pos-20, 100, 20], ...
        'String', {'-', '--', ':', '-.'}, 'Callback', @updateLine);
    
    x_pos = x_ground+275;
    uicontrol('Style', 'text', 'Position', [20, x_pos, 80, 20], 'String', 'Line Width');
    widthList = uicontrol('Style', 'popupmenu', 'Position', [20, x_pos-20, 100, 20], ...
        'String', {'1', '2', '3', '4', '5'}, 'Callback', @updateLine);
    
    % Create UI controls for text label style
    x_pos = x_ground+225;
    uicontrol('Style', 'text', 'Position', [20, x_pos, 80, 20], 'String', 'Text Color');
    textColorList = uicontrol('Style', 'popupmenu', 'Position', [20, x_pos-20, 100, 20], ...
        'String', {'Red', 'Green', 'Blue', 'Black', 'Yellow'}, 'Callback', @onTextColorListChanged);
    textColorPreview = uicontrol('Style', 'text', 'Position', [125, x_pos-20, 20, 20], 'String', '', 'BackgroundColor', [0 0 0]);
    uicontrol('Style', 'pushbutton', 'Position', [150, x_pos-20, 70, 20], 'String', 'Palette...', 'Callback', @chooseTextColorFromPalette);
    
    x_pos = x_ground+175;
    uicontrol('Style', 'text', 'Position', [20, x_pos, 80, 20], 'String', 'Font Size');
    fontSizeList = uicontrol('Style', 'popupmenu', 'Position', [20, x_pos-20, 100, 20], ...
        'String', {'8', '10', '12', '14', '16'}, 'Callback', @updateText);

    x_pos = x_ground+125;
    labelVisibleCheckbox = uicontrol('Style', 'checkbox', ...
        'Position', [20, x_pos, 200, 20], ...
        'String', 'Logo', ...
        'Value', 1, ...
        'Callback', @updateText);
    
    x_pos = x_ground+100;
    uicontrol('Style', 'text', 'Position', [20, x_pos, 100, 20], 'String', 'Background Color');
    bgColorList = uicontrol('Style', 'popupmenu', 'Position', [20, x_pos-20, 100, 20], ...
        'String', {'None', 'Red', 'Green', 'Blue', 'Yellow'}, 'Callback', @onBgColorListChanged);
    bgColorPreview = uicontrol('Style', 'text', 'Position', [125, x_pos-20, 20, 20], 'String', '', 'BackgroundColor', [1 1 1]);
    uicontrol('Style', 'pushbutton', 'Position', [150, x_pos-20, 70, 20], 'String', 'Palette...', 'Callback', @chooseBgColorFromPalette);
    
    x_pos = x_ground+50;
    uicontrol('Style', 'text', 'Position', [20, x_pos, 80, 20], 'String', 'Font Weight');
    fontWeightList = uicontrol('Style', 'popupmenu', 'Position', [20, x_pos-20, 100, 20], ...
        'String', {'Normal', 'Bold'}, 'Callback', @updateText);
    
    % Button to save changes to the structure
    x_pos = x_ground+25;
    uicontrol('Style', 'pushbutton', 'Position', [270, x_pos-25, 100, 30], 'String', 'Reset', 'Callback', @resetSelectedLineDefaults);
    uicontrol('Style', 'pushbutton', 'Position', [380, x_pos-25, 100, 30], 'String', 'Apply', 'Callback', @applyChanges);
    
    % Variable to keep track of selected line
    if isFixedSelectedLine
        selectedLine = selectedLineArg;
    else
        selectedLine = 'stimulus_lines';
    end
    currentLineColor = 'r';
    currentTextColor = 'k';
    currentBgColor = 'none';
    
    % Callback functions to update line and text
    function selectLine(source, ~)
        if isFixedSelectedLine
            selectedLine = selectedLineArg;
        else
            options = get(source, 'String');
            selectedLine = options{get(source, 'Value')};
        end
        
        % Update the GUI elements to match the selected line's current style
        lineStyle = lines_and_styles.(selectedLine);
        
        setPopupByColor(colorList, {'r', 'g', 'b', 'k', 'y'}, lineStyle.LineColor);
        set(styleList, 'Value', find(strcmp({'-', '--', ':', '-.'}, lineStyle.LineStyle)));
        set(widthList, 'Value', find([1, 2, 3, 4, 5] == lineStyle.LineWidth));
        
        setPopupByColor(textColorList, {'r', 'g', 'b', 'k', 'y'}, lineStyle.LabelColor);
        set(fontSizeList, 'Value', find([8, 10, 12, 14, 16] == lineStyle.LabelFontSize));
        setPopupByColor(bgColorList, {'none', 'r', 'g', 'b', 'y'}, lineStyle.LabelBackgroundColor);
        set(fontWeightList, 'Value', find(strcmp({'normal', 'bold'}, lineStyle.LabelFontWeight)));
        if isfield(lineStyle, 'LabelVisible')
            set(labelVisibleCheckbox, 'Value', logical(lineStyle.LabelVisible));
        else
            set(labelVisibleCheckbox, 'Value', 1);
        end
        currentLineColor = lineStyle.LineColor;
        currentTextColor = lineStyle.LabelColor;
        currentBgColor = lineStyle.LabelBackgroundColor;
        set(lineColorPreview, 'BackgroundColor', colorSpecToRgb(currentLineColor, [1 0 0]));
        set(textColorPreview, 'BackgroundColor', colorSpecToRgb(currentTextColor, [0 0 0]));
        set(bgColorPreview, 'BackgroundColor', colorSpecToRgb(currentBgColor, [1 1 1]));
        
        % Apply these styles to the line and text on the plot
        updateLine();
        updateText();
    end
    
    function updateLine(~, ~)
        lineStyles = {'-', '--', ':', '-.'};
        lineWidths = [1, 2, 3, 4, 5];
        
        style = lineStyles{get(styleList, 'Value')};
        width = lineWidths(get(widthList, 'Value'));
        
        set(hLine, 'Color', currentLineColor, 'LineStyle', style, 'LineWidth', width);
    end

    function updateText(~, ~)
        fontSizes = [8, 10, 12, 14, 16];
        fontWeights = {'normal', 'bold'};
        
        size = fontSizes(get(fontSizeList, 'Value'));
        weight = fontWeights{get(fontWeightList, 'Value')};
        
        if logical(get(labelVisibleCheckbox, 'Value'))
            textVisible = 'on';
        else
            textVisible = 'off';
        end
        set(hText, 'Color', currentTextColor, 'FontSize', size, 'BackgroundColor', currentBgColor, 'FontWeight', weight, 'Visible', textVisible);
    end

    function onLineColorListChanged(~, ~)
        colors = {'r', 'g', 'b', 'k', 'y'};
        currentLineColor = colors{get(colorList, 'Value')};
        set(lineColorPreview, 'BackgroundColor', colorSpecToRgb(currentLineColor, [1 0 0]));
        updateLine();
    end

    function onTextColorListChanged(~, ~)
        colors = {'r', 'g', 'b', 'k', 'y'};
        currentTextColor = colors{get(textColorList, 'Value')};
        set(textColorPreview, 'BackgroundColor', colorSpecToRgb(currentTextColor, [0 0 0]));
        updateText();
    end

    function onBgColorListChanged(~, ~)
        bgColors = {'none', 'r', 'g', 'b', 'y'};
        currentBgColor = bgColors{get(bgColorList, 'Value')};
        set(bgColorPreview, 'BackgroundColor', colorSpecToRgb(currentBgColor, [1 1 1]));
        updateText();
    end

    function chooseLineColorFromPalette(~, ~)
        selectedHex = chooseColorFromPalette(currentLineColor);
        if isempty(selectedHex)
            return;
        end
        currentLineColor = selectedHex;
        set(lineColorPreview, 'BackgroundColor', colorSpecToRgb(currentLineColor, [1 0 0]));
        updateLine();
    end

    function chooseTextColorFromPalette(~, ~)
        selectedHex = chooseColorFromPalette(currentTextColor);
        if isempty(selectedHex)
            return;
        end
        currentTextColor = selectedHex;
        set(textColorPreview, 'BackgroundColor', colorSpecToRgb(currentTextColor, [0 0 0]));
        updateText();
    end

    function chooseBgColorFromPalette(~, ~)
        selectedHex = chooseColorFromPalette(currentBgColor);
        if isempty(selectedHex)
            return;
        end
        currentBgColor = selectedHex;
        set(bgColorPreview, 'BackgroundColor', colorSpecToRgb(currentBgColor, [1 1 1]));
        updateText();
    end

    function setPopupByColor(hPopup, standardColors, colorValue)
        colorValue = char(string(colorValue));
        idx = find(strcmp(standardColors, colorValue), 1, 'first');
        if isempty(idx)
            idx = 1;
        end
        set(hPopup, 'Value', idx);
    end

    function selectedHex = chooseColorFromPalette(currentColor)
        colors = getColors(30);
        grayColors = {'#000000', '#404040', '#808080', '#BFBFBF', '#FFFFFF'};
        palette = [colors(:); grayColors(:)];

        figW = 330;
        figH = 280;
        btnW = 35;
        btnH = 35;
        cols = 7;
        gap = 6;
        margin = 10;
        top = 40;

        paletteFig = figure('Position', [430, 220, figW, figH], ...
            'Name', 'Color Palette', ...
            'NumberTitle', 'off', ...
            'MenuBar', 'none', ...
            'ToolBar', 'none', ...
            'Resize', 'off', ...
            'WindowStyle', 'modal');

        selectedHex = '';
        if ~(strcmpi(currentColor, 'none'))
            selectedHex = char(string(currentColor));
        end

        uicontrol('Parent', paletteFig, 'Style', 'text', ...
            'String', 'Select color', ...
            'Position', [10 figH-30 140 20], ...
            'HorizontalAlignment', 'left');

        for iColor = 1:numel(palette)
            row = floor((iColor - 1) / cols);
            col = mod(iColor - 1, cols);
            x = margin + col * (btnW + gap);
            y = figH - top - row * (btnH + gap);
            oneHex = palette{iColor};
            uicontrol('Parent', paletteFig, 'Style', 'pushbutton', ...
                'Position', [x y btnW btnH], ...
                'BackgroundColor', colorSpecToRgb(oneHex, [1 0 0]), ...
                'Callback', @(~,~) selectAndClose(oneHex));
        end

        uicontrol('Parent', paletteFig, 'Style', 'pushbutton', ...
            'String', 'Cancel', ...
            'Position', [figW-90 10 80 25], ...
            'Callback', @(~,~) close(paletteFig));

        uiwait(paletteFig);

        function selectAndClose(hex)
            selectedHex = hex;
            if isvalid(paletteFig)
                uiresume(paletteFig);
                close(paletteFig);
            end
        end
    end

    function rgb = colorSpecToRgb(colorSpec, defaultRgb)
        if nargin < 2
            defaultRgb = [1 0 0];
        end
        rgb = defaultRgb;
        if isempty(colorSpec)
            return;
        end
        colorSpec = char(string(colorSpec));
        if strcmpi(colorSpec, 'none')
            rgb = [1 1 1];
            return;
        end
        switch lower(colorSpec)
            case 'r'
                rgb = [1 0 0];
                return;
            case 'g'
                rgb = [0 1 0];
                return;
            case 'b'
                rgb = [0 0 1];
                return;
            case 'k'
                rgb = [0 0 0];
                return;
            case 'y'
                rgb = [1 1 0];
                return;
            case 'c'
                rgb = [0 1 1];
                return;
            case 'm'
                rgb = [1 0 1];
                return;
            case 'w'
                rgb = [1 1 1];
                return;
        end
        if startsWith(colorSpec, '#') && numel(colorSpec) == 7
            rgb = [hex2dec(colorSpec(2:3)), hex2dec(colorSpec(4:5)), hex2dec(colorSpec(6:7))] / 255;
        end
    end
    
    function applyChanges(~, ~)
        lineStyles = {'-', '--', ':', '-.'};
        lineWidths = [1, 2, 3, 4, 5];
        fontSizes = [8, 10, 12, 14, 16];
        fontWeights = {'normal', 'bold'};
        
        lines_and_styles.(selectedLine).LineColor = currentLineColor;
        lines_and_styles.(selectedLine).LineStyle = lineStyles{get(styleList, 'Value')};
        lines_and_styles.(selectedLine).LineWidth = lineWidths(get(widthList, 'Value'));
        
        lines_and_styles.(selectedLine).LabelColor = currentTextColor;
        lines_and_styles.(selectedLine).LabelFontSize = fontSizes(get(fontSizeList, 'Value'));
        lines_and_styles.(selectedLine).LabelBackgroundColor = currentBgColor;
        lines_and_styles.(selectedLine).LabelFontWeight = fontWeights{get(fontWeightList, 'Value')};
        lines_and_styles.(selectedLine).LabelVisible = logical(get(labelVisibleCheckbox, 'Value'));
        
        save(SettingsFilepath, 'lines_and_styles', '-append')
        updatePlot()
        syncSignalViewerLogoCheckboxes()
        close(fig)
    end

    function resetSelectedLineDefaults(~, ~)
        defaultStyle = getDefaultStyleForLine(selectedLine);

        currentLineColor = defaultStyle.LineColor;
        currentTextColor = defaultStyle.LabelColor;
        currentBgColor = defaultStyle.LabelBackgroundColor;

        setPopupByColor(colorList, {'r', 'g', 'b', 'k', 'y'}, defaultStyle.LineColor);
        set(styleList, 'Value', find(strcmp({'-', '--', ':', '-.'}, defaultStyle.LineStyle), 1, 'first'));
        set(widthList, 'Value', find([1, 2, 3, 4, 5] == defaultStyle.LineWidth, 1, 'first'));

        setPopupByColor(textColorList, {'r', 'g', 'b', 'k', 'y'}, defaultStyle.LabelColor);
        set(fontSizeList, 'Value', find([8, 10, 12, 14, 16] == defaultStyle.LabelFontSize, 1, 'first'));
        setPopupByColor(bgColorList, {'none', 'r', 'g', 'b', 'y'}, defaultStyle.LabelBackgroundColor);
        set(fontWeightList, 'Value', find(strcmp({'normal', 'bold'}, defaultStyle.LabelFontWeight), 1, 'first'));
        set(labelVisibleCheckbox, 'Value', logical(defaultStyle.LabelVisible));

        set(lineColorPreview, 'BackgroundColor', colorSpecToRgb(currentLineColor, [1 0 0]));
        set(textColorPreview, 'BackgroundColor', colorSpecToRgb(currentTextColor, [0 0 0]));
        set(bgColorPreview, 'BackgroundColor', colorSpecToRgb(currentBgColor, [1 1 1]));

        updateLine();
        updateText();
    end

    function style = getDefaultStyleForLine(lineName)
        switch lineName
            case 'events_lines'
                style = struct( ...
                    'LineColor', 'r', ...
                    'LineStyle', '--', ...
                    'LineWidth', 2, ...
                    'LabelColor', 'r', ...
                    'LabelFontSize', 10, ...
                    'LabelBackgroundColor', 'y', ...
                    'LabelFontWeight', 'bold', ...
                    'LabelVisible', true);
            otherwise
                style = struct( ...
                    'LineColor', 'b', ...
                    'LineStyle', '--', ...
                    'LineWidth', 1, ...
                    'LabelColor', 'b', ...
                    'LabelFontSize', 10, ...
                    'LabelBackgroundColor', 'y', ...
                    'LabelFontWeight', 'normal', ...
                    'LabelVisible', true);
        end
    end
    
    if isFixedSelectedLine
        lineItems = get(lineSelectList, 'String');
        lineIdx = find(strcmp(lineItems, selectedLineArg), 1, 'first');
        if isempty(lineIdx)
            lineIdx = 1;
        end
        set(lineSelectList, 'Value', lineIdx);
    end
    selectLine(lineSelectList); % Initialize the GUI with current line settings
    
end

function syncSignalViewerLogoCheckboxes()
    global lines_and_styles
    viewerFig = findobj('Type', 'figure', 'Tag', 'SignalViewerGUI');
    if isempty(viewerFig)
        return;
    end
    eventsLogoBtn = findobj(viewerFig, 'Tag', 'show_events_logo_button');
    stimLogoBtn = findobj(viewerFig, 'Tag', 'show_stim_logo_button');
    if isempty(lines_and_styles) || ~isfield(lines_and_styles, 'events_lines')
        return;
    end
    if ~isfield(lines_and_styles.events_lines, 'LabelVisible')
        lines_and_styles.events_lines.LabelVisible = true;
    end
    if ~isempty(eventsLogoBtn)
        set(eventsLogoBtn, 'Value', logical(lines_and_styles.events_lines.LabelVisible));
    end
    if isempty(lines_and_styles) || ~isfield(lines_and_styles, 'stimulus_lines')
        return;
    end
    if ~isfield(lines_and_styles.stimulus_lines, 'LabelVisible')
        lines_and_styles.stimulus_lines.LabelVisible = true;
    end
    if ~isempty(stimLogoBtn)
        set(stimLogoBtn, 'Value', logical(lines_and_styles.stimulus_lines.LabelVisible));
    end
end