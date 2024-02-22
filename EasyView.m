function EasyView()
    clear global

    global Fs N time chosen_time_interval cond ch_inxs m_coef 
    global data time_in shiftCoeff eventTable
    global lfp hd spks multiax lineCoefficients
    global channelNames numChannels channelEnabled scalingCoefficients tableData
    global matFilePath channelSettingsFilePath
    global timeUnitFactor selectedUnit
    global saved_time_interval
    global meanData timeAxis initialDir
    global events event_inx events_exist event_comments
    global stims stim_inx stims_exist
    global lastOpenedFiles
    global updatedData
    global zavp newFs selectedCenter
    global time_back time_forward
    global figure_position timeForwardEdit
    global meanSaveButton saveDataButton
    global std_coef show_spikes binsize show_CSD % спайки/CSD
    global events_detected
    global ev_hists ch_hists 
    global ch_labels_l colors_in_l  widths_in_l
    global add_event_settings
    global mean_group_ch timeSlider menu_visible csd_avaliable filter_avaliable filterSettings
    global channelTable 
    global data_loaded
    
    data_loaded = false;
    menu_visible = false;
    
    binsize = 0.001;%s
    show_spikes = false;
    show_CSD = false;
    std_coef = 0.5;
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
    SettingsFilepath = fullfile(tempdir, 'last_opened_files_1.03.mat');
    loadLastOpenedFiles()    
    function loadLastOpenedFiles()
        if exist(SettingsFilepath, 'file')
            d = load(SettingsFilepath);
            lastOpenedFiles = d.lastOpenedFiles;
            figure_position = d.figure_position;
            if isfield(d, 'add_event_settings')
                add_event_settings = d.add_event_settings;
            end
        else
            lastOpenedFiles = {};
            figure_position = base_figure_position;
            % Инициализация структуры настроек по умолчанию
            add_event_settings.mode = 'freehand';
            add_event_settings.channel = 11;
            add_event_settings.polarity = 'positive';
            add_event_settings.timeWindow = 10;
        end
    end

    % координаты графических элементов
    
    
    scaleX = figure_position(3) / base_figure_position(3);
    scaleY = figure_position(4) / base_figure_position(4);
    scaling_matrix = [scaleX, scaleY, scaleX, scaleY];
    
    menu_coords = [1070, 510, 150, 100].*scaling_matrix*min_scale_coef;
    optionbtn_coords = [150, 600, 90, 30].*scaling_matrix*min_scale_coef;
    saveEventsBtn_coords = [270, 140, 70, 30].*scaling_matrix*min_scale_coef;
    loadEventsBtn_coords = [270, 110, 70, 30].*scaling_matrix*min_scale_coef;
    eventAdd_coords = [10, 10, 80, 30].*scaling_matrix*min_scale_coef;
    channelTable_coords = [10, 200, 300, 400].*scaling_matrix*min_scale_coef;
    timeSlider_coords = [300, 50, 220, 15].*scaling_matrix*min_scale_coef;
    timeUnitPopup_coords = [540, 35, 50, 30].*scaling_matrix*min_scale_coef;
    timeCenterPopup_coords = [540, 10, 50, 30].*scaling_matrix*min_scale_coef;
    viewallbutton_coords = [850, 35, 30, 30].*scaling_matrix*min_scale_coef;
    timeBackEdit_coords = [165, 10, 50, 30].*scaling_matrix*min_scale_coef;
    timeForwardEdit_coords = [220, 10, 50, 30].*scaling_matrix*min_scale_coef;
    stdCoefEdit_coords = [775, 10, 50, 30].*scaling_matrix*min_scale_coef;
    showSpikesButton_coords = [775, 45, 50, 30].*scaling_matrix*min_scale_coef;
    showCSDbutton_coords = [720, 45, 50, 30].*scaling_matrix*min_scale_coef;
    previousbutton_coords = [305, 10, 100, 30].*scaling_matrix*min_scale_coef;
    nextbutton_coords = [415, 10, 100, 30].*scaling_matrix*min_scale_coef;
    eventTable_coords = [10, 50, 250, 127].*scaling_matrix*min_scale_coef;
    LoadSettingsBtn_coords = [10, 600, 120, 30].*scaling_matrix*min_scale_coef;
    eventDeleteEdit_coords = [100, 10, 50, 30].*scaling_matrix*min_scale_coef;
    shiftCoeffEdit_coords = [650, 10, 50, 30].*scaling_matrix*min_scale_coef;
    FsCoeffEdit_coords = [650, 50, 50, 30].*scaling_matrix*min_scale_coef;
    meanEventsWindowEdit_coords = [285, 48, 40, 20].*scaling_matrix*min_scale_coef;
    meanEventsWindowText_coords = [265, 60, 80, 20].*scaling_matrix*min_scale_coef;
    clearTableBtn_coords = [270, 10, 70, 30].*scaling_matrix*min_scale_coef;
    MeanEventsBtn_coords = [270, 80, 70, 30].*scaling_matrix*min_scale_coef;
    AutoEventDetectionBtn_coords = [90, 178, 120, 20].*scaling_matrix*min_scale_coef;
    DataComparerBtn_coords = [260, 178, 80, 20].*scaling_matrix*min_scale_coef;
    DeleteEventBtn_coords = [150, 10, 80, 30].*scaling_matrix*min_scale_coef;
    FsText_coords = [600, 43, 80, 30].*scaling_matrix*min_scale_coef;
    shiftCoefText_coords = [598, 3, 60, 30].*scaling_matrix*min_scale_coef;
    stdCoefText_coords = [708, 4, 80, 30].*scaling_matrix*min_scale_coef;
    EventsText_coords = [10, 175, 100, 20].*scaling_matrix*min_scale_coef;
    LoadMatFileBtn_coords = [10, 10, 120, 30].*scaling_matrix*min_scale_coef;
    TimeWindowText_coords = [165, 42, 100, 30].*scaling_matrix*min_scale_coef;
    BeforeText_coords = [165, 27, 50, 30].*scaling_matrix*min_scale_coef;
    AfterText_coords = [220, 27, 50, 30].*scaling_matrix*min_scale_coef;
    

    
    function saveSettings()
        figure_position = f.Position;
        save(SettingsFilepath, 'lastOpenedFiles', 'figure_position', 'add_event_settings');
    end

    clc
    
    timeUnitFactor = 1;    
    selectedUnit = 's';
    activ_all_view = true;
    
    % Создание таймера
    t = timer('TimerFcn', @resetParametersCallback, 'StartDelay', 1, 'ExecutionMode', 'singleShot');
    
    % Создание фигуры и панелей
    f = figure('Name', 'LFP Data Viewer', ...
           'MenuBar', 'none', ... % Отключение стандартного меню
           'ToolBar', 'none', ...
           'KeyPressFcn', @keyPressFunction);
    
    
    f.Position = figure_position;       
    
    mainPanel = uipanel('Parent', f, 'Position', [.01 .01 .7 .13]);
    multiax = axes('Position', [0.07    0.2    0.63    0.75]);
    sidePanel = uipanel('Parent', f, 'Position', [.72 .01 .27 .98]);
    
    set(f, 'SizeChangedFcn', @resizeComponents);
    % Настройка обработчика закрытия для фигуры
    set(f, 'CloseRequestFcn', @(src, event)closeAllCallback(src, event));

    height_of_sidePanel = 195;
    width_of_text = 100;
    % Добавление текстовой метки как заголовка к sidePanel
    EventsText = uicontrol('Parent', sidePanel, 'Style', 'text', 'String', 'Events', ...
              'Position', [10, height_of_sidePanel - 20, width_of_text, 20], ...
              'HorizontalAlignment', 'left', ...
              'FontSize', 10, ... % Можно настроить размер шрифта
              'FontWeight', 'bold'); % Жирный шрифт для заголовка
      
    buttonY_line = 10;
    % Добавление слайдера для времени
    timeSlider = uicontrol('Parent', mainPanel, 'Style', 'slider', 'Position', timeSlider_coords, 'Min', 0, 'Max', 1, 'Value', 0, 'Callback', @timeSliderCallback);

    % Добавление выпадающего списка для выбора единиц времени
    timeUnitPopup = uicontrol('Parent', mainPanel, 'Style', 'popup', 'String', {'s', 'ms', 'min'}, 'Position', timeUnitPopup_coords, 'Callback', @changeTimeUnit);

    % Добавление выпадающего списка для выбора режима просмотра
    timeCenterPopup = uicontrol('Parent', mainPanel, 'Style', 'popup', 'String', {'time', 'stimulus', 'event'}, 'Position', timeCenterPopup_coords, 'Callback', @changeTimeCenter);

    % Кнопка для загрузки .mat файла
    LoadMatFileBtn = uicontrol('Parent', mainPanel, 'Style', 'pushbutton', 'String', 'Load .mat File (ZAV Format)', 'Position', LoadMatFileBtn_coords, 'Callback', @OpenZavLfpFile);

    % Кнопка для просмотра всего сигнала целиком
    viewallbutton = uicontrol('Parent', mainPanel, 'Style', 'pushbutton', 'String', '[ ]', 'Position', viewallbutton_coords, 'Callback', @ViewAll);

    % Поля для выбора временного окна
    TimeWindowText = uicontrol('Parent', mainPanel, 'Style', 'text', 'String', 'Time Window (s):', 'Position', TimeWindowText_coords);
    BeforeText = uicontrol('Parent', mainPanel, 'Style', 'text', 'String', 'before', 'Position', BeforeText_coords);
    AfterText = uicontrol('Parent', mainPanel, 'Style', 'text', 'String', 'after', 'Position', AfterText_coords);
    timeBackEdit = uicontrol('Parent', mainPanel, 'Style', 'edit', 'String', '1', 'Position', timeBackEdit_coords, 'Callback', @timeBackEditCallback);
    timeForwardEdit = uicontrol('Parent', mainPanel, 'Style', 'edit', 'String', '1', 'Position', timeForwardEdit_coords, 'Callback', @timeForwardEditCallback);

    % Spikes
    % STD
    stdCoefText = uicontrol('Parent', mainPanel, 'Style', 'text', 'String', 'STD coef:', 'Position', stdCoefText_coords);
    stdCoefEdit = uicontrol('Parent', mainPanel, 'Style', 'edit', 'String', num2str(std_coef), 'Position', stdCoefEdit_coords, 'Callback', @StdCoefCallback);
    showSpikesButton = uicontrol('Parent', mainPanel, 'Style', 'checkbox', 'String', 'spikes', 'Position', showSpikesButton_coords, 'Callback', @ShowSpikesButtonCallback);
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

    
    % Список настроек
    options = {'Events','Filtering', 'CSD Displaying', 'Average subtraction', 'Spectral Density'};    
   
    % Создание выпадающего списка
    menu = uicontrol('Style', 'listbox',...
              'String', options,...
              'Visible', 'off', ...
              'Position', menu_coords,...
              'Callback', @OptionsSelectionCallback);
    % Создание кнопки для активации выпадающего списка
    btn = uicontrol('Parent', sidePanel, 'Style', 'pushbutton', 'String', 'Options ...',...
                    'Visible', 'on', ...
                    'Position', optionbtn_coords + [0, 0, 0, 0],...
                    'Callback', @showMenu);

    
    % Таблица для отображения событий
    event_table_data = [num2cell([]), num2cell([])];    
    eventTable = uitable('Parent', sidePanel, ...
                     'Position', [10, 50, 250, 127], ...
                     'ColumnName', {'Time', 'Comment'}, ...
                     'ColumnFormat', {'bank', 'char'}, ... % Формат для отображения чисел
                     'Data', event_table_data, ...
                     'ColumnEditable', [false true]);
                 
    % Автоматический детектор событий
    AutoEventDetectionBtn = uicontrol('Parent', sidePanel,'Style', 'pushbutton', 'String', 'Auto Event Detection',...
        'Position', AutoEventDetectionBtn_coords, 'Callback', @openAutoEventDetectionWindow);
    
    % Сравнение средних событий
    DataComparerBtn = uicontrol('Parent', sidePanel,'Style', 'pushbutton', 'String', 'Data Comparer',...
        'Position', DataComparerBtn_coords, 'Callback', @dataComparerCallback);   

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

    % Кнопки и поля для управления событиями    
    DeleteEventBtn = uicontrol('Parent', sidePanel, 'Style', 'pushbutton', 'String', 'Delete Event', 'Position', DeleteEventBtn_coords, 'Callback', @deleteEvent);
    eventDeleteEdit = uicontrol('Parent', sidePanel, 'Style', 'edit', 'Position', eventDeleteEdit_coords);

    % Clear Table
    clearTableBtn = uicontrol('Parent', sidePanel, 'Style', 'pushbutton', 'String', 'Clear Table', 'Position', clearTableBtn_coords, 'Callback', @clearTable);
    
    % Add event
    eventAdd = uicontrol('Parent', sidePanel, 'Style', 'pushbutton', 'String', 'Add Event', 'Position', eventAdd_coords, 'Callback', @addEvent);

    % Кнопка для сохранения событий
    saveEventsBtn = uicontrol('Parent', sidePanel, 'Style', 'pushbutton', 'String', 'Save Events', 'Position', saveEventsBtn_coords, 'Callback', @saveEvents);

    % Кнопка для загрузки событий
    loadEventsBtn = uicontrol('Parent', sidePanel, 'Style', 'pushbutton', 'String', 'Load Events', 'Position', loadEventsBtn_coords, 'Callback', @loadEvents);

    % Кнопка и окно ввода для 'Mean Events'
    MeanEventsBtn = uicontrol('Parent', sidePanel, 'Style', 'pushbutton', 'String', 'Mean Events', 'Position', MeanEventsBtn_coords, 'Callback', @meanEventsCallback);
    meanEventsWindowText = uicontrol('Parent', sidePanel, 'Style', 'text', 'String', 'Window(+/-, s):', 'Position', meanEventsWindowText_coords);
    meanEventsWindowEdit = uicontrol('Parent', sidePanel, 'Style', 'edit', 'String', '1', 'Position', meanEventsWindowEdit_coords); % Окно ввода временного окна
    
    % отключаем все элементы управления кроме начальных
    setUIControlsEnable({sidePanel, mainPanel} , 'off')
    set(LoadMatFileBtn, 'Enable', 'on');
    set(loadEventsBtn, 'Enable', 'on');
           
    f.WindowButtonDownFcn = @(src, event)ButtonDownFcn(multiax, f);
    function ButtonDownFcn(ax, fig)
        % Проверяем, зажата ли клавиша Ctrl
        modifiers = get(fig, 'CurrentModifier');
        if ismember('control', modifiers) % Если зажата Ctrl
            % Добавление интерактивного маркера при клике на график 
            marker = addMarker(ax);
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
    function closeAllCallback(src, event)
        % Закрытие всех фигур
        close all;
        clear global
        % Удаление текущей фигуры из памяти и её закрытие
        delete(src);
    end

    % Callback для сброса параметров
    function resetParametersCallback(~, ~)
        resetGraphParameters()
    end

    % Функция для сброса графических параметров
    function resetGraphParameters()
        % disp('Resetting graphic parameters...');
        % Код для сброса параметров здесь
        set(menu, 'Visible', 'off'); % Скрыть меню
        set(btn, 'String', 'Options ...');
        menu_visible = false;
    end
        % Обратный вызов выпадающего списка
    function OptionsSelectionCallback(src, ~)
        val = src.Value;
        str = src.String;
        selectedOption = str{val};
        disp(selectedOption)
        switch selectedOption
            case options{2}%'Filtering ...'
                setupSignalFilteringGUI();
            case options{1}% Add event options
                addEventSettingsUicontrol();
            case options{3}%'CSD ...'
                % вызов функции для CSD ...
                CSDfigSettings();
            case options{4} %'Subtract mean ...'
                % вызов функции для Subtract mean ...
                SubMeanFigSettings()
            case options{5}
                % отображение спектральной плотности текущего сигнала
                spectralDensityGUI();
        end
        resetGraphParameters()
    end
    % Функция обратного вызова для кнопки
    function showMenu(src, ~)
        if menu_visible
            set(menu, 'Visible', 'off'); % Убрать меню
            strn = 'Options ...';
        else
            set(menu, 'Visible', 'on'); % Показать меню    
            strn = 'Options:';
        end
        set(btn, 'String', strn);
        menu_visible = not(menu_visible);
    end

    function resizeComponents(~, ~)
        % Получение текущего размера фигуры
        pos = get(f, 'Position');
        scaleX = pos(3) / figure_position(3);
        scaleY = pos(4) / figure_position(4);
        scaling_matrix = [scaleX, scaleY, scaleX, scaleY];

        set(btn, 'Position', optionbtn_coords .*scaling_matrix);
        set(menu, 'Position', menu_coords .*scaling_matrix);
        set(saveEventsBtn, 'Position', saveEventsBtn_coords .* scaling_matrix);
        set(loadEventsBtn, 'Position', loadEventsBtn_coords .* scaling_matrix);
        set(eventAdd, 'Position', eventAdd_coords .* scaling_matrix);
        set(channelTable, 'Position', channelTable_coords .* scaling_matrix);
        set(timeSlider, 'Position', timeSlider_coords .* scaling_matrix);
        set(timeUnitPopup, 'Position', timeUnitPopup_coords .* scaling_matrix);
        set(timeCenterPopup, 'Position', timeCenterPopup_coords .* scaling_matrix);
        set(viewallbutton, 'Position', viewallbutton_coords .* scaling_matrix);
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
        set(DataComparerBtn, 'Position', DataComparerBtn_coords .* scaling_matrix);
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


    function dataComparerCallback(~, ~)
        dataComparerApp()
    end

    function openAutoEventDetectionWindow(~, ~)
        % Окно Auto Event Detection
        detectionFig = figure('Name', 'Auto Event Detection', 'NumberTitle', 'off', 'Position', [100, 100, 800, 400]);

        % Окошко для ввода MinPeakProminence
        uicontrol(detectionFig, 'Style', 'text', 'Position', [10, 350, 150, 20], 'String', 'MinPeakProminence:');
        hMinPeakProminence = uicontrol(detectionFig, 'Style', 'edit', 'Position', [160, 350, 130, 20], 'String', '50');

        % Окно выбора ChPos и ChNeg из списка каналов
        uicontrol(detectionFig, 'Style', 'text', 'Position', [10, 310, 150, 20], 'String', 'ChPos:');
        hChPos = uicontrol(detectionFig, 'Style', 'popupmenu', 'Position', [160, 310, 130, 20], 'String', hd.recChNames);
        uicontrol(detectionFig, 'Style', 'text', 'Position', [10, 270, 150, 20], 'String', 'ChNeg:');
        hChNeg = uicontrol(detectionFig, 'Style', 'popupmenu', 'Position', [160, 270, 130, 20], 'String', hd.recChNames);

        % Окошко для ввода MinPeakDistance
        uicontrol(detectionFig, 'Style', 'text', 'Position', [10, 230, 150, 20], 'String', 'MinPeakDistance (s):');
        hMinPeakDistance = uicontrol(detectionFig, 'Style', 'edit', 'Position', [160, 230, 130, 20], 'String', '3');

        % Окошко для ввода onset_threshold
        uicontrol(detectionFig, 'Style', 'text', 'Position', [10, 190, 150, 20], 'String', 'onset_threshold:');
        hOnsetThreshold = uicontrol(detectionFig, 'Style', 'edit', 'Position', [160, 190, 130, 20], 'String', '10');

        % Окошко для ввода sig_part_window
        uicontrol(detectionFig, 'Style', 'text', 'Position', [10, 150, 150, 20], 'String', 'sig_part_window (s):');
        hSigPartWindow = uicontrol(detectionFig, 'Style', 'edit', 'Position', [160, 150, 130, 20], 'String', '1');

        % Окно выбора режима детекции
        uicontrol(detectionFig, 'Style', 'text', 'Position', [10, 110, 150, 20], 'String', 'Detection Mode:');
        hDetectionMode = uicontrol(detectionFig, 'Style', 'popupmenu', 'Position', [160, 110, 130, 20], 'String', {'peaks', 'onsets'});

       
        ax = axes('Position', [0.43    0.27    0.54    0.3]);
        
        axpos = axes('Position', [0.43    0.8267   0.54    0.15]);
        axneg = axes('Position', [0.43    0.6283    0.54    0.15]);
       
        
        % Кнопка 'Check Detection'
        uicontrol(detectionFig, 'Style', 'pushbutton', 'String', 'Check Detection',...
            'Position', [340, 10, 280, 40], 'Callback', @checkDetectionCallback);
        
        % Кнопка 'Apply'
        uicontrol(detectionFig, 'Style', 'pushbutton', 'String', 'Apply',...
            'Position', [650, 10, 120, 40], 'Callback', @detectButtonCallback);
        
        function checkDetectionCallback(~, ~)
            clc
            % Сбор значений параметров и упаковка их в структуру
            params.MinPeakProminence = str2double(get(hMinPeakProminence, 'String'));
            params.ChPos = get(hChPos, 'Value');
            params.ChNeg = get(hChNeg, 'Value');
            params.MinPeakDistance = str2double(get(hMinPeakDistance, 'String'));
            params.OnsetThreshold = str2double(get(hOnsetThreshold, 'String'));
            params.SigPartWindow = str2double(get(hSigPartWindow, 'String'));
            DetectionModes = get(hDetectionMode, 'String');
            params.DetectionMode = DetectionModes{get(hDetectionMode, 'Value')};
        
            [events_detected, PosTrace, NegTrace, Filtered_Reversion, time_res] = autoEventDetection(params);
            
            axes(axpos)
            cla, hold on
            plot(time_res, PosTrace)
            xlim([time_res(1), time_res(end)])
            ylim([-shiftCoeff, shiftCoeff])
            Lines(events_detected, [], 'r',':');
            
            axes(axneg)
            cla, hold on
            plot(time_res, NegTrace)
            xlim([time_res(1), time_res(end)])
            ylim([-shiftCoeff, shiftCoeff])
            Lines(events_detected, [], 'r',':');
            
            axes(ax)
            cla, hold on
            plot(time_res, Filtered_Reversion)
            xlim([time_res(1), time_res(end)])
            
            Lines(events_detected, [], 'r',':');
        end
        
        function detectButtonCallback(~, ~)

            events = events_detected;
            event_comments = repmat({'...'}, numel(events), 1); % Инициализация комментариев
            
            % Закрыть окно Auto Event Detection
            close(detectionFig);
            
            if not(isempty(events))
                
                UpdateEventTable();
                events_exist = true;
                event_inx = 1;
                updatePlot()            
            end        
        end
        
    end



    function [events_detected, PosTrace, NegTrace, Filtered_Reversion, time_res] = autoEventDetection(params)
        % Распаковка параметров из структуры
        sig_part_window = params.SigPartWindow;
        MinPeakProminence = params.MinPeakProminence;
        ChPos = params.ChPos;
        ChNeg = params.ChNeg;
        MinPeakDistance = params.MinPeakDistance;
        onset_threshold = params.OnsetThreshold;
        DetectionMode = params.DetectionMode;
        % detecting eSPW events and onsets by Mikhail Sintsov's method
        raw_frq = Fs;
        lfp_frq = round(newFs);
        NegTrace = resample(double(lfp(:, ChNeg)), lfp_frq , raw_frq)';
        PosTrace = resample(double(lfp(:, ChPos)), lfp_frq , raw_frq)';
        time_res = linspace(time(1),time(end),numel(PosTrace));   
        Reversion = PosTrace - NegTrace;
        Reversion = medfilt1(Reversion, 20);
        baseline = medfilt1(Reversion, 1000);
        Filtered_Reversion = Reversion;
        Filtered_Reversion(Filtered_Reversion<baseline) = baseline(Filtered_Reversion<baseline);
        Filtered_Reversion = Filtered_Reversion - baseline;
        [~, peak_times] = findpeaks(Filtered_Reversion, time_res, 'MinPeakProminence',MinPeakProminence, 'MinPeakDistance', MinPeakDistance);
        peak_locs_inx = ClosestIndex(peak_times, time_res);
        
        switch DetectionMode
            case 'peaks'
                events_detected = peak_times';
            case 'onsets'
                % onset of peaks by Khazipov method
                onset_locs_inx = zeros(size(peak_locs_inx));
                sig_part_window_inx = ClosestIndex(sig_part_window, time_res);
                o_i = 0;
                for peak_loc_inx = peak_locs_inx
                    o_i = o_i + 1;
                    
                    start_inx = peak_loc_inx - sig_part_window_inx;
                    end_inx = peak_loc_inx + sig_part_window_inx;
                    
                    if start_inx > 1 & end_inx < numel(Filtered_Reversion)
                        signal_part = Filtered_Reversion(start_inx : end_inx);
                        onset_l = find(diff(signal_part) > onset_threshold);
                        if not(isempty(onset_l))
                            onset_locs_inx(o_i) = start_inx + onset_l(1);
                        end
                    end                    
                end
                onset_locs_inx(onset_locs_inx == 0) = [];
                onset_times = time_res(onset_locs_inx)';
                events_detected = onset_times;
        end
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

    

    function saveFigure(fig)
        % Скрытие кнопки
        set(meanSaveButton, 'Visible', 'off');
        set(saveDataButton, 'Visible', 'off');
        
        [path, name, ~] = fileparts(matFilePath);
        defaultFileName = fullfile(path, [name '_events.png']);
        
        % Открытие диалогового окна для сохранения файла
        [fileName, filePath, filterIndex] = uiputfile('*.png', 'Save as', defaultFileName);

        % Проверка, был ли выбран файл
        if fileName ~= 0
            % Создание полного пути к файлу
            fullFilePath = fullfile(filePath, fileName);
            saveas(fig, fullFilePath, 'png');
        else
            disp('File save cancelled.');
        end
        
        % Восстановление видимости кнопки
        set(meanSaveButton, 'Visible', 'on');
        set(saveDataButton, 'Visible', 'on');
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

    % Функция просмотра всего сигнала
    function ViewAll(~, ~)
        if activ_all_view
            buttonstring = '][';
            buttonmode = 'off';
            % сохраняем старую позицию
            saved_time_interval = chosen_time_interval;
            % меняем позицию
            chosen_time_interval = [time(1), time(end)];
        else
            buttonstring = '[ ]';
            buttonmode = 'on';     
            % возвращаем позицию
            chosen_time_interval = saved_time_interval;    
        end

        % (де)активировать кнопки
        set(previousbutton, 'Enable', buttonmode);
        set(nextbutton, 'Enable', buttonmode);
        set(timeForwardEdit, 'Enable', buttonmode);
        set(viewallbutton, 'String', buttonstring);
            
            
        % Меняем состояние
        activ_all_view = not(activ_all_view);

        updatePlot(); % Обновление графика
    end
    
    % std coef
    function StdCoefCallback(src, ~)
        std_coef = str2double(get(src, 'String'));
        updatePlot(); % Обновление графика
    end
    function ShowSpikesButtonCallback(src, ~)
        show_spikes = not(show_spikes);
        set(showSpikesButton, 'Value', show_spikes);
        updatePlot(); % Обновление графика
    end

    function ShowCSDButtonCallback(src, ~)
        show_CSD = not(show_CSD);
        set(showCSDbutton, 'Value', show_CSD);
        updatePlot(); % Обновление графика
    end

    % Функция обратного вызова для timeBackEdit
    function timeBackEditCallback(src, ~)
        time_back = str2double(get(src, 'String'));
        timeForwardEditCallback(timeForwardEdit);% используем функционал обратного вызова timeForwardEdit
    end
    % Функция обратного вызова для timeForwardEdit
    function timeForwardEditCallback(src, ~)
        windowSize = str2double(get(src, 'String'));
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
                    set(src, 'String', num2str(windowSize)); % Обновляем значение в поле
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
        UpdateEventTable();
        updatePlot(); % Обновление графика с новыми единицами времени
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
            'csd_avaliable', 'filter_avaliable', 'filterSettings');
    end
    
    % Функция обратного вызова слайдера
    function timeSliderCallback(src, ~)
        sliderValue = get(src, 'Value'); % Текущее значение слайдера
        windowSize = str2double(get(timeForwardEdit, 'String'));
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
        set(timeBackEdit, 'String', num2str(time_back));% time window before
        set(timeForwardEdit, 'String', num2str(time_forward));% time window after
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
            setUIControlsEnable({sidePanel, mainPanel} , 'on')
            data_loaded = true;
        end
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
                time_back = loadedSettings.time_back;
                set(timeBackEdit, 'String', num2str(time_back));% time window before
            end
            if isfield(loadedSettings, 'time_forward')
                time_forward = loadedSettings.time_forward;
                chosen_time_interval = [0, time_forward];
                set(timeForwardEdit, 'String', num2str(time_forward));% time window after
            end
            if isfield(loadedSettings, 'mean_group_ch')
                mean_group_ch = loadedSettings.mean_group_ch;
            else% если настройки старые
                mean_group_ch = false(numChannels, 1);% Ни один канал не участвует в усреднении
                disp('settings were without mean_group_ch')
            end
            if isfield(loadedSettings, 'csd_avaliable')
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
            if isfield(loadedSettings, 'filterSettings')
                filterSettings = loadedSettings.filterSettings;
            else% если настройки старые                
                filterSettings.filterType = 'highpass';
                filterSettings.freqLow = 10;
                filterSettings.freqHigh = 50;
                filterSettings.order = 4;
                filterSettings.channelsToFilter = false(numChannels, 1);% Ни один канал не участвует в фильтрации
                disp('settings were without filterSettings')
            end            
    end

    % Функция загрузки настроек каналов
    function loadChannelSettings()
        [path, name, ~] = fileparts(matFilePath);
        channelSettingsFilePath = fullfile(path, [name '_channelSettings.stn']);
        if isfile(channelSettingsFilePath)
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
        events = [];
        event_comments = {};
        UpdateEventTable();
        events_exist = false;
        updatePlot()
    end

    function shiftTime(~, ~, direction, timeForwardEdit)
        
        windowSize = str2double(get(timeForwardEdit, 'String'));
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

    function addEventSettingsCallback(~, ~)
%         addEventSettings();
        addEventSettingsUicontrol();
    end

% Функция загрузки событий
function loadEvents(~, ~)
    
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
    loadedData = load(filepath, '-mat'); % Загружаем данные в структуру
    
    % если не был загружен lfp, грузим lfp для этих эвентов
    [~, name, ~] = fileparts(filepath);
    fileName = name(1:19);
    firstMatFile = findFirstMatFile(path, fileName)
    if ~isempty(firstMatFile)
        if isempty(matFilePath)
            loadMatFile(firstMatFile) % Загрузка первого .mat файла если не было matFilePath
        else
            [~, current_fileName, ~] = fileparts(matFilePath);
            if ~strcmp(fileName, current_fileName)
                loadMatFile(firstMatFile) % Загрузка первого .mat файла если у нас другой файл поступил
            end
        end
    end
    
    if isempty(firstMatFile) & isempty(matFilePath)
        warndlg(['The ' fileName '.mat file was not found in this directory. Open .mat file manually or move .ev file to .mat file''s directory and try again.'], 'File Not Found');
        return;
    end

    
    if isfield(loadedData, 'manlDet')
        events = time([loadedData.manlDet.t])'; % Обновляем таблицу событий
        
        if not(isfield(loadedData, 'event_comments'))% если комментариев не было
            event_comments = repmat({'...'}, numel(events), 1); % Инициализация комментариев
        else % если были комментарии
            event_comments = loadedData.event_comments;      
        end
            
        UpdateEventTable();
        events_exist = true;
        event_inx = 1;
        timeForwardEditCallback(timeForwardEdit);
        updatePlot();
    elseif isfield(loadedData, 'events') % Добавлено условие для .mean файлов
        events = loadedData.events; % Извлечение переменной events из .mean файла
        event_comments = repmat({'...'}, numel(events), 1); % Инициализация комментариев
        UpdateEventTable();
        events_exist = true;
        event_inx = 1;
        timeForwardEditCallback(timeForwardEdit);
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
        events; % Получение данных событий
        clear manlDet
        for i = 1:numel(events)
            manlDet(i).t = ClosestIndex(events(i), time);
            manlDet(i).ch = 1;
            manlDet(i).subT = [];
            manlDet(i).subCh = 2;
            manlDet(i).sw = 1;
        end
        event_comments;
        save(filepath, 'manlDet', 'event_comments'); % Сохранение в .ev файл
    end

    set(eventTable, 'CellEditCallback', @updateEventTable);
    set(channelTable, 'CellEditCallback', @updateChannelSelection);
end
