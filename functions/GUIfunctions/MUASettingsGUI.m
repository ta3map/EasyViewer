function wasApplied = MUASettingsGUI()
    figTag = 'MUASettingsGUI';
    guiFig = findobj('Type', 'figure', 'Tag', figTag);
    wasApplied = false;
    if ~isempty(guiFig)
        figure(guiFig);
        return
    end

    global std_coef binsize visualSettings

    if ~isfield(visualSettings, 'mua_use_mask')
        visualSettings.mua_use_mask = true;
    end
    if ~isfield(visualSettings, 'mua_color') || isempty(visualSettings.mua_color)
        visualSettings.mua_color = '#FF0000';
    end
    if ~isfield(visualSettings, 'mua_alpha') || ~isfinite(visualSettings.mua_alpha)
        visualSettings.mua_alpha = 0.9;
    end
    if isempty(binsize) || ~isfinite(binsize) || binsize <= 0
        binsize = 0.005;
    end

    MUASettingsFig = figure( ...
        'Name', 'MUA Settings', ...
        'Tag', figTag, ...
        'NumberTitle', 'off', ...
        'MenuBar', 'none', ...
        'ToolBar', 'none', ...
        'Position', [360 180 360 320], ...
        'Resize', 'off', ...
        'WindowStyle', 'modal');

    uicontrol('Parent', MUASettingsFig, 'Style', 'text', ...
        'String', 'MUA visualization settings', ...
        'Position', [20 285 320 20], 'HorizontalAlignment', 'left');

    showSpikesCheckbox = uicontrol('Parent', MUASettingsFig, 'Style', 'checkbox', ...
        'String', 'Show MUA', ...
        'Value', logical(visualSettings.show_spikes), ...
        'Position', [20 255 130 24]);

    uicontrol('Parent', MUASettingsFig, 'Style', 'text', ...
        'String', 'MUA coef:', ...
        'Position', [20 225 90 20], 'HorizontalAlignment', 'left');
    stdCoefInit = min(max(double(std_coef), 0), 10);
    stdCoefEdit = uicontrol('Parent', MUASettingsFig, 'Style', 'edit', ...
        'String', num2str(stdCoefInit), ...
        'Position', [120 225 60 24], 'BackgroundColor', 'white', ...
        'Callback', @onStdCoefEditChanged);
    stdCoefSlider = uicontrol('Parent', MUASettingsFig, 'Style', 'slider', ...
        'Min', 0, 'Max', 10, 'Value', stdCoefInit, ...
        'Position', [190 225 150 24], ...
        'Callback', @onStdCoefSliderChanged);

    uicontrol('Parent', MUASettingsFig, 'Style', 'text', ...
        'String', 'Render mode:', ...
        'Position', [20 195 90 20], 'HorizontalAlignment', 'left');
    renderPopup = uicontrol('Parent', MUASettingsFig, 'Style', 'popupmenu', ...
        'String', {'Scatter', 'Mask'}, ...
        'Value', 1 + logical(visualSettings.mua_use_mask), ...
        'Position', [120 195 220 24], 'BackgroundColor', 'white');

    uicontrol('Parent', MUASettingsFig, 'Style', 'text', ...
        'String', 'Bin size (ms):', ...
        'Position', [20 165 90 20], 'HorizontalAlignment', 'left');
    binSizeEdit = uicontrol('Parent', MUASettingsFig, 'Style', 'edit', ...
        'String', num2str(binsize * 1000), ...
        'Position', [120 165 220 24], 'BackgroundColor', 'white');

    uicontrol('Parent', MUASettingsFig, 'Style', 'text', ...
        'String', 'Mask alpha (%):', ...
        'Position', [20 135 90 20], 'HorizontalAlignment', 'left');
    alphaPercentInit = min(max(double(visualSettings.mua_alpha), 0), 1) * 100;
    alphaEdit = uicontrol('Parent', MUASettingsFig, 'Style', 'edit', ...
        'String', num2str(alphaPercentInit), ...
        'Position', [120 135 60 24], 'BackgroundColor', 'white', ...
        'Callback', @onAlphaEditChanged);
    alphaSlider = uicontrol('Parent', MUASettingsFig, 'Style', 'slider', ...
        'Min', 0, 'Max', 100, 'Value', alphaPercentInit, ...
        'Position', [190 135 150 24], ...
        'Callback', @onAlphaSliderChanged);

    uicontrol('Parent', MUASettingsFig, 'Style', 'text', ...
        'String', 'MUA color:', ...
        'Position', [20 105 90 20], 'HorizontalAlignment', 'left');
    colorPreview = uicontrol('Parent', MUASettingsFig, 'Style', 'text', ...
        'String', '      ', ...
        'Position', [120 105 50 24], ...
        'BackgroundColor', hexToRgb(visualSettings.mua_color));
    uicontrol('Parent', MUASettingsFig, 'Style', 'pushbutton', ...
        'String', 'Palette...', ...
        'Position', [180 105 160 24], ...
        'Callback', @chooseMUAColor);

    uicontrol('Parent', MUASettingsFig, 'Style', 'pushbutton', ...
        'String', 'Reset', ...
        'Position', [80 20 80 28], ...
        'Callback', @resetDefaults);
    uicontrol('Parent', MUASettingsFig, 'Style', 'pushbutton', ...
        'String', 'Apply', ...
        'Position', [170 20 80 28], ...
        'Callback', @applySettings);
    uicontrol('Parent', MUASettingsFig, 'Style', 'pushbutton', ...
        'String', 'Cancel', ...
        'Position', [260 20 80 28], ...
        'Callback', @(~,~) close(MUASettingsFig));

    uiwait(MUASettingsFig);

    function resetDefaults(~, ~)
        set(showSpikesCheckbox, 'Value', 0);
        set(stdCoefEdit, 'String', '0');
        set(stdCoefSlider, 'Value', 0);
        set(renderPopup, 'Value', 2); % Mask
        set(binSizeEdit, 'String', '5');
        set(alphaEdit, 'String', '90');
        set(alphaSlider, 'Value', 90);
        visualSettings.mua_color = '#FF0000';
        set(colorPreview, 'BackgroundColor', hexToRgb(visualSettings.mua_color));
    end

    function onAlphaSliderChanged(~, ~)
        set(alphaEdit, 'String', sprintf('%.0f', get(alphaSlider, 'Value')));
    end

    function onStdCoefSliderChanged(~, ~)
        set(stdCoefEdit, 'String', sprintf('%.2f', get(stdCoefSlider, 'Value')));
    end

    function onStdCoefEditChanged(~, ~)
        value = str2double(get(stdCoefEdit, 'String'));
        if isnan(value)
            set(stdCoefEdit, 'String', sprintf('%.2f', get(stdCoefSlider, 'Value')));
            return;
        end
        value = min(max(value, 0), 10);
        set(stdCoefEdit, 'String', sprintf('%.2f', value));
        set(stdCoefSlider, 'Value', value);
    end

    function onAlphaEditChanged(~, ~)
        value = str2double(get(alphaEdit, 'String'));
        if isnan(value)
            set(alphaEdit, 'String', sprintf('%.0f', get(alphaSlider, 'Value')));
            return;
        end
        value = min(max(value, 0), 100);
        set(alphaEdit, 'String', sprintf('%.0f', value));
        set(alphaSlider, 'Value', value);
    end

    function applySettings(~, ~)
        newStdCoef = str2double(get(stdCoefEdit, 'String'));
        if isnan(newStdCoef)
            errordlg('MUA coef must be a number.', 'MUA settings', 'modal');
            return;
        end

        newBinMs = str2double(get(binSizeEdit, 'String'));
        if isnan(newBinMs) || newBinMs <= 0
            errordlg('Bin size must be a positive number.', 'MUA settings', 'modal');
            return;
        end
        newAlphaPercent = str2double(get(alphaEdit, 'String'));
        if isnan(newAlphaPercent) || newAlphaPercent < 0 || newAlphaPercent > 100
            errordlg('Mask alpha must be in range [0..100] percent.', 'MUA settings', 'modal');
            return;
        end

        std_coef = min(max(newStdCoef, 0), 10);
        binsize = newBinMs / 1000;
        visualSettings.show_spikes = logical(get(showSpikesCheckbox, 'Value'));
        visualSettings.mua_use_mask = logical(get(renderPopup, 'Value') == 2);
        visualSettings.mua_alpha = newAlphaPercent / 100;

        saveChannelSettings('std_coef', 'binsize', 'visualSettings');
        wasApplied = true;

        uiresume(MUASettingsFig);
        close(MUASettingsFig);
    end

    function chooseMUAColor(~, ~)
        pickedColor = chooseColorFromPalette(visualSettings.mua_color);
        if isempty(pickedColor)
            return;
        end
        visualSettings.mua_color = pickedColor;
        set(colorPreview, 'BackgroundColor', hexToRgb(visualSettings.mua_color));
    end

    function selectedHex = chooseColorFromPalette(currentHex)
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
            'Name', 'MUA Color Palette', ...
            'NumberTitle', 'off', ...
            'MenuBar', 'none', ...
            'ToolBar', 'none', ...
            'Resize', 'off', ...
            'WindowStyle', 'modal');

        selectedHex = '';
        uicontrol('Parent', paletteFig, 'Style', 'text', ...
            'String', 'Select MUA color', ...
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
                'BackgroundColor', hexToRgb(oneHex), ...
                'Callback', @(~,~) selectAndClose(oneHex));
        end

        uicontrol('Parent', paletteFig, 'Style', 'pushbutton', ...
            'String', 'Cancel', ...
            'Position', [figW-90 10 80 25], ...
            'Callback', @(~,~) close(paletteFig));

        if ~isempty(currentHex)
            selectedHex = currentHex;
        end

        uiwait(paletteFig);

        function selectAndClose(hex)
            selectedHex = hex;
            if isvalid(paletteFig)
                uiresume(paletteFig);
                close(paletteFig);
            end
        end
    end

    function rgb = hexToRgb(hexColor)
        rgb = [1, 0, 0];
        if ~(ischar(hexColor) || isstring(hexColor))
            return;
        end
        hexColor = char(hexColor);
        if startsWith(hexColor, '#') && numel(hexColor) == 7
            rgb = [ ...
                hex2dec(hexColor(2:3)), ...
                hex2dec(hexColor(4:5)), ...
                hex2dec(hexColor(6:7))] / 255;
        end
    end
end
