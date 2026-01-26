function signalAnalysisGUI(editMode)
    debugState('signalAnalysisGUI', 'Signal Analysis Started')

    % Проверяем режим редактирования
    if nargin < 1
        editMode = 'normal';
    end
    
    % Загружаем глобальные настройки (включая инициализацию по умолчанию)
    loadGlobalSettings();
    
    % Загружаем координаты элементов из JSON файла
    coordsFile = getGUIConfigPath('signalAnalysisGUI_coords.json');
    if exist(coordsFile, 'file')
        coordsData = jsondecode(fileread(coordsFile));
    else
        error('Coordinates file not found: %s', coordsFile);
    end
    
    % Signal Analysis GUI - анализ и измерение параметров сигнала
    
    % Глобальные переменные для доступа к данным
    global EV_path EV_version EV_date
    global lfp time chosen_time_interval time_back time_forward hd
    global newFs Fs timeUnitFactor selectedUnit
    global filterSettings filter_avaliable mean_group_ch
    global selectedCenter events stims sweep_info event_inx stim_inx sweep_inx events_exist stims_exist
    global stimShowFlag art_rem_window_ms
    global SettingsFilepath channelSettings
    global original_xlim original_ylim
    global channel_data time_in
    global saveChannelSettingsFunc
    global zav_calling event_calling table_calling outside_calling_filepath
    global lastOpenedFiles auto_analysis_mode
    
    % Глобальные переменные настроек (загружены в app.m)
    global figure_position lastOpenedFiles add_event_settings
    global autodetection_settings lines_and_styles side_panel_visible
    global auto_open_last_file updatePlotFunc
    
    % Глобальные настройки уже загружены в app.m
    
    % Глобальные переменные для настроек каналов
    global channelNames channelEnabled scalingCoefficients colorsIn lineCoefficients
    global csd_avaliable stims_loaded_from_settings
    global shiftCoeff stim_offset
    
    % Глобальные переменные для slope measurement
    global slope_measurement_settings
    global analysis_smooth_enabled analysis_smooth_span analysis_smooth_method
    global slope_measurement_results
    global selected_row_slope % для отслеживания выделенной строки в таблице
    
    % Глобальные переменные для измерений
    global slope_value slope_angle peak_time peak_value baseline_value onset_time onset_value onset_method measurement_metadata

    % Глобальные переменные для сохранения результатов
    global matFilePath matFileName
    global current_loaded_excel_path % путь к загруженному Excel файлу (для сохранения поверх)
    global hot_resave_enabled % флаг горячего пересохранения (Hot Resave)
    
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
    
    % Инициализация параметров сглаживания
    if ~exist('analysis_smooth_enabled', 'var') || isempty(analysis_smooth_enabled)
        analysis_smooth_enabled = false;
    end
    if ~exist('analysis_smooth_span', 'var') || isempty(analysis_smooth_span) || ~isnumeric(analysis_smooth_span) || numel(analysis_smooth_span) ~= 1
        analysis_smooth_span = 5;
    end
    if ~exist('analysis_smooth_method', 'var') || isempty(analysis_smooth_method)
        analysis_smooth_method = 'moving';
    elseif ~any(strcmp(analysis_smooth_method, {'moving', 'median'}))
        analysis_smooth_method = 'moving';
    end
    
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
    global EV_version numChannels
    
    % Глобальные переменные для UI элементов
    global hBaselineStartEdit hBaselineEndEdit hPeakStartEdit hPeakEndEdit
    global hPlotAxes hNavigationStatus hReplaceBtn
    global hSmoothEnableCheckbox hSmoothSpanEdit hSmoothMethodPopup hSmoothShowRawCheckbox
    global hTimeWindowText hTimeBackEdit hTimeForwardEdit
    
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
    
    % Инициализация пути к загруженному Excel файлу
    current_loaded_excel_path = [];
    
    % Инициализация флага Hot Resave
    hot_resave_enabled = false;
    
    % Инициализация флага восстановления состояния из метаданных
    restoring_from_metadata = false;
    
    % Инициализация глобальной функции обновления графика
    updatePlotFunc = @updateAnalysisPlotFunc;
    
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
    if isempty(getappdata(signalFig, 'analysis_show_raw_signal'))
        setappdata(signalFig, 'analysis_show_raw_signal', false);
    end
    
    loadSmoothingSettingsFromFile();

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
    hBaselineStartUnit = uicontrol(signalFig, 'Style', 'text', 'Position', getElementPosition('baseline_start_unit'), ...
        'String', selectedUnit, 'HorizontalAlignment', 'left', 'Tag', 'baseline_start_unit');
    addMagnetButton(hBaselineStartEdit, hBaselineStartUnit, 'baseline_start_magnet', @baselineStartCallback);
    
    % Baseline конец
    uicontrol(signalFig, 'Style', 'text', 'Position', getElementPosition('baseline_end_label'), ...
        'String', 'Baseline End:', 'HorizontalAlignment', 'left', 'Tag', 'baseline_end_label');
    hBaselineEndEdit = uicontrol(signalFig, 'Style', 'edit', ...
        'Position', getElementPosition('baseline_end_edit'), ...
        'String', '0', 'Callback', @baselineEndCallback, 'Tag', 'baseline_end_edit');
    hBaselineEndUnit = uicontrol(signalFig, 'Style', 'text', 'Position', getElementPosition('baseline_end_unit'), ...
        'String', selectedUnit, 'HorizontalAlignment', 'left', 'Tag', 'baseline_end_unit');
    addMagnetButton(hBaselineEndEdit, hBaselineEndUnit, 'baseline_end_magnet', @baselineEndCallback);
    
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
    hPeakStartUnit = uicontrol(signalFig, 'Style', 'text', 'Position', getElementPosition('peak_start_unit'), ...
        'String', selectedUnit, 'HorizontalAlignment', 'left', 'Tag', 'peak_start_unit');
    addMagnetButton(hPeakStartEdit, hPeakStartUnit, 'peak_start_magnet', @peakStartCallback);
    
    % Peak конец
    uicontrol(signalFig, 'Style', 'text', 'Position', getElementPosition('peak_end_label'), ...
        'String', 'Peak End:', 'HorizontalAlignment', 'left', 'Tag', 'peak_end_label');
    hPeakEndEdit = uicontrol(signalFig, 'Style', 'edit', ...
        'Position', getElementPosition('peak_end_edit'), ...
        'String', '0', 'Callback', @peakEndCallback, 'Tag', 'peak_end_edit');
    hPeakEndUnit = uicontrol(signalFig, 'Style', 'text', 'Position', getElementPosition('peak_end_unit'), ...
        'String', selectedUnit, 'HorizontalAlignment', 'left', 'Tag', 'peak_end_unit');
    addMagnetButton(hPeakEndEdit, hPeakEndUnit, 'peak_end_magnet', @peakEndCallback);
    
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
    
    % Блок сглаживания
    uicontrol(signalFig, 'Style', 'text', 'Position', getElementPosition('smoothing_separator'), ...
        'String', '────── Smoothing ──────', ...
        'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'Tag', 'smoothing_separator');
    
    uicontrol(signalFig, 'Style', 'text', 'Position', getElementPosition('smoothing_label'), ...
        'String', 'Enable:', 'HorizontalAlignment', 'left', 'Tag', 'smoothing_label');
    hSmoothEnableCheckbox = uicontrol(signalFig, 'Style', 'checkbox', 'Position', getElementPosition('smoothing_checkbox'), ...
        'Value', analysis_smooth_enabled, 'Callback', @toggleSmoothing, 'Tag', 'smoothing_checkbox');
    
    uicontrol(signalFig, 'Style', 'text', 'Position', getElementPosition('smoothing_span_label'), ...
        'String', 'Kernel:', 'HorizontalAlignment', 'left', 'Tag', 'smoothing_span_label');
    hSmoothSpanEdit = uicontrol(signalFig, 'Style', 'edit', ...
        'Position', getElementPosition('smoothing_span_edit'), ...
        'String', num2str(analysis_smooth_span), ...
        'Callback', @changeSmoothingSpan, 'Tag', 'smoothing_span_edit');
    
    uicontrol(signalFig, 'Style', 'text', 'Position', getElementPosition('smoothing_method_label'), ...
        'String', 'Method:', 'HorizontalAlignment', 'left', 'Tag', 'smoothing_method_label');
    smoothingMethodDisplay = {'Moving', 'Median'};
    hSmoothMethodPopup = uicontrol(signalFig, 'Style', 'popupmenu', ...
        'Position', getElementPosition('smoothing_method_popup'), ...
        'String', smoothingMethodDisplay, ...
        'Value', getSmoothingMethodIndex(analysis_smooth_method), ...
        'Callback', @changeSmoothingMethod, 'Tag', 'smoothing_method_popup');
    
    uicontrol(signalFig, 'Style', 'text', 'Position', getElementPosition('smoothing_show_raw_label'), ...
        'String', 'Show Raw:', 'HorizontalAlignment', 'left', 'Tag', 'smoothing_show_raw_label');
    hSmoothShowRawCheckbox = uicontrol(signalFig, 'Style', 'checkbox', ...
        'Position', getElementPosition('smoothing_show_raw_checkbox'), ...
        'Value', getShowRawFlag(), 'Callback', @toggleShowRawSignal, 'Tag', 'smoothing_show_raw_checkbox');
    updateSmoothingControls();
    
    % Выбор временного окна
    hTimeWindowText = uicontrol(signalFig, 'Style', 'text', ...
        'Position', getElementPosition('time_window_text'), ...
        'String', ['Time Window, ' selectedUnit ':'], ...
        'HorizontalAlignment', 'left', 'Tag', 'time_window_text');
    uicontrol(signalFig, 'Style', 'text', ...
        'Position', getElementPosition('before_text'), ...
        'String', 'before', 'HorizontalAlignment', 'left', 'Tag', 'before_text');
    hTimeBackEdit = uicontrol(signalFig, 'Style', 'edit', ...
        'Position', getElementPosition('time_back_edit'), ...
        'String', sprintf('%.3f', time_back * timeUnitFactor), ...
        'Callback', @timeBackEditCallback, 'Tag', 'time_back_edit');
    uicontrol(signalFig, 'Style', 'text', ...
        'Position', getElementPosition('after_text'), ...
        'String', 'after', 'HorizontalAlignment', 'left', 'Tag', 'after_text');
    hTimeForwardEdit = uicontrol(signalFig, 'Style', 'edit', ...
        'Position', getElementPosition('time_forward_edit'), ...
        'String', sprintf('%.3f', time_forward * timeUnitFactor), ...
        'Callback', @timeForwardEditCallback, 'Tag', 'time_forward_edit');
    
    % Разделитель навигации
    uicontrol(signalFig, 'Style', 'text', 'Position', getElementPosition('navigation_separator'), ...
        'String', '────── Navigation ──────', ...
        'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'Tag', 'navigation_separator');
    
    % Статус навигации
    hNavigationStatus = uicontrol(signalFig, 'Style', 'text', 'Position', getElementPosition('navigation_status'), ...
        'String', 'Mode: time', 'HorizontalAlignment', 'left', 'Tag', 'navigation_status');
    
    % Путь к папке с иконками
    assetsPath = getAssetsPath();
    
    % Кнопки навигации (сдвигаем вниз)
    hPrevBtn = uicontrol(signalFig, 'Style', 'pushbutton', 'String', '◀ Previous', ...
        'Position', getElementPosition('prev_btn'), 'Callback', @(~,~)shiftTimeSlope(-1), 'Tag', 'prev_btn');
    btnIcon(hPrevBtn, fullfile(assetsPath, 'previous_button.png'), false);
    
    hNextBtn = uicontrol(signalFig, 'Style', 'pushbutton', 'String', 'Next ▶', ...
        'Position', getElementPosition('next_btn'), 'Callback', @(~,~)shiftTimeSlope(1), 'Tag', 'next_btn');
    btnIcon(hNextBtn, fullfile(assetsPath, 'next_button.png'), false);
    
    % Кнопка автоматического измерения всех участков
    hAutoMeasureBtn = uicontrol(signalFig, 'Style', 'pushbutton', 'String', 'Auto Measure All', ...
        'Position', getElementPosition('auto_measure_btn'), 'Callback', @autoMeasureAllTimeRanges, 'Tag', 'auto_measure_btn');
    
    % Кнопка настроек удаления артефактов
    hSettingsButton = uicontrol(signalFig, 'Style', 'pushbutton', 'String', 'Settings', ...
        'Position', getElementPosition('settings_btn'), 'Callback', @(~,~)optionsRemovalArtifactsGUI(), 'Tag', 'settings_btn');
    btnIcon(hSettingsButton, fullfile(assetsPath, 'settings_btn.png'), false);
    
    % Кнопка открытия файла
    hOpenFileButton = uicontrol(signalFig, 'Style', 'pushbutton', 'String', 'Open File', ...
        'Position', getElementPosition('open_file_btn'), 'Callback', @openFile, 'Tag', 'open_file_btn');
    btnIcon(hOpenFileButton, fullfile(assetsPath, 'load_mat_file_btn.png'), false);
    
    % Кнопка File Manager (использует прежние координаты Load Events)
    hFileManagerButton = uicontrol(signalFig, 'Style', 'pushbutton', 'String', 'File Manager', ...
        'Position', getElementPosition('load_events_btn'), ...
        'Callback', @(~,~)fileManagerGUI(), 'Tag', 'load_events_btn');
    % Используем иконку из assets для единообразия с signalViewerGUI
    btnIcon(hFileManagerButton, fullfile(assetsPath, 'fm_button.png'), false);
    
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
    
    % Кнопки управления инструментами графика
    hZoomButton = uicontrol(signalFig, 'Style', 'pushbutton', 'String', 'Zoom', ...
        'Position', getElementPosition('zoom_btn'), 'Callback', @zoomButtonCallback, 'Tag', 'zoom_btn');
    btnIcon(hZoomButton, fullfile(assetsPath, 'zoom_btn.png'), false);
    
    hPanButton = uicontrol(signalFig, 'Style', 'pushbutton', 'String', 'Pan', ...
        'Position', getElementPosition('pan_btn'), 'Callback', @panButtonCallback, 'Tag', 'pan_btn');
    btnIcon(hPanButton, fullfile(assetsPath, 'pan_btn.png'), false);
    
    hCursorButton = uicontrol(signalFig, 'Style', 'pushbutton', 'String', 'Cursor', ...
        'Position', getElementPosition('cursor_btn'), 'Callback', @cursorButtonCallback, 'Tag', 'cursor_btn');
    btnIcon(hCursorButton, fullfile(assetsPath, 'cursor_btn.png'), false);
    
    hBrushButton = uicontrol(signalFig, 'Style', 'pushbutton', 'String', 'Brush', ...
        'Position', getElementPosition('brush_btn'), 'Callback', @brushButtonCallback, 'Tag', 'brush_btn');
    btnIcon(hBrushButton, fullfile(assetsPath, 'brush_btn.png'), false);
    
    hHomeButton = uicontrol(signalFig, 'Style', 'pushbutton', 'String', 'Home', ...
        'Position', getElementPosition('home_btn'), 'Callback', @homeButtonCallback, 'Tag', 'home_btn');
    btnIcon(hHomeButton, fullfile(assetsPath, 'home_btn.png'), false);

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
    
    % Кнопка сохранения результатов как новый файл
    uicontrol(signalFig, 'Style', 'pushbutton', 'String', 'Save As', ...
        'Position', getElementPosition('save_as_btn'), 'Callback', @saveResultsAs, 'Tag', 'save_as_btn');
    
    % Кнопка сохранения изображения
    uicontrol(signalFig, 'Style', 'pushbutton', 'String', 'Save Image', ...
        'Position', getElementPosition('save_image_btn'), 'Callback', @saveImage, 'Tag', 'save_image_btn');
    
    % Выпадающий список результатов из базы данных
    hResultsDropdown = uicontrol(signalFig, 'Style', 'popupmenu', ...
        'Position', getElementPosition('results_dropdown'), ...
        'String', {'No results found'}, ...
        'Callback', @resultsDropdownCallback, ...
        'Enable', 'off', ...
        'Tag', 'results_dropdown');
    setappdata(hResultsDropdown, 'meta_paths', {});
    
    % Чекбокс Hot Resave
    uicontrol(signalFig, 'Style', 'text', 'Position', getElementPosition('hot_resave_label'), ...
        'String', 'Hot Resave:', 'HorizontalAlignment', 'left', 'Tag', 'hot_resave_label');
    hHotResaveCheckbox = uicontrol(signalFig, 'Style', 'checkbox', ...
        'Position', getElementPosition('hot_resave_checkbox'), ...
        'String', '', ...
        'Callback', @hotResaveCallback, ...
        'Enable', 'off', ...
        'Value', 0, ...
        'Tag', 'hot_resave_checkbox');
    
    % Чекбокс Hot Resave
    uicontrol(signalFig, 'Style', 'text', 'Position', getElementPosition('hot_resave_label'), ...
        'String', 'Hot Resave:', 'HorizontalAlignment', 'left', 'Tag', 'hot_resave_label');
    hHotResaveCheckbox = uicontrol(signalFig, 'Style', 'checkbox', ...
        'Position', getElementPosition('hot_resave_checkbox'), ...
        'String', '', ...
        'Callback', @hotResaveCallback, ...
        'Enable', 'off', ...
        'Value', 0, ...
        'Tag', 'hot_resave_checkbox');

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
    
    original_ylim = [];    % исходные границы амплитуды для восстановления
    original_xlim = [];    % исходные границы времени для восстановления
    
    % Переменная для относительного сдвига времени
    rel_shift = 0;
    
    % Переменные для среднего сигнала
    mean_results_active = false;
    mean_signal_data = [];
    mean_signal_time = [];
    
    % Пытаемся автоматически открыть последний файл при запуске
    autoOpenLastFile();

    % Добавляем обработку клавиш для навигации
    set(signalFig, 'KeyPressFcn', @keyPressFunction);
    
    % Добавляем обработчик изменения размера окна для масштабирования элементов
    set(signalFig, 'SizeChangedFcn', @resizeSignalAnalysisWindow);
    
    % Добавляем обработчик закрытия окна для сохранения положения
    set(signalFig, 'CloseRequestFcn', @closeSignalAnalysisWindow);
    
    % Разворачиваем окно после создания всех элементов и установки обработчиков
    % SizeChangedFcn автоматически вызовет ResizeElements для правильного масштабирования
    signalFig.WindowState = 'maximized';
    
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
        if exist('hTimeBackEdit', 'var') && ishandle(hTimeBackEdit)
            set(hTimeBackEdit, 'String', sprintf('%.3f', time_back * timeUnitFactor));
        end
        if exist('hTimeForwardEdit', 'var') && ishandle(hTimeForwardEdit)
            set(hTimeForwardEdit, 'String', sprintf('%.3f', time_forward * timeUnitFactor));
        end
        if exist('hTimeWindowText', 'var') && ishandle(hTimeWindowText)
            set(hTimeWindowText, 'String', ['Time Window, ' selectedUnit ':']);
        end
    end
    
    function channelCallback(src, ~)
        slope_measurement_settings.channel = get(src, 'Value');
        
        % Сохраняем выбранный канал в глобальные настройки
        try
            analysis_selected_channel = slope_measurement_settings.channel;
            if exist(SettingsFilepath, 'file')
                save(SettingsFilepath, 'analysis_selected_channel', '-append');
            else
                save(SettingsFilepath, 'analysis_selected_channel');
            end
        catch
            % Игнорируем ошибки сохранения
        end
        
        % Вычисляем и применяем оптимальные границы осей
        [optimal_xlim, optimal_ylim] = calculateOptimalAxisLimits(true);
        
        % Сохраняем как original для правильной работы зума
        original_xlim = optimal_xlim;
        original_ylim = optimal_ylim;
        
        % Обновляем график
        updatePlotAndCalculation();
        
        debugState('channelCallback', '✓ Channel changed, optimal axis sizes applied');
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
    
    function addMagnetButton(editHandle, unitHandle, tagName, callbackHandle)
        if ~ishandle(editHandle)
            return;
        end
        editPos = get(editHandle, 'Position');
        spacing = 5;
        buttonWidth = min(editPos(4), 22);
        buttonPos = [editPos(1) + editPos(3) + spacing, editPos(2), buttonWidth, editPos(4)];
        magnetBtn = uicontrol(signalFig, ...
            'Style', 'pushbutton', ...
            'String', '★', ...
            'Position', buttonPos, ...
            'Tag', tagName, ...
            'Callback', @(~, ~)magnetPickTime(editHandle, callbackHandle), ...
            'TooltipString', 'Выбрать точку на графике');
        if nargin >= 2 && ~isempty(unitHandle) && ishandle(unitHandle)
            unitPos = get(unitHandle, 'Position');
            unitPos(1) = buttonPos(1) + buttonPos(3) + spacing;
            set(unitHandle, 'Position', unitPos);
        end
        registerMagnetButton(magnetBtn, editHandle, unitHandle, spacing, buttonWidth);
    end
    
    function registerMagnetButton(buttonHandle, editHandle, unitHandle, spacingPx, buttonWidthPx)
        if ~ishandle(signalFig) || ~ishandle(buttonHandle) || ~ishandle(editHandle)
            return;
        end
        editPos = get(editHandle, 'Position');
        editHeight = max(editPos(4), 1);
        magnetButtons = getappdata(signalFig, 'magnetButtons');
        info = struct(...
            'button', buttonHandle, ...
            'edit', editHandle, ...
            'unit', unitHandle, ...
            'spacingRatio', spacingPx / editHeight, ...
            'widthRatio', buttonWidthPx / editHeight);
        if isempty(magnetButtons)
            magnetButtons = info;
        else
            magnetButtons = [magnetButtons, info];
        end
        setappdata(signalFig, 'magnetButtons', magnetButtons);
    end
    
    function updateMagnetButtonPositions()
        if ~ishandle(signalFig)
            return;
        end
        magnetButtons = getappdata(signalFig, 'magnetButtons');
        if isempty(magnetButtons)
            return;
        end
        keepMask = true(1, numel(magnetButtons));
        for idx = 1:numel(magnetButtons)
            entry = magnetButtons(idx);
            if ~ishandle(entry.button) || ~ishandle(entry.edit)
                keepMask(idx) = false;
                continue;
            end
            applyMagnetLayout(entry);
        end
        magnetButtons = magnetButtons(keepMask);
        setappdata(signalFig, 'magnetButtons', magnetButtons);
    end
    
    function applyMagnetLayout(entry)
        editPos = get(entry.edit, 'Position');
        editHeight = editPos(4);
        if editHeight <= 0
            return;
        end
        spacing = entry.spacingRatio * editHeight;
        buttonWidth = entry.widthRatio * editHeight;
        buttonPos = [editPos(1) + editPos(3) + spacing, editPos(2), buttonWidth, editHeight];
        set(entry.button, 'Position', buttonPos);
        if isfield(entry, 'unit') && ~isempty(entry.unit) && ishandle(entry.unit)
            unitPos = get(entry.unit, 'Position');
            unitPos(1) = buttonPos(1) + buttonPos(3) + spacing;
            set(entry.unit, 'Position', unitPos);
        end
    end
    
    function magnetPickTime(targetEditHandle, callbackHandle)
        if ~ishandle(hPlotAxes) || strcmp(get(hPlotAxes, 'Visible'), 'off')
            debugState('magnetPickTime', '❌ Сначала загрузите данные для анализа');
            return;
        end
        figure(signalFig);
        axes(hPlotAxes);
        try
            [x, ~] = ginput(1);
        catch
            debugState('magnetPickTime', '❌ Выбор точки отменен');
            return;
        end
        if isempty(x) || ~isfinite(x)
            debugState('magnetPickTime', '❌ Выбор точки отменен');
            return;
        end
        set(targetEditHandle, 'String', sprintf('%.3f', x));
        callbackHandle(targetEditHandle, []);
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
    
    function toggleSmoothing(src, ~)
        analysis_smooth_enabled = logical(get(src, 'Value'));
        saveSmoothingSettings();
        updatePlotAndCalculation();
    end
    
    function changeSmoothingSpan(src, ~)
        new_span = round(str2double(get(src, 'String')));
        if isnan(new_span) || ~isfinite(new_span)
            set(src, 'String', num2str(analysis_smooth_span));
            return;
        end
        analysis_smooth_span = new_span;
        set(src, 'String', num2str(analysis_smooth_span));
        saveSmoothingSettings();
        updatePlotAndCalculation();
    end
    
    function changeSmoothingMethod(src, ~)
        methods = {'moving', 'median'};
        selection = get(src, 'Value');
        selection = max(1, min(numel(methods), selection));
        analysis_smooth_method = methods{selection};
        saveSmoothingSettings();
        updatePlotAndCalculation();
    end
    
    function timeBackEditCallback(src, ~)
        new_before = str2double(get(src, 'String')) / timeUnitFactor;
        if isnan(new_before) || new_before < 0
            set(src, 'String', sprintf('%.3f', time_back * timeUnitFactor));
            return;
        end
        time_back = new_before;
        refreshRelShift();
        [original_xlim, original_ylim] = calculateOptimalAxisLimits(true);
        saveChannelSettings('time_back');
        updateNavigationStatus();
        updateCursorEditFields();
        updatePlotAndCalculation();
    end
    
    function timeForwardEditCallback(src, ~)
        new_after = str2double(get(src, 'String')) / timeUnitFactor;
        if isnan(new_after) || new_after <= 0
            set(src, 'String', sprintf('%.3f', time_forward * timeUnitFactor));
            return;
        end
        time_forward = new_after;
        refreshRelShift();
        [original_xlim, original_ylim] = calculateOptimalAxisLimits(true);
        saveChannelSettings('time_forward');
        updateNavigationStatus();
        updateCursorEditFields();
        updatePlotAndCalculation();
    end
    
    function toggleShowRawSignal(src, ~)
        flag = logical(get(src, 'Value'));
        setappdata(signalFig, 'analysis_show_raw_signal', flag);
        saveSmoothingSettings();
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
    
    function method_index = getSmoothingMethodIndex(method_name)
        methods = {'moving', 'median'};
        idx = find(strcmp(methods, method_name), 1);
        if isempty(idx)
            method_index = 1;
        else
            method_index = idx;
        end
    end
    
    function flag = getShowRawFlag()
        flag = false;
        if ishandle(signalFig)
            val = getappdata(signalFig, 'analysis_show_raw_signal');
            if ~isempty(val)
                flag = logical(val);
            end
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
        
        [display_channel_data, display_time_in] = getCurrentData();
        channel_data = display_channel_data;
        time_in = display_time_in;
        
        if mean_results_active && ~isempty(mean_signal_data) && ~isempty(mean_signal_time)
            calc_channel_data = display_channel_data;
            calc_time_in = display_time_in;
        else
            calc_interval = getMeasurementInterval(slope_measurement_settings.baseline_start, ...
                slope_measurement_settings.baseline_end, ...
                slope_measurement_settings.peak_start, ...
                slope_measurement_settings.peak_end, ...
                chosen_time_interval, time_back, time_forward, time);
            [calc_channel_data, calc_time_in] = getCurrentData(calc_interval);
        end
        
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
            time_in_rel = calc_time_in;
        else
            % В обычном режиме используем абсолютные координаты с вычитанием rel_shift
            baseline_data_struct.baseline_start = baseline_start - rel_shift;
            baseline_data_struct.baseline_end = baseline_end - rel_shift;
            baseline_data_struct.peak_start = peak_start - rel_shift;
            baseline_data_struct.peak_end = peak_end - rel_shift;
            time_in_rel = calc_time_in - rel_shift;
        end
        
        baseline_data_struct.slope_percent = slope_percent;
        baseline_data_struct.peak_polarity = peak_polarity;
        
        % Расчет slope с использованием calculateMeasurementByType
        
        [slope_value, measurement_metadata] = calculateMeasurementByType(calc_channel_data, time_in_rel, ...
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
        
        if analysis_smooth_enabled && ~mean_results_active && getShowRawFlag()
            raw_data = getappdata(hPlotAxes, 'analysis_raw_data');
            if ~isempty(raw_data)
                plot(time_display, raw_data, 'Color', [0.6 0.6 0.6], ...
                    'LineWidth', 0.75, 'LineStyle', '--');
            end
        end
        
        plot(time_display, channel_data, 'LineWidth', 1, ...
            'Color', colorsIn{slope_measurement_settings.channel});
        
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
            hBaselineLines(1) = xline(t_bl_start, 'Color', 'b', 'LineWidth', 2, 'LineStyle', ':');
            hBaselineLines(2) = xline(t_bl_end, 'Color', 'b', 'LineWidth', 2, 'LineStyle', ':');
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
            hPeakLines(1) = xline(t_pk_start, 'Color', 'g', 'LineWidth', 2, 'LineStyle', ':');
            hPeakLines(2) = xline(t_pk_end, 'Color', 'g', 'LineWidth', 2, 'LineStyle', ':');
            
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
    
    function updateSmoothingControls()
        if exist('hSmoothEnableCheckbox', 'var') && ~isempty(hSmoothEnableCheckbox) && ishandle(hSmoothEnableCheckbox)
            set(hSmoothEnableCheckbox, 'Value', analysis_smooth_enabled);
        end
        if exist('hSmoothSpanEdit', 'var') && ~isempty(hSmoothSpanEdit) && ishandle(hSmoothSpanEdit)
            set(hSmoothSpanEdit, 'String', num2str(analysis_smooth_span));
        end
        if exist('hSmoothMethodPopup', 'var') && ~isempty(hSmoothMethodPopup) && ishandle(hSmoothMethodPopup)
            set(hSmoothMethodPopup, 'Value', getSmoothingMethodIndex(analysis_smooth_method));
        end
        if exist('hSmoothShowRawCheckbox', 'var') && ~isempty(hSmoothShowRawCheckbox) && all(ishandle(hSmoothShowRawCheckbox))
            set(hSmoothShowRawCheckbox, 'Value', getShowRawFlag());
        end
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
        
        % Hot Resave - автоматическое сохранение при завершении перетаскивания курсоров
        if hot_resave_enabled && ...
           ~isempty(selected_row_slope) && ...
           selected_row_slope <= length(slope_measurement_results) && ...
           ~isempty(current_loaded_excel_path) && ...
           exist(current_loaded_excel_path, 'file')
            
            % Автоматический Replace (без обновления UI)
            replaceResultSilent();
            
            % Автоматическое сохранение поверх (без диалогов)
            doSaveResults(current_loaded_excel_path, true);
            
            % Обновляем таблицу чтобы пользователь видел изменения
            updateResultsTable();
        end
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
            
            % Сохраняем активный канал
            loadedSettings.analysis_selected_channel = slope_measurement_settings.channel;
            
            % Сохраняем обновленные настройки
            % Используем -append чтобы не перезаписывать существующие настройки
            if exist(SettingsFilepath, 'file')
                save(SettingsFilepath, '-struct', 'loadedSettings', 'cursor_positions', 'analysis_selected_channel', '-append');
            else
                save(SettingsFilepath, '-struct', 'loadedSettings', 'cursor_positions', 'analysis_selected_channel');
            end
            
    
            
        catch ME
    
        end
    end
    
    function updateLinePositions()
        % Обновляет только позиции линий без пересчета параметров
        
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
                set(hBaselineLines(1), 'Value', t_bl_start);
            end
            if ishandle(hBaselineLines(2))
                set(hBaselineLines(2), 'Value', t_bl_end);
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
                set(hPeakLines(1), 'Value', t_pk_start);
            end
            if ishandle(hPeakLines(2))
                set(hPeakLines(2), 'Value', t_pk_end);
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

        % устанавливаем оптимальные границы осей
        [original_xlim, original_ylim] = calculateOptimalAxisLimits(true);

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
    
    function refreshRelShift()
        if strcmp(selectedCenter, 'stimulus') && stims_exist && ~isempty(stims)
            rel_shift = stims(stim_inx);
        else
            rel_shift = chosen_time_interval(1);
        end
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
    
    function zoomButtonCallback(src, ~)
        % Активация встроенного zoom
        zoom(signalFig, 'off');
        pan(signalFig, 'off');
        datacursormode(signalFig, 'off');
        brush(signalFig, 'off');
        zoom(signalFig, 'on');
        zoom(hPlotAxes, 'on');
        debugState('zoomButtonCallback', 'Built-in zoom activated');
    end

    function panButtonCallback(src, ~)
        % Активация встроенного pan
        zoom(signalFig, 'off');
        pan(signalFig, 'off');
        datacursormode(signalFig, 'off');
        brush(signalFig, 'off');
        pan(signalFig, 'on');
        pan(hPlotAxes, 'on');
        debugState('panButtonCallback', 'Built-in pan activated');
    end

    function cursorButtonCallback(src, ~)
        % Активация встроенного data cursor
        zoom(signalFig, 'off');
        pan(signalFig, 'off');
        datacursormode(signalFig, 'off');
        brush(signalFig, 'off');
        datacursormode(signalFig, 'on');
        debugState('cursorButtonCallback', 'Data cursor activated');
    end

    function brushButtonCallback(src, ~)
        % Активация встроенного brush
        zoom(signalFig, 'off');
        pan(signalFig, 'off');
        datacursormode(signalFig, 'off');
        brush(signalFig, 'off');
        brush(signalFig, 'on');
        brush(hPlotAxes, 'on');
        debugState('brushButtonCallback', 'Built-in brush activated');
    end

    function homeButtonCallback(src, ~)
        % Сброс всех инструментов и восстановление исходного вида графика
        zoom(signalFig, 'off');
        pan(signalFig, 'off');
        datacursormode(signalFig, 'off');
        brush(signalFig, 'off');
        applyAutoscale();
        debugState('homeButtonCallback', 'All tools reset, view restored');
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
        
        % Сохраняем настройки сглаживания
        metadata.analysis_smooth_enabled = analysis_smooth_enabled;
        metadata.analysis_smooth_span = analysis_smooth_span;
        metadata.analysis_smooth_method = analysis_smooth_method;
        metadata.analysis_show_raw_signal = getShowRawFlag();
        
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
        
        debugState('addResult', '✓ Result added to table (total: %d)', length(slope_measurement_results));
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
        
        % Сохраняем настройки сглаживания
        metadata.analysis_smooth_enabled = analysis_smooth_enabled;
        metadata.analysis_smooth_span = analysis_smooth_span;
        metadata.analysis_smooth_method = analysis_smooth_method;
        metadata.analysis_show_raw_signal = getShowRawFlag();
        
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
                debugState('removeResult', 'DEBUG: Сохранены позиции - vpos: %d, hpos: %d', saved_vpos, saved_hpos);
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
        
        debugState('removeResult', '✓ Result #%d removed from table', selected_row_slope);
        
        % Оставляем selected_row_slope без изменений для сохранения выделения
            
        else
            % Fallback: если нет выделенной строки, удаляем последний результат
            if ~isempty(slope_measurement_results)
                last_index = length(slope_measurement_results);
                slope_measurement_results(last_index) = [];
                
                % Обновляем таблицу
                updateResultsTable();
                
                debugState('removeResult', '✓ Last result #%d removed from table', last_index);
            else
                debugState('removeResult', '❌ No results to delete');
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
    
    function replaceResultSilent()
        % Заменяет выбранный результат текущим измерением БЕЗ обновления UI
        % Используется для Hot Resave
        
        if isempty(selected_row_slope) || selected_row_slope > length(slope_measurement_results)
            return;
        end
        
        % Проверяем, что у нас есть текущие результаты
        if ~exist('slope_value', 'var') || isnan(slope_value)
            return;
        end
        
        % Используем глобальные метаданные если они есть, иначе создаем новые
        if ~isempty(current_measurement_metadata)
            metadata = current_measurement_metadata;
        else
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
        
        % Сохраняем настройки сглаживания
        metadata.analysis_smooth_enabled = analysis_smooth_enabled;
        metadata.analysis_smooth_span = analysis_smooth_span;
        metadata.analysis_smooth_method = analysis_smooth_method;
        metadata.analysis_show_raw_signal = getShowRawFlag();
        
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

        % Заменяем выбранный результат (без обновления UI)
        slope_measurement_results(selected_row_slope) = new_result;
    end
    
    function replaceResult(~, ~)
        % Заменяет выбранный результат текущим измерением
        
        if isempty(selected_row_slope) || selected_row_slope > length(slope_measurement_results)
            debugState('replaceResult', '❌ No selected result to replace');
            return;
        end
        
        % Проверяем, что у нас есть текущие результаты
        if ~exist('slope_value', 'var') || isnan(slope_value)
            debugState('replaceResult', '❌ No current results to replace');
            return;
        end
        
        % Используем replaceResultSilent для замены
        replaceResultSilent();
        
        % Сохраняем позицию прокрутки перед обновлением таблицы
        global saved_vpos saved_hpos;
        try
            jTable = findjobj(hResultsTable);
            % UIScrollPane уже содержит методы прокрутки
                saved_vpos = jTable.getVerticalScrollBar.getValue();
                saved_hpos = jTable.getHorizontalScrollBar.getValue();
                debugState('replaceResult', 'DEBUG: Сохранены позиции - vpos: %d, hpos: %d', saved_vpos, saved_hpos);
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
        
        debugState('replaceResult', '✓ Result #%d replaced with current measurement', selected_row_slope);
        
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
    
    function doSaveResults(excel_path, is_overwrite)
        % Общая функция сохранения результатов
        % excel_path - путь к Excel файлу
        % is_overwrite - флаг, сохраняем ли поверх существующего файла
        
        try
            % Создаем структуру params из slope_measurement_settings для сохранения
            params = struct();
            if ~isempty(slope_measurement_settings)
                params.channel = slope_measurement_settings.channel;
                params.baseline_start = slope_measurement_settings.baseline_start;
                params.baseline_end = slope_measurement_settings.baseline_end;
                params.peak_start = slope_measurement_settings.peak_start;
                params.peak_end = slope_measurement_settings.peak_end;
                params.slope_percent = slope_measurement_settings.slope_percent;
                params.peak_polarity = slope_measurement_settings.peak_polarity;
                if isfield(slope_measurement_settings, 'onset_method')
                    params.onset_method = slope_measurement_settings.onset_method;
                end
                if isfield(slope_measurement_settings, 'onset_threshold')
                    params.onset_threshold = slope_measurement_settings.onset_threshold;
                end
            end
            
            % Используем общую функцию сохранения
            result_info = saveSlopeMeasurementResults(slope_measurement_results, excel_path, timeUnitFactor, matFilePath, matFileName, params);
            
            if result_info.success
                debugState('doSaveResults', '✓ Results saved:');
                debugState('doSaveResults', '  Excel: %s', result_info.excel_path);
                if isfield(result_info, 'meta_path')
                    debugState('doSaveResults', '  Metadata: %s', result_info.meta_path);
                end
                debugState('doSaveResults', '  Total records: %d', length(slope_measurement_results));
                
                % Сохраняем путь к Excel файлу для возможности сохранения поверх в будущем
                current_loaded_excel_path = result_info.excel_path;
                
                % Сохраняем результат анализа в базу данных только если это новый файл
                if ~is_overwrite && ~isempty(matFilePath)
                    result = struct( ...
                        'module_name', 'signalAnalysis', ...
                        'module_display_name', 'Signal Analysis', ...
                        'module_description', 'Анализ сигнала с измерениями slope, peak, onset', ...
                        'report_path', result_info.excel_path, ...
                        'parameters', struct('total_records', length(slope_measurement_results)));
                    if isfield(result_info, 'meta_path')
                        result.parameters.meta_path = result_info.meta_path;
                    end
                    logAnalysisResult(matFilePath, result);
                    debugState('doSaveResults', '  Analysis result saved to database');
                else
                    debugState('doSaveResults', '  Skipping database update (overwrite mode)');
                end
                
                % Обновляем список результатов в выпадающем списке
                updateResultsDropdown();
                
                % Обновляем состояние чекбокса Hot Resave (может стать активным после сохранения)
                updateHotResaveState();
            else
                debugState('doSaveResults', '❌ Error saving results');
                if isfield(result_info, 'error')
                    debugState('doSaveResults', '  Error: %s', result_info.error);
                end
            end
            
        catch ME
            debugState('doSaveResults', '❌ Error saving: %s', ME.message);
            rethrow(ME);
        end
    end
    
    function saveResults(~, ~)
        % Сохраняет результаты поверх загруженного файла (если есть) или показывает диалог
        
        if isempty(slope_measurement_results)
            debugState('saveResults', '❌ No results to save');
            return;
        end
        
        % Проверяем, есть ли загруженный Excel путь
        if ~isempty(current_loaded_excel_path) && exist(current_loaded_excel_path, 'file')
            % Показываем диалог подтверждения
            choice = questdlg(...
                sprintf('Overwrite existing file?\n\nThis will replace both Excel and metadata files:\n%s', current_loaded_excel_path), ...
                'Confirm Overwrite', ...
                'Yes', 'No', 'Cancel', 'Cancel');
            
            switch choice
                case 'Yes'
                    % Сохраняем поверх существующего файла
                    doSaveResults(current_loaded_excel_path, true);
                case 'No'
                    % Показываем диалог выбора файла (как Save As)
                    saveResultsAs([], []);
                case 'Cancel'
                    debugState('saveResults', '❌ Save cancelled by user');
                    return;
            end
        else
            % Нет загруженного файла - показываем диалог выбора файла
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
                debugState('saveResults', '❌ Save cancelled');
                return;
            end
            
            % Получаем базовое имя файла без расширения
            excel_path = fullfile(pathname, filename);
            
            % Сохраняем как новый файл
            doSaveResults(excel_path, false);
        end
    end
    
    function saveResultsAs(~, ~)
        % Сохраняет результаты в новый файл (всегда показывает диалог выбора файла)
        
        if isempty(slope_measurement_results)
            debugState('saveResultsAs', '❌ No results to save');
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
            debugState('saveResultsAs', '❌ Save cancelled');
            return;
        end
        
        % Получаем базовое имя файла без расширения
        excel_path = fullfile(pathname, filename);
        
        % Сохраняем как новый файл
        doSaveResults(excel_path, false);
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
            table_data{i, 13} = getNavigationStatusTextLocal(metadata);
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
            debugState('updateResultsTable', 'DEBUG: jTable тип: %s', class(jTable));
            
            % Проверяем доступные методы UIScrollPane
            debugState('updateResultsTable', 'DEBUG: Проверяем методы UIScrollPane');
            
            % Восстанавливаем позицию прокрутки через viewport
            if exist('saved_vpos', 'var') && ~isempty(saved_vpos)
                debugState('updateResultsTable', 'DEBUG: Восстанавливаем vpos: %d', saved_vpos);
                
                try
                    viewport = jTable.getViewport();
                    viewport.setViewPosition(java.awt.Point(0, saved_vpos));
                    % fprintf('DEBUG: ✓ Способ 2 (viewport) применен\n');
                catch ME
                    debugState('updateResultsTable', 'DEBUG: ✗ Способ 2 не сработал: %s', ME.message);
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
            debugState('updateResultsTable', 'DEBUG: Ошибка при восстановлении позиции: %s', ME.message);
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
        




        % Вычисляем разность времени пика и онсета для всех результатов
        peak_onset_diff_values = ([slope_measurement_results.peak_time] - [slope_measurement_results.onset_time]) * timeUnitFactor;
        
        % Вычисляем средние значения
        avg_slope = mean(slope_values, 'omitnan');
        avg_peak_time_rel = mean(peak_time_rel_values, 'omitnan');
        avg_peak_amplitude = mean(peak_amplitude_values, 'omitnan');
        avg_onset_time_rel = mean(onset_time_rel_values, 'omitnan');
        avg_baseline = mean(baseline_values, 'omitnan');
        avg_peak_onset_diff = mean(peak_onset_diff_values, 'omitnan');
        
        set(hAverageTable, 'Data', {avg_slope, avg_peak_time_rel, avg_peak_amplitude, avg_onset_time_rel, avg_baseline, avg_peak_onset_diff});
    end
    
    function tableSelectionChanged(~, event)
        % Обработчик изменения выделения в таблице
        
        if isempty(event.Indices)
            selected_row_slope = [];
            updateReplaceButtonState();
            updateHotResaveState();
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
            
            % Обновляем состояние чекбокса Hot Resave
            updateHotResaveState();
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
        
        % Восстанавливаем настройки сглаживания если они есть
        if isfield(metadata, 'analysis_smooth_enabled')
            analysis_smooth_enabled = logical(metadata.analysis_smooth_enabled);
        end
        if isfield(metadata, 'analysis_smooth_span')
            analysis_smooth_span = metadata.analysis_smooth_span;
        end
        if isfield(metadata, 'analysis_smooth_method')
            analysis_smooth_method = metadata.analysis_smooth_method;
        end
        if isfield(metadata, 'analysis_show_raw_signal')
            setappdata(signalFig, 'analysis_show_raw_signal', logical(metadata.analysis_show_raw_signal));
        end
        
        % Обновляем UI элементы сглаживания
        updateSmoothingControls();
        
        % Обновляем видимость поля порога
        % updateOnsetThresholdVisibility();
        
        % Актуализируем rel_shift перед обновлением
        refreshRelShift();
        
        % Обновляем edit fields с относительным временем
        updateCursorEditFields();
        
        % Обновляем график ПЕРВЫМ (чтобы данные были актуальные)
        updatePlotAndCalculation();
        
        % Применяем автоскейлинг (как если бы пользователь нажал кнопку Autoscale)
        applyAutoscale();
        
        % Сохраняем позиции курсоров в память после восстановления состояния
        saveCurrentMarkerPositions();
        
        % Принудительно обновляем интерфейс перед сбросом флага
        drawnow;
                
        % Сбрасываем флаг восстановления ПОСЛЕ всех обновлений
        restoring_from_metadata = false;
        
        debugState('restoreStateFromMetadata', '✓ State restored from result #%d', row_index);
    end
    
    function status_text = getNavigationStatusTextLocal(metadata)
        % Возвращает текст статуса навигации (аналогично updateNavigationStatus)
        % Использует функцию из functions/getNavigationStatusText.m
        status_text = getNavigationStatusText(metadata);
    end
    
    function toggleMeanResults(~, ~)
        % Переключает режим просмотра среднего сигнала
        
        if isempty(slope_measurement_results)
            debugState('toggleMeanResults', '❌ No results for averaging');
            return;
        end
        
        mean_results_active = ~mean_results_active;
        
        if mean_results_active
            % Вычисляем средний сигнал
            [mean_signal_data, mean_signal_time] = calculateMeanSignal();
            set(hMeanResultsBtn, 'String', 'Show Single');
            debugState('toggleMeanResults', '✓ Average signal mode enabled (%d results)', length(slope_measurement_results));
            % вычисляем границы осей
            [optimal_xlim, optimal_ylim] = calculateOptimalAxisLimits(true);
        else
            % Сбрасываем средний сигнал
            mean_signal_data = [];
            mean_signal_time = [];
            set(hMeanResultsBtn, 'String', 'Av. Trace');
            debugState('toggleMeanResults', '✓ Single signal mode enabled');
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
    


    function [channel_data, time_in] = getCurrentData(custom_interval)
        % Получает текущие данные для измерений
        
        % Проверяем, нужно ли использовать средний сигнал
        if mean_results_active && ~isempty(mean_signal_data) && ~isempty(mean_signal_time)
            % Используем средний сигнал
            channel_data = mean_signal_data;
            time_in = mean_signal_time;
            
            if analysis_smooth_enabled && analysis_smooth_span >= 5
                channel_data = smooth1(channel_data(:), analysis_smooth_span, analysis_smooth_method);
            end
        else
            if nargin < 1 || isempty(custom_interval)
                data_interval = chosen_time_interval;
                data_interval(1) = data_interval(1) - time_back;
                data_interval(2) = chosen_time_interval(1) + time_forward;
                store_raw_data = true;
            else
                data_interval = custom_interval;
                store_raw_data = false;
            end
            
            cond = time >= data_interval(1) & time < data_interval(2);
            if ~any(cond)
                channel_data = [];
                time_in = [];
                return;
            end
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
        
            raw_channel_data = channel_data;
            
            if analysis_smooth_enabled && analysis_smooth_span >= 5
                channel_data = smooth1(channel_data(:), analysis_smooth_span, analysis_smooth_method);
            end
            
            if store_raw_data
                setappdata(hPlotAxes, 'analysis_raw_data', raw_channel_data);
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
                    debugState('autoMeasureAllTimeRanges', '✓ Table cleared before automatic measurement');
                    
                case 'No'
                    % Продолжаем с существующими результатами
                    debugState('autoMeasureAllTimeRanges', '✓ Automatic measurement will be added to existing results');
                    
                case 'Cancel'
                    % Отменяем операцию
                    debugState('autoMeasureAllTimeRanges', '❌ Automatic measurement cancelled by user');
                    return;
                    
                otherwise
                    % Пользователь закрыл диалог
                    debugState('autoMeasureAllTimeRanges', '❌ Automatic measurement cancelled');
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
                    debugState('autoMeasureAllTimeRanges', 'Automatic measurement of %d stimuli...', total_ranges);
                else
                    debugState('autoMeasureAllTimeRanges', 'ERROR: No stimuli for measurement');
                    return;
                end
                
            case 'sweep'
                if isstruct(sweep_info) && sweep_info.is_sweep_data
                    total_ranges = sweep_info.sweep_count;
                    debugState('autoMeasureAllTimeRanges', 'Automatic measurement of %d sweeps...', total_ranges);
                else
                    debugState('autoMeasureAllTimeRanges', 'ERROR: No sweep data for measurement');
                    return;
                end
                
            case 'time'
                % Для режима time вычисляем количество возможных шагов
                windowSize = chosen_time_interval(2) - chosen_time_interval(1);
                if windowSize <= 0
                    debugState('autoMeasureAllTimeRanges', 'ERROR: Invalid time window size');
                    return;
                end
                total_ranges = floor((time(end) - time(1)) / windowSize);
                if total_ranges <= 0
                    debugState('autoMeasureAllTimeRanges', 'ERROR: Insufficient data for measurement');
                    return;
                end
                debugState('autoMeasureAllTimeRanges', 'Automatic measurement of %d time segments...', total_ranges);
                
            otherwise
                debugState('autoMeasureAllTimeRanges', 'ERROR: Unsupported navigation mode');
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
                    debugState('autoMeasureAllTimeRanges', '❌ Automatic measurement cancelled by user');
                    break;
                end
                
                % Обновляем прогресс
                progress = i / total_ranges;
                percent = round(progress * 100);
                current_message = sprintf('Measuring segment %d of %d (%d%%)', i, total_ranges, percent);
                waitbar(progress, hWaitBar, current_message);
                
                debugState('autoMeasureAllTimeRanges', 'Measuring segment %d/%d...', i, total_ranges);
                
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
                    debugState('autoMeasureAllTimeRanges', 'Progress: %d/%d', i, total_ranges);
                end
            end
            
            % Проверяем, была ли отмена
            if ~ishandle(hWaitBar)
                debugState('autoMeasureAllTimeRanges', '❌ Автоматическое измерение отменено пользователем');
            else
                debugState('autoMeasureAllTimeRanges', 'SUCCESS: Automatic measurement completed! Added %d results', total_ranges);
            end
            
            % Принудительно закрываем окно прогресса после завершения цикла
            if exist('hWaitBar', 'var') && ishandle(hWaitBar)
                close(hWaitBar);
                debugState('autoMeasureAllTimeRanges', '✓ Progress window closed after completion');
            end
            
        catch ME
            % Закрываем окно прогресса при ошибке
            if exist('hWaitBar', 'var') && ishandle(hWaitBar)
                close(hWaitBar);
                debugState('autoMeasureAllTimeRanges', '✓ Progress window closed on error');
            end
            
            % Сбрасываем флаг автоанализа
            auto_analysis_mode = false;
            
            % Показываем ошибку пользователю
            debugState('autoMeasureAllTimeRanges', 'Error in auto-analysis: %s', ME.message);
            debugState('autoMeasureAllTimeRanges', '❌ Error in auto-analysis: %s', ME.message);
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
            debugState('autoMeasureAllTimeRanges', '✓ Progress window closed');
        end
        
        % ФИНАЛЬНОЕ обновление всех таблиц и графика
        updateResultsTable();
        updatePlotAndCalculation();
        
        % Обновляем статус навигации
        updateNavigationStatus();
        
        % Обновляем состояние кнопки Replace
        updateReplaceButtonState();
    end
    
    function loadResults(~, ~, directPath)
        % Загружает результаты и измерения из .meta файла
        % Если передан directPath, использует его вместо диалога выбора файла
        
        if nargin >= 3 && ~isempty(directPath) && ischar(directPath)
            % Используем прямой путь к файлу
            filepath = directPath;
        else
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
                debugState('loadResults', '❌ Loading cancelled');
                return;
            end
            
            filepath = fullfile(pathname, filename);
        end
        
        try
            % Загружаем данные из файла (фактически .mat файл с расширением .meta)
            loaded_data = load(filepath, '-mat');
            
            % Проверяем, нужно ли загружать оригинальный файл
            if isfield(loaded_data, 'original_file_info') && ~isempty(loaded_data.original_file_info.matFileName)
                if ~strcmp(loaded_data.original_file_info.matFileName, matFileName)
                    % Имена файлов не совпадают, загружаем оригинальный файл
                    debugState('loadResults', '📁 Loading original file: %s', loaded_data.original_file_info.matFilePath);
                    OpenFilePath(loaded_data.original_file_info.matFilePath);
                else
                    debugState('loadResults', 'ℹ️ Original file already loaded: %s', matFileName);
                end
            end
            
            % Загружаем основные результаты
            slope_measurement_results = loaded_data.slope_measurement_results;
            
            % Проверяем и обновляем старые метаданные
            debugState('loadResults', 'Checking and updating old metadata...');
            for i = 1:length(slope_measurement_results)
                % Проверяем наличие поля stim_inx
                if ~isfield(slope_measurement_results(i).metadata, 'stim_inx')
                    % Для старых метаданных пробуем получить номер стимула из индекса
                    if strcmp(slope_measurement_results(i).metadata.selectedCenter, 'stimulus') && stims_exist && ~isempty(stims)
                        slope_measurement_results(i).metadata.stim_inx = i;
                        debugState('loadResults', '  Result #%d: added stimulus number %d', i, i);
                    else
                        slope_measurement_results(i).metadata.stim_inx = NaN;
                        debugState('loadResults', '  Result #%d: stimulus number not determined', i);
                    end
                end
                
                % Проверяем наличие полей для peak_onset_diff
                if ~isfield(slope_measurement_results(i), 'onset_time')
                    slope_measurement_results(i).onset_time = NaN;
                    debugState('loadResults', '  Result #%d: added onset_time field', i);
                end
                if ~isfield(slope_measurement_results(i), 'onset_value')
                    slope_measurement_results(i).onset_value = NaN;
                    debugState('loadResults', '  Result #%d: added onset_value field', i);
                end
            end
            debugState('loadResults', 'Metadata update completed');

            % Сбрасываем выделения
            selected_row_slope = [];
            selected_measurement_row = [];
            
            % Обновляем отображение
            updateResultsTable();
            
            debugState('loadResults', '✓ Results loaded from file:');
            debugState('loadResults', '  File: %s', filepath);
            debugState('loadResults', '  Results: %d', length(slope_measurement_results));
            
            % Сохраняем путь к Excel файлу для возможности сохранения поверх
            % Восстанавливаем Excel путь из .meta пути (заменяем расширение)
            [path, name, ~] = fileparts(filepath);
            current_loaded_excel_path = fullfile(path, [name, '.xlsx']);
            
            % Проверяем существование Excel файла
            if ~exist(current_loaded_excel_path, 'file')
                % Если Excel файл не найден, сбрасываем путь
                current_loaded_excel_path = [];
                debugState('loadResults', '⚠️ Excel file not found, save overwrite disabled');
            else
                debugState('loadResults', '✓ Excel file path saved for overwrite: %s', current_loaded_excel_path);
            end
            
            % Восстанавливаем состояние первого результата если есть
            if ~isempty(slope_measurement_results)
                restoreStateFromMetadata(1);
                % Сохраняем позиции курсоров в память после восстановления состояния
                saveCurrentMarkerPositions();
            end
            
            % Обновляем список результатов в выпадающем списке
            updateResultsDropdown();
            
            % Обновляем состояние чекбокса Hot Resave
            updateHotResaveState();
            
        catch ME
            debugState('loadResults', '❌ Error loading: %s', ME.message);
        end
    end
    
    function loadResultsFromPath(metaPath)
        % Вспомогательная функция для загрузки результатов по прямому пути
        % Используется из resultsDropdownCallback
        loadResults([], [], metaPath);
    end
    
    function metadata = openFile(varargin)
        % Открывает новый файл для анализа (аналогично OpenZavLfpFile из signalViewerGUI.m)
        metadata = struct('hd', [], 'stims', [], 'filePath', '');
        
        % Определяем filepath из аргументов или глобальной переменной
        if nargin > 0 && ~isempty(varargin{1}) && (ischar(varargin{1}) || isstring(varargin{1}))
            filepath = char(varargin{1});
        elseif ~isempty(outside_calling_filepath)
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
                debugState('openFile', 'File selection canceled.');
                return;
            end
            filepath = fullfile(path, file);
        end
        
        % Автоконверсия ABF файлов
        [~, ~, ext] = fileparts(filepath);
        if strcmpi(ext, '.abf')
            debugState('openFile', 'ABF file detected, converting to ZAV...');
            zavFilePath = autoConvertAbfToZav(filepath);
            if ~isempty(zavFilePath) && exist(zavFilePath, 'file')
                filepath = zavFilePath;
            else
                debugState('openFile', 'Failed to convert ABF file');
                return;
            end
        end
        
        % Проверка, открыт ли уже файл
        if exist('matFilePath', 'var') && ~isempty(matFilePath) && exist('hd', 'var') && ~isempty(hd)
            [~, currentFileName, ~] = fileparts(matFilePath);
            [~, newFileName, ~] = fileparts(filepath);
            if strcmp(currentFileName, newFileName) && strcmp(matFilePath, filepath)
                debugState('openFile', 'File already open: %s', newFileName);
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
        
        % Очищаем все предыдущие результаты и измерения
        slope_measurement_results = [];
        
        % Сбрасываем путь к загруженному Excel файлу
        current_loaded_excel_path = [];
        
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
                'auto_set_time_windows', false, ...
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
            
            % Загружаем настройки каналов 
            loadChannelSettings();
            
            % Загружаем сохраненный канал из глобальных настроек
            saved_channel = 1; % значение по умолчанию
            try
                if exist(SettingsFilepath, 'file')
                    loadedSettings = load(SettingsFilepath, '-mat');
                    if isfield(loadedSettings, 'analysis_selected_channel')
                        saved_channel = loadedSettings.analysis_selected_channel;
                    end
                end
            catch
                % Используем значение по умолчанию при ошибке
            end
            
            % Обновляем popup каналов
            if exist('hChannelPopup', 'var') && ishandle(hChannelPopup)
                if isfield(hd, 'recChNames') && iscell(hd.recChNames) && ~isempty(hd.recChNames)
                    % Ограничиваем сохраненный канал диапазоном доступных каналов
                    saved_channel = min(max(1, saved_channel), length(hd.recChNames));
                    set(hChannelPopup, 'String', hd.recChNames, 'Value', saved_channel);
                    slope_measurement_settings.channel = saved_channel;
                else
                    set(hChannelPopup, 'String', {'Ch1'}, 'Value', 1);
                    slope_measurement_settings.channel = 1;
                end
            end
            
            % Показываем оси после загрузки файла
            set(hPlotAxes, 'Visible', 'on');
            
            % Обновляем rel_shift перед первым автоскейлом
            refreshRelShift();
            
            % Вычисляем и применяем оптимальные границы осей ДО обновления курсоров и графика
            [optimal_xlim, optimal_ylim] = calculateOptimalAxisLimits(true);
            
            % Сохраняем как original для правильной работы зума
            original_xlim = optimal_xlim;
            original_ylim = optimal_ylim;
            
            % Обновляем поля ввода курсоров после автоскейла
            updateCursorEditFields();
            
            % Обновляем отображение
            updateNavigationStatus();
            updatePlotAndCalculation();
            updateResultsTable();
            updateButtonStates();
            
            % Обновляем состояние кнопки Replace
            updateReplaceButtonState();
            
            % Загружаем позиции курсоров из настроек ПОСЛЕ загрузки файла
            loadCursorPositionsFromSettings();
            
            % После загрузки позиций курсоров обновляем rel_shift и повторно применяем автоскейл
            refreshRelShift();
            [optimal_xlim, optimal_ylim] = calculateOptimalAxisLimits(true);
            original_xlim = optimal_xlim;
            original_ylim = optimal_ylim;
            updateCursorEditFields();
            updateNavigationStatus();
            updatePlotAndCalculation();
            
            debugState('openFile', '✓ File successfully loaded: %s', matFileName);
            debugState('openFile', '  Data size: %dx%dx%d', size(lfp));
            debugState('openFile', '  Sampling rate: %.1f Hz', Fs);
            debugState('openFile', '  Duration: %.3f s', time(end));
            
            % Обновляем список результатов в выпадающем списке
            updateResultsDropdown();
            
            % Обновляем состояние чекбокса Hot Resave
            updateHotResaveState();
            
            % Возвращаем метаданные для совместимости с launchFile
            metadata.hd = hd;
            metadata.stims = stims;
            metadata.filePath = filepath;
            
        catch ME
            debugState('openFile', '❌ Error loading file: %s', ME.message);
            % Восстанавливаем предыдущие данные если загрузка не удалась
            metadata = struct('hd', [], 'stims', [], 'filePath', '');
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
                
                % Сбрасываем путь к загруженному Excel файлу
                current_loaded_excel_path = [];
                
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
        
        % Обновляем состояние чекбокса Hot Resave
        updateHotResaveState();
        
        debugState('clearAllResults', '✓ All results and measurements cleared');
                
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
            debugState('updateAnalysisPlotFunc', '✓ Signal analysis plot updated from group settings');
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
            debugState('loadChannelSettings', 'Loading individual channel settings...')
            loadSettingsFile(channelSettingsFilePath);
        else
            % Индивидуальных настроек нет - загружаем групповые + создаем индивидуальные
            % fprintf('DEBUG: loadChannelSettings: Индивидуальные настройки НЕ найдены, загружаем групповые\n');
            debugState('loadChannelSettings', 'No individual settings found, loading group settings...')
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
                channelSettings = updatedData;

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
                debugState('loadSettingsFile', 'settings were without filterSettings')
            end       

            if isfield(loadedSettings, 'newFs')
                newFs = loadedSettings.newFs;
            end
            if isfield(loadedSettings, 'shiftCoeff')
                shiftCoeff = loadedSettings.shiftCoeff;
            end
            if isfield(loadedSettings, 'time_back')
                time_back = loadedSettings.time_back;
                debugState('loadSettingsFileANALYSIS', 'time_back=%f', time_back);
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
                debugState('loadSettingsFile', 'Loaded shifted stimulus times from settings')
            end
            

            
            % fprintf('DEBUG: loadSettingsFile: Настройки каналов загружены успешно\n');
            debugState('loadSettingsFile', 'Channel settings loaded successfully')
            
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
            
            debugState('setDefaultChannelSettings', 'Default channel settings applied')
        end
    end

    % === ДОБАВЛЕНО: Функция для открытия редактора групповых настроек ===
    
    function openGroupSettingsEditor(~, ~)
        % Открывает редактор групповых настроек
        
        % Проверяем, загружен ли файл
        if isempty(matFilePath) || ~exist(matFilePath, 'file')
            debugState('openGroupSettingsEditor', 'No project loaded. Please load a MAT file first.');
            return;
        end
        
        % Проверяем, что все необходимые глобальные переменные доступны
        if ~exist('numChannels', 'var') || isempty(numChannels)
            debugState('openGroupSettingsEditor', 'Channel information not available. Please reload the file.');
            return;
        end
        
        if ~exist('Fs', 'var') || isempty(Fs)
            debugState('openGroupSettingsEditor', 'Sampling rate information not available. Please reload the file.');
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
        updateTableFunc = @() debugState('openGroupSettingsEditor', 'Table update function called');
        updateLocalCoefsFunc = @() debugState('openGroupSettingsEditor', 'Local coefficients update function called');
        updatePlotFunc = @() updatePlotAndCalculation();
        saveChannelSettingsFunc = @() saveChannelSettings();
        
        % Открываем редактор настроек
        try
            settingsEditor();
            debugState('openGroupSettingsEditor', 'Settings Editor opened successfully');
        catch ME
            debugState('openGroupSettingsEditor', 'Error opening Settings Editor: %s', ME.message);
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
            debugState('saveImage', '❌ Image save cancelled');
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
                    debugState('saveImage', '✓ Plot saved as PDF: %s', filename);
                case 2
                    print(tempFig, filename, '-depsc');
                    debugState('saveImage', '✓ Plot saved as EPS: %s', filename);
                case 3
                    saveas(tempFig, filename, 'png');
                    debugState('saveImage', '✓ Plot saved as PNG: %s', filename);
                otherwise
                    saveas(tempFig, filename);
                    debugState('saveImage', '✓ Plot saved: %s', filename);
            end
            
            % Удаляем временную фигуру
            delete(tempFig);
            
        catch ME
            debugState('saveImage', '❌ Error saving plot: %s', ME.message);
            debugState('saveImage', 'Error saving image: %s', ME.message);
            
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
                    
                    debugState('loadCursorPositionsFromSettings', '✓ Cursor positions loaded from settings');
                    
                    % Обновляем edit fields с новыми позициями
                    updateCursorEditFields();
                    
                    % НЕ вызываем updatePlotAndCalculation() здесь, чтобы не перезаписывать границы осей
                    % Границы осей уже применены в OpenFilePath() через calculateOptimalAxisLimits()
                else
                    debugState('loadCursorPositionsFromSettings', 'ℹ️ Cursor positions not found in settings');
                end
            else
                debugState('loadCursorPositionsFromSettings', 'ℹ️ Settings file not found');
            end
        catch ME
            debugState('loadCursorPositionsFromSettings', '❌ Error loading cursor positions: %s', ME.message);
        end
    end
    
    function loadSmoothingSettingsFromFile()
        try
            if exist(SettingsFilepath, 'file')
                loadedSettings = load(SettingsFilepath, '-mat');
                if isfield(loadedSettings, 'analysis_smooth_enabled')
                    analysis_smooth_enabled = logical(loadedSettings.analysis_smooth_enabled);
                end
                if isfield(loadedSettings, 'analysis_smooth_span')
                    spanCandidate = loadedSettings.analysis_smooth_span;
                    if isnumeric(spanCandidate) && ~isempty(spanCandidate)
                        spanCandidate = spanCandidate(1);
                        if isfinite(spanCandidate)
                            analysis_smooth_span = round(spanCandidate);
                        end
                    end
                end
                if isfield(loadedSettings, 'analysis_smooth_method')
                    methodCandidate = loadedSettings.analysis_smooth_method;
                    if isstring(methodCandidate)
                        methodCandidate = char(methodCandidate);
                    end
                    if ischar(methodCandidate) && any(strcmp(methodCandidate, {'moving', 'median'}))
                        analysis_smooth_method = methodCandidate;
                    else
                        analysis_smooth_method = 'moving';
                    end
                end
                if isfield(loadedSettings, 'analysis_show_raw_signal')
                    setappdata(signalFig, 'analysis_show_raw_signal', logical(loadedSettings.analysis_show_raw_signal));
                end
            end
        catch
        end
        updateSmoothingControls();
        loadHotResaveSettings();
    end
    
    function loadHotResaveSettings()
        % Загружает состояние чекбокса Hot Resave из настроек
        try
            if exist(SettingsFilepath, 'file')
                loadedSettings = load(SettingsFilepath, '-mat');
                if isfield(loadedSettings, 'hot_resave_enabled')
                    hot_resave_enabled = logical(loadedSettings.hot_resave_enabled);
                else
                    hot_resave_enabled = false;
                end
            else
                hot_resave_enabled = false;
            end
        catch
            hot_resave_enabled = false;
        end
        
        % Обновляем состояние чекбокса
        if exist('hHotResaveCheckbox', 'var') && ishandle(hHotResaveCheckbox)
            set(hHotResaveCheckbox, 'Value', hot_resave_enabled);
            updateHotResaveState();
        end
    end
    
    function saveHotResaveSettings()
        % Сохраняет состояние чекбокса Hot Resave в настройки
        try
            if exist(SettingsFilepath, 'file')
                save(SettingsFilepath, 'hot_resave_enabled', '-append');
            else
                save(SettingsFilepath, 'hot_resave_enabled');
            end
        catch
            % Игнорируем ошибки сохранения
        end
    end
    
    function updateHotResaveState()
        % Обновляет состояние чекбокса Hot Resave
        % Синхронизирует UI с глобальной переменной
        
        if ~exist('hHotResaveCheckbox', 'var') || ~ishandle(hHotResaveCheckbox)
            return;
        end
        
        % Чекбокс всегда доступен
        set(hHotResaveCheckbox, 'Enable', 'on');
        
        % Синхронизируем значение чекбокса с глобальной переменной
        set(hHotResaveCheckbox, 'Value', hot_resave_enabled);
    end
    
    function hotResaveCallback(src, ~)
        % Callback для чекбокса Hot Resave
        hot_resave_enabled = logical(get(src, 'Value'));
        saveHotResaveSettings();
        debugState('hotResaveCallback', 'Hot Resave %s', char(string(hot_resave_enabled).replace("1", "enabled").replace("0", "disabled")));
    end
    
    function saveSmoothingSettings()
        try
            if exist('SettingsFilepath', 'var') && ~isempty(SettingsFilepath)
                analysis_show_raw_signal = getShowRawFlag();
                vars = {'analysis_smooth_enabled', 'analysis_smooth_span', 'analysis_smooth_method', 'analysis_show_raw_signal'};
                if exist(SettingsFilepath, 'file')
                    save(SettingsFilepath, vars{:}, '-append');
                else
                    save(SettingsFilepath, vars{:});
                end
            end
        catch
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
                debugState('autoOpenLastFile', 'ℹ️ No recent files found for automatic opening');
                return;
            end
            
            % Берем последний файл из списка
            lastFile = lastOpenedFiles{end};
            
            % Проверяем, существует ли файл
            if ~exist(lastFile, 'file')
                debugState('autoOpenLastFile', '⚠️ Last file not found: %s', lastFile);
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
                        debugState('autoOpenLastFile', 'ℹ️ Manual file opening cancelled');
                end
                return;
            end
            debugState('autoOpenLastFile', '🔄 Automatically opening last file: %s', lastFile);
            outside_calling_filepath = lastFile;
            openFile([], []);
        catch ME
            debugState('autoOpenLastFile', '❌ Error during automatic file opening: %s', ME.message);
            debugState('autoOpenLastFile', 'ℹ️ Continuing with clean initialization');
        end
    end

    function OpenFilePath(filepath)
        outside_calling_filepath = filepath;
        openFile([], []);
    end

    
    function applyAutoscale(~, ~)
        % Применяет оптимальные размеры осей для видимых данных
        
        % Вычисляем и применяем оптимальные границы осей
        [optimal_xlim, optimal_ylim] = calculateOptimalAxisLimits(true);
        
        % Отключаем все инструменты
        zoom(signalFig, 'off');
        pan(signalFig, 'off');
        datacursormode(signalFig, 'off');
        brush(signalFig, 'off');
        
        % Обновляем статус навигации
        updateNavigationStatus();
        
        debugState('applyAutoscale', '✓ Optimal axis sizes applied');
    end

    function loadEvents(~, ~)
        % Загружает события из файла используя универсальную функцию
        
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

    function results = getAnalysisResultsFromDatabase(fileId)
        % Запрашивает результаты анализа из базы данных
        % Фильтрует по модулям 'signalAnalysis' и 'autoSlopeMeasurement'
        % Возвращает структуру с полями: report_path, module_name, analysis_timestamp
        
        results = [];
        
        if isempty(fileId) || ~isnumeric(fileId)
            return;
        end
        
        try
            % SQL запрос аналогичный updateAnalysisTable() из File Manager
            % Используем escapeSql для экранирования строковых значений в IN clause
            query = sprintf(['SELECT report_path, module_name, analysis_timestamp ' ...
                'FROM analysis_results ' ...
                'WHERE file_id = %d ' ...
                'AND module_name IN (''%s'', ''%s'') ' ...
                'ORDER BY analysis_timestamp DESC'], ...
                fileId, escapeSql('signalAnalysis'), escapeSql('autoSlopeMeasurement'));
            
            rows = sqlFetch(query);
            
            if ~isempty(rows)
                results = struct('report_path', {}, 'module_name', {}, 'analysis_timestamp', {});
                for i = 1:size(rows, 1)
                    results(i).report_path = rows{i, 1};
                    results(i).module_name = rows{i, 2};
                    results(i).analysis_timestamp = rows{i, 3};
                end
            end
        catch ME
            debugState('getAnalysisResultsFromDatabase', '❌ Error querying database: %s', ME.message);
        end
    end
    
    function updateResultsDropdown()
        % Обновляет содержимое выпадающего списка результатов
        % Вызывается при открытии файла и после сохранения результатов
        
        hResultsDropdown = findobj(signalFig, 'Tag', 'results_dropdown');
        if isempty(hResultsDropdown) || ~ishandle(hResultsDropdown)
            return;
        end
        
        % Проверяем, есть ли открытый файл
        if ~exist('matFilePath', 'var') || isempty(matFilePath)
            set(hResultsDropdown, 'String', {'No results found'}, 'Enable', 'off');
            setappdata(hResultsDropdown, 'meta_paths', {});
            return;
        end
        
        try
            % Получаем fileId через resolveFileId
            fileId = resolveFileId(matFilePath);
            
            if isempty(fileId)
                set(hResultsDropdown, 'String', {'No results found'}, 'Enable', 'off');
                setappdata(hResultsDropdown, 'meta_paths', {});
                return;
            end
            
            % Получаем результаты из базы данных
            results = getAnalysisResultsFromDatabase(fileId);
            
            if isempty(results)
                set(hResultsDropdown, 'String', {'No results found'}, 'Enable', 'off');
                setappdata(hResultsDropdown, 'meta_paths', {});
            else
                % Формируем список строк для popupmenu (только имена файлов)
                displayStrings = cell(length(results), 1);
                metaPaths = cell(length(results), 1);
                
                for i = 1:length(results)
                    % Преобразуем report_path (Excel) в путь к .meta файлу
                    [path, name, ~] = fileparts(results(i).report_path);
                    metaPath = fullfile(path, [name, '.meta']);
                    metaPaths{i} = metaPath;
                    
                    % Используем только имя файла для отображения
                    [~, fileName, ~] = fileparts(results(i).report_path);
                    displayStrings{i} = fileName;
                end
                
                set(hResultsDropdown, 'String', displayStrings, 'Enable', 'on', 'Value', 1);
                setappdata(hResultsDropdown, 'meta_paths', metaPaths);
            end
        catch ME
            debugState('updateResultsDropdown', '❌ Error updating results dropdown: %s', ME.message);
            set(hResultsDropdown, 'String', {'No results found'}, 'Enable', 'off');
            setappdata(hResultsDropdown, 'meta_paths', {});
        end
    end
    
    function resultsDropdownCallback(src, ~)
        % Обрабатывает выбор результата из выпадающего списка
        % Открывает выбранный результат через loadResults
        
        if ~ishandle(src)
            return;
        end
        
        selectedIdx = get(src, 'Value');
        metaPaths = getappdata(src, 'meta_paths');
        
        if isempty(metaPaths) || selectedIdx < 1 || selectedIdx > length(metaPaths)
            return;
        end
        
        metaPath = metaPaths{selectedIdx};
        
        % Проверяем существование файла
        if ~exist(metaPath, 'file')
            debugState('resultsDropdownCallback', '❌ File not found: %s', metaPath);
            msgbox(sprintf('File not found: %s', metaPath), 'Error', 'error');
            return;
        end
        
        % Вызываем loadResults с прямым путем к файлу
        loadResultsFromPath(metaPath);
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
            debugState('collectAllMetadata', '❌ Metadata collection cancelled');
            return;
        end
        
        % Создаем окно прогресса
        hWaitBar = waitbar(0, 'Starting metadata collection...', 'Name', 'Collecting Metadata');
        
        try
            % Находим все .meta файлы рекурсивно
            debugState('collectAllMetadata', '🔍 Searching for .meta files in folder %s...', root_dir);
            meta_files = dir(fullfile(root_dir, '**', '*.meta'));
            
            if isempty(meta_files)
                close(hWaitBar);
                debugState('collectAllMetadata', 'No .meta files found in the selected directory and its subdirectories.');
                debugState('collectAllMetadata', '❌ No .meta files found');
                return;
            end
            
            debugState('collectAllMetadata', '✓ Files found: %d', length(meta_files));
            
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
                        debugState('collectAllMetadata', '⚠️ Skipped file %s: no measurement results', meta_files(i).name);
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
                    debugState('collectAllMetadata', '⚠️ Error processing file %s: %s', meta_files(i).name, ME.message);
                    continue;
                end
            end
            
            % Закрываем окно прогресса
            close(hWaitBar);
            
            if isempty(all_results)
                debugState('collectAllMetadata', 'No valid results found in any of the .meta files.');
                debugState('collectAllMetadata', '❌ No valid results to save');
                return;
            end
            
            % Создаем имя файла для сохранения на основе имени корневой папки
            [~, root_folder_name, ~] = fileparts(root_dir);
            default_excel_name = fullfile(root_dir, [root_folder_name '_combined_results.xlsx']);
            
            % Запрашиваем имя файла для сохранения
            [filename, pathname] = uiputfile({'*.xlsx', 'Excel Files (*.xlsx)'}, ...
                'Save Combined Results As', default_excel_name);
            
            if isequal(filename, 0) || isequal(pathname, 0)
                debugState('collectAllMetadata', '❌ Save cancelled');
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
                excel_data{current_row, 15} = getNavigationStatusTextLocal(metadata);
                
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
            
            debugState('collectAllMetadata', '✓ Summary table saved:');
            debugState('collectAllMetadata', '  Path: %s', excel_path);
            debugState('collectAllMetadata', '  Files processed: %d', length(meta_files));
            debugState('collectAllMetadata', '  Total results: %d', length(all_results));
            
        catch ME
            % Закрываем окно прогресса при ошибке
            if exist('hWaitBar', 'var') && ishandle(hWaitBar)
                close(hWaitBar);
            end
            debugState('collectAllMetadata', '❌ Ошибка при сборе метаданных: %s', ME.message);
            debugState('collectAllMetadata', 'Error collecting metadata: %s', ME.message);
        end
    end

    % Функция обработки изменения размера окна
    function resizeSignalAnalysisWindow(~, ~)
        try
            % Путь к файлу координат
            coordsFile = getGUIConfigPath('signalAnalysisGUI_coords.json');
            
            % Используем figure_position для правильного вычисления коэффициентов масштабирования
            ResizeElements(signalFig, coordsFile, figure_position);
            updateMagnetButtonPositions();
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
        
        % Очистка памяти - очищаем все глобальные переменные
        clear global
        
        % Не сохраняем положение окна - всегда используем базовое из JSON
        delete(src);
        
        % Проверяем наличие других главных окон и открываем app.m при необходимости
        manageMainWindows('SignalAnalysisGUI');
    end

    % Режим редактирования координат
    if strcmp(editMode, 'edit')
        inspect(signalFig);
    end

end 