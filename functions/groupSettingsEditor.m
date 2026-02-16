function groupSettingsEditor()
    % Редактор групповых настроек для EasyViewer
    % Позволяет редактировать и сохранять настройки проекта
    
    % ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ
    global matFilePath newFs shiftCoeff time_back time_forward stim_offset
    global updateTableFunc updateLocalCoefsFunc updatePlotFunc saveChannelSettingsFunc
    global EV_version numChannels Fs timeUnitFactor selectedUnit updatePlotFunc
    global art_rem_settings SettingsFilepath
    
    % Проверяем, не открыто ли уже окно
    existingFig = findobj('Tag', 'GroupSettingsEditor');
    if ~isempty(existingFig)
        figure(existingFig);
        return;
    end
    
    % Получаем текущий путь к проекту
    if isempty(matFilePath)
        fprintf('No project loaded. Please load a MAT file first.\n');
        return;
    end
    
    [projectPath, ~, ~] = fileparts(matFilePath);
    [~, projectName, ~] = fileparts(projectPath);
    
    % Путь к групповым настройкам
    groupSettingsPath = fullfile(projectPath, [projectName '.stn']);
    
    % === КЛЮЧЕВОЕ ИЗМЕНЕНИЕ ===
    % Загружаем текущие настройки ИЛИ создаем по умолчанию
    if isfile(groupSettingsPath)
        % Групповые настройки существуют - загружаем их
        currentSettings = loadGroupSettings(groupSettingsPath);
        disp('Loaded existing group settings');
    else
        % Групповых настроек нет - создаем их
        createGroupSettings(groupSettingsPath, numChannels, Fs, EV_version);
        % Загружаем созданные настройки
        currentSettings = loadGroupSettings(groupSettingsPath);
        disp('Created new group settings');
    end
    
    % === ИНИЦИАЛИЗАЦИЯ ГЛОБАЛЬНЫХ ПЕРЕМЕННЫХ ===
    % Берем значения из currentSettings (а не "от балды")
    newFs = currentSettings.newFs;
    shiftCoeff = currentSettings.shiftCoeff;
    time_back = currentSettings.time_back;
    time_forward = currentSettings.time_forward;
    
    % ТОЛЬКО для stim_offset проверяем отсутствие и инициализируем из настроек
    if ~exist('stim_offset', 'var') || isempty(stim_offset)
        stim_offset = currentSettings.stim_offset;
    end
    
    % Инициализация art_rem_settings из глобальных настроек
    if isempty(SettingsFilepath)
        SettingsFilepath = fullfile(tempdir, 'ev_settings.mat');
    end
    
    if isempty(art_rem_settings) || ~isfield(art_rem_settings, 'artifact_window_ms')
        try
            d = load(SettingsFilepath);
            art_rem_settings = d.art_rem_settings;
        catch
            art_rem_settings = struct('artifact_window_ms', 0, 'interp_method', 'linear');
        end
    end
    if ~isfield(art_rem_settings, 'interp_method')
        art_rem_settings.interp_method = 'linear';
    end
    
    % Создаем главное окно с уникальным тегом и запретом масштабирования
    % Получаем размеры экрана для центрирования окна
    screenSize = get(0, 'ScreenSize');
    windowWidth = 500;
    windowHeight = 810;
    
    % Центрируем окно на экране
    xPos = (screenSize(3) - windowWidth) / 2;
    yPos = (screenSize(4) - windowHeight) / 2;
    
    fig = figure('Name', ['Group Settings Editor - ' projectName], ...
                 'NumberTitle', 'off', ...
                 'MenuBar', 'none', ...
                 'ToolBar', 'none', ...
                 'Position', [xPos, yPos, windowWidth, windowHeight], ...
                 'Resize', 'off', ...
                 'Tag', 'GroupSettingsEditor', ...
                 'CloseRequestFcn', @closeWindow);
    
    % === ЗАГОЛОВОК ===
    % Убран заголовок "Group Settings Editor"
    
    % === FILE OPERATIONS ===
    % Open Settings File
    openBtn = uicontrol('Parent', fig, 'Style', 'pushbutton', ...
                        'String', 'Open Settings File', ...
                        'Position', [25, 700, 120, 30], ...
                        'Callback', @openSettingsFile);
    
    % Current File Info
    currentFileText = uicontrol('Parent', fig, 'Style', 'text', ...
                                'String', ['Current: ' projectName '.stn'], ...
                                'Position', [160, 705, 300, 20], ...
                                'HorizontalAlignment', 'left', ...
                                'FontSize', 9);
    
    % Разделительная линия
    uicontrol('Parent', fig, 'Style', 'text', ...
              'String', '────────────────────────────────────────────────────────', ...
              'Position', [25, 675, 450, 15], ...
              'HorizontalAlignment', 'left', ...
              'ForegroundColor', [0.5, 0.5, 0.5]);
    
    % === DISPLAY SETTINGS ===
    % Sampling Rate
    uicontrol('Parent', fig, 'Style', 'text', ...
              'String', 'Sampling Rate (Hz):', ...
              'Position', [25, 650, 150, 20], ...
              'HorizontalAlignment', 'left', ...
              'FontWeight', 'bold');
    
    newFsEdit = uicontrol('Parent', fig, 'Style', 'edit', ...
                          'String', num2str(currentSettings.newFs), ...
                          'Position', [200, 650, 100, 25], ...
                          'HorizontalAlignment', 'center');
    
    % Channel Shift
    uicontrol('Parent', fig, 'Style', 'text', ...
              'String', 'Channel Shift:', ...
              'Position', [25, 610, 150, 20], ...
              'HorizontalAlignment', 'left', ...
              'FontWeight', 'bold');
    
    shiftCoeffEdit = uicontrol('Parent', fig, 'Style', 'edit', ...
                               'String', num2str(currentSettings.shiftCoeff), ...
                               'Position', [200, 610, 100, 25], ...
                               'HorizontalAlignment', 'center');
    
    % Разделительная линия
    uicontrol('Parent', fig, 'Style', 'text', ...
              'String', '────────────────────────────────────────────────────────', ...
              'Position', [25, 580, 450, 15], ...
              'HorizontalAlignment', 'left', ...
              'ForegroundColor', [0.5, 0.5, 0.5]);
    
    % === TIME WINDOWS ===
    % Before
    uicontrol('Parent', fig, 'Style', 'text', ...
              'String', ['Before (' selectedUnit '):'], ...
              'Position', [25, 560, 150, 20], ...
              'HorizontalAlignment', 'left', ...
              'FontWeight', 'bold');
    
    timeBackEdit = uicontrol('Parent', fig, 'Style', 'edit', ...
                             'String', num2str(currentSettings.time_back * timeUnitFactor), ...
                             'Position', [200, 560, 100, 25], ...
                             'HorizontalAlignment', 'center');
    
    % After
    uicontrol('Parent', fig, 'Style', 'text', ...
              'String', ['After (' selectedUnit '):'], ...
              'Position', [25, 520, 150, 20], ...
              'HorizontalAlignment', 'left', ...
              'FontWeight', 'bold');
    
    timeForwardEdit = uicontrol('Parent', fig, 'Style', 'edit', ...
                                'String', num2str(currentSettings.time_forward * timeUnitFactor), ...
                                'Position', [200, 520, 100, 25], ...
                                'HorizontalAlignment', 'center');
    
    % Разделительная линия
    uicontrol('Parent', fig, 'Style', 'text', ...
              'String', '────────────────────────────────────────────────────────', ...
              'Position', [25, 490, 450, 15], ...
              'HorizontalAlignment', 'left', ...
              'ForegroundColor', [0.5, 0.5, 0.5]);
    
    % === STIMULATION SETTINGS ===
    % Stimulus Offset
    uicontrol('Parent', fig, 'Style', 'text', ...
              'String', ['Stimulus Offset (' selectedUnit '):'], ...
              'Position', [25, 470, 150, 20], ...
              'HorizontalAlignment', 'left', ...
              'FontWeight', 'bold');
    
    stimOffsetEdit = uicontrol('Parent', fig, 'Style', 'edit', ...
                               'String', num2str(currentSettings.stim_offset * timeUnitFactor), ...
                               'Position', [200, 470, 100, 25], ...
                               'HorizontalAlignment', 'center');
    
    % Разделительная линия
    uicontrol('Parent', fig, 'Style', 'text', ...
              'String', '────────────────────────────────────────────────────────', ...
              'Position', [25, 440, 450, 15], ...
              'HorizontalAlignment', 'left', ...
              'ForegroundColor', [0.5, 0.5, 0.5]);
    
    % === TIME UNIT SELECTION ===
    uicontrol('Parent', fig, 'Style', 'text', ...
              'String', 'Time Unit:', ...
              'Position', [25, 420, 80, 20], ...
              'HorizontalAlignment', 'left', ...
              'FontWeight', 'bold');
    
    timeUnitPopup = uicontrol('Parent', fig, 'Style', 'popup', ...
                              'String', {'ms', 's', 'min'}, ...
                              'Position', [110, 420, 60, 25], ...
                              'Callback', @changeTimeUnit);
    
    % Set initial time unit selection
    units = {'ms', 's', 'min'};
    index = find(strcmp(units, selectedUnit));
    set(timeUnitPopup, 'Value', index);
    
    % Разделительная линия
    uicontrol('Parent', fig, 'Style', 'text', ...
              'String', '────────────────────────────────────────────────────────', ...
              'Position', [25, 390, 450, 15], ...
              'HorizontalAlignment', 'left', ...
              'ForegroundColor', [0.5, 0.5, 0.5]);
    
    % === ARTIFACT REMOVAL SETTINGS ===
    chkArtifactRemoval = uicontrol('Parent', fig, 'Style', 'checkbox', ...
                                   'String', 'Enable Artifact Removal', ...
                                   'Position', [25, 360, 200, 25], ...
                                   'Value', art_rem_settings.artifact_window_ms ~= 0, ...
                                   'Callback', @toggleArtifactRemoval, ...
                                   'FontWeight', 'bold');
    
    uicontrol('Parent', fig, 'Style', 'text', ...
              'String', ['Window size (' selectedUnit '):'], ...
              'Position', [25, 320, 120, 20], ...
              'HorizontalAlignment', 'left');
    
    artWindowEdit = uicontrol('Parent', fig, 'Style', 'edit', ...
                              'String', num2str(art_rem_settings.artifact_window_ms * timeUnitFactor / 1000), ...
                              'Position', [150, 320, 80, 25], ...
                              'HorizontalAlignment', 'center', ...
                              'Enable', bool2str(art_rem_settings.artifact_window_ms ~= 0), ...
                              'Callback', @setArtRemWindow);
    
    interp_list = {'linear', 'spline', 'pchip', 'smooth', 'median'};
    [~, interp_idx] = ismember(art_rem_settings.interp_method, interp_list);
    if interp_idx == 0
        interp_idx = 1;
    end
    uicontrol('Parent', fig, 'Style', 'text', 'String', 'Interpolation:', ...
              'Position', [25, 285, 100, 20], 'HorizontalAlignment', 'left');
    popupArtInterp = uicontrol('Parent', fig, 'Style', 'popupmenu', ...
                              'String', interp_list, 'Value', interp_idx, ...
                              'Position', [150, 285, 120, 25]);
    
    % Разделительная линия
    uicontrol('Parent', fig, 'Style', 'text', ...
              'String', '────────────────────────────────────────────────────────', ...
              'Position', [25, 258, 450, 15], ...
              'HorizontalAlignment', 'left', ...
              'ForegroundColor', [0.5, 0.5, 0.5]);
    
    % === BUTTONS ===
    % Apply & Save to Current Project
    applySaveBtn = uicontrol('Parent', fig, 'Style', 'pushbutton', ...
                             'String', 'Apply & Save', ...
                             'Position', [25, 50, 150, 35], ...
                             'Callback', @applyAndSave, ...
                             'FontSize', 11, 'FontWeight', 'bold');
    
    % Устанавливаем фокус на кнопку Apply & Save для быстрого доступа по Enter
    uicontrol(applySaveBtn);
    
    % Reset to Defaults
    resetBtn = uicontrol('Parent', fig, 'Style', 'pushbutton', ...
                         'String', 'Reset to Defaults', ...
                         'Position', [190, 50, 150, 35], ...
                         'Callback', @resetToDefaults, ...
                         'FontSize', 11);
    
    % Close
    closeBtn = uicontrol('Parent', fig, 'Style', 'pushbutton', ...
                         'String', 'Close', ...
                         'Position', [355, 50, 100, 35], ...
                         'Callback', @closeWindow, ...
                         'FontSize', 11);
    
    % === Callback Functions ===
    
    function openSettingsFile(~, ~)
        % Открывает файл настроек для редактирования
        try
            % Определяем начальную директорию
            if isfile(groupSettingsPath)
                startPath = groupSettingsPath;
            else
                startPath = projectPath;
            end
            
            % Открываем диалог выбора файла
            [fileName, filePath] = uigetfile('*.stn', 'Select Group Settings File', startPath);
            
            if fileName ~= 0
                selectedFilePath = fullfile(filePath, fileName);
                
                % Загружаем настройки из выбранного файла
                loadedSettings = loadGroupSettings(selectedFilePath);
                
                if ~isempty(fieldnames(loadedSettings))
                    % Обновляем поля интерфейса
                    if isfield(loadedSettings, 'newFs')
                        set(newFsEdit, 'String', num2str(loadedSettings.newFs));
                    end
                    
                    if isfield(loadedSettings, 'shiftCoeff')
                        set(shiftCoeffEdit, 'String', num2str(loadedSettings.shiftCoeff));
                    end
                    
                    if isfield(loadedSettings, 'time_back')
                        set(timeBackEdit, 'String', num2str(loadedSettings.time_back * timeUnitFactor));
                    end
                    
                    if isfield(loadedSettings, 'time_forward')
                        set(timeForwardEdit, 'String', num2str(loadedSettings.time_forward * timeUnitFactor));
                    end
                    
                    if isfield(loadedSettings, 'stim_offset')
                        set(stimOffsetEdit, 'String', num2str(loadedSettings.stim_offset * timeUnitFactor));
                    end
                    
                    % Настройки удаления артефактов не загружаются из групповых настроек,
                    % так как это глобальная настройка приложения
                    
                    % Обновляем глобальные переменные для синхронизации
                    if isfield(loadedSettings, 'newFs')
                        newFs = loadedSettings.newFs;
                    end
                    if isfield(loadedSettings, 'shiftCoeff')
                        shiftCoeff = loadedSettings.shiftCoeff;
                    end
                    if isfield(loadedSettings, 'time_back')
                        time_back = loadedSettings.time_back;
                    end
                    if isfield(loadedSettings, 'time_forward')
                        time_forward = loadedSettings.time_forward;
                    end
                    if isfield(loadedSettings, 'stim_offset')
                        stim_offset = loadedSettings.stim_offset;
                    end
                    
                    % Обновляем UI элементы в основном окне
                    mainFig = findobj('Tag', 'SignalViewerGUI');
                    if ~isempty(mainFig)
                        % Обновляем поля ввода временных окон
                        timeBackEdit_main = findobj(mainFig, 'Tag', 'timeBackEdit');
                        if ~isempty(timeBackEdit_main) && isfield(loadedSettings, 'time_back')
                            set(timeBackEdit_main, 'String', num2str(time_back * timeUnitFactor));
                        end
                        
                        timeForwardEdit_main = findobj(mainFig, 'Tag', 'timeForwardEdit');
                        if ~isempty(timeForwardEdit_main) && isfield(loadedSettings, 'time_forward')
                            set(timeForwardEdit_main, 'String', num2str(time_forward * timeUnitFactor));
                        end
                        
                        % Обновляем поле ввода коэффициента сдвига
                        shiftCoeffEdit_main = findobj(mainFig, 'Tag', 'shiftCoeffEdit');
                        if ~isempty(shiftCoeffEdit_main) && isfield(loadedSettings, 'shiftCoeff')
                            set(shiftCoeffEdit_main, 'String', num2str(shiftCoeff));
                        end
                        
                        % Обновляем поле ввода частоты дискретизации
                        FsCoeffEdit_main = findobj(mainFig, 'Tag', 'FsCoeffEdit');
                        if ~isempty(FsCoeffEdit_main) && isfield(loadedSettings, 'newFs')
                            set(FsCoeffEdit_main, 'String', num2str(newFs));
                        end
                    end
                    
                    % Применяем сдвиг времен стимулов
                    applyStimulusOffset();
                    
                    % Обновляем информацию о текущем файле
                    [~, fileNameOnly, ~] = fileparts(fileName);
                    set(currentFileText, 'String', ['Current: ' fileNameOnly '.stn']);
                    
                    % Обновляем путь к групповым настройкам
                    groupSettingsPath = selectedFilePath;
                    
                    fprintf('Settings loaded from: %s\n', fileName);
                else
                    fprintf('Could not load settings from the selected file\n');
                end
            end
            
        catch ME
            fprintf('Error opening settings file: %s\n', ME.message);
        end
    end
    
    function applyAndSave(~, ~)
        % Применяет настройки к текущему проекту и сохраняет их
        try
            % Получаем значения из полей
            newFs_val = str2double(get(newFsEdit, 'String'));
            shiftCoeff_val = str2double(get(shiftCoeffEdit, 'String'));
            time_back_val = str2double(get(timeBackEdit, 'String')) / timeUnitFactor; % Конвертируем из текущих единиц в секунды
            time_forward_val = str2double(get(timeForwardEdit, 'String')) / timeUnitFactor; % Конвертируем из текущих единиц в секунды
            stim_offset_val = str2double(get(stimOffsetEdit, 'String')) / timeUnitFactor; % Конвертируем из текущих единиц в секунды
            
            if get(chkArtifactRemoval, 'Value')
                art_window_val = str2double(get(artWindowEdit, 'String')) / timeUnitFactor * 1000;
            else
                art_window_val = 0;
            end
            art_rem_settings = struct('artifact_window_ms', art_window_val, ...
                'interp_method', interp_list{get(popupArtInterp, 'Value')});
            
            newFs = newFs_val;
            shiftCoeff = shiftCoeff_val;
            time_back = time_back_val;
            time_forward = time_forward_val;
            stim_offset = stim_offset_val;
            
            % Применяем сдвиг времен стимулов
            applyStimulusOffset();
            
            % Сохраняем в файл (теперь используются обновленные глобальные переменные)
            save(groupSettingsPath, ...
                'newFs', 'shiftCoeff', 'time_back', 'time_forward', 'stim_offset', 'EV_version');
            
            try
                if exist(SettingsFilepath, 'file')
                    save(SettingsFilepath, 'art_rem_settings', '-append');
                else
                    initializeDefaultSettings();
                    save(SettingsFilepath, 'art_rem_settings', '-append');
                end
            catch ME
                warning('Error saving art_rem_settings to global settings: %s', ME.message);
            end
            
            % Обновляем UI элементы в основном окне для синхронизации с новыми настройками
            % Получаем ссылки на UI элементы из основного окна
            mainFig = findobj('Tag', 'SignalViewerGUI');
            if ~isempty(mainFig)
                % Обновляем поля ввода временных окон
                timeBackEdit_main = findobj(mainFig, 'Tag', 'timeBackEdit');
                if ~isempty(timeBackEdit_main)
                    set(timeBackEdit_main, 'String', num2str(time_back * timeUnitFactor));
                end
                
                timeForwardEdit_main = findobj(mainFig, 'Tag', 'timeForwardEdit');
                if ~isempty(timeForwardEdit_main)
                    set(timeForwardEdit_main, 'String', num2str(time_forward * timeUnitFactor));
                end
                
                % Обновляем поле ввода коэффициента сдвига
                shiftCoeffEdit_main = findobj(mainFig, 'Tag', 'shiftCoeffEdit');
                if ~isempty(shiftCoeffEdit_main)
                    set(shiftCoeffEdit_main, 'String', num2str(shiftCoeff));
                end
                
                % Обновляем поле ввода частоты дискретизации
                FsCoeffEdit_main = findobj(mainFig, 'Tag', 'FsCoeffEdit');
                if ~isempty(FsCoeffEdit_main)
                    set(FsCoeffEdit_main, 'String', num2str(newFs));
                end
            end
            
            % Обновляем интерфейс
            updateMainInterface();
            
            % === ДОБАВЛЕНО: Обновляем график анализа сигнала ===
            try
                if ~isempty(updatePlotFunc)
                    updatePlotFunc();
                    disp('Analysis plot updated with new group settings');
                else
                    warning('updatePlotFunc not available');
                end
            catch ME
                warning('Could not update analysis plot: %s', ME.message);
            end
            
            % ВАЖНО: Пересохраняем индивидуальные настройки с новыми значениями
            % чтобы при следующем открытии файла загружались обновленные настройки
            try
                % Используем правильную функцию сохранения индивидуальных настроек
                if ~isempty(saveChannelSettingsFunc)
                    saveChannelSettingsFunc();
                    disp('Individual settings updated with new group values');
                else
                    warning('saveChannelSettingsFunc not available');
                end
            catch ME
                warning('Could not update individual settings: %s', ME.message);
            end
            
            % Закрываем окно редактора
            delete(fig);
            
            % Показываем сообщение об успехе
            fprintf('Settings applied and saved to current project successfully!\n');
            
        catch ME
            fprintf('Error applying and saving settings: %s\n', ME.message);
        end
    end
    
    function resetToDefaults(~, ~)
        % Сбрасывает настройки к значениям по умолчанию
        choice = questdlg('Reset all settings to default values?', ...
                          'Reset to Defaults', 'Yes', 'No', 'No');
        if strcmp(choice, 'Yes')
            % numChannels и Fs уже объявлены в основной функции
            [newFs_def, shiftCoeff_def, time_back_def, time_forward_def, stim_offset_def] = setDefaultGroupSettings(numChannels, Fs);
            
            art_rem_settings = struct('artifact_window_ms', 0, 'interp_method', 'linear');
            
            set(newFsEdit, 'String', num2str(newFs_def));
            set(shiftCoeffEdit, 'String', num2str(shiftCoeff_def));
            set(timeBackEdit, 'String', num2str(time_back_def * timeUnitFactor));
            set(timeForwardEdit, 'String', num2str(time_forward_def * timeUnitFactor));
            set(stimOffsetEdit, 'String', num2str(stim_offset_def * timeUnitFactor));
            set(chkArtifactRemoval, 'Value', false);
            set(artWindowEdit, 'String', '0');
            set(artWindowEdit, 'Enable', 'off');
            set(popupArtInterp, 'Value', 1);
            
            newFs = newFs_def;
            shiftCoeff = shiftCoeff_def;
            time_back = time_back_def;
            time_forward = time_forward_def;
            stim_offset = stim_offset_def;
            
            % Применяем сдвиг времен стимулов
            applyStimulusOffset();
            
            % Обновляем UI элементы в основном окне
            mainFig = findobj('Tag', 'SignalViewerGUI');
            if ~isempty(mainFig)
                % Обновляем поля ввода временных окон
                timeBackEdit_main = findobj(mainFig, 'Tag', 'timeBackEdit');
                if ~isempty(timeBackEdit_main)
                    set(timeBackEdit_main, 'String', num2str(time_back * timeUnitFactor));
                end
                
                timeForwardEdit_main = findobj(mainFig, 'Tag', 'timeForwardEdit');
                if ~isempty(timeForwardEdit_main)
                    set(timeForwardEdit_main, 'String', num2str(time_forward * timeUnitFactor));
                end
                
                % Обновляем поле ввода коэффициента сдвига
                shiftCoeffEdit_main = findobj(mainFig, 'Tag', 'shiftCoeffEdit');
                if ~isempty(shiftCoeffEdit_main)
                    set(shiftCoeffEdit_main, 'String', num2str(shiftCoeff));
                end
                
                % Обновляем поле ввода частоты дискретизации
                FsCoeffEdit_main = findobj(mainFig, 'Tag', 'FsCoeffEdit');
                if ~isempty(FsCoeffEdit_main)
                    set(FsCoeffEdit_main, 'String', num2str(newFs));
                end
            end
            
            try
                if exist(SettingsFilepath, 'file')
                    save(SettingsFilepath, 'art_rem_settings', '-append');
                else
                    initializeDefaultSettings();
                    save(SettingsFilepath, 'art_rem_settings', '-append');
                end
            catch ME
                warning('Error saving art_rem_settings to global settings: %s', ME.message);
            end
            
            % Обновляем основной интерфейс
            updateMainInterface();
            
            % === ДОБАВЛЕНО: Обновляем график анализа сигнала ===
            try
                if ~isempty(updatePlotFunc)
                    updatePlotFunc();
                    disp('Analysis plot updated with reset group settings');
                else
                    warning('updatePlotFunc not available');
                end
            catch ME
                warning('Could not update analysis plot: %s', ME.message);
            end
            
            fprintf('Settings reset to default values\n');
        end
    end
    
    function closeWindow(~, ~)
        % Закрывает окно
        delete(fig);
    end
    
    function updateMainInterface()
        % Обновляет основной интерфейс EasyViewer
        try
            % updateTableFunc, updateLocalCoefsFunc, updatePlotFunc уже объявлены в основной функции
            
            % Обновляем таблицу и график
            if ~isempty(updateTableFunc)
                updateTableFunc();
            end
            
            if ~isempty(updateLocalCoefsFunc)
                updateLocalCoefsFunc();
            end
            
            if ~isempty(updatePlotFunc)
                updatePlotFunc();
            end
            
        catch ME
            warning('Could not update main interface: %s', ME.message);
        end
    end

    function applyStimulusOffset()
        % Применяет сдвиг времен стимулов к глобальным переменным stims
        
        global stims stims_exist
        if stims_exist && ~isempty(stims)
            % Шаг 1: Вычитаем из всех времен время первого стимула (первый станет 0)
            firstStimTime = stims(1);
            stims = stims - firstStimTime;
            
            % Шаг 2: Применяем stim_offset (первый будет иметь значение stim_offset)
            if stim_offset ~= 0
                stims = stims + stim_offset;
                disp(['Applied stimulus offset: ' num2str(stim_offset) ' seconds']);
            end
            
            disp(['Normalized stimulus times: first stimulus at ' num2str(stims(1)) ' seconds']);
        end
    end
    
    function toggleArtifactRemoval(hObject, ~)
        % Включает/выключает удаление артефактов
        if hObject.Value
            set(artWindowEdit, 'Enable', 'on');
        else
            set(artWindowEdit, 'Enable', 'off');
            set(artWindowEdit, 'String', '0');
        end
    end
    
    function setArtRemWindow(hObject, ~)
        art_rem_settings.artifact_window_ms = str2double(hObject.String) / timeUnitFactor * 1000;
    end
    
    function changeTimeUnit(src, ~)
        % Изменяет единицы времени для всех временных параметров
        selectedUnit = src.String{src.Value};
        switch selectedUnit
            case 'ms'
                timeUnitFactor = 1000; % секунды в миллисекунды
            case 's'
                timeUnitFactor = 1; % секунды
            case 'min'
                timeUnitFactor = 1/60; % секунды в минуты
        end
        
        % Обновляем отображение всех полей времени
        set(timeBackEdit, 'String', num2str(time_back * timeUnitFactor));
        set(timeForwardEdit, 'String', num2str(time_forward * timeUnitFactor));
        set(stimOffsetEdit, 'String', num2str(stim_offset * timeUnitFactor));
        set(artWindowEdit, 'String', num2str(art_rem_settings.artifact_window_ms * timeUnitFactor / 1000));
        
        % Обновляем подписи
        timeBackText = findobj(fig, 'String', 'Before (');
        if ~isempty(timeBackText)
            set(timeBackText, 'String', ['Before (' selectedUnit '):']);
        end
        
        timeForwardText = findobj(fig, 'String', 'After (');
        if ~isempty(timeForwardText)
            set(timeForwardText, 'String', ['After (' selectedUnit '):']);
        end
        
        stimOffsetText = findobj(fig, 'String', 'Stimulus Offset (');
        if ~isempty(stimOffsetText)
            set(stimOffsetText, 'String', ['Stimulus Offset (' selectedUnit '):']);
        end
        
        artWindowText = findobj(fig, 'String', 'Window size (');
        if ~isempty(artWindowText)
            set(artWindowText, 'String', ['Window size (' selectedUnit '):']);
        end
        
        % Сохраняем изменения в глобальные настройки
        try
            if exist(SettingsFilepath, 'file')
                save(SettingsFilepath, 'selectedUnit', 'timeUnitFactor', '-append');
            else
                initializeDefaultSettings();
                save(SettingsFilepath, 'selectedUnit', 'timeUnitFactor', '-append');
            end
        catch ME
            warning('Error saving time unit settings: %s', ME.message);
        end
    end
    
    function str = bool2str(bool)
        % Конвертирует логическое значение в строку для Enable
        if bool
            str = 'on';
        else
            str = 'off';
        end
    end
end