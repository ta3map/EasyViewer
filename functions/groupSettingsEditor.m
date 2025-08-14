function groupSettingsEditor()
    % Редактор групповых настроек для EasyViewer
    % Позволяет редактировать и сохранять настройки проекта
    
    % ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ
    global matFilePath newFs shiftCoeff time_back time_forward stim_offset
    global updateTableFunc updateLocalCoefsFunc updatePlotFunc saveChannelSettingsFunc
    global EV_version numChannels Fs timeUnitFactor selectedUnit
    
    % Проверяем, не открыто ли уже окно
    existingFig = findobj('Tag', 'GroupSettingsEditor');
    if ~isempty(existingFig)
        figure(existingFig);
        return;
    end
    
    % Получаем текущий путь к проекту
    if isempty(matFilePath)
        errordlg('No project loaded. Please load a MAT file first.', 'No Project');
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
    
    % Основная панель
    mainPanel = uipanel('Parent', fig, 'Position', [0.05, 0.05, 0.9, 0.9]);
    
    % Заголовок
    titleText = uicontrol('Parent', mainPanel, 'Style', 'text', ...
                          'String', 'Group Settings Editor', ...
                          'Position', [10, 400, 450, 30], ...
                          'FontSize', 16, 'FontWeight', 'bold', ...
                          'HorizontalAlignment', 'center');
    
    % === File Operations Panel ===
    filePanel = uipanel('Parent', mainPanel, 'Title', 'File Operations', ...
                        'Position', [0.05, 0.85, 0.9, 0.12]);
    
    % Open Settings File
    openBtn = uicontrol('Parent', filePanel, 'Style', 'pushbutton', ...
                        'String', 'Open Settings File', ...
                        'Position', [10, 20, 120, 25], ...
                        'Callback', @openSettingsFile);
    
    % Current File Info
    currentFileText = uicontrol('Parent', filePanel, 'Style', 'text', ...
                                'String', ['Current: ' projectName '.stn'], ...
                                'Position', [140, 20, 300, 25], ...
                                'HorizontalAlignment', 'left', ...
                                'FontSize', 9);
    
    % === Display Settings ===
    displayPanel = uipanel('Parent', mainPanel, 'Title', 'Display Settings', ...
                           'Position', [0.05, 0.65, 0.9, 0.18]);
    
    % Sampling Rate
    uicontrol('Parent', displayPanel, 'Style', 'text', ...
              'String', 'Sampling Rate (Hz):', ...
              'Position', [10, 50, 150, 20], ...
              'HorizontalAlignment', 'left');
    
    newFsEdit = uicontrol('Parent', displayPanel, 'Style', 'edit', ...
                          'String', num2str(currentSettings.newFs), ...
                          'Position', [170, 50, 100, 25], ...
                          'HorizontalAlignment', 'center');
    
    % Channel Shift
    uicontrol('Parent', displayPanel, 'Style', 'text', ...
              'String', 'Channel Shift:', ...
              'Position', [10, 20, 150, 20], ...
              'HorizontalAlignment', 'left');
    
    shiftCoeffEdit = uicontrol('Parent', displayPanel, 'Style', 'edit', ...
                               'String', num2str(currentSettings.shiftCoeff), ...
                               'Position', [170, 20, 100, 25], ...
                               'HorizontalAlignment', 'center');
    
    % === Time Windows ===
    timePanel = uipanel('Parent', mainPanel, 'Title', 'Time Windows', ...
                        'Position', [0.05, 0.42, 0.9, 0.18]);
    
    % Before
    uicontrol('Parent', timePanel, 'Style', 'text', ...
              'String', ['Before (' selectedUnit '):'], ...
              'Position', [10, 50, 150, 20], ...
              'HorizontalAlignment', 'left');
    
    timeBackEdit = uicontrol('Parent', timePanel, 'Style', 'edit', ...
                             'String', num2str(currentSettings.time_back * timeUnitFactor), ...
                             'Position', [170, 50, 100, 25], ...
                             'HorizontalAlignment', 'center');
    
    % After
    uicontrol('Parent', timePanel, 'Style', 'text', ...
              'String', ['After (' selectedUnit '):'], ...
              'Position', [10, 20, 150, 20], ...
              'HorizontalAlignment', 'left');
    
    timeForwardEdit = uicontrol('Parent', timePanel, 'Style', 'edit', ...
                                'String', num2str(currentSettings.time_forward * timeUnitFactor), ...
                                'Position', [170, 20, 100, 25], ...
                                'HorizontalAlignment', 'center');
    
    % === Stimulation Settings ===
    stimPanel = uipanel('Parent', mainPanel, 'Title', 'Stimulation Settings', ...
                         'Position', [0.05, 0.19, 0.9, 0.18]);
    
    % Stimulus Offset
    uicontrol('Parent', stimPanel, 'Style', 'text', ...
              'String', ['Stimulus Offset (' selectedUnit '):'], ...
              'Position', [10, 50, 150, 20], ...
              'HorizontalAlignment', 'left');
    
    stimOffsetEdit = uicontrol('Parent', stimPanel, 'Style', 'edit', ...
                               'String', num2str(currentSettings.stim_offset * timeUnitFactor), ...
                               'Position', [170, 50, 100, 25], ...
                               'HorizontalAlignment', 'center');
    
    % === Buttons ===
    buttonPanel = uipanel('Parent', mainPanel, 'Position', [0.05, 0.05, 0.9, 0.12]);
    
    % Apply & Save to Current Project
    applySaveBtn = uicontrol('Parent', buttonPanel, 'Style', 'pushbutton', ...
                             'String', 'Apply & Save', ...
                             'Position', [10, 40, 150, 30], ...
                             'Callback', @applyAndSave);
    
    % Reset to Defaults
    resetBtn = uicontrol('Parent', buttonPanel, 'Style', 'pushbutton', ...
                         'String', 'Reset to Defaults', ...
                         'Position', [10, 10, 150, 30], ...
                         'Callback', @resetToDefaults);
    
    % Close
    closeBtn = uicontrol('Parent', buttonPanel, 'Style', 'pushbutton', ...
                         'String', 'Close', ...
                         'Position', [170, 10, 150, 30], ...
                         'Callback', @closeWindow);
    
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
                    mainFig = findobj('Tag', 'EasyViewer');
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
                    
                    msgbox(['Settings loaded from: ' fileName], 'Success', 'help');
                else
                    errordlg('Could not load settings from the selected file', 'Load Error');
                end
            end
            
        catch ME
            errordlg(['Error opening settings file: ' ME.message], 'Error');
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
            
            % Применяем к глобальным переменным (уже объявлены в основной функции)
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
            
            % Обновляем UI элементы в основном окне для синхронизации с новыми настройками
            % Получаем ссылки на UI элементы из основного окна
            mainFig = findobj('Tag', 'EasyViewer');
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
            
            % Показываем сообщение об успехе
            msgbox('Settings applied and saved to current project successfully!', 'Success', 'help');
            
        catch ME
            errordlg(['Error applying and saving settings: ' ME.message], 'Error');
        end
    end
    
    function resetToDefaults(~, ~)
        % Сбрасывает настройки к значениям по умолчанию
        choice = questdlg('Reset all settings to default values?', ...
                          'Reset to Defaults', 'Yes', 'No', 'No');
        if strcmp(choice, 'Yes')
            % numChannels и Fs уже объявлены в основной функции
            [newFs_def, shiftCoeff_def, time_back_def, time_forward_def, stim_offset_def] = setDefaultGroupSettings(numChannels, Fs);
            
            % Обновляем поля в редакторе
            set(newFsEdit, 'String', num2str(newFs_def));
            set(shiftCoeffEdit, 'String', num2str(shiftCoeff_def));
            set(timeBackEdit, 'String', num2str(time_back_def * timeUnitFactor));
            set(timeForwardEdit, 'String', num2str(time_forward_def * timeUnitFactor));
            set(stimOffsetEdit, 'String', num2str(stim_offset_def * timeUnitFactor));
            
            % Обновляем глобальные переменные
            newFs = newFs_def;
            shiftCoeff = shiftCoeff_def;
            time_back = time_back_def;
            time_forward = time_forward_def;
            stim_offset = stim_offset_def;
            
            % Применяем сдвиг времен стимулов
            applyStimulusOffset();
            
            % Обновляем UI элементы в основном окне
            mainFig = findobj('Tag', 'EasyViewer');
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
            
            % Обновляем основной интерфейс
            updateMainInterface();
            
            msgbox('Settings reset to default values', 'Reset Complete', 'help');
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
end