function EasyView()

    
    EV_version = '1.08.01';
    
    clc
    disp(['Easy Viewer version: ' EV_version])
    
    EV_path = pwd;
    disp('working directory:')
    fprintf('%s\n',EV_path);
    disp('wait ...')
    
    global Fs N time chosen_time_interval ch_inxs m_coef
    global shiftCoeff eventTable
    global lfp hd spks multiax lineCoefficients
    global channelNames numChannels channelEnabled scalingCoefficients tableData
    global matFilePath channelSettingsFilePath
    global timeUnitFactor selectedUnit
    global initialDir
    global events event_inx events_exist event_comments
    global stims stim_inx stims_exist
    global lastOpenedFiles
    global updatedData
    global zavp newFs selectedCenter
    global time_back time_forward
    global figure_position timeForwardEdit
    global std_coef show_spikes binsize show_CSD % спайки/CSD
    global ch_labels_l colors_in_l  widths_in_l
    global add_event_settings
    global mean_group_ch timeSlider menu_visible csd_avaliable filter_avaliable filterSettings
    global channelTable 
    global data_loaded
    global SettingsFilepath
    global csd_smooth_coef csd_contrast_coef
    global autodetection_settings
    
    csd_contrast_coef = 99.9;
    
    data_loaded = false;
    menu_visible = false;
    file_menu_visible = false;
    view_menu_visible = false;
    
    binsize = 0.001;%s
    show_spikes = false;
    show_CSD = false;
    std_coef = 0;
    time_back = 1;
    time_forward = 1;
    
    stims = [];
    stim_inx = 1;
    
    events = [];
    event_inx = 1;
    event_comments = {};
    
    min_scale_coef = 0.8;
    base_figure_position = [20 60 1280 650]*min_scale_coef;

    % Загрузка списка последних файлов
    SettingsFilepath = fullfile(tempdir, 'last_opened_files_1.06.mat');
    loadLastOpenedFiles()
    function loadLastOpenedFiles()
        if exist(SettingsFilepath, 'file')
            d = load(SettingsFilepath);
            lastOpenedFiles = d.lastOpenedFiles;
            figure_position = d.figure_position;
            % настройки добавления события
            if isfield(d, 'add_event_settings')
                add_event_settings = d.add_event_settings;
            end
            % глобальные настройки единиц времени
            if isfield(d, 'timeUnitFactor')
                timeUnitFactor = d.timeUnitFactor;
                selectedUnit = d.selectedUnit;
            else
                timeUnitFactor = 1;    
                selectedUnit = 's';
            end            
            % глобальные настройки автодетекции
            if isfield(d, 'autodetection_settings')
                autodetection_settings = d.autodetection_settings;
            else
                autodetection_settings = [];
            end

        else
            % Инициализация всех переменных при первом запуске
            lastOpenedFiles = {};
            figure_position = base_figure_position;            
            add_event_settings.mode = 'manual';
            add_event_settings.channel = 11;
            add_event_settings.polarity = 'positive';
            add_event_settings.timeWindow = 10;
            timeUnitFactor = 1;    
            selectedUnit = 's';
            save(SettingsFilepath, 'lastOpenedFiles', 'figure_position', 'add_event_settings');
        end
        
    end

    % координаты графических элементов
    
    
    scaleX = figure_position(3) / base_figure_position(3);
    scaleY = figure_position(4) / base_figure_position(4);
    scaling_matrix = [scaleX, scaleY, scaleX, scaleY];
    
    file_menu_coords = [3, 528, 150, 100].*scaling_matrix*min_scale_coef;
    file_btn_coords = [3, 628, 150, 20].*scaling_matrix*min_scale_coef;    
    
    view_menu_coords = [153, 528, 150, 100].*scaling_matrix*min_scale_coef;
    view_btn_coords = [153, 628, 150, 20].*scaling_matrix*min_scale_coef;
    
    opt_menu_coords = [303, 528, 150, 100].*scaling_matrix*min_scale_coef;
    option_btn_coords = [303, 628, 150, 20].*scaling_matrix*min_scale_coef;
    
    % Side panel
    channelTable_coords = [10, 27, 300, 370].*scaling_matrix*min_scale_coef;
    LoadSettingsBtn_coords = [10, 5, 120, 20].*scaling_matrix*min_scale_coef;
    
    % Event panel
    EventsText_coords = [10, 177, 100, 20].*scaling_matrix*min_scale_coef;
    saveEventsBtn_coords = [270, 140, 70, 30].*scaling_matrix*min_scale_coef;
    loadEventsBtn_coords = [270, 110, 70, 30].*scaling_matrix*min_scale_coef;
    eventAdd_coords = [10, 10, 80, 30].*scaling_matrix*min_scale_coef;
    eventDeleteEdit_coords = [100, 10, 50, 30].*scaling_matrix*min_scale_coef;
    eventTable_coords = [10, 50, 250, 127].*scaling_matrix*min_scale_coef;    
    meanEventsWindowEdit_coords = [285, 48, 40, 20].*scaling_matrix*min_scale_coef;
    meanEventsWindowText_coords = [265, 60, 80, 20].*scaling_matrix*min_scale_coef;    
    MeanEventsBtn_coords = [270, 80, 70, 30].*scaling_matrix*min_scale_coef;    
    clearTableBtn_coords = [270, 10, 70, 30].*scaling_matrix*min_scale_coef;
    AutoEventDetectionBtn_coords = [220, 178, 120, 20].*scaling_matrix*min_scale_coef;    
    DeleteEventBtn_coords = [150, 10, 80, 30].*scaling_matrix*min_scale_coef;
    
    timeSlider_coords = [300, 50, 220, 15].*scaling_matrix*min_scale_coef;
    timeUnitPopup_coords = [540, 35, 50, 30].*scaling_matrix*min_scale_coef;
    timeCenterPopup_coords = [540, 10, 50, 30].*scaling_matrix*min_scale_coef;
    FMbutton_coords = [10, 10, 120, 30].*scaling_matrix*min_scale_coef;
    timeBackEdit_coords = [165, 10, 50, 30].*scaling_matrix*min_scale_coef;
    timeForwardEdit_coords = [220, 10, 50, 30].*scaling_matrix*min_scale_coef;
    stdCoefEdit_coords = [775, 10, 50, 30].*scaling_matrix*min_scale_coef;
    showSpikesButton_coords = [775, 45, 50, 30].*scaling_matrix*min_scale_coef;
    showCSDbutton_coords = [720, 45, 50, 30].*scaling_matrix*min_scale_coef;
    previousbutton_coords = [305, 10, 100, 30].*scaling_matrix*min_scale_coef;
    nextbutton_coords = [415, 10, 100, 30].*scaling_matrix*min_scale_coef;
    
    shiftCoeffEdit_coords = [650, 10, 50, 30].*scaling_matrix*min_scale_coef;
    FsCoeffEdit_coords = [650, 50, 50, 30].*scaling_matrix*min_scale_coef;
    FsText_coords = [600, 43, 80, 30].*scaling_matrix*min_scale_coef;
    shiftCoefText_coords = [598, 3, 60, 30].*scaling_matrix*min_scale_coef;
    stdCoefText_coords = [708, 4, 80, 30].*scaling_matrix*min_scale_coef;
    
    LoadMatFileBtn_coords = [10, 40, 120, 30].*scaling_matrix*min_scale_coef;
    TimeWindowText_coords = [165, 42, 100, 30].*scaling_matrix*min_scale_coef;
    BeforeText_coords = [165, 27, 50, 30].*scaling_matrix*min_scale_coef;
    AfterText_coords = [220, 27, 50, 30].*scaling_matrix*min_scale_coef;
        
    function saveSettings()
        figure_position = f.Position;
        save(SettingsFilepath, 'lastOpenedFiles', 'figure_position', 'add_event_settings', '-append');
    end

    
    
    % Создание таймера
    timer('TimerFcn', @resetParametersCallback, 'StartDelay', 1, 'ExecutionMode', 'singleShot');
    
    % Создание фигуры и панелей
    f = figure('Name', 'LFP Data Viewer', ...
           'NumberTitle', 'off',...
           'MenuBar', 'none', ... % Отключение стандартного меню
           'ToolBar', 'none', ...
           'KeyPressFcn', @keyPressFunction);
    
    
    f.Position = figure_position;           
    
    mainPanel = uipanel('Parent', f, 'Position', [.01 .01 .7 .13]);
    multiax_position_a = [0.07    0.2    0.63    0.74];
    multiax_position_b = [0.07    0.2    0.9    0.74];
    multiax = axes('Position', multiax_position_a);
    
    sidePanel = uipanel('Parent', f, 'Position', [.72 .33 .27 .63]);
    
    % боковая панель видна по умолчанию
    side_panel_visible = true;
    set(sidePanel, 'Visible', 'on');
 
    % Подготовка данных для таблицы каналов
    channelNames = {'Ch1'};
    numChannels = length(channelNames);
    channelEnabled = true(numChannels, 1); % Все каналы активированы по умолчанию
    scalingCoefficients = ones(numChannels, 1); % Коэффициенты масштабирования по умолчанию
    colorsIn = repmat({'black'}, numChannels, 1); % Инициализация цветов
    lineCoefficients = ones(numChannels, 1)*0.1; % Инициализация толщины линий

    tableData = [channelNames, num2cell(channelEnabled), num2cell(scalingCoefficients), colorsIn, num2cell(lineCoefficients)];

    % Создание таблицы каналов в GUI
    channelTable = uitable('Parent', sidePanel, ...
                           'Data', tableData, ...
                           'ColumnName', {'Channel', 'Enabled', 'Scale', 'Color', 'Line Width'}, ...
                           'ColumnFormat', {'char', 'logical', 'numeric', 'char', 'numeric'}, ...
                           'ColumnEditable', [false true true true true], ...
                           'Position', channelTable_coords);
        % Кнопка для загрузки настроек    
    LoadSettingsBtn = uicontrol('Parent', sidePanel, 'Style', 'pushbutton', 'String', 'Load Channel Settings', 'Position', LoadSettingsBtn_coords, 'Callback', @loadSettings);
    
    % Панель событий                   
    event_panel_position_a = [.72 .01 .27 .31];
    eventPanel = uipanel('Parent', f, 'Position', event_panel_position_a);
    
    set(f, 'SizeChangedFcn', @resizeComponents);
    % Настройка обработчика закрытия для фигуры
    set(f, 'CloseRequestFcn', @(src, event)closeAllCallback(src, event));
        
    % multiax не видим при запуске
    set(multiax, 'Visible', 'off')
    text(multiax, 0.5, 0.5, 'Open MAT or EV file', 'color', 'r', 'horizontalalignment', 'center')
    
    % Добавление текстовой метки как заголовка к sidePanel
    EventsText = uicontrol('Parent', eventPanel, 'Style', 'text', 'String', 'Events', ...
              'Position', EventsText_coords, ...
              'HorizontalAlignment', 'left', ...
              'FontWeight', 'bold'); % Жирный шрифт для заголовка
      
    % Добавление слайдера для времени
    timeSlider = uicontrol('Parent', mainPanel, 'Style', 'slider', 'Position', timeSlider_coords, 'Min', 0, 'Max', 1, 'Value', 0, 'Callback', @timeSliderCallback);

    % Добавление выпадающего списка для выбора единиц времени
    units = {'s', 'ms', 'min'};
    timeUnitPopup = uicontrol('Parent', mainPanel, 'Style', 'popup', 'String', units, 'Position', timeUnitPopup_coords, 'Callback', @changeTimeUnit);
    index = find(strcmp(units, selectedUnit));
    set(timeUnitPopup, 'Value', index);

    % Добавление выпадающего списка для выбора режима просмотра
    timeCenterPopup = uicontrol('Parent', mainPanel, 'Style', 'popup', 'String', {'time', 'stimulus', 'event'}, 'Position', timeCenterPopup_coords, 'Callback', @changeTimeCenter);

    % Кнопка для загрузки .mat файла
    LoadMatFileBtn = uicontrol('Parent', mainPanel, 'Style', 'pushbutton', 'String', 'Load .mat File (ZAV Format)', 'Position', LoadMatFileBtn_coords, 'Callback', @OpenZavLfpFile);
       
    % Кнопка для менеджера файлов
    FMbutton = uicontrol('Parent', mainPanel, 'Style', 'pushbutton', 'String', 'File Manager', 'Position', FMbutton_coords, 'Callback', @fileManagerBtnClb);

    % Поля для выбора временного окна
    TimeWindowText = uicontrol('Parent', mainPanel, 'Style', 'text', 'String', ['Time Window, ' selectedUnit ':'] , 'Position', TimeWindowText_coords);
    BeforeText = uicontrol('Parent', mainPanel, 'Style', 'text', 'String', 'before', 'Position', BeforeText_coords);
    AfterText = uicontrol('Parent', mainPanel, 'Style', 'text', 'String', 'after', 'Position', AfterText_coords);
    timeBackEdit = uicontrol('Parent', mainPanel, 'Style', 'edit', 'String', num2str(time_back*timeUnitFactor), 'Position', timeBackEdit_coords, 'Callback', @timeBackEditCallback);
    timeForwardEdit = uicontrol('Parent', mainPanel, 'Style', 'edit', 'String', num2str(time_forward*timeUnitFactor), 'Position', timeForwardEdit_coords, 'Callback', @timeForwardEditCallback);

    % Spikes
    % STD
    stdCoefText = uicontrol('Parent', mainPanel, 'Style', 'text', 'String', 'MUA coef:', 'Position', stdCoefText_coords);
    stdCoefEdit = uicontrol('Parent', mainPanel, 'Style', 'edit', 'String', num2str(std_coef), 'Position', stdCoefEdit_coords, 'Callback', @StdCoefCallback);
    showSpikesButton = uicontrol('Parent', mainPanel, 'Style', 'checkbox', 'String', 'MUA', 'Position', showSpikesButton_coords, 'Callback', @ShowSpikesButtonCallback);
    showCSDbutton = uicontrol('Parent', mainPanel, 'Style', 'checkbox', 'String', 'CSD', 'Position', showCSDbutton_coords, 'Callback', @ShowCSDButtonCallback);

    % Кнопки для навигации по времени
    previousbutton = uicontrol('Parent', mainPanel, 'Style', 'pushbutton', 'String', 'Previous', 'Position', previousbutton_coords, 'Callback', {@shiftTime, -1, timeForwardEdit});
    nextbutton = uicontrol('Parent', mainPanel, 'Style', 'pushbutton', 'String', 'Next', 'Position', nextbutton_coords, 'Callback', {@shiftTime, 1, timeForwardEdit});

    % Окошко для выбора размера shiftCoeff
    shiftCoefText = uicontrol('Parent', mainPanel, 'Style', 'text', 'String', 'Ch. Shift:', 'Position', shiftCoefText_coords);
    shiftCoeffEdit = uicontrol('Parent', mainPanel, 'Style', 'edit', 'String', '200', 'Position', shiftCoeffEdit_coords, 'Callback', @shiftCoeffEditCallback);

    % Окошко для выбора частоты дискретизации
    FsText = uicontrol('Parent', mainPanel, 'Style', 'text', 'String', 'Fs:', 'Position', FsText_coords);
    FsCoeffEdit = uicontrol('Parent', mainPanel, 'Style', 'edit', 'String', '1000', 'Position', FsCoeffEdit_coords, 'Callback', @FsCoeffEditCallback);
    
    
    % Список действий
    file_functions = {'open ZAV(.mat) file', ...
        'open event (.ev) file',...
        '', ...
        'file manager', ...
        '', ...
        'convert NLX to ZAV', ...
        '', ...
        'compare average data', ...
        '',...
        'check for a new version'};
        
    % Создание выпадающего списка
    file_menu = uicontrol('Style', 'listbox',...
        'String', file_functions,...
        'Visible', 'off', ...
        'Position', file_menu_coords,...
        'Callback', @FileMenuSelectionCallback);
    
    % Создание кнопки для активации выпадающего списка
    fileBtn = uicontrol('Style', 'pushbutton', 'String', 'File',...
        'Visible', 'on', ...
        'Position', file_btn_coords,...
        'Callback', @showFileMenu);
                
    view_functions = {'close all windows', ...
        '', ...
        'hide Channel Settings'};
          
    % Создание выпадающего списка
    view_menu = uicontrol('Style', 'listbox',...
        'String', view_functions,...
        'Visible', 'off', ...
        'Position', view_menu_coords,...
        'Callback', @ViewMenuSelectionCallback);
    
    % Создание кнопки для активации выпадающего списка
    viewBtn = uicontrol('Style', 'pushbutton', 'String', 'View',...
        'Visible', 'on', ...
        'Position', view_btn_coords,...
        'Callback', @showViewMenu);          
                
    % Список настроек
    options = {'Event Creation',...
        'Auto Event Detection',...
        '',...
        'Filtering', ...
        'CSD Displaying', ...
        'Average subtraction', ...
        '',...
        'Spectral Density'};    
   
    % Создание выпадающего списка
    opt_menu = uicontrol('Style', 'listbox',...
              'String', options,...
              'Visible', 'off', ...
              'Position', opt_menu_coords,...
              'Callback', @OptionsSelectionCallback);
    % Создание кнопки для активации выпадающего списка
    OptBtn = uicontrol('Style', 'pushbutton', 'String', 'Options',...
                    'Visible', 'on', ...
                    'Position', option_btn_coords + [0, 0, 0, 0],...
                    'Callback', @showMenu);

    
    % Таблица для отображения событий
    event_table_data = [num2cell([]), num2cell([])];    
    eventTable = uitable('Parent', eventPanel, ...
                     'Position', eventTable_coords, ...
                     'ColumnName', {'Time', 'Comment'}, ...
                     'ColumnFormat', {'bank', 'char'}, ... % Формат для отображения чисел
                     'Data', event_table_data, ...
                     'ColumnEditable', [false true]);
                 
    % Автоматический детектор событий
    AutoEventDetectionBtn = uicontrol('Parent', eventPanel,'Style', 'pushbutton', 'String', 'Auto Event Detection',...
        'Position', AutoEventDetectionBtn_coords, 'Callback', @openAutoEventDetectionWindow);
    
    % Кнопки и поля для управления событиями    
    DeleteEventBtn = uicontrol('Parent', eventPanel, 'Style', 'pushbutton', 'String', 'Delete Event', 'Position', DeleteEventBtn_coords, 'Callback', @deleteEvent);
    eventDeleteEdit = uicontrol('Parent', eventPanel, 'Style', 'edit', 'Position', eventDeleteEdit_coords);

    % Clear Table
    clearTableBtn = uicontrol('Parent', eventPanel, 'Style', 'pushbutton', 'String', 'Clear Table', 'Position', clearTableBtn_coords, 'Callback', @clearTable);
    
    % Add event
    eventAdd = uicontrol('Parent', eventPanel, 'Style', 'pushbutton', 'String', 'Add Event', 'Position', eventAdd_coords, 'Callback', @addEvent);

    % Кнопка для сохранения событий
    saveEventsBtn = uicontrol('Parent', eventPanel, 'Style', 'pushbutton', 'String', 'Save Events', 'Position', saveEventsBtn_coords, 'Callback', @saveEvents);

    % Кнопка для загрузки событий
    loadEventsBtn = uicontrol('Parent', eventPanel, 'Style', 'pushbutton', 'String', 'Load Events', 'Position', loadEventsBtn_coords, 'Callback', @loadEvents);

    % Кнопка и окно ввода для 'Mean Events'
    MeanEventsBtn = uicontrol('Parent', eventPanel, 'Style', 'pushbutton', 'String', 'Mean Events', 'Position', MeanEventsBtn_coords, 'Callback', @meanEventsCallback);
    meanEventsWindowText = uicontrol('Parent', eventPanel, 'Style', 'text', 'String', 'Window(+/-, s):', 'Position', meanEventsWindowText_coords, 'visible', 'off');
    meanEventsWindowEdit = uicontrol('Parent', eventPanel, 'Style', 'edit', 'String', '1', 'Position', meanEventsWindowEdit_coords, 'visible', 'off'); % Окно ввода временного окна (скрыл)
    
    % отключаем все элементы управления кроме начальных
    set(OptBtn, 'Enable', 'off');
    setUIControlsEnable({eventPanel, sidePanel, mainPanel} , 'off')    
    set(LoadMatFileBtn, 'Enable', 'on');
    set(FMbutton, 'Enable', 'on');
    set(loadEventsBtn, 'Enable', 'on');
           
    f.WindowButtonDownFcn = @(src, event)ButtonDownFcn(multiax, f);
    function ButtonDownFcn(ax, fig)
        % Проверяем, зажата ли клавиша Ctrl
        modifiers = get(fig, 'CurrentModifier');
        if ismember('control', modifiers) % Если зажата Ctrl
            % Добавление интерактивного маркера при клике на график 
            addMarker(ax);
            updateMarkersDiff(ax);
            
        elseif ismember('shift', modifiers) % Если зажата Ctrl
            % Добавление события
            addEvent(eventAdd);
        end
    end
    
    % Функция для добавления маркера
    function marker = addMarker(ax)
%         global hT
        % Получение координат клика
        cp = ax.CurrentPoint;
        x = cp(1,1);
        
        % Добавление вертикальной линии
        marker = line(ax, [x x], ylim, 'Color', 'r', 'LineWidth', 2, 'Tag', 'Draggable');
        
        % Добавление текста с временем
        hT = text(x, ax.YLim(2), sprintf('%.2f', x), 'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'center');
        
        % Добавление обработчика для перетаскивания
        draggable(ax, marker, hT, 'h');
    end
    
%     resizeComponents();
    % Функция, вызываемая при закрытии фигуры
    function closeAllCallback(src, ~)
        % Закрытие всех фигур
        clear global
        closeAllButOne(src)
        delete(src);
    end

    function closeAllButOne(targetFigure)
        % Получаем массив всех текущих фигур
        figures = findobj(allchild(0), 'flat', 'Type', 'figure');
        % Перебираем все фигуры и закрываем те, которые не совпадают с целевой
        for i = 1:length(figures)
            if figures(i) ~= targetFigure
                close(figures(i));
            end
        end
    end

    % Callback для сброса параметров
    function resetParametersCallback(~, ~)
        try
            resetGraphParameters()
        catch
            disp('')
        end
    end

    % Функция для сброса графических параметров
    function resetGraphParameters()
        try
        % Код для сброса параметров здесь
        set(opt_menu, 'Visible', 'off'); % Скрыть меню
        menu_visible = false;
        
        set(file_menu, 'Visible', 'off'); % Скрыть меню
        file_menu_visible = false;
        
        set(view_menu, 'Visible', 'off'); % Скрыть меню
        view_menu_visible = false;
        catch
            disp('bravo 5')
        end
    end

    % Обратный вызов выпадающего списка
    function FileMenuSelectionCallback(src, ~)
        val = src.Value;
        str = src.String;
        selectedOption = str{val};
        dont_close_menu = false;
        switch selectedOption
            case file_functions{1}
                % загрузка файла
                OpenZavLfpFile([], []);
            case file_functions{2}
                % загрузка события
                loadEvents([], []);
            case file_functions{4}
                % открытие менеджера файлов
                fileManagerBtnClb([], []);
            case file_functions{6}
                % конвертация в ZAV формат
                convertNlx2zavGUI();
            case file_functions{8}
                % сравнение средних данных
                dataComparerApp();
            case file_functions{10}
                updateAndRunInstaller();
            case ''
                dont_close_menu = true;
        end
        disp(selectedOption);
        if ~dont_close_menu
            resetGraphParameters()
        end
    end

    % Обратный вызов выпадающего списка
    function ViewMenuSelectionCallback(src, ~)
        val = src.Value;
        str = src.String;
        selectedOption = str{val};
        dont_close_menu = false;
        switch selectedOption
            case view_functions{1}
                % закрыть все окна кроме основного
                closeAllButOne(f);
            case view_functions{3}
                % показывать или скрывать боковую панель
                showHideSidePanel();
            case ''
            dont_close_menu = true;
        end
        disp(selectedOption);
        if ~dont_close_menu
            resetGraphParameters()
        end
    end
    % Обратный вызов выпадающего списка
    function OptionsSelectionCallback(src, ~)
        val = src.Value;
        str = src.String;
        selectedOption = str{val};
        dont_close_menu = false;
        switch selectedOption
            case options{1}% Add event options
                addEventSettingsUicontrol();
            case options{2}% Auto event detection
                openAutoEventDetectionWindow();
            case options{4}%'Filtering ...'
                setupSignalFilteringGUI();
            case options{5}%'CSD ...'
                % вызов функции для CSD ...
                CSDfigSettings();
            case options{6} %'Subtract mean ...'
                % вызов функции для Subtract mean ...
                SubMeanFigSettings();
            case options{8}
                % отображение спектральной плотности текущего сигнала
                spectralDensityGUI();  
            case ''
            dont_close_menu = true;
        end
        disp(selectedOption);
        if ~dont_close_menu
            resetGraphParameters()
        end
    end
    
    % вызов файл-менеджера
    function fileManagerBtnClb(~, ~)
        fileManagerGUI();
    end
    
    function showHideSidePanel()
        
        if side_panel_visible
            disp('Hiding Side Panel')
            set(sidePanel, 'Visible', 'off');
            set(multiax,'Position', multiax_position_b);
            str_out = 'view Channel Settings';
            resizeUIControls(eventPanel, 1, 0.5);
        else
            disp('Showing Side Panel')
            set(sidePanel, 'Visible', 'on');            
            set(multiax,'Position', multiax_position_a);
            str_out = 'hide Channel Settings';
            resizeUIControls(eventPanel, 1, 1/0.5);
        end
        
        view_functions{3} = str_out;
        set(view_menu, 'String', view_functions);
            
        side_panel_visible = ~side_panel_visible;
    end

    function showSidePanel()
        if ~side_panel_visible
            disp('Showing Side Panel')
            set(sidePanel, 'Visible', 'on');            
            set(multiax,'Position', multiax_position_a);
            str_out = 'hide Channel Settings';

            view_functions{3} = str_out;
            set(view_menu, 'String', view_functions);

            resizeUIControls(eventPanel, 1, 1/0.5);
            side_panel_visible = true;
        end
    end


    function resizeUIControls(panelHandle, scaleX, scaleY)
        % Находим все uicontrols и uitable внутри указанной панели
        controls = findall(panelHandle, 'Type', 'uicontrol');
        controls = [controls; findall(panelHandle, 'Type', 'uitable')];

        % Перебираем каждый элемент управления для изменения размера
        for i = 1:length(controls)
            control = controls(i);

            % Получаем текущее положение элемента управления
            currentPosition = get(control, 'Position');

            % Масштабируем положение согласно заданным коэффициентам
            newPosition = [currentPosition(1) * scaleX, currentPosition(2) * scaleY, ...
                           currentPosition(3) * scaleX, currentPosition(4) * scaleY];

            % Применяем новое положение элемента управления
            set(control, 'Position', newPosition);
        end

        % Получаем и изменяем размер самой панели
        panelPosition = get(panelHandle, 'Position');
        newPanelPosition = [panelPosition(1) * scaleX, panelPosition(2) * scaleY, ...
                            panelPosition(3) * scaleX, panelPosition(4) * scaleY];
        set(panelHandle, 'Position', newPanelPosition);
    end



    % Функция обратного вызова для кнопки
    function showFileMenu(~, ~)
        if file_menu_visible
            set(file_menu, 'Visible', 'off'); % Убрать меню
        else
            set(file_menu, 'Visible', 'on'); % Показать меню
        end
        file_menu_visible = not(file_menu_visible);
    end
    
    % Функция обратного вызова для кнопки
    function showViewMenu(~, ~)
        if view_menu_visible
            set(view_menu, 'Visible', 'off'); % Убрать меню
        else
            set(view_menu, 'Visible', 'on'); % Показать меню
        end
        view_menu_visible = not(view_menu_visible);
    end
    
    % Функция обратного вызова для кнопки
    function showMenu(~, ~)
        if menu_visible
            set(opt_menu, 'Visible', 'off'); % Убрать меню
        else
            set(opt_menu, 'Visible', 'on'); % Показать меню   
        end
        menu_visible = not(menu_visible);
    end

    function resizeComponents(~, ~)
        
        % сбрасываем изменения боковой панели
        showSidePanel();
        
        % Получение текущего размера фигуры
        pos = get(f, 'Position');
        scaleX = pos(3) / figure_position(3);
        scaleY = pos(4) / figure_position(4);
        scaling_matrix = [scaleX, scaleY, scaleX, scaleY];

        set(OptBtn, 'Position', option_btn_coords .*scaling_matrix);
        set(opt_menu, 'Position', opt_menu_coords .*scaling_matrix);
        set(file_menu, 'Position', file_menu_coords .*scaling_matrix);
        set(view_menu, 'Position', view_menu_coords .*scaling_matrix);
        set(fileBtn, 'Position', file_btn_coords .*scaling_matrix);        
        set(viewBtn, 'Position', view_btn_coords .*scaling_matrix);
        set(saveEventsBtn, 'Position', saveEventsBtn_coords .* scaling_matrix);
        set(loadEventsBtn, 'Position', loadEventsBtn_coords .* scaling_matrix);
        set(eventAdd, 'Position', eventAdd_coords .* scaling_matrix);
        set(channelTable, 'Position', channelTable_coords .* scaling_matrix);
        set(timeSlider, 'Position', timeSlider_coords .* scaling_matrix);
        set(timeUnitPopup, 'Position', timeUnitPopup_coords .* scaling_matrix);
        set(timeCenterPopup, 'Position', timeCenterPopup_coords .* scaling_matrix);
        set(FMbutton, 'Position', FMbutton_coords .* scaling_matrix);
        set(timeBackEdit, 'Position', timeBackEdit_coords .* scaling_matrix);
        set(timeForwardEdit, 'Position', timeForwardEdit_coords .* scaling_matrix);
        set(stdCoefEdit, 'Position', stdCoefEdit_coords .* scaling_matrix);
        set(showSpikesButton, 'Position', showSpikesButton_coords .* scaling_matrix);
        set(showCSDbutton, 'Position', showCSDbutton_coords .* scaling_matrix);
        set(previousbutton, 'Position', previousbutton_coords .* scaling_matrix);
        set(nextbutton, 'Position', nextbutton_coords .* scaling_matrix);
        set(eventTable, 'Position', eventTable_coords .* scaling_matrix);
        set(LoadSettingsBtn, 'Position', LoadSettingsBtn_coords .* scaling_matrix);
        set(eventDeleteEdit, 'Position', eventDeleteEdit_coords .* scaling_matrix);
        set(shiftCoeffEdit, 'Position', shiftCoeffEdit_coords .* scaling_matrix);
        set(FsCoeffEdit, 'Position', FsCoeffEdit_coords .* scaling_matrix);
        set(meanEventsWindowEdit, 'Position', meanEventsWindowEdit_coords .* scaling_matrix);
        set(meanEventsWindowText, 'Position', meanEventsWindowText_coords .* scaling_matrix);
        set(clearTableBtn, 'Position', clearTableBtn_coords .* scaling_matrix);
        set(MeanEventsBtn, 'Position', MeanEventsBtn_coords .* scaling_matrix);
        set(AutoEventDetectionBtn, 'Position', AutoEventDetectionBtn_coords .* scaling_matrix);        
        set(DeleteEventBtn, 'Position', DeleteEventBtn_coords .* scaling_matrix);
        set(FsText, 'Position', FsText_coords .* scaling_matrix);
        set(shiftCoefText, 'Position', shiftCoefText_coords .* scaling_matrix);
        set(stdCoefText, 'Position', stdCoefText_coords .* scaling_matrix);
        set(EventsText, 'Position', EventsText_coords .* scaling_matrix);
        set(LoadMatFileBtn, 'Position', LoadMatFileBtn_coords .* scaling_matrix);
        set(TimeWindowText, 'Position', TimeWindowText_coords .* scaling_matrix);
        set(BeforeText, 'Position', BeforeText_coords .* scaling_matrix);
        set(AfterText, 'Position', AfterText_coords .* scaling_matrix);
    end


    function openAutoEventDetectionWindow(~, ~)
        openAutoEventDetection();
    end
        
    % Функция обработки нажатия клавиш
    function keyPressFunction(src, event)
%         disp(event.Key)
        switch event.Key            
            case 'leftarrow'
                shiftTime(src, [], -1, timeForwardEdit); % Или вызов Callback функции previousButton
            case 'rightarrow'
                shiftTime(src, [], 1, timeForwardEdit); % Или вызов Callback функции nextButton
        end
    end

    function meanEventsCallback(~, ~)
        meanWindow = str2double(get(meanEventsWindowEdit, 'String'));
        if isnan(meanWindow) || meanWindow <= 0
            errordlg('Invalid Mean Window Value');
            return;
        end
        calculateAndPlotMeanEvents(meanWindow);
    end

    


    function shiftCoeffEditCallback(src, ~)
        newShiftCoeff = str2double(get(src, 'String'));
        if isnan(newShiftCoeff) || newShiftCoeff <= 0
            errordlg('Invalid Shift Coeff Value');
            return;
        end
        shiftCoeff = newShiftCoeff;
        saveChannelSettings();
        updatePlot(); % Обновление графика с новым shiftCoeff
    end

    function FsCoeffEditCallback(src, ~)
        newFsCoeff = str2double(get(src, 'String'));
        if isnan(newFsCoeff) || newFsCoeff <= 0
            errordlg('Invalid Fs Value');
            return;
        end
        newFs = newFsCoeff;
        saveChannelSettings();
        updatePlot(); % Обновление графика с новым shiftCoeff
    end
    
    % std coef
    function StdCoefCallback(src, ~)
        std_coef = str2double(get(src, 'String'));
        updatePlot(); % Обновление графика
    end
    function ShowSpikesButtonCallback(~, ~)
        show_spikes = not(show_spikes);
        set(showSpikesButton, 'Value', show_spikes);
        updatePlot(); % Обновление графика
    end

    function ShowCSDButtonCallback(~, ~)
        show_CSD = not(show_CSD);
        set(showCSDbutton, 'Value', show_CSD);
        updatePlot(); % Обновление графика
    end

    % Функция обратного вызова для timeBackEdit
    function timeBackEditCallback(src, ~)
        time_back = str2double(get(src, 'String'))/timeUnitFactor;% time_back - в секундах
        timeForwardEditCallback(timeForwardEdit);% используем функционал обратного вызова timeForwardEdit
    end
    % Функция обратного вызова для timeForwardEdit
    function timeForwardEditCallback(src, ~)
        windowSize = str2double(get(src, 'String'))/timeUnitFactor;% time_forward - в секундах
        time_forward = windowSize;
        if isnan(windowSize) || windowSize <= 0
            errordlg('Invalid time window size.');
            return;
        end
                
        switch selectedCenter
            case 'event'
                if events_exist
                    chosen_time_interval(1) = events(event_inx);
                    chosen_time_interval(2) = events(event_inx)+windowSize;
                end
            case 'stimulus'
                if stims_exist
                    chosen_time_interval(1) = stims(stim_inx);
                    chosen_time_interval(2) = stims(stim_inx)+windowSize;
                end
            case 'time'
                % Обновляем интервал времени, сохраняя начальную точку интервала
                chosen_time_interval(2) = chosen_time_interval(1) + windowSize;

                % Проверяем, не выходит ли интервал за границы временного ряда
                if chosen_time_interval(2) > time(end)
                    chosen_time_interval(2) = time(end);
                    chosen_time_interval(1) = max(time(end) - windowSize, 0);
                    set(src, 'String', num2str(windowSize*timeUnitFactor)); % Обновляем значение в поле
                end
        end
        
        saveChannelSettings();
        updatePlot(); % Обновление графика
    end

    % Функция обратного вызова для выпадающего списка
    function changeTimeUnit(src, ~)
        selectedUnit = src.String{src.Value};
        switch selectedUnit
            case 'ms'
                timeUnitFactor = 1000; % секунды в миллисекунды
            case 's'
                timeUnitFactor = 1; % секунды
            case 'min'
                timeUnitFactor = 1/60; % секунды в минуты
        end
        
        set(timeBackEdit, 'String', num2str(time_back*timeUnitFactor));
        set(timeForwardEdit, 'String', num2str(time_forward*timeUnitFactor));
        set(TimeWindowText, 'String', ['Time Window, ' selectedUnit ':']);
        
        UpdateEventTable();
        updatePlot(); % Обновление графика с новыми единицами времени
        
        % сохраняем фактор в глобальные настройки              
        save(SettingsFilepath, 'selectedUnit', 'timeUnitFactor', '-append');
    end

    function changeTimeCenter(src, ~)
        selectedCenter = src.String{src.Value};
        switch selectedCenter
            case 'time'
                nan;
            case 'stimulus'
                stim_inx = 1;
            case 'event'
                event_inx = 1;
        end
        timeForwardEditCallback(timeForwardEdit)
%         updatePlot(); % Обновление графика с новыми единицами времени
    end
    % Функция сохранения настроек каналов
    function saveChannelSettings()
%         global mean_group_ch time_back time_forward shiftCoeff newFs channelTable matFilePath
        [path, name, ~] = fileparts(matFilePath);
        channelSettingsFilePath = fullfile(path, [name '_channelSettings.stn']);
        channelSettings = get(channelTable, 'Data');
        save(channelSettingsFilePath, 'channelSettings', 'newFs', 'shiftCoeff', ...
            'time_forward', 'time_back', 'mean_group_ch', ...
            'csd_avaliable', 'filter_avaliable', 'filterSettings', ...
            'csd_smooth_coef', 'csd_contrast_coef');
    end
    
    % Функция обратного вызова слайдера
    function timeSliderCallback(src, ~)
        sliderValue = get(src, 'Value'); % Текущее значение слайдера
        windowSize = str2double(get(timeForwardEdit, 'String'))/timeUnitFactor;% должен быть в секундах;
        % Проверка на выход за границы времени
        if sliderValue + windowSize > time(end)
            sliderValue = time(end) - windowSize;
        end
        chosen_time_interval = [sliderValue, sliderValue + windowSize];
        updatePlot(); % Обновление графика
    end

    % Функция для обновления данных на основе выбора в таблице
    function updateChannelSelection(~, ~)
        % Получение данных из таблицы
        updatedData = get(channelTable, 'Data');
        ch_inxs = find([updatedData{:, 2}]); % Индексы активированных каналов
        m_coef = [updatedData{:, 3}]; % Обновленные коэффициенты масштабирования
        m_coef = m_coef(ch_inxs);
        ch_labels_l = updatedData(ch_inxs, 1)';
        colors_in_l = updatedData(ch_inxs, 4)';
        widths_in_l = [updatedData{:, 5}];
        widths_in_l = widths_in_l(ch_inxs);
        saveChannelSettings();
        updatePlot(); % Обновление графика
    end

    % Функция для обновления данных на основе выбора в таблице
    function updateEventTable(~, ~)
        % Получение данных из таблицы
        updatedEventData = get(eventTable, 'Data');
        event_comments = updatedEventData(:, 2);
    end
    
    % Внутренние функции для обработки событий GUI
    function OpenZavLfpFile(~, ~)

        % Получение пути к последнему открытому файлу или использование стандартной директории
        initialDir = pwd;
        if ~isempty(lastOpenedFiles)
            initialDir = fileparts(lastOpenedFiles{end});
        end
        
        [file, path] = uigetfile('*.mat', 'Load .mat File', initialDir);
        if isequal(file, 0)
            disp('File selection canceled.');
            return;
        end
        filepath = fullfile(path, file);
        
        loadMatFile(filepath)
        
        % Очистка таблицы событий
        events = [];
        UpdateEventTable();
        event_inx = 1;
        
        saveSettings();
        
        data_loaded = true;
    end

    function loadMatFile(filepath)
        % разрешение опций
        set(OptBtn, 'Enable', 'on');
        % если идет вызов снаружи
        if ~isempty(outside_calling_filepath)
            filepath = outside_calling_filepath;
            outside_calling_filepath = [];
        end
        
        d = load(filepath); % Загружаем данные в структуру
        spks = d.spks;
        lfp = d.lfp;
        hd = d.hd;
        Fs = d.zavp.dwnSmplFrq;
        N = size(lfp, 1);
        zavp = d.zavp;
        time = (0:N-1) / Fs;% s
        time_forward = 1;
        chosen_time_interval = [0, time_forward];
        shiftCoeff = 200;
        newFs = 1000;
        selectedCenter = 'time';
        stim_inx = 1;
        time_back = 1;
        show_spikes = false;
        show_CSD = false;
        channelNames = hd.recChNames;
        numChannels = length(channelNames);
        
        if isfield(zavp, 'realStim')
            stims = zavp.realStim(:).r(:) * zavp.siS;  
            stims_exist = ~isempty(stims);
        else
            stims = [];
            stims_exist = false;
        end
        
        set(showSpikesButton, 'Value', show_spikes);
        set(showCSDbutton, 'Value', show_CSD);
        set(timeCenterPopup, 'Value', 1);
        set(timeBackEdit, 'String', num2str(time_back*timeUnitFactor));% time window before
        set(timeForwardEdit, 'String', num2str(time_forward*timeUnitFactor));% time window after
        set(shiftCoeffEdit, 'String', num2str(shiftCoeff));
        set(FsCoeffEdit, 'String', num2str(newFs));
        
        % Сохранение пути к загруженному .mat файлу
        matFilePath = filepath;        

        % Обновление максимального значения слайдера
        set(timeSlider, 'Max', time(end));
        
        % Обновление и сохранение списка последних открытых файлов
        lastOpenedFiles{end + 1} = filepath;
        
        % Попытка загрузить настройки каналов
        loadChannelSettings();    
        
        % Включаем все элементы управления если файл загрузился в первый
        % раз
        if ~data_loaded
            setUIControlsEnable({eventPanel, sidePanel, mainPanel} , 'on')
            data_loaded = true;
        end
        
        % включаем multiax
        set(multiax, 'Visible', 'on')
    end

    function loadSettings(~, ~)
        % Определение начальной директории
        [path, name, ~] = fileparts(matFilePath);
        startPath = fullfile(path, [name '_channelSettings.stn']);

        % Открытие диалогового окна для выбора файла
        [fileName, filePath] = uigetfile('*.stn', 'Select Channel Settings File', startPath);

        % Проверка, был ли выбран файл
        if fileName ~= 0
            channelSettingsFilePath = fullfile(filePath, fileName);

            % Загрузка настроек из выбранного файла
            if isfile(channelSettingsFilePath)
                loadSettingsFile()
                updateChannelSelection();
            else
                disp('File does not exist.');
            end
        else
            disp('File selection cancelled.');
        end
    end

    % Функция загрузки настроек из файла
    function loadSettingsFile()                
            loadedSettings = load(channelSettingsFilePath, '-mat');
            if isfield(loadedSettings, 'channelSettings')
                set(channelTable, 'Data', loadedSettings.channelSettings);
            end
            if isfield(loadedSettings, 'newFs')
                newFs = loadedSettings.newFs;
                set(FsCoeffEdit, 'String', num2str(newFs));
            end
            if isfield(loadedSettings, 'shiftCoeff')
                shiftCoeff = loadedSettings.shiftCoeff;
                set(shiftCoeffEdit, 'String', num2str(shiftCoeff));
            end
            if isfield(loadedSettings, 'time_back')
                time_back = loadedSettings.time_back;% time window before (s)
                set(timeBackEdit, 'String', num2str(time_back*timeUnitFactor));
            end
            if isfield(loadedSettings, 'time_forward')
                time_forward = loadedSettings.time_forward;% time window after (s)
                chosen_time_interval = [0, time_forward];
                set(timeForwardEdit, 'String', num2str(time_forward*timeUnitFactor));
            end
            if isfield(loadedSettings, 'mean_group_ch')
                mean_group_ch = loadedSettings.mean_group_ch;
            else% если настройки старые
                mean_group_ch = false(numChannels, 1);% Ни один канал не участвует в усреднении
                disp('settings were without mean_group_ch')
            end
            if isfield(loadedSettings, 'csd_avaliable') && ~(isempty(loadedSettings.csd_avaliable))
                csd_avaliable = loadedSettings.csd_avaliable;
            else% если настройки старые                
                csd_avaliable = true(numChannels, 1);% Все каналы участвуют в CSD
                disp('settings were without csd_avaliable')
            end
            if isfield(loadedSettings, 'filter_avaliable')
                filter_avaliable = loadedSettings.filter_avaliable;
            else% если настройки старые                
                filter_avaliable = false(numChannels, 1);% Ни один канал не участвует в фильтрации
                disp('settings were without filter_avaliable')
            end            
            if isfield(loadedSettings, 'filterSettings') && ~(isempty(loadedSettings.filterSettings))
                filterSettings = loadedSettings.filterSettings;
            else% если настройки старые                
                filterSettings.filterType = 'highpass';
                filterSettings.freqLow = 10;
                filterSettings.freqHigh = 50;
                filterSettings.order = 4;
                filterSettings.channelsToFilter = false(numChannels, 1);% Ни один канал не участвует в фильтрации
                disp('settings were without filterSettings')
            end            
            if isfield(loadedSettings, 'csd_smooth_coef')
                csd_smooth_coef = loadedSettings.csd_smooth_coef;
            else
                csd_smooth_coef = 1;
                disp('settings were without CSD smooth coef')
            end
            if isfield(loadedSettings, 'csd_contrast_coef')
                csd_contrast_coef = loadedSettings.csd_contrast_coef;
            else
                csd_contrast_coef = 99.99;
                disp('settings were without CSD contrast coef')
            end
    end

    % Функция загрузки настроек каналов
    function loadChannelSettings()
        [path, name, ~] = fileparts(matFilePath);
        channelSettingsFilePath = fullfile(path, [name '_channelSettings.stn']);
        if isfile(channelSettingsFilePath)
            disp('loading Channel settings ..')
            loadSettingsFile()
            updateChannelSelection();
        else % если не было настроек
            % Подготовка данных для таблицы каналов
            
            channelEnabled = true(numChannels, 1); % Все каналы активированы по умолчанию
            scalingCoefficients = ones(numChannels, 1); % Коэффициенты масштабирования по умолчанию
            colorsIn = repmat({'black'}, numChannels, 1); % Инициализация цветов
            lineCoefficients = ones(numChannels, 1)*0.5; % Инициализация толщины линий
            mean_group_ch = false(numChannels, 1);% Ни один канал не участвует в усреднении
            csd_avaliable = true(numChannels, 1);% Все каналы участвуют в CSD
            filter_avaliable = true(numChannels, 1);
            
            filterSettings.filterType = 'highpass';
            filterSettings.freqLow = 10;
            filterSettings.freqHigh = 50;
            filterSettings.order = 4;
            filterSettings.channelsToFilter = false(numChannels, 1);% Ни один канал не участвует в фильтрации
                
            tableData = [channelNames, num2cell(channelEnabled), num2cell(scalingCoefficients), colorsIn, num2cell(lineCoefficients)];

            set(channelTable, 'Data', tableData); % Обновляем данные в таблице

            updateChannelSelection(); % Вызываем функцию для обновления выбора каналов
        end
    end
    
    function UpdateEventTable()
        
        [events, ev_inxs] = sort(events);
        event_comments = event_comments(ev_inxs);
        eventTable.Data = [num2cell(events*timeUnitFactor), event_comments];
    end

    function addEvent(~, ~)
        event_x = addExtraEvent();% alvays in seconds!
        events = [events; event_x];
        event_comments{numel(events), 1} = '...';
        UpdateEventTable();
        events_exist = true;
        updatePlot()
    end

    function clearTable(~, ~)
        choice = questdlg('Are you sure you want to clear the table?', ...
                          'Clear Table', ...
                          'Yes','No','No');
        switch choice
            case 'Yes'
                events = [];
                event_comments = {};
                UpdateEventTable();
                events_exist = false;
                updatePlot();
            case 'No'
                % Do nothing if the user selects 'No'
        end
    end


    function shiftTime(~, ~, direction, timeForwardEdit)
        
        windowSize = str2double(get(timeForwardEdit, 'String'))/timeUnitFactor;% должен быть в секундах
        switch selectedCenter
            case 'event'
                if events_exist
                    if direction == 1% движение вперед  
                        event_inx = event_inx+1;                    
                    else% движение назад 
                        event_inx = event_inx-1;                    
                    end
                    if event_inx > numel(events)
                        event_inx = numel(events);
                    end
                    if event_inx > 0
                        chosen_time_interval(1) = events(event_inx);
                        chosen_time_interval(2) = events(event_inx)+windowSize;
                    else
                        event_inx = 1;
                    end
                end
            case 'stimulus'
                if stims_exist
                    if direction == 1% движение вперед  
                        stim_inx = stim_inx+1;                    
                    else% движение назад 
                        stim_inx = stim_inx-1;                    
                    end
                    if stim_inx > numel(stims)
                        stim_inx = numel(stims);
                    end
                    if stim_inx > 0
                        chosen_time_interval(1) = stims(stim_inx);
                        chosen_time_interval(2) = stims(stim_inx)+windowSize;
                    else
                        stim_inx = 1;
                    end
                end
            case 'time'            
            if direction == 1% движение вперед            
                next_step_1 = chosen_time_interval(2);
                next_step_2 = chosen_time_interval(2)+windowSize; 
                % проверка           
                if next_step_2>time(end)
                    errordlg('Invalid time interval.');
                    return;
                end
                % Обновление интервала времени
                chosen_time_interval(1) = next_step_1;
                chosen_time_interval(2) = next_step_2;
            else% движение назад 
                next_step_1 = chosen_time_interval(1)-windowSize;
                next_step_2 = next_step_1 + windowSize;
                if next_step_1<0
                    errordlg('Invalid time interval.');
                    return;
                end         
                chosen_time_interval(1) = next_step_1;
                chosen_time_interval(2) = next_step_2;
            end
        end
        updatePlot(); % Обновление графика
    end
    
    function deleteEvent(~, ~)
        eventIndex = str2double(get(eventDeleteEdit, 'String'));
        if isnan(eventIndex) || eventIndex <= 0 || eventIndex > size(events, 1)
            errordlg('Invalid event index.');
            return;
        end
        % Удаление события
        events(eventIndex) = [];
        event_comments(eventIndex) = [];
        UpdateEventTable();% update event table
        if isempty(events)
            events_exist = false;
        end
        updatePlot()
    end

% добавляем возможность вызвать функцию открытия извне
global event_calling outside_calling_filepath zav_calling
zav_calling = @loadMatFile;
event_calling = @loadEvents;
outside_calling_filepath = [];

% Функция загрузки событий
function loadEvents(~, ~)
    disp(outside_calling_filepath)
    if isempty(outside_calling_filepath)
        % Получение пути к последнему открытому файлу или использование стандартной директории
        initialDir = pwd;
        if ~isempty(lastOpenedFiles)
            initialDir = fileparts(lastOpenedFiles{end});
        end

        [file, path] = uigetfile({'*.ev'; '*.mean'}, 'Load Events', initialDir);
        if isequal(file, 0)
            disp('File selection canceled.');
            return;
        end
        filepath = fullfile(path, file);
    else
        disp('loading file from outside')
        filepath = outside_calling_filepath;
        [path,~,~] = fileparts(outside_calling_filepath);
        outside_calling_filepath = [];
    end
    
    loadedData = load(filepath, '-mat'); % Загружаем данные в структуру
    % Если не был загружен mat файл, инициируем поиск
    [~, name, ~] = fileparts(filepath);
    fileName = name(1:19);
    keepSearching = true; % Флаг продолжения поиска
    while keepSearching
        firstMatFile = findFirstMatFile(path, fileName);
        if ~isempty(firstMatFile)
            loadMatFile(firstMatFile); % Загрузка .mat файла
            keepSearching = false; % Останавливаем поиск, если файл найден
        else
            choice = questdlg('The .mat file was not found. What do you want to do?', ...
                'File Not Found', ...
                'Retry in Parent Directory', 'Select File Manually', 'Cancel', ...
                'Retry in Parent Directory');
            
            switch choice
                case 'Retry in Parent Directory'
                    [path, ~, ~] = fileparts(path); % Переход на уровень выше
                    if isempty(path)
                        warndlg('Reached the top directory. Please select the file manually.');
                        keepSearching = false; % Прекращаем поиск, если достигнута верхняя директория
                    end
                case 'Select File Manually'
                    [file, path] = uigetfile('*.mat', 'Select the .mat file', path);
                    if isequal(file, 0)
                        disp('File selection canceled.');
                        return;
                    else
                        matFilePath = fullfile(path, file);
                        loadMatFile(matFilePath); % Загрузка выбранного .mat файла
                        keepSearching = false; % Останавливаем поиск, если файл выбран вручную
                    end
                otherwise % В случае отмены
                    return;
            end
        end
    end
    
    if isfield(loadedData, 'manlDet')
        events = time([loadedData.manlDet.t])'; % Обновляем таблицу событий
        
        if ~isfield(loadedData, 'event_comments') % если комментариев не было
            event_comments = repmat({'...'}, numel(events), 1); % Инициализация комментариев
        else % если были комментарии
            event_comments = loadedData.event_comments;
        end
        
        UpdateEventTable();
        events_exist = true;
        event_inx = 1;
        timeForwardEditCallback(timeForwardEdit);
        
        set(timeCenterPopup, 'Value', 3);
        changeTimeCenter(timeCenterPopup);
        
        updatePlot();
    else
        errordlg('No events found in the file.');
    end
end



    function saveEvents(~, ~)

        [path, name, ~] = fileparts(matFilePath);
        defaultFileName = fullfile(path, [name '_events.ev']);

        [file, path] = uiputfile('*.ev', 'Save Events', defaultFileName);
        if isequal(file, 0)
            disp('File save canceled.');
            return;
        end
        filepath = fullfile(path, file);
        clear manlDet
        % Преаллокация структуры
        manlDet(numel(events)) = struct('t', [], 'ch', [], 'subT', [], 'subCh', [], 'sw', []);

        for i = 1:numel(events)
            manlDet(i).t = ClosestIndex(events(i), time);
            manlDet(i).ch = 1;
            manlDet(i).subT = [];
            manlDet(i).subCh = 2;
            manlDet(i).sw = 1;
        end

        save(filepath, 'manlDet', 'event_comments'); % Сохранение в .ev файл
    end

    set(eventTable, 'CellEditCallback', @updateEventTable);
    set(channelTable, 'CellEditCallback', @updateChannelSelection);
    
    
    function updateAndRunInstaller()
        saveDirectory = fullfile(fileparts(EV_path), 'EV updates'); % Save directory

        % Check for the existence of the save directory and create it if necessary
        if ~exist(saveDirectory, 'dir')
            mkdir(saveDirectory);
        end

        % Call the function to check and update the version
        [isNewVersionAvailable, newVersion] = checkAndUpdateVersion(EV_version, saveDirectory);

        % Check if a new version has been downloaded
        if isNewVersionAvailable
            % Dialog box to confirm the installation of the new version
            choice = questdlg(['New version ' newVersion ' is available. Do you want to install it now?'], ...
                'Update Available', ...
                'Yes', 'No', 'Yes');

            % Handle the user's response
            if strcmp(choice, 'Yes')
                % Form the full path to the downloaded installer file
                installerPath = fullfile(saveDirectory, ['EasyView ', newVersion, '.exe']);
                % открываем папку с установщиком
                winopen(saveDirectory)
                % закрываем программу
                closeAllCallback(f, []);
            end
        else
            % Dialog box to inform the user that the latest version is already installed
            msgbox('The latest version is already installed.', 'No Update Required', 'warn');
        end
    end

end

