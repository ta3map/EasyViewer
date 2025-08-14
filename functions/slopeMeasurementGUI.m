function slopeMeasurementGUI()
    % Slope Measurement GUI - измерение угла наклона сигнала
    
    % Глобальные переменные для доступа к данным
    global lfp time chosen_time_interval time_back hd
    global newFs Fs timeUnitFactor selectedUnit
    global filterSettings filter_avaliable mean_group_ch
    global selectedCenter events stims sweep_info event_inx stim_inx sweep_inx events_exist stims_exist

    % Глобальные переменные для slope measurement
    global slope_measurement_settings
    global slope_measurement_results
    global selected_row_slope % для отслеживания выделенной строки в таблице
    
    % Глобальные переменные для множественных измерений
    global multiple_measurements
    global measurement_cursors
    global selected_measurement_row % для отслеживания выделенной строки в таблице измерений
    global slope_value slope_angle peak_time peak_value baseline_value onset_time onset_value onset_method measurement_metadata

    % Глобальные переменные для сохранения результатов
    global matFilePath matFileName
    
    % Глобальные переменные для среднего сигнала
    global mean_signal_data mean_signal_time mean_results_active
    
    % Глобальная переменная для метаданных измерений
    global current_measurement_metadata

    global rel_shift

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
    
    % Инициализация множественных измерений если их нет
    if isempty(multiple_measurements)
        multiple_measurements = struct('range_start_rel', {}, 'range_end_rel', {}, 'measurement_value', {}, 'metadata', {}, ...
                                     'function_type', {}, 'line_color', {}, 'line_style', {}, 'line_width', {}, ...
                                     'label_text', {}, 'label_background', {}, 'font_size', {});
    end
    
    % Инициализация курсоров измерений если их нет
    if isempty(measurement_cursors)
        measurement_cursors = [];
    end
    
    % Инициализация переменной для выделенной строки измерений
    selected_measurement_row = [];
    
    % Инициализация глобальной переменной для метаданных
    current_measurement_metadata = [];
    
    % Идентификатор (tag) для GUI фигуры
    figTag = 'SlopeMeasurement';
    
    % Определяем названия колонок как единый источник (доступны во всех функциях)
    table_column_names = {'Slope', 'Peak Time (rel)', 'Peak Time (abs)', 'Peak Amplitude', 'Onset Time (rel)', 'Onset Time (abs)', 'Baseline', 'Channel', 'Info'};
    table_column_widths = {50, 50, 50, 60, 65, 65, 50, 50, 80};
    table_column_formats = {'numeric', 'numeric', 'numeric', 'numeric', 'numeric', 'numeric', 'numeric', 'numeric', 'char'};
    
    % Поиск открытой фигуры с заданным идентификатором
    guiFig = findobj('Type', 'figure', 'Tag', figTag);
    
    if ~isempty(guiFig)
        % Делаем существующее окно текущим (активным)
        figure(guiFig);
        return
    end
    
    % Создание главного окна (увеличиваем размер для расширенной таблицы)
    slopeFig = figure('Name', 'Slope Measurement', 'Tag', figTag, ...
        'Resize', 'off', ...
        'NumberTitle', 'off', 'MenuBar', 'none', 'ToolBar', 'none', ...
        'Position', [100, 100, 1470, 600]);

    % === Левая панель управления ===
    
    % Выбор канала
    uicontrol(slopeFig, 'Style', 'text', 'Position', [20, 560, 100, 20], ...
        'String', 'Channel:', 'HorizontalAlignment', 'left');
    hChannelPopup = uicontrol(slopeFig, 'Style', 'popupmenu', ...
        'Position', [120, 560, 150, 25], ...
        'String', hd.recChNames, ...
        'Value', slope_measurement_settings.channel, ...
        'Callback', @channelCallback);
    
    % Настройки slope
    uicontrol(slopeFig, 'Style', 'text', 'Position', [20, 530, 100, 20], ...
        'String', 'Peak Polarity:', 'HorizontalAlignment', 'left');
    hPolarityPopup = uicontrol(slopeFig, 'Style', 'popupmenu', ...
        'Position', [120, 530, 100, 25], ...
        'String', {'Positive', 'Negative'}, ...
        'Value', strcmp(slope_measurement_settings.peak_polarity, 'negative') + 1, ...
        'Callback', @polarityCallback);
    
    uicontrol(slopeFig, 'Style', 'text', 'Position', [20, 500, 100, 20], ...
        'String', 'Slope Percent:', 'HorizontalAlignment', 'left');
    hSlopePercentEdit = uicontrol(slopeFig, 'Style', 'edit', ...
        'Position', [120, 500, 60, 25], ...
        'String', num2str(slope_measurement_settings.slope_percent), ...
        'Callback', @slopePercentCallback);
    uicontrol(slopeFig, 'Style', 'text', 'Position', [185, 500, 20, 20], ...
        'String', '%', 'HorizontalAlignment', 'left');
    
    % Настройки онсета
    uicontrol(slopeFig, 'Style', 'text', 'Position', [20, 470, 100, 20], ...
        'String', 'Onset Method:', 'HorizontalAlignment', 'left');
    hOnsetMethodPopup = uicontrol(slopeFig, 'Style', 'popupmenu', ...
        'Position', [120, 470, 120, 25], ...
        'String', {'First Derivative', 'Second Derivative', 'Threshold Crossing', 'Inverted Peak'}, ...
        'Value', getOnsetMethodIndex(slope_measurement_settings.onset_method), ...
        'Callback', @onsetMethodCallback);
    
    hOnsetThresholdLabel = uicontrol(slopeFig, 'Style', 'text', 'Position', [20, 440, 100, 20], ...
        'String', 'Onset Threshold:', 'HorizontalAlignment', 'left');
    hOnsetThresholdEdit = uicontrol(slopeFig, 'Style', 'edit', ...
        'Position', [120, 440, 60, 25], ...
        'String', num2str(slope_measurement_settings.onset_threshold), ...
        'Callback', @onsetThresholdCallback);
    hOnsetThresholdUnit = uicontrol(slopeFig, 'Style', 'text', 'Position', [185, 440, 20, 20], ...
        'String', 'std', 'HorizontalAlignment', 'left');
    
    % Разделитель baseline
    uicontrol(slopeFig, 'Style', 'text', 'Position', [20, 410, 250, 20], ...
        'String', '────── Baseline Range ──────', ...
        'HorizontalAlignment', 'center', 'FontWeight', 'bold');
    
    % Baseline начало
    uicontrol(slopeFig, 'Style', 'text', 'Position', [20, 380, 100, 20], ...
        'String', 'Baseline Start:', 'HorizontalAlignment', 'left');
    hBaselineStartEdit = uicontrol(slopeFig, 'Style', 'edit', ...
        'Position', [120, 380, 80, 25], ...
        'String', '0', 'Callback', @baselineStartCallback);
    uicontrol(slopeFig, 'Style', 'text', 'Position', [205, 380, 20, 20], ...
        'String', selectedUnit, 'HorizontalAlignment', 'left');
    
    % Baseline конец
    uicontrol(slopeFig, 'Style', 'text', 'Position', [20, 350, 100, 20], ...
        'String', 'Baseline End:', 'HorizontalAlignment', 'left');
    hBaselineEndEdit = uicontrol(slopeFig, 'Style', 'edit', ...
        'Position', [120, 350, 80, 25], ...
        'String', '0', 'Callback', @baselineEndCallback);
    uicontrol(slopeFig, 'Style', 'text', 'Position', [205, 350, 20, 20], ...
        'String', selectedUnit, 'HorizontalAlignment', 'left');
    
    % Разделитель peak
    uicontrol(slopeFig, 'Style', 'text', 'Position', [20, 320, 250, 20], ...
        'String', '────── Peak Search Range ──────', ...
        'HorizontalAlignment', 'center', 'FontWeight', 'bold');
    
    % Peak начало
    uicontrol(slopeFig, 'Style', 'text', 'Position', [20, 290, 100, 20], ...
        'String', 'Peak Start:', 'HorizontalAlignment', 'left');
    hPeakStartEdit = uicontrol(slopeFig, 'Style', 'edit', ...
        'Position', [120, 290, 80, 25], ...
        'String', '0', 'Callback', @peakStartCallback);
    uicontrol(slopeFig, 'Style', 'text', 'Position', [205, 290, 20, 20], ...
        'String', selectedUnit, 'HorizontalAlignment', 'left');
    
    % Peak конец
    uicontrol(slopeFig, 'Style', 'text', 'Position', [20, 260, 100, 20], ...
        'String', 'Peak End:', 'HorizontalAlignment', 'left');
    hPeakEndEdit = uicontrol(slopeFig, 'Style', 'edit', ...
        'Position', [120, 260, 80, 25], ...
        'String', '0', 'Callback', @peakEndCallback);
    uicontrol(slopeFig, 'Style', 'text', 'Position', [205, 260, 20, 20], ...
        'String', selectedUnit, 'HorizontalAlignment', 'left');
    
    % Разделитель результатов
    uicontrol(slopeFig, 'Style', 'text', 'Position', [20, 230, 250, 20], ...
        'String', '────── Results ──────', ...
        'HorizontalAlignment', 'center', 'FontWeight', 'bold');
    
    % Результаты
    hBaselineText = uicontrol(slopeFig, 'Style', 'text', 'Position', [20, 205, 200, 20], ...
        'String', 'Baseline: -', 'HorizontalAlignment', 'left');
    hBaselineCheckbox = uicontrol(slopeFig, 'Style', 'checkbox', 'Position', [225, 205, 20, 20], ...
        'Value', slope_measurement_settings.show_baseline, 'Callback', @baselineVisibilityCallback);
    
    hPeakText = uicontrol(slopeFig, 'Style', 'text', 'Position', [20, 185, 200, 20], ...
        'String', 'Peak: (-, -)', 'HorizontalAlignment', 'left');
    hPeakCheckbox = uicontrol(slopeFig, 'Style', 'checkbox', 'Position', [225, 185, 20, 20], ...
        'Value', slope_measurement_settings.show_peak, 'Callback', @peakVisibilityCallback);
    
    hSlopeText = uicontrol(slopeFig, 'Style', 'text', 'Position', [20, 165, 200, 20], ...
        'String', 'Slope: -', 'HorizontalAlignment', 'left');
    hSlopeCheckbox = uicontrol(slopeFig, 'Style', 'checkbox', 'Position', [225, 165, 20, 20], ...
        'Value', slope_measurement_settings.show_slope, 'Callback', @slopeVisibilityCallback);
    
    hAngleText = uicontrol(slopeFig, 'Style', 'text', 'Position', [20, 145, 200, 20], ...
        'String', 'Angle: -', 'HorizontalAlignment', 'left');
    
    hOnsetText = uicontrol(slopeFig, 'Style', 'text', 'Position', [20, 125, 200, 20], ...
        'String', 'Onset: -', 'HorizontalAlignment', 'left');
    hOnsetCheckbox = uicontrol(slopeFig, 'Style', 'checkbox', 'Position', [225, 125, 20, 20], ...
        'Value', slope_measurement_settings.show_onset, 'Callback', @onsetVisibilityCallback);
    
    % Разделитель навигации
    uicontrol(slopeFig, 'Style', 'text', 'Position', [20, 105, 250, 20], ...
        'String', '────── Navigation ──────', ...
        'HorizontalAlignment', 'center', 'FontWeight', 'bold');
    
    % Статус навигации
    hNavigationStatus = uicontrol(slopeFig, 'Style', 'text', 'Position', [20, 65, 250, 20], ...
        'String', 'Mode: time', 'HorizontalAlignment', 'left');
    
    % Кнопки навигации (сдвигаем вниз)
    hPrevBtn = uicontrol(slopeFig, 'Style', 'pushbutton', 'String', '◀ Previous', ...
        'Position', [20, 5, 70, 25], 'Callback', @(~,~)shiftTimeSlope(-1));
    hNextBtn = uicontrol(slopeFig, 'Style', 'pushbutton', 'String', 'Next ▶', ...
        'Position', [95, 5, 70, 25], 'Callback', @(~,~)shiftTimeSlope(1));
    
    % Кнопка автоматического измерения всех участков
    hAutoMeasureBtn = uicontrol(slopeFig, 'Style', 'pushbutton', 'String', 'Auto Measure All', ...
        'Position', [170, 5, 100, 25], 'Callback', @autoMeasureAllTimeRanges);
    
    % Кнопка добавления результата
    hAddBtn = uicontrol(slopeFig, 'Style', 'pushbutton', 'String', 'Add', ...
        'Position', [1040, 530, 70, 25], 'Callback', @addResult);
    
    % Кнопка удаления результата
    hRemoveBtn = uicontrol(slopeFig, 'Style', 'pushbutton', 'String', 'Remove', ...
        'Position', [1040, 500, 70, 25], 'Callback', @removeResult);
    
    % Кнопка просмотра среднего сигнала
    hMeanResultsBtn = uicontrol(slopeFig, 'Style', 'pushbutton', 'String', 'Mean Results', ...
        'Position', [1040, 470, 70, 25], 'Callback', @toggleMeanResults, 'Enable', 'off');
    
    % Кнопка загрузки результатов
    uicontrol(slopeFig, 'Style', 'pushbutton', 'String', 'Load', ...
        'Position', [1040, 340, 70, 25], 'Callback', @loadResults);
    
    % Кнопка очистки всех результатов
    uicontrol(slopeFig, 'Style', 'pushbutton', 'String', 'Clear All', ...
        'Position', [1380, 530, 70, 25], 'Callback', @clearAllResults);
    
    % Кнопка сохранения результатов
    uicontrol(slopeFig, 'Style', 'pushbutton', 'String', 'Save', ...
        'Position', [1040, 310, 70, 25], 'Callback', @saveResults);
    
    % === Панель множественных измерений ===
    % Заголовок панели измерений
    uicontrol(slopeFig, 'Style', 'text', 'Position', [280, 560, 200, 20], ...
        'String', 'Multiple Measurements', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
    
    % Кнопки управления измерениями
    hAddMeasurementBtn = uicontrol(slopeFig, 'Style', 'pushbutton', 'String', 'Add Measurement', ...
        'Position', [280, 530, 100, 25], 'Callback', @addMeasurement);
    hRemoveMeasurementBtn = uicontrol(slopeFig, 'Style', 'pushbutton', 'String', 'Remove Measurement', ...
        'Position', [390, 530, 100, 25], 'Callback', @removeMeasurement);
    
    % Таблица измерений
    hMeasurementsTable = uitable(slopeFig, 'Position', [280, 50, 200, 470], ...
        'ColumnName', {'Range', 'Value', 'Type'}, ...
        'ColumnWidth', {80, 80, 40}, ...
        'ColumnFormat', {'char', 'numeric', 'char'}, ...
        'Data', {}, ...
        'CellSelectionCallback', @measurementTableSelectionChanged);
    
    % Кнопка для открытия свойств выделенного измерения
    hPropertiesBtn = uicontrol(slopeFig, 'Style', 'pushbutton', 'String', 'Properties', ...
        'Position', [280, 20, 100, 25], 'Callback', @openMeasurementProperties);
    
        
    
    % === График ===
    hPlotAxes = axes('Position', [0.37, 0.15, 0.322, 0.75]);
    
    % Кнопка зума в левом углу графика
    hZoomButton = uicontrol(slopeFig, 'Style', 'pushbutton', 'String', 'Zoom', ...
        'Position', [520, 530, 70, 25], 'Callback', @toggleZoom);
    
    % === Таблица результатов ===
    % Заголовок таблицы
    uicontrol(slopeFig, 'Style', 'text', 'Position', [1120, 560, 330, 25], ...
        'String', 'Results Table', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
    
    % Таблица результатов
    hResultsTable = uitable(slopeFig, 'Position', [1120, 50, 330, 470], ...
        'ColumnName', table_column_names, ...
        'ColumnWidth', table_column_widths, ...
        'ColumnFormat', table_column_formats, ...
        'Data', {}, ...
        'CellSelectionCallback', @tableSelectionChanged);
    
    % Переменные для хранения графических объектов
    hBaselineLines = [];  % линии baseline диапазона
    hPeakLines = [];      % линии peak диапазона  
    hSlopeLine = [];      % линия slope regression
    hPeakMarker = [];     % маркер пика
    hOnsetMarker = [];    % маркер онсета
    hBaselineMarkers = [];% маркеры baseline
    hPeakMarkers = [];    % маркеры peak диапазона
    hMeasurementLines = []; % линии измерений (множественные курсоры)
    
    % Локальные переменные для зума
    zoom_active = false;
    zoom_start_rel = 0;    % относительная позиция начала зума по времени (0-1)
    zoom_end_rel = 1;      % относительная позиция конца зума по времени (0-1)
    zoom_y_min = [];       % минимальная амплитуда зума
    zoom_y_max = [];       % максимальная амплитуда зума
    original_ylim = [];    % исходные границы амплитуды для восстановления
    
    % Переменная для относительного сдвига времени
    rel_shift = 0;
    
    % Переменные для среднего сигнала
    mean_results_active = false;
    mean_signal_data = [];
    mean_signal_time = [];
    
    % Флаг для восстановления состояния из метаданных
    restoring_from_metadata = false;
    
    % Инициализация
    initializeTimes();
    
    % Устанавливаем видимость поля порога в зависимости от выбранного метода
    % updateOnsetThresholdVisibility();
    
    updateNavigationStatus();
    updatePlotAndCalculation();
    updateResultsTable();
    updateMeasurementsTable();
    updateButtonStates();
    
    % Добавляем обработку клавиш для навигации
    set(slopeFig, 'KeyPressFcn', @keyPressFunction);
    
    % Добавляем обработку колеса мыши для зума
    set(slopeFig, 'WindowScrollWheelFcn', @mouseWheelZoom);
    
    % === Callback функции ===
        
    function initializeTimes()
        % Вычисляем начальные времена для baseline и peak диапазонов
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
        
        % Обновляем edit fields
        set(hBaselineStartEdit, 'String', sprintf('%.3f', (baseline_start - rel_shift) * timeUnitFactor));
        set(hBaselineEndEdit, 'String', sprintf('%.3f', (baseline_end - rel_shift) * timeUnitFactor));
        set(hPeakStartEdit, 'String', sprintf('%.3f', (peak_start - rel_shift) * timeUnitFactor));
        set(hPeakEndEdit, 'String', sprintf('%.3f', (peak_end - rel_shift) * timeUnitFactor));
    end
    
    function channelCallback(src, ~)
        slope_measurement_settings.channel = get(src, 'Value');
        updatePlotAndCalculation();
    end
    
    function polarityCallback(src, ~)
        polarities = get(src, 'String');
        slope_measurement_settings.peak_polarity = lower(polarities{get(src, 'Value')});
        updatePlotAndCalculation();
    end
    
    function slopePercentCallback(src, ~)
        new_percent = str2double(get(src, 'String'));
        if ~isnan(new_percent) && new_percent > 0 && new_percent < 100
            slope_measurement_settings.slope_percent = new_percent;
            updatePlotAndCalculation();
        end
    end
    
    function baselineStartCallback(src, ~)
        new_time = str2double(get(src, 'String')) / timeUnitFactor;
        if ~isnan(new_time)
            slope_measurement_settings.baseline_start = rel_shift + new_time;
            updatePlotAndCalculation();
        end
    end
    
    function baselineEndCallback(src, ~)
        new_time = str2double(get(src, 'String')) / timeUnitFactor;
        if ~isnan(new_time)
            slope_measurement_settings.baseline_end = rel_shift + new_time;
            updatePlotAndCalculation();
        end
    end
    
    function peakStartCallback(src, ~)
        new_time = str2double(get(src, 'String')) / timeUnitFactor;
        if ~isnan(new_time)
            slope_measurement_settings.peak_start = rel_shift + new_time;
            updatePlotAndCalculation();
        end
    end
    
    function peakEndCallback(src, ~)
        new_time = str2double(get(src, 'String')) / timeUnitFactor;
        if ~isnan(new_time)
            slope_measurement_settings.peak_end = rel_shift + new_time;
            updateNavigationStatus(); % Синхронизируем с основным приложением
            updatePlotAndCalculation();
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
        if ~isnan(new_threshold) && new_threshold > 0
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
        
        % Сначала вычисляем все результаты
        [slope_value, slope_angle, peak_time, peak_value, baseline_value, onset_time, onset_value, measurement_metadata] = calculateResults();
        
        % Затем обновляем график и визуализацию
        updatePlotVisualization();
    end
    
    function [slope_value, slope_angle, peak_time, peak_value, baseline_value, onset_time, onset_value, measurement_metadata] = calculateResults()
        % Вычисляет все результаты измерений без отрисовки
        
        % Проверяем, нужно ли использовать средний сигнал
        if mean_results_active && ~isempty(mean_signal_data) && ~isempty(mean_signal_time)
            % Используем средний сигнал
            channel_data = mean_signal_data;
            time_in = mean_signal_time;
            rel_shift = 0; % В режиме среднего сигнала время уже нормализовано
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
            
            % Устанавливаем сдвиг для относительного времени
            if strcmp(selectedCenter, 'stimulus') && stims_exist && ~isempty(stims)
                rel_shift = stims(stim_inx);
            else
                rel_shift = chosen_time_interval(1);
            end
            
            % Фильтрация если включена
            if sum(filter_avaliable) > 0 && filter_avaliable(selected_channel)
                channel_data = applyFilter(channel_data, filterSettings, newFs);
            end
            
            % Ресэмплинг если нужен
            if Fs ~= newFs
                lfp_Fs = round(newFs);
                channel_data = resample(double(channel_data), lfp_Fs, Fs);
                time_in = linspace(time_in(1), time_in(end), length(channel_data));
            end
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
        else
            % В обычном режиме используем абсолютные координаты с вычитанием rel_shift
            baseline_data_struct.baseline_start = baseline_start - rel_shift;
            baseline_data_struct.baseline_end = baseline_end - rel_shift;
            baseline_data_struct.peak_start = peak_start - rel_shift;
            baseline_data_struct.peak_end = peak_end - rel_shift;
        end
        
        baseline_data_struct.slope_percent = slope_percent;
        baseline_data_struct.peak_polarity = peak_polarity;
        
        % Расчет slope с использованием calculateMeasurementByType
        time_in_rel = time_in - rel_shift;
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
        
        % Проверяем, нужно ли использовать средний сигнал
        if mean_results_active && ~isempty(mean_signal_data) && ~isempty(mean_signal_time)
            % Используем средний сигнал
            channel_data = mean_signal_data;
            time_in = mean_signal_time;
            rel_shift = 0;
            time_display = time_in * timeUnitFactor;
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
            
            % Устанавливаем сдвиг для относительного времени
            if strcmp(selectedCenter, 'stimulus') && stims_exist && ~isempty(stims)
                rel_shift = stims(stim_inx);
            else
                rel_shift = chosen_time_interval(1);
            end
            
            % Фильтрация если включена
            if sum(filter_avaliable) > 0 && filter_avaliable(selected_channel)
                channel_data = applyFilter(channel_data, filterSettings, newFs);
            end
            
            % Ресэмплинг если нужен
            if Fs ~= newFs
                lfp_Fs = round(newFs);
                channel_data = resample(double(channel_data), lfp_Fs, Fs);
                time_in = linspace(time_in(1), time_in(end), length(channel_data));
            end
            
            % Преобразование времени с учетом единиц
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
        
        % Применяем зум если активен
        if zoom_active && ~isnan(zoom_start_rel) && ~isnan(zoom_end_rel)
            % Зум по времени
            full_start = chosen_time_interval(1) - time_back;
            full_end = chosen_time_interval(2);
            full_range = full_end - full_start;
            
            if full_range > 0
                zoom_start_abs = full_start + zoom_start_rel * full_range;
                zoom_end_abs = full_start + zoom_end_rel * full_range;
                
                if zoom_end_abs > zoom_start_abs
                    xlim([(zoom_start_abs - rel_shift) * timeUnitFactor, (zoom_end_abs - rel_shift) * timeUnitFactor]);
                else
                    % Сбрасываем зум
                    zoom_active = false;
                    zoom_start_rel = 0;
                    zoom_end_rel = 1;
                    zoom_y_min = [];
                    zoom_y_max = [];
                    full_start = (chosen_time_interval(1) - time_back - rel_shift) * timeUnitFactor;
                    full_end = (chosen_time_interval(2) - rel_shift) * timeUnitFactor;
                    xlim([full_start, full_end]);
                    
                    zoomBtn = findobj(slopeFig, 'Style', 'pushbutton', 'Callback', @toggleZoom);
                    if ~isempty(zoomBtn)
                        set(zoomBtn, 'String', 'Zoom');
                    end
                end
            else
                % Сбрасываем зум
                zoom_active = false;
                zoom_start_rel = 0;
                zoom_end_rel = 1;
                zoom_y_min = [];
                zoom_y_max = [];
                full_start = (chosen_time_interval(1) - time_back - rel_shift) * timeUnitFactor;
                full_end = (chosen_time_interval(2) - rel_shift) * timeUnitFactor;
                xlim([full_start, full_end]);
                
                zoomBtn = findobj(slopeFig, 'Style', 'pushbutton', 'Callback', @toggleZoom);
                if ~isempty(zoomBtn)
                    set(zoomBtn, 'String', 'Zoom');
                end
            end
            
            % Зум по амплитуде
            if ~isempty(zoom_y_min) && ~isempty(zoom_y_max) && zoom_y_max > zoom_y_min
                ylim([zoom_y_min, zoom_y_max]);
            end
        else
            % Сбрасываем к полному диапазону времени
            if mean_results_active && ~isempty(mean_signal_data) && ~isempty(mean_signal_time)
                % В режиме среднего сигнала используем границы из данных
                full_start = min(time_display);
                full_end = max(time_display);
                xlim([full_start, full_end]);
                
                % Вычисляем границы амплитуды с небольшим запасом
                y_min = min(channel_data);
                y_max = max(channel_data);
                y_range = y_max - y_min;
                if y_range == 0
                    y_range = abs(y_min) * 0.1;
                end
                y_padding = y_range * 0.05;
                ylim([y_min - y_padding, y_max + y_padding]);
            else
                % В обычном режиме используем стандартные границы времени
                full_start = (chosen_time_interval(1) - time_back - rel_shift) * timeUnitFactor;
                full_end = (chosen_time_interval(2) - rel_shift) * timeUnitFactor;
                xlim([full_start, full_end]);
                
                % Проверяем, есть ли уже сохраненные границы амплитуды
                if restoring_from_metadata && ~isempty(original_ylim) && length(original_ylim) == 2
                    ylim(original_ylim);
                else
                    % Вычисляем границы амплитуды с небольшим запасом
                    y_min = min(channel_data);
                    y_max = max(channel_data);
                    y_range = y_max - y_min;
                    if y_range == 0
                        y_range = abs(y_min) * 0.1;
                    end
                    y_padding = y_range * 0.05;
                    ylim([y_min - y_padding, y_max + y_padding]);
                end
            end
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
        
        % Обновление результатов в текстовых полях
        if exist('baseline_value', 'var') && ~isnan(baseline_value)
            set(hBaselineText, 'String', sprintf('Baseline: %.3f', baseline_value));
        else
            set(hBaselineText, 'String', 'Baseline: -');
        end
        
        if exist('peak_time', 'var') && exist('peak_value', 'var') && ~isnan(peak_time) && ~isnan(peak_value)
            set(hPeakText, 'String', sprintf('Peak: (%.3f, %.3f)', peak_time * timeUnitFactor, peak_value));
        else
            set(hPeakText, 'String', 'Peak: (-, -)');
        end
        
        if exist('slope_value', 'var') && ~isnan(slope_value)
            set(hSlopeText, 'String', sprintf('Slope: %.6f units/%s', slope_value, selectedUnit));
        else
            set(hSlopeText, 'String', 'Slope: -');
        end
        
        if exist('slope_angle', 'var') && ~isnan(slope_angle)
            set(hAngleText, 'String', sprintf('Angle: %.2f°', slope_angle));
        else
            set(hAngleText, 'String', 'Angle: -');
        end
        
        if exist('onset_time', 'var') && exist('onset_value', 'var') && ~isnan(onset_time) && ~isnan(onset_value)
            set(hOnsetText, 'String', sprintf('Onset: (%.3f, %.3f)', onset_time * timeUnitFactor, onset_value));
        else
            set(hOnsetText, 'String', 'Onset: (-, -)');
        end
        
        % Обновляем видимость текстовых полей
        if slope_measurement_settings.show_baseline
            set(hBaselineText, 'Visible', 'on');
        else
            set(hBaselineText, 'Visible', 'off');
        end
        
        if slope_measurement_settings.show_peak
            set(hPeakText, 'Visible', 'on');
        else
            set(hPeakText, 'Visible', 'off');
        end
        
        if slope_measurement_settings.show_slope
            set(hSlopeText, 'Visible', 'on');
            set(hAngleText, 'Visible', 'on');
        else
            set(hSlopeText, 'Visible', 'off');
            set(hAngleText, 'Visible', 'off');
        end
        
        if slope_measurement_settings.show_onset
            set(hOnsetText, 'Visible', 'on');
        else
            set(hOnsetText, 'Visible', 'off');
        end
        
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
            title('Mean Signal (Average of All Results)');
        else
            selected_channel = slope_measurement_settings.channel;
            title(['Channel: ' hd.recChNames{selected_channel}]);
        end
        
        grid on;
        
            % Обновляем таблицу измерений
    updateMeasurementsTable();
    
    % Обновляем таблицу результатов
    % updateResultsTable(); % Закомментировано чтобы не терять выделение при восстановлении состояния
    
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
        set(slopeFig, 'WindowButtonMotionFcn', @(s,e)dragMarker(s,e,range_type,line_num));
        set(slopeFig, 'WindowButtonUpFcn', @stopDrag);
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
                set(hBaselineStartEdit, 'String', sprintf('%.3f', (new_time - rel_shift) * timeUnitFactor));
            else % конец baseline
                slope_measurement_settings.baseline_end = new_time;
                set(hBaselineEndEdit, 'String', sprintf('%.3f', (new_time - rel_shift) * timeUnitFactor));
            end
        elseif strcmp(range_type, 'peak')
            if line_num == 1 % начало peak
                slope_measurement_settings.peak_start = new_time;
                set(hPeakStartEdit, 'String', sprintf('%.3f', (new_time - rel_shift) * timeUnitFactor));
            else % конец peak
                slope_measurement_settings.peak_end = new_time;
                set(hPeakEndEdit, 'String', sprintf('%.3f', (new_time - rel_shift) * timeUnitFactor));
            end
        end
        
        % Обновляем только позиции линий без пересчета параметров
        updateLinePositions();
    end
    
    function stopDrag(~, ~)
        set(slopeFig, 'WindowButtonMotionFcn', '');
        set(slopeFig, 'WindowButtonUpFcn', '');
        
        % Пересчитываем параметры только после того как пользователь отжал мышь
        updatePlotAndCalculation();
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
        % Навигация между временными сегментами (аналогично shiftTime из EasyView.m)
        
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
        
        % Обновляем статус и график
        updateNavigationStatus();
        updatePlotAndCalculation();
        
        % Пересчитываем значения измерений для нового сегмента
        for i = 1:length(multiple_measurements)
            calculateMeasurementValue(i);
        end
        updateMeasurementsTable();
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
        set(hBaselineStartEdit, 'String', sprintf('%.3f', baseline_rel.start * timeUnitFactor));
        set(hBaselineEndEdit, 'String', sprintf('%.3f', baseline_rel.end * timeUnitFactor));
        set(hPeakStartEdit, 'String', sprintf('%.3f', peak_rel.start * timeUnitFactor));
        set(hPeakEndEdit, 'String', sprintf('%.3f', peak_rel.end * timeUnitFactor));
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
        zoomBtn = findobj(slopeFig, 'Style', 'pushbutton', 'Callback', @toggleZoom);
        currentText = '';
        if ~isempty(zoomBtn)
            currentText = get(zoomBtn, 'String');
        end
        fprintf('DEBUG: toggleZoom вызвана, zoom_active = %d, кнопка = "%s"\n', zoom_active, currentText);
        if zoom_active
            % Если зум активен - сбрасываем
            fprintf('DEBUG: Зум активен, вызываем resetZoom\n');
            resetZoom();
        else
            % Если зум неактивен - начинаем выбор области
            fprintf('DEBUG: Зум неактивен, вызываем startZoomSelection\n');
            startZoomSelection();
        end
    end
    
    function startZoomSelection()
        % Начинаем выбор области для зума
        axes(hPlotAxes);
        fprintf('Выберите область зума: кликните любые две точки для определения области\n');
        
        % Собираем две точки для зума (с координатами X и Y)
        [x1, y1] = ginput(1);
        if isempty(x1)
            fprintf('Зум отменен\n');
            return;
        end
        
        % Показываем первую точку
        hold(hPlotAxes, 'on');
        current_xlim = xlim(hPlotAxes);
        current_ylim = ylim(hPlotAxes);
        hTempLineV = line([x1, x1], current_ylim, 'Color', 'r', 'LineStyle', '--', 'LineWidth', 2);
        hTempLineH = line(current_xlim, [y1, y1], 'Color', 'r', 'LineStyle', '--', 'LineWidth', 2);
        fprintf('Первая точка выбрана: (%.3f, %.3f). Выберите вторую точку\n', x1, y1);
        
        [x2, y2] = ginput(1);
        if isempty(x2)
            delete(hTempLineV);
            delete(hTempLineH);
            fprintf('Зум отменен\n');
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
            fprintf('Некорректная область зума: область должна иметь ненулевой размер\n');
        end
    end
    
    function applyZoom(zoom_start_time, zoom_end_time, zoom_start_y, zoom_end_y)
        % Применяем зум к выбранной области (время + амплитуда)
        
        fprintf('DEBUG: applyZoom входные данные: время [%.3f, %.3f], амплитуда [%.3f, %.3f]\n', ...
            zoom_start_time, zoom_end_time, zoom_start_y, zoom_end_y);
        
        % Определяем полный временной диапазон данных
        full_start = chosen_time_interval(1) - time_back;
        full_end = chosen_time_interval(2);
        full_range = full_end - full_start;
        
        fprintf('DEBUG: полный диапазон данных: [%.3f, %.3f], range=%.3f\n', full_start, full_end, full_range);
        
        % Конвертируем времена из отображаемых единиц в абсолютные секунды
        % Учитываем что отображаемое время = (абсолютное_время - rel_shift) * timeUnitFactor
        % Поэтому абсолютное_время = отображаемое_время / timeUnitFactor + rel_shift
        zoom_start_sec = zoom_start_time / timeUnitFactor + rel_shift;
        zoom_end_sec = zoom_end_time / timeUnitFactor + rel_shift;
        
        fprintf('DEBUG: конвертированные времена в абсолютных секундах: [%.3f, %.3f]\n', zoom_start_sec, zoom_end_sec);
        
        % Ограничиваем зум область границами данных
        zoom_start_sec = max(zoom_start_sec, full_start);
        zoom_end_sec = min(zoom_end_sec, full_end);
        
        fprintf('DEBUG: ограниченные времена: [%.3f, %.3f]\n', zoom_start_sec, zoom_end_sec);
        
        % Вычисляем относительные позиции по времени (0-1)
        if full_range > 0
            zoom_start_rel = (zoom_start_sec - full_start) / full_range;
            zoom_end_rel = (zoom_end_sec - full_start) / full_range;
            
            % Ограничиваем значения от 0 до 1
            zoom_start_rel = max(0, min(1, zoom_start_rel));
            zoom_end_rel = max(0, min(1, zoom_end_rel));
            
            fprintf('DEBUG: относительные позиции: [%.3f, %.3f]\n', zoom_start_rel, zoom_end_rel);
        else
            % Если full_range некорректный - используем значения по умолчанию
            zoom_start_rel = 0;
            zoom_end_rel = 1;
            fprintf('DEBUG: full_range некорректный, используем значения по умолчанию\n');
        end
        
        % Сохраняем зум по амплитуде - порядок не важен, min/max автоматически сортируют
        zoom_y_min = min(zoom_start_y, zoom_end_y);
        zoom_y_max = max(zoom_start_y, zoom_end_y);
        
        fprintf('DEBUG: зум по амплитуде: [%.3f, %.3f]\n', zoom_y_min, zoom_y_max);
        
        % Проверяем что зум область корректна
        fprintf('DEBUG: проверки: full_range>0=%d, zoom_end_rel>zoom_start_rel=%d, zoom_y_max>zoom_y_min=%d\n', ...
            full_range > 0, zoom_end_rel > zoom_start_rel, zoom_y_max > zoom_y_min);
        
        if full_range > 0 && zoom_end_rel > zoom_start_rel && zoom_y_max > zoom_y_min
            zoom_active = true;
            
            % Сохраняем исходные границы амплитуды при первом зуме
            if isempty(original_ylim)
                original_ylim = ylim(hPlotAxes);
                fprintf('DEBUG: Сохранены исходные границы амплитуды: [%.2f, %.2f]\n', original_ylim(1), original_ylim(2));
            end
            
            fprintf('DEBUG: Меняем кнопку на Reset, zoom_active = %d\n', zoom_active);
            
            % Находим кнопку зума в фигуре
            zoomBtn = findobj(slopeFig, 'Style', 'pushbutton', 'Callback', @toggleZoom);
            if ~isempty(zoomBtn)
                set(zoomBtn, 'String', 'Reset Zoom');
                fprintf('DEBUG: Текст кнопки изменен на: %s\n', get(zoomBtn, 'String'));
            else
                fprintf('ERROR: Кнопка зума не найдена!\n');
            end
            
            fprintf('✓ Зум применен: время %.1f%%-%.1f%%, амплитуда %.2f-%.2f\n', ...
                zoom_start_rel*100, zoom_end_rel*100, zoom_y_min, zoom_y_max);
            updateNavigationStatus();
            updatePlotAndCalculation();
        else
            fprintf('❌ Некорректная область зума\n');
            if full_range <= 0
                fprintf('  - full_range <= 0: %.3f\n', full_range);
            end
            if zoom_end_rel <= zoom_start_rel
                fprintf('  - zoom_end_rel <= zoom_start_rel: %.3f <= %.3f\n', zoom_end_rel, zoom_start_rel);
            end
            if zoom_y_max <= zoom_y_min
                fprintf('  - zoom_y_max <= zoom_y_min: %.3f <= %.3f\n', zoom_y_max, zoom_y_min);
            end
        end
    end
    
    function resetZoom()
        % Сбрасываем зум
        fprintf('DEBUG: resetZoom вызвана\n');
        zoom_active = false;
        zoom_start_rel = 0;
        zoom_end_rel = 1;
        zoom_y_min = [];
        zoom_y_max = [];
        
        % Сбрасываем original_ylim чтобы при следующем updatePlotAndCalculation()
        % были вычислены новые оптимальные границы
        original_ylim = [];
        
        % Находим кнопку зума в фигуре
        zoomBtn = findobj(slopeFig, 'Style', 'pushbutton', 'Callback', @toggleZoom);
        if ~isempty(zoomBtn)
            set(zoomBtn, 'String', 'Zoom');
            fprintf('DEBUG: Кнопка сброшена на: %s, zoom_active = %d\n', get(zoomBtn, 'String'), zoom_active);
        else
            fprintf('ERROR: Кнопка зума не найдена в resetZoom!\n');
        end
        
        fprintf('✓ Зум сброшен (будут вычислены новые оптимальные границы)\n');
        updateNavigationStatus();
        updatePlotAndCalculation();
    end
    
    function mouseWheelZoom(~, eventdata)
        % Зум колесом мыши
        if ~zoom_active
            return; % Колесо работает только когда уже есть зум
        end
        
        % Получаем позицию курсора
        cp = get(hPlotAxes, 'CurrentPoint');
        if isempty(cp)
            return;
        end
        
        cursor_time = cp(1,1) / timeUnitFactor; % Конвертируем в секунды
        
        % Определяем полный временной диапазон
        full_start = chosen_time_interval(1) - time_back;
        full_end = chosen_time_interval(2);
        full_range = full_end - full_start;
        
        % Текущий зум диапазон
        current_zoom_range = (zoom_end_rel - zoom_start_rel) * full_range;
        
        % Коэффициент зума
        zoom_factor = 0.1; % 10% за один шаг колеса
        
        if eventdata.VerticalScrollCount > 0
            % Скролл вниз - увеличиваем зум (уменьшаем область)
            new_zoom_range = current_zoom_range * (1 - zoom_factor);
        else
            % Скролл вверх - уменьшаем зум (увеличиваем область)
            new_zoom_range = current_zoom_range * (1 + zoom_factor);
        end
        
        % Ограничиваем минимальный и максимальный зум
        min_range = full_range * 0.05; % минимум 5% от полного диапазона
        max_range = full_range; % максимум = полный диапазон
        new_zoom_range = max(min_range, min(max_range, new_zoom_range));
        
        % Если достигли максимума - сбрасываем зум
        if new_zoom_range >= max_range
            resetZoom();
            return;
        end
        
        % Позиция курсора относительно текущего зума
        current_zoom_start = full_start + zoom_start_rel * full_range;
        current_zoom_end = full_start + zoom_end_rel * full_range;
        cursor_rel = (cursor_time - current_zoom_start) / (current_zoom_end - current_zoom_start);
        cursor_rel = max(0, min(1, cursor_rel)); % Ограничиваем 0-1
        
        % Новые границы зума с центром в позиции курсора
        new_zoom_start = cursor_time - cursor_rel * new_zoom_range;
        new_zoom_end = new_zoom_start + new_zoom_range;
        
        % Ограничиваем границами данных
        if new_zoom_start < full_start
            new_zoom_start = full_start;
            new_zoom_end = new_zoom_start + new_zoom_range;
        end
        if new_zoom_end > full_end
            new_zoom_end = full_end;
            new_zoom_start = new_zoom_end - new_zoom_range;
        end
        
        % Конвертируем в относительные координаты
        zoom_start_rel = (new_zoom_start - full_start) / full_range;
        zoom_end_rel = (new_zoom_end - full_start) / full_range;
        
        % Обновляем график
        updateNavigationStatus();
        updatePlotAndCalculation();
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
        
        % Всегда сохраняем текущие границы амплитуды
        if isempty(original_ylim)
            % Если original_ylim пустой, берем текущие границы
            axes(hPlotAxes);
            metadata.original_ylim = ylim(hPlotAxes);
        else
            metadata.original_ylim = original_ylim;
        end
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
        
        % Добавляем результат в структуру
        new_result = struct('baseline_value', baseline_value, 'slope_value', slope_value, ...
                           'peak_time', peak_time, 'peak_value', peak_value, ...
                           'onset_time', onset_time, 'onset_value', onset_value, 'onset_method', onset_method, ...
                           'metadata', metadata);
        slope_measurement_results = [slope_measurement_results, new_result];
        
        % Обновляем таблицу
        updateResultsTable();
        
        fprintf('✓ Результат добавлен в таблицу (всего: %d)\n', length(slope_measurement_results));
    end
    
    function removeResult(~, ~)
        % Удаляет выделенный результат из таблицы
        
        % Получаем выделенную строку из таблицы
        if ~isempty(selected_row_slope) && selected_row_slope <= length(slope_measurement_results)
            % Удаляем результат
            slope_measurement_results(selected_row_slope) = [];
            
            % Обновляем таблицу
            updateResultsTable();
            
            fprintf('✓ Результат #%d удален из таблицы\n', selected_row_slope);
            
            % Сбрасываем выделение
            selected_row_slope = [];
        else
            % Fallback: если нет выделенной строки, удаляем последний результат
            if ~isempty(slope_measurement_results)
                last_index = length(slope_measurement_results);
                slope_measurement_results(last_index) = [];
                
                % Обновляем таблицу
                updateResultsTable();
                
                fprintf('✓ Последний результат #%d удален из таблицы\n', last_index);
            else
                fprintf('❌ Нет результатов для удаления\n');
            end
        end
        
        % Сбрасываем средний сигнал при удалении результатов
        if mean_results_active
            mean_results_active = false;
            mean_signal_data = [];
            mean_signal_time = [];
            set(hMeanResultsBtn, 'String', 'Mean Results');
            updateButtonStates();
            updatePlotAndCalculation();
        end
    end
    
    function saveResults(~, ~)
        % Сохраняет результаты в Excel файл и метаданные в .meta файл
        
        if isempty(slope_measurement_results)
            fprintf('❌ Нет результатов для сохранения\n');
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
            fprintf('❌ Сохранение отменено\n');
            return;
        end
        
        % Получаем базовое имя файла без расширения
        [~, basename, ~] = fileparts(filename);
        excel_path = fullfile(pathname, filename);
        meta_path = fullfile(pathname, [basename, '.meta']);
        
        try
            % Подготавливаем данные для Excel
            excel_data = cell(length(slope_measurement_results) + 1, 9);
            
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
                
                excel_data{i+1, 1} = slope_measurement_results(i).slope_value;
                excel_data{i+1, 2} = peak_time_rel;
                excel_data{i+1, 3} = peak_time_abs;
                excel_data{i+1, 4} = slope_measurement_results(i).peak_value;
                excel_data{i+1, 5} = onset_time_rel;
                excel_data{i+1, 6} = onset_time_abs;
                excel_data{i+1, 7} = slope_measurement_results(i).baseline_value;
                excel_data{i+1, 8} = metadata.channel;
                excel_data{i+1, 9} = getNavigationStatusText(metadata);
            end
            
            % Сохраняем Excel файл
            writecell(excel_data, excel_path);
            
            % Сохраняем метаданные в .meta файл (фактически .mat формат)
            save(meta_path, 'slope_measurement_results', 'multiple_measurements', '-v7.3');
            
            fprintf('✓ Результаты сохранены:\n');
            fprintf('  Excel: %s\n', excel_path);
            fprintf('  Metadata: %s\n', meta_path);
            fprintf('  Всего записей: %d\n', length(slope_measurement_results));
            
        catch ME
            fprintf('❌ Ошибка при сохранении: %s\n', ME.message);
        end
    end
    
    function updateResultsTable()
        % Обновляет отображение таблицы результатов
        
        if isempty(slope_measurement_results)
            set(hResultsTable, 'Data', {});
            % Деактивируем кнопку Mean Results
            set(hMeanResultsBtn, 'Enable', 'off');
            return;
        end
        
        % Подготавливаем данные для таблицы
        table_data = cell(length(slope_measurement_results), 9);
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
            
            table_data{i, 1} = slope_measurement_results(i).slope_value; % slope
            table_data{i, 2} = peak_time_rel; % peak time relative
            table_data{i, 3} = peak_time_abs; % peak time absolute
            table_data{i, 4} = slope_measurement_results(i).peak_value; % peak amplitude
            table_data{i, 5} = onset_time_rel; % onset time relative
            table_data{i, 6} = onset_time_abs; % onset time absolute
            table_data{i, 7} = slope_measurement_results(i).baseline_value; % baseline
            table_data{i, 8} = metadata.channel; % channel number
            table_data{i, 9} = getNavigationStatusText(metadata); % info
        end
        
        set(hResultsTable, 'Data', table_data);
        
        % Активируем кнопку Mean Results если есть результаты
        set(hMeanResultsBtn, 'Enable', 'on');
    end
    
    function tableSelectionChanged(~, event)
        % Обработчик изменения выделения в таблице
        
        if isempty(event.Indices)
            selected_row_slope = [];
            return;
        end
        
        selected_row_slope = event.Indices(1);
        if selected_row_slope <= length(slope_measurement_results)
            % Автоматически выходим из режима среднего сигнала
            if mean_results_active
                mean_results_active = false;
                mean_signal_data = [];
                mean_signal_time = [];
                set(hMeanResultsBtn, 'String', 'Mean Results');
                updateButtonStates();
            end
            
            % Восстанавливаем состояние из метаданных
            restoreStateFromMetadata(selected_row_slope);
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
        
        % Восстанавливаем временной интервал
        chosen_time_interval = metadata.chosen_time_interval;
        
        % Восстанавливаем зум
        zoom_active = metadata.zoom_active;
        zoom_start_rel = metadata.zoom_start_rel;
        zoom_end_rel = metadata.zoom_end_rel;
        zoom_y_min = metadata.zoom_y_min;
        zoom_y_max = metadata.zoom_y_max;
        original_ylim = metadata.original_ylim;
        
        % Восстанавливаем границы амплитуды если они были сохранены и зум не был применен
        if ~isempty(original_ylim) && length(original_ylim) == 2 && ~zoom_active
            axes(hPlotAxes);
            ylim(original_ylim);
        end
        
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
        if strcmp(selectedCenter, 'stimulus') && stims_exist && ~isempty(stims)
            rel_shift = stims(stim_inx);
        else
            rel_shift = chosen_time_interval(1);
        end
        
        set(hBaselineStartEdit, 'String', sprintf('%.3f', (slope_measurement_settings.baseline_start - rel_shift) * timeUnitFactor));
        set(hBaselineEndEdit, 'String', sprintf('%.3f', (slope_measurement_settings.baseline_end - rel_shift) * timeUnitFactor));
        set(hPeakStartEdit, 'String', sprintf('%.3f', (slope_measurement_settings.peak_start - rel_shift) * timeUnitFactor));
        set(hPeakEndEdit, 'String', sprintf('%.3f', (slope_measurement_settings.peak_end - rel_shift) * timeUnitFactor));
        
        % Обновляем кнопку зума
        zoomBtn = findobj(slopeFig, 'Style', 'pushbutton', 'Callback', @toggleZoom);
        if ~isempty(zoomBtn)
            if zoom_active
                set(zoomBtn, 'String', 'Reset Zoom');
            else
                set(zoomBtn, 'String', 'Zoom');
            end
        end
        
        % Если был применен зум, обновляем статус навигации
        if zoom_active
            updateNavigationStatus();
        end
        
        % Обновляем график и статус
        updateNavigationStatus();
        updatePlotAndCalculation();
        
        % Пересчитываем значения измерений при восстановлении состояния
        for i = 1:length(multiple_measurements)
            calculateMeasurementValue(i);
        end
        updateMeasurementsTable();
        
        % Сбрасываем флаг восстановления
        restoring_from_metadata = false;
        
        fprintf('✓ Состояние восстановлено из результата #%d\n', row_index);
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
            fprintf('❌ Нет результатов для усреднения\n');
            return;
        end
        
        mean_results_active = ~mean_results_active;
        
        if mean_results_active
            % Вычисляем средний сигнал
            [mean_signal_data, mean_signal_time] = calculateMeanSignal();
            set(hMeanResultsBtn, 'String', 'Show Single');
            fprintf('✓ Режим среднего сигнала включен (%d результатов)\n', length(slope_measurement_results));
        else
            % Сбрасываем средний сигнал
            mean_signal_data = [];
            mean_signal_time = [];
            set(hMeanResultsBtn, 'String', 'Mean Results');
            fprintf('✓ Режим одиночного сигнала включен\n');
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
            set(hRemoveBtn, 'Enable', 'off');
        else
            % Активируем кнопки при показе одиночного сигнала
            set(hPrevBtn, 'Enable', 'on');
            set(hNextBtn, 'Enable', 'on');
            set(hAddBtn, 'Enable', 'on');
            set(hRemoveBtn, 'Enable', 'on');
        end
    end
    

    % === Функции для множественных измерений ===
    
    function addMeasurement(~, ~)
        % Добавляет новое измерение с интерактивными курсорами
        
        % Получаем текущие данные
        [channel_data, time_in] = getCurrentData();
        if isempty(channel_data) || isempty(time_in)
            fprintf('❌ Нет данных для измерения\n');
            return;
        end
        
        % Вычисляем начальные позиции для нового диапазона (в относительном времени)
        time_range = max(time_in) - min(time_in);
        range_start_rel = time_range * 0.3;
        range_end_rel = time_range * 0.7;
        
        % Создаем новое измерение с настройками по умолчанию
        colors = {'r', 'g', 'b', 'm', 'c', 'y'};
        color_idx = mod(length(multiple_measurements), length(colors)) + 1;
        
        new_measurement = struct('range_start_rel', range_start_rel, 'range_end_rel', range_end_rel, ...
                               'measurement_value', NaN, 'metadata', struct(), ...
                               'function_type', 'Mean', 'line_color', colors{color_idx}, ...
                               'line_style', ':', 'line_width', 2, ...
                               'label_text', sprintf('M%d', length(multiple_measurements) + 1), ...
                               'label_background', 'white', 'font_size', 10);
        
        % Добавляем в глобальный массив
        multiple_measurements = [multiple_measurements, new_measurement];
        
        % Вычисляем значение измерения
        calculateMeasurementValue(length(multiple_measurements));
        
        % Обновляем отображение
        updateMeasurementsTable();
        updateMeasurementCursors();
        
        fprintf('✓ Добавлено измерение #%d (диапазон: %.3f - %.3f)\n', ...
            length(multiple_measurements), range_start_rel, range_end_rel);
    end
    
    function removeMeasurement(~, ~)
        % Удаляет выделенное измерение или последнее добавленное
        
        if isempty(multiple_measurements)
            fprintf('❌ Нет измерений для удаления\n');
            return;
        end
        
        % Определяем какое измерение удалять
        if ~isempty(selected_measurement_row) && selected_measurement_row <= length(multiple_measurements)
            % Удаляем выделенное измерение
            remove_index = selected_measurement_row;
            fprintf('✓ Удалено выделенное измерение #%d\n', remove_index);
        else
            % Удаляем последнее измерение
            remove_index = length(multiple_measurements);
            fprintf('✓ Удалено последнее измерение #%d\n', remove_index);
        end
        
        % Удаляем измерение
        multiple_measurements(remove_index) = [];
        
        % Удаляем соответствующие курсоры
        if ~isempty(measurement_cursors) && length(measurement_cursors) >= 3
            % Вычисляем индекс курсоров для удаляемого измерения
            cursor_start_idx = (remove_index - 1) * 3 + 1;
            cursor_end_idx = remove_index * 3;
            
            % Удаляем курсоры в обратном порядке, чтобы индексы не сдвигались
            for i = cursor_end_idx:-1:cursor_start_idx
                if i <= length(measurement_cursors) && ishandle(measurement_cursors(i))
                    delete(measurement_cursors(i));
                end
            end
            
            % Удаляем элементы из массива курсоров
            measurement_cursors(cursor_start_idx:cursor_end_idx) = [];
        end
        
        % Сбрасываем выделение
        selected_measurement_row = [];
        
        % Обновляем отображение
        updateMeasurementsTable();
        updateMeasurementCursors();
    end
    
    function calculateMeasurementValue(measurement_index)
        % Вычисляет значение измерения для заданного индекса
        
        if measurement_index > length(multiple_measurements)
            return;
        end
        
        % Получаем данные
        [channel_data, time_in] = getCurrentData();
        if isempty(channel_data) || isempty(time_in)
            return;
        end
        
        % Получаем диапазон измерения (в относительном времени)
        range_start_rel = multiple_measurements(measurement_index).range_start_rel;
        range_end_rel = multiple_measurements(measurement_index).range_end_rel;
        
        % Используем относительные координаты (от 0)
        % range_start_rel и range_end_rel уже в относительном времени
        range_start = range_start_rel;
        range_end = range_end_rel;
        
        % Нормализуем время используя rel_shift (как в основном коде)
        if strcmp(selectedCenter, 'stimulus') && stims_exist && ~isempty(stims)
            rel_shift = stims(stim_inx);
        else
            rel_shift = time_in(1);
        end
        time_in_rel = time_in - rel_shift;
        
        % Вычисляем измерение через соответствующую функцию
        function_type = multiple_measurements(measurement_index).function_type;
        
        if strcmp(function_type, 'Slope')
            % Для Slope нужны дополнительные параметры baseline
            % Создаем структуру baseline_data с текущими настройками slope measurement
            % Нормализуем времена baseline относительно rel_shift
            baseline_data_struct = struct();
            baseline_data_struct.baseline_start = slope_measurement_settings.baseline_start - rel_shift;
            baseline_data_struct.baseline_end = slope_measurement_settings.baseline_end - rel_shift;
            baseline_data_struct.peak_start = slope_measurement_settings.peak_start - rel_shift;
            baseline_data_struct.peak_end = slope_measurement_settings.peak_end - rel_shift;
            baseline_data_struct.slope_percent = slope_measurement_settings.slope_percent;
            baseline_data_struct.peak_polarity = slope_measurement_settings.peak_polarity;
            
            [measurement_value, measurement_metadata] = calculateMeasurementByType(channel_data, time_in_rel, range_start, range_end, function_type, baseline_data_struct);
        else
            % Для остальных типов измерений
            [measurement_value, measurement_metadata] = calculateMeasurementByType(channel_data, time_in_rel, range_start, range_end, function_type);
        end
        
        % Сохраняем результат
        multiple_measurements(measurement_index).measurement_value = measurement_value;
        multiple_measurements(measurement_index).metadata = measurement_metadata;
    end
    
    function updateMeasurementsTable()
        % Обновляет таблицу измерений
        
        if isempty(multiple_measurements)
            set(hMeasurementsTable, 'Data', {});
            return;
        end
        
        % Подготавливаем данные для таблицы
        table_data = cell(length(multiple_measurements), 3);
        for i = 1:length(multiple_measurements)
            range_start_rel = multiple_measurements(i).range_start_rel;
            range_end_rel = multiple_measurements(i).range_end_rel;
            measurement_value = multiple_measurements(i).measurement_value;
            
            % Форматируем диапазон (в относительном времени)
            range_text = sprintf('%.1f-%.1f', range_start_rel * timeUnitFactor, range_end_rel * timeUnitFactor);
            
            table_data{i, 1} = range_text; % Range
            table_data{i, 2} = measurement_value; % Value
            table_data{i, 3} = multiple_measurements(i).function_type(1); % Type (первая буква функции)
        end
        
        set(hMeasurementsTable, 'Data', table_data);
    end
    
    function updateMeasurementCursors()
        % Обновляет отображение курсоров измерений на графике
        
        % Удаляем старые курсоры
        for i = 1:length(measurement_cursors)
            if ishandle(measurement_cursors(i))
                delete(measurement_cursors(i));
            end
        end
        measurement_cursors = [];
        
        if isempty(multiple_measurements)
            return;
        end
        
        % Устанавливаем текущие оси
        axes(hPlotAxes);
        
        % Получаем границы осей
        ylims = ylim(hPlotAxes);
        
        % Создаем новые курсоры для каждого измерения
        for i = 1:length(multiple_measurements)
            range_start_rel = multiple_measurements(i).range_start_rel;
            range_end_rel = multiple_measurements(i).range_end_rel;
            
            % Конвертируем в отображаемые координаты (всегда в относительном времени)
            t_start = range_start_rel * timeUnitFactor;
            t_end = range_end_rel * timeUnitFactor;
            
            % Получаем настройки измерения
            line_color = multiple_measurements(i).line_color;
            line_style = multiple_measurements(i).line_style;
            line_width = multiple_measurements(i).line_width;
            label_text = multiple_measurements(i).label_text;
            label_background = multiple_measurements(i).label_background;
            font_size = multiple_measurements(i).font_size;
            
            % Линия начала диапазона
            h_start = line([t_start, t_start], ylims, 'Color', line_color, ...
                          'LineWidth', line_width, 'LineStyle', line_style);
            
            % Линия конца диапазона
            h_end = line([t_end, t_end], ylims, 'Color', line_color, ...
                        'LineWidth', line_width, 'LineStyle', line_style);
            
            % Делаем курсоры перетаскиваемыми
            set(h_start, 'ButtonDownFcn', @(src,evt)startDragMeasurement(src,evt,i,'start'));
            set(h_end, 'ButtonDownFcn', @(src,evt)startDragMeasurement(src,evt,i,'end'));
            
            % Подписи диапазонов
            h_label = text(t_start, ylims(1) + (ylims(2) - ylims(1)) * 0.05, label_text, ...
                 'HorizontalAlignment', 'center', 'Color', line_color, 'FontWeight', 'bold', ...
                 'FontSize', font_size, 'BackgroundColor', label_background);
            
            % Добавляем в массив курсоров (включая подписи)
            measurement_cursors = [measurement_cursors, h_start, h_end, h_label];
        end
    end
    
    function startDragMeasurement(src, ~, measurement_index, cursor_type)
        % Начинает перетаскивание курсора измерения
        set(slopeFig, 'WindowButtonMotionFcn', @(s,e)dragMeasurementCursor(s,e,measurement_index,cursor_type));
        set(slopeFig, 'WindowButtonUpFcn', @stopDragMeasurement);
    end
    
    function dragMeasurementCursor(~, ~, measurement_index, cursor_type)
        % Перетаскивание курсора измерения
        pt = get(hPlotAxes, 'CurrentPoint');
        new_time_rel = pt(1,1) / timeUnitFactor; % Конвертируем обратно в секунды (относительное время)
        
        % Получаем текущие данные для определения границ
        [channel_data, time_in] = getCurrentData();
        if ~isempty(time_in)
            time_range = max(time_in) - min(time_in);
            new_time_rel = min(time_range, new_time_rel);
        end
        
        % Обновляем позицию курсора (в относительном времени)
        if strcmp(cursor_type, 'start')
            multiple_measurements(measurement_index).range_start_rel = new_time_rel;
        else % 'end'
            multiple_measurements(measurement_index).range_end_rel = new_time_rel;
        end
        
        % Убеждаемся что начало < конец
        if multiple_measurements(measurement_index).range_start_rel >= multiple_measurements(measurement_index).range_end_rel
            if strcmp(cursor_type, 'start')
                multiple_measurements(measurement_index).range_start_rel = multiple_measurements(measurement_index).range_end_rel - 0.001;
            else
                multiple_measurements(measurement_index).range_end_rel = multiple_measurements(measurement_index).range_start_rel + 0.001;
            end
        end
        
        % Обновляем только позиции курсоров без пересчета
        updateMeasurementCursorPositions();
    end
    
    function stopDragMeasurement(~, ~)
        % Завершает перетаскивание курсора измерения
        set(slopeFig, 'WindowButtonMotionFcn', '');
        set(slopeFig, 'WindowButtonUpFcn', '');
        
        % Пересчитываем значения измерений
        for i = 1:length(multiple_measurements)
            calculateMeasurementValue(i);
        end
        
        % Обновляем отображение
        updateMeasurementsTable();
        
        % ПЕРЕРИСОВЫВАЕМ ГРАФИК С НОВЫМИ ОБЪЕКТАМИ ВИЗУАЛИЗАЦИИ
        updatePlotAndCalculation();
    end
    
    function updateMeasurementCursorPositions()
        % Обновляет только позиции курсоров измерений без пересчета
        if isempty(measurement_cursors)
            return;
        end
        
        % Устанавливаем текущие оси
        axes(hPlotAxes);
        
        % Получаем границы осей
        ylims = ylim(hPlotAxes);
        
        % Обновляем позиции для каждого измерения
        for i = 1:length(multiple_measurements)
            range_start_rel = multiple_measurements(i).range_start_rel;
            range_end_rel = multiple_measurements(i).range_end_rel;
            
            % Конвертируем в отображаемые координаты (всегда в относительном времени)
            t_start = range_start_rel * timeUnitFactor;
            t_end = range_end_rel * timeUnitFactor;
            
            % Обновляем позиции линий и подписей (каждое измерение имеет 3 элемента: 2 линии + 1 подпись)
            cursor_idx = (i-1) * 3 + 1;
            if cursor_idx <= length(measurement_cursors) && ishandle(measurement_cursors(cursor_idx))
                set(measurement_cursors(cursor_idx), 'XData', [t_start, t_start], 'YData', ylims);
            end
            if cursor_idx + 1 <= length(measurement_cursors) && ishandle(measurement_cursors(cursor_idx + 1))
                set(measurement_cursors(cursor_idx + 1), 'XData', [t_end, t_end], 'YData', ylims);
            end
            if cursor_idx + 2 <= length(measurement_cursors) && ishandle(measurement_cursors(cursor_idx + 2))
                set(measurement_cursors(cursor_idx + 2), 'Position', [t_start, ylims(1) + (ylims(2) - ylims(1)) * 0.05, 0]);
            end
        end
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
            
            % Фильтрация если включена
            if sum(filter_avaliable) > 0 && filter_avaliable(selected_channel)
                channel_data = applyFilter(channel_data, filterSettings, newFs);
            end
            
            % Ресэмплинг если нужен
            if Fs ~= newFs
                lfp_Fs = round(newFs);
                channel_data = resample(double(channel_data), lfp_Fs, Fs);
                time_in = linspace(time_in(1), time_in(end), length(channel_data));
            end
        end
    end
    
    function measurementTableSelectionChanged(~, event)
        % Обработчик изменения выделения в таблице измерений
        
        if isempty(event.Indices)
            selected_measurement_row = [];
            return;
        end
        
        selected_measurement_row = event.Indices(1);
        if selected_measurement_row <= length(multiple_measurements)
            fprintf('✓ Выбрано измерение #%d\n', selected_measurement_row);
        end
    end
    
    function openMeasurementProperties(~, ~)
        % Открывает окно свойств для выделенного измерения
        
        if isempty(selected_measurement_row) || selected_measurement_row > length(multiple_measurements)
            fprintf('❌ Выберите измерение для редактирования свойств\n');
            return;
        end
        
        % Открываем окно свойств измерения
        measurementPropertiesGUI(selected_measurement_row);
        
        % После закрытия окна обновляем отображение
        if ~isempty(selected_measurement_row) && selected_measurement_row <= length(multiple_measurements)
            % Пересчитываем значение измерения с новыми настройками
            calculateMeasurementValue(selected_measurement_row);
            
            % Обновляем отображение
            updateMeasurementsTable();
            updateMeasurementCursors();
            
            fprintf('OK: Отображение обновлено после изменения свойств\n');
        end
    end
    
    function autoMeasureAllTimeRanges(~, ~)
        % Автоматически измеряет все временные участки и заполняет таблицу
        % Аналогично тому, как пользователь нажимает Next + Add в цикле
        
        % Сохраняем текущее состояние
        original_interval = chosen_time_interval;
        original_stim_inx = stim_inx;
        original_sweep_inx = sweep_inx;
        
        % Определяем количество участков в зависимости от режима
        switch selectedCenter
            case 'stimulus'
                if stims_exist && ~isempty(stims)
                    total_ranges = length(stims);
                    fprintf('Автоматическое измерение %d стимулов...\n', total_ranges);
                else
                    fprintf('ERROR: Нет стимулов для измерения\n');
                    return;
                end
                
            case 'sweep'
                if isstruct(sweep_info) && sweep_info.is_sweep_data
                    total_ranges = sweep_info.sweep_count;
                    fprintf('Автоматическое измерение %d sweepов...\n', total_ranges);
                else
                    fprintf('ERROR: Нет sweep данных для измерения\n');
                    return;
                end
                
            case 'time'
                % Для режима time вычисляем количество возможных шагов
                windowSize = chosen_time_interval(2) - chosen_time_interval(1);
                if windowSize <= 0
                    fprintf('ERROR: Некорректный размер временного окна\n');
                    return;
                end
                total_ranges = floor((time(end) - time(1)) / windowSize);
                if total_ranges <= 0
                    fprintf('ERROR: Недостаточно данных для измерения\n');
                    return;
                end
                fprintf('Автоматическое измерение %d временных участков...\n', total_ranges);
                
            otherwise
                fprintf('ERROR: Неподдерживаемый режим навигации\n');
                return;
        end
        
        % Сохраняем относительные позиции текущих диапазонов
        [baseline_rel, peak_rel] = getRelativePositions();
        
        % Получаем размер окна из текущего интервала
        windowSize = chosen_time_interval(2) - chosen_time_interval(1);
        
        % Циклически измеряем каждый участок
        for i = 1:total_ranges
            fprintf('Измерение участка %d/%d...\n', i, total_ranges);
            
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
            
            % Вычисляем результаты для текущего участка
            [slope_value, slope_angle, peak_time, peak_value, baseline_value, onset_time, onset_value, measurement_metadata] = calculateResults();
            
            % Автоматически добавляем результат в таблицу
            addResult();
            
            % Обновляем UI
            drawnow;
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
        
        % Обновляем статус навигации
        updateNavigationStatus();
        
        % Обновляем график
        updatePlotAndCalculation();
        
        fprintf('SUCCESS: Автоматическое измерение завершено! Добавлено %d результатов\n', total_ranges);
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
            fprintf('❌ Загрузка отменена\n');
            return;
        end
        
        filepath = fullfile(pathname, filename);
        
        try
            % Загружаем данные из файла (фактически .mat файл с расширением .meta)
            loaded_data = load(filepath, '-mat');
            
            % Загружаем основные результаты
            slope_measurement_results = loaded_data.slope_measurement_results;
            
            % Загружаем множественные измерения
            multiple_measurements = loaded_data.multiple_measurements;
            
            % Очищаем курсоры измерений
            if ~isempty(measurement_cursors)
                for i = 1:length(measurement_cursors)
                    if ishandle(measurement_cursors(i))
                        delete(measurement_cursors(i));
                    end
                end
                measurement_cursors = [];
            end
            
            % Сбрасываем выделения
            selected_row_slope = [];
            selected_measurement_row = [];
            
            % Обновляем отображение
            updateResultsTable();
            updateMeasurementsTable();
            updateMeasurementCursors();
            
            fprintf('✓ Результаты загружены из файла:\n');
            fprintf('  Файл: %s\n', filepath);
            fprintf('  Результатов: %d\n', length(slope_measurement_results));
            fprintf('  Измерений: %d\n', length(multiple_measurements));
            
            % Восстанавливаем состояние первого результата если есть
            if ~isempty(slope_measurement_results)
                restoreStateFromMetadata(1);
            end
            
        catch ME
            fprintf('❌ Ошибка при загрузке: %s\n', ME.message);
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
                
                % Очищаем все множественные измерения
                multiple_measurements = [];
                
                % Очищаем курсоры измерений
                if ~isempty(measurement_cursors)
                    for i = 1:length(measurement_cursors)
                        if ishandle(measurement_cursors(i))
                            delete(measurement_cursors(i));
                        end
                    end
                    measurement_cursors = [];
                end
                
                % Сбрасываем выделения
                selected_row_slope = [];
                selected_measurement_row = [];
                
                % Сбрасываем средний сигнал
                mean_results_active = false;
                mean_signal_data = [];
                mean_signal_time = [];
                
                % Обновляем отображение
                updateResultsTable();
                updateMeasurementsTable();
                updateMeasurementCursors();
                
                % Обновляем состояние кнопок
                updateButtonStates();
                
                % Обновляем график
                updatePlotAndCalculation();
                
                fprintf('✓ Все результаты и измерения очищены\n');
                
            case 'No'
                % Пользователь отменил операцию
                return;
        end
    end

end 