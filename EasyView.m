function EasyView()
    
    % Easy Viewer:  visualization and analysis and electrophysiological data
    % 
    % 
    % Author:       Azat Gainutdinov
    %               ta3map@gmail.com
    %               
    % Date:         25.02.2025
    
    EV_version = '1.10.05';
    
    clc
    disp(['Easy Viewer version: ' EV_version])
    
    global app_path
    
    EV_path = pwd;
    disp('working directory:')
    fprintf('%s\n',EV_path);
    
    app_path = fileparts(mfilename('fullpath'));
    disp('app directory:')
    fprintf('%s\n',app_path);
    
    icons_path = [app_path, '\icons'];
    
    % если папки с иконками нет, скачиваем с GitHub и помещаем куда надо
    % это нужно для скомпилированного приложения
    if exist(icons_path) == 0 
        icons_path = downloadAndExtractGithub(app_path, 'icons');
    end
    
    disp('please wait ...')
   
    global Fs N time chosen_time_interval ch_inxs m_coef
    global shiftCoeff eventTable
    global lfp hd spks multiax chnlGrp
    
    global matFilePath matFileName channelSettingsFilePath
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
    global timeSlider menu_visible filterSettings
    
    global data_loaded
    global SettingsFilepath
    global csd_smooth_coef csd_contrast_coef
    global autodetection_settings
    global show_power power_window % для мощности
    global lfpVar windowSize
    global timeCenterPopup
    global event_title_string evfilename eventDeleteEdit
    global art_rem_window_ms
    global stimShowFlag 
    global lines_and_styles
    global keyboardpressed previousKey
    global ica_flag pca_flag
    
    global numChannels % число каналов
    global tableData
    
    global channelTable % отображаемые данные о каналах
    
    global channelNames % названия каналов
    global channelEnabled % вкл/выкл каналы
    global scalingCoefficients % множитель амплитуды
    global colorsIn % цвет линии
    global lineCoefficients % толщина линии
    global mean_group_ch % каналы учавствующие в усреднении
    global csd_avaliable % каналы которые показывают CSD
    global filter_avaliable % каналы к которым применяется фильтрация
    
    global t_mean_profile
    
    t_mean_profile = 0;
    
    ica_flag = false;
    pca_flag = false;
    previousKey = '';
    keyboardpressed = false;

    
    lines_and_styles = struct(...
        'stimulus_lines', struct(...
            'Name', 'Line 1', ...
            'LineColor', 'b', ...
            'LineStyle', '-', ...
            'LineWidth', 2, ...
            'LabelText', 'stimuli', ...
            'LabelColor', 'b', ...
            'LabelFontSize', 10, ...
            'LabelBackgroundColor', 'y', ...
            'LabelFontWeight', 'normal' ...
        ), ...
        'events_lines', struct(...
            'Name', 'Line 2', ...
            'LineColor', 'r', ...
            'LineStyle', '--', ...
            'LineWidth', 2, ...
            'LabelText', 'event', ...
            'LabelColor', 'r', ...
            'LabelFontSize', 10, ...
            'LabelBackgroundColor', 'y', ...
            'LabelFontWeight', 'bold' ...
        )...
    );


    
    matFileName = '';
    
    stimShowFlag = true;
    
    art_rem_window_ms = 0;
    
    csd_smooth_coef = 5;
    
    event_title_string = 'Events';
    csd_contrast_coef = 99.9;
    
    show_power = false;
    power_window = 0.025;% 25 милисекунд   
    
    data_loaded = false;
    menu_visible = false;
    file_menu_visible = false;
    view_menu_visible = false;
    analysis_menu_visible = false;
    
    binsize = 0.001;%s
    show_spikes = false;
    show_CSD = false;
    std_coef = 0;
    time_back = 0.6;
    time_forward = 0.6;
    
    stims = [];
    stim_inx = 1;
    
    events = [];
    event_inx = 1;
    event_comments = {};
    
    min_scale_coef = 0.8;
    base_figure_position = [20 60 1280 650]*min_scale_coef;

    
    % добавляем возможность вызвать функцию извне
    global event_calling outside_calling_filepath zav_calling table_calling 
    global call_mean_events call_csd call_closeall zav_saving 
    global call_resetMainWindowButtons call_updateTable
    global call_setStandardChannelSettings
    
    zav_calling = @loadMatFile;
    zav_saving = @saveMatFile;
    table_calling = @UpdateEventTable;
    event_calling = @loadEvents;
    outside_calling_filepath = [];
    call_mean_events = @meanEventsCallback;
    call_csd = @ShowCSDButtonCallback;
    call_closeall = @closeAllButOne;
    call_resetMainWindowButtons = @resetMainWindowButtons;
    call_updateTable = @updateTable;
    call_setStandardChannelSettings = @setStandardChannelSettings;
    
    % Загрузка списка последних файлов
    SettingsFilepath = fullfile(tempdir, 'ev_settings.mat');
    loadLastOpenedFiles()
    function loadLastOpenedFiles()
        if exist(SettingsFilepath, 'file')
            d = load(SettingsFilepath);
            lastOpenedFiles = d.lastOpenedFiles;
            figure_position = d.figure_position;
            if ~isempty(lastOpenedFiles)
                matFilePath = lastOpenedFiles{end};
                [~, matFileName, ~] = fileparts(matFilePath);
            else
                matFilePath = '';
            end
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
            % размер окна очистки артефакта
            if isfield(d, 'art_rem_window_ms')
                art_rem_window_ms = d.art_rem_window_ms;
            else
                art_rem_window_ms = 0;
            end
            % настройки стиля линей
            if isfield(d, 'lines_and_styles')
                lines_and_styles = d.lines_and_styles;
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
            art_rem_window_ms = 0;
            save(SettingsFilepath, 'lastOpenedFiles', 'figure_position', ...
                'add_event_settings', 'timeUnitFactor', 'selectedUnit', ...
                'art_rem_window_ms', 'lines_and_styles');
        end
        
    end

    %% координаты графических элементов
    
    
    scaleX = figure_position(3) / base_figure_position(3);
    scaleY = figure_position(4) / base_figure_position(4);
    scaling_matrix = [scaleX, scaleY, scaleX, scaleY];
    
    file_menu_coords = [3, 528, 150, 100].*scaling_matrix*min_scale_coef;
    file_btn_coords = [3, 628, 150, 20].*scaling_matrix*min_scale_coef;    
    
    view_menu_coords = [153, 528, 150, 100].*scaling_matrix*min_scale_coef;
    view_btn_coords = [153, 628, 150, 20].*scaling_matrix*min_scale_coef;
    
    opt_menu_coords = [303, 528, 150, 100].*scaling_matrix*min_scale_coef;
    option_btn_coords = [303, 628, 150, 20].*scaling_matrix*min_scale_coef;
    
    analysis_menu_coords = [453, 528, 150, 100].*scaling_matrix*min_scale_coef;
    analysis_btn_coords = [453, 628, 150, 20].*scaling_matrix*min_scale_coef;
    
    % Side panel
    channelTable_coords = [10, 27, 300, 370].*scaling_matrix*min_scale_coef;
    LoadSettingsBtn_coords = [10, 5, 120, 20].*scaling_matrix*min_scale_coef;
    
    % Event panel
    EventsTableTitle_coords = [10, 177, 200, 20].*scaling_matrix*min_scale_coef;
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
    
    showCSDbutton_coords = [720, 55, 50, 30].*scaling_matrix*min_scale_coef;
    
    showSpikesButton_coords = [775, 55, 50, 30].*scaling_matrix*min_scale_coef; 
    stdCoefEdit_coords = [775, 5, 40, 30].*scaling_matrix*min_scale_coef;       
    stdCoefText_coords = [755, 35, 80, 15].*scaling_matrix*min_scale_coef;    
    
    showPowerButton_coords = [840, 55, 50, 30].*scaling_matrix*min_scale_coef;
    powerWindow_coords = [840, 5, 40, 30].*scaling_matrix*min_scale_coef;
    powerText_coords = [815, 35, 90, 15].*scaling_matrix*min_scale_coef;
    
    previousbutton_coords = [305, 10, 100, 30].*scaling_matrix*min_scale_coef;
    nextbutton_coords = [415, 10, 100, 30].*scaling_matrix*min_scale_coef;
    
    shiftCoeffEdit_coords = [650, 10, 50, 30].*scaling_matrix*min_scale_coef;
    FsCoeffEdit_coords = [650, 50, 50, 30].*scaling_matrix*min_scale_coef;
    FsText_coords = [600, 43, 80, 30].*scaling_matrix*min_scale_coef;
    shiftCoefText_coords = [598, 3, 60, 30].*scaling_matrix*min_scale_coef;
    
    
    LoadMatFileBtn_coords = [10, 40, 120, 30].*scaling_matrix*min_scale_coef;
    TimeWindowText_coords = [165, 42, 100, 30].*scaling_matrix*min_scale_coef;
    BeforeText_coords = [165, 27, 50, 30].*scaling_matrix*min_scale_coef;
    AfterText_coords = [220, 27, 50, 30].*scaling_matrix*min_scale_coef;
    
    % Конец координат графических элементов
        %%
    function saveSettings()
        figure_position = f.Position;
        save(SettingsFilepath, 'lastOpenedFiles', 'figure_position', 'add_event_settings', '-append');
    end

    % Создание таймера
    timer('TimerFcn', @resetParametersCallback, 'StartDelay', 1, 'ExecutionMode', 'singleShot');
    
    % Создание фигуры и панелей
    f = figure('Name', ['Easy Viewer v' EV_version], ...
           'NumberTitle', 'off',...
           'MenuBar', 'none', ... % Отключение стандартного меню
           'ToolBar', 'none', ...
           'Tag', 'EasyViwerFigure', ...
           'KeyPressFcn', @keyPressFunction);
    
    
    f.Position = figure_position;
    
    mainPanel = uipanel('Parent', f, 'Position', [.01 .01 .7 .13]);
    multiax_position_a = [0.07    0.2    0.63    0.74];
    multiax_position_b = [0.07    0.2    0.9    0.74];
    multiax = axes('Position', multiax_position_a);
    set(multiax,'TickLabelInterpreter','none')
    
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
    EventsTableTitle = uicontrol('Parent', eventPanel, 'Style', 'text', 'String', event_title_string, ...
              'Position', EventsTableTitle_coords, ...
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
    btnIcon(LoadMatFileBtn, [icons_path, '\open-file.png'], false) % ставим иконку для кнопки
    
    % Кнопка для менеджера файлов
    FMbutton = uicontrol('Parent', mainPanel, 'Style', 'pushbutton', 'String', 'File Manager', 'Position', FMbutton_coords, 'Callback', @fileManagerBtnClb);
    btnIcon(FMbutton, [icons_path, '\file manager.png'], false) % ставим иконку для кнопки
    
    % Поля для выбора временного окна
    TimeWindowText = uicontrol('Parent', mainPanel, 'Style', 'text', 'String', ['Time Window, ' selectedUnit ':'] , 'Position', TimeWindowText_coords);
    BeforeText = uicontrol('Parent', mainPanel, 'Style', 'text', 'String', 'before', 'Position', BeforeText_coords);
    AfterText = uicontrol('Parent', mainPanel, 'Style', 'text', 'String', 'after', 'Position', AfterText_coords);
    timeBackEdit = uicontrol('Parent', mainPanel, 'Style', 'edit', 'String', num2str(time_back*timeUnitFactor), 'Position', timeBackEdit_coords, 'Callback', @timeBackEditCallback);
    timeForwardEdit = uicontrol('Parent', mainPanel, 'Style', 'edit', 'String', num2str(time_forward*timeUnitFactor), 'Position', timeForwardEdit_coords, 'Callback', @timeForwardEditCallback);

    % Spikes
    % STD
    stdCoefEdit = uicontrol('Parent', mainPanel, 'Style', 'edit', 'String', num2str(std_coef), 'Position', stdCoefEdit_coords, 'Callback', @StdCoefCallback);
    stdCoefText = uicontrol('Parent', mainPanel, 'Style', 'text', 'String', 'MUA coef:', 'Position', stdCoefText_coords);
    
    showSpikesButton = uicontrol('Parent', mainPanel, 'Style', 'checkbox', 'String', 'MUA', 'Position', showSpikesButton_coords, 'Callback', @ShowSpikesButtonCallback);
    showCSDbutton = uicontrol('Parent', mainPanel, 'Style', 'checkbox', 'String', 'CSD', 'Position', showCSDbutton_coords, 'Callback', @ShowCSDButtonCallback);
    
    showPowerButton = uicontrol('Parent', mainPanel, 'Style', 'checkbox', 'String', 'Power', 'Position', showPowerButton_coords, 'Callback', @ShowPowerButtonCallback);
    powerWindow = uicontrol('Parent', mainPanel, 'Style', 'edit', 'String', num2str(power_window*timeUnitFactor), 'Position', powerWindow_coords, 'Callback', @powerWindowCallback);
    powerText = uicontrol('Parent', mainPanel, 'Style', 'text', 'String', ['Window, ' selectedUnit ':'], 'Position', powerText_coords);
    
    % Кнопки для навигации по времени
    previousbutton = uicontrol('Parent', mainPanel, 'Style', 'pushbutton', 'String', 'Previous', 'Position', previousbutton_coords, 'Callback', {@shiftTime, -1, timeForwardEdit});
    nextbutton = uicontrol('Parent', mainPanel, 'Style', 'pushbutton', 'String', 'Next', 'Position', nextbutton_coords, 'Callback', {@shiftTime, 1, timeForwardEdit});

    % Окошко для выбора размера shiftCoeff
    shiftCoefText = uicontrol('Parent', mainPanel, 'Style', 'text', 'String', 'Ch. Shift:', 'Position', shiftCoefText_coords);
    shiftCoeffEdit = uicontrol('Parent', mainPanel, 'Style', 'edit', 'String', '200', 'Position', shiftCoeffEdit_coords, 'Callback', @shiftCoeffEditCallback);

    % Окошко для выбора частоты дискретизации
    FsText = uicontrol('Parent', mainPanel, 'Style', 'text', 'String', 'Fs:', 'Position', FsText_coords);
    FsCoeffEdit = uicontrol('Parent', mainPanel, 'Style', 'edit', 'String', '1000', 'Position', FsCoeffEdit_coords, 'Callback', @FsCoeffEditCallback);
    
    %% Выпадающие меню
    analysis_functions = {'Auto Event Detection',...
        '',...
        'Z-score',...
        '',...
        'Spectral Density', ...
        '', ...
        'Cross-Correlation Between Channels', ...
        '', ...
        'Cross-Correlation Between Events', ...
        '', ...
        'ICA', ...
        'PCA', ...
        'Data operations'};
    
    % Создание выпадающего списка
    analysis_menu = uicontrol('Style', 'listbox',...
        'String', analysis_functions,...
        'Visible', 'off', ...
        'Position', analysis_menu_coords,...
        'Callback', @AnalysisMenuSelectionCallback);
    % Создание кнопки для активации выпадающего списка
    analysisBtn = uicontrol('Style', 'pushbutton', 'String', 'Analysis',...
        'Visible', 'on', ...
        'Position', analysis_btn_coords,...
        'Callback', @showAnalysisMenu);       
    
    % Список действий
    file_functions = {'open ZAV(.mat) file', ...
        'open event (.ev) file',...
        'save ZAV(.mat) file', ...
        'file manager', ...
        'open figure', ...
        'convert ABF', ...
        'convert NLX', ...
        'convert Open Ephys', ...
        'save figure snapshot', ...
        'compare average data', ...
        'import events from stimulus',...
        'import data from ZAV(.mat) file'};
        
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
        'hide Channel Settings', ...
        '', ...
        'hide stimulus', ...
        '', ...
        'lines and styles', ...
        '', ...
        'CSD displaying'};
          
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
    options = {'Manual events settings',...
        '',...
        'Removal of Artifacts',...
        '', ...
        'Average subtraction', ...
        '', ...
        'Filtering', ...
        '',...
        'Edit stimulus times', ...
        '', ...
        'Mean Events'};    
   
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

                % Конец выпадающих меню
    %%
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
    eventDeleteEdit = uicontrol('Parent', eventPanel, 'Style', 'edit', 'Position', eventDeleteEdit_coords, 'Callback', @eventEdited);

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
    set(viewBtn, 'Enable', 'off');
    set(analysisBtn, 'Enable', 'off');
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

    % Закрываем все фигуры, кроме EasyViewer
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
        
        set(analysis_menu, 'Visible', 'off'); % Скрыть меню
        analysis_menu_visible = false;
        
        catch
            disp('bravo 5')
        end
    end

    function AnalysisMenuSelectionCallback(src, ~)
        val = src.Value;
        str = src.String;
        selectedOption = str{val};
        dont_close_menu = false;
        
        switch selectedOption            
            case analysis_functions{1}% Auto event detection
                openAutoEventDetectionWindow();
            case analysis_functions{3} 
                ZScoreGUI();
%                 ICAazGUI();  
            case analysis_functions{5}
                % отображение спектральной плотности текущего сигнала
                spectralDensityGUI();  
            case analysis_functions{7}
                chCossCorrelationGUI();
            case analysis_functions{9}
                eventCrossCorrelationGUI();
            case analysis_functions{11}% ICA анализ  
                ICAazGUI();
            case analysis_functions{12}% PCA analysis
                PCAazGUI();
            case analysis_functions{13}
                performChannelOperations();
            case ''
                dont_close_menu = true;
        end    
        disp(selectedOption);        
        if ~dont_close_menu
            resetGraphParameters()
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
            case file_functions{3}
                saveMatFile(matFilePath);
            case file_functions{4}
                % открытие менеджера файлов
                fileManagerBtnClb([], []);
            case file_functions{5}
                openFigureWithFileDialog();
            case file_functions{6}
                convertAbf2zavGUI()
            case file_functions{7}
                % конвертация в ZAV формат
                convertNlx2zavGUI();
            case file_functions{8}    
                convertOEP2zavGUI();
            case file_functions{9}
                % save figure snapshot
                saveMainAxisAs();
            case file_functions{10}
                % сравнение средних данных
                dataComparerApp();
            case file_functions{11}
                importEventsFromSimulus();
            case file_functions{12}
                importLFP();
            case ''
                dont_close_menu = true;
        end
        disp(selectedOption);
        if ~dont_close_menu
            resetGraphParameters()
        end
    end


    function importEventsFromSimulus()
        if not(isempty(stims))
            
            importEventsFromSimulusGUI()
            
            if not(isempty(events))
                sliderValue = get(timeSlider, 'Value'); % Текущее значение слайдера
                event_inx = ClosestIndex(sliderValue, events);% Индекс текущего эвента во времени
                event_comments = repmat({'...'}, numel(events), 1); % Инициализация комментариев
                event_title_string = [matFileName, ' stimulus imported'];
                evfilename = matFileName;
                events_exist = true;
                set(timeCenterPopup, 'Value', 3);
                changeTimeCenter(timeCenterPopup);
                UpdateEventTable();
                updatePlot();
            end
        end
    end

    function saveMainAxisAs()
        
        [mat_file_folder, figure_name, ~] = fileparts(matFilePath);
        
        [file, path, filterindex] = uiputfile(...
            {'*.pdf', 'PDF files (*.pdf)';...
             '*.eps', 'EPS files (*.eps)';...
             '*.png', 'PNG files (*.png)';...
             '*.*', 'All Files (*.*)'},...
             'Save file name', [mat_file_folder '/' figure_name]);
        if isequal(file,0) || isequal(path,0)
           disp('User pressed cancel');
        else
           filename = fullfile(path, file);      
           switch filterindex
               case 1
                   print(f, filename, '-dpdf', '-bestfit');
               case 2
                   print(f, filename, '-depsc');
               case 3
                   saveas(f, filename, 'png');
               otherwise
                   saveas(f, filename);
           end
           disp(['Image saved to ', filename]);
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
            case view_functions{5}
                showHideStimulus()
            case view_functions{7}
                lineStyleGUI()
            case view_functions{9}%'CSD ...'
                % вызов функции для CSD ...
                CSDfigSettings();
                updateTable();
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
            case options{3}
                optionsRemovalArtifactsGUI();                       
            case options{5} %'Subtract mean ...'
                % вызов функции для Subtract mean ...
                SubMeanFigSettings();
                updateTable();
            case options{7}%'Filtering ...'
                setupSignalFilteringGUI(); 
                updateTable();            
            case options{9}
                editStimTimes();
            case options{11}%'Mean Events'    
                setupMeanEventsGUI();
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

    function showHideStimulus()
        
        if stimShowFlag
            disp('Hiding Stimulus')
            str_out = 'show stimulus';
        else
            disp('Showing Stimulus')
            str_out = 'hide stimulus';
        end
        
        view_functions{5} = str_out;
        set(view_menu, 'String', view_functions);
        stimShowFlag = ~stimShowFlag;
        
        updatePlot()
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
    function showAnalysisMenu(~, ~)
        if analysis_menu_visible
            set(analysis_menu, 'Visible', 'off'); % Убрать меню
        else
            set(analysis_menu, 'Visible', 'on'); % Показать меню
        end
        analysis_menu_visible = not(analysis_menu_visible);
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

        
        
        set(opt_menu, 'Position', opt_menu_coords .*scaling_matrix);
        set(file_menu, 'Position', file_menu_coords .*scaling_matrix);
        set(view_menu, 'Position', view_menu_coords .*scaling_matrix);
        set(analysis_menu, 'Position', analysis_menu_coords .*scaling_matrix);  
        
        set(OptBtn, 'Position', option_btn_coords .*scaling_matrix);
        set(fileBtn, 'Position', file_btn_coords .*scaling_matrix);        
        set(viewBtn, 'Position', view_btn_coords .*scaling_matrix);
        set(analysisBtn, 'Position', analysis_btn_coords .*scaling_matrix);
        
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
        
        set(powerWindow, 'Position', powerWindow_coords .* scaling_matrix);
        set(powerText, 'Position', powerText_coords .* scaling_matrix);
        
        set(showSpikesButton, 'Position', showSpikesButton_coords .* scaling_matrix);
        set(showPowerButton, 'Position', showPowerButton_coords .* scaling_matrix);        
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
        set(EventsTableTitle, 'Position', EventsTableTitle_coords .* scaling_matrix);
        set(LoadMatFileBtn, 'Position', LoadMatFileBtn_coords .* scaling_matrix);
        set(TimeWindowText, 'Position', TimeWindowText_coords .* scaling_matrix);
        set(BeforeText, 'Position', BeforeText_coords .* scaling_matrix);
        set(AfterText, 'Position', AfterText_coords .* scaling_matrix);
    end


    function openAutoEventDetectionWindow(~, ~)
        autoEventDetectionGUI();
    end
        
    % Nested function to check key press
    function check_key_press(~, ~)
%         drawnow; % Process GUI events
        key = get(f, 'CurrentCharacter');
        if ~isempty(key)
            disp(['Key pressed: ', key]);
%             set(gcf, 'CurrentCharacter', ''); % Reset current character
        end
    end

    % Функция обработки нажатия клавиш
    function keyPressFunction(src, event)
%         disp('key pressed:')
%         disp(event.Key)
        % Если кнопка уже была нажата - блокируем исполнение
        if keyboardpressed
           return;
        end
        
        switch event.Key            
            case 'leftarrow'
                shiftTime(src, [], -1, timeForwardEdit); % Или вызов Callback функции previousButton
            case 'rightarrow'
                shiftTime(src, [], 1, timeForwardEdit); % Или вызов Callback функции nextButton
            case 'delete'
                deleteEvent();
        end
        
%         previousKey = event.Key
    end
%% Построение среднего графика
    function meanEventsCallback(~, ~)
        calculateAndPlotMeanEvents();
    end
%%

    function shiftCoeffEditCallback(src, ~)
        newShiftCoeff = str2double(get(src, 'String'));
        if isnan(newShiftCoeff) || newShiftCoeff <= 0
            uiwait(errordlg('Invalid Shift Coeff Value'));
            return;
        end
        shiftCoeff = newShiftCoeff;
        saveChannelSettings();
        updatePlot(); % Обновление графика с новым shiftCoeff
    end

    function FsCoeffEditCallback(src, ~)
        newFsCoeff = str2double(get(src, 'String'));
        if isnan(newFsCoeff) || newFsCoeff <= 0
            uiwait(errordlg('Invalid Fs Value'));
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

    % power coef
    function powerWindowCallback(src, ~)
        power_window = str2double(get(src, 'String'))/timeUnitFactor;
        updatePlot(); % Обновление графика
    end

    function ShowSpikesButtonCallback(~, ~)
        show_spikes = not(show_spikes);
        set(showSpikesButton, 'Value', show_spikes);
        updatePlot(); % Обновление графика
    end

    function ShowPowerButtonCallback(~, ~)
        show_power = not(show_power);
        set(showPowerButton, 'Value', show_power);
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
%         disp('time edited')
        windowSize = str2double(get(src, 'String'))/timeUnitFactor;% time_forward - в секундах
        time_forward = windowSize;
        if isnan(windowSize) || windowSize <= 0
            uiwait(errordlg('Invalid time window size.'));
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
        set(powerWindow, 'String', num2str(power_window*timeUnitFactor));
        
        set(TimeWindowText, 'String', ['Time Window, ' selectedUnit ':']);
        set(powerText, 'String', ['Window, ' selectedUnit ':']);
        
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
        if exist(matFilePath, 'file') == 2
            % если мат файл существует, 
            % это не просто промежуточные варианты, как ICA,
            % то сохранять настройки

            [path, name, ~] = fileparts(matFilePath);
            channelSettingsFilePath = fullfile(path, [name '_channelSettings.stn']);
            channelSettings = get(channelTable, 'Data');
            save(channelSettingsFilePath, ...
                'channelSettings', ...% для версии начиная с 1.10.00 не актуален как хранитель данных
                'newFs', ...
                'shiftCoeff', ...
                'time_forward', ...
                'time_back', ...
                'filterSettings', ...
                'csd_smooth_coef', ...
                'csd_contrast_coef', ...
                'channelNames', ...% (*) - начиная с 1.10.00 заменяет собой channelSettings
                'channelEnabled', ...%(*)
                'scalingCoefficients', ...%(*)
                'colorsIn', ...%(*)
                'lineCoefficients', ...%(*)
                'mean_group_ch', ...%(*)
                'csd_avaliable', ...%(*)
                'filter_avaliable', ...
                'EV_version');%(*)
        end
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
        
        if not(isempty(events))
            event_inx = ClosestIndex(sliderValue, events);
            set(eventDeleteEdit, 'String', num2str(event_inx));  
        end
        
        updatePlot(); % Обновление графика
    end

    % Функция для обновления данных на основе выбора в таблице
    function updateChannelSelection(~, ~)
        % Получение данных из таблицы
        updatedData = get(channelTable, 'Data');
        
        channelNames = updatedData(:, 1)';% имена каналов
        channelEnabled = [updatedData{:, 2}];
        scalingCoefficients = [updatedData{:, 3}];
        colorsIn = updatedData(:, 4)';
        lineCoefficients = [updatedData{:, 5}];
        mean_group_ch = [updatedData{:, 6}];% каналы учавствующие в усреднении
        csd_avaliable = [updatedData{:, 7}];% каналы которые показывают CSD
        filter_avaliable  = [updatedData{:, 8}];%каналы к которым применяется фильтрация

        updateLocalCoefs()% локальные аналоги для текущего учаска времени

        saveChannelSettings();

        updatePlot(); % Обновление графика
    end

    function updateLocalCoefs()
        ch_inxs = find(channelEnabled); % Индексы активированных каналов
        m_coef = np_flatten(scalingCoefficients(ch_inxs));% Обновленные коэффициенты масштабирования
        ch_labels_l = channelNames(ch_inxs);
        colors_in_l = colorsIn(ch_inxs);
        widths_in_l = lineCoefficients(ch_inxs);
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
        event_title_string = 'Events';
        UpdateEventTable();
        event_inx = 1;
        
        set(eventDeleteEdit, 'String', num2str(event_inx));   
        
        saveSettings();
        
        data_loaded = true;
        
        
    end
    
    function saveMatFile(filepath)
        % Get initial path and file name from the provided filepath
        if nargin < 1
            filepath = ''; % Default to empty if no filepath is provided
        end

        % Split the filepath into path and file name components
        [initialPath, initialFile, ext] = fileparts(filepath);
        if isempty(ext)
            ext = '.mat'; % Default extension if none provided
        end

        % Open a file save dialog with initial path and file name
        [file, path] = uiputfile(['*' ext], 'Save ZAV (.mat) File', fullfile(initialPath, [initialFile ext]));
        if isequal(file, 0) || isequal(path, 0)
            disp('User canceled the operation');
            return;
        end
        filepath = fullfile(path, file);

        % Extract the file name without extension
        [~, matFileName, ~] = fileparts(filepath);
        disp(['Saving mat file: ' matFileName]);
        
        % записываем отредактированные стимулы
        zavp.realStim = struct('r', stims'/zavp.siS);
        
        
        % Save the variables to the specified file
        save(filepath, 'spks', 'lfp', 'hd', 'zavp', 'chnlGrp', 'lfpVar');
        
        % Сохраняем настройки каналов
        saveChannelSettings()
    end



    function loadMatFile(filepath)
        disp('loading mat file:')
        ica_flag = false;
        pca_flag = false;
        
        windowSize = str2double(get(timeForwardEdit, 'String'))/timeUnitFactor;% должен быть в секундах
        

        % если идет вызов снаружи
        if ~isempty(outside_calling_filepath)
            filepath = outside_calling_filepath;
            outside_calling_filepath = [];          
        end
        
         % Сохранение пути к загруженному .mat файлу
        matFilePath = filepath;        
        [~, matFileName, ~] = fileparts(matFilePath);
        disp(matFileName)       
        
        d = load(filepath); % Загружаем данные в структуру
        spks = d.spks;
        lfp = d.lfp;
        hd = d.hd;
        Fs = d.zavp.dwnSmplFrq;
        zavp = d.zavp;
        lfpVar = d.lfpVar;
        chnlGrp = d.chnlGrp;
        
        [m, n, p] = size(lfp);  % получение размеров исходной матрицы
        
        if p > 1 % случай со свипами
            [lfp, spks, stims, lfpVar] = sweepProcessData(p, spks, n, m, lfp, Fs, zavp, lfpVar);  
            stims_exist = ~isempty(stims);
        else
            if isfield(zavp, 'realStim') 
                stims = zavp.realStim(:).r(:) * zavp.siS;  
                stims_exist = ~isempty(stims);
            else
                stims = [];
                stims_exist = false;
            end
        end
                
        N = size(lfp, 1);
        
        
        
        time = (0:N-1) / Fs;% s
        time_forward = 0.6;
        time_back = 0.6;        
        chosen_time_interval = [0, time_forward];
        shiftCoeff = 200;
        newFs = 1000;
        selectedCenter = 'time';
        stim_inx = 1;        
        show_spikes = false;
        show_CSD = false;
        channelNames = hd.recChNames;
        numChannels = length(channelNames);
        
        resetMainWindowButtons()
        

        
        % Обновление и сохранение списка последних открытых файлов
        lastOpenedFiles{end + 1} = filepath;
        
        % Попытка загрузить настройки каналов
        loadChannelSettings();    
    end

    function resetMainWindowButtons()
        
        % разрешение опций
        set(OptBtn, 'Enable', 'on');
        set(viewBtn, 'Enable', 'on');
        set(analysisBtn, 'Enable', 'on');
        
        set(showSpikesButton, 'Value', show_spikes);
        set(showCSDbutton, 'Value', show_CSD);
        set(timeCenterPopup, 'Value', 1);
        set(timeBackEdit, 'String', num2str(time_back*timeUnitFactor));% time window before
        set(timeForwardEdit, 'String', num2str(time_forward*timeUnitFactor));% time window after
        set(shiftCoeffEdit, 'String', num2str(shiftCoeff));
        set(FsCoeffEdit, 'String', num2str(newFs));
        
        % Обновление максимального значения слайдера
        set(timeSlider, 'Max', time(end));
        
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

    function updateTable()
        tableData = [np_flatten(channelNames); ...
        np_flatten(num2cell(channelEnabled));...
        np_flatten(num2cell(scalingCoefficients)); ...
        np_flatten(colorsIn); ...
        np_flatten(num2cell(lineCoefficients)); ...
        np_flatten(num2cell(mean_group_ch)); ...
        np_flatten(num2cell(csd_avaliable));...
        np_flatten(num2cell(filter_avaliable))]';

        set(channelTable, 'Data', tableData, ... % Обновляем данные в таблице
                   'ColumnName', {'Channel', 'Enabled', 'Scale', 'Color', 'Line Width', 'Averaging', 'CSD', 'Filter'}, ...
                   'ColumnFormat', {'char', 'logical', 'numeric', 'char', 'numeric', 'logical', 'logical', 'logical'}, ...
                   'ColumnEditable', [false true true true true true true true]);
        
        updateLocalCoefs()
    end

% Функция загрузки настроек из файла
function loadSettingsFile()
    try
        loadedSettings = load(channelSettingsFilePath, '-mat');
        if isfield(loadedSettings, 'EV_version') % работает с 1.10.00  
            channelNames = np_flatten(loadedSettings.channelNames);
            channelEnabled  = np_flatten(loadedSettings.channelEnabled);
            scalingCoefficients  = np_flatten(loadedSettings.scalingCoefficients);
            colorsIn = np_flatten(loadedSettings.colorsIn);
            lineCoefficients = np_flatten(loadedSettings.lineCoefficients);
            mean_group_ch = np_flatten(loadedSettings.mean_group_ch);
            csd_avaliable = np_flatten(loadedSettings.csd_avaliable);
            filter_avaliable = np_flatten(loadedSettings.filter_avaliable);
        else % неактуально с 1.10.00  
            warning('Old settings')
            % Получение данных из таблицы
            updatedData = loadedSettings.channelSettings;

            channelNames = updatedData(:, 1)';
            channelEnabled = [updatedData{:, 2}];
            scalingCoefficients = [updatedData{:, 3}];
            colorsIn = updatedData(:, 4)';
            lineCoefficients = [updatedData{:, 5}];
            
            mean_group_ch = np_flatten(loadedSettings.mean_group_ch);
            csd_avaliable = np_flatten(loadedSettings.csd_avaliable);
            filter_avaliable = np_flatten(loadedSettings.filter_avaliable);
        end
        updateTable();

        if isfield(loadedSettings, 'filterSettings') && ~(isempty(loadedSettings.filterSettings))
            filterSettings = loadedSettings.filterSettings;
        else % если настройки старые                
            filterSettings.filterType = 'highpass';
            filterSettings.freqLow = 10;
            filterSettings.freqHigh = 50;
            filterSettings.order = 4;
            filterSettings.channelsToFilter = false(numChannels, 1); % Ни один канал не участвует в фильтрации
            disp('settings were without filterSettings')
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
            time_back = loadedSettings.time_back; % time window before (s)
            set(timeBackEdit, 'String', num2str(time_back * timeUnitFactor));
        end
        if isfield(loadedSettings, 'time_forward')
            time_forward = loadedSettings.time_forward; % time window after (s)
            chosen_time_interval = [0, time_forward];
            set(timeForwardEdit, 'String', num2str(time_forward * timeUnitFactor));
        end

        if isfield(loadedSettings, 'csd_smooth_coef')
            csd_smooth_coef = loadedSettings.csd_smooth_coef;
        else
            csd_smooth_coef = 5;
            disp('settings were without CSD smooth coef')
        end
        if isfield(loadedSettings, 'csd_contrast_coef')
            csd_contrast_coef = loadedSettings.csd_contrast_coef;
        else
            csd_contrast_coef = 99.99;
            disp('settings were without CSD contrast coef')
        end
    catch
        createNewChoice = questdlg('An error occurred when loading channel settings. Do you want to create new channel settings file?', ...
            'Save Results', ...
            'Yes', 'No', 'Yes');
        if strcmp(createNewChoice, 'Yes')
            createNewSettingsFile();
        end
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
        else % если не было настроек создаем новый файл с настройками
            warning('Could not find Settings (.stn) file')
            createNewSettingsFile()
        end
        
    end
    
    function createNewSettingsFile()
            % Подготовка данных для таблицы каналов            
            setStandardChannelSettings()
            updateTable();
            saveChannelSettings();
            updatePlot(); % Обновление графика
    end
    
    function setStandardChannelSettings()
            channelNames = np_flatten(channelNames);
            channelEnabled = true(1, numChannels); % Все каналы активированы по умолчанию
            scalingCoefficients = ones(1, numChannels); % Коэффициенты масштабирования по умолчанию
            colorsIn = np_flatten(repmat({'black'}, numChannels, 1)); % Инициализация цветов
            lineCoefficients = ones(1, numChannels)*0.5; % Инициализация толщины линий
            mean_group_ch = false(1, numChannels);% Ни один канал не участвует в усреднении
            csd_avaliable = true(1, numChannels);% Все каналы участвуют в CSD
            filter_avaliable = false(1, numChannels);% Ни один канал не участвует в фильтрации
            
            filterSettings.filterType = 'highpass';
            filterSettings.freqLow = 10;
            filterSettings.freqHigh = 50;
            filterSettings.order = 4;
            filterSettings.channelsToFilter = false(numChannels, 1);% Ни один канал не участвует в фильтрации
    end

    function UpdateEventTable()        
        [events, ev_inxs] = sort(events);
        event_comments = event_comments(ev_inxs);
        eventTable.Data = [num2cell(events*timeUnitFactor), event_comments];
        set(EventsTableTitle, 'String', [event_title_string, ': ', num2str(numel(events))]);
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
                event_title_string = 'Events';
                UpdateEventTable();
                events_exist = false;
                updatePlot();
            case 'No'
                % Do nothing if the user selects 'No'
        end
    end


    function shiftTime(~, ~, direction, timeForwardEdit)
        
        % отключаем возможность использовать клавиатуру
%         set(f, 'KeyPressFcn', '');
        
        if keyboardpressed
           return;
        end
        keyboardpressed = true;
        
%         disp('changed position')
        windowSize = str2double(get(timeForwardEdit, 'String'))/timeUnitFactor;% должен быть в секундах
        switch selectedCenter
            case 'event'
                if events_exist
                    if direction == 1% движение вперед  
%                         disp('event forward')
                        event_inx = event_inx+1;                    
                    else% движение назад 
%                         disp('event back')
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
                    % обновляем активное окно
                    set(eventDeleteEdit, 'String', num2str(event_inx));                    
                end
            case 'stimulus'
                if stims_exist
                    if direction == 1% движение вперед  
%                         disp('stimulus forward')
                        stim_inx = stim_inx+1;                    
                    else% движение назад 
%                         disp('stimulus back')
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
%                 disp('time forward')
                next_step_1 = chosen_time_interval(2);
                next_step_2 = chosen_time_interval(2)+windowSize; 
                
            else% движение назад 
%                 disp('time back')
                next_step_1 = chosen_time_interval(1)-windowSize;
                next_step_2 = next_step_1 + windowSize;
            end
            
            % Обновление интервала времени
            % проверка 
            if ~(next_step_1<0 || next_step_2>time(end)+windowSize)
                chosen_time_interval(1) = next_step_1;
                chosen_time_interval(2) = next_step_2;
            end
        end
        
        keyboardpressed = false;
        updatePlot(); % Обновление графика
        
        % Включаем callback нажатия клавиш
%         set(f, 'KeyPressFcn', @keyPressFunction);
    end
    
    function deleteEvent(~, ~)
        eventIndex = str2double(get(eventDeleteEdit, 'String'));
        if isnan(eventIndex) || eventIndex <= 0 || eventIndex > size(events, 1)
            showErrorDialog('Invalid event index.');
            return;
        end
        % Удаление события
        events(eventIndex) = [];
        event_comments(eventIndex) = [];
        UpdateEventTable();% update event table
        if isempty(events)
            events_exist = false;
        end
        
        if event_inx>numel(events)
            event_inx = numel(events);
        end
        
        if events_exist
            chosen_time_interval(1) = events(event_inx);
            chosen_time_interval(2) = events(event_inx)+windowSize;
        end
        
        updatePlot()
    end

    function eventEdited(~, ~)
        eventIndex = str2double(get(eventDeleteEdit, 'String'));
        if isnan(eventIndex) || eventIndex <= 0 || eventIndex > size(events, 1)
            showErrorDialog('Invalid event index.');
            return;
        else
            event_inx = eventIndex;
        end
        
        if events_exist
            chosen_time_interval(1) = events(event_inx);
            chosen_time_interval(2) = events(event_inx)+windowSize;
        end
        
        updatePlot()
    end


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
        [path,file,ext] = fileparts(outside_calling_filepath);
        file = [file,ext];
        outside_calling_filepath = [];% очищаем наружний путь
    end
    
    loadedData = load(filepath, '-mat'); % Загружаем данные в структуру
    % Если не был загружен mat файл, инициируем поиск
%     [~, matname, ~] = fileparts(matFilePath);
    [~, evfilename, ~] = fileparts(filepath);
    fileName = evfilename(1:19);    
    firstMatFile = findFirstMatFile(path, fileName);
    if ~isempty(firstMatFile)
            loadMatFile(firstMatFile); % Загрузка .mat файла
    end

    
    if isfield(loadedData, 'manlDet')
        events = time(round([loadedData.manlDet.t]))'; % Обновляем таблицу событий
        
        if ~isfield(loadedData, 'event_comments') % если комментариев не было
            event_comments = repmat({'...'}, numel(events), 1); % Инициализация комментариев
        else % если были комментарии
            event_comments = loadedData.event_comments;
        end
        
        event_title_string = file;
        UpdateEventTable();
        events_exist = true;
        event_inx = 1;
        timeForwardEditCallback(timeForwardEdit);
        
        set(timeCenterPopup, 'Value', 3);
        changeTimeCenter(timeCenterPopup);
        
%         updatePlot(); Уже обновили график когда вызывали timeForwardEditCallback
    else
        uiwait(errordlg('No events found in the file.'));
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
        
        clear viewer_data
        viewer_data.matFileName = matFileName;
        viewer_data.autodetection_settings = autodetection_settings;
        viewer_data.add_event_settings = add_event_settings;
        viewer_data.EV_version = EV_version;
        
        save(filepath, 'manlDet', 'event_comments', ...
            'viewer_data'); % Сохранение в .ev файл
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

