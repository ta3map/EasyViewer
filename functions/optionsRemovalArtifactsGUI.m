function optionsRemovalArtifactsGUI()
    
    global art_rem_window_ms SettingsFilepath updateAnalysisPlotFunc_global
    
    % Если SettingsFilepath пустая - устанавливаем путь по умолчанию
    if isempty(SettingsFilepath)
        SettingsFilepath = fullfile(tempdir, 'ev_settings.mat');
    end
    
    % Проверяем, если глобальная переменная пустая - загружаем из файла настроек
    if isempty(art_rem_window_ms) && exist(SettingsFilepath, 'file')
        try
            d = load(SettingsFilepath);
            if isfield(d, 'art_rem_window_ms')
                art_rem_window_ms = d.art_rem_window_ms;
            else
                art_rem_window_ms = 0;
            end
        catch
            art_rem_window_ms = 0;
        end
    end
    
    % Если все еще пустая - устанавливаем значение по умолчанию
    if isempty(art_rem_window_ms)
        art_rem_window_ms = 0;
    end
    
    window_ms = art_rem_window_ms; % локальное значение
    
    % Идентификатор (tag) для GUI фигуры
    figTag = 'RemovalArtifactsGUI';
    
    % Поиск открытой фигуры с заданным идентификатором
    guiFig = findobj('Type', 'figure', 'Tag', figTag);
    
    if ~isempty(guiFig)
        % Делаем существующее окно текущим (активным)
        figure(guiFig);
        return
    end
    
    % Создание и настройка главного окна
    fig = figure('Name', 'Removal of Artifacts', 'Tag', figTag, ...
        'NumberTitle', 'off', ...
        'MenuBar', 'none', 'ToolBar', 'none', 'Position', [100, 100, 450, 150], ...
        'Resize', 'off', ...
        'WindowStyle', 'modal');  % Делаем окно модальным

    % Determine initial checkbox state
    isArtifactRemovalEnabled = window_ms ~= 0;
    
    % Checkbox for enabling/disabling artifact removal
    chkArtifactRemoval = uicontrol('Style', 'checkbox', 'String', 'Enable Artifact Removal', ...
        'Position', [50, 80, 200, 30], 'Value', isArtifactRemovalEnabled, ...
        'Callback', @toggleArtifactRemoval);
    
    % Text above the edit box
    txtWindowSize = uicontrol('Style', 'text', 'String', 'Window size, ms', ...
        'Position', [260, 110, 100, 15], 'HorizontalAlignment', 'left');
    
    % Edit box for setting the artifact removal window in ms
    editArtRemWindow = uicontrol('Style', 'edit', 'Position', [260, 80, 100, 30], ...
        'String', num2str(window_ms), 'Enable', bool2str(isArtifactRemovalEnabled), ...
        'Callback', @setArtRemWindow);
    
    % Apply button
    btnApply = uicontrol('Style', 'pushbutton', 'String', 'Apply', ...
        'Position', [175, 30, 100, 30], 'Callback', @applySettings);
    
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

    function applySettings(~, ~)
        % отправляем в глобальную переменную
        art_rem_window_ms = window_ms;
        
        % сохраняем фактор в глобальные настройки              
        save(SettingsFilepath, 'art_rem_window_ms', '-append');
        
        % Обновляем график в signalAnalysisGUI если он открыт
        if ~isempty(updateAnalysisPlotFunc_global)
            try
                updateAnalysisPlotFunc_global();
            catch
                % Игнорируем ошибки если функция недоступна
            end
        end
        
        % Close the GUI window
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
