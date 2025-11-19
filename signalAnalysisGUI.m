function signalAnalysisGUI(editMode)
    disp('Signal Analysis Started')

    % Проверяем режим редактирования
    if nargin < 1
        editMode = 'normal';
    end
    
    % Загружаем глобальные настройки (включая инициализацию по умолчанию)
    loadGlobalSettings();
    
    % Загружаем координаты элементов из JSON файла
    coordsFile = fullfile(fileparts(mfilename('fullpath')), 'signalAnalysisGUI_coords.json');
    if exist(coordsFile, 'file')
        coordsData = jsondecode(fileread(coordsFile));
    else
        error('Coordinates file not found: %s', coordsFile);
    end
    
    % Signal Analysis GUI - анализ и измерение параметров сигнала
    
    % Глобальные переменные для доступа к данным
    global lfp time chosen_time_interval time_back time_forward hd
    global newFs Fs timeUnitFactor selectedUnit
    global filterSettings filter_avaliable mean_group_ch
    global selectedCenter events stims sweep_info event_inx stim_inx sweep_inx events_exist stims_exist
    global stimShowFlag art_rem_window_ms
    global SettingsFilepath
    global original_xlim original_ylim
    global channel_data time_in
    global saveChannelSettingsFunc
    global zav_calling event_calling table_calling outside_calling_filepath
    global lastOpenedFiles auto_analysis_mode
    
    % Глобальные переменные настроек (загружены в app.m)
    global figure_position lastOpenedFiles add_event_settings
    global autodetection_settings lines_and_styles side_panel_visible
    global auto_open_last_file
    
    % Глобальные настройки уже загружены в app.m
    
    % Глобальные переменные для настроек каналов
    global channelNames channelEnabled scalingCoefficients colorsIn lineCoefficients
    global csd_avaliable stims_loaded_from_settings
    global shiftCoeff stim_offset
    
    % Глобальные переменные для slope measurement
    global slope_measurement_settings
    global slope_measurement_results
    global selected_row_slope % для отслеживания выделенной строки в таблице
    
    % Глобальные переменные для измерений
    global slope_value slope_angle peak_time peak_value baseline_value onset_time onset_value onset_method measurement_metadata

    % Глобальные переменные для сохранения результатов
    global matFilePath matFileName
    
    % Глобальные переменные для среднего сигнала
    global mean_signal_data mean_signal_time mean_results_active
    
    % Вспомогательная функция для получения координат элемента
    function pos = getElementPosition(tag)
        if isfield(coordsData.elements, tag)
            pos = coordsData.elements.(tag);
            
            % Проверяем, не является ли элемент осью или панелью - для них оставляем относительные координаты
            if ~strcmp(tag, 'main_axes') && ~strcmp(tag, 'plot_container') && ...
               ~strcmp(tag, 'main_panel') && ~strcmp(tag, 'side_panel') && ~strcmp(tag, 'event_panel')
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
    
    % Путь к файлу настроек (аналогично signalViewerGUI.m)
    SettingsFilepath = fullfile(tempdir, 'ev_settings.mat');
    
    % Callback-и для File Manager
    zav_calling = @openFile;
    event_calling = @loadEvents;
    table_calling = @() [];
    outside_calling_filepath = [];
    
    % Загрузка настроек единиц времени из основного приложения
    % Сначала проверяем, есть ли уже глобальные переменные из EasyView
    if ~exist('timeUnitFactor', 'var') || isempty(timeUnitFactor)
        % Пытаемся загрузить из настроек основного приложения
        if exist(SettingsFilepath, 'file')
                    try
            d = load(SettingsFilepath);
            if isfield(d, 'timeUnitFactor')
                timeUnitFactor = d.timeUnitFactor;
            else
                timeUnitFactor = 1; % по умолчанию
            end
            if isfield(d, 'selectedUnit')
                selectedUnit = d.selectedUnit;
            else
                selectedUnit = 's'; % по умолчанию
            end
        catch ME
            timeUnitFactor = 1;
            selectedUnit = 's';
        end
    else
        timeUnitFactor = 1;
        selectedUnit = 's';
    end
else
end

if ~exist('selectedUnit', 'var') || isempty(selectedUnit)
    selectedUnit = 's';
else
end
    
    % Глобальная переменная для метаданных измерений
    global current_measurement_metadata

    global rel_shift

    % Глобальные переменные для settingsEditor
    global EV_version numChannels updateAnalysisPlotFunc_global
    
    % Глобальные переменные для UI элементов
    global hBaselineStartEdit hBaselineEndEdit hPeakStartEdit hPeakEndEdit
    global hPlotAxes hNavigationStatus hReplaceBtn
    
    % Инициализация флага показа стимулов
    stimShowFlag = true;
    
    % Инициализация размера окна удаления артефакта (в мс)
    if isempty(art_rem_window_ms)
        try
            d = load(SettingsFilepath);
            art_rem_window_ms = d.art_rem_window_ms;
        catch
            art_rem_window_ms = 0;
        end
    end

    % Инициализация настроек если их нет
    if isempty(slope_measurement_settings)
        slope_measurement_settings.channel = 1;
        slope_measurement_settings.baseline_start = 0;
        slope_measurement_settings.baseline_end = 0;
        slope_measurement_settings.peak_start = 0;
        slope_measurement_settings.peak_end = 0;
        slope_measurement_settings.slope_percent = 20; % процент для slope расчета
        slope_measurement_settings.peak_polarity = 'positive'; % 'positive' или 'negative'
        slope_measurement_settings.onset_method = 'derivative'; % метод расчета онсета
        slope_measurement_settings.onset_threshold = 3; % порог в единицах std
        % Настройки видимости
        slope_measurement_settings.show_baseline = true;
        slope_measurement_settings.show_onset = true;
        slope_measurement_settings.show_slope = true;
        slope_measurement_settings.show_peak = true;
    else
        % Проверяем и добавляем недостающие поля для онсета
        if ~isfield(slope_measurement_settings, 'onset_method')
            slope_measurement_settings.onset_method = 'derivative';
        end
        if ~isfield(slope_measurement_settings, 'onset_threshold')
            slope_measurement_settings.onset_threshold = 3;
        end
        % Проверяем и добавляем недостающие поля для видимости
        if ~isfield(slope_measurement_settings, 'show_baseline')
            slope_measurement_settings.show_baseline = true;
        end
        if ~isfield(slope_measurement_settings, 'show_onset')
            slope_measurement_settings.show_onset = true;
        end
        if ~isfield(slope_measurement_settings, 'show_slope')
            slope_measurement_settings.show_slope = true;
        end
        if ~isfield(slope_measurement_settings, 'show_peak')
            slope_measurement_settings.show_peak = true;
        end
    end
    
    % Инициализация результатов если их нет
    if isempty(slope_measurement_results)
        slope_measurement_results = struct('baseline_value', {}, 'slope_value', {}, ...
                                         'peak_time', {}, 'peak_value', {}, ...
                                         'onset_time', {}, 'onset_value', {}, 'onset_method', {}, ...
                                         'metadata', {});
    else
        % Проверяем и добавляем недостающие поля для онсета в существующих результатах
        if ~isfield(slope_measurement_results, 'onset_time')
            for i = 1:length(slope_measurement_results)
                slope_measurement_results(i).onset_time = NaN;
                slope_measurement_results(i).onset_value = NaN;
                slope_measurement_results(i).onset_method = 'not_calculated';
            end
        end
        
        % Проверяем и добавляем недостающие поля для пика в существующих результатах
        if ~isfield(slope_measurement_results, 'peak_time')
            for i = 1:length(slope_measurement_results)
                slope_measurement_results(i).peak_time = NaN;
                slope_measurement_results(i).peak_value = NaN;
            end
        end
    end
    
    % Инициализация переменной для выделенной строки
    selected_row_slope = [];
    
    % Загрузка списка последних открытых файлов из настроек
    if exist(SettingsFilepath, 'file')
        try
            d = load(SettingsFilepath);
            if isfield(d, 'lastOpenedFiles')
                lastOpenedFiles = d.lastOpenedFiles;
            else
                lastOpenedFiles = {};
            end
        catch
            lastOpenedFiles = {};
        end
    else
        lastOpenedFiles = {};
    end
    


    
    
    % Инициализация переменной для выделенной строки измерений
    selected_measurement_row = [];
    
    % Инициализация глобальной переменной для метаданных
    current_measurement_metadata = [];
    
    % Инициализация глобальной функции обновления графика
    updateAnalysisPlotFunc_global = @updateAnalysisPlotFunc;
    
    % Инициализация флага автоанализа
    auto_analysis_mode = false;
    
    % Идентификатор (tag) для GUI фигуры
    figTag = 'SignalAnalysisGUI';
    
    % Закрываем окно просмотра сигналов при запуске анализа
    delete(findobj('Type', 'figure', 'Tag', 'SignalViewerGUI'));
    
    % Определяем названия колонок как единый источник (доступны во всех функциях)
    table_column_names = {'Stimulus', 'Slope', 'Peak Time (rel)', 'Peak Time (abs)', 'Peak Amplitude', 'Peak Value (rel)', 'Onset Time (rel)', 'Onset Time (abs)', 'Peak - Onset', 'Baseline', 'Channel', 'Stim Time', 'Info'};
    table_column_widths = {55, 50, 100, 100, 100, 100, 100, 100, 100, 80, 80, 80, 200};
    table_column_formats = {'numeric', 'numeric', 'numeric', 'numeric', 'numeric', 'numeric', 'numeric', 'numeric', 'numeric', 'numeric', 'numeric', 'numeric', 'char'};
    
    % Поиск открытой фигуры с заданным идентификатором
    guiFig = findobj('Type', 'figure', 'Tag', figTag);
    
    if ~isempty(guiFig)
        % Делаем существующее окно текущим (активным)
        figure(guiFig);
        return
    end
    
    % Создание главного окна с использованием базового положения из JSON
    figure_position = coordsData.base_figure_position;
    signalFig = figure('Name', 'Signal Analysis', 'Tag', figTag, ...
        'Resize', 'on', ...
        'NumberTitle', 'off', 'MenuBar', 'none', 'ToolBar', 'none', ...
        'Position', figure_position);
    
    % Применяем начальное масштабирование элементов сразу после создания окна
    % (аналогично signalViewerGUI.m)
    try
        coordsFile = fullfile(fileparts(mfilename('fullpath')), 'signalAnalysisGUI_coords.json');
        if exist(coordsFile, 'file')
            % Используем figure_position как базовую позицию
            ResizeElements(signalFig, coordsFile, figure_position);
        end
    catch ME
        warning('Error during initial element scaling: %s', ME.message);
    end

    % === Левая панель управления ===
    
        % Выбор канала
    uicontrol(signalFig, 'Style', 'text', 'Position', getElementPosition('channel_label'), ...
        'String', 'Channel:', 'HorizontalAlignment', 'left', 'Tag', 'channel_label');
    
    % Проверяем корректность hd.recChNames для popup
    if isfield(hd, 'recChNames') && iscell(hd.recChNames) && ~isempty(hd.recChNames)
        channel_names_for_popup = hd.recChNames;
    else
        channel_names_for_popup = {'Ch1'};
    end
    
    hChannelPopup = uicontrol(signalFig, 'Style', 'popupmenu', ...
        'Position', getElementPosition('channel_popup'), ...
        'String', channel_names_for_popup, ...
        'Value', min(slope_measurement_settings.channel, length(channel_names_for_popup)), ...
        'Callback', @channelCallback, 'Tag', 'channel_popup');
    
    % Настройки slope
    uicontrol(signalFig, 'Style', 'text', 'Position', getElementPosition('polarity_label'), ...
        'String', 'Peak Polarity:', 'HorizontalAlignment', 'left', 'Tag', 'polarity_label');
    hPolarityPopup = uicontrol(signalFig, 'Style', 'popupmenu', ...
        'Position', getElementPosition('polarity_popup'), ...
        'String', {'Positive', 'Negative'}, ...
        'Value', strcmp(slope_measurement_settings.peak_polarity, 'negative') + 1, ...
        'Callback', @polarityCallback, 'Tag', 'polarity_popup');
    
    uicontrol(signalFig, 'Style', 'text', 'Position', getElementPosition('slope_percent_label'), ...
        'String', 'Slope Percent:', 'HorizontalAlignment', 'left', 'Tag', 'slope_percent_label');
    hSlopePercentEdit = uicontrol(signalFig, 'Style', 'edit', ...
        'Position', getElementPosition('slope_percent_edit'), ...
        'String', num2str(slope_measurement_settings.slope_percent), ...
        'Callback', @slopePercentCallback, 'Tag', 'slope_percent_edit');
    uicontrol(signalFig, 'Style', 'text', 'Position', getElementPosition('slope_percent_unit'), ...
        'String', '%', 'HorizontalAlignment', 'left', 'Tag', 'slope_percent_unit');
    
    % Настройки онсета (скрыты и неактивны)
    hOnsetMethodLabel = uicontrol(signalFig, 'Style', 'text', 'Position', getElementPosition('onset_method_label'), ...
        'String', 'Onset Method:', 'HorizontalAlignment', 'left', 'Visible', 'off', 'Tag', 'onset_method_label');
    hOnsetMethodPopup = uicontrol(signalFig, 'Style', 'popupmenu', ...
        'Position', getElementPosition('onset_method_popup'), ...
        'String', {'First Derivative', 'Second Derivative', 'Threshold Crossing', 'Inverted Peak'}, ...
        'Value', getOnsetMethodIndex(slope_measurement_settings.onset_method), ...
        'Callback', @onsetMethodCallback, 'Visible', 'off', 'Enable', 'off', 'Tag', 'onset_method_popup');
    
    hOnsetThresholdLabel = uicontrol(signalFig, 'Style', 'text', 'Position', getElementPosition('onset_threshold_label'), ...
        'String', 'Onset Threshold:', 'HorizontalAlignment', 'left', 'Visible', 'off', 'Tag', 'onset_threshold_label');
    hOnsetThresholdEdit = uicontrol(signalFig, 'Style', 'edit', ...
        'Position', getElementPosition('onset_threshold_edit'), ...
        'String', num2str(slope_measurement_settings.onset_threshold), ...
        'Callback', @onsetThresholdCallback, 'Visible', 'off', 'Enable', 'off', 'Tag', 'onset_threshold_edit');
    hOnsetThresholdUnit = uicontrol(signalFig, 'Style', 'text', 'Position', getElementPosition('onset_threshold_unit'), ...
        'String', 'std', 'HorizontalAlignment', 'left', 'Visible', 'off', 'Tag', 'onset_threshold_unit');
    
    % Разделитель baseline
    uicontrol(signalFig, 'Style', 'text', 'Position', getElementPosition('baseline_separator'), ...
        'String', '────── Baseline Range ──────', ...
        'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'Tag', 'baseline_separator');
    
    % Baseline начало
    uicontrol(signalFig, 'Style', 'text', 'Position', getElementPosition('baseline_start_label'), ...
        'String', 'Baseline Start:', 'HorizontalAlignment', 'left', 'Tag', 'baseline_start_label');
    hBaselineStartEdit = uicontrol(signalFig, 'Style', 'edit', ...
        'Position', getElementPosition('baseline_start_edit'), ...
        'String', '0', 'Callback', @baselineStartCallback, 'Tag', 'baseline_start_edit');
    uicontrol(signalFig, 'Style', 'text', 'Position', getElementPosition('baseline_start_unit'), ...
        'String', selectedUnit, 'HorizontalAlignment', 'left', 'Tag', 'baseline_start_unit');
    
    % Baseline конец
    uicontrol(signalFig, 'Style', 'text', 'Position', getElementPosition('baseline_end_label'), ...
        'String', 'Baseline End:', 'HorizontalAlignment', 'left', 'Tag', 'baseline_end_label');
    hBaselineEndEdit = uicontrol(signalFig, 'Style', 'edit', ...
        'Position', getElementPosition('baseline_end_edit'), ...
        'String', '0', 'Callback', @baselineEndCallback, 'Tag', 'baseline_end_edit');
    uicontrol(signalFig, 'Style', 'text', 'Position', getElementPosition('baseline_end_unit'), ...
        'String', selectedUnit, 'HorizontalAlignment', 'left', 'Tag', 'baseline_end_unit');
    
    % Разделитель peak
    uicontrol(signalFig, 'Style', 'text', 'Position', getElementPosition('peak_separator'), ...
        'String', '────── Peak Search Range ──────', ...
        'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'Tag', 'peak_separator');
    
    % Peak начало
    uicontrol(signalFig, 'Style', 'text', 'Position', getElementPosition('peak_start_label'), ...
        'String', 'Peak Start:', 'HorizontalAlignment', 'left', 'Tag', 'peak_start_label');
    hPeakStartEdit = uicontrol(signalFig, 'Style', 'edit', ...
        'Position', getElementPosition('peak_start_edit'), ...
        'String', '0', 'Callback', @peakStartCallback, 'Tag', 'peak_start_edit');
    uicontrol(signalFig, 'Style', 'text', 'Position', getElementPosition('peak_start_unit'), ...
        'String', selectedUnit, 'HorizontalAlignment', 'left', 'Tag', 'peak_start_unit');
    
    % Peak конец
    uicontrol(signalFig, 'Style', 'text', 'Position', getElementPosition('peak_end_label'), ...
        'String', 'Peak End:', 'HorizontalAlignment', 'left', 'Tag', 'peak_end_label');
    hPeakEndEdit = uicontrol(signalFig, 'Style', 'edit', ...
        'Position', getElementPosition('peak_end_edit'), ...
        'String', '0', 'Callback', @peakEndCallback, 'Tag', 'peak_end_edit');
    uicontrol(signalFig, 'Style', 'text', 'Position', getElementPosition('peak_end_unit'), ...
        'String', selectedUnit, 'HorizontalAlignment', 'left', 'Tag', 'peak_end_unit');
    
    % Разделитель результатов
    uicontrol(signalFig, 'Style', 'text', 'Position', getElementPosition('results_separator'), ...
        'String', '────── Results ──────', ...
        'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'Tag', 'results_separator');
    
    % Результаты
    hBaselineText = uicontrol(signalFig, 'Style', 'text', 'Position', getElementPosition('baseline_text'), ...
        'String', 'Baseline:', 'HorizontalAlignment', 'left', 'Tag', 'baseline_text');
    hBaselineCheckbox = uicontrol(signalFig, 'Style', 'checkbox', 'Position', getElementPosition('baseline_checkbox'), ...
        'Value', slope_measurement_settings.show_baseline, 'Callback', @baselineVisibilityCallback, 'Tag', 'baseline_checkbox');
    
    hPeakText = uicontrol(signalFig, 'Style', 'text', 'Position', getElementPosition('peak_text'), ...
        'String', 'Peak:', 'HorizontalAlignment', 'left', 'Tag', 'peak_text');
    hPeakCheckbox = uicontrol(signalFig, 'Style', 'checkbox', 'Position', getElementPosition('peak_checkbox'), ...
        'Value', slope_measurement_settings.show_peak, 'Callback', @peakVisibilityCallback, 'Tag', 'peak_checkbox');
    
    hSlopeText = uicontrol(signalFig, 'Style', 'text', 'Position', getElementPosition('slope_text'), ...
        'String', 'Slope:', 'HorizontalAlignment', 'left', 'Tag', 'slope_text');
    hSlopeCheckbox = uicontrol(signalFig, 'Style', 'checkbox', 'Position', getElementPosition('slope_checkbox'), ...
        'Value', slope_measurement_settings.show_slope, 'Callback', @slopeVisibilityCallback, 'Tag', 'slope_checkbox');
    
    hOnsetText = uicontrol(signalFig, 'Style', 'text', 'Position', getElementPosition('onset_text'), ...
        'String', 'Onset:', 'HorizontalAlignment', 'left', 'Tag', 'onset_text');
    hOnsetCheckbox = uicontrol(signalFig, 'Style', 'checkbox', 'Position', getElementPosition('onset_checkbox'), ...
        'Value', slope_measurement_settings.show_onset, 'Callback', @onsetVisibilityCallback, 'Tag', 'onset_checkbox');
    
    % Разделитель навигации
    uicontrol(signalFig, 'Style', 'text', 'Position', getElementPosition('navigation_separator'), ...
        'String', '────── Navigation ──────', ...
        'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'Tag', 'navigation_separator');
    
    % Статус навигации
    hNavigationStatus = uicontrol(signalFig, 'Style', 'text', 'Position', getElementPosition('navigation_status'), ...
        'String', 'Mode: time', 'HorizontalAlignment', 'left', 'Tag', 'navigation_status');
    
    % Кнопки навигации (сдвигаем вниз)
    hPrevBtn = uicontrol(signalFig, 'Style', 'pushbutton', 'String', '◀ Previous', ...
        'Position', getElementPosition('prev_btn'), 'Callback', @(~,~)shiftTimeSlope(-1), 'Tag', 'prev_btn');
    hNextBtn = uicontrol(signalFig, 'Style', 'pushbutton', 'String', 'Next ▶', ...
        'Position', getElementPosition('next_btn'), 'Callback', @(~,~)shiftTimeSlope(1), 'Tag', 'next_btn');
    
    % Кнопка автоматического измерения всех участков
    hAutoMeasureBtn = uicontrol(signalFig, 'Style', 'pushbutton', 'String', 'Auto Measure All', ...
        'Position', getElementPosition('auto_measure_btn'), 'Callback', @autoMeasureAllTimeRanges, 'Tag', 'auto_measure_btn');
    
    % Кнопка открытия файла
    uicontrol(signalFig, 'Style', 'pushbutton', 'String', 'Open File', ...
        'Position', getElementPosition('open_file_btn'), 'Callback', @openFile, 'Tag', 'open_file_btn');
    
    % Кнопка File Manager (использует прежние координаты Load Events)
    uicontrol(signalFig, 'Style', 'pushbutton', 'String', 'File Manager', ...
        'Position', getElementPosition('load_events_btn'), ...
        'Callback', @(~,~)fileManagerGUI(), 'Tag', 'file_manager_btn');
    
    % Кнопка групповых настроек
    uicontrol(signalFig, 'Style', 'pushbutton', 'String', 'Settings', ...
        'Position', getElementPosition('settings_btn'), 'Callback', @openGroupSettingsEditor, 'Tag', 'settings_btn');
    
 
        
    
    % === График ===
    % Создаем панель для графика (как в app.m)
    plotPanel = uipanel('Parent', signalFig, ...
        'Position', getElementPosition('plot_container'), ...
        'Tag', 'plot_container');
    
    % Создаем оси внутри панели с координатами из JSON
    hPlotAxes = axes('Parent', plotPanel, ...
        'Position', getElementPosition('main_axes'), ...  % Координаты из JSON
        'Tag', 'main_axes');
    
    % Плейсхолдер пока файл не загружен
    set(hPlotAxes, 'Visible', 'off');
    text(hPlotAxes, 0.5, 0.5, 'Load ZAV or EV file', 'color', 'r', 'horizontalalignment', 'center');
    
    % Кнопка зума в левом углу графика
    hZoomButton = uicontrol(signalFig, 'Style', 'pushbutton', 'String', 'Zoom', ...
        'Position', getElementPosition('zoom_btn'), 'Callback', @toggleZoom, 'Tag', 'zoom_btn');
    
    % Кнопка Autoscale для применения оптимальных размеров осей
    hAutoscaleButton = uicontrol(signalFig, 'Style', 'pushbutton', 'String', 'Autoscale', ...
        'Position', getElementPosition('autoscale_btn'), 'Callback', @applyAutoscale, 'Tag', 'autoscale_btn');

    % === Кнопки управления трассами (поверх графика) ===
    % Кнопка добавления результата
    hAddBtn = uicontrol(signalFig, 'Style', 'pushbutton', 'String', 'Add', ...
        'Position', getElementPosition('add_btn'), 'Callback', @addResult, 'Tag', 'add_btn');
    
    % Кнопка удаления результата
    hRemoveBtn = uicontrol(signalFig, 'Style', 'pushbutton', 'String', 'Remove', ...
        'Position', getElementPosition('remove_btn'), 'Callback', @removeResult, 'Tag', 'remove_btn');
    
    % Кнопка замены результата
    hReplaceBtn = uicontrol(signalFig, 'Style', 'pushbutton', 'String', 'Replace', ...
        'Position', getElementPosition('replace_btn'), 'Callback', @replaceResult, 'Enable', 'off', 'Tag', 'replace_btn');
    
    % Кнопка просмотра среднего сигнала
    hMeanResultsBtn = uicontrol(signalFig, 'Style', 'pushbutton', 'String', 'Av. Trace', ...
        'Position', getElementPosition('mean_results_btn'), 'Callback', @toggleMeanResults, 'Enable', 'off', 'Tag', 'mean_results_btn');
    
    % Кнопка сбора всех метаданных
    uicontrol(signalFig, 'Style', 'pushbutton', 'String', 'Collect All', ...
        'Position', getElementPosition('collect_all_btn'), 'Callback', @collectAllMetadata, 'Tag', 'collect_all_btn');
    
    % Кнопка загрузки результатов
    uicontrol(signalFig, 'Style', 'pushbutton', 'String', 'Load', ...
        'Position', getElementPosition('load_btn'), 'Callback', @loadResults, 'Tag', 'load_btn');
    
    % Кнопка сохранения результатов
    uicontrol(signalFig, 'Style', 'pushbutton', 'String', 'Save', ...
        'Position', getElementPosition('save_btn'), 'Callback', @saveResults, 'Tag', 'save_btn');
    
    % Кнопка сохранения изображения
    uicontrol(signalFig, 'Style', 'pushbutton', 'String', 'Save Image', ...
        'Position', getElementPosition('save_image_btn'), 'Callback', @saveImage, 'Tag', 'save_image_btn');

    % === Таблица текущих результатов ===
    % Разделитель таблицы текущих результатов
    uicontrol(signalFig, 'Style', 'text', 'Position', getElementPosition('current_results_table_separator'), ...
        'String', '────── Current Results ──────', 'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'Tag', 'current_results_table_separator');
    
    % Таблица текущих результатов (одна строчка)
    hCurrentResultsTable = uitable(signalFig, 'Position', getElementPosition('current_results_table'), ...
        'ColumnName', {'Slope', 'Peak Time (rel)', 'Peak Amplitude', 'Onset Time (rel)', 'Baseline'}, ...
        'ColumnWidth', {90, 90, 90, 90, 90}, ...
        'ColumnFormat', {'numeric', 'numeric', 'numeric', 'numeric', 'numeric'}, ...
        'Data', {NaN, NaN, NaN, NaN, NaN}, ...
        'RowName', [], 'Tag', 'current_results_table');
    

    % === Таблица результатов ===
    % Разделитель таблицы результатов
    uicontrol(signalFig, 'Style', 'text', 'Position', getElementPosition('results_table_separator'), ...
        'String', '────── Results Table ──────', 'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'Tag', 'results_table_separator');

    % Таблица собираемых результатов
    hResultsTable = uitable(signalFig, 'Position', getElementPosition('results_table'), ...
        'ColumnName', table_column_names, ...
        'ColumnWidth', table_column_widths, ...
        'ColumnFormat', table_column_formats, ...
        'Data', {}, ...
        'RowName', {}, ...
        'CellSelectionCallback', @tableSelectionChanged, 'Tag', 'results_table');
    
    % Кнопка очистки собираемых результатов
    uicontrol(signalFig, 'Style', 'pushbutton', 'String', 'Clear Table', ...
        'Position', getElementPosition('clear_table_btn'), 'Callback', @clearAllResults, 'Tag', 'clear_table_btn');

    % === Таблица средних значений ===
    % Разделитель таблицы средних значений
    uicontrol(signalFig, 'Style', 'text', 'Position', getElementPosition('average_table_separator'), ...
        'String', '────── Average Values ──────', 'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'Tag', 'average_table_separator');
    
    % Таблица средних значений (одна строчка)
    hAverageTable = uitable(signalFig, 'Position', getElementPosition('average_table'), ...
        'ColumnName', {'Slope', 'Peak Time (rel)', 'Peak Amplitude', 'Onset Time (rel)', 'Baseline', 'Peak - Onset'}, ...
        'ColumnWidth', {75, 75, 75, 75, 75, 75}, ...
        'ColumnFormat', {'numeric', 'numeric', 'numeric', 'numeric', 'numeric', 'numeric'}, ...
        'Data', {NaN, NaN, NaN, NaN, NaN, NaN}, ...
        'RowName', [], 'Tag', 'average_table');
    
    % Переменные для хранения графических объектов
    hBaselineLines = [];  % линии baseline диапазона
    hPeakLines = [];      % линии peak диапазона  
    hSlopeLine = [];      % линия slope regression
    hPeakMarker = [];     % маркер пика
    hOnsetMarker = [];    % маркер онсета
    hBaselineMarkers = [];% маркеры baseline
    hPeakMarkers = [];    % маркеры peak диапазона
    
    % Локальные переменные для зума
    zoom_active = false;
    zoom_start_rel = 0;    % относительная позиция начала зума по времени (0-1)
    zoom_end_rel = 1;      % относительная позиция конца зума по времени (0-1)
    zoom_y_min = [];       % минимальная амплитуда зума
    zoom_y_max = [];       % максимальная амплитуда зума
    original_ylim = [];    % исходные границы амплитуды для восстановления
    original_xlim = [];    % исходные границы времени для восстановления
    
    % Переменная для относительного сдвига времени
    rel_shift = 0;
    
    % Переменные для среднего сигнала
    mean_results_active = false;
    mean_signal_data = [];
    mean_signal_time = [];
    
    % Переменные для перетаскивания области зума
    pan_active = false;
    pan_start_mouse_pos = [];
    pan_start_xlim = [];
    pan_start_ylim = [];
    
    % Флаг для восстановления состояния из метаданных
    restoring_from_metadata = false;
    
    % Пытаемся автоматически открыть последний файл при запуске
    autoOpenLastFile();

    % Добавляем обработку клавиш для навигации
    set(signalFig, 'KeyPressFcn', @keyPressFunction);
    
    % Добавляем обработку колеса мыши для зума
    set(signalFig, 'WindowScrollWheelFcn', @mouseWheelZoom);
    
    % Добавляем обработку правой кнопки мыши для перетаскивания зума
    set(hPlotAxes, 'ButtonDownFcn', @rightClickPan);
    
    % Добавляем обработчик изменения размера окна для масштабирования элементов
    set(signalFig, 'SizeChangedFcn', @resizeSignalAnalysisWindow);
    
    
    % Добавляем обработчик закрытия окна для сохранения положения
    set(signalFig, 'CloseRequestFcn', @closeSignalAnalysisWindow);
    
    % Загружаем позиции курсоров из настроек при первом запуске
    %loadCursorPositionsFromSettings();
    
    % === Callback функции ===
        
    function initializeTimes()
        % Проверяем, есть ли сохраненные позиции курсоров
        if ~isempty(slope_measurement_results) && length(slope_measurement_results) > 0
            % Восстанавливаем позиции из последнего результата
            last_result = slope_measurement_results(end);
            if isfield(last_result.metadata, 'cursor_positions')
                slope_measurement_settings.baseline_start = last_result.metadata.cursor_positions.baseline_start;
                slope_measurement_settings.baseline_end = last_result.metadata.cursor_positions.baseline_end;
                slope_measurement_settings.peak_start = last_result.metadata.cursor_positions.peak_start;
                slope_measurement_settings.peak_end = last_result.metadata.cursor_positions.peak_end;
                        % Позиции загружены из результатов
    else
        % Используем стандартные позиции
        setDefaultCursorPositions();
    end
else
    % Пытаемся загрузить позиции из главного файла настроек
    try
        SettingsFilepath = fullfile(tempdir, 'ev_settings.mat');
        if exist(SettingsFilepath, 'file')
            loadedSettings = load(SettingsFilepath, '-mat');
            if isfield(loadedSettings, 'cursor_positions')
                % Восстанавливаем абсолютные позиции из относительных используя глобальную переменную rel_shift
                slope_measurement_settings.baseline_start = loadedSettings.cursor_positions.baseline_start + rel_shift;
                slope_measurement_settings.baseline_end = loadedSettings.cursor_positions.baseline_end + rel_shift;
                slope_measurement_settings.peak_start = loadedSettings.cursor_positions.peak_start + rel_shift;
                slope_measurement_settings.peak_end = loadedSettings.cursor_positions.peak_end + rel_shift;
            else
                % Используем стандартные позиции
                setDefaultCursorPositions();
            end
        else
            % Используем стандартные позиции
            setDefaultCursorPositions();
        end
    catch ME
        % Используем стандартные позиции
        setDefaultCursorPositions();
    end
end

% Обновляем edit fields с учетом единиц времени
updateCursorEditFields();
        
    end
    
    function setDefaultCursorPositions()
        % Вычисляем стандартные времена для baseline и peak диапазонов
        time_range = chosen_time_interval(2) - chosen_time_interval(1);
        
        % Baseline: первые 20% временного интервала
        baseline_start = chosen_time_interval(1) + time_range * 0.1;
        baseline_end = chosen_time_interval(1) + time_range * 0.3;
        
        % Peak search: последние 60% временного интервала  
        peak_start = chosen_time_interval(1) + time_range * 0.4;
        peak_end = chosen_time_interval(1) + time_range * 0.9;
        
        % Сохраняем в настройках
        slope_measurement_settings.baseline_start = baseline_start;
        slope_measurement_settings.baseline_end = baseline_end;
        slope_measurement_settings.peak_start = peak_start;
        slope_measurement_settings.peak_end = peak_end;
    end
    
    function updateCursorEditFields()
        % Обновляет edit fields с учетом единиц времени и относительного сдвига
        
        if strcmp(selectedCenter, 'stimulus') && stims_exist && ~isempty(stims)
            rel_shift = stims(stim_inx);
        else
            rel_shift = chosen_time_interval(1);
        end
        
        set(hBaselineStartEdit, 'String', sprintf('%.3f', (slope_measurement_settings.baseline_start - rel_shift) * timeUnitFactor));
        set(hBaselineEndEdit, 'String', sprintf('%.3f', (slope_measurement_settings.baseline_end - rel_shift) * timeUnitFactor));
        set(hPeakStartEdit, 'String', sprintf('%.3f', (slope_measurement_settings.peak_start - rel_shift) * timeUnitFactor));
        set(hPeakEndEdit, 'String', sprintf('%.3f', (slope_measurement_settings.peak_end - rel_shift) * timeUnitFactor));
    end
    
    function channelCallback(src, ~)
        slope_measurement_settings.channel = get(src, 'Value');
        
        % Вычисляем и применяем оптимальные границы осей
        [optimal_xlim, optimal_ylim] = calculateOptimalAxisLimits(true);
        
        % Сохраняем как original для правильной работы зума
        original_xlim = optimal_xlim;
        original_ylim = optimal_ylim;
        
        % Обновляем график
        updatePlotAndCalculation();
        
        fprintf('✓ Channel changed, optimal axis sizes applied\n');
    end
    
    function polarityCallback(src, ~)
        polarities = get(src, 'String');
        slope_measurement_settings.peak_polarity = lower(polarities{get(src, 'Value')});
        updatePlotAndCalculation();
    end
    
    function slopePercentCallback(src, ~)
        new_percent = str2double(get(src, 'String'));
        if ~isnan(new_percent) & new_percent > 0 & new_percent < 100
            slope_measurement_settings.slope_percent = new_percent;
            updatePlotAndCalculation();
        end
    end
    
    function baselineStartCallback(src, ~)
        new_time = str2double(get(src, 'String')) / timeUnitFactor;
        if ~isnan(new_time)
            slope_measurement_settings.baseline_start = rel_shift + new_time;
            updatePlotAndCalculation();
            
            % Сохраняем позиции курсоров в настройки
            saveCurrentMarkerPositions();
        end
    end
    
    function baselineEndCallback(src, ~)
        new_time = str2double(get(src, 'String')) / timeUnitFactor;
        if ~isnan(new_time)
            slope_measurement_settings.baseline_end = rel_shift + new_time;
            updatePlotAndCalculation();
            
            % Сохраняем позиции курсоров в настройки
            saveCurrentMarkerPositions();
        end
    end
    
    function peakStartCallback(src, ~)
        new_time = str2double(get(src, 'String')) / timeUnitFactor;
        if ~isnan(new_time)
            slope_measurement_settings.peak_start = rel_shift + new_time;
            updatePlotAndCalculation();
            
            % Сохраняем позиции курсоров в настройки
            saveCurrentMarkerPositions();
        end
    end
    
    function peakEndCallback(src, ~)
        new_time = str2double(get(src, 'String')) / timeUnitFactor;
        if ~isnan(new_time)
            slope_measurement_settings.peak_end = rel_shift + new_time;
            updateNavigationStatus(); % Синхронизируем с основным приложением
            updatePlotAndCalculation();
            
            % Сохраняем позиции курсоров в настройки
            saveCurrentMarkerPositions();
        end
    end
    
    function onsetMethodCallback(src, ~)
        methods = get(src, 'String');
        selected_method_name = methods{get(src, 'Value')};
        
        % Преобразуем названия методов в внутренние имена
        switch selected_method_name
            case 'First Derivative'
                selected_method = 'derivative';
            case 'Second Derivative'
                selected_method = 'second_derivative';
            case 'Threshold Crossing'
                selected_method = 'threshold_crossing';
            case 'Inverted Peak'
                selected_method = 'inverted_peak';
            otherwise
                selected_method = 'derivative'; % по умолчанию
        end
        
        slope_measurement_settings.onset_method = selected_method;
        % updateOnsetThresholdVisibility();
        updatePlotAndCalculation();
    end
    
    function onsetThresholdCallback(src, ~)
        new_threshold = str2double(get(src, 'String'));
        if ~isnan(new_threshold) & new_threshold > 0
            slope_measurement_settings.onset_threshold = new_threshold;
            updatePlotAndCalculation();
        end
    end
    
    function baselineVisibilityCallback(src, ~)
        slope_measurement_settings.show_baseline = get(src, 'Value');
        updatePlotAndCalculation();
    end
    
    function slopeVisibilityCallback(src, ~)
        slope_measurement_settings.show_slope = get(src, 'Value');
        updatePlotAndCalculation();
    end
    
    function onsetVisibilityCallback(src, ~)
        slope_measurement_settings.show_onset = get(src, 'Value');
        updatePlotAndCalculation();
    end
    
    function peakVisibilityCallback(src, ~)
        slope_measurement_settings.show_peak = get(src, 'Value');
        updatePlotAndCalculation();
    end
    
    function method_index = getOnsetMethodIndex(method_name)
        % Вспомогательная функция для определения индекса метода в popupmenu
        method_map = containers.Map({'derivative', 'second_derivative', 'threshold_crossing', 'inverted_peak'}, {1, 2, 3, 4});
        if method_map.isKey(method_name)
            method_index = method_map(method_name);
        else
            method_index = 1; % по умолчанию
        end
    end
    
    
    function updatePlotAndCalculation()
        % Координирует вычисление результатов и обновление графика
        
        % Пропускаем обновление графика в режиме автоанализа
        if exist('auto_analysis_mode', 'var') & auto_analysis_mode
            % Только вычисляем результаты, НЕ обновляем график
            [slope_value, slope_angle, peak_time, peak_value, baseline_value, onset_time, onset_value, measurement_metadata] = calculateResults();
            return;
        end
        
        % Обновляем временной интервал на основе режима и временных окон
        if strcmp(selectedCenter, 'event') && events_exist && ~isempty(events)
            % В режиме события центрируем интервал по текущему событию
            chosen_time_interval(1) = events(event_inx);
            chosen_time_interval(2) = chosen_time_interval(1) + time_forward;
        elseif strcmp(selectedCenter, 'stimulus') && stims_exist && ~isempty(stims)
            % В режиме стимула центрируем интервал по текущему стимулу
            chosen_time_interval(1) = stims(stim_inx);
            chosen_time_interval(2) = chosen_time_interval(1) + time_forward;
        elseif strcmp(selectedCenter, 'sweep') && isstruct(sweep_info) && sweep_info.is_sweep_data
            % В режиме sweep используем времена свипов
            chosen_time_interval(1) = sweep_info.sweep_times(sweep_inx);
            chosen_time_interval(2) = chosen_time_interval(1) + time_forward;
        elseif strcmp(selectedCenter, 'time')
            % В режиме time обновляем только правую границу
            chosen_time_interval(2) = chosen_time_interval(1) + time_forward;
        end
        
        % Сначала вычисляем все результаты
        [slope_value, slope_angle, peak_time, peak_value, baseline_value, onset_time, onset_value, measurement_metadata] = calculateResults();
        
        % Затем обновляем график и визуализацию
        updatePlotVisualization();
    end
    
    function [slope_value, slope_angle, peak_time, peak_value, baseline_value, onset_time, onset_value, measurement_metadata] = calculateResults()
        % Вычисляет все результаты измерений без отрисовки
        
        % Инициализируем все выходные переменные
        slope_value = NaN;
        slope_angle = NaN;
        peak_time = NaN;
        peak_value = NaN;
        baseline_value = NaN;
        onset_time = NaN;
        onset_value = NaN;
        measurement_metadata = struct();
        
        [channel_data, time_in] = getCurrentData();
        
        % Получаем параметры для расчета
        baseline_start = slope_measurement_settings.baseline_start;
        baseline_end = slope_measurement_settings.baseline_end;
        peak_start = slope_measurement_settings.peak_start;
        peak_end = slope_measurement_settings.peak_end;
        slope_percent = slope_measurement_settings.slope_percent;
        peak_polarity = slope_measurement_settings.peak_polarity;
        
        % Создаем структуру baseline_data для calculateMeasurementByType
        baseline_data_struct = struct();
        
        if mean_results_active && ~isempty(mean_signal_data) && ~isempty(mean_signal_time)
            % В режиме среднего сигнала используем относительные координаты
            [baseline_rel, peak_rel] = getRelativePositions();
            baseline_data_struct.baseline_start = baseline_rel.start;
            baseline_data_struct.baseline_end = baseline_rel.end;
            baseline_data_struct.peak_start = peak_rel.start;
            baseline_data_struct.peak_end = peak_rel.end;
            time_in_rel = time_in;
        else
            % В обычном режиме используем абсолютные координаты с вычитанием rel_shift
            baseline_data_struct.baseline_start = baseline_start - rel_shift;
            baseline_data_struct.baseline_end = baseline_end - rel_shift;
            baseline_data_struct.peak_start = peak_start - rel_shift;
            baseline_data_struct.peak_end = peak_end - rel_shift;
            time_in_rel = time_in - rel_shift;
        end
        
        baseline_data_struct.slope_percent = slope_percent;
        baseline_data_struct.peak_polarity = peak_polarity;
        
        % Расчет slope с использованием calculateMeasurementByType
        
        [slope_value, measurement_metadata] = calculateMeasurementByType(channel_data, time_in_rel, ...
            baseline_data_struct.peak_start, baseline_data_struct.peak_end, 'Slope', baseline_data_struct);
        
        % Добавляем rel_shift в метаданные для возможности получения абсолютного времени
        measurement_metadata.rel_shift = rel_shift;
        
        % Сохраняем метаданные в глобальную переменную для использования в addResult
        current_measurement_metadata = measurement_metadata;
        
        % Извлекаем все необходимые значения из метаданных
        if isfield(measurement_metadata, 'slope_angle')
            slope_angle = measurement_metadata.slope_angle;
        else
            slope_angle = NaN;
        end
        
        if isfield(measurement_metadata, 'peak_time')
            peak_time = measurement_metadata.peak_time;
        else
            peak_time = NaN;
        end
        
        if isfield(measurement_metadata, 'peak_value')
            peak_value = measurement_metadata.peak_value;
        else
            peak_value = NaN;
        end
        
        if isfield(measurement_metadata, 'baseline_value')
            baseline_value = measurement_metadata.baseline_value;
        else
            baseline_value = NaN;
        end
        
        if isfield(measurement_metadata, 'onset_time')
            onset_time = measurement_metadata.onset_time;
        else
            onset_value = NaN;
        end
        
        if isfield(measurement_metadata, 'onset_value')
            onset_value = measurement_metadata.onset_value;
        else
            onset_value = NaN;
        end
    end

    function updatePlotVisualization()
        % Обновляет график и визуализацию без пересчета результатов
        
        % Получаем параметры для отображения лимитов
        baseline_start = slope_measurement_settings.baseline_start;
        baseline_end = slope_measurement_settings.baseline_end;
        peak_start = slope_measurement_settings.peak_start;
        peak_end = slope_measurement_settings.peak_end;
        
        % [channel_data, time_in] = getCurrentData();
        
        % Преобразование времени с учетом единиц
        if mean_results_active && ~isempty(mean_signal_data) && ~isempty(mean_signal_time)
            % В режиме среднего сигнала время уже нормализовано
            time_display = time_in * timeUnitFactor;
        else
            % В обычном режиме нормализуем относительно rel_shift
            time_display = (time_in - rel_shift) * timeUnitFactor;
        end

        % Отображение графика
        axes(hPlotAxes);
        cla(hPlotAxes);
        hold on;
        
        plot(time_display, channel_data, 'b-', 'LineWidth', 1);
        
        % Проверяем границы осей
        xlims = xlim;
        ylims = ylim;
        
        % Проверяем корректность данных
        if isempty(channel_data) || all(isnan(channel_data)) || all(isinf(channel_data))
            return;
        end
        

        % Отрисовка элементов визуализации из глобальных переменных
        if exist('measurement_metadata', 'var') && isfield(measurement_metadata, 'visualization')
            % Отрисовка пика
            if slope_measurement_settings.show_peak && isfield(measurement_metadata.visualization, 'peak_marker')
                peak_obj = measurement_metadata.visualization.peak_marker;
                if strcmp(peak_obj.type, 'point') && ~isnan(peak_obj.coordinates.x)
                    renderVisualizationObject(peak_obj, hPlotAxes, timeUnitFactor);
                    
                    % Добавляем подпись
                    peak_time_display = peak_obj.coordinates.x * timeUnitFactor;
                    text(peak_time_display, peak_obj.coordinates.y + (ylims(2) - ylims(1)) * 0.05, ...
                        sprintf('Peak: %.3f', peak_time_display), ...
                        'HorizontalAlignment', 'center', 'Color', peak_obj.style.color, 'FontWeight', 'bold');
                end
            end
            
            % Отрисовка онсета
            if slope_measurement_settings.show_onset && exist('onset_time', 'var') && ~isnan(onset_time)
                onset_time_display = onset_time * timeUnitFactor;
                hOnsetMarker = plot(onset_time_display, onset_value, 'mo', 'MarkerSize', 8, 'MarkerFaceColor', 'm');
                text(onset_time_display, onset_value - (ylims(2) - ylims(1)) * 0.05, ...
                    sprintf('Onset: %.3f', onset_time_display), ...
                    'HorizontalAlignment', 'center', 'Color', 'm', 'FontWeight', 'bold');
            end
            
            % Отрисовка slope линии и точек регрессии
            if slope_measurement_settings.show_slope && isfield(measurement_metadata.visualization, 'slope_line')
                slope_obj = measurement_metadata.visualization.slope_line;
                if strcmp(slope_obj.type, 'line') && ~isnan(slope_obj.coordinates.x1)
                    renderVisualizationObject(slope_obj, hPlotAxes, timeUnitFactor);
                    
                    % Отрисовываем точки регрессии
                    if isfield(measurement_metadata.visualization, 'regression_markers')
                        reg_obj = measurement_metadata.visualization.regression_markers;
                        renderVisualizationObject(reg_obj, hPlotAxes, timeUnitFactor);
                    end
                end
            end
        end
        
        
        % Обновление таблицы текущих результатов
        if exist('slope_value', 'var') && ~isnan(slope_value)
            current_slope = slope_value;
        else
            current_slope = NaN;
        end
        
        if exist('peak_time', 'var') && ~isnan(peak_time)
            current_peak_time = peak_time * timeUnitFactor;
        else
            current_peak_time = NaN;
        end
        
        if exist('peak_value', 'var') && ~isnan(peak_value)
            current_peak_amplitude = peak_value;
        else
            current_peak_amplitude = NaN;
        end
        
        if exist('onset_time', 'var') && ~isnan(onset_time)
            current_onset_time = onset_time * timeUnitFactor;
        else
            current_onset_time = NaN;
        end
        
        if exist('baseline_value', 'var') && ~isnan(baseline_value)
            current_baseline = baseline_value;
        else
            current_baseline = NaN;
        end
        
        % Обновляем таблицу текущих результатов
        set(hCurrentResultsTable, 'Data', {current_slope, current_peak_time, current_peak_amplitude, current_onset_time, current_baseline});
        

        
        % Рисуем линии лимитов в самом конце, после установки всех лимитов
        ylims = ylim;
        
        % Отображение baseline диапазона (синие линии) - только если включено
        if slope_measurement_settings.show_baseline
            if mean_results_active && ~isempty(mean_signal_data) && ~isempty(mean_signal_time)
                rel_shift = stims(stim_inx);
                % В режиме среднего сигнала времена уже нормализованы
                t_bl_start = (baseline_start - rel_shift) * timeUnitFactor;
                t_bl_end = (baseline_end - rel_shift) * timeUnitFactor;
            else
                % В обычном режиме нормализуем относительно rel_shift
                t_bl_start = (baseline_start - rel_shift) * timeUnitFactor;
                t_bl_end = (baseline_end - rel_shift) * timeUnitFactor;
            end
            hBaselineLines(1) = line([t_bl_start, t_bl_start], ylims, 'Color', 'b', 'LineWidth', 2, 'LineStyle', ':');
            hBaselineLines(2) = line([t_bl_end, t_bl_end], ylims, 'Color', 'b', 'LineWidth', 2, 'LineStyle', ':');
            % Горизонтальная линия baseline через весь график (точечный пунктир)
            xlims = xlim;
            hBaselineLines(3) = line([xlims(1), xlims(2)], [baseline_value, baseline_value], 'Color', 'b', 'LineWidth', 1, 'LineStyle', ':');
            
            % Подписи диапазонов
            text(t_bl_start, ylims(1) + (ylims(2) - ylims(1)) * 0.05, 'BL', 'HorizontalAlignment', 'center', 'Color', 'b', 'FontWeight', 'bold');
        else
            hBaselineLines = [];
        end
        
        % Отображение peak диапазона (зеленые линии) - отображаются если включен хотя бы один элемент,
        % который вычисляется внутри этих границ (peak, onset, slope)
        show_peak_range = slope_measurement_settings.show_peak || slope_measurement_settings.show_onset || slope_measurement_settings.show_slope;
        
        if show_peak_range
            if mean_results_active && ~isempty(mean_signal_data) && ~isempty(mean_signal_time)
                rel_shift = stims(stim_inx);
                % В режиме среднего сигнала времена уже нормализованы
                t_pk_start = (peak_start - rel_shift) * timeUnitFactor;
                t_pk_end = (peak_end - rel_shift) * timeUnitFactor;
            else
                % В обычном режиме нормализуем относительно rel_shift
                t_pk_start = (peak_start - rel_shift) * timeUnitFactor;
                t_pk_end = (peak_end - rel_shift) * timeUnitFactor;
            end
            hPeakLines(1) = line([t_pk_start, t_pk_start], ylims, 'Color', 'g', 'LineWidth', 2, 'LineStyle', ':');
            hPeakLines(2) = line([t_pk_end, t_pk_end], ylims, 'Color', 'g', 'LineWidth', 2, 'LineStyle', ':');
            
            % Подписи диапазонов
            text(t_pk_start, ylims(1) + (ylims(2) - ylims(1)) * 0.05, 'PK', 'HorizontalAlignment', 'center', 'Color', 'g', 'FontWeight', 'bold');
        else
            hPeakLines = [];
        end
        
        % Настройка осей
        xlabel(['Time, ' selectedUnit]);
        ylabel('Amplitude');
        
        % Заголовок с указанием режима
            if mean_results_active
                title({['File: ' matFileName], 'Mean Signal (Average of All Results)'});
            else
                selected_channel = slope_measurement_settings.channel;
                title({['File: ' matFileName], ['Channel: ' hd.recChNames{selected_channel}]}, 'Interpreter', 'none');
            end
        
        grid on;
        
    % Добавляем возможность перетаскивания для диапазонов
    makeDraggable();
    end
    
    function makeDraggable()
        % Делаем линии диапазонов перетаскиваемыми
        if slope_measurement_settings.show_baseline && ~isempty(hBaselineLines)
            for i = 1:2 % первые две линии - границы baseline
                if ishandle(hBaselineLines(i))
                    set(hBaselineLines(i), 'ButtonDownFcn', @(src,evt)startDrag(src,evt,'baseline',i));
                end
            end
        end
        
        % Перетаскивание peak линий - доступно если включен хотя бы один элемент,
        % который вычисляется внутри этих границ (peak, onset, slope)
        show_peak_range = slope_measurement_settings.show_peak || slope_measurement_settings.show_onset || slope_measurement_settings.show_slope;
        if show_peak_range && ~isempty(hPeakLines)
            for i = 1:2 % первые две линии - границы peak
                if ishandle(hPeakLines(i))
                    set(hPeakLines(i), 'ButtonDownFcn', @(src,evt)startDrag(src,evt,'peak',i));
                end
            end
        end
    end
    
    function startDrag(src, ~, range_type, line_num)
        set(signalFig, 'WindowButtonMotionFcn', @(s,e)dragMarker(s,e,range_type,line_num));
        set(signalFig, 'WindowButtonUpFcn', @stopDrag);
    end
    
    function dragMarker(~, ~, range_type, line_num)
        % Вычисляем rel_shift для нормализации времен
        if strcmp(selectedCenter, 'stimulus') && stims_exist && ~isempty(stims)
            rel_shift = stims(stim_inx);
        else
            rel_shift = chosen_time_interval(1);
        end
        
        pt = get(hPlotAxes, 'CurrentPoint');
        new_time_rel = pt(1,1) / timeUnitFactor; % Конвертируем обратно в секунды (относительное время)
        new_time = rel_shift + new_time_rel; % Преобразуем в абсолютное время
        
        % Ограничиваем время в пределах данных
        time_limits = [chosen_time_interval(1) - time_back, chosen_time_interval(2)];
        new_time = max(time_limits(1), min(time_limits(2), new_time));
        
        if strcmp(range_type, 'baseline')
            if line_num == 1 % начало baseline
                slope_measurement_settings.baseline_start = new_time;
            else % конец baseline
                slope_measurement_settings.baseline_end = new_time;
            end
        elseif strcmp(range_type, 'peak')
            if line_num == 1 % начало peak
                slope_measurement_settings.peak_start = new_time;
            else % конец peak
                slope_measurement_settings.peak_end = new_time;
            end
        end
        
        % Обновляем edit fields после изменения позиций
        updateCursorEditFields();
        
        % Обновляем только позиции линий без пересчета параметров
        updateLinePositions();
    end
    
    function stopDrag(~, ~)
        set(signalFig, 'WindowButtonMotionFcn', '');
        set(signalFig, 'WindowButtonUpFcn', '');
        
        % Сохраняем текущие позиции маркеров в настройки
        saveCurrentMarkerPositions();
        
        % Пересчитываем параметры только после того как пользователь отжал мышь
        updatePlotAndCalculation();
    end
    
    function saveCurrentMarkerPositions()
        % Сохраняет текущие позиции маркеров в главный файл настроек
        % Эта функция вызывается при завершении перетаскивания маркеров
        
        try
            % Путь к главному файлу настроек
            SettingsFilepath = fullfile(tempdir, 'ev_settings.mat');
            
            % Загружаем существующие настройки если файл есть
            if exist(SettingsFilepath, 'file')
                loadedSettings = load(SettingsFilepath, '-mat');
            else
                % Создаем базовую структуру настроек
                loadedSettings = struct();
            end
            
            % Сохраняем относительные позиции курсоров используя глобальную переменную rel_shift
            loadedSettings.cursor_positions = struct();
            loadedSettings.cursor_positions.baseline_start = slope_measurement_settings.baseline_start - rel_shift;
            loadedSettings.cursor_positions.baseline_end = slope_measurement_settings.baseline_end - rel_shift;
            loadedSettings.cursor_positions.peak_start = slope_measurement_settings.peak_start - rel_shift;
            loadedSettings.cursor_positions.peak_end = slope_measurement_settings.peak_end - rel_shift;
            
            
            
            % Сохраняем обновленные настройки
            % Используем -append чтобы не перезаписывать существующие настройки
            if exist(SettingsFilepath, 'file')
                save(SettingsFilepath, '-struct', 'loadedSettings', 'cursor_positions', '-append');
            else
                save(SettingsFilepath, '-struct', 'loadedSettings', 'cursor_positions');
            end
            
    
            
        catch ME
    
        end
    end
    
    function updateLinePositions()
        % Обновляет только позиции линий без пересчета параметров
        % Получаем текущие границы осей
        ylims = ylim(hPlotAxes);
        
        % Получаем параметры для отображения линий
        baseline_start = slope_measurement_settings.baseline_start;
        baseline_end = slope_measurement_settings.baseline_end;
        peak_start = slope_measurement_settings.peak_start;
        peak_end = slope_measurement_settings.peak_end;
        
        % Вычисляем rel_shift для нормализации времен
        if strcmp(selectedCenter, 'stimulus') && stims_exist && ~isempty(stims)
            rel_shift = stims(stim_inx);
        else
            rel_shift = chosen_time_interval(1);
        end
        
        % Обновляем позиции baseline линий
        if slope_measurement_settings.show_baseline && ~isempty(hBaselineLines) && length(hBaselineLines) >= 3
            if mean_results_active && ~isempty(mean_signal_data) && ~isempty(mean_signal_time)
                % В режиме среднего сигнала времена уже нормализованы
                t_bl_start = baseline_start * timeUnitFactor;
                t_bl_end = baseline_end * timeUnitFactor;
            else
                % В обычном режиме нормализуем относительно rel_shift
                t_bl_start = (baseline_start - rel_shift) * timeUnitFactor;
                t_bl_end = (baseline_end - rel_shift) * timeUnitFactor;
            end
            
            % Обновляем позиции линий
            if ishandle(hBaselineLines(1))
                set(hBaselineLines(1), 'XData', [t_bl_start, t_bl_start], 'YData', ylims);
            end
            if ishandle(hBaselineLines(2))
                set(hBaselineLines(2), 'XData', [t_bl_end, t_bl_end], 'YData', ylims);
            end
            % Не обновляем горизонтальную линию baseline во время перетаскивания
            % Она будет обновлена только после завершения перетаскивания в updatePlotAndCalculation()
        end
        
        % Обновляем позиции peak линий - отображаются если включен хотя бы один элемент,
        % который вычисляется внутри этих границ (peak, onset, slope)
        show_peak_range = slope_measurement_settings.show_peak || slope_measurement_settings.show_onset || slope_measurement_settings.show_slope;
        if show_peak_range && ~isempty(hPeakLines) && length(hPeakLines) >= 2
            if mean_results_active && ~isempty(mean_signal_data) && ~isempty(mean_signal_time)
                % В режиме среднего сигнала времена уже нормализованы
                t_pk_start = peak_start * timeUnitFactor;
                t_pk_end = peak_end * timeUnitFactor;
            else
                % В обычном режиме нормализуем относительно rel_shift
                t_pk_start = (peak_start - rel_shift) * timeUnitFactor;
                t_pk_end = (peak_end - rel_shift) * timeUnitFactor;
            end
            
            % Обновляем позиции линий
            if ishandle(hPeakLines(1))
                set(hPeakLines(1), 'XData', [t_pk_start, t_pk_start], 'YData', ylims);
            end
            if ishandle(hPeakLines(2))
                set(hPeakLines(2), 'XData', [t_pk_end, t_pk_end], 'YData', ylims);
            end
        end
        
        % Обновляем edit fields после изменения позиций линий
        updateCursorEditFields();
    end

    function updateNavigationStatus()
        % Обновляет статус навигации на основе текущего режима
        status_text = sprintf('Mode: %s', selectedCenter);
        
        % Добавляем информацию о текущей позиции
        switch selectedCenter
            case 'event'
                if events_exist && ~isempty(events)
                    status_text = sprintf('%s (%d/%d)', status_text, event_inx, length(events));
                end
            case 'stimulus'
                if stims_exist && ~isempty(stims)
                    status_text = sprintf('%s (%d/%d)', status_text, stim_inx, length(stims));
                end
            case 'sweep'
                if isstruct(sweep_info) && sweep_info.is_sweep_data
                    status_text = sprintf('%s (%d/%d)', status_text, sweep_inx, sweep_info.sweep_count);
                end
        end
        
        % Добавляем информацию о зуме
        if zoom_active
            if ~isempty(zoom_y_min) && ~isempty(zoom_y_max)
                status_text = sprintf('%s | Zoom: %.1f%%-%.1f%% | Y: %.2f-%.2f', status_text, ...
                    zoom_start_rel*100, zoom_end_rel*100, zoom_y_min, zoom_y_max);
            else
                status_text = sprintf('%s | Zoom: %.1f%%-%.1f%%', status_text, ...
                    zoom_start_rel*100, zoom_end_rel*100);
            end
        end
        
        set(hNavigationStatus, 'String', status_text);
    end
    
    function shiftTimeSlope(direction)
        % Навигация между временными сегментами (аналогично shiftTime из signalViewerGUI.m)
        
        % Сохраняем относительные позиции текущих диапазонов
        old_interval = chosen_time_interval;
        [baseline_rel, peak_rel] = getRelativePositions();
        
        % Вычисляем размер окна
        windowSize = chosen_time_interval(2) - chosen_time_interval(1);
        
        % Навигация в зависимости от режима
        switch selectedCenter
            case 'event'
                if events_exist && ~isempty(events)
                    if direction == 1  % движение вперед
                        event_inx = min(event_inx + 1, length(events));
                    else  % движение назад
                        event_inx = max(event_inx - 1, 1);
                    end
                    chosen_time_interval(1) = events(event_inx);
                    chosen_time_interval(2) = events(event_inx) + windowSize;
                end
                
            case 'stimulus'
                if stims_exist && ~isempty(stims)
                    if direction == 1  % движение вперед
                        stim_inx = min(stim_inx + 1, length(stims));
                    else  % движение назад
                        stim_inx = max(stim_inx - 1, 1);
                    end
                    chosen_time_interval(1) = stims(stim_inx);
                    chosen_time_interval(2) = stims(stim_inx) + windowSize;
                end
                
            case 'sweep'
                if isstruct(sweep_info) && sweep_info.is_sweep_data
                    if direction == 1  % движение вперед
                        sweep_inx = min(sweep_inx + 1, sweep_info.sweep_count);
                    else  % движение назад
                        sweep_inx = max(sweep_inx - 1, 1);
                    end
                    chosen_time_interval(1) = sweep_info.sweep_times(sweep_inx);
                    chosen_time_interval(2) = chosen_time_interval(1) + windowSize;
                end
                
            case 'time'
                if direction == 1  % движение вперед
                    next_step_1 = chosen_time_interval(2);
                    next_step_2 = chosen_time_interval(2) + windowSize;
                else  % движение назад
                    next_step_1 = chosen_time_interval(1) - windowSize;
                    next_step_2 = next_step_1 + windowSize;
                end
                
                % Проверяем границы времени
                if ~(next_step_1 < 0 || next_step_2 > time(end) + windowSize)
                    chosen_time_interval(1) = next_step_1;
                    chosen_time_interval(2) = next_step_2;
                end
        end
        
        % Применяем сохраненные относительные позиции к новому интервалу
        setRelativePositions(baseline_rel, peak_rel);

        % устанавливаем оптимальные границы осей только если зум не активен
        if ~zoom_active
            [original_xlim, original_ylim] = calculateOptimalAxisLimits(true);
        end

        % Обновляем edit fields после изменения позиций
        updateCursorEditFields();
        
        % Обновляем статус и график
        updateNavigationStatus();
        updatePlotAndCalculation();
    end
    
    function [baseline_rel, peak_rel] = getRelativePositions()
        % Возвращает относительные позиции диапазонов относительно относительного нуля
        % Вычисляем текущий относительный нуль
        if strcmp(selectedCenter, 'stimulus') && stims_exist && ~isempty(stims)
            current_rel_shift = stims(stim_inx);
        else
            current_rel_shift = chosen_time_interval(1);
        end
        
        % Сохраняем позиции относительно относительного нуля
        baseline_rel.start = slope_measurement_settings.baseline_start - current_rel_shift;
        baseline_rel.end = slope_measurement_settings.baseline_end - current_rel_shift;
        peak_rel.start = slope_measurement_settings.peak_start - current_rel_shift;
        peak_rel.end = slope_measurement_settings.peak_end - current_rel_shift;
    end
    
    function setRelativePositions(baseline_rel, peak_rel)
        % Устанавливает позиции диапазонов на основе относительных координат
        % Вычисляем новый относительный нуль
        if strcmp(selectedCenter, 'stimulus') && stims_exist && ~isempty(stims)
            new_rel_shift = stims(stim_inx);
        else
            new_rel_shift = chosen_time_interval(1);
        end
        
        % Восстанавливаем абсолютные позиции
        slope_measurement_settings.baseline_start = new_rel_shift + baseline_rel.start;
        slope_measurement_settings.baseline_end = new_rel_shift + baseline_rel.end;
        slope_measurement_settings.peak_start = new_rel_shift + peak_rel.start;
        slope_measurement_settings.peak_end = new_rel_shift + peak_rel.end;
        
        % Обновляем edit fields с относительным временем
        updateCursorEditFields();
    end
    
    function keyPressFunction(~, event)
        % Обработка нажатий клавиш для навигации
        switch event.Key
            case 'leftarrow'
                shiftTimeSlope(-1);
            case 'rightarrow'
                shiftTimeSlope(1);
        end
    end
    

    
    function toggleZoom(~, ~)
        % Переключение между зумом и сбросом
        zoomBtn = findobj(signalFig, 'Style', 'pushbutton', 'Callback', @toggleZoom);
        currentText = '';
        if ~isempty(zoomBtn)
            currentText = get(zoomBtn, 'String');
        end

        if zoom_active
            % Если зум активен - сбрасываем

            resZoom();
        else
            % Если зум неактивен - начинаем выбор области
            % fprintf('DEBUG: Зум неактивен, вызываем startZoomSelection\n');
            startZoomSelection();
        end
    end
    
    function startZoomSelection()
        % Начинаем выбор области для зума
        axes(hPlotAxes);
        fprintf('Select zoom area: click any two points to define the area\n');
        
        % Собираем две точки для зума (с координатами X и Y)
        [x1, y1] = ginput(1);
        if isempty(x1)
            fprintf('Zoom cancelled\n');
            return;
        end
        
        % Показываем первую точку
        hold(hPlotAxes, 'on');
        current_xlim = xlim(hPlotAxes);
        current_ylim = ylim(hPlotAxes);
        hTempLineV = line([x1, x1], current_ylim, 'Color', 'r', 'LineStyle', '--', 'LineWidth', 2);
        hTempLineH = line(current_xlim, [y1, y1], 'Color', 'r', 'LineStyle', '--', 'LineWidth', 2);
        fprintf('First point selected: (%.3f, %.3f). Select second point\n', x1, y1);
        
        [x2, y2] = ginput(1);
        if isempty(x2)
            delete(hTempLineV);
            delete(hTempLineH);
            fprintf('Zoom cancelled\n');
            return;
        end
        
        % Удаляем временные линии
        delete(hTempLineV);
        delete(hTempLineH);
        
        % Применяем зум - порядок точек не важен
        zoom_x_start = min(x1, x2);
        zoom_x_end = max(x1, x2);
        zoom_y_start = min(y1, y2);
        zoom_y_end = max(y1, y2);
        
        % Проверяем что область имеет ненулевой размер
        if zoom_x_end > zoom_x_start && zoom_y_end > zoom_y_start
            applyZoom(zoom_x_start, zoom_x_end, zoom_y_start, zoom_y_end);
        else
            fprintf('Invalid zoom area: area must have non-zero size\n');
        end
    end
    
    function applyZoom(zoom_start_time, zoom_end_time, zoom_start_y, zoom_end_y)
        % Применяем зум к выбранной области (время + амплитуда)
        
        % fprintf('DEBUG: applyZoom входные данные: время [%.3f, %.3f], амплитуда [%.3f, %.3f]\n', ...
        %    zoom_start_time, zoom_end_time, zoom_start_y, zoom_end_y);
                
        % Сохраняем зум по амплитуде
        zoom_y_min = min(zoom_start_y, zoom_end_y);
        zoom_y_max = max(zoom_start_y, zoom_end_y);
        
        if zoom_y_max > zoom_y_min
            zoom_active = true;
            
            % Сохраняем исходные границы амплитуды и времени при первом зуме
            if isempty(original_ylim)
                original_ylim = ylim(hPlotAxes);
                original_xlim = xlim(hPlotAxes);
            end
            
            % Вычисляем относительные позиции зума на основе текущих границ осей
            current_xlim = xlim(hPlotAxes);
            full_range = current_xlim(2) - current_xlim(1);
            
            % Конвертируем абсолютные времена в относительные (0-1)
            zoom_start_rel = (zoom_start_time - current_xlim(1)) / full_range;
            zoom_end_rel = (zoom_end_time - current_xlim(1)) / full_range;
            
            % Обновляем кнопку зума
            zoomBtn = findobj(signalFig, 'Style', 'pushbutton', 'Callback', @toggleZoom);
            if ~isempty(zoomBtn)
                set(zoomBtn, 'String', 'Reset Zoom');
            end
            
            updateNavigationStatus();
            xlim([zoom_start_time, zoom_end_time]);
            ylim([zoom_y_min, zoom_y_max]);
        end
    end

    function [optimal_xlim, optimal_ylim] = calculateOptimalAxisLimits(should_apply_limits)
        % Вычисляет оптимальные границы осей на основе настроек файла и данных
        % и опционально применяет их к текущим осям
        %
        % Параметры:
        %   should_apply_limits - если true, применяет границы к текущим осям,
        %                        если false, только возвращает значения
        %                        (по умолчанию true)
        
        if nargin < 1
            should_apply_limits = true;
        end
        
        % Границы по X - просто time_back и time_forward
        x_start = -time_back * timeUnitFactor;
        x_end = time_forward * timeUnitFactor;
        optimal_xlim = [x_start, x_end];
        
        % Границы по Y - оптимальные на основе данных
        if mean_results_active && ~isempty(mean_signal_data)
            % В режиме среднего сигнала используем его данные
            y_data = mean_signal_data;
            x_data = mean_signal_time;
        else
            % В обычном режиме получаем данные текущего интервала
            plot_time_interval = chosen_time_interval;
            plot_time_interval(1) = plot_time_interval(1) - time_back;
            plot_time_interval(2) = chosen_time_interval(1) + time_forward;
            
            cond = time >= plot_time_interval(1) & time < plot_time_interval(2);
            selected_channel = slope_measurement_settings.channel;
            y_data = lfp(cond, selected_channel);
            x_data = time(cond)-rel_shift;
        end
        
        % Вычисляем оптимальные границы амплитуды
        % Удаляем артефакты для всех каналов
        Fs_fascor = Fs/1000;
        y_data = removeStimArtifact(y_data, 0, x_data, art_rem_window_ms*Fs_fascor*0.5);
        y_min = min(y_data);
        y_max = max(y_data);
        y_range = y_max - y_min;
        
        if y_range == 0
            y_range = abs(y_min) * 0.1;
        end
        
        y_padding = y_range * 0.05; % 5% запас
        optimal_ylim = [y_min - y_padding, y_max + y_padding];
        
        % Применяем границы к текущим осям если нужно
        if should_apply_limits
            axes(hPlotAxes);
            xlim(optimal_xlim);
            ylim(optimal_ylim);
        end
    end

    function resZoom()
        % Сбрасываем зум
        % fprintf('DEBUG: resZoom вызвана\n');
        zoom_active = false;
        zoom_start_rel = 0;
        zoom_end_rel = 1;
        zoom_y_min = [];
        zoom_y_max = [];
        
        % Применяем original_ylim и original_xlim 
        ylim(original_ylim);
        xlim(original_xlim);
        
        % Находим кнопку зума в фигуре
        zoomBtn = findobj(signalFig, 'Style', 'pushbutton', 'Callback', @toggleZoom);
        if ~isempty(zoomBtn)
            set(zoomBtn, 'String', 'Zoom');
            % fprintf('DEBUG: Кнопка сброшена на: %s, zoom_active = %d\n', get(zoomBtn, 'String'), zoom_active);
        else
            fprintf('ERROR: Zoom button not found in resZoom!\n');
        end
        
        fprintf('✓ Zoom reset (new optimal boundaries will be calculated)\n');
        updateNavigationStatus();
        updatePlotAndCalculation();
    end
    
    function mouseWheelZoom(~, eventdata)
        if ~zoom_active
            return;
        end
        
        % Получаем текущие границы осей
        current_xlim = xlim(hPlotAxes);
        current_range = current_xlim(2) - current_xlim(1);
        
        % Коэффициент зума
        zoom_factor = 0.1;
        
        if eventdata.VerticalScrollCount > 0
            new_range = current_range * (1 + zoom_factor);
        else
            new_range = current_range * (1 - zoom_factor);
        end
        
        % Проверяем минимальный размер зума
        if new_range >= (original_xlim(2) - original_xlim(1))
            resZoom();
            return;
        end
        
        % Зум от центра текущей области
        center = (current_xlim(1) + current_xlim(2)) / 2;
        new_start = center - new_range / 2;
        new_end = center + new_range / 2;
        
        % Применяем новые границы осей
        xlim([new_start, new_end]);
        
        % Обновляем относительные позиции зума
        full_range = original_xlim(2) - original_xlim(1);
        zoom_start_rel = (new_start - original_xlim(1)) / full_range;
        zoom_end_rel = (new_end - original_xlim(1)) / full_range;
        
        % Обновляем статус навигации
        updateNavigationStatus();
        
        % Обновляем только позиции линий без пересчета параметров
        updateLinePositions();
        updateMeasurementCursorPositions();
    end
    
    % === Функции для работы с таблицей результатов ===
    
    function addResult(~, ~)
        % Добавляет текущий результат в таблицу
        % Используем уже вычисленные значения вместо повторного вычисления
        

        
        % Используем глобальные метаданные если они есть, иначе создаем новые
        if ~isempty(current_measurement_metadata)
            % Используем существующие метаданные с rel_shift
            metadata = current_measurement_metadata;
        else
            % Создаем новые метаданные
            metadata = struct();
        end
        
        % Добавляем недостающие поля в метаданные
        metadata.channel = slope_measurement_settings.channel;
        metadata.baseline_start = slope_measurement_settings.baseline_start;
        metadata.baseline_end = slope_measurement_settings.baseline_end;
        metadata.peak_start = slope_measurement_settings.peak_start;
        metadata.peak_end = slope_measurement_settings.peak_end;
        metadata.slope_percent = slope_measurement_settings.slope_percent;
        metadata.peak_polarity = slope_measurement_settings.peak_polarity;
        metadata.chosen_time_interval = chosen_time_interval;
        metadata.zoom_active = zoom_active;
        metadata.zoom_start_rel = zoom_start_rel;
        metadata.zoom_end_rel = zoom_end_rel;
        metadata.zoom_y_min = zoom_y_min;
        metadata.zoom_y_max = zoom_y_max;
        
        % вычисляем границы осей
        [original_xlim, original_ylim] = calculateOptimalAxisLimits(false);
        metadata.original_xlim = original_xlim;
        metadata.original_ylim = original_ylim;
        
        metadata.selectedCenter = selectedCenter;
        metadata.event_inx = event_inx;
        metadata.stim_inx = stim_inx;
        metadata.sweep_inx = sweep_inx;
        metadata.onset_method = slope_measurement_settings.onset_method;
        metadata.onset_threshold = slope_measurement_settings.onset_threshold;
        metadata.show_baseline = slope_measurement_settings.show_baseline;
        metadata.show_onset = slope_measurement_settings.show_onset;
        metadata.show_slope = slope_measurement_settings.show_slope;
        metadata.show_peak = slope_measurement_settings.show_peak;
        
        % Добавляем rel_shift только если его нет в переданных метаданных
        if ~isfield(metadata, 'rel_shift')
            if strcmp(selectedCenter, 'stimulus') && stims_exist && ~isempty(stims)
                metadata.rel_shift = stims(stim_inx);
            else
                metadata.rel_shift = chosen_time_interval(1);
            end
        end
        
        % Добавляем позиции курсоров в метаданные
        metadata.cursor_positions = struct();
        metadata.cursor_positions.baseline_start = slope_measurement_settings.baseline_start;
        metadata.cursor_positions.baseline_end = slope_measurement_settings.baseline_end;
        metadata.cursor_positions.peak_start = slope_measurement_settings.peak_start;
        metadata.cursor_positions.peak_end = slope_measurement_settings.peak_end;
        
        % Добавляем результат в структуру
        new_result = struct('baseline_value', baseline_value, 'slope_value', slope_value, ...
                           'peak_time', peak_time, 'peak_value', peak_value, ...
                           'onset_time', onset_time, 'onset_value', onset_value, 'onset_method', onset_method, ...
                           'metadata', metadata);

        % Добавляем время стимула в метаданные если оно есть
        if strcmp(selectedCenter, 'stimulus') && stims_exist && ~isempty(stims)
            new_result.metadata.stim_time = stims(stim_inx);
        else
            new_result.metadata.stim_time = NaN;
        end

        slope_measurement_results = [slope_measurement_results, new_result];
        
        % Обновляем таблицу
        updateResultsTable();
        
        fprintf('✓ Result added to table (total: %d)\n', length(slope_measurement_results));
    end
    
    function addResultSilent()
        % Добавляет результат БЕЗ обновления UI (для автоанализа)
        
        % Используем глобальные метаданные если они есть, иначе создаем новые
        if ~isempty(current_measurement_metadata)
            % Используем существующие метаданные с rel_shift
            metadata = current_measurement_metadata;
        else
            % Создаем новые метаданные
            metadata = struct();
        end
        
        % Добавляем недостающие поля в метаданные
        metadata.channel = slope_measurement_settings.channel;
        metadata.baseline_start = slope_measurement_settings.baseline_start;
        metadata.baseline_end = slope_measurement_settings.baseline_end;
        metadata.peak_start = slope_measurement_settings.peak_start;
        metadata.peak_end = slope_measurement_settings.peak_end;
        metadata.slope_percent = slope_measurement_settings.slope_percent;
        metadata.peak_polarity = slope_measurement_settings.peak_polarity;
        metadata.chosen_time_interval = chosen_time_interval;
        metadata.zoom_active = zoom_active;
        metadata.zoom_start_rel = zoom_start_rel;
        metadata.zoom_end_rel = zoom_end_rel;
        metadata.zoom_y_min = zoom_y_min;
        metadata.zoom_y_max = zoom_y_max;

        % вычисляем границы осей
        [original_xlim, original_ylim] = calculateOptimalAxisLimits(false);
        metadata.original_xlim = original_xlim;
        metadata.original_ylim = original_ylim;

        metadata.selectedCenter = selectedCenter;
        metadata.event_inx = event_inx;
        metadata.stim_inx = stim_inx;
        metadata.sweep_inx = sweep_inx;
        metadata.onset_method = slope_measurement_settings.onset_method;
        metadata.onset_threshold = slope_measurement_settings.onset_threshold;
        metadata.show_baseline = slope_measurement_settings.show_baseline;
        metadata.show_onset = slope_measurement_settings.show_onset;
        metadata.show_slope = slope_measurement_settings.show_slope;
        metadata.show_peak = slope_measurement_settings.show_peak;
        
        % Добавляем rel_shift только если его нет в переданных метаданных
        if ~isfield(metadata, 'rel_shift')
            if strcmp(selectedCenter, 'stimulus') && stims_exist && ~isempty(stims)
                metadata.rel_shift = stims(stim_inx);
            else
                metadata.rel_shift = chosen_time_interval(1);
            end
        end
        
        % Добавляем позиции курсоров в метаданные
        metadata.cursor_positions = struct();
        metadata.cursor_positions.baseline_start = slope_measurement_settings.baseline_start;
        metadata.cursor_positions.baseline_end = slope_measurement_settings.baseline_end;
        metadata.cursor_positions.peak_start = slope_measurement_settings.peak_start;
        metadata.cursor_positions.peak_end = slope_measurement_settings.peak_end;
        
        % Добавляем результат в структуру
        new_result = struct('baseline_value', baseline_value, 'slope_value', slope_value, ...
                           'peak_time', peak_time, 'peak_value', peak_value, ...
                           'onset_time', onset_time, 'onset_value', onset_value, 'onset_method', onset_method, ...
                           'metadata', metadata);

        % Добавляем время стимула в метаданные если оно есть
        if strcmp(selectedCenter, 'stimulus') && stims_exist && ~isempty(stims)
            new_result.metadata.stim_time = stims(stim_inx);
        else
            new_result.metadata.stim_time = NaN;
        end

        slope_measurement_results = [slope_measurement_results, new_result];
        
        % НЕ обновляем таблицы и график - только добавляем в память
        % updateResultsTable(); - ЗАКОММЕНТИРОВАНО
        % updatePlotAndCalculation(); - ЗАКОММЕНТИРОВАНО
    end
    
    function removeResult(~, ~)
        % Удаляет выделенный результат из таблицы
        
        % Получаем выделенную строку из таблицы
        if ~isempty(selected_row_slope) && selected_row_slope <= length(slope_measurement_results)
            % Удаляем результат
            slope_measurement_results(selected_row_slope) = [];
            
            % Сохраняем позицию прокрутки перед обновлением таблицы
            global saved_vpos saved_hpos;
            try
                jTable = findjobj(hResultsTable);
                % UIScrollPane уже содержит методы прокрутки
                saved_vpos = jTable.getVerticalScrollBar.getValue();
                saved_hpos = jTable.getHorizontalScrollBar.getValue();
                fprintf('DEBUG: Сохранены позиции - vpos: %d, hpos: %d\n', saved_vpos, saved_hpos);
            catch
                saved_vpos = [];
                saved_hpos = [];
            end
            
            % Отключаем видимость таблицы для плавного обновления
            set(hResultsTable, 'Visible', 'off');
            
            % Показываем текст "Wait..." в центре таблицы
            waitText = uicontrol(signalFig, 'Style', 'text', ...
                'Position', [1135, 300, 460, 20], ...
                'String', 'Wait...', ...
                'FontSize', 16, ...
                'FontWeight', 'bold', ...
                'BackgroundColor', get(signalFig, 'Color'), ...
                'ForegroundColor', [0.5, 0.5, 0.5], ...
                'HorizontalAlignment', 'center');
            
            % Обновляем таблицу
            updateResultsTable();
        
        fprintf('✓ Result #%d removed from table\n', selected_row_slope);
        
        % Оставляем selected_row_slope без изменений для сохранения выделения
            
        else
            % Fallback: если нет выделенной строки, удаляем последний результат
            if ~isempty(slope_measurement_results)
                last_index = length(slope_measurement_results);
                slope_measurement_results(last_index) = [];
                
                % Обновляем таблицу
                updateResultsTable();
                
                fprintf('✓ Last result #%d removed from table\n', last_index);
            else
                fprintf('❌ No results to delete\n');
            end
        end
        
        % Сбрасываем средний сигнал при удалении результатов
        if mean_results_active
            mean_results_active = false;
            mean_signal_data = [];
            mean_signal_time = [];
            set(hMeanResultsBtn, 'String', 'Av. Trace');
            updateButtonStates();
            updatePlotAndCalculation();
        end
        
        % Обновляем состояние кнопки Replace
        updateReplaceButtonState();
    end
    
    function replaceResult(~, ~)
        % Заменяет выбранный результат текущим измерением
        
        if isempty(selected_row_slope) || selected_row_slope > length(slope_measurement_results)
            fprintf('❌ No selected result to replace\n');
            return;
        end
        
        % Проверяем, что у нас есть текущие результаты
        if ~exist('slope_value', 'var') || isnan(slope_value)
            fprintf('❌ No current results to replace\n');
            return;
        end
        
        % Используем глобальные метаданные если они есть, иначе создаем новые
        if ~isempty(current_measurement_metadata)
            % Используем существующие метаданные с rel_shift
            metadata = current_measurement_metadata;
        else
            % Создаем новые метаданные
            metadata = struct();
        end
        
        % Добавляем недостающие поля в метаданные
        metadata.channel = slope_measurement_settings.channel;
        metadata.baseline_start = slope_measurement_settings.baseline_start;
        metadata.baseline_end = slope_measurement_settings.baseline_end;
        metadata.peak_start = slope_measurement_settings.peak_start;
        metadata.peak_end = slope_measurement_settings.peak_end;
        metadata.slope_percent = slope_measurement_settings.slope_percent;
        metadata.peak_polarity = slope_measurement_settings.peak_polarity;
        metadata.chosen_time_interval = chosen_time_interval;
        metadata.zoom_active = zoom_active;
        metadata.zoom_start_rel = zoom_start_rel;
        metadata.zoom_end_rel = zoom_end_rel;
        metadata.zoom_y_min = zoom_y_min;
        metadata.zoom_y_max = zoom_y_max;
        
        % вычисляем границы осей
        [original_xlim, original_ylim] = calculateOptimalAxisLimits(false);
        metadata.original_xlim = original_xlim;
        metadata.original_ylim = original_ylim;
        
        metadata.selectedCenter = selectedCenter;
        metadata.event_inx = event_inx;
        metadata.stim_inx = stim_inx;
        metadata.sweep_inx = sweep_inx;
        metadata.onset_method = slope_measurement_settings.onset_method;
        metadata.onset_threshold = slope_measurement_settings.onset_threshold;
        metadata.show_baseline = slope_measurement_settings.show_baseline;
        metadata.show_onset = slope_measurement_settings.show_onset;
        metadata.show_slope = slope_measurement_settings.show_slope;
        metadata.show_peak = slope_measurement_settings.show_peak;
        
        % Добавляем rel_shift только если его нет в переданных метаданных
        if ~isfield(metadata, 'rel_shift')
            if strcmp(selectedCenter, 'stimulus') && stims_exist && ~isempty(stims)
                metadata.rel_shift = stims(stim_inx);
            else
                metadata.rel_shift = chosen_time_interval(1);
            end
        end
        
        % Добавляем позиции курсоров в метаданные
        metadata.cursor_positions = struct();
        metadata.cursor_positions.baseline_start = slope_measurement_settings.baseline_start;
        metadata.cursor_positions.baseline_end = slope_measurement_settings.baseline_end;
        metadata.cursor_positions.peak_start = slope_measurement_settings.peak_start;
        metadata.cursor_positions.peak_end = slope_measurement_settings.peak_end;
        
        % Создаем новый результат
        new_result = struct('baseline_value', baseline_value, 'slope_value', slope_value, ...
                           'peak_time', peak_time, 'peak_value', peak_value, ...
                           'onset_time', onset_time, 'onset_value', onset_value, 'onset_method', onset_method, ...
                           'metadata', metadata);

        % Добавляем время стимула в метаданные если оно есть
        if strcmp(selectedCenter, 'stimulus') && stims_exist && ~isempty(stims)
            new_result.metadata.stim_time = stims(stim_inx);
        else
            new_result.metadata.stim_time = NaN;
        end

        % Заменяем выбранный результат
        slope_measurement_results(selected_row_slope) = new_result;
        
        % Сохраняем позицию прокрутки перед обновлением таблицы
        global saved_vpos saved_hpos;
        try
            jTable = findjobj(hResultsTable);
            % UIScrollPane уже содержит методы прокрутки
            saved_vpos = jTable.getVerticalScrollBar.getValue();
            saved_hpos = jTable.getHorizontalScrollBar.getValue();
            fprintf('DEBUG: Сохранены позиции - vpos: %d, hpos: %d\n', saved_vpos, saved_hpos);
        catch
            saved_vpos = [];
            saved_hpos = [];
        end
        
        % Отключаем видимость таблицы для плавного обновления
        set(hResultsTable, 'Visible', 'off');
        
        % Показываем текст "Wait..." в центре таблицы
        waitText = uicontrol(signalFig, 'Style', 'text', ...
            'Position', [1135, 300, 460, 20], ...
            'String', 'Wait...', ...
            'FontSize', 16, ...
            'FontWeight', 'bold', ...
            'BackgroundColor', get(signalFig, 'Color'), ...
            'ForegroundColor', [0.5, 0.5, 0.5], ...
            'HorizontalAlignment', 'center');
        
        % Обновляем таблицу
        updateResultsTable();
        
        fprintf('✓ Result #%d replaced with current measurement\n', selected_row_slope);
        
        % Оставляем selected_row_slope без изменений для сохранения выделения
        
        updateReplaceButtonState();
    end
    
    function updateReplaceButtonState()
        % Обновляет состояние кнопки Replace в зависимости от выбора строки
        
        if exist('hReplaceBtn', 'var') && ishandle(hReplaceBtn)
            if ~isempty(selected_row_slope) && selected_row_slope <= length(slope_measurement_results)
                % Есть выбранная строка - активируем кнопку
                set(hReplaceBtn, 'Enable', 'on');
            else
                % Нет выбранной строки - деактивируем кнопку
                set(hReplaceBtn, 'Enable', 'off');
            end
        end
    end
    
    function saveResults(~, ~)
        % Сохраняет результаты в Excel файл и метаданные в .meta файл
        
        if isempty(slope_measurement_results)
            fprintf('❌ No results to save\n');
            return;
        end

        % Создаем имя файла по умолчанию на основе исходного файла
        if ~isempty(matFilePath) && ~isempty(matFileName)
            [path, name, ~] = fileparts(matFilePath);
            defaultFileName = fullfile(path, [name, '_slope_measurements.xlsx']);
        else
            defaultFileName = 'slope_measurements.xlsx';
        end
        
        % Запрашиваем имя Excel файла для сохранения
        [filename, pathname] = uiputfile({'*.xlsx', 'Excel Files (*.xlsx)'; ...
                                        '*.xls', 'Excel Files (*.xls)'}, ...
                                       'Save Excel Results As', defaultFileName);
        
        if isequal(filename, 0) || isequal(pathname, 0)
            fprintf('❌ Save cancelled\n');
            return;
        end
        
        % Получаем базовое имя файла без расширения
        [~, basename, ~] = fileparts(filename);
        excel_path = fullfile(pathname, filename);
        meta_path = fullfile(pathname, [basename, '.meta']);
        
        try
            % Подготавливаем данные для Excel
            excel_data = cell(length(slope_measurement_results) + 1, 13);
            
            % Используем те же названия колонок что и в таблице
            excel_data(1, :) = table_column_names;
            
            % Данные
            for i = 1:length(slope_measurement_results)
                metadata = slope_measurement_results(i).metadata;
                
                % Относительное время пика
                peak_time_rel = slope_measurement_results(i).peak_time * timeUnitFactor;
                
                % Абсолютное время пика
                peak_time_abs = (slope_measurement_results(i).peak_time + metadata.rel_shift) * timeUnitFactor;
                
                % Относительное время онсета
                onset_time_rel = slope_measurement_results(i).onset_time * timeUnitFactor;
                
                % Абсолютное время онсета
                onset_time_abs = (slope_measurement_results(i).onset_time + metadata.rel_shift) * timeUnitFactor;
                
                % Номер стимула
                stimulus_number = metadata.stim_inx;
                
                % Разность времени пика и онсета
                peak_onset_diff = (slope_measurement_results(i).peak_time - slope_measurement_results(i).onset_time) * timeUnitFactor;
                
                excel_data{i+1, 1} = stimulus_number;
                excel_data{i+1, 2} = slope_measurement_results(i).slope_value;
                excel_data{i+1, 3} = peak_time_rel;
                excel_data{i+1, 4} = peak_time_abs;
                excel_data{i+1, 5} = slope_measurement_results(i).peak_value;
                excel_data{i+1, 6} = slope_measurement_results(i).peak_value - slope_measurement_results(i).baseline_value; % Peak Value (rel)
                excel_data{i+1, 7} = onset_time_rel;
                excel_data{i+1, 8} = onset_time_abs;
                excel_data{i+1, 9} = peak_onset_diff;
                excel_data{i+1, 10} = slope_measurement_results(i).baseline_value;
                excel_data{i+1, 11} = metadata.channel;
                excel_data{i+1, 12} = metadata.stim_time; % Stim Time
                excel_data{i+1, 13} = getNavigationStatusText(metadata);
            end
            
            % Добавляем пустую строку после основных данных
            excel_data{end+1, 1} = '';
            
            % Добавляем заголовок для средних значений
            excel_data{end+1, 1} = 'Average Values';
            
            % Добавляем названия колонок для средних значений
            excel_data{end+1, 2} = 'Slope';
            excel_data{end, 3} = 'Peak Time (rel)';
            excel_data{end, 5} = 'Peak Amplitude';
            excel_data{end, 6} = 'Peak Value (rel)';
            excel_data{end, 7} = 'Onset Time (rel)';
            excel_data{end, 8} = 'Onset Time (abs)';
            excel_data{end, 9} = 'Peak - Onset';
            excel_data{end, 10} = 'Baseline';
            
            % Вычисляем средние значения
            slope_values = [slope_measurement_results.slope_value];
            peak_time_rel_values = [slope_measurement_results.peak_time] * timeUnitFactor;
            peak_amplitude_values = [slope_measurement_results.peak_value];
            peak_value_rel_values = peak_amplitude_values - [slope_measurement_results.baseline_value];
            onset_time_rel_values = [slope_measurement_results.onset_time] * timeUnitFactor;
            baseline_values = [slope_measurement_results.baseline_value];
            peak_onset_diff_values = ([slope_measurement_results.peak_time] - [slope_measurement_results.onset_time]) * timeUnitFactor;
            
            % Добавляем средние значения
            excel_data{end+1, 2} = mean(slope_values, 'omitnan');
            excel_data{end, 3} = mean(peak_time_rel_values, 'omitnan');
            excel_data{end, 5} = mean(peak_amplitude_values, 'omitnan');
            excel_data{end, 6} = mean(peak_value_rel_values, 'omitnan');
            excel_data{end, 7} = mean(onset_time_rel_values, 'omitnan');
            excel_data{end, 9} = mean(peak_onset_diff_values, 'omitnan');
            excel_data{end, 10} = mean(baseline_values, 'omitnan');
            
            % Добавляем стандартные отклонения
            excel_data{end+1, 1} = 'Standard Deviation';
            excel_data{end+1, 2} = std(slope_values, 'omitnan');
            excel_data{end, 3} = std(peak_time_rel_values, 'omitnan');
            excel_data{end, 5} = std(peak_amplitude_values, 'omitnan');
            excel_data{end, 6} = std(peak_value_rel_values, 'omitnan');
            excel_data{end, 7} = std(onset_time_rel_values, 'omitnan');
            excel_data{end, 9} = std(peak_onset_diff_values, 'omitnan');
            excel_data{end, 10} = std(baseline_values, 'omitnan');
            
            % Сохраняем Excel файл
            writecell(excel_data, excel_path);
            
            % Создаем структуру с средними значениями для сохранения в .meta файл
            average_values = struct();
            average_values.slope = mean(slope_values, 'omitnan');
            average_values.peak_time_rel = mean(peak_time_rel_values, 'omitnan');
            average_values.peak_amplitude = mean(peak_amplitude_values, 'omitnan');
            average_values.peak_value_rel = mean(peak_value_rel_values, 'omitnan');
            average_values.onset_time_rel = mean(onset_time_rel_values, 'omitnan');
            average_values.baseline = mean(baseline_values, 'omitnan');
            
            % Добавляем стандартные отклонения
            average_values.std_slope = std(slope_values, 'omitnan');
            average_values.std_peak_time_rel = std(peak_time_rel_values, 'omitnan');
            average_values.std_peak_amplitude = std(peak_amplitude_values, 'omitnan');
            average_values.std_peak_value_rel = std(peak_value_rel_values, 'omitnan');
            average_values.std_onset_time_rel = std(onset_time_rel_values, 'omitnan');
            average_values.std_baseline = std(baseline_values, 'omitnan');
            
            % Сохраняем информацию об оригинальном файле
            original_file_info = struct();
            original_file_info.matFilePath = matFilePath;
            original_file_info.matFileName = matFileName;
            original_file_info.timestamp = datestr(now);
            
            % Сохраняем метаданные в .meta файл (фактически .mat формат)
            save(meta_path, 'slope_measurement_results', 'average_values', 'original_file_info', '-v7.3');
            
            fprintf('✓ Results saved:\n');
            fprintf('  Excel: %s\n', excel_path);
            fprintf('  Metadata: %s\n', meta_path);
            fprintf('  Total records: %d\n', length(slope_measurement_results));
            
        catch ME
            fprintf('❌ Error saving: %s\n', ME.message);
        end
    end
    
    function updateResultsTable()
        % Обновляет отображение таблицы результатов
        
        % Пропускаем обновление в режиме автоанализа
        if exist('auto_analysis_mode', 'var') && auto_analysis_mode
            return;
        end
        
        
        if isempty(slope_measurement_results)
            set(hResultsTable, 'Data', {});
            % Деактивируем кнопку Mean Results
            set(hMeanResultsBtn, 'Enable', 'off');
            return;
        end
        
        % Подготавливаем данные для таблицы
        table_data = cell(length(slope_measurement_results), 13);
        for i = 1:length(slope_measurement_results)
            metadata = slope_measurement_results(i).metadata;
            
            % Относительное время пика
            peak_time_rel = slope_measurement_results(i).peak_time * timeUnitFactor;
            
            % Абсолютное время пика
            peak_time_abs = (slope_measurement_results(i).peak_time + metadata.rel_shift) * timeUnitFactor;
            
            % Относительное время онсета
            onset_time_rel = slope_measurement_results(i).onset_time * timeUnitFactor;
            
            % Абсолютное время онсета
            onset_time_abs = (slope_measurement_results(i).onset_time + metadata.rel_shift) * timeUnitFactor;
            
            % Относительное значение пика (относительно базовой линии)
            peak_value_rel = slope_measurement_results(i).peak_value - slope_measurement_results(i).baseline_value;
            
            % Номер стимула
            if isfield(metadata, 'stim_inx')
                stimulus_number = metadata.stim_inx;
            else
                stimulus_number = NaN;
            end
            
            % Разность времени пика и онсета
            peak_onset_diff = (slope_measurement_results(i).peak_time - slope_measurement_results(i).onset_time) * timeUnitFactor;
            
            table_data{i, 1} = stimulus_number;
            table_data{i, 2} = slope_measurement_results(i).slope_value;
            table_data{i, 3} = peak_time_rel;
            table_data{i, 4} = peak_time_abs;
            table_data{i, 5} = slope_measurement_results(i).peak_value;
            table_data{i, 6} = peak_value_rel;
            table_data{i, 7} = onset_time_rel;
            table_data{i, 8} = onset_time_abs;
            table_data{i, 9} = peak_onset_diff;
            table_data{i, 10} = slope_measurement_results(i).baseline_value;
            table_data{i, 11} = metadata.channel;
            table_data{i, 12} = metadata.stim_time;
            table_data{i, 13} = getNavigationStatusText(metadata);
        end
        
        set(hResultsTable, 'Data', table_data);
        
        % Активируем кнопку Mean Results если есть результаты
        set(hMeanResultsBtn, 'Enable', 'on');
        
        % Обновляем состояние кнопки Replace
        updateReplaceButtonState();
        
        % Обновляем таблицу средних значений
        updateAverageTable();
        
        % Восстанавливаем позицию прокрутки через Java
        global saved_vpos saved_hpos;
        try
            % Получаем Java-объект таблицы через findjobj
            jTable = findjobj(hResultsTable);
            fprintf('DEBUG: jTable тип: %s\n', class(jTable));
            
            % Проверяем доступные методы UIScrollPane
            fprintf('DEBUG: Проверяем методы UIScrollPane\n');
            
            % Восстанавливаем позицию прокрутки через viewport
            if exist('saved_vpos', 'var') && ~isempty(saved_vpos)
                fprintf('DEBUG: Восстанавливаем vpos: %d\n', saved_vpos);
                
                try
                    viewport = jTable.getViewport();
                    viewport.setViewPosition(java.awt.Point(0, saved_vpos));
                    % fprintf('DEBUG: ✓ Способ 2 (viewport) применен\n');
                catch ME
                    fprintf('DEBUG: ✗ Способ 2 не сработал: %s\n', ME.message);
                end
                
                % Удаляем текст "Wait..." и включаем видимость таблицы
                waitTextHandles = findobj(signalFig, 'Style', 'text', 'String', 'Wait...');
                if ~isempty(waitTextHandles)
                    delete(waitTextHandles);
                end
                set(hResultsTable, 'Visible', 'on');
                
                % Принудительно обновляем интерфейс несколькими способами
                drawnow;
                jTable.repaint();
                jTable.getParent().repaint();
                drawnow;
            end
        catch ME
            % Выводим ошибки Java для отладки
            fprintf('DEBUG: Ошибка при восстановлении позиции: %s\n', ME.message);
        end
        
    end
    
    function updateAverageTable()
        % Обновляет таблицу средних значений
        


        
        if isempty(slope_measurement_results)
            % Если нет результатов, показываем NaN

            set(hAverageTable, 'Data', {NaN, NaN, NaN, NaN, NaN, NaN});
            return;
        end
        
        % Вычисляем средние значения для указанных параметров
        slope_values = [slope_measurement_results.slope_value];
        peak_time_rel_values = [slope_measurement_results.peak_time] * timeUnitFactor;
        peak_amplitude_values = [slope_measurement_results.peak_value];
        onset_time_rel_values = [slope_measurement_results.onset_time] * timeUnitFactor;
        baseline_values = [slope_measurement_results.baseline_value];
        




        % Вычисляем средние значения
        avg_slope = mean(slope_values, 'omitnan');
        avg_peak_time_rel = mean(peak_time_rel_values, 'omitnan');
        avg_peak_amplitude = mean(peak_amplitude_values, 'omitnan');
        avg_onset_time_rel = mean(onset_time_rel_values, 'omitnan');
        avg_baseline = mean(baseline_values, 'omitnan');
        

        
        % Обновляем таблицу средних значений

        disp(hAverageTable);
        
        % Вычисляем разность времени пика и онсета для всех результатов
        peak_onset_diff_values = ([slope_measurement_results.peak_time] - [slope_measurement_results.onset_time]) * timeUnitFactor;
        avg_peak_onset_diff = mean(peak_onset_diff_values, 'omitnan');
        
        try
            set(hAverageTable, 'Data', {avg_slope, avg_peak_time_rel, avg_peak_amplitude, avg_onset_time_rel, avg_baseline, avg_peak_onset_diff});
        catch ME
            fprintf('Error updating table: %s\n', ME.message);
        end
    end
    
    function tableSelectionChanged(~, event)
        % Обработчик изменения выделения в таблице
        
        if isempty(event.Indices)
            selected_row_slope = [];
            updateReplaceButtonState();
            return;
        end
        
        selected_row_slope = event.Indices(1);
        if selected_row_slope <= length(slope_measurement_results)
            % Автоматически выходим из режима среднего сигнала
            if mean_results_active
                mean_results_active = false;
                mean_signal_data = [];
                mean_signal_time = [];
                set(hMeanResultsBtn, 'String', 'Av. Trace');
                updateButtonStates();
            end
            
            % Восстанавливаем состояние из метаданных
            restoreStateFromMetadata(selected_row_slope);
            
            % Обновляем состояние кнопки Replace
            updateReplaceButtonState();
        end
    end
    

    
    function restoreStateFromMetadata(row_index)
        % Восстанавливает состояние из метаданных выбранной строки
        
        if row_index > length(slope_measurement_results)
            return;
        end
        
        % Устанавливаем флаг восстановления
        restoring_from_metadata = true;
        
        metadata = slope_measurement_results(row_index).metadata;
        
        % Восстанавливаем настройки slope measurement
        slope_measurement_settings.channel = metadata.channel;
        slope_measurement_settings.baseline_start = metadata.baseline_start;
        slope_measurement_settings.baseline_end = metadata.baseline_end;
        slope_measurement_settings.peak_start = metadata.peak_start;
        slope_measurement_settings.peak_end = metadata.peak_end;
        slope_measurement_settings.slope_percent = metadata.slope_percent;
        slope_measurement_settings.peak_polarity = metadata.peak_polarity;
        
        % Восстанавливаем настройки видимости если они есть
        if isfield(metadata, 'show_baseline')
            slope_measurement_settings.show_baseline = metadata.show_baseline;
        end
        if isfield(metadata, 'show_onset')
            slope_measurement_settings.show_onset = metadata.show_onset;
        end
        if isfield(metadata, 'show_slope')
            slope_measurement_settings.show_slope = metadata.show_slope;
        end
        if isfield(metadata, 'show_peak')
            slope_measurement_settings.show_peak = metadata.show_peak;
        end
        
        % Восстанавливаем позиции курсоров если они есть
        if isfield(metadata, 'cursor_positions')
            slope_measurement_settings.baseline_start = metadata.cursor_positions.baseline_start;
            slope_measurement_settings.baseline_end = metadata.cursor_positions.baseline_end;
            slope_measurement_settings.peak_start = metadata.cursor_positions.peak_start;
            slope_measurement_settings.peak_end = metadata.cursor_positions.peak_end;
        end
        
        % Восстанавливаем временной интервал
        chosen_time_interval = metadata.chosen_time_interval;
        
        % Восстанавливаем зум (закомментировано для возможного использования в будущем)
        % zoom_active = metadata.zoom_active;
        % zoom_start_rel = metadata.zoom_start_rel;
        % zoom_end_rel = metadata.zoom_end_rel;
        % zoom_y_min = metadata.zoom_y_min;
        % zoom_y_max = metadata.zoom_y_max;
        % original_ylim = metadata.original_ylim;
        % original_xlim = metadata.original_xlim;
        
        % Вместо восстановления зума применяем оптимальные размеры осей
        [optimal_xlim, optimal_ylim] = calculateOptimalAxisLimits(true);
        
        % Сохраняем оптимальные границы как original для возможного использования
        original_xlim = optimal_xlim;
        original_ylim = optimal_ylim;
        
        fprintf('DEBUG: Применены оптимальные границы ylim: %s, xlim: %s\n', mat2str(optimal_ylim), mat2str(optimal_xlim));
        
        % Восстанавливаем режим навигации
        selectedCenter = metadata.selectedCenter;
        event_inx = metadata.event_inx;
        stim_inx = metadata.stim_inx;
        sweep_inx = metadata.sweep_inx;
        
        % Обновляем UI элементы
        set(hChannelPopup, 'Value', slope_measurement_settings.channel);
        
        polarity_values = get(hPolarityPopup, 'String');
        % Конвертируем в правильный формат для сравнения
        if strcmp(slope_measurement_settings.peak_polarity, 'positive')
            polarity_idx = 1;
        else
            polarity_idx = 2;
        end
        set(hPolarityPopup, 'Value', polarity_idx);
        
        set(hSlopePercentEdit, 'String', num2str(slope_measurement_settings.slope_percent));
        
        % Обновляем настройки онсета
        set(hOnsetMethodPopup, 'Value', getOnsetMethodIndex(slope_measurement_settings.onset_method));
        set(hOnsetThresholdEdit, 'String', num2str(slope_measurement_settings.onset_threshold));
        
        % Обновляем настройки видимости
        set(hBaselineCheckbox, 'Value', slope_measurement_settings.show_baseline);
        set(hSlopeCheckbox, 'Value', slope_measurement_settings.show_slope);
        set(hOnsetCheckbox, 'Value', slope_measurement_settings.show_onset);
        set(hPeakCheckbox, 'Value', slope_measurement_settings.show_peak);
        
        % Обновляем видимость поля порога
        % updateOnsetThresholdVisibility();
        
        % Обновляем edit fields с относительным временем
        updateCursorEditFields();
        
        % Обновляем кнопку зума (зум сброшен, поэтому всегда показываем "Zoom")
        zoomBtn = findobj(signalFig, 'Style', 'pushbutton', 'Callback', @toggleZoom);
        if ~isempty(zoomBtn)
            set(zoomBtn, 'String', 'Zoom');
        end
        
        % Зум сброшен, поэтому обновляем статус навигации без учета зума
        % if zoom_active
        %     updateNavigationStatus();
        % end
        
        % Обновляем график и статус
        updateNavigationStatus();
        updatePlotAndCalculation();
                
        % Сбрасываем флаг восстановления
        restoring_from_metadata = false;
        
        fprintf('✓ State restored from result #%d\n', row_index);
    end
    
    function status_text = getNavigationStatusText(metadata)
        % Возвращает текст статуса навигации (аналогично updateNavigationStatus)
        status_text = sprintf('Mode: %s', metadata.selectedCenter);
        
        % Добавляем информацию о текущей позиции
        switch metadata.selectedCenter
            case 'event'
                if events_exist && ~isempty(events)
                    status_text = sprintf('%s (%d/%d)', status_text, metadata.event_inx, length(events));
                end
            case 'stimulus'
                if stims_exist && ~isempty(stims)
                    status_text = sprintf('%s (%d/%d)', status_text, metadata.stim_inx, length(stims));
                end
            case 'sweep'
                if isstruct(sweep_info) && sweep_info.is_sweep_data
                    status_text = sprintf('%s (%d/%d)', status_text, metadata.sweep_inx, sweep_info.sweep_count);
                end
        end
        
        % Добавляем информацию о зуме
        if metadata.zoom_active
            if ~isempty(metadata.zoom_y_min) && ~isempty(metadata.zoom_y_max)
                status_text = sprintf('%s | Zoom: %.1f%%-%.1f%% | Y: %.2f-%.2f', status_text, ...
                    metadata.zoom_start_rel*100, metadata.zoom_end_rel*100, metadata.zoom_y_min, metadata.zoom_y_max);
            else
                status_text = sprintf('%s | Zoom: %.1f%%-%.1f%%', status_text, ...
                    metadata.zoom_start_rel*100, metadata.zoom_end_rel*100);
            end
        end
    end
    
    function toggleMeanResults(~, ~)
        % Переключает режим просмотра среднего сигнала
        
        if isempty(slope_measurement_results)
            fprintf('❌ No results for averaging\n');
            return;
        end
        
        mean_results_active = ~mean_results_active;
        
        if mean_results_active
            % Вычисляем средний сигнал
            [mean_signal_data, mean_signal_time] = calculateMeanSignal();
            set(hMeanResultsBtn, 'String', 'Show Single');
            fprintf('✓ Average signal mode enabled (%d results)\n', length(slope_measurement_results));
            % вычисляем границы осей
            [optimal_xlim, optimal_ylim] = calculateOptimalAxisLimits(true);
        else
            % Сбрасываем средний сигнал
            mean_signal_data = [];
            mean_signal_time = [];
            set(hMeanResultsBtn, 'String', 'Av. Trace');
            fprintf('✓ Single signal mode enabled\n');
            if isempty(original_xlim) && isempty(original_ylim)
                [original_xlim, original_ylim] = calculateOptimalAxisLimits(true);
            else
                xlim(original_xlim);
                ylim(original_ylim);
            end
        end
        
        % Обновляем состояние кнопок
        updateButtonStates();
        
        % Обновляем график
        updatePlotAndCalculation();
    end
    
    function updateButtonStates()
        % Обновляет состояние кнопок в зависимости от режима среднего сигнала
        
        if mean_results_active
            % Деактивируем кнопки при показе среднего результата
            set(hPrevBtn, 'Enable', 'off');
            set(hNextBtn, 'Enable', 'off');
            set(hAddBtn, 'Enable', 'off');
            set(hReplaceBtn, 'Enable', 'off');
            set(hRemoveBtn, 'Enable', 'off');
        else
            % Активируем кнопки при показе одиночного сигнала
            set(hPrevBtn, 'Enable', 'on');
            set(hNextBtn, 'Enable', 'on');
            set(hAddBtn, 'Enable', 'on');
            set(hReplaceBtn, 'Enable', 'on');
            set(hRemoveBtn, 'Enable', 'on');
        end
        
        % Обновляем состояние кнопки Replace отдельно
        updateReplaceButtonState();
    end
    


    function [channel_data, time_in] = getCurrentData()
        % Получает текущие данные для измерений
        
        % Проверяем, нужно ли использовать средний сигнал
        if mean_results_active && ~isempty(mean_signal_data) && ~isempty(mean_signal_time)
            % Используем средний сигнал
            channel_data = mean_signal_data;
            time_in = mean_signal_time;
        else
            % Получаем данные текущего временного интервала
            plot_time_interval = chosen_time_interval;
            plot_time_interval(1) = plot_time_interval(1) - time_back;
            
            cond = time >= plot_time_interval(1) & time < plot_time_interval(2);
            local_lfp = lfp(cond, :);
            
            % Вычитание средних каналов если нужно
            if ~isempty(mean_group_ch) && any(mean_group_ch)
                local_lfp(:, mean_group_ch) = local_lfp(:, mean_group_ch) - mean(local_lfp(:, mean_group_ch), 2);
            end
            
            selected_channel = slope_measurement_settings.channel;
            channel_data = local_lfp(:, selected_channel);
            time_in = time(cond);
            
            % Убираем артефакт стимуляции если есть стимулы
            if not(isempty(stims)) && stimShowFlag
                Fs_fascor = Fs/1000;
                channel_data = removeStimArtifact(channel_data, stims, time_in, art_rem_window_ms*Fs_fascor*0.5);
            end

        end
    end
    

    
    
    function autoMeasureAllTimeRanges(~, ~)
        % Автоматически измеряет все временные участки и заполняет таблицу
        % Аналогично тому, как пользователь нажимает Next + Add в цикле
        
        % Проверяем, есть ли уже результаты в таблице
        if ~isempty(slope_measurement_results)
            % Запрашиваем подтверждение у пользователя с тремя опциями
            choice = questdlg('The table already contains results. Do you want to clear them before auto measurement?', ...
                              'Auto Measurement Options', ...
                              'Yes', 'No', 'Cancel', 'Cancel');
            
            switch choice
                case 'Yes'
                    % Очищаем таблицу результатов перед автоматическим измерением
                    slope_measurement_results = [];
                    updateResultsTable();
                    fprintf('✓ Table cleared before automatic measurement\n');
                    
                case 'No'
                    % Продолжаем с существующими результатами
                    fprintf('✓ Automatic measurement will be added to existing results\n');
                    
                case 'Cancel'
                    % Отменяем операцию
                    fprintf('❌ Automatic measurement cancelled by user\n');
                    return;
                    
                otherwise
                    % Пользователь закрыл диалог
                    fprintf('❌ Automatic measurement cancelled\n');
                    return;
            end
        end
        
        % Сбрасываем выделения
        selected_row_slope = [];
        
        % Сбрасываем средний сигнал
        mean_results_active = false;
        mean_signal_data = [];
        mean_signal_time = [];
        
        % Обновляем состояние кнопок
        updateButtonStates();
        
        % Сохраняем текущее состояние
        original_interval = chosen_time_interval;
        original_stim_inx = stim_inx;
        original_sweep_inx = sweep_inx;
        
        % Определяем количество участков в зависимости от режима
        switch selectedCenter
            case 'stimulus'
                if stims_exist && ~isempty(stims)
                    total_ranges = length(stims);
                    fprintf('Automatic measurement of %d stimuli...\n', total_ranges);
                else
                    fprintf('ERROR: No stimuli for measurement\n');
                    return;
                end
                
            case 'sweep'
                if isstruct(sweep_info) && sweep_info.is_sweep_data
                    total_ranges = sweep_info.sweep_count;
                    fprintf('Automatic measurement of %d sweeps...\n', total_ranges);
                else
                    fprintf('ERROR: No sweep data for measurement\n');
                    return;
                end
                
            case 'time'
                % Для режима time вычисляем количество возможных шагов
                windowSize = chosen_time_interval(2) - chosen_time_interval(1);
                if windowSize <= 0
                    fprintf('ERROR: Invalid time window size\n');
                    return;
                end
                total_ranges = floor((time(end) - time(1)) / windowSize);
                if total_ranges <= 0
                    fprintf('ERROR: Insufficient data for measurement\n');
                    return;
                end
                fprintf('Automatic measurement of %d time segments...\n', total_ranges);
                
            otherwise
                fprintf('ERROR: Unsupported navigation mode\n');
                return;
        end
        
        % Сохраняем относительные позиции текущих диапазонов
        [baseline_rel, peak_rel] = getRelativePositions();
        
        % Получаем размер окна из текущего интервала
        windowSize = chosen_time_interval(2) - chosen_time_interval(1);
        
        % Устанавливаем флаг автоанализа
        auto_analysis_mode = true;
        
        % Создаем окно прогресса
        hWaitBar = waitbar(0, 'Starting auto analysis...', 'Name', 'Auto analysis');
        
        % Циклически измеряем каждый участок
        try
            for i = 1:total_ranges
                % Проверяем, не было ли закрыто окно прогресса
                if ~ishandle(hWaitBar)
                    fprintf('❌ Automatic measurement cancelled by user\n');
                    break;
                end
                
                % Обновляем прогресс
                progress = i / total_ranges;
                percent = round(progress * 100);
                current_message = sprintf('Measuring segment %d of %d (%d%%)', i, total_ranges, percent);
                waitbar(progress, hWaitBar, current_message);
                
                fprintf('Measuring segment %d/%d...\n', i, total_ranges);
                
                % Переключаемся на следующий участок (аналогично Next)
                switch selectedCenter
                    case 'stimulus'
                        stim_inx = i;
                        chosen_time_interval(1) = stims(stim_inx);
                        chosen_time_interval(2) = stims(stim_inx) + windowSize;
                        
                    case 'sweep'
                        sweep_inx = i;
                        chosen_time_interval(1) = sweep_info.sweep_times(sweep_inx);
                        chosen_time_interval(2) = chosen_time_interval(1) + windowSize;
                        
                    case 'time'
                        chosen_time_interval(1) = time(1) + (i-1) * windowSize;
                        chosen_time_interval(2) = chosen_time_interval(1) + windowSize;
                end
            
                % Применяем сохраненные относительные позиции к новому интервалу
                setRelativePositions(baseline_rel, peak_rel);
                
                % Обновляем edit fields после изменения позиций
                updateCursorEditFields();
                
                % Вычисляем результаты для текущего участка
                [slope_value, slope_angle, peak_time, peak_value, baseline_value, onset_time, onset_value, measurement_metadata] = calculateResults();
                
                % Автоматически добавляем результат в таблицу БЕЗ обновления UI
                addResultSilent();
                
                % Минимальная задержка для проверки отмены
                pause(0.01);
                
                % Минимальное обновление для прогресса
                if mod(i, 10) == 0 || i == total_ranges
                    fprintf('Progress: %d/%d\n', i, total_ranges);
                end
            end
            
            % Проверяем, была ли отмена
            if ~ishandle(hWaitBar)
                fprintf('❌ Автоматическое измерение отменено пользователем\n');
            else
                fprintf('SUCCESS: Automatic measurement completed! Added %d results\n', total_ranges);
            end
            
            % Принудительно закрываем окно прогресса после завершения цикла
            if exist('hWaitBar', 'var') && ishandle(hWaitBar)
                close(hWaitBar);
                fprintf('✓ Progress window closed after completion\n');
            end
            
        catch ME
            % Закрываем окно прогресса при ошибке
            if exist('hWaitBar', 'var') && ishandle(hWaitBar)
                close(hWaitBar);
                fprintf('✓ Progress window closed on error\n');
            end
            
            % Сбрасываем флаг автоанализа
            auto_analysis_mode = false;
            
            % Показываем ошибку пользователю
            fprintf('Error in auto-analysis: %s\n', ME.message);
            fprintf('❌ Error in auto-analysis: %s\n', ME.message);
            return;
        end
        
        % Восстанавливаем исходное состояние
        chosen_time_interval = original_interval;
        
        % Восстанавливаем индексы в зависимости от режима
        switch selectedCenter
            case 'stimulus'
                if stims_exist && ~isempty(stims)
                    % Находим ближайший стимул к восстановленному интервалу
                    [~, stim_inx] = min(abs(stims - chosen_time_interval(1)));
                end
            case 'sweep'
                if isstruct(sweep_info) && sweep_info.is_sweep_data
                    % Находим ближайший sweep к восстановленному интервалу
                    [~, sweep_inx] = min(abs(sweep_info.sweep_times - chosen_time_interval(1)));
                end
        end
        
        % Восстанавливаем относительные позиции диапазонов
        setRelativePositions(baseline_rel, peak_rel);
        
        % Сбрасываем флаг автоанализа
        auto_analysis_mode = false;
        
        % Закрываем окно прогресса в любом случае
        if exist('hWaitBar', 'var') && ishandle(hWaitBar)
            close(hWaitBar);
            fprintf('✓ Progress window closed\n');
        end
        
        % ФИНАЛЬНОЕ обновление всех таблиц и графика
        updateResultsTable();
        updatePlotAndCalculation();
        
        % Обновляем статус навигации
        updateNavigationStatus();
        
        % Обновляем состояние кнопки Replace
        updateReplaceButtonState();
    end
    
    function loadResults(~, ~)
        % Загружает результаты и измерения из .meta файла
        
        % Определяем начальный путь для загрузки (тот же, что и для сохранения)
        if ~isempty(matFilePath) && ~isempty(matFileName)
            [path, ~, ~] = fileparts(matFilePath);
            defaultPath = path;
        else
            defaultPath = pwd; % текущая директория если нет исходного файла
        end
        
        % Запрашиваем файл для загрузки
        [filename, pathname] = uigetfile('*.meta', 'Load Results From', defaultPath);
        
        if isequal(filename, 0) || isequal(pathname, 0)
            fprintf('❌ Loading cancelled\n');
            return;
        end
        
        filepath = fullfile(pathname, filename);
        
        try
            % Загружаем данные из файла (фактически .mat файл с расширением .meta)
            loaded_data = load(filepath, '-mat');
            
            % Проверяем, нужно ли загружать оригинальный файл
            if isfield(loaded_data, 'original_file_info') && ~isempty(loaded_data.original_file_info.matFileName)
                if ~strcmp(loaded_data.original_file_info.matFileName, matFileName)
                    % Имена файлов не совпадают, загружаем оригинальный файл
                    fprintf('📁 Loading original file: %s\n', loaded_data.original_file_info.matFilePath);
                    OpenFilePath(loaded_data.original_file_info.matFilePath);
                else
                    fprintf('ℹ️ Original file already loaded: %s\n', matFileName);
                end
            end
            
            % Загружаем основные результаты
            slope_measurement_results = loaded_data.slope_measurement_results;
            
            % Проверяем и обновляем старые метаданные
            fprintf('Checking and updating old metadata...\n');
            for i = 1:length(slope_measurement_results)
                % Проверяем наличие поля stim_inx
                if ~isfield(slope_measurement_results(i).metadata, 'stim_inx')
                    % Для старых метаданных пробуем получить номер стимула из индекса
                    if strcmp(slope_measurement_results(i).metadata.selectedCenter, 'stimulus') && stims_exist && ~isempty(stims)
                        slope_measurement_results(i).metadata.stim_inx = i;
                        fprintf('  Result #%d: added stimulus number %d\n', i, i);
                    else
                        slope_measurement_results(i).metadata.stim_inx = NaN;
                        fprintf('  Result #%d: stimulus number not determined\n', i);
                    end
                end
                
                % Проверяем наличие полей для peak_onset_diff
                if ~isfield(slope_measurement_results(i), 'onset_time')
                    slope_measurement_results(i).onset_time = NaN;
                    fprintf('  Result #%d: added onset_time field\n', i);
                end
                if ~isfield(slope_measurement_results(i), 'onset_value')
                    slope_measurement_results(i).onset_value = NaN;
                    fprintf('  Result #%d: added onset_value field\n', i);
                end
            end
            fprintf('Metadata update completed\n');

            % Сбрасываем выделения
            selected_row_slope = [];
            selected_measurement_row = [];
            
            % Обновляем отображение
            updateResultsTable();
            
            fprintf('✓ Results loaded from file:\n');
            fprintf('  File: %s\n', filepath);
            fprintf('  Results: %d\n', length(slope_measurement_results));
            
            % Восстанавливаем состояние первого результата если есть
            if ~isempty(slope_measurement_results)
                restoreStateFromMetadata(1);
            end
            
        catch ME
            fprintf('❌ Error loading: %s\n', ME.message);
        end
    end
    
    function openFile(~, ~)
        % Открывает новый файл для анализа (аналогично OpenZavLfpFile из signalViewerGUI.m)
        if ~isempty(outside_calling_filepath)
            filepath = outside_calling_filepath;
            outside_calling_filepath = [];
        else
            % Получение пути к последнему открытому файлу или использование стандартной директории
            initialDir = pwd;
            if ~isempty(lastOpenedFiles)
                initialDir = fileparts(lastOpenedFiles{end});
            end
            
            [file, path] = uigetfile('*.mat', 'Load .mat File (ZAV or Heka format)', initialDir);
            if isequal(file, 0)
                disp('File selection canceled.');
                return;
            end
            filepath = fullfile(path, file);
        end
        
        % Очищаем все предыдущие результаты и измерения
        slope_measurement_results = [];

        
        % Сбрасываем выделения
        selected_row_slope = [];
        selected_measurement_row = [];
        
        % Сбрасываем средний сигнал
        mean_results_active = false;
        mean_signal_data = [];
        mean_signal_time = [];
        
        % Загружаем новый файл используя универсальную функцию
        try
            % Используем универсальную функцию загрузки
            data = load_zav_file(filepath, ...
                'auto_set_time_windows', true, ...
                'auto_set_fs', true);
            [lfp, spks, hd, zavp, lfpVar, chnlGrp, time, stims, sweep_info, time_forward, time_back] = struct2vars(data);
            
            % Получаем размеры для совместимости
            [m, n, p] = size(lfp);
            N = size(lfp, 1);
            Fs = zavp.dwnSmplFrq;
            
            % Устанавливаем флаги
            stims_exist = ~isempty(stims);
            sweep_inx = 1;
            
            % Устанавливаем временные параметры
            chosen_time_interval = [0, time_forward];
            
            % Устанавливаем newFs
            newFs = Fs; % используем частоту даунсемплинга
            
            % Автоматический выбор режима центра
            if stims_exist && ~isempty(stims)
                selectedCenter = 'stimulus';
            else
                selectedCenter = 'time';
            end
            stim_inx = 1;
            
            % === ДОБАВЛЕНО: Загрузка групповых настроек ===
            % Инициализируем переменные для настроек
            if isfield(hd, 'recChNames') && iscell(hd.recChNames)
                channelNames = hd.recChNames;
            else
                channelNames = {'Ch1'};
            end
            numChannels = length(channelNames);
            
            % === КОНЕЦ ДОБАВЛЕННОГО КОДА ===
            
            % Обновление и сохранение списка последних открытых файлов
            lastOpenedFiles{end + 1} = filepath;
            
            % Сохраняем обновленный список в настройки
            try
                save(SettingsFilepath, 'lastOpenedFiles', '-append');
            catch
                % Если не удалось сохранить, создаем новый файл
                save(SettingsFilepath, 'lastOpenedFiles');
            end
            
            % Обновляем глобальные переменные
            matFilePath = filepath;
            [~, matFileName, ~] = fileparts(matFilePath);
            
            % Загружаем настройки каналов (индивидуальные или групповые)
            loadChannelSettings();
            
            % Обновляем popup каналов
            if exist('hChannelPopup', 'var') && ishandle(hChannelPopup)
                if isfield(hd, 'recChNames') && iscell(hd.recChNames) && ~isempty(hd.recChNames)
                    set(hChannelPopup, 'String', hd.recChNames, 'Value', 1);
                else
                    set(hChannelPopup, 'String', {'Ch1'}, 'Value', 1);
                end
            end
            
            % Обновляем edit fields для нового файла
            updateCursorEditFields();
            
            % Показываем оси после загрузки файла
            set(hPlotAxes, 'Visible', 'on');
            
            % Обновляем отображение
            updateNavigationStatus();
            updatePlotAndCalculation();
            
            % Вычисляем и применяем оптимальные границы осей ПОСЛЕ обновления графика
            [optimal_xlim, optimal_ylim] = calculateOptimalAxisLimits(true);
            
            % Сохраняем как original для правильной работы зума
            original_xlim = optimal_xlim;
            original_ylim = optimal_ylim;
            updateResultsTable();
            updateButtonStates();
            
            % Обновляем состояние кнопки Replace
            updateReplaceButtonState();
            
            % Загружаем позиции курсоров из настроек ПОСЛЕ загрузки файла
            loadCursorPositionsFromSettings();
            
            fprintf('✓ File successfully loaded: %s\n', matFileName);
            fprintf('  Data size: %dx%dx%d\n', size(lfp));
            fprintf('  Sampling rate: %.1f Hz\n', Fs);
            fprintf('  Duration: %.3f s\n', time(end));
            
        catch ME
            fprintf('❌ Error loading file: %s\n', ME.message);
            % Восстанавливаем предыдущие данные если загрузка не удалась
            return;
        end
    end
    
    function clearAllResults(~, ~)
        % Очищает все результаты и измерения разом
        
        % Запрос подтверждения у пользователя
        choice = questdlg('Are you sure you want to clear all results and measurements? This action cannot be undone.', ...
                          'Clear All Results', ...
                          'Yes', 'No', 'No');
        switch choice
            case 'Yes'
                % Очищаем все результаты slope measurement
                slope_measurement_results = [];
                
                % Сбрасываем выделения
                selected_row_slope = [];
                selected_measurement_row = [];
                
                % Сбрасываем средний сигнал
                mean_results_active = false;
                mean_signal_data = [];
                mean_signal_time = [];
                
                % Обновляем отображение
                updateResultsTable();
                
                        % Обновляем состояние кнопок
        updateButtonStates();
        
        % Обновляем график
        updatePlotAndCalculation();
        
        % Обновляем состояние кнопки Replace
        updateReplaceButtonState();
        
        fprintf('✓ All results and measurements cleared\n');
                
            case 'No'
                % Пользователь отменил операцию
                return;
        end
    end
    
    function updateAnalysisPlotFunc()
        % Глобальная функция для обновления графика анализа сигнала
        % Вызывается из settingsEditor.m
        try
            updatePlotAndCalculation();
            fprintf('✓ Signal analysis plot updated from group settings\n');
        catch ME
            warning('Error updating analysis plot: %s', ME.message);
        end
    end

    % === ДОБАВЛЕНО: Функции для загрузки настроек каналов ===
    
    function updateTable()
        % Простая версия функции updateTable для signalAnalysisGUI
        % fprintf('DEBUG: updateTable: Функция вызвана\n');
        % fprintf('DEBUG: updateTable: channelNames = ');
        % disp(channelNames);
        % fprintf('DEBUG: updateTable: numChannels = %d\n', numChannels);
        
        % Здесь можно добавить логику обновления таблицы если нужно
        % fprintf('DEBUG: updateTable: Таблица обновлена\n');
    end
    
    function loadChannelSettings()
        % Загружает настройки каналов (индивидуальные или групповые)
        % fprintf('DEBUG: loadChannelSettings: Начало функции\n');
        % fprintf('DEBUG: loadChannelSettings: matFilePath = %s\n', matFilePath);
        % fprintf('DEBUG: loadChannelSettings: numChannels = %d\n', numChannels);
        % fprintf('DEBUG: loadChannelSettings: Fs = %.1f\n', Fs);
        % fprintf('DEBUG: loadChannelSettings: EV_version = %s\n', EV_version);
        
        [path, name, ~] = fileparts(matFilePath);
        channelSettingsFilePath = fullfile(path, [name '_channelSettings.stn']);
        % fprintf('DEBUG: loadChannelSettings: channelSettingsFilePath = %s\n', channelSettingsFilePath);
        
        if isfile(channelSettingsFilePath)
            % Индивидуальные настройки существуют - загружаем их полностью
            % fprintf('DEBUG: loadChannelSettings: Индивидуальные настройки найдены\n');
            disp('Loading individual channel settings...')
            loadSettingsFile(channelSettingsFilePath);
        else
            % Индивидуальных настроек нет - загружаем групповые + создаем индивидуальные
            % fprintf('DEBUG: loadChannelSettings: Индивидуальные настройки НЕ найдены, загружаем групповые\n');
            disp('No individual settings found, loading group settings...')
            % Загружаем групповые настройки и создаем индивидуальные
            loadGroupSettingsAndCreateIndividual(matFilePath, numChannels, Fs, EV_version);
        end
        
        % fprintf('DEBUG: loadChannelSettings: Конец функции\n');
    end
    
    function loadSettingsFile(channelSettingsFilePath)
        % Загружает настройки из файла настроек каналов
        % fprintf('DEBUG: loadSettingsFile: Начало загрузки из %s\n', channelSettingsFilePath);
        
        try
            loadedSettings = load(channelSettingsFilePath, '-mat');
            % fprintf('DEBUG: loadSettingsFile: Файл загружен, поля: ');
            % disp(fieldnames(loadedSettings));
            if isfield(loadedSettings, 'EV_version') % работает с 1.10.00  
                % fprintf('DEBUG: loadSettingsFile: Новый формат настроек (EV_version = %s)\n', loadedSettings.EV_version);
                channelNames = np_flatten(loadedSettings.channelNames);
                channelEnabled = np_flatten(loadedSettings.channelEnabled);
                scalingCoefficients = np_flatten(loadedSettings.scalingCoefficients);
                colorsIn = np_flatten(loadedSettings.colorsIn);
                lineCoefficients = np_flatten(loadedSettings.lineCoefficients);
                mean_group_ch = np_flatten(loadedSettings.mean_group_ch);
                csd_avaliable = np_flatten(loadedSettings.csd_avaliable);
                filter_avaliable = np_flatten(loadedSettings.filter_avaliable);
                
                % fprintf('DEBUG: loadSettingsFile: Загружено каналов: %d\n', length(channelNames));
            else % неактуально с 1.10.00  
                % fprintf('DEBUG: loadSettingsFile: Старый формат настроек\n');
                warning('Old settings format detected')
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
                
                % fprintf('DEBUG: loadSettingsFile: Загружено каналов (старый формат): %d\n', length(channelNames));
            end
            
            % fprintf('DEBUG: loadSettingsFile: Вызываем updateTable()\n');
            updateTable();
            % fprintf('DEBUG: loadSettingsFile: После updateTable(): numChannels = %d\n', numChannels);

            if isfield(loadedSettings, 'filterSettings') && ~(isempty(loadedSettings.filterSettings))
                filterSettings = loadedSettings.filterSettings;
            else % если настройки старые                
                filterSettings.filterType = 'highpass';
                filterSettings.freqLow = 10;
                filterSettings.freqHigh = 50;
                filterSettings.order = 4;
                filterSettings.channelsToFilter = false(length(channelNames), 1);
                disp('settings were without filterSettings')
            end       

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
                chosen_time_interval = [0, time_forward];
            end

            % Загружаем смещенные стимулы если они есть
            if isfield(loadedSettings, 'stims')
                stims = loadedSettings.stims;
                stims_exist = ~isempty(stims);
                stims_loaded_from_settings = true;
                disp('Loaded shifted stimulus times from settings')
            end
            

            
            % fprintf('DEBUG: loadSettingsFile: Настройки каналов загружены успешно\n');
            disp('Channel settings loaded successfully')
            
        catch ME
            warning('Error loading channel settings: %s', ME.message)
            % В случае ошибки создаем настройки по умолчанию
            setDefaultChannelSettings();
        end
    end
    
    function setDefaultChannelSettings()
        % Устанавливает настройки каналов по умолчанию
        if exist('numChannels', 'var') && ~isempty(numChannels)
            channelNames = np_flatten(channelNames);
            channelEnabled = true(1, numChannels);
            scalingCoefficients = ones(1, numChannels);
            colorsIn = np_flatten(repmat({'black'}, numChannels, 1));
            lineCoefficients = ones(1, numChannels) * 0.5;
            mean_group_ch = false(1, numChannels);
            csd_avaliable = true(1, numChannels);
            filter_avaliable = false(1, numChannels);
            
            filterSettings.filterType = 'highpass';
            filterSettings.freqLow = 10;
            filterSettings.freqHigh = 50;
            filterSettings.order = 4;
            filterSettings.channelsToFilter = false(numChannels, 1);
            
            disp('Default channel settings applied')
        end
    end

    % === ДОБАВЛЕНО: Функция для открытия редактора групповых настроек ===
    
    function openGroupSettingsEditor(~, ~)
        % Открывает редактор групповых настроек
        
        % Проверяем, загружен ли файл
        if isempty(matFilePath) || ~exist(matFilePath, 'file')
            fprintf('No project loaded. Please load a MAT file first.\n');
            return;
        end
        
        % Проверяем, что все необходимые глобальные переменные доступны
        if ~exist('numChannels', 'var') || isempty(numChannels)
            fprintf('Channel information not available. Please reload the file.\n');
            return;
        end
        
        if ~exist('Fs', 'var') || isempty(Fs)
            fprintf('Sampling rate information not available. Please reload the file.\n');
            return;
        end
        

        
        % Устанавливаем единицы времени если их нет
        if ~exist('timeUnitFactor', 'var') || isempty(timeUnitFactor)
            timeUnitFactor = 1;
        end
        
        if ~exist('selectedUnit', 'var') || isempty(selectedUnit)
            selectedUnit = 's';
        end
        
        % Создаем заглушки для функций обновления (аналогично signalViewerGUI.m)
        % В slopeMeasurementGUI.m эти функции могут быть пустыми или выполнять базовые операции
        updateTableFunc = @() disp('Table update function called');
        updateLocalCoefsFunc = @() disp('Local coefficients update function called');
        updatePlotFunc = @() updatePlotAndCalculation();
        saveChannelSettingsFunc = @() saveChannelSettings();
        
        % Открываем редактор настроек
        try
            settingsEditor();
            disp('Settings Editor opened successfully');
        catch ME
            fprintf('Error opening Settings Editor: %s\n', ME.message);
        end
    end


    % === ДОБАВЛЕНО: Функция для сохранения изображения ===
    
    function saveImage(~, ~)
        % Сохраняет только график анализа сигнала в различных графических форматах
        
        % Создаем имя файла по умолчанию на основе исходного файла
        if ~isempty(matFilePath) && ~isempty(matFileName)
            [path, name, ~] = fileparts(matFilePath);
            defaultFileName = fullfile(path, [name, '_signal_analysis']);
        else
            defaultFileName = 'signal_analysis';
        end
        
        % Запрашиваем имя файла для сохранения
        [file, path, filterindex] = uiputfile(...
            {'*.pdf', 'PDF files (*.pdf)';...
             '*.eps', 'EPS files (*.eps)';...
             '*.png', 'PNG files (*.png)';...
             '*.*', 'All Files (*.*)'},...
             'Save Image As', defaultFileName);
        
        if isequal(file, 0) || isequal(path, 0)
            fprintf('❌ Image save cancelled\n');
            return;
        end
        
        filename = fullfile(path, file);
        
        try
            % Создаем временную фигуру только с графиком
            tempFig = figure('Visible', 'off', 'Position', [100, 100, 800, 600]);
            tempAxes = copyobj(hPlotAxes, tempFig);
            
            % Устанавливаем размеры временной фигуры
            set(tempAxes, 'Position', [0.1, 0.1, 0.8, 0.8]);
            
            % Сохраняем временную фигуру в выбранном формате
            switch filterindex
                case 1
                    print(tempFig, filename, '-dpdf', '-bestfit');
                    fprintf('✓ Plot saved as PDF: %s\n', filename);
                case 2
                    print(tempFig, filename, '-depsc');
                    fprintf('✓ Plot saved as EPS: %s\n', filename);
                case 3
                    saveas(tempFig, filename, 'png');
                    fprintf('✓ Plot saved as PNG: %s\n', filename);
                otherwise
                    saveas(tempFig, filename);
                    fprintf('✓ Plot saved: %s\n', filename);
            end
            
            % Удаляем временную фигуру
            delete(tempFig);
            
        catch ME
            fprintf('❌ Error saving plot: %s\n', ME.message);
            fprintf('Error saving image: %s\n', ME.message);
            
            % Убеждаемся что временная фигура удалена даже при ошибке
            if exist('tempFig', 'var') && ishandle(tempFig)
                delete(tempFig);
            end
        end
    end

    % === Функция для загрузки позиций курсоров ===
    
    function loadCursorPositionsFromSettings()
        % Загружает позиции курсоров из настроек ПОСЛЕ загрузки файла
        
        try
            SettingsFilepath = fullfile(tempdir, 'ev_settings.mat');
            if exist(SettingsFilepath, 'file')
                loadedSettings = load(SettingsFilepath, '-mat');
                if isfield(loadedSettings, 'cursor_positions')
                    % Восстанавливаем абсолютные позиции курсоров из относительных
                    slope_measurement_settings.baseline_start = loadedSettings.cursor_positions.baseline_start + rel_shift;
                    slope_measurement_settings.baseline_end = loadedSettings.cursor_positions.baseline_end + rel_shift;
                    slope_measurement_settings.peak_start = loadedSettings.cursor_positions.peak_start + rel_shift;
                    slope_measurement_settings.peak_end = loadedSettings.cursor_positions.peak_end + rel_shift;
                    
                    fprintf('✓ Cursor positions loaded from settings\n');
                    
                    % Обновляем edit fields с новыми позициями
                    updateCursorEditFields();
                    
                    % НЕ вызываем updatePlotAndCalculation() здесь, чтобы не перезаписывать границы осей
                    % Границы осей уже применены в OpenFilePath() через calculateOptimalAxisLimits()
                else
                    fprintf('ℹ️ Cursor positions not found in settings\n');
                end
            else
                fprintf('ℹ️ Settings file not found\n');
            end
        catch ME
            fprintf('❌ Error loading cursor positions: %s\n', ME.message);
        end
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
                fprintf('ℹ️ No recent files found for automatic opening\n');
                return;
            end
            
            % Берем последний файл из списка
            lastFile = lastOpenedFiles{end};
            
            % Проверяем, существует ли файл
            if ~exist(lastFile, 'file')
                fprintf('⚠️ Last file not found: %s\n', lastFile);
                % Удаляем несуществующий файл из списка
                lastOpenedFiles(end) = [];
                
                % Показываем диалог с предложением открыть файл вручную
                choice = questdlg('Last opened file not found. Would you like to open a file manually?', ...
                    'File Not Found', ...
                    'Yes', 'No', 'Yes');
                
                switch choice
                    case 'Yes'
                        % Получаем путь к последнему открытому файлу или используем стандартную директорию
                        initialDir = pwd;
                        if ~isempty(lastOpenedFiles)
                            initialDir = fileparts(lastOpenedFiles{end});
                        end
                        
                        [file, path] = uigetfile('*.mat', 'Load .mat File (ZAV or Heka format)', initialDir);
                        if ~isequal(file, 0)
                            outside_calling_filepath = fullfile(path, file);
                            openFile([], []);
                        end
                    case 'No'
                        fprintf('ℹ️ Manual file opening cancelled\n');
                end
                return;
            end
            fprintf('🔄 Automatically opening last file: %s\n', lastFile);
            outside_calling_filepath = lastFile;
            openFile([], []);
        catch ME
            fprintf('❌ Error during automatic file opening: %s\n', ME.message);
            fprintf('ℹ️ Continuing with clean initialization\n');
        end
    end

    function OpenFilePath(filepath)
        outside_calling_filepath = filepath;
        openFile([], []);
    end

    % === Функции для перетаскивания области зума ===
    
    function rightClickPan(~, ~)
        if ~zoom_active
            return;
        end
        
        % Проверяем, что это правая кнопка мыши
        if strcmp(get(signalFig, 'SelectionType'), 'alt') % alt = правая кнопка
            pan_active = true;
            
            % Запоминаем начальную позицию мыши и границы зума
            cp = get(hPlotAxes, 'CurrentPoint');
            pan_start_mouse_pos = [cp(1,1), cp(1,2)]; % X и Y координаты
            pan_start_xlim = xlim(hPlotAxes);
            pan_start_ylim = ylim(hPlotAxes);
            
            % Устанавливаем обработчики движения и отпускания мыши
            set(signalFig, 'WindowButtonMotionFcn', @panZoom);
            set(signalFig, 'WindowButtonUpFcn', @stopPanZoom);
        end
    end
    
    function panZoom(~, ~)
        if ~pan_active
            return;
        end
        
        % Вычисляем смещение мыши от начальной точки
        cp = get(hPlotAxes, 'CurrentPoint');
        mouse_delta_x = cp(1,1) - pan_start_mouse_pos(1);
        mouse_delta_y = cp(1,2) - pan_start_mouse_pos(2);
        
        % Сдвигаем область зума по X на то же расстояние
        new_xlim = pan_start_xlim - mouse_delta_x;
        
        % Проверяем границы по X (не выходим за original_xlim)
        zoom_width = new_xlim(2) - new_xlim(1);
        if new_xlim(1) < original_xlim(1)
            new_xlim = [original_xlim(1), original_xlim(1) + zoom_width];
        elseif new_xlim(2) > original_xlim(2)
            new_xlim = [original_xlim(2) - zoom_width, original_xlim(2)];
        end
        
        % Сдвигаем область зума по Y на то же расстояние
        new_ylim = pan_start_ylim - mouse_delta_y;
        
        % Проверяем границы по Y (не выходим за original_ylim)
        zoom_height = new_ylim(2) - new_ylim(1);
        if new_ylim(1) < original_ylim(1)
            new_ylim = [original_ylim(1), original_ylim(1) + zoom_height];
        elseif new_ylim(2) > original_ylim(2)
            new_ylim = [original_ylim(2) - zoom_height, original_ylim(2)];
        end
        
        % Применяем новые границы
        xlim(new_xlim);
        ylim(new_ylim);
        
        % Обновляем zoom_start_rel и zoom_end_rel
        full_range = original_xlim(2) - original_xlim(1);
        zoom_start_rel = (new_xlim(1) - original_xlim(1)) / full_range;
        zoom_end_rel = (new_xlim(2) - original_xlim(1)) / full_range;
        
        % Обновляем zoom_y_min и zoom_y_max
        zoom_y_min = new_ylim(1);
        zoom_y_max = new_ylim(2);
        
        % Обновляем позиции линий
        updateLinePositions();
        updateMeasurementCursorPositions();
    end
    
    function stopPanZoom(~, ~)
        pan_active = false;
        set(signalFig, 'WindowButtonMotionFcn', '');
        set(signalFig, 'WindowButtonUpFcn', '');
        
        % Обновляем статус навигации
        updateNavigationStatus();
    end
    
    function applyAutoscale(~, ~)
        % Применяет оптимальные размеры осей для видимых данных
        
        % Вычисляем и применяем оптимальные границы осей
        [optimal_xlim, optimal_ylim] = calculateOptimalAxisLimits(true);
        
        % Сбрасываем зум если он был активен
        if zoom_active
            zoom_active = false;
            zoom_start_rel = 0;
            zoom_end_rel = 1;
            zoom_y_min = [];
            zoom_y_max = [];
            
            % Обновляем кнопку зума
            zoomBtn = findobj(signalFig, 'Style', 'pushbutton', 'Callback', @toggleZoom);
            if ~isempty(zoomBtn)
                set(zoomBtn, 'String', 'Zoom');
            end
        end
        
        % Обновляем статус навигации
        updateNavigationStatus();
        
        fprintf('✓ Optimal axis sizes applied\n');
    end

    function loadEvents(~, ~)
        % Загружает события из файла используя универсальную функцию
        global updatePlotFunc
        
        % Сохраняем текущие callback функции
        old_updatePlotFunc = [];
        old_table_calling = [];
        if exist('updatePlotFunc', 'var')
            old_updatePlotFunc = updatePlotFunc;
        end
        if exist('table_calling', 'var')
            old_table_calling = table_calling;
        end
        
        % Устанавливаем callback функции для signalAnalysisGUI
        updatePlotFunc = @() updatePlotAndCalculation();
        table_calling = []; % В signalAnalysisGUI нет таблицы событий
        
        % Определяем источник файла
        if ~isempty(outside_calling_filepath)
            filepath = outside_calling_filepath;
            outside_calling_filepath = [];
        else
            filepath = [];
        end
        
        % Вызываем универсальную функцию загрузки
        if isempty(filepath)
            loadEventsFromFile();
        else
            loadEventsFromFile(filepath, struct('skip_mode_change', true));
        end
        
        % Восстанавливаем callback функции
        if ~isempty(old_updatePlotFunc)
            updatePlotFunc = old_updatePlotFunc;
        end
        if ~isempty(old_table_calling)
            table_calling = old_table_calling;
        end
        
        % Если события успешно загружены, переключаемся на режим событий и обновляем график
        if events_exist && ~isempty(events)
            selectedCenter = 'event';
            event_inx = 1;
            
            % Обновляем временной интервал для первого события
            if exist('time_forward', 'var') && ~isempty(time_forward)
                chosen_time_interval(1) = events(event_inx);
                chosen_time_interval(2) = events(event_inx) + time_forward;
            end
            
            % Обновляем edit fields
            updateCursorEditFields();
            
            % Обновляем график и статус
            updateNavigationStatus();
            updatePlotAndCalculation();
        else
            % Обновляем только статус если события не загружены
            updateNavigationStatus();
        end
    end

    function collectAllMetadata(~, ~)
        % Функция для сбора всех метаданных из подпапок и создания сводной таблицы
        
        % Определяем начальную директорию из текущего файла
        if ~isempty(matFilePath)
            initial_dir = fileparts(matFilePath);
        else
            initial_dir = pwd;
        end
        
        % Запрашиваем корневую папку для поиска
        root_dir = uigetdir(initial_dir, 'Select Root Directory for Metadata Collection');
        if root_dir == 0
            fprintf('❌ Metadata collection cancelled\n');
            return;
        end
        
        % Создаем окно прогресса
        hWaitBar = waitbar(0, 'Starting metadata collection...', 'Name', 'Collecting Metadata');
        
        try
            % Находим все .meta файлы рекурсивно
            fprintf('🔍 Searching for .meta files in folder %s...\n', root_dir);
            meta_files = dir(fullfile(root_dir, '**', '*.meta'));
            
            if isempty(meta_files)
                close(hWaitBar);
                fprintf('No .meta files found in the selected directory and its subdirectories.\n');
                fprintf('❌ No .meta files found\n');
                return;
            end
            
            fprintf('✓ Files found: %d\n', length(meta_files));
            
            % Инициализируем массив для всех результатов
            all_results = [];
            
            % Обрабатываем каждый файл
            for i = 1:length(meta_files)
                % Обновляем прогресс
                progress = i / length(meta_files);
                waitbar(progress, hWaitBar, sprintf('Processing file %d of %d (%d%%)', i, length(meta_files), round(progress * 100)));
                
                % Полный путь к файлу
                meta_path = fullfile(meta_files(i).folder, meta_files(i).name);
                
                try
                    % Загружаем метаданные
                    loaded_data = load(meta_path, '-mat');
                    
                    % Проверяем наличие необходимых полей
                    if ~isfield(loaded_data, 'slope_measurement_results') || isempty(loaded_data.slope_measurement_results)
                        fprintf('⚠️ Skipped file %s: no measurement results\n', meta_files(i).name);
                        continue;
                    end
                    
                    % Проверяем и нормализуем структуру каждого результата
                    for j = 1:length(loaded_data.slope_measurement_results)
                        % Проверяем наличие metadata
                        if ~isfield(loaded_data.slope_measurement_results(j), 'metadata')
                            loaded_data.slope_measurement_results(j).metadata = struct();
                        end
                        
                        % Добавляем информацию о файле
                        loaded_data.slope_measurement_results(j).metadata.source_file = meta_files(i).name;
                        loaded_data.slope_measurement_results(j).metadata.source_path = meta_files(i).folder;
                        
                        % Проверяем наличие rel_shift
                        if ~isfield(loaded_data.slope_measurement_results(j).metadata, 'rel_shift')
                            loaded_data.slope_measurement_results(j).metadata.rel_shift = 0;
                        end
                        
                        % Проверяем наличие stim_inx
                        if ~isfield(loaded_data.slope_measurement_results(j).metadata, 'stim_inx')
                            loaded_data.slope_measurement_results(j).metadata.stim_inx = NaN;
                        end
                        
                        % Проверяем наличие channel
                        if ~isfield(loaded_data.slope_measurement_results(j).metadata, 'channel')
                            loaded_data.slope_measurement_results(j).metadata.channel = 1;
                        end
                        
                        % Проверяем наличие stim_time
                        if ~isfield(loaded_data.slope_measurement_results(j).metadata, 'stim_time')
                            loaded_data.slope_measurement_results(j).metadata.stim_time = NaN;
                        end
                    end
                    
                    % Объединяем результаты
                    if isempty(all_results)
                        all_results = loaded_data.slope_measurement_results;
                    else
                        all_results = [all_results, loaded_data.slope_measurement_results];
                    end
                    
                catch ME
                    fprintf('⚠️ Error processing file %s: %s\n', meta_files(i).name, ME.message);
                    continue;
                end
            end
            
            % Закрываем окно прогресса
            close(hWaitBar);
            
            if isempty(all_results)
                fprintf('No valid results found in any of the .meta files.\n');
                fprintf('❌ No valid results to save\n');
                return;
            end
            
            % Создаем имя файла для сохранения на основе имени корневой папки
            [~, root_folder_name, ~] = fileparts(root_dir);
            default_excel_name = fullfile(root_dir, [root_folder_name '_combined_results.xlsx']);
            
            % Запрашиваем имя файла для сохранения
            [filename, pathname] = uiputfile({'*.xlsx', 'Excel Files (*.xlsx)'}, ...
                'Save Combined Results As', default_excel_name);
            
            if isequal(filename, 0) || isequal(pathname, 0)
                fprintf('❌ Save cancelled\n');
                return;
            end
            
            excel_path = fullfile(pathname, filename);
            
            % Подготавливаем данные для Excel
            excel_data = cell(length(all_results) + 1, 15); % +2 колонки для пути и имени файла
            
            % Заголовки колонок (включая новые)
            headers = {'Source File', 'Source Path', 'Stimulus', 'Slope', 'Peak Time (rel)', ...
                'Peak Time (abs)', 'Peak Amplitude', 'Peak Value (rel)', 'Onset Time (rel)', ...
                'Onset Time (abs)', 'Peak - Onset', 'Baseline', 'Channel', 'Stim Time', 'Info'};
            excel_data(1, :) = headers;
            
            % Заполняем данные с разделителями между файлами
            current_row = 2; % Начинаем с 2, так как 1-я строка - заголовки
            current_file = '';
            
            for i = 1:length(all_results)
                metadata = all_results(i).metadata;
                
                % Если начинается новый файл, добавляем пустую строку-разделитель
                if ~strcmp(current_file, metadata.source_file) && ~isempty(current_file)
                    % Добавляем пустую строку
                    for j = 1:size(excel_data, 2)
                        excel_data{current_row, j} = '';
                    end
                    current_row = current_row + 1;
                end
                current_file = metadata.source_file;
                
                % Относительное время пика
                peak_time_rel = all_results(i).peak_time * timeUnitFactor;
                
                % Абсолютное время пика
                peak_time_abs = (all_results(i).peak_time + metadata.rel_shift) * timeUnitFactor;
                
                % Относительное время онсета
                onset_time_rel = all_results(i).onset_time * timeUnitFactor;
                
                % Абсолютное время онсета
                onset_time_abs = (all_results(i).onset_time + metadata.rel_shift) * timeUnitFactor;
                
                % Разность времени пика и онсета
                peak_onset_diff = (all_results(i).peak_time - all_results(i).onset_time) * timeUnitFactor;
                
                % Заполняем строку данных
                excel_data{current_row, 1} = metadata.source_file;
                excel_data{current_row, 2} = metadata.source_path;
                excel_data{current_row, 3} = metadata.stim_inx;
                excel_data{current_row, 4} = all_results(i).slope_value;
                excel_data{current_row, 5} = peak_time_rel;
                excel_data{current_row, 6} = peak_time_abs;
                excel_data{current_row, 7} = all_results(i).peak_value;
                excel_data{current_row, 8} = all_results(i).peak_value - all_results(i).baseline_value;
                excel_data{current_row, 9} = onset_time_rel;
                excel_data{current_row, 10} = onset_time_abs;
                excel_data{current_row, 11} = peak_onset_diff;
                excel_data{current_row, 12} = all_results(i).baseline_value;
                excel_data{current_row, 13} = metadata.channel;
                excel_data{current_row, 14} = metadata.stim_time;
                excel_data{current_row, 15} = getNavigationStatusText(metadata);
                
                current_row = current_row + 1;
            end
            
            % Сохраняем основные данные на первый лист
            writecell(excel_data, excel_path, 'Sheet', 'Raw Data');
            
            % Создаем второй лист со статистикой по каждому файлу
            % Заголовки для листа статистики
            stats_headers = {'File Name', 'N', ...
                'Slope (Mean)', 'Slope (STD)', ...
                'Peak Time (Mean)', 'Peak Time (STD)', ...
                'Peak Amplitude (Mean)', 'Peak Amplitude (STD)', ...
                'Peak Value rel (Mean)', 'Peak Value rel (STD)', ...
                'Onset Time (Mean)', 'Onset Time (STD)', ...
                'Peak-Onset (Mean)', 'Peak-Onset (STD)', ...
                'Baseline (Mean)', 'Baseline (STD)'};
            
            % Получаем уникальные имена файлов
            source_files = cell(1, length(all_results));
            for i = 1:length(all_results)
                source_files{i} = all_results(i).metadata.source_file;
            end
            unique_files = unique(source_files);
            stats_data = cell(length(unique_files) + 1, length(stats_headers));
            stats_data(1, :) = stats_headers;
            
            % Для каждого файла вычисляем статистику
            for i = 1:length(unique_files)
                file_name = unique_files{i};
                % Находим все результаты для этого файла
                file_mask = false(1, length(all_results));
                for j = 1:length(all_results)
                    if strcmp(all_results(j).metadata.source_file, file_name)
                        file_mask(j) = true;
                    end
                end
                file_results = all_results(file_mask);
                
                % Количество измерений
                n_measurements = sum(file_mask);
                
                % Вычисляем статистику
                slope_values = [file_results.slope_value];
                peak_times = [file_results.peak_time] * timeUnitFactor;
                peak_values = [file_results.peak_value];
                peak_values_rel = [file_results.peak_value] - [file_results.baseline_value];
                onset_times = [file_results.onset_time] * timeUnitFactor;
                peak_onset_diff = ([file_results.peak_time] - [file_results.onset_time]) * timeUnitFactor;
                baseline_values = [file_results.baseline_value];
                
                % Заполняем строку данных
                row = i + 1;
                stats_data{row, 1} = file_name;
                stats_data{row, 2} = n_measurements;
                stats_data{row, 3} = mean(slope_values, 'omitnan');
                stats_data{row, 4} = std(slope_values, 'omitnan');
                stats_data{row, 5} = mean(peak_times, 'omitnan');
                stats_data{row, 6} = std(peak_times, 'omitnan');
                stats_data{row, 7} = mean(peak_values, 'omitnan');
                stats_data{row, 8} = std(peak_values, 'omitnan');
                stats_data{row, 9} = mean(peak_values_rel, 'omitnan');
                stats_data{row, 10} = std(peak_values_rel, 'omitnan');
                stats_data{row, 11} = mean(onset_times, 'omitnan');
                stats_data{row, 12} = std(onset_times, 'omitnan');
                stats_data{row, 13} = mean(peak_onset_diff, 'omitnan');
                stats_data{row, 14} = std(peak_onset_diff, 'omitnan');
                stats_data{row, 15} = mean(baseline_values, 'omitnan');
                stats_data{row, 16} = std(baseline_values, 'omitnan');
            end
            
            % Добавляем общую статистику по всем файлам
            stats_data{end+1, 1} = 'ALL FILES';
            stats_data{end, 2} = length(all_results);
            
            % Вычисляем общую статистику
            all_slopes = [all_results.slope_value];
            all_peak_times = [all_results.peak_time] * timeUnitFactor;
            all_peak_values = [all_results.peak_value];
            all_peak_values_rel = [all_results.peak_value] - [all_results.baseline_value];
            all_onset_times = [all_results.onset_time] * timeUnitFactor;
            all_peak_onset_diff = ([all_results.peak_time] - [all_results.onset_time]) * timeUnitFactor;
            all_baseline_values = [all_results.baseline_value];
            
            stats_data{end, 3} = mean(all_slopes, 'omitnan');
            stats_data{end, 4} = std(all_slopes, 'omitnan');
            stats_data{end, 5} = mean(all_peak_times, 'omitnan');
            stats_data{end, 6} = std(all_peak_times, 'omitnan');
            stats_data{end, 7} = mean(all_peak_values, 'omitnan');
            stats_data{end, 8} = std(all_peak_values, 'omitnan');
            stats_data{end, 9} = mean(all_peak_values_rel, 'omitnan');
            stats_data{end, 10} = std(all_peak_values_rel, 'omitnan');
            stats_data{end, 11} = mean(all_onset_times, 'omitnan');
            stats_data{end, 12} = std(all_onset_times, 'omitnan');
            stats_data{end, 13} = mean(all_peak_onset_diff, 'omitnan');
            stats_data{end, 14} = std(all_peak_onset_diff, 'omitnan');
            stats_data{end, 15} = mean(all_baseline_values, 'omitnan');
            stats_data{end, 16} = std(all_baseline_values, 'omitnan');
            
            % Сохраняем статистику на второй лист
            writecell(stats_data, excel_path, 'Sheet', 'Statistics');
            
            fprintf('✓ Summary table saved:\n');
            fprintf('  Path: %s\n', excel_path);
            fprintf('  Files processed: %d\n', length(meta_files));
            fprintf('  Total results: %d\n', length(all_results));
            
        catch ME
            % Закрываем окно прогресса при ошибке
            if exist('hWaitBar', 'var') && ishandle(hWaitBar)
                close(hWaitBar);
            end
            fprintf('❌ Ошибка при сборе метаданных: %s\n', ME.message);
            fprintf('Error collecting metadata: %s\n', ME.message);
        end
    end

    % Функция обработки изменения размера окна
    function resizeSignalAnalysisWindow(~, ~)
        try
            % Путь к файлу координат
            coordsFile = fullfile(fileparts(mfilename('fullpath')), 'signalAnalysisGUI_coords.json');
            
            % Используем figure_position для правильного вычисления коэффициентов масштабирования
            ResizeElements(signalFig, coordsFile, figure_position);
        catch ME
            warning('Ошибка при масштабировании элементов: %s', ME.message);
        end
    end

    function closeSignalAnalysisWindow(src, ~)
        % Если был режим редактирования - обновляем координаты
        if strcmp(editMode, 'edit')
            try
                update_coords(coordsFile, signalFig);
            catch ME
                warning('Ошибка при обновлении координат: %s', ME.message);
            end
        end
        
        % Не сохраняем положение окна - всегда используем базовое из JSON
        delete(src);
    end

    % Режим редактирования координат
    if strcmp(editMode, 'edit')
        inspect(signalFig);
    end

end 