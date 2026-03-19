function signalViewerGUI(filePath)
    % Все global объявления должны быть в самом начале функции
    % EV_version и EV_date теперь определены в app.m как глобальные переменные
    global EV_path EV_version EV_date
   
    global Fs N time chosen_time_interval ch_inxs m_coef
    global shiftCoeff eventTable
    global lfp_file hd spks multiax chnlGrp
    
    global matFilePath matFileName channelSettingsFilePath
    global timeUnitFactor selectedUnit
    global initialDir
    global events event_inx events_exist event_comments event_indices
    global event_amplitudes event_channels event_widths event_prominences event_metadata
    global stims stim_inx stims_exist
    global lastOpenedFiles
    global updatedData
    global zavp newFs selectedCenter
    global time_back time_forward
    global figure_position timeForwardEdit
    global std_coef binsize % спайки/CSD
    global ch_labels_l colors_in_l  widths_in_l
    global add_event_settings
    global timeSlider menu_visible filterSettings
    global previousSliderValue % сохраняем предыдущее значение слайдера
    global data_loaded
    global SettingsFilepath
    global csd_smooth_coef csd_contrast_coef
    global autodetection_settings
    global lfpVar windowSize
    global timeCenterPopup
    global event_title_string evfilename eventDeleteEdit StimuliTitle
    global art_rem_settings
    global lines_and_styles
    global auto_open_last_file
    global visualSettings
    global keyboardpressed previousKey
    global plot_updating loading_text_handle % флаг обновления графика и handle текста
    global ica_flag pca_flag
    global autoSetNewFsFromFs % флаг автоматической установки newFs на основе Fs
    global autoSetTimeWindowsFromSweeps % флаг автоматической установки time_back/time_forward на основе свипов
    global slope_measurement_settings % настройки измерения slope
    global stims_loaded_from_settings % флаг загрузки стимулов из настроек
    % Переменные для работы со свипами
    global sweep_info sweep_inx % информация о свипах и индекс текущего свипа
    global numChannels % число каналов
    global tableData
    global channelTable % отображаемые данные о каналах
    global zoomState zoomButton % состояние зума и кнопка зума
    global channelNames % названия каналов
    global channelEnabled % вкл/выкл каналы
    global scalingCoefficients % множитель амплитуды
    global colorsIn % цвет линии
    global lineCoefficients % толщина линии
    global mean_group_ch % каналы учавствующие в усреднении
    global csd_avaliable % каналы которые показывают CSD
    global filter_avaliable % каналы к которым применяется фильтрация
    global baseline_subtract_available % каналы с вычитанием базовой линии
    global t_mean_profile
    global event_calling outside_calling_filepath zav_calling table_calling 
    global call_mean_events call_csd call_closeall zav_saving 
    global call_resetMainWindowButtons call_updateTable
    global call_setStandardChannelSettings
    global saveChannelSettingsFunc
    global updateTableFunc updateLocalCoefsFunc updatePlotFunc
    global event_label_click_callback

    debugState('signalViewerGUI', 'Signal Viewer Started')

    if nargin < 1
        filePath = [];
    end
    
    % Загружаем глобальные настройки (включая инициализацию по умолчанию)
    loadGlobalSettings();
    
    % Загружаем координаты элементов из JSON файла
    coordsFile = getGUIConfigPath('signalViewerGUI_coords.json');
    if exist(coordsFile, 'file')
        coordsData = jsondecode(fileread(coordsFile));
    else
        error('Coordinates file not found: %s', coordsFile);
    end
    
    % Вспомогательная функция для получения координат элемента
    function pos = getElementPosition(tag)
        if isfield(coordsData.elements, tag)
            pos = coordsData.elements.(tag);
            
            % Проверяем, не является ли элемент осью или панелью - для них оставляем относительные координаты
            if ~strcmp(tag, 'main_axes') && ~strcmp(tag, 'multiax') && ...
               ~strcmp(tag, 'main_panel') && ~strcmp(tag, 'side_panel')
                % Преобразуем относительные координаты в абсолютные на основе base_figure_position
                base_pos = coordsData.base_figure_position;
                pos = [
                    pos(1) * base_pos(3),  % x
                    pos(2) * base_pos(4),  % y
                    pos(3) * base_pos(3),  % width
                    pos(4) * base_pos(4)   % height
                ];
            end
        else
            error('Coordinates for element %s not found in JSON file', tag);
        end
    end
    
    t_mean_profile = 0;
    
    ica_flag = false;
    pca_flag = false;
    previousKey = '';
    keyboardpressed = false;
    plot_updating = false;
    loading_text_handle = [];
    previousSliderValue = 0; % инициализация предыдущего значения слайдера
    zoomState = struct( ...
        'await_points', false, ...
        'has_zoom', false, ...
        'points', zeros(0, 2), ...
        'lines', gobjects(0), ...
        'is_panning', false, ...
        'pan_start_point', [0 0], ...
        'pan_start_xlim', [0 0], ...
        'pan_start_ylim', [0 0]);
    zoomButton = [];
    add_event_pending = false;
    
    % Инициализация настроек slope measurement
    slope_measurement_settings = struct();
    slope_measurement_settings.channel = 1;
    slope_measurement_settings.baseline_start = 0;
    slope_measurement_settings.baseline_end = 0;
    slope_measurement_settings.peak_start = 0;
    slope_measurement_settings.peak_end = 0;
    slope_measurement_settings.slope_percent = 20;
    slope_measurement_settings.peak_polarity = 'positive';

    
    % Инициализируем lines_and_styles только если они не были загружены из настроек
    if isempty(lines_and_styles) || ~isfield(lines_and_styles, 'stimulus_lines') || ~isfield(lines_and_styles, 'events_lines')
        lines_and_styles = struct(...
            'stimulus_lines', struct(...
                'Name', 'Line 1', ...
                'LineColor', 'b', ...
                'LineStyle', '-', ...
                'LineWidth', 2, ...
                'LineAlpha', 1, ...
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
                'LineAlpha', 1, ...
                'LabelText', 'event', ...
                'LabelColor', 'r', ...
                'LabelFontSize', 10, ...
                'LabelBackgroundColor', 'y', ...
                'LabelFontWeight', 'bold' ...
            )...
        );
    end


    
    matFileName = '';
    
    visualSettings.stim_show = true;
    
    
    csd_smooth_coef = 5;
    
    event_title_string = 'Events';
    csd_contrast_coef = 99.9;
    
    data_loaded = false;
    autoSetNewFsFromFs = true; % по умолчанию включен автоматический расчет newFs
    autoSetTimeWindowsFromSweeps = true; % по умолчанию включен автоматический расчет временных окон на основе свипов
    stims_loaded_from_settings = false; % флаг загрузки стимулов из настроек
    menu_visible = false;
    file_menu_visible = false;
    view_menu_visible = false;
    analysis_menu_visible = false;
    help_menu_visible = false;
    
    binsize = 0.001;%s
    visualSettings.show_spikes = false;
    visualSettings.show_CSD = false;
    if ~isfield(visualSettings, 'events_show')
        visualSettings.events_show = true;
    end
    std_coef = 0;
    time_back = 0.6;
    time_forward = 0.6;
    
    stims = [];
    stim_inx = 1;
    
    events = [];
    event_indices = [];
    event_inx = 1;
    selected_event_rows = [];
    event_comments = {};
    
    % Новые массивы метаданных событий для расширенной функциональности
    event_amplitudes = [];      % Амплитуды событий
    event_channels = [];        % Каналы событий (может быть массив для многоканальных)
    event_widths = [];          % Ширина пиков (для автодетекции)
    event_prominences = [];     % Выраженность пиков (для автодетекции)
    event_metadata = [];        % Структура с полными метаданными каждого события
    
    min_scale_coef = 0.8;
    base_figure_position = [20 60 1280 650]*min_scale_coef;

    figTag = 'SignalViewerGUI';
    delete(findobj('Type', 'figure', 'Tag', 'SignalAnalysisGUI'));
    guiFig = findobj('Type', 'figure', 'Tag', figTag);
    if ~isempty(guiFig)
        if ~isempty(filePath)
            [~, ~, ext] = fileparts(filePath);
            switch lower(ext)
                case '.ev'
                    outside_calling_filepath = filePath;
                    event_calling();
                case {'.mat', '.abf'}
                    zav_calling(filePath);
                    table_calling();
            end
        end
        figure(guiFig);
        return
    end

    % добавляем возможность вызвать функцию извне
    zav_calling = @loadMatFile;
    zav_saving = @saveMatFile;
    table_calling = @UpdateEventTable;
    event_calling = @loadEvents;
    outside_calling_filepath = [];
    call_mean_events = @meanEventsCallback;
    call_csd = @ShowCSDButtonCallback;
    % call_closeall убрано - теперь это делает главное окно app.m
    call_resetMainWindowButtons = @resetMainWindowButtons;
    call_updateTable = @updateTable;
    call_setStandardChannelSettings = @setStandardChannelSettings;
    saveChannelSettingsFunc = @saveChannelSettings;
    
    % Присваиваем функции глобальным переменным для доступа из внешних файлов
    updateTableFunc = @updateTable;
    updateLocalCoefsFunc = @updateLocalCoefs;
    updatePlotFunc = @updatePlot;
    event_label_click_callback = @selectEventByIndex;
    
    % Устанавливаем matFilePath и matFileName из последних открытых файлов
    if ~isempty(lastOpenedFiles)
        matFilePath = lastOpenedFiles{end};
        [~, matFileName, ~] = fileparts(matFilePath);
    else
        matFilePath = '';
        matFileName = '';
    end

    %% координаты графических элементов - теперь загружаются из JSON файла
        %%
    function saveSettings()
        % Не сохраняем положение окна - всегда используем базовое из JSON
        save(SettingsFilepath, 'lastOpenedFiles', 'add_event_settings', '-append');
    end

    % Создание таймера
    timer('TimerFcn', @resetParametersCallback, 'StartDelay', 1, 'ExecutionMode', 'singleShot');
    
    % Создание фигуры и панелей
    f = figure('Name', 'Signal Viewer', ...
           'NumberTitle', 'off',...
           'MenuBar', 'none', ...
           'ToolBar', 'figure', ...
           'Tag', figTag, ...
           'KeyPressFcn', @keyPressFunction);
    
    % Используем базовое положение из JSON файла для начального построения
    base_figure_position = coordsData.base_figure_position;
    f.Position = base_figure_position;
    
    % Тулбар создаём для доступа к инструментам (zoom и т.д.), затем скрываем
    hToolbar = findall(f, 'Type', 'uitoolbar');
    if ~isempty(hToolbar)
        set(hToolbar, 'Visible', 'off');
    end
    
    mainPanel = uipanel('Parent', f, 'Position', getElementPosition('main_panel'), 'Tag', 'main_panel');
    multiax_position_a = getElementPosition('multiax_position_a');
    multiax_position_b = getElementPosition('multiax_position_b');
    multiax = axes('Position', multiax_position_a, 'Tag', 'multiax');
    set(multiax,'TickLabelInterpreter','none')
    
    sidePanel = uipanel('Parent', f, 'Position', getElementPosition('side_panel'), 'Tag', 'side_panel');
    
    % Используем значение из глобальных настроек (загружено через loadGlobalSettings)
    if isempty(visualSettings.side_panel_visible)
        visualSettings.side_panel_visible = true; % fallback на случай если настройки не загрузились
    end
    
    if visualSettings.side_panel_visible
        set(sidePanel, 'Visible', 'on');
    else
        set(sidePanel, 'Visible', 'off');
    end
    
    % Кнопка переключения видимости боковой панели
    sidePanelToggleBtn = uicontrol('Parent', f, 'Style', 'pushbutton', ...
        'Position', getElementPosition('side_panel_toggle_btn'), ...
        'Callback', @toggleSidePanelCallback, ...
        'Tag', 'side_panel_toggle_btn');
    
    % Устанавливаем начальный текст кнопки
    if visualSettings.side_panel_visible
        set(sidePanelToggleBtn, 'String', '×');
    else
        set(sidePanelToggleBtn, 'String', '□');
    end
 
    % Подготовка данных для таблицы каналов
    channelNames = {'Ch1'};
    numChannels = length(channelNames);
    channelEnabled = true(numChannels, 1); % Все каналы активированы по умолчанию
    scalingCoefficients = ones(numChannels, 1); % Коэффициенты масштабирования по умолчанию
    colorsIn = getColors(numChannels); % Инициализация цветов
    lineCoefficients = ones(numChannels, 1)*0.1; % Инициализация толщины линий
    mean_group_ch = false(numChannels, 1); % Ни один канал не участвует в усреднении
    csd_avaliable = true(numChannels, 1); % Все каналы участвуют в CSD
    filter_avaliable = false(numChannels, 1); % Ни один канал не участвует в фильтрации
    baseline_subtract_available = true(numChannels, 1); % Вычитание базовой линии включено по умолчанию

    tableData = [channelNames, num2cell(channelEnabled), num2cell(scalingCoefficients), colorsIn, num2cell(lineCoefficients), num2cell(mean_group_ch), num2cell(csd_avaliable), num2cell(filter_avaliable), num2cell(baseline_subtract_available)];

    % Создание таблицы каналов в GUI
    channelTable = uitable('Parent', sidePanel, ...
                           'Data', tableData, ...
                           'ColumnName', {'Channel', 'Enabled', 'Scale', 'Color', 'Line Width', 'Averaging', 'CSD', 'Filter', 'Baseline'}, ...
                           'ColumnFormat', {'char', 'logical', 'numeric', 'char', 'numeric', 'logical', 'logical', 'logical', 'logical'}, ...
                           'ColumnEditable', [false true true true true true true true true], ...
                           'Position', getElementPosition('channel_table'), 'Tag', 'channel_table');
    % Toggle кнопки для свойств каналов (порядок как в таблице: ch, Averaging, CSD, Filter, Baseline)
    toggleAllChannelsBtn = uicontrol('Parent', sidePanel, 'Style', 'togglebutton', 'String', '(De)select ch', 'Position', getElementPosition('toggle_all_channels_btn'), 'Callback', @(src,evt)toggleChannelProperty(src, evt, 2), 'Tag', 'toggle_all_channels_btn');
    toggleAveragingBtn = uicontrol('Parent', sidePanel, 'Style', 'togglebutton', 'String', '(De)select Averaging', 'Position', getElementPosition('toggle_averaging_btn'), 'Callback', @(src,evt)toggleChannelProperty(src, evt, 6), 'Tag', 'toggle_averaging_btn');
    toggleCSDBtn = uicontrol('Parent', sidePanel, 'Style', 'togglebutton', 'String', '(De)select CSD', 'Position', getElementPosition('toggle_csd_btn'), 'Callback', @(src,evt)toggleChannelProperty(src, evt, 7), 'Tag', 'toggle_csd_btn');
    toggleFilterBtn = uicontrol('Parent', sidePanel, 'Style', 'togglebutton', 'String', '(De)select Filter', 'Position', getElementPosition('toggle_filter_btn'), 'Callback', @(src,evt)toggleChannelProperty(src, evt, 8), 'Tag', 'toggle_filter_btn');
    toggleBaselineBtn = uicontrol('Parent', sidePanel, 'Style', 'togglebutton', 'String', '(De)select Baseline', 'Position', getElementPosition('toggle_baseline_btn'), 'Callback', @(src,evt)toggleChannelProperty(src, evt, 9), 'Tag', 'toggle_baseline_btn');
    
    % Кнопка Edit Stimulus times
    editStimulusTimesBtn = uicontrol('Parent', sidePanel, 'Style', 'pushbutton', 'String', 'Edit', 'Position', getElementPosition('edit_stimulus_times_btn'), 'Callback', @(~,~)editStimulusTimesGUI(), 'Tag', 'edit_stimulus_times_btn');
    
    set(f, 'SizeChangedFcn', @resizeComponents);
    % Сохраняем настройки после изменения размера окна
    set(f, 'WindowButtonUpFcn', @(~,~)saveSettings());
    % Настройка обработчика закрытия для фигуры
    set(f, 'CloseRequestFcn', @(src, event)closeAllCallback(src, event));
        
    % multiax не видим при запуске
    set(multiax, 'Visible', 'off')
    text(multiax, 0.5, 0.5, 'Open MAT or EV file', 'color', 'r', 'horizontalalignment', 'center')
    
    % Заголовок секции каналов
    ChannelsTitle = uicontrol('Parent', sidePanel, 'Style', 'text', 'String', 'Channels', ...
              'Position', getElementPosition('channels_title'), ...
              'HorizontalAlignment', 'left', ...
              'FontSize', 11, ...
              'FontWeight', 'bold', 'Tag', 'channels_title');
    
    % Разделитель 1 (между каналами и стимулами)
    separator1 = uicontrol('Parent', sidePanel, 'Style', 'text', ...
              'Position', getElementPosition('separator_1'), ...
              'String', '────── Stimuli ──────', ...
              'HorizontalAlignment', 'center', ...
              'FontWeight', 'bold', ...
              'Tag', 'separator_1');
    
    % Заголовок секции стимулов
    StimuliTitle = uicontrol('Parent', sidePanel, 'Style', 'text', 'String', 'Stimuli', ...
              'Position', getElementPosition('stimuli_title'), ...
              'HorizontalAlignment', 'left', ...
              'FontSize', 11, ...
              'FontWeight', 'bold', 'Tag', 'stimuli_title');
    
    % Разделитель 2 (между стимулами и событиями)
    separator2 = uicontrol('Parent', sidePanel, 'Style', 'text', ...
              'Position', getElementPosition('separator_2'), ...
              'String', '────── Events ──────', ...
              'HorizontalAlignment', 'center', ...
              'FontWeight', 'bold', ...
              'Tag', 'separator_2');
    
    % Добавление текстовой метки как заголовка к sidePanel
    EventsTableTitle = uicontrol('Parent', sidePanel, 'Style', 'text', 'String', event_title_string, ...
              'Position', getElementPosition('events_table_title'), ...
              'HorizontalAlignment', 'left', ...
              'FontSize', 11, ...
              'FontWeight', 'bold', 'Tag', 'events_table_title'); % Жирный шрифт для заголовка
      
    % Добавление слайдера для времени
    timeSlider = uicontrol('Parent', mainPanel, 'Style', 'slider', 'Position', getElementPosition('time_slider'), 'Min', 0, 'Max', 1, 'Value', 0, 'Callback', @timeSliderCallback, 'Tag', 'time_slider');

    % Добавление выпадающего списка для выбора единиц времени
    units = {'s', 'ms', 'min'};
    timeUnitPopup = uicontrol('Parent', mainPanel, 'Style', 'popup', 'String', units, 'Position', getElementPosition('time_unit_popup'), 'Callback', @changeTimeUnit, 'Tag', 'time_unit_popup');
    index = find(strcmp(units, selectedUnit));
    set(timeUnitPopup, 'Value', index);

    % Добавление выпадающего списка для выбора режима просмотра
    timeCenterPopup = uicontrol('Parent', mainPanel, 'Style', 'popup', 'String', {'time', 'stimulus', 'event', 'sweep'}, 'Position', getElementPosition('time_center_popup'), 'Callback', @changeTimeCenter, 'Tag', 'time_center_popup');

    % Путь к папке с иконками
    assetsPath = getAssetsPath();
    
    % Кнопка для загрузки .mat файла
    LoadMatFileBtn = uicontrol('Parent', mainPanel, 'Style', 'pushbutton', 'String', 'Load .mat File', 'Position', getElementPosition('load_mat_file_btn'), 'Callback', @OpenZavLfpFile, 'Tag', 'load_mat_file_btn');
    btnIcon(LoadMatFileBtn, fullfile(assetsPath, 'load_mat_file_btn.png'), false);
    
    % Кнопка для менеджера файлов
    FMbutton = uicontrol('Parent', mainPanel, 'Style', 'pushbutton', 'String', 'File Manager', 'Position', getElementPosition('fm_button'), 'Callback', @fileManagerBtnClb, 'Tag', 'fm_button');
    btnIcon(FMbutton, fullfile(assetsPath, 'fm_button.png'), false);
    
    % Поля для выбора временного окна
    TimeWindowText = uicontrol('Parent', mainPanel, 'Style', 'text', 'String', ['Time Window, ' selectedUnit ':'] , 'Position', getElementPosition('time_window_text'), 'Tag', 'time_window_text');
    BeforeText = uicontrol('Parent', mainPanel, 'Style', 'text', 'String', 'before', 'Position', getElementPosition('before_text'), 'Tag', 'before_text');
    AfterText = uicontrol('Parent', mainPanel, 'Style', 'text', 'String', 'after', 'Position', getElementPosition('after_text'), 'Tag', 'after_text');
    timeBackEdit = uicontrol('Parent', mainPanel, 'Style', 'edit', 'String', num2str(time_back*timeUnitFactor), 'Position', getElementPosition('time_back_edit'), 'Callback', @timeBackEditCallback, 'Tag', 'time_back_edit');
    timeForwardEdit = uicontrol('Parent', mainPanel, 'Style', 'edit', 'String', num2str(time_forward*timeUnitFactor), 'Position', getElementPosition('time_forward_edit'), 'Callback', @timeForwardEditCallback, 'Tag', 'time_forward_edit');

    % Spikes
    % STD
    stdCoefEdit = uicontrol('Parent', mainPanel, 'Style', 'edit', 'String', num2str(std_coef), 'Position', getElementPosition('std_coef_edit'), 'Callback', @StdCoefCallback, 'Tag', 'std_coef_edit');
    stdCoefText = uicontrol('Parent', mainPanel, 'Style', 'text', 'String', 'MUA coef:', 'Position', getElementPosition('std_coef_text'), 'Tag', 'std_coef_text');
    
    showSpikesButton = uicontrol('Parent', mainPanel, 'Style', 'checkbox', 'String', 'MUA', 'Position', getElementPosition('show_spikes_button'), 'Callback', @ShowSpikesButtonCallback, 'Tag', 'show_spikes_button');
    showCSDbutton = uicontrol('Parent', mainPanel, 'Style', 'checkbox', 'String', 'CSD', 'Position', getElementPosition('show_csd_button'), 'Callback', @ShowCSDButtonCallback, 'Tag', 'show_csd_button');
    showEventsButton = uicontrol('Parent', mainPanel, 'Style', 'checkbox', 'String', 'Events', 'Position', getElementPosition('show_events_button'), 'Value', visualSettings.events_show, 'Callback', @ShowEventsButtonCallback, 'Tag', 'show_events_button');
    showStimButton = uicontrol('Parent', mainPanel, 'Style', 'checkbox', 'String', 'Stim', 'Position', getElementPosition('show_stim_button'), 'Value', visualSettings.stim_show, 'Callback', @ShowStimButtonCallback, 'Tag', 'show_stim_button');
    
    % Кнопки для навигации по времени
    previousbutton = uicontrol('Parent', mainPanel, 'Style', 'pushbutton', 'String', 'Previous', 'Position', getElementPosition('previous_button'), 'Callback', {@shiftTime, -1, timeForwardEdit}, 'Tag', 'previous_button');
    btnIcon(previousbutton, fullfile(assetsPath, 'previous_button.png'), false);
    
    nextbutton = uicontrol('Parent', mainPanel, 'Style', 'pushbutton', 'String', 'Next', 'Position', getElementPosition('next_button'), 'Callback', {@shiftTime, 1, timeForwardEdit}, 'Tag', 'next_button');
    btnIcon(nextbutton, fullfile(assetsPath, 'next_button.png'), false);

    % Окошко для выбора размера shiftCoeff
    shiftCoefText = uicontrol('Parent', mainPanel, 'Style', 'text', 'String', 'Ch. Shift:', 'Position', getElementPosition('shift_coef_text'), 'Tag', 'shift_coef_text');
    shiftCoeffEdit = uicontrol('Parent', mainPanel, 'Style', 'edit', 'String', '200', 'Position', getElementPosition('shift_coeff_edit'), 'Callback', @shiftCoeffEditCallback, 'Tag', 'shift_coeff_edit');

    % Окошко для выбора частоты дискретизации
    FsText = uicontrol('Parent', mainPanel, 'Style', 'text', 'String', 'Fs:', 'Position', getElementPosition('fs_text'), 'Tag', 'fs_text');
    FsCoeffEdit = uicontrol('Parent', mainPanel, 'Style', 'edit', 'String', '1000', 'Position', getElementPosition('fs_coeff_edit'), 'Callback', @FsCoeffEditCallback, 'Tag', 'fs_coeff_edit');
    
    %% Выпадающие меню
    analysis_functions = {'Autodetection',...
        '',...
        'Z-score',...
        '',...
        'Spectral Density', ...
        '', ...
        'Signal Analysis', ...
        '', ...
        'Cross-Correlation', ...
        '', ...
        'PCA', ...
        '', ... % 'ICA', ... % в разработке
        'Data Operations', ...
        '', ...
        'Compare average data', ...
        '', ...
        'Snapshot all frames', ...
        '', ...
        'Plot from Table'};
    
    % Создание выпадающего списка
    analysis_menu = uicontrol('Style', 'listbox',...
        'String', analysis_functions,...
        'Visible', 'off', ...
        'Position', getElementPosition('analysis_menu'),...
        'Callback', @AnalysisMenuSelectionCallback, 'Tag', 'analysis_menu');
    % Создание кнопки для активации выпадающего списка
    analysisBtn = uicontrol('Style', 'pushbutton', 'String', 'Analysis',...
        'Visible', 'on', ...
        'Position', getElementPosition('analysis_btn'),...
        'Callback', @showAnalysisMenu, 'Tag', 'analysis_btn');       
    
    % Список действий
    file_functions = {'Open ZAV(.mat) file', ...
        '', ...
        'Recent files', ...
        '', ...
        'Open event (.ev) file',...
        '', ...
        'Save ZAV(.mat) file', ...
        '', ...
        'File manager', ...
        '', ...
        'Open figure', ...
        '', ...
        'Import', ...
        '', ...
        'Save figure snapshot'};
        
    % Создание выпадающего списка
    file_menu = uicontrol('Style', 'listbox',...
        'String', file_functions,...
        'Visible', 'off', ...
        'Position', getElementPosition('file_menu'),...
        'Callback', @FileMenuSelectionCallback, 'Tag', 'file_menu');
    
    % Создание кнопки для активации выпадающего списка
    fileBtn = uicontrol('Style', 'pushbutton', 'String', 'File',...
        'Visible', 'on', ...
        'Position', getElementPosition('file_btn'),...
        'Callback', @showFileMenu, 'Tag', 'file_btn');
                
    view_functions = {'Close all windows', ...
        '', ...
        'Hide Channel Settings', ...
        '', ...
        'Hide stimulus', ...
        '', ...
        'Hide full signal', ...
        '', ...
        'Manual channel shift', ...
        '', ...
        'Lines and styles', ...
        '', ...
        'CSD displaying', ...
        '', ...
        'Built-in Zoom', ...
        '', ...
        'Built-in Pan', ...
        '', ...
        'Data Cursor', ...
        '', ...
        'Full channel trace'};
          
    % Создание выпадающего списка
    view_menu = uicontrol('Style', 'listbox',...
        'String', view_functions,...
        'Visible', 'off', ...
        'Position', getElementPosition('view_menu'),...
        'Callback', @ViewMenuSelectionCallback, 'Tag', 'view_menu');
    
    % Создание кнопки для активации выпадающего списка
    viewBtn = uicontrol('Style', 'pushbutton', 'String', 'View',...
        'Visible', 'on', ...
        'Position', getElementPosition('view_btn'),...
        'Callback', @showViewMenu, 'Tag', 'view_btn');          
                
    % Список настроек
    options = {'Manual events settings',...
        '',...
        'Removal of Artifacts',...
        '', ...
        'Average subtraction', ...
        '', ...
        'Filtering', ...
        '',...
        'Edit events', ...
        '', ...
        'Edit stimulus times', ...
        '', ...
        'Mean Events', ...
        '', ...
        'Reset record''s settings'};
   
    % Создание выпадающего списка
    opt_menu = uicontrol('Style', 'listbox',...
              'String', options,...
              'Visible', 'off', ...
              'Position', getElementPosition('opt_menu'),...
              'Callback', @OptionsSelectionCallback, 'Tag', 'opt_menu');
    % Создание кнопки для активации выпадающего списка
    OptBtn = uicontrol('Style', 'pushbutton', 'String', 'Options',...
                    'Visible', 'on', ...
                    'Position', getElementPosition('option_btn'),...
                    'Callback', @showMenu, 'Tag', 'option_btn');
    
    % Список пунктов Help меню
    help_functions = {'About Program', ...
        '', ...
        'About Current File', ...
        '', ...
        'Help'};
    
    % Создание выпадающего списка
    help_menu = uicontrol('Style', 'listbox',...
        'String', help_functions,...
        'Visible', 'off', ...
        'Position', getElementPosition('help_menu'),...
        'Callback', @HelpMenuSelectionCallback, 'Tag', 'help_menu');
    
    % Создание кнопки для активации выпадающего списка
    helpBtn = uicontrol('Style', 'pushbutton', 'String', 'Help',...
        'Visible', 'on', ...
        'Position', getElementPosition('help_btn'),...
        'Callback', @showHelpMenu, 'Tag', 'help_btn');

                % Конец выпадающих меню
    %%
    % Таблица для отображения событий с расширенными колонками
    event_table_data = [num2cell([]), num2cell([]), num2cell([]), num2cell([]), num2cell([])];    
    eventTable = uitable('Parent', sidePanel, ...
                     'Position', getElementPosition('event_table'), ...
                     'ColumnName', {'Time', 'Comment', 'Amplitude', 'Channel', 'Source'}, ...
                     'ColumnFormat', {'bank', 'char', 'bank', 'numeric', 'char'}, ... % Формат для отображения чисел
                     'Data', event_table_data, ...
                     'ColumnEditable', [false true false false false], 'Tag', 'event_table', ...
                     'CellSelectionCallback', @eventTableSelectionChanged);
                 
    % Автоматический детектор событий
    AutoEventDetectionBtn = uicontrol('Parent', sidePanel,'Style', 'pushbutton', 'String', 'Detect',...
        'Position', getElementPosition('auto_event_detection_btn'), 'Callback', @openAutoEventDetectionWindow, 'Tag', 'auto_event_detection_btn');
    
    EditEventsBtn = uicontrol('Parent', sidePanel, 'Style', 'pushbutton', 'String', 'Edit', ...
        'Position', getElementPosition('edit_events_btn'), 'Callback', @(~,~)editEventsGUI(), 'Tag', 'edit_events_btn');
    
    % Кнопки и поля для управления событиями    
    DeleteEventBtn = uicontrol('Parent', sidePanel, 'Style', 'pushbutton', 'String', 'Delete', 'Position', getElementPosition('delete_event_btn'), 'Callback', @deleteEvent, 'Tag', 'delete_event_btn');
    eventDeleteEdit = uicontrol('Parent', sidePanel, 'Style', 'edit', 'Position', getElementPosition('event_delete_edit'), 'Callback', @eventEdited, 'Tag', 'event_delete_edit');

    % Clear Table
    clearTableBtn = uicontrol('Parent', sidePanel, 'Style', 'pushbutton', 'String', 'Clear', 'Position', getElementPosition('clear_table_btn'), 'Callback', @clearTable, 'Tag', 'clear_table_btn');
    
    % Add event
    eventAdd = uicontrol('Parent', sidePanel, 'Style', 'pushbutton', 'String', 'Add', 'Position', getElementPosition('event_add'), 'Callback', @addEvent, 'Tag', 'event_add');

    % Кнопка для сохранения событий
    saveEventsBtn = uicontrol('Parent', sidePanel, 'Style', 'pushbutton', 'String', 'Save', 'Position', getElementPosition('save_events_btn'), 'Callback', @saveEvents, 'Tag', 'save_events_btn');

    % Кнопка для загрузки событий
    loadEventsBtn = uicontrol('Parent', sidePanel, 'Style', 'pushbutton', 'String', 'Load', 'Position', getElementPosition('load_events_btn'), 'Callback', @loadEvents, 'Tag', 'load_events_btn');

    % Кнопка и окно ввода для 'Mean Events'
    MeanEventsBtn = uicontrol('Parent', sidePanel, 'Style', 'pushbutton', 'String', 'Mean', 'Position', getElementPosition('mean_events_btn'), 'Callback', @meanEventsCallback, 'Tag', 'mean_events_btn');
    meanEventsWindowText = uicontrol('Parent', sidePanel, 'Style', 'text', 'String', 'Window(+/-, s):', 'Position', getElementPosition('mean_events_window_text'), 'visible', 'off', 'Tag', 'mean_events_window_text');
    meanEventsWindowEdit = uicontrol('Parent', sidePanel, 'Style', 'edit', 'String', '1', 'Position', getElementPosition('mean_events_window_edit'), 'visible', 'off', 'Tag', 'mean_events_window_edit'); % Окно ввода временного окна (скрыл)
    
    % Применяем полное состояние боковой панели после создания всех элементов
    if ~visualSettings.side_panel_visible
        set(multiax,'Position', multiax_position_b);
    end
    
    % Обновляем текст в меню View в соответствии с состоянием
    if visualSettings.side_panel_visible
        view_functions{3} = 'Hide Channel Settings';
    else
        view_functions{3} = 'View Channel Settings';
    end
    if visualSettings.show_full_signal
        view_functions{7} = 'Hide full signal';
    else
        view_functions{7} = 'Show full signal';
    end
    if visualSettings.auto_shift
        view_functions{9} = 'Manual channel shift';
    else
        view_functions{9} = 'Auto channel shift';
    end
    set(view_menu, 'String', view_functions);
    
    if visualSettings.auto_shift
        set(shiftCoefText, 'Visible', 'off');
        set(shiftCoeffEdit, 'Visible', 'off');
    end
    
    % отключаем все элементы управления кроме начальных
    set(OptBtn, 'Enable', 'off');
    set(viewBtn, 'Enable', 'off');
    set(analysisBtn, 'Enable', 'off');
    setUIControlsEnable({sidePanel, mainPanel} , 'off')    
    set(LoadMatFileBtn, 'Enable', 'on');
    set(FMbutton, 'Enable', 'on');
    set(loadEventsBtn, 'Enable', 'on');
           
    f.WindowButtonDownFcn = @(src, event)ButtonDownFcn(multiax, f);
    f.WindowButtonMotionFcn = @(src, event)ButtonMotionFcn(multiax, f);
    f.WindowButtonUpFcn = @(src, event)ButtonUpFcn(multiax, f);
    
    % Используем базовое положение из JSON (как в signalAnalysisGUI.m)
    figure_position = base_figure_position;
    
    % Разворачиваем окно после успешной инициализации
    f.WindowState = 'maximized';
    
    function ButtonDownFcn(ax, fig)
        if zoomState.await_points
            handleZoomClick(ax);
            return;
        end
        
        if zoomState.has_zoom
            cp = get(ax, 'CurrentPoint');
            zoomState.is_panning = true;
            zoomState.pan_start_point = [cp(1, 1), cp(1, 2)];
            zoomState.pan_start_xlim = get(ax, 'XLim');
            zoomState.pan_start_ylim = get(ax, 'YLim');
            set(f, 'Pointer', 'fleur');
            return;
        end
        
        % Проверяем, зажата ли клавиша Ctrl
        modifiers = get(fig, 'CurrentModifier');
        if ismember('control', modifiers) % Если зажата Ctrl
            % Добавление интерактивного маркера при клике на график 
            addMarker(ax);
            updateMarkersDiff(ax);
            
        elseif ismember('shift', modifiers) % Добавление события по клику (та же логика, что у маркера)
            cp = get(ax, 'CurrentPoint');
            x = cp(1, 1);
            if strcmp(selectedCenter, 'sweep') && sweep_info.is_sweep_data
                time_origin = sweep_info.sweep_times(sweep_inx);
            else
                time_origin = chosen_time_interval(1);
            end
            t_absolute = time_origin + x / timeUnitFactor;
            addEventAtTime(t_absolute);
        elseif add_event_pending
            cp = get(ax, 'CurrentPoint');
            x = cp(1, 1);
            if strcmp(selectedCenter, 'sweep') && sweep_info.is_sweep_data
                time_origin = sweep_info.sweep_times(sweep_inx);
            else
                time_origin = chosen_time_interval(1);
            end
            t_absolute = time_origin + x / timeUnitFactor;
            addEventAtTime(t_absolute);
            add_event_pending = false;
        end
    end
    
    function ButtonMotionFcn(ax, fig)
        if ~zoomState.is_panning
            modifiers = get(fig, 'CurrentModifier');
            need_plus = add_event_pending || ismember('control', modifiers) || ismember('shift', modifiers);
            if need_plus
                set(fig, 'Pointer', 'crosshair');
            else
                set(fig, 'Pointer', 'arrow');
            end
            return;
        end
        
        cp = get(ax, 'CurrentPoint');
        current_point = [cp(1, 1), cp(1, 2)];
        
        dx = current_point(1) - zoomState.pan_start_point(1);
        dy = current_point(2) - zoomState.pan_start_point(2);
        
        zoomState.pan_new_xlim = zoomState.pan_start_xlim - dx;
        zoomState.pan_new_ylim = zoomState.pan_start_ylim - dy;
    end
    
    function ButtonUpFcn(ax, fig)
        if zoomState.is_panning
            if isfield(zoomState, 'pan_new_xlim') && ~isempty(zoomState.pan_new_xlim)
                set(ax, 'XLim', zoomState.pan_new_xlim);
                set(ax, 'YLim', zoomState.pan_new_ylim);
            end
            zoomState.is_panning = false;
            zoomState.pan_new_xlim = [];
            zoomState.pan_new_ylim = [];
            set(f, 'Pointer', 'arrow');
        end
    end

    function handleZoomClick(ax)
        cp = get(ax, 'CurrentPoint');
        x = cp(1, 1);
        y = cp(1, 2);
        
        zoomState.points(end + 1, :) = [x y];
        
        yLim = get(ax, 'YLim');
        xLim = get(ax, 'XLim');
        
        zoomState.lines(end + 1) = line(ax, [x x], yLim, ...
            'Color', [0 0 0], ...
            'LineStyle', '--', ...
            'HitTest', 'off');
        zoomState.lines(end + 1) = line(ax, xLim, [y y], ...
            'Color', [0 0 0], ...
            'LineStyle', '--', ...
            'HitTest', 'off');
        
        if size(zoomState.points, 1) < 2
            return;
        end
        
        xs = sort(zoomState.points(:, 1));
        ys = sort(zoomState.points(:, 2));
        
        if xs(1) == xs(2)
            xs(2) = xs(2) + eps(xs(2) + 1);
        end
        if ys(1) == ys(2)
            ys(2) = ys(2) + eps(ys(2) + 1);
        end
        
        set(ax, 'XLim', xs);
        set(ax, 'YLim', ys);
        
        zero_time_units = chosen_time_interval(1) * timeUnitFactor;
        y_bottom = ys(1);
        y_range = max(ys(2) - ys(1), eps);
        tick_height = max(y_range * 0.05, eps);
        label_offset = tick_height * 0.6;
        
        rel_min = xs(1) - zero_time_units;
        rel_max = xs(2) - zero_time_units;
        tick_values = generateNiceTicks(rel_min, rel_max, 10);

        for idx = 1:numel(tick_values)
            rel_time = tick_values(idx);
            t_pos = zero_time_units + rel_time;
            line(ax, [t_pos t_pos], [y_bottom y_bottom + tick_height], ...
                'Color', [0 0 0], ...
                'LineWidth', 1, ...
                'HitTest', 'off');
            
            label_str = sprintf('%.1f', rel_time);
            text(ax, t_pos, y_bottom + tick_height + label_offset, label_str, ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'bottom', ...
                'Color', [0 0 0], ...
                'BackgroundColor', 'none', ...
                'Clipping', 'on');
        end
        
        zoomState.await_points = false;
        zoomState.has_zoom = true;
        zoomState.points = zeros(0, 2);
        zoomState.lines = gobjects(0);
        set(zoomButton, 'String', 'Reset Zoom');
        set(f, 'Pointer', 'arrow');
    end

    function ticks = generateNiceTicks(minVal, maxVal, desiredCount)
        if minVal > maxVal
            temp = minVal; minVal = maxVal; maxVal = temp;
        end
        rangeVal = max(maxVal - minVal, eps);
        if desiredCount < 2
            desiredCount = 2;
        end
        rawStep = rangeVal / (desiredCount - 1);
        magnitude = 10^floor(log10(rawStep));
        normalized = rawStep / magnitude;
        if normalized < 1.5
            niceFraction = 1;
        elseif normalized < 3
            niceFraction = 2;
        elseif normalized < 7
            niceFraction = 5;
        else
            niceFraction = 10;
        end
        step = niceFraction * magnitude;
        startTick = ceil(minVal / step) * step;
        endTick = floor(maxVal / step) * step;
        if startTick > minVal
            startTick = startTick - step;
        end
        ticks = startTick:step:endTick;
        if isempty(ticks) || ticks(1) > minVal
            ticks = [startTick - step, ticks];
        end
        if ticks(end) < maxVal
            ticks = [ticks, ticks(end) + step];
        end
        ticks = ticks(ticks >= minVal - step*0.5 & ticks <= maxVal + step*0.5);
        if isempty(ticks)
            ticks = [minVal, maxVal];
        end
        ticks = unique(ticks);
    end

    function zoomButtonCallback(src, ~)
        % Активация встроенного zoom
        resetZoom(); % Сбрасываем кастомный zoom если был активен
        pan(f, 'off'); % Отключаем другие инструменты
        datacursormode(f, 'off');
        brush(f, 'off');
        zoom(f, 'on');
        zoom(multiax, 'on');
        debugState('zoomButtonCallback', 'Built-in zoom activated');
    end

    function panButtonCallback(src, ~)
        % Активация встроенного pan
        resetZoom(); % Сбрасываем кастомный zoom если был активен
        zoom(f, 'off'); % Отключаем другие инструменты
        datacursormode(f, 'off');
        brush(f, 'off');
        pan(f, 'on');
        pan(multiax, 'on');
        debugState('panButtonCallback', 'Built-in pan activated');
    end

    function cursorButtonCallback(src, ~)
        % Активация встроенного data cursor
        resetZoom(); % Сбрасываем кастомный zoom если был активен
        zoom(f, 'off'); % Отключаем другие инструменты
        pan(f, 'off');
        brush(f, 'off');
        datacursormode(f, 'on');
        debugState('cursorButtonCallback', 'Data cursor activated');
    end

    function homeButtonCallback(src, ~)
        % Сброс всех инструментов и восстановление исходного вида графика
        resetZoom(); % Сбрасываем кастомный zoom
        zoom(f, 'off'); % Отключаем все встроенные инструменты
        pan(f, 'off');
        datacursormode(f, 'off');
        brush(f, 'off');
        updatePlot(); % Восстанавливаем исходные границы осей
        debugState('homeButtonCallback', 'All tools reset, view restored');
    end

    function brushButtonCallback(src, ~)
        % Активация встроенного brush
        resetZoom(); % Сбрасываем кастомный zoom если был активен
        zoom(f, 'off'); % Отключаем другие инструменты
        pan(f, 'off');
        datacursormode(f, 'off');
        brush(f, 'on');
        brush(multiax, 'on');
        debugState('brushButtonCallback', 'Built-in brush activated');
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
        % Сохраняем настройки перед закрытием
        try
            saveSettings();
        catch
            % Игнорируем ошибки сохранения при закрытии
        end
        
        % Закрываем все зависимые окна
        closeChildWindows();

        % Сбрасываем состояние загруженного файла перед закрытием окна
        resetToNoFileState();
        
        % Удаляем окно
        delete(src);
        
        % Проверяем наличие других главных окон и открываем app.m при необходимости
        manageMainWindows('SignalViewerGUI');
    end

    % Функция closeAllButOne убрана - теперь это делает главное окно app.m

    % Callback для сброса параметров
    function resetParametersCallback(~, ~)
        try
            resetGraphParameters()
        catch
            debugState('resetParametersCallback', '')
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
        
        set(help_menu, 'Visible', 'off'); % Скрыть меню
        help_menu_visible = false;
        
        catch
            debugState('resetGraphParameters', 'bravo 5')
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
            case analysis_functions{7}% Signal Analysis
                openSignalAnalysisWindow();
            case analysis_functions{9}
                eventCrossCorrelationGUI();
            % case analysis_functions{11}% ICA анализ  
            %     ICAazGUI();
            case analysis_functions{11}% PCA analysis
                PCAazGUI();
            case analysis_functions{13}
                performChannelOperationsGUI();
            case analysis_functions{15}
                dataComparerGUI();
            case analysis_functions{17}
                set(opt_menu, 'Visible', 'off');
                menu_visible = false;
                set(file_menu, 'Visible', 'off');
                file_menu_visible = false;
                set(view_menu, 'Visible', 'off');
                view_menu_visible = false;
                set(analysis_menu, 'Visible', 'off');
                analysis_menu_visible = false;
                set(help_menu, 'Visible', 'off');
                help_menu_visible = false;
                snapshotAllFrames(f, @updatePlot, @shiftTime, timeForwardEdit);
            case analysis_functions{19}
                plotFromTableGUI();
            case ''
                dont_close_menu = true;
        end    
        debugState('AnalysisMenuSelectionCallback', 'Selected: %s', selectedOption);        
        if ~dont_close_menu
            resetGraphParameters()
        end
    end
    
    function showImportFormatDialog()
        formats = {'ABF', 'NLX', 'Open Ephys', 'ZAV (.mat)'};
        [selection, ok] = listdlg('ListString', formats, ...
            'SelectionMode', 'single', ...
            'PromptString', 'Select format to import:', ...
            'Name', 'Import Format', ...
            'ListSize', [200 120]);
        
        if ok && ~isempty(selection)
            switch selection
                case 1
                    convertAbf2zavGUI();
                case 2
                    convertNlx2zavGUI();
                case 3
                    convertOEP2zavGUI();
                case 4
                    importLFPGUI();
            end
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
                OpenZavLfpFile([], []);
            case file_functions{3}
                showRecentFilesDialog();
            case file_functions{5}
                loadEvents([], []);
            case file_functions{7}
                saveMatFile(matFilePath);
            case file_functions{9}
                fileManagerBtnClb([], []);
            case file_functions{11}
                openFigureWithFileDialog();
            case file_functions{13}
                showImportFormatDialog();
            case file_functions{15}
                saveMainAxisAs();
            case ''
                dont_close_menu = true;
        end
        debugState('FileMenuSelectionCallback', 'Selected: %s', selectedOption);
        if ~dont_close_menu
            resetGraphParameters()
        end
    end


    function showRecentFilesDialog()
        selectedRow = [];
        
        tableData_rf = cell(0, 2);
        reversed = unique(lastOpenedFiles(end:-1:1), 'stable');
        for i = 1:numel(reversed)
            [~, fname, fext] = fileparts(reversed{i});
            tableData_rf{i, 1} = [fname, fext];
            tableData_rf{i, 2} = reversed{i};
        end
        
        dlgWidth = 600;
        dlgHeight = 400;
        screenSize = get(0, 'ScreenSize');
        dlgPos = [(screenSize(3) - dlgWidth) / 2, (screenSize(4) - dlgHeight) / 2, dlgWidth, dlgHeight];
        
        dlg = figure('Name', 'Recent files', 'NumberTitle', 'off', ...
            'MenuBar', 'none', 'ToolBar', 'none', ...
            'WindowStyle', 'modal', 'Resize', 'off', ...
            'Position', dlgPos);
        
        recentTable = uitable('Parent', dlg, ...
            'Data', tableData_rf, ...
            'ColumnName', {'File name', 'Path'}, ...
            'RowName', {}, ...
            'ColumnEditable', [false false], ...
            'ColumnWidth', {180, 380}, ...
            'Position', [10, 50, 580, 340], ...
            'CellSelectionCallback', @onCellSelection);
        
        btnOpenLoc = uicontrol('Parent', dlg, 'Style', 'pushbutton', ...
            'String', 'Open File Location', 'Position', [10, 10, 140, 30], ...
            'Enable', 'off', 'Callback', @onOpenLocation);
        
        btnOpen = uicontrol('Parent', dlg, 'Style', 'pushbutton', ...
            'String', 'Open', 'Position', [490, 10, 100, 30], ...
            'Enable', 'off', 'Callback', @onOpen);
        
        function onCellSelection(~, evt)
            if ~isempty(evt.Indices)
                selectedRow = evt.Indices(1, 1);
                set(btnOpen, 'Enable', 'on');
                set(btnOpenLoc, 'Enable', 'on');
            end
        end
        
        function onOpen(~, ~)
            filePath_rf = recentTable.Data{selectedRow, 2};
            close(dlg);
            loadMatFile(filePath_rf);
        end
        
        function onOpenLocation(~, ~)
            filePath_rf = recentTable.Data{selectedRow, 2};
            folder = fileparts(filePath_rf);
            winopen(folder);
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
        defaultName = evfilename;
        
        [file, path, filterindex] = uiputfile(...
            {'*.pdf', 'PDF files (*.pdf)';...
             '*.eps', 'EPS files (*.eps)';...
             '*.png', 'PNG files (*.png)';...
             '*.*', 'All Files (*.*)'},...
             'Save file name', fullfile(mat_file_folder, defaultName));
        if isequal(file,0) || isequal(path,0)
           debugState('saveMainAxisAs', 'User pressed cancel');
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
           debugState('saveMainAxisAs', 'Image saved to %s', filename);
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
                % Убрано - теперь это делает главное окно app.m
            case view_functions{3}
                showHideSidePanel();
            case view_functions{5}
                showHideStimulus()
            case view_functions{7}
                toggleFullSignal()
            case view_functions{9}
                toggleAutoShift()
            case view_functions{11}
                lineStyleGUI()
            case view_functions{13}%'CSD ...'
                CSDSettingsGUI();
                updateTable();
            case view_functions{15}%'Built-in Zoom'
                activateBuiltInZoom();
            case view_functions{17}%'Built-in Pan'
                activateBuiltInPan();
            case view_functions{19}%'Data Cursor'
                activateDataCursor();
            case view_functions{21}
                viewFullChannelGUI();
            case ''
            dont_close_menu = true;
        end
        debugState('ViewMenuSelectionCallback', 'Selected: %s', selectedOption);
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
                addEventSettingsGUI();
            case options{3}
                optionsRemovalArtifactsGUI();                       
            case options{5} %'Subtract mean ...'
                % вызов функции для Subtract mean ...
                SubMeanSettingsGUI();
                updateTable();
            case options{7}%'Filtering ...'
                setupSignalFilteringGUI(); 
                updateTable();            
            case options{9}%'Edit events'
                editEventsGUI();
            case options{11}
                editStimulusTimesGUI();
            case options{13}%'Mean Events'    
                setupMeanEventsGUI();
            case options{15}%'Reset record''s settings'
                resetRecordSettings();
            case ''
            dont_close_menu = true;
        end
        debugState('OptionsSelectionCallback', 'Selected: %s', selectedOption);
        if ~dont_close_menu
            resetGraphParameters()
        end
    end
    
    % вызов файл-менеджера
    function fileManagerBtnClb(~, ~)
        fileManagerGUI();
    end
    
    function showHideSidePanel()
        
        if visualSettings.side_panel_visible
            debugState('showHideSidePanel', 'Hiding Side Panel')
            set(sidePanel, 'Visible', 'off');
            set(multiax,'Position', multiax_position_b);
            str_out = 'View Channel Settings';
        else
            debugState('showHideSidePanel', 'Showing Side Panel')
            set(sidePanel, 'Visible', 'on');            
            set(multiax,'Position', multiax_position_a);
            str_out = 'Hide Channel Settings';
        end
        
        view_functions{3} = str_out;
        set(view_menu, 'String', view_functions);
            
        visualSettings.side_panel_visible = ~visualSettings.side_panel_visible;
        
        % Обновляем текст кнопки переключения
        if exist('sidePanelToggleBtn', 'var') && isvalid(sidePanelToggleBtn)
            if visualSettings.side_panel_visible
                set(sidePanelToggleBtn, 'String', '×');
            else
                set(sidePanelToggleBtn, 'String', '□');
            end
        end
        
        % Сохраняем состояние в общие настройки
        save(SettingsFilepath, 'visualSettings', '-append');
    end
    
    function toggleSidePanelCallback(~, ~)
        showHideSidePanel();
    end

    function showHideStimulus()
        
        if visualSettings.stim_show
            debugState('showHideStimulus', 'Hiding Stimulus')
            str_out = 'Show stimulus';
        else
            debugState('showHideStimulus', 'Showing Stimulus')
            str_out = 'Hide stimulus';
        end
        
        view_functions{5} = str_out;
        set(view_menu, 'String', view_functions);
        visualSettings.stim_show = ~visualSettings.stim_show;
        set(showStimButton, 'Value', visualSettings.stim_show);
        
        updatePlot()
    end

    function toggleFullSignal()
        visualSettings.show_full_signal = ~visualSettings.show_full_signal;
        
        if visualSettings.show_full_signal
            str_out = 'Hide full signal';
        else
            str_out = 'Show full signal';
        end
        
        view_functions{7} = str_out;
        set(view_menu, 'String', view_functions);
        
        save(SettingsFilepath, 'visualSettings', '-append');
        updatePlot()
    end

    function toggleAutoShift()
        visualSettings.auto_shift = ~visualSettings.auto_shift;
        
        if visualSettings.auto_shift
            str_out = 'Manual channel shift';
            set(shiftCoefText, 'Visible', 'off');
            set(shiftCoeffEdit, 'Visible', 'off');
        else
            str_out = 'Auto channel shift';
            set(shiftCoefText, 'Visible', 'on');
            set(shiftCoeffEdit, 'Visible', 'on');
        end
        
        view_functions{9} = str_out;
        set(view_menu, 'String', view_functions);
        
        save(SettingsFilepath, 'visualSettings', '-append');
        updatePlot()
    end

    function activateBuiltInZoom()
        % Активация встроенного инструмента zoom для multiax через меню
        resetZoom();
        pan(f, 'off');
        datacursormode(f, 'off');
        brush(f, 'off');
        zoom(f, 'on');
        zoom(multiax, 'on');
        debugState('activateBuiltInZoom', 'Built-in zoom activated');
    end

    function activateBuiltInPan()
        % Активация встроенного инструмента pan для multiax через меню
        resetZoom();
        zoom(f, 'off');
        datacursormode(f, 'off');
        brush(f, 'off');
        pan(f, 'on');
        pan(multiax, 'on');
        debugState('activateBuiltInPan', 'Built-in pan activated');
    end

    function activateDataCursor()
        % Активация встроенного инструмента data cursor для multiax через меню
        resetZoom();
        zoom(f, 'off');
        pan(f, 'off');
        brush(f, 'off');
        datacursormode(f, 'on');
        debugState('activateDataCursor', 'Data cursor activated');
    end

    function showSidePanel()
        if ~visualSettings.side_panel_visible
            debugState('showSidePanel', 'Showing Side Panel')
            set(sidePanel, 'Visible', 'on');            
            set(multiax,'Position', multiax_position_a);
            str_out = 'Hide Channel Settings';

            view_functions{3} = str_out;
            set(view_menu, 'String', view_functions);

            visualSettings.side_panel_visible = true;
            
            % Обновляем текст кнопки переключения
            if exist('sidePanelToggleBtn', 'var') && isvalid(sidePanelToggleBtn)
                set(sidePanelToggleBtn, 'String', '×');
            end
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
    
    % Функция обратного вызова для кнопки Help
    function showHelpMenu(~, ~)
        if help_menu_visible
            set(help_menu, 'Visible', 'off'); % Убрать меню
        else
            set(help_menu, 'Visible', 'on'); % Показать меню
        end
        help_menu_visible = not(help_menu_visible);
    end

    
    % Обратный вызов выпадающего списка Help
    function HelpMenuSelectionCallback(src, ~)
        val = src.Value;
        str = src.String;
        selectedOption = str{val};
        dont_close_menu = false;
        switch selectedOption
            case help_functions{1} % 'About Program'
                showAboutProgram();
            case help_functions{3} % 'About Current File'
                showAboutCurrentFile();
            case help_functions{5} % 'Help'
                showHelp();
            case ''
                dont_close_menu = true;
        end
        if ~dont_close_menu
            resetGraphParameters()
        end
    end

    function resizeComponents(~, ~)
        try
            % Применяем текущее состояние боковой панели без изменения настройки
            if visualSettings.side_panel_visible
                set(sidePanel, 'Visible', 'on');
                set(multiax,'Position', multiax_position_a);
            else
                set(sidePanel, 'Visible', 'off');
                set(multiax,'Position', multiax_position_b);
            end
            
            % Путь к файлу координат
            coordsFile = getGUIConfigPath('signalViewerGUI_coords.json');
            
            % Загружаем базовый размер из JSON для правильного вычисления коэффициентов масштабирования
            if exist(coordsFile, 'file')
                coordsData = jsondecode(fileread(coordsFile));
                base_figure_position = coordsData.base_figure_position;
                ResizeElements(f, coordsFile, base_figure_position);
            end
        catch ME
            warning('Error scaling elements: %s', ME.message);
        end
    end


    function openAutoEventDetectionWindow(~, ~)
        global wb
        if isempty(wb) || ~isvalid(wb)
            wb = waitbar(0.01, 'Opening Auto Event Detection...', 'Name', 'Event Detection');
            drawnow;
        else
            waitbar(0.01, wb, 'Opening Auto Event Detection...');
            drawnow;
        end
        autoEventDetectionGUI();
    end
    
    function openSignalAnalysisWindow(~, ~)
        signalAnalysisGUI();
    end
        
    % Nested function to check key press
    function check_key_press(~, ~)
%         drawnow; % Process GUI events
        key = get(f, 'CurrentCharacter');
        if ~isempty(key)
            debugState('check_key_press', 'Key pressed: %s', key);
%             set(gcf, 'CurrentCharacter', ''); % Reset current character
        end
    end

    % Функция обработки нажатия клавиш
    function keyPressFunction(src, event)
%         disp('key pressed:')
%         disp(event.Key)
        % Если кнопка уже была нажата или идет обновление графика - блокируем исполнение
        if keyboardpressed || plot_updating
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
        has_events = isscalar(events_exist) && events_exist;
        has_stims = isscalar(stims_exist) && stims_exist;
        
        if ~has_events && ~has_stims
            errordlg('No events or stimuli available. Please load events or a file with stimuli.', 'Error');
            return;
        end
        
        if has_events && ~has_stims
            calculateAndPlotMeanEvents('events', struct('removeBaseline', true));
        elseif ~has_events && has_stims
            calculateAndPlotMeanEvents('stimuli', struct('removeBaseline', true));
        else
            choice = questdlg('Select data source for mean calculation:', ...
                'Mean Calculation', ...
                'Events', 'Stimuli', 'Cancel', 'Events');
            switch choice
                case 'Events'
                    calculateAndPlotMeanEvents('events', struct('removeBaseline', true));
                case 'Stimuli'
                    calculateAndPlotMeanEvents('stimuli', struct('removeBaseline', true));
                case 'Cancel'
                    return;
            end
        end
    end
%%

    function shiftCoeffEditCallback(src, ~)
        newShiftCoeff = str2double(get(src, 'String'));
        if isnan(newShiftCoeff) || newShiftCoeff <= 0
            debugState('shiftCoeffEditCallback', 'Invalid Shift Coeff Value');
            return;
        end
        shiftCoeff = newShiftCoeff;
        saveChannelSettings();
        updatePlot(); % Обновление графика с новым shiftCoeff
    end

    function FsCoeffEditCallback(src, ~)
        newFsCoeff = str2double(get(src, 'String'));
        if isnan(newFsCoeff) || newFsCoeff <= 0
            debugState('FsCoeffEditCallback', 'Invalid Fs Value');
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
        visualSettings.show_spikes = ~visualSettings.show_spikes;
        set(showSpikesButton, 'Value', visualSettings.show_spikes);
        updatePlot(); % Обновление графика
    end

    function ShowEventsButtonCallback(~, ~)
        if ~isfield(visualSettings, 'events_show')
            visualSettings.events_show = true;
        end
        visualSettings.events_show = ~visualSettings.events_show;
        set(showEventsButton, 'Value', visualSettings.events_show);
        updatePlot();
    end

    function ShowStimButtonCallback(~, ~)
        visualSettings.stim_show = ~visualSettings.stim_show;
        set(showStimButton, 'Value', visualSettings.stim_show);
        updatePlot();
    end

    function ShowCSDButtonCallback(~, ~)
        prev_show_csd = visualSettings.show_CSD;
        visualSettings.show_CSD = ~visualSettings.show_CSD;

        if visualSettings.show_CSD
            active_csd_channels = sum(csd_avaliable(ch_inxs));
            if active_csd_channels < 4
                visualSettings.show_CSD = prev_show_csd;
                set(showCSDbutton, 'Value', visualSettings.show_CSD);
                errordlg('At least 4 active channels are required to compute CSD.', 'CSD Error', 'modal');
                return;
            end
        end

        set(showCSDbutton, 'Value', visualSettings.show_CSD);
        try
            updatePlot(); % Обновление графика
        catch ME
            csd_error_detected = contains(ME.message, 'At least 4 channels are required to compute CSD.') || ...
                contains(ME.message, 'Output argument "csd"');
            if csd_error_detected
                visualSettings.show_CSD = prev_show_csd;
                set(showCSDbutton, 'Value', visualSettings.show_CSD);
                errordlg('At least 4 active channels are required to compute CSD.', 'CSD Error', 'modal');
                return;
            end
            rethrow(ME);
        end
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
            debugState('timeForwardEditCallback', 'Invalid time window size.');
            return;
        end
        debugState('timeForwardEditCallback', 'windowSize=%.3f, stim_inx=%d', windowSize, stim_inx);
                
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
            case 'sweep'
                if sweep_info.is_sweep_data && sweep_inx > 0 && sweep_inx <= sweep_info.sweep_count
                    % Устанавливаем начало текущего свипа
                    chosen_time_interval(1) = sweep_info.sweep_times(sweep_inx);
                    chosen_time_interval(2) = chosen_time_interval(1) + windowSize;
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
            case 'sweep'
                sweep_inx = 1;
        end
        
        % Обновляем максимальное значение слайдера в зависимости от режима
        updateSliderMaxValue();
        
        timeForwardEditCallback(timeForwardEdit)
%         updatePlot(); % Обновление графика с новыми единицами времени
    end
    
    % Функция для обновления максимального значения слайдера в зависимости от режима
    function updateSliderMaxValue()
        switch selectedCenter
            case 'stimulus'
                if stims_exist
                    % Максимальное значение - время последнего стимула
                    set(timeSlider, 'Max', stims(end));
                    set(timeSlider, 'Min', stims(1));
                else
                    % Если стимулов нет, используем обычное время
                    set(timeSlider, 'Max', time(end));
                    set(timeSlider, 'Min', time(1));
                end
            case 'event'
                if events_exist
                    % Максимальное значение - время последнего события
                    set(timeSlider, 'Max', events(end));
                    set(timeSlider, 'Min', events(1));
                else
                    % Если событий нет, используем обычное время
                    set(timeSlider, 'Max', time(end));
                    set(timeSlider, 'Min', time(1));
                end
            case 'sweep'
                if sweep_info.is_sweep_data
                    % Максимальное значение - время последнего свипа
                    set(timeSlider, 'Max', sweep_info.sweep_times(end));
                    set(timeSlider, 'Min', sweep_info.sweep_times(1));
                else
                    % Если свипов нет, используем обычное время
                    set(timeSlider, 'Max', time(end));
                    set(timeSlider, 'Min', time(1));
                end
            case 'time'
                % Обычное время
                set(timeSlider, 'Max', time(end));
                set(timeSlider, 'Min', time(1));
        end
    end
    
    % Функция обратного вызова слайдера
    function timeSliderCallback(src, ~)
        
        
        % Если идет обновление графика - игнорируем
        if plot_updating
            % Возвращаем значение обратно
            set(src, 'Value', previousSliderValue);
            return;
        end
        
        sliderValue = get(src, 'Value'); % Текущее значение слайдера
        sliderMin = get(src, 'Min');
        sliderMax = get(src, 'Max');
        
        % Определяем шаг слайдера (обычно это небольшая величина)
        % Используем 1% от диапазона как порог для определения клика по стрелке
        sliderRange = sliderMax - sliderMin;
        sliderStep = sliderRange / 100; % примерный шаг
        
        % Определяем направление изменения
        valueChange = sliderValue - previousSliderValue;
        
        % Если изменение небольшое (меньше 2% от диапазона) - это клик по стрелке
        if abs(valueChange) < sliderStep * 2 && abs(valueChange) > 0
            % Это клик по стрелке - используем shiftTime
            direction = sign(valueChange); % 1 для вперед, -1 для назад
            % Возвращаем значение обратно
            set(src, 'Value', previousSliderValue);
            % Вызываем shiftTime
            shiftTime(src, [], direction, timeForwardEdit);
            return;
        end
        
        % Иначе это перетаскивание ползунка - работаем как обычно
        previousSliderValue = sliderValue;
        
        windowSize = str2double(get(timeForwardEdit, 'String'))/timeUnitFactor;% должен быть в секундах;
        
        switch selectedCenter
            case 'stimulus'
                if stims_exist
                    % Находим ближайший стимул к текущему значению слайдера
                    stim_inx = ClosestIndex(sliderValue, stims);
                    
                    % Проверяем границы
                    if stim_inx > numel(stims)
                        stim_inx = numel(stims);
                    elseif stim_inx < 1
                        stim_inx = 1;
                    end
                    
                    % Устанавливаем временной интервал относительно найденного стимула
                    chosen_time_interval(1) = stims(stim_inx);
                    chosen_time_interval(2) = stims(stim_inx) + windowSize;
                else
                    % Если стимулов нет, работаем как с обычным временем
                    if sliderValue + windowSize > time(end)
                        sliderValue = time(end) - windowSize;
                    end
                    chosen_time_interval = [sliderValue, sliderValue + windowSize];
                end
            case 'event'
                if events_exist
                    % Находим ближайшее событие к текущему значению слайдера
                    event_inx = ClosestIndex(sliderValue, events);
                    
                    % Проверяем границы
                    if event_inx > numel(events)
                        event_inx = numel(events);
                    elseif event_inx < 1
                        event_inx = 1;
                    end
                    
                    % Устанавливаем временной интервал относительно найденного события
                    chosen_time_interval(1) = events(event_inx);
                    chosen_time_interval(2) = events(event_inx) + windowSize;
                    
                    % Обновляем активное окно
                    set(eventDeleteEdit, 'String', num2str(event_inx));
                else
                    % Если событий нет, работаем как с обычным временем
                    if sliderValue + windowSize > time(end)
                        sliderValue = time(end) - windowSize;
                    end
                    chosen_time_interval = [sliderValue, sliderValue + windowSize];
                end
            case 'sweep'
                if sweep_info.is_sweep_data
                    % Находим ближайший свип к текущему значению слайдера
                    sweep_inx = ClosestIndex(sliderValue, sweep_info.sweep_times);
                    
                    % Проверяем границы
                    if sweep_inx > sweep_info.sweep_count
                        sweep_inx = sweep_info.sweep_count;
                    elseif sweep_inx < 1
                        sweep_inx = 1;
                    end
                    
                    % Устанавливаем временной интервал относительно найденного свипа
                    chosen_time_interval(1) = sweep_info.sweep_times(sweep_inx);
                    chosen_time_interval(2) = chosen_time_interval(1) + windowSize;
                else
                    % Если свипов нет, работаем как с обычным временем
                    if sliderValue + windowSize > time(end)
                        sliderValue = time(end) - windowSize;
                    end
                    chosen_time_interval = [sliderValue, sliderValue + windowSize];
                end
            case 'time'
                % Проверка на выход за границы времени
                if sliderValue + windowSize > time(end)
                    sliderValue = time(end) - windowSize;
                end
                chosen_time_interval = [sliderValue, sliderValue + windowSize];
                
                if not(isempty(events))
                    event_inx = ClosestIndex(sliderValue, events);
                    set(eventDeleteEdit, 'String', num2str(event_inx));  
                end
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
        baseline_subtract_available = [updatedData{:, 9}];% каналы с вычитанием базовой линии
        filterSettings.channelsToFilter = np_flatten(filter_avaliable);

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
    
    function eventTableSelectionChanged(~, event)
        if isempty(event.Indices) || isempty(events)
            return;
        end
        
        selected_event_rows = unique(event.Indices(:, 1))';
        selected_event_rows = selected_event_rows(selected_event_rows > 0 & selected_event_rows <= length(events));

        selected_row = selected_event_rows(1);
        selectedCenter = 'event';
        event_inx = selected_row;

        set(timeCenterPopup, 'Value', 3);

        windowSize = time_forward;
        chosen_time_interval(1) = events(event_inx);
        chosen_time_interval(2) = events(event_inx) + windowSize;

        set(eventDeleteEdit, 'String', num2str(event_inx));

        updatePlot();
    end

    function selectEventByIndex(ev_ix)
        if isempty(events) || ev_ix < 1 || ev_ix > numel(events)
            return;
        end
        selectedCenter = 'event';
        event_inx = ev_ix;
        set(timeCenterPopup, 'Value', 3);
        windowSize = time_forward;
        chosen_time_interval(1) = events(event_inx);
        chosen_time_interval(2) = events(event_inx) + windowSize;
        set(eventDeleteEdit, 'String', num2str(event_inx));
        updatePlot();
    end
    
    % Внутренние функции для обработки событий GUI
    function OpenZavLfpFile(~, ~)
        
        % Получение пути к последнему открытому файлу или использование стандартной директории
        initialDir = pwd;
        if ~isempty(lastOpenedFiles)
            initialDir = fileparts(lastOpenedFiles{end});
        end
        
        [file, path] = uigetfile({'*.mat'; '*.abf'}, 'Load .mat File (ZAV or Heka format) or ABF file', initialDir);
        if isequal(file, 0)
            debugState('OpenZavLfpFile', 'File selection canceled.');
            return;
        end
        filepath = fullfile(path, file);
        
        % Очистка таблицы событий ДО загрузки файла
        events = [];
        event_indices = [];
        event_amplitudes = [];
        event_channels = [];
        event_widths = [];
        event_prominences = [];
        event_metadata = [];
        event_comments = {};
        event_title_string = 'Events';
        event_inx = 1;
        events_exist = false;
        
        loadMatFile(filepath)
        
        UpdateEventTable();
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
            debugState('saveMatFile', 'User canceled the operation');
            return;
        end
        filepath = fullfile(path, file);

        % Extract the file name without extension
        [~, matFileName, ~] = fileparts(filepath);
        debugState('saveMatFile', 'Saving mat file: %s', matFileName);
        
        % записываем отредактированные стимулы
        zavp.realStim = struct('r', stims'/zavp.siS);
        
        
        % Save the variables to the specified file
        lfp = lfp_file.lfp;
        save(filepath, 'spks', 'lfp', 'hd', 'zavp', 'chnlGrp', 'lfpVar', '-v7.3');
        clear lfp;
        
        % Сохраняем настройки каналов
        saveChannelSettings()
    end



    function metadata = loadMatFile(filepath)
        metadata = struct('hd', [], 'stims', [], 'filePath', '');
        closeChildWindows();
        debugState('loadMatFile', 'loading mat file:');
        ica_flag = false;
        pca_flag = false;
        stims_loaded_from_settings = false; % сбрасываем флаг при загрузке нового файла
        
        windowSize = str2double(get(timeForwardEdit, 'String'))/timeUnitFactor;% должен быть в секундах
        

        % если идет вызов снаружи
        if ~isempty(outside_calling_filepath)
            filepath = outside_calling_filepath;
            outside_calling_filepath = [];          
        end
        
        % Автоконверсия ABF файлов
        [~, ~, ext] = fileparts(filepath);
        if strcmpi(ext, '.abf')
            debugState('loadMatFile', 'ABF file detected, converting to ZAV...');
            zavFilePath = autoConvertAbfToZav(filepath);
            if ~isempty(zavFilePath) && exist(zavFilePath, 'file')
                filepath = zavFilePath;
            else
                debugState('loadMatFile', 'Failed to convert ABF file');
                resetToNoFileState();
                metadata = [];
                return;
            end
        end
        
        % Проверка, открыт ли уже файл
        if exist('matFilePath', 'var') && ~isempty(matFilePath) && exist('hd', 'var') && ~isempty(hd)
            [~, currentFileName, ~] = fileparts(matFilePath);
            [~, newFileName, ~] = fileparts(filepath);
            if strcmp(currentFileName, newFileName) && strcmp(matFilePath, filepath)
                debugState('loadMatFile', 'File already open: %s', newFileName);
                hWaitBar = waitbar(0, 'File already open...', 'Name', 'Loading file');
                waitbar(0.5, hWaitBar, 'File already open...');
                pause(0.3);
                waitbar(1, hWaitBar, 'Complete');
                pause(0.1);
                if isvalid(hWaitBar)
                    close(hWaitBar);
                end
                metadata = struct('hd', hd, 'stims', stims, 'filePath', matFilePath);
                return;
            end
        end
        
         % Сохранение пути к загруженному .mat файлу
        matFilePath = filepath;        
        [~, matFileName, ~] = fileparts(matFilePath);
        evfilename = matFileName;
        debugState('loadMatFile', '%s', matFileName);       
        
        % Используем универсальную функцию загрузки
        data = load_zav_file(filepath, ...
            'auto_set_time_windows', autoSetTimeWindowsFromSweeps, ...
            'auto_set_fs', autoSetNewFsFromFs);
        [lfp_file, spks, hd, zavp, lfpVar, chnlGrp, time, stims, sweep_info, time_forward, time_back] = struct2vars(data);

        N = length(time);
        Fs = zavp.dwnSmplFrq;
        
        % Устанавливаем флаги
        stims_exist = ~isempty(stims);
        sweep_inx = 1;
        debugState('loadMatFile', 'stims_exist=%d', stims_exist);
        
        % Обновляем заголовок стимулов
        if stims_exist
            set(StimuliTitle, 'String', ['Stimuli: ', num2str(numel(stims))]);
        else
            set(StimuliTitle, 'String', 'Stimuli');
        end
        
        % Устанавливаем временные параметры
        shiftCoeff = 200;
        
        % Устанавливаем newFs
        if autoSetNewFsFromFs
            newFs = Fs;
        else
            newFs = 1000;
        end
        
        % Автоматический выбор режима центра
        if stims_exist && numel(stims) > 1
            selectedCenter = 'stimulus';
        elseif sweep_info.is_sweep_data && sweep_info.sweep_count > 1
            selectedCenter = 'sweep';
        else
            selectedCenter = 'time';
        end
        stim_inx = 1;
        debugState('loadMatFile', 'selectedCenter=%s, stim_inx=%d', selectedCenter, stim_inx);
        
        % Правильно устанавливаем chosen_time_interval в зависимости от выбранного режима
        % Используем time_forward, который был установлен load_zav_file (или значение по умолчанию)
        windowSize = time_forward;
        switch selectedCenter
            case 'stimulus'
                if stims_exist && stim_inx > 0 && stim_inx <= numel(stims)
                    chosen_time_interval(1) = stims(stim_inx);
                    chosen_time_interval(2) = stims(stim_inx) + windowSize;
                else
                    chosen_time_interval = [0, windowSize];
                end
            case 'sweep'
                if sweep_info.is_sweep_data && sweep_inx > 0 && sweep_inx <= sweep_info.sweep_count
                    chosen_time_interval(1) = sweep_info.sweep_times(sweep_inx);
                    chosen_time_interval(2) = chosen_time_interval(1) + windowSize;
                else
                    chosen_time_interval = [0, windowSize];
                end
            case 'time'
                chosen_time_interval = [0, windowSize];
        end
        
        visualSettings.show_spikes = false;
        visualSettings.show_CSD = false;
        channelNames = hd.recChNames;
        numChannels = length(channelNames);
        
        resetMainWindowButtons()
        

        
        % Обновление и сохранение списка последних открытых файлов
        lastOpenedFiles{end + 1} = filepath;
        
            % Попытка загрузить настройки каналов
    % Сначала проверяются индивидуальные настройки, затем групповые
       loadChannelSettings();
       metadata = struct('hd', hd, 'stims', stims, 'filePath', filepath);
   end

    function resetToNoFileState()
        lfp_file = []; spks = []; hd = []; zavp = []; lfpVar = []; chnlGrp = []; time = []; stims = [];
        sweep_info = struct('is_sweep_data', false, 'sweep_count', 0, 'sweep_times', []);
        time_forward = []; time_back = []; matFilePath = ''; matFileName = ''; stims_exist = false;
        events = []; event_indices = []; event_comments = {}; event_amplitudes = []; event_channels = [];
        event_widths = []; event_prominences = []; event_metadata = [];
        N = []; Fs = []; newFs = []; sweep_inx = 1; selectedCenter = 'time'; stim_inx = 1;
        chosen_time_interval = [0, 0];
        set(StimuliTitle, 'String', 'Stimuli');
        axes(multiax);
        cla(multiax);
        text(multiax, 0.5, 0.5, 'Open MAT or EV file', 'color', 'r', 'horizontalalignment', 'center', 'Units', 'normalized');
        set(multiax, 'Visible', 'off');
        if ~isempty(loading_text_handle) && isvalid(loading_text_handle)
            set(loading_text_handle, 'Visible', 'off');
        end
        set(OptBtn, 'Enable', 'off');
        set(viewBtn, 'Enable', 'off');
        set(analysisBtn, 'Enable', 'off');
        setUIControlsEnable({sidePanel, mainPanel}, 'off');
        set(LoadMatFileBtn, 'Enable', 'on');
        set(FMbutton, 'Enable', 'on');
        set(loadEventsBtn, 'Enable', 'on');
        data_loaded = false;
    end

    function closeChildWindows()
        % Список тегов окон для закрытия
        windowTags = {
            'editStimulusTimesGUI', ...
            'EventDetection', ...
            'SignalAnalysisGUI', ...
            'ZScoreGUI', ...
            'spectralDensityGUI', ...
            'chCrossCorrelationGUI', ...
            'eventCrossCorrelationGUI', ...
            'ICA', ...
            'PCA', ...
            'performChannelOperationsGUI', ...
            'convertAbf2zavGUI', ...
            'convertOEP2zavGUI', ...
            'importLFPGUI', ...
            'RemovalArtifactsGUI', ...
            'SubMeanSettingsGUI', ...
            'SignalFiltering', ...
            'OptionsMeanEvents', ...
            'lineStyleGUI', ...
            'CSDSettingsGUI', ...
            'EventCreation', ...
            'importEventsFromSimulusGUI', ...
            'meanSignalResult'
        };
        
        % Закрываем окна по тегам
        for i = 1:length(windowTags)
            figs = findall(0, 'Type', 'figure', 'Tag', windowTags{i});
            if ~isempty(figs)
                delete(figs);
            end
        end
        
        % Закрываем окна без тегов по имени
        allFigs = findall(0, 'Type', 'figure');
        for i = 1:length(allFigs)
            figName = get(allFigs(i), 'Name');
            % Закрываем окно конвертации NLX (без тега)
            if strcmp(figName, 'Convert to ZAV')
                delete(allFigs(i));
            end
        end
    end

    


    function resetMainWindowButtons()
        if ~isfield(visualSettings, 'events_show')
            visualSettings.events_show = true;
        end
        
        % разрешение опций
        set(OptBtn, 'Enable', 'on');
        set(viewBtn, 'Enable', 'on');
        set(analysisBtn, 'Enable', 'on');
        
        set(showSpikesButton, 'Value', visualSettings.show_spikes);
        set(showCSDbutton, 'Value', visualSettings.show_CSD);
        set(showEventsButton, 'Value', visualSettings.events_show);
        set(showStimButton, 'Value', visualSettings.stim_show);
        
        % Установка правильного значения в выпадающем списке в зависимости от selectedCenter
        switch selectedCenter
            case 'time'
                set(timeCenterPopup, 'Value', 1);
            case 'stimulus'
                set(timeCenterPopup, 'Value', 2);
            case 'event'
                set(timeCenterPopup, 'Value', 3);
            case 'sweep'
                set(timeCenterPopup, 'Value', 4);
        end
        
        set(timeBackEdit, 'String', num2str(time_back*timeUnitFactor));% time window before
        set(timeForwardEdit, 'String', num2str(time_forward*timeUnitFactor));% time window after
        set(shiftCoeffEdit, 'String', num2str(shiftCoeff));
        set(FsCoeffEdit, 'String', num2str(newFs));
        
        % Управление доступностью режима sweep в зависимости от типа данных
        if sweep_info.is_sweep_data
            % Для данных со свипами показываем все режимы
            set(timeCenterPopup, 'String', {'time', 'stimulus', 'event', 'sweep'});
        else
            % Для обычных данных скрываем режим sweep
            set(timeCenterPopup, 'String', {'time', 'stimulus', 'event'});
        end
        
        % Обновление максимального значения слайдера
        updateSliderMaxValue();
        
        % Включаем все элементы управления если файл загрузился в первый
        % раз
        if ~data_loaded
            setUIControlsEnable({sidePanel, mainPanel} , 'on')
            data_loaded = true;
        end
        
        % включаем multiax
        set(multiax, 'Visible', 'on')
    end

    function toggleChannelProperty(~, ~, columnIndex)
        % Общая функция для toggle кнопок свойств каналов
        % columnIndex: 2=Enabled, 6=Averaging, 7=CSD, 8=Filter, 9=Baseline
        updatedData = get(channelTable, 'Data');
        currentValues = [updatedData{:, columnIndex}];
        
        % Определение нового состояния: если все включены - выключаем все, иначе включаем все
        allEnabled = all(currentValues);
        newState = ~allEnabled;
        
        % Обновление данных в таблице
        for i = 1:size(updatedData, 1)
            updatedData{i, columnIndex} = newState;
        end
        set(channelTable, 'Data', updatedData);
        
        % Обновление соответствующих глобальных переменных
        switch columnIndex
            case 2
                channelEnabled(:) = newState;
            case 6
                mean_group_ch(:) = newState;
            case 7
                csd_avaliable(:) = newState;
            case 8
                filter_avaliable(:) = newState;
                filterSettings.channelsToFilter = filter_avaliable;
            case 9
                baseline_subtract_available(:) = newState;
        end
        
        % Обновление выбора каналов и графика
        updateChannelSelection();
    end

    function updateTable()
        numCh = length(channelNames);
        tableData = cell(numCh, 9);
        for i = 1:numCh
            tableData{i, 1} = channelNames{i};
            tableData{i, 2} = channelEnabled(i);
            tableData{i, 3} = scalingCoefficients(i);
            tableData{i, 4} = colorsIn{i};
            tableData{i, 5} = lineCoefficients(i);
            tableData{i, 6} = mean_group_ch(i);
            tableData{i, 7} = csd_avaliable(i);
            tableData{i, 8} = filter_avaliable(i);
            tableData{i, 9} = baseline_subtract_available(i);
        end

        set(channelTable, 'Data', tableData, ... % Обновляем данные в таблице
                   'ColumnName', {'Channel', 'Enabled', 'Scale', 'Color', 'Line Width', 'Averaging', 'CSD', 'Filter', 'Baseline'}, ...
                   'ColumnFormat', {'char', 'logical', 'numeric', 'char', 'numeric', 'logical', 'logical', 'logical', 'logical'}, ...
                   'ColumnEditable', [false true true true true true true true true]);
        
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
            if isfield(loadedSettings, 'baseline_subtract_available')
                baseline_subtract_available = np_flatten(loadedSettings.baseline_subtract_available);
            else
                baseline_subtract_available = true(numChannels, 1);
            end
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
            if isfield(loadedSettings, 'baseline_subtract_available')
                baseline_subtract_available = np_flatten(loadedSettings.baseline_subtract_available);
            else
                baseline_subtract_available = true(numChannels, 1);
            end
        end
        updateTable();

        if isfield(loadedSettings, 'filterSettings') && ~(isempty(loadedSettings.filterSettings))
            filterSettings = loadedSettings.filterSettings;
            if ~isfield(filterSettings, 'smoothSpan')
                filterSettings.smoothSpan = 0;
            end
            if ~isfield(filterSettings, 'smoothMethod')
                filterSettings.smoothMethod = 'moving';
            end
        else % если настройки старые
            filterSettings.filterType = 'highpass';
            filterSettings.freqLow = 10;
            filterSettings.freqHigh = 50;
            filterSettings.order = 4;
            filterSettings.channelsToFilter = false(numChannels, 1); % Ни один канал не участвует в фильтрации
            filterSettings.smoothSpan = 0;
            filterSettings.smoothMethod = 'moving';
            debugState('loadSettingsFile', 'settings were without filterSettings');
        end
        if ~islogical(filterSettings.channelsToFilter) || numel(filterSettings.channelsToFilter) ~= numel(filter_avaliable)
            filterSettings.channelsToFilter = np_flatten(filter_avaliable);
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
            debugState('loadSettingsFileVIEWER', 'time_back=%f', time_back);
            set(timeBackEdit, 'String', num2str(time_back * timeUnitFactor));
        end
        if isfield(loadedSettings, 'time_forward')
            time_forward = loadedSettings.time_forward; % time window after (s)
            set(timeForwardEdit, 'String', num2str(time_forward * timeUnitFactor));
        end

        if isfield(loadedSettings, 'csd_smooth_coef')
            csd_smooth_coef = loadedSettings.csd_smooth_coef;
        else
            csd_smooth_coef = 5;
            debugState('loadSettingsFile', 'settings were without CSD smooth coef');
        end
        if isfield(loadedSettings, 'csd_contrast_coef')
            csd_contrast_coef = loadedSettings.csd_contrast_coef;
        else
            csd_contrast_coef = 99.99;
            debugState('loadSettingsFile', 'settings were without CSD contrast coef');
        end
        
        % Загружаем смещенные стимулы если они есть
        if isfield(loadedSettings, 'stims')
            stims = loadedSettings.stims;
            stims_exist = ~isempty(stims);
            stims_loaded_from_settings = true;
            debugState('loadSettingsFile', 'Loaded shifted stimulus times from settings');
            
            % Обновляем заголовок стимулов
            if stims_exist
                set(StimuliTitle, 'String', ['Stimuli: ', num2str(numel(stims))]);
            else
                set(StimuliTitle, 'String', 'Stimuli');
            end
        end
        
        % Правильно устанавливаем chosen_time_interval в зависимости от режима
        % Делаем это ПОСЛЕ загрузки всех настроек, включая stims
        if isfield(loadedSettings, 'time_forward')
            switch selectedCenter
                case 'stimulus'
                    if stims_exist && stim_inx > 0 && stim_inx <= numel(stims)
                        chosen_time_interval = [stims(stim_inx), stims(stim_inx) + time_forward];
                    else
                        chosen_time_interval = [0, time_forward];
                    end
                case 'sweep'
                    if isfield(sweep_info, 'is_sweep_data') && sweep_info.is_sweep_data && sweep_inx > 0 && sweep_inx <= sweep_info.sweep_count
                        chosen_time_interval = [sweep_info.sweep_times(sweep_inx), sweep_info.sweep_times(sweep_inx) + time_forward];
                    else
                        chosen_time_interval = [0, time_forward];
                    end
                otherwise
                    chosen_time_interval = [0, time_forward];
            end
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

    % Функция создания нового файла настроек
    function createNewSettingsFile()
        [path, name, ~] = fileparts(matFilePath);
        channelSettingsFilePath = fullfile(path, [name '_channelSettings.stn']);
        
        if exist(channelSettingsFilePath, 'file')
            delete(channelSettingsFilePath);
            debugState('createNewSettingsFile', 'Deleted old settings file');
        end
        
        setStandardChannelSettings();
        
        csd_smooth_coef = 5;
        csd_contrast_coef = 99.99;
        
        saveChannelSettings();
        
        updateTableFunc();
        updateLocalCoefsFunc();
        updateChannelSelection();
        updatePlotFunc();
        
        debugState('createNewSettingsFile', 'Created new settings file');
    end

    % Функция загрузки настроек каналов
    function loadChannelSettings()
        [path, name, ~] = fileparts(matFilePath);
        channelSettingsFilePath = fullfile(path, [name '_channelSettings.stn']);
        
        if isfile(channelSettingsFilePath)
            % Индивидуальные настройки существуют - загружаем их полностью
            debugState('loadChannelSettings', 'Loading individual channel settings...');
            loadSettingsFile()
            updateChannelSelection();
        else
            % Индивидуальных настроек нет - загружаем групповые + создаем индивидуальные
            debugState('loadChannelSettings', 'No individual settings found, loading group settings...');
            loadGroupSettingsAndCreateIndividual(matFilePath, numChannels, Fs, EV_version)
        end
        
    end
    

    
    function setStandardChannelSettings()
            channelNames = np_flatten(channelNames);
            channelEnabled = true(1, numChannels); % Все каналы активированы по умолчанию
            scalingCoefficients = ones(1, numChannels); % Коэффициенты масштабирования по умолчанию
            colorsIn = np_flatten(getColors(numChannels)); % Инициализация цветов
            lineCoefficients = ones(1, numChannels)*0.5; % Инициализация толщины линий
            mean_group_ch = false(1, numChannels);% Ни один канал не участвует в усреднении
            csd_avaliable = true(1, numChannels);% Все каналы участвуют в CSD
            filter_avaliable = false(1, numChannels);% Ни один канал не участвует в фильтрации
            baseline_subtract_available = true(1, numChannels);% Вычитание базовой линии включено по умолчанию
            
            filterSettings.filterType = 'highpass';
            filterSettings.freqLow = 10;
            filterSettings.freqHigh = 50;
            filterSettings.order = 4;
            filterSettings.channelsToFilter = false(numChannels, 1);% Ни один канал не участвует в фильтрации
            filterSettings.smoothSpan = 0;
            filterSettings.smoothMethod = 'moving';
    end

    function resetRecordSettings()
        % Функция для сброса настроек записи к значениям по умолчанию
        if ~data_loaded
            debugState('resetRecordSettings', 'No data loaded. Please load a MAT file first.');
            return;
        end
        
        % Запрос подтверждения у пользователя
        choice = questdlg('Are you sure you want to reset all channel settings to default values? This action cannot be undone.', ...
                          'Reset Record Settings', ...
                          'Yes', 'No', 'No');
        switch choice
            case 'Yes'
                % Удаляем файл настроек каналов, если он существует
                [path, name, ~] = fileparts(matFilePath);
                channelSettingsFilePath = fullfile(path, [name '_channelSettings.stn']);
                
                if exist(channelSettingsFilePath, 'file')
                    delete(channelSettingsFilePath);
                    debugState('resetRecordSettings', 'Settings file deleted.');
                end
                
                % Создаем новый файл настроек с настройками по умолчанию
                createNewSettingsFile();
                
                debugState('resetRecordSettings', 'Channel settings have been reset to default values.');
                
            case 'No'
                % Пользователь отменил операцию
                return;
        end
    end

    function UpdateEventTable()        
        [events, ev_inxs] = sort(events);
        event_comments = event_comments(ev_inxs);
        
        % Сортируем все метаданные в том же порядке что и события
        if ~isempty(event_amplitudes) && length(event_amplitudes) == length(events)
            sorted_amplitudes = event_amplitudes(ev_inxs);
        else
            sorted_amplitudes = NaN(size(events));
        end
        
        if ~isempty(event_channels) && size(event_channels, 1) == length(events)
            sorted_channels = event_channels(ev_inxs, :);
            % Для отображения берем первый канал или показываем все каналы
            if size(sorted_channels, 2) == 1
                display_channels = sorted_channels;
            else
                % Для многоканальных показываем первый канал
                display_channels = sorted_channels(:, 1);
            end
        else
            display_channels = ones(size(events));
        end
        
        if ~isempty(event_metadata) && length(event_metadata) == length(events)
            sorted_metadata = event_metadata(ev_inxs);
            source_strings = cell(size(events));
            for i = 1:length(sorted_metadata)
                if isstruct(sorted_metadata(i)) && isfield(sorted_metadata(i), 'source')
                    source_strings{i} = sorted_metadata(i).source;
                else
                    source_strings{i} = 'unknown';
                end
            end
        else
            source_strings = repmat({'unknown'}, size(events));
        end
        
        % Обновляем данные таблицы с новыми колонками
        eventTable.Data = [num2cell(events*timeUnitFactor), event_comments, ...
                          num2cell(sorted_amplitudes), num2cell(display_channels), source_strings];
        set(EventsTableTitle, 'String', [event_title_string, ': ', num2str(numel(events))]);
    end

    function addEvent(~, ~)
        add_event_pending = true;
    end

    function addEventAtTime(t_absolute)
        events = [events; t_absolute];
        [~, idx] = min(abs(time - t_absolute));
        event_indices = [event_indices; idx];
        event_comments{numel(events), 1} = '...';
        event_amplitudes = [event_amplitudes; NaN];
        event_channels = [event_channels; 1];
        event_widths = [event_widths; NaN];
        event_prominences = [event_prominences; NaN];
        event_metadata = [event_metadata; createDefaultEventMetadata('manual', 1)];
        UpdateEventTable();
        events_exist = true;
        updatePlot();
    end

    function clearTable(~, ~)
        choice = questdlg('Are you sure you want to clear the table?', ...
                          'Clear Table', ...
                          'Yes','No','No');
        switch choice
            case 'Yes'
                events = [];
                event_indices = [];
                event_comments = {};
                event_amplitudes = [];
                event_channels = [];
                event_widths = [];
                event_prominences = [];
                event_metadata = [];
                event_title_string = 'Events';
                UpdateEventTable();
                events_exist = false;
                updatePlot();
            case 'No'
                % Do nothing if the user selects 'No'
        end
    end


    function shiftTime(~, ~, direction, timeForwardEdit)
        
        
        % Проверяем, не идет ли уже обновление графика
        if plot_updating
            return;
        end
        
        % отключаем возможность использовать клавиатуру
%         set(f, 'KeyPressFcn', '');
        
        if keyboardpressed
           return;
        end
        keyboardpressed = true;
        
%         disp('changed position')
        windowSize = str2double(get(timeForwardEdit, 'String'))/timeUnitFactor;% должен быть в секундах
        debugState('shiftTime', 'windowSize=%.3f, stims_exist=%d, stim_inx=%d', windowSize, stims_exist, stim_inx);
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
                    debugState('shiftTime', 'stim_inx=%d, numel(stims)=%d', stim_inx, numel(stims));
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
                        debugState('shiftTime', 'stim_inx=%d, stims(stim_inx)=%.3f, chosen_time_interval=[%.3f, %.3f]', stim_inx, stims(stim_inx), chosen_time_interval(1), chosen_time_interval(2));
                    else
                        stim_inx = 1;
                    end
                end
            case 'sweep'
                if sweep_info.is_sweep_data
                    if direction == 1% движение вперед  
                        sweep_inx = sweep_inx+1;                    
                    else% движение назад 
                        sweep_inx = sweep_inx-1;                    
                    end
                    if sweep_inx > sweep_info.sweep_count
                        sweep_inx = sweep_info.sweep_count;
                    end
                    if sweep_inx > 0
                        chosen_time_interval(1) = sweep_info.sweep_times(sweep_inx);
                        chosen_time_interval(2) = chosen_time_interval(1) + windowSize;
                    else
                        sweep_inx = 1;
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
        debugState('shiftTime', 'chosen_time_interval=[%.3f, %.3f]', chosen_time_interval(1), chosen_time_interval(2));
        updatePlot(); % Обновление графика
        debugState('shiftTime', 'plot updated');
        
        % Включаем callback нажатия клавиш
%         set(f, 'KeyPressFcn', @keyPressFunction);
    end
    
    function deleteEvent(~, ~)
        % Определяем индексы для удаления: выделенные строки или значение из поля ввода
        if ~isempty(selected_event_rows)
            idxs = selected_event_rows;
        else
            idxs = str2double(get(eventDeleteEdit, 'String'));
        end
        
        idxs = idxs(~isnan(idxs) & idxs > 0 & idxs <= length(events));
        if isempty(idxs)
            showErrorDialog('Invalid event index.');
            return;
        end

        events(idxs) = [];
        event_comments(idxs) = [];
        
        if ~isempty(event_amplitudes), event_amplitudes(idxs) = []; end
        if ~isempty(event_channels), event_channels(idxs, :) = []; end
        if ~isempty(event_widths), event_widths(idxs) = []; end
        if ~isempty(event_prominences), event_prominences(idxs) = []; end
        if ~isempty(event_metadata), event_metadata(idxs) = []; end
        
        selected_event_rows = [];
        
        UpdateEventTable();
        if isempty(events)
            events_exist = false;
        end
        
        if event_inx > numel(events)
            event_inx = max(numel(events), 1);
        end
        
        if events_exist
            chosen_time_interval(1) = events(event_inx);
            chosen_time_interval(2) = events(event_inx) + windowSize;
        end
        
        updatePlot();
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

    function applyEventsLoadedState()
        selectedCenter = 'event';
        set(timeCenterPopup, 'Value', 3);
        chosen_time_interval(1) = events(event_inx);
        chosen_time_interval(2) = events(event_inx) + time_forward;
        cb = get(timeSlider, 'Callback');
        set(timeSlider, 'Callback', []);
        updateSliderMaxValue();
        set(timeSlider, 'Value', events(1));
        set(timeSlider, 'Callback', cb);
        updatePlot();
    end

% Функция загрузки событий
function loadEvents(~, ~)
    debugState('loadEvents', '%s', outside_calling_filepath);
    if isempty(outside_calling_filepath)
        % Получение пути к последнему открытому файлу или использование стандартной директории
        initialDir = pwd;
        if ~isempty(lastOpenedFiles)
            initialDir = fileparts(lastOpenedFiles{end});
        end

        [file, path] = uigetfile({'*.ev;*.mean;*.xlsx;*.xls', 'Events / Excel files (*.ev, *.mean, *.xlsx, *.xls)'}, 'Load Events', initialDir);
        if isequal(file, 0)
            debugState('loadEvents', 'File selection canceled.');
            return;
        end
        filepath = fullfile(path, file);
        
    else
        debugState('loadEvents', 'loading file from outside');
        filepath = outside_calling_filepath;
        [path,file,ext] = fileparts(outside_calling_filepath);
        file = [file,ext];
        outside_calling_filepath = [];% очищаем наружний путь
    end
    
    % Обработка Excel-файлов
    [~, ~, fileExt] = fileparts(filepath);
    if ismember(lower(fileExt), {'.xlsx', '.xls'})
        loadEventsFromExcel(filepath, file);
        return;
    end

    loadedData = load(filepath, '-mat'); % Загружаем данные в структуру
    % Если не был загружен mat файл, инициируем поиск
    if isfield(loadedData, 'viewer_data')
        if isfield(loadedData.viewer_data, 'matFilePath') && ~isempty(loadedData.viewer_data.matFilePath)
            if exist(loadedData.viewer_data.matFilePath, 'file')
                % Загружаем файл, если путь отличается ИЛИ данные не загружены
                if ~strcmp(loadedData.viewer_data.matFilePath, matFilePath) || ~exist('time', 'var') || isempty(time)
                    loadMatFile(loadedData.viewer_data.matFilePath);
                else
                    updatePlot();
                end
            end
        end
    end

    
    if isfield(loadedData, 'manlDet')
        event_indices = round([loadedData.manlDet.t])';
        events = time(event_indices)';
        
        if ~isfield(loadedData, 'event_comments') % если комментариев не было
            event_comments = repmat({'...'}, numel(events), 1); % Инициализация комментариев
        else % если были комментарии
            event_comments = loadedData.event_comments;
        end
        
        % Загрузка новых полей с обратной совместимостью
        if isfield(loadedData.manlDet, 'amplitude')
            event_amplitudes = [loadedData.manlDet.amplitude]';
        else
            event_amplitudes = NaN(size(events)); % default для старых файлов
            debugState('loadEvents', 'Old format detected: amplitude data not available');
        end
        
        if isfield(loadedData.manlDet, 'channels')
            % Проверяем, одноканальные или многоканальные данные
            first_channels = loadedData.manlDet(1).channels;
            if isscalar(first_channels)
                event_channels = [loadedData.manlDet.channels]';
            else
                % Многоканальные данные - собираем в матрицу
                max_channels = max(cellfun(@length, {loadedData.manlDet.channels}));
                event_channels = NaN(length(events), max_channels);
                for i = 1:length(events)
                    chs = loadedData.manlDet(i).channels;
                    event_channels(i, 1:length(chs)) = chs;
                end
            end
        elseif isfield(loadedData.manlDet, 'ch')
            event_channels = [loadedData.manlDet.ch]'; % Используем старое поле ch
        else
            event_channels = ones(size(events)); % default
            debugState('loadEvents', 'Old format detected: channel data not available');
        end
        
        if isfield(loadedData.manlDet, 'width')
            event_widths = [loadedData.manlDet.width]';
        else
            event_widths = NaN(size(events)); % default для старых файлов
            debugState('loadEvents', 'Old format detected: width data not available');
        end
        
        if isfield(loadedData.manlDet, 'prominence')
            event_prominences = [loadedData.manlDet.prominence]';
        else
            event_prominences = NaN(size(events)); % default для старых файлов
            debugState('loadEvents', 'Old format detected: prominence data not available');
        end
        
        if isfield(loadedData.manlDet, 'metadata')
            event_metadata = [loadedData.manlDet.metadata]';
        else
            % Создаем default metadata для старых файлов
            event_metadata = createDefaultEventMetadata('loaded', length(events));
            debugState('loadEvents', 'Old format detected: metadata not available');
        end
        
        event_title_string = file;
        UpdateEventTable();
        events_exist = true;
        event_inx = 1;
        applyEventsLoadedState();
    else
        debugState('loadEvents', 'No events found in the file.');
    end
end

    function loadEventsFromExcel(filepath, file)
        T = readtable(filepath);
        colNames = T.Properties.VariableNames;

        [colIdx, ok] = listdlg('ListString', colNames, ...
            'SelectionMode', 'single', ...
            'PromptString', 'Выберите колонку с временами событий (в секундах):', ...
            'ListSize', [300, 200]);
        if ~ok
            return;
        end

        eventTimes = T{:, colIdx};
        eventTimes = eventTimes(~isnan(eventTimes));
        n = numel(eventTimes);

        events = eventTimes(:);
        event_indices = zeros(n, 1);
        for k = 1:n
            [~, event_indices(k)] = min(abs(time(:) - eventTimes(k)));
        end
        event_comments = repmat({'...'}, n, 1);
        event_amplitudes = NaN(n, 1);
        event_channels = ones(n, 1);
        event_widths = NaN(n, 1);
        event_prominences = NaN(n, 1);
        event_metadata = createDefaultEventMetadata('excel', n);

        event_title_string = file;
        UpdateEventTable();
        events_exist = true;
        event_inx = 1;
        applyEventsLoadedState();
    end

    function saveEvents(~, ~)
        choice = questdlg('Select file format:', 'Save Events', ...
            'Excel (.xlsx)', '.ev file', 'Cancel', '.ev file');
        
        if isempty(choice) || strcmp(choice, 'Cancel')
            return;
        end
        
        saveExcel = strcmp(choice, 'Excel (.xlsx)');
        
        saveEventsToFile(events, time, matFilePath, ...
            'event_indices', event_indices, ...
            'event_comments', event_comments, ...
            'event_amplitudes', event_amplitudes, ...
            'event_channels', event_channels, ...
            'event_widths', event_widths, ...
            'event_prominences', event_prominences, ...
            'event_metadata', event_metadata, ...
            'dialogTitle', 'Save Events', ...
            'defaultFileNameSuffix', '_events', ...
            'matFileName', matFileName, ...
            'autodetection_settings', autodetection_settings, ...
            'add_event_settings', add_event_settings, ...
            'EV_version', EV_version, ...
            'saveExcel', saveExcel);
    end

    set(eventTable, 'CellEditCallback', @updateEventTable);
    set(channelTable, 'CellEditCallback', @updateChannelSelection);
    
    if ~isempty(filePath)
        [~, ~, ext] = fileparts(filePath);
        switch lower(ext)
            case '.ev'
                outside_calling_filepath = filePath;
                loadEvents();
            case {'.mat', '.abf'}
                loadMatFile(filePath);
                UpdateEventTable();
        end
    else
        resetToNoFileState();
        autoOpenLastFile();
    end
    
    function autoOpenLastFile()
        % Автоматически открывает последний открытый файл при запуске GUI
        
        % Проверяем настройку автоматического открытия
        if ~exist('auto_open_last_file', 'var') || isempty(auto_open_last_file)
            return; % Если настройка не загружена - не открываем
        end
        
        if ~auto_open_last_file
            return;
        end
        
        try
            % Проверяем, есть ли список последних файлов
            if isempty(lastOpenedFiles)
                return;
            end
            
            % Берем последний файл из списка
            lastFile = lastOpenedFiles{end};
            
            % Проверяем, существует ли файл
            if ~exist(lastFile, 'file')
                % Удаляем несуществующий файл из списка
                lastOpenedFiles(end) = [];
                return;
            end
            
            % Загружаем файл
            loadMatFile(lastFile);
        catch ME
            % Игнорируем ошибки при автоматической загрузке
        end
    end
    
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
            debugState('updateAndRunInstaller', 'The latest version is already installed.');
        end
    end

end

