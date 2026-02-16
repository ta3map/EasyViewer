function optionsRemovalArtifactsGUI()
    
    global art_rem_settings SettingsFilepath updatePlotFunc
    
    % Если SettingsFilepath пустая - устанавливаем путь по умолчанию
    if isempty(SettingsFilepath)
        SettingsFilepath = fullfile(tempdir, 'ev_settings.mat');
    end
    
    default_art_rem = struct('artifact_window_ms', 0, 'interp_method', 'linear');
    if isempty(art_rem_settings) || ~isfield(art_rem_settings, 'artifact_window_ms')
        try
            d = load(SettingsFilepath);
            art_rem_settings = d.art_rem_settings;
        catch
            art_rem_settings = default_art_rem;
        end
    end
    if ~isfield(art_rem_settings, 'interp_method')
        art_rem_settings.interp_method = 'linear';
    end
    
    window_ms = art_rem_settings.artifact_window_ms;
    interp_methods = {'linear', 'spline', 'pchip', 'smooth', 'median'};
    [~, method_idx] = ismember(art_rem_settings.interp_method, interp_methods);
    if method_idx == 0
        method_idx = 1;
    end
    
    % Идентификатор (tag) для GUI фигуры
    figTag = 'RemovalArtifactsGUI';
    
    % Поиск открытой фигуры с заданным идентификатором
    guiFig = findobj('Type', 'figure', 'Tag', figTag);
    
    if ~isempty(guiFig)
        figure(guiFig);
        return
    end
    
    fig = figure('Name', 'Removal of Artifacts', 'Tag', figTag, ...
        'NumberTitle', 'off', ...
        'MenuBar', 'none', 'ToolBar', 'none', 'Position', [100, 100, 450, 190], ...
        'Resize', 'off', ...
        'WindowStyle', 'modal');

    isArtifactRemovalEnabled = window_ms ~= 0;
    
    chkArtifactRemoval = uicontrol('Style', 'checkbox', 'String', 'Enable Artifact Removal', ...
        'Position', [50, 120, 200, 30], 'Value', isArtifactRemovalEnabled, ...
        'Callback', @toggleArtifactRemoval);
    
    uicontrol('Style', 'text', 'String', 'Window size, ms', ...
        'Position', [260, 150, 100, 15], 'HorizontalAlignment', 'left');
    
    editArtRemWindow = uicontrol('Style', 'edit', 'Position', [260, 120, 100, 30], ...
        'String', num2str(window_ms), 'Enable', bool2str(isArtifactRemovalEnabled), ...
        'Callback', @setArtRemWindow);
    
    uicontrol('Style', 'text', 'String', 'Interpolation', ...
        'Position', [50, 75, 100, 15], 'HorizontalAlignment', 'left');
    
    popupInterp = uicontrol('Style', 'popupmenu', 'Position', [50, 45, 150, 30], ...
        'String', interp_methods, 'Value', method_idx, 'Callback', @setInterpMethod);
    
    btnApply = uicontrol('Style', 'pushbutton', 'String', 'Apply', ...
        'Position', [175, 10, 100, 30], 'Callback', @applySettings);
    
    function toggleArtifactRemoval(hObject, ~)
        if hObject.Value
            set(editArtRemWindow, 'Enable', 'on');
        else
            set(editArtRemWindow, 'Enable', 'off');
            window_ms = 0;
        end
    end

    function setArtRemWindow(hObject, ~)
        window_ms = str2double(hObject.String);
    end

    function setInterpMethod(~, ~)
    end

    function applySettings(~, ~)
        art_rem_settings = struct('artifact_window_ms', window_ms, ...
            'interp_method', interp_methods{popupInterp.Value});
        
        try
            if exist(SettingsFilepath, 'file')
                save(SettingsFilepath, 'art_rem_settings', '-append');
            else
                initializeDefaultSettings();
                save(SettingsFilepath, 'art_rem_settings', '-append');
            end
        catch ME
            warning('Error saving settings: %s', ME.message);
            try
                initializeDefaultSettings();
                save(SettingsFilepath, 'art_rem_settings', '-append');
            catch ME2
                fprintf('Error saving settings: %s\n', ME2.message);
            end
        end
        
        if ~isempty(updatePlotFunc)
            try
                updatePlotFunc();
            catch
            end
        end
        
        close(fig);
    end

    function str = bool2str(bool)
        if bool
            str = 'on';
        else
            str = 'off';
        end
    end
end
