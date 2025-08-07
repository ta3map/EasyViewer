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
    end
    
    % Инициализация переменной для выделенной строки
    selected_row_slope = [];
    
    % Идентификатор (tag) для GUI фигуры
    figTag = 'SlopeMeasurement';
    
    % Поиск открытой фигуры с заданным идентификатором
    guiFig = findobj('Type', 'figure', 'Tag', figTag);
    
    if ~isempty(guiFig)
        % Делаем существующее окно текущим (активным)
        figure(guiFig);
        return
    end
    
    % Создание главного окна (увеличиваем размер для таблицы)
    slopeFig = figure('Name', 'Slope Measurement', 'Tag', figTag, ...
        'Resize', 'off', ...
        'NumberTitle', 'off', 'MenuBar', 'none', 'ToolBar', 'none', ...
        'Position', [100, 100, 1200, 600]);

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
    
    % Кнопка добавления результата
    hAddBtn = uicontrol(slopeFig, 'Style', 'pushbutton', 'String', 'Add', ...
        'Position', [170, 5, 70, 25], 'Callback', @addResult);
    
    % Кнопка удаления результата
    hRemoveBtn = uicontrol(slopeFig, 'Style', 'pushbutton', 'String', 'Remove', ...
        'Position', [245, 5, 70, 25], 'Callback', @removeResult);
    
    % Кнопка сохранения результатов
    uicontrol(slopeFig, 'Style', 'pushbutton', 'String', 'Save', ...
        'Position', [320, 5, 70, 25], 'Callback', @saveResults);
    
    % Кнопка просмотра среднего сигнала
    hMeanResultsBtn = uicontrol(slopeFig, 'Style', 'pushbutton', 'String', 'Mean Results', ...
        'Position', [395, 5, 70, 25], 'Callback', @toggleMeanResults, 'Enable', 'off');
    
        
    
    % === График ===
    hPlotAxes = axes('Position', [0.35, 0.15, 0.45, 0.75]);
    
    % Кнопка зума в левом углу графика
    hZoomButton = uicontrol(slopeFig, 'Style', 'pushbutton', 'String', 'Zoom', ...
        'Position', [320, 510, 100, 30], 'Callback', @toggleZoom);
    
    % === Таблица результатов ===
    % Заголовок таблицы
    uicontrol(slopeFig, 'Style', 'text', 'Position', [980, 510, 200, 25], ...
        'String', 'Results Table', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
    
    % Таблица результатов
    hResultsTable = uitable(slopeFig, 'Position', [980, 50, 200, 500], ...
        'ColumnName', {'Slope', 'Baseline', 'Onset', 'Ch', 'Mode'}, ...
        'ColumnWidth', {70, 70, 70, 30, 120}, ...
        'ColumnFormat', {'numeric', 'numeric', 'numeric', 'numeric', 'char'}, ...
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
    
%     function updateOnsetThresholdVisibility()
%         % Обновляет видимость поля порога в зависимости от выбранного метода
%         if strcmp(slope_measurement_settings.onset_method, 'threshold_crossing') || strcmp(slope_measurement_settings.onset_method, 'inverted_peak')
%             % Показываем поле порога для методов Threshold Crossing и Inverted Peak
%             set(hOnsetThresholdLabel, 'Visible', 'on');
%             set(hOnsetThresholdEdit, 'Visible', 'on');
%             set(hOnsetThresholdUnit, 'Visible', 'on');
%         else
%             % Скрываем поле порога для методов First Derivative и Second Derivative
%             set(hOnsetThresholdLabel, 'Visible', 'off');
%             set(hOnsetThresholdEdit, 'Visible', 'off');
%             set(hOnsetThresholdUnit, 'Visible', 'off');
%         end
%     end
    

    
    function updatePlotAndCalculation()
        % Проверяем, нужно ли использовать средний сигнал
        if mean_results_active && ~isempty(mean_signal_data) && ~isempty(mean_signal_time)
            % Используем средний сигнал
            channel_data = mean_signal_data;
            time_in = mean_signal_time;
            
            fprintf('DEBUG: updatePlotAndCalculation - режим среднего сигнала\n');
            fprintf('DEBUG: Размер channel_data: %s, time_in: %s\n', ...
                mat2str(size(channel_data)), mat2str(size(time_in)));
            fprintf('DEBUG: Начало channel_data: [%.6f, %.6f, %.6f]\n', ...
                channel_data(1:min(3, length(channel_data))));
            fprintf('DEBUG: Начало time_in: [%.3f, %.3f, %.3f]\n', ...
                time_in(1:min(3, length(time_in))));
            
            % В режиме среднего сигнала время уже нормализовано, используем его как есть
            % rel_shift = 0; % Не применяем дополнительный сдвиг
            
            fprintf('DEBUG: rel_shift = %.3f (не применяется для среднего сигнала)\n', rel_shift);
            fprintf('DEBUG: timeUnitFactor = %.3f\n', timeUnitFactor);
            
            % Преобразование времени с учетом единиц (без дополнительного сдвига)
            time_display = time_in * timeUnitFactor;
            
            fprintf('DEBUG: Начало time_display: [%.3f, %.3f, %.3f]\n', ...
                time_display(1:min(3, length(time_display))));
        else
            % Получаем данные текущего временного интервала (аналогично updatePlot.m)
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
                % В режиме stimulus используем время стимула как относительный нуль
                rel_shift = stims(stim_inx);
            else
                % В других режимах используем начало временного интервала
                rel_shift = time_in(1);
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
        
        fprintf('DEBUG: Рисуем график - размер time_display: %s, channel_data: %s\n', ...
            mat2str(size(time_display)), mat2str(size(channel_data)));
        fprintf('DEBUG: Диапазон time_display: [%.3f, %.3f]\n', min(time_display), max(time_display));
        fprintf('DEBUG: Диапазон channel_data: [%.6f, %.6f]\n', min(channel_data), max(channel_data));
        
        plot(time_display, channel_data, 'b-', 'LineWidth', 1);
        
        fprintf('DEBUG: График нарисован\n');
        
        % Проверяем границы осей
        xlims = xlim;
        ylims = ylim;
        fprintf('DEBUG: Границы осей - X: [%.3f, %.3f], Y: [%.6f, %.6f]\n', xlims(1), xlims(2), ylims(1), ylims(2));
        
        % Получаем параметры для расчета
        baseline_start = slope_measurement_settings.baseline_start;
        baseline_end = slope_measurement_settings.baseline_end;
        peak_start = slope_measurement_settings.peak_start;
        peak_end = slope_measurement_settings.peak_end;
        slope_percent = slope_measurement_settings.slope_percent;
        peak_polarity = slope_measurement_settings.peak_polarity;
        
        % В режиме среднего сигнала нормализуем времена, так как time_in уже нормализовано
        if mean_results_active && ~isempty(mean_signal_data) && ~isempty(mean_signal_time)
            % Вычисляем rel_shift для нормализации времен
            if strcmp(selectedCenter, 'stimulus') && stims_exist && ~isempty(stims)
                rel_shift_for_normalization = stims(stim_inx);
            else
                rel_shift_for_normalization = chosen_time_interval(1);
            end
            
            % Нормализуем времена
            baseline_start = baseline_start - rel_shift_for_normalization;
            baseline_end = baseline_end - rel_shift_for_normalization;
            peak_start = peak_start - rel_shift_for_normalization;
            peak_end = peak_end - rel_shift_for_normalization;
            
            fprintf('DEBUG: Нормализованные времена для среднего сигнала:\n');
            fprintf('  baseline: [%.3f, %.3f]\n', baseline_start, baseline_end);
            fprintf('  peak: [%.3f, %.3f]\n', peak_start, peak_end);
        end
        
        % Расчет baseline один раз
        [baseline_value, baseline_indices] = calculateBaseline(channel_data, time_in, baseline_start, baseline_end);
        
        % Вычисляем стандартное отклонение baseline для онсета
        if ~isempty(baseline_indices)
            baseline_data = channel_data(baseline_indices);
            baseline_std = std(baseline_data);
        else
            baseline_std = NaN;
        end
        
        % Расчет slope
        [slope_value, slope_angle, regression_points, peak_time, peak_value] = ...
            calculateSlope(channel_data, time_in, baseline_value, ...
                         peak_start, peak_end, slope_percent, peak_polarity);
        
        % Расчет онсета
        [onset_time, onset_value, onset_method] = calculateOnset(channel_data, time_in, ...
            baseline_value, baseline_std, peak_start, peak_end, ...
            slope_measurement_settings.onset_method, slope_measurement_settings.onset_threshold);
        
        % Применяем зум если активен
        if zoom_active && ~isnan(zoom_start_rel) && ~isnan(zoom_end_rel)
            % Зум по времени - используем ту же логику что и в applyZoom
            full_start = chosen_time_interval(1) - time_back;
            full_end = chosen_time_interval(2);
            full_range = full_end - full_start;
            
            % Проверяем что full_range положительный
            if full_range > 0
                zoom_start_abs = full_start + zoom_start_rel * full_range;
                zoom_end_abs = full_start + zoom_end_rel * full_range;
                
                % Проверяем что границы корректные
                if zoom_end_abs > zoom_start_abs
                    % Конвертируем в отображаемые координаты: (абсолютное_время - rel_shift) * timeUnitFactor
                    xlim([(zoom_start_abs - rel_shift) * timeUnitFactor, (zoom_end_abs - rel_shift) * timeUnitFactor]);
                else
                    % Если границы некорректные - сбрасываем зум
                    zoom_active = false;
                    zoom_start_rel = 0;
                    zoom_end_rel = 1;
                    zoom_y_min = [];
                    zoom_y_max = [];
                    full_start = (chosen_time_interval(1) - time_back - rel_shift) * timeUnitFactor;
                    full_end = (chosen_time_interval(2) - rel_shift) * timeUnitFactor;
                    xlim([full_start, full_end]);
                    
                    % Обновляем кнопку зума
                    zoomBtn = findobj(slopeFig, 'Style', 'pushbutton', 'Callback', @toggleZoom);
                    if ~isempty(zoomBtn)
                        set(zoomBtn, 'String', 'Zoom');
                    end
                end
            else
                % Если full_range некорректный - сбрасываем зум
                zoom_active = false;
                zoom_start_rel = 0;
                zoom_end_rel = 1;
                zoom_y_min = [];
                zoom_y_max = [];
                full_start = (chosen_time_interval(1) - time_back - rel_shift) * timeUnitFactor;
                full_end = (chosen_time_interval(2) - rel_shift) * timeUnitFactor;
                xlim([full_start, full_end]);
                
                % Обновляем кнопку зума
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
                    y_range = abs(y_min) * 0.1; % если данные постоянные, добавляем 10% от значения
                end
                y_padding = y_range * 0.05; % 5% запас сверху и снизу
                ylim([y_min - y_padding, y_max + y_padding]);
                
                fprintf('DEBUG: [Средний сигнал] Вычислены границы амплитуды - данные: [%.3f, %.3f], границы: [%.3f, %.3f]\n', ...
                    y_min, y_max, y_min - y_padding, y_max + y_padding);
            else
                % В обычном режиме используем стандартные границы времени
                full_start = (chosen_time_interval(1) - time_back - rel_shift) * timeUnitFactor;
                full_end = (chosen_time_interval(2) - rel_shift) * timeUnitFactor;
                xlim([full_start, full_end]);
                
                % Проверяем, есть ли уже сохраненные границы амплитуды (при восстановлении из метаданных)
                if restoring_from_metadata && ~isempty(original_ylim) && length(original_ylim) == 2
                    % Используем сохраненные границы вместо вычисления новых
                    ylim(original_ylim);
                    fprintf('DEBUG: [Обычный режим] Использованы сохраненные границы амплитуды: [%.3f, %.3f]\n', ...
                        original_ylim(1), original_ylim(2));
                else
                    % Вычисляем границы амплитуды с небольшим запасом
                    y_min = min(channel_data);
                    y_max = max(channel_data);
                    y_range = y_max - y_min;
                    if y_range == 0
                        y_range = abs(y_min) * 0.1; % если данные постоянные, добавляем 10% от значения
                    end
                    y_padding = y_range * 0.05; % 5% запас сверху и снизу
                    ylim([y_min - y_padding, y_max + y_padding]);
                    
                    % Сохраняем вычисленные границы как исходные для будущих сбросов зума
                    original_ylim = [y_min - y_padding, y_max + y_padding];
                    
                    fprintf('DEBUG: [Обычный режим] Вычислены границы амплитуды - данные: [%.3f, %.3f], границы: [%.3f, %.3f]\n', ...
                        y_min, y_max, y_min - y_padding, y_max + y_padding);
                end
            end
        end
        
        % Настройка относительного времени (как в updatePlot.m)
        xTicks = get(hPlotAxes, 'XTick');
        
        if ~isempty(xTicks)
            % Создаем относительные метки времени
            % newTicks = xTicks - xTicks(1) - time_back*timeUnitFactor;
            % newTicks(1) = xTicks(1); % Первый тик остается абсолютным
            % newTicks(abs(newTicks)<1e-4) = 0; % Убираем очень маленькие значения
            % newLabels = arrayfun(@num2str, newTicks, 'UniformOutput', false);
            % newLabels{1} = [newLabels{1}, ' ', selectedUnit]; % Добавляем единицы к первому тику
            
            % Применяем новые метки
            % set(hPlotAxes, 'XTickLabel', newLabels);
        end
        
        xlabel(['Time, ' selectedUnit]);
        ylabel('Amplitude');
        
        % Заголовок с указанием режима
        if mean_results_active
            title('Mean Signal (Average of All Results)');
        else
            title(['Channel: ' hd.recChNames{selected_channel}]);
        end
        
        grid on;
        
        % Отображение времени стимула вертикальной серой линией
        if stims_exist && ~isempty(stims)
            % Находим стимул, ближайший к центру текущего временного интервала
            interval_center = (chosen_time_interval(1) + chosen_time_interval(2)) / 2;
            [~, closest_stim_idx] = min(abs(stims - interval_center));
            stim_time = stims(closest_stim_idx);
            stim_time_display = (stim_time - rel_shift) * timeUnitFactor;
            line([stim_time_display, stim_time_display], ylims, 'Color', [0.5, 0.5, 0.5], 'LineWidth', 1, 'LineStyle', ':');
        end
        
        % Рисуем линии лимитов в самом конце, после установки всех лимитов
        ylims = ylim;
        
        % Отображение baseline диапазона (синие линии) - только если включено
        if slope_measurement_settings.show_baseline
            if mean_results_active && ~isempty(mean_signal_data) && ~isempty(mean_signal_time)
                % В режиме среднего сигнала времена уже нормализованы
                t_bl_start = baseline_start * timeUnitFactor;
                t_bl_end = baseline_end * timeUnitFactor;
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
                % В режиме среднего сигнала времена уже нормализованы
                t_pk_start = peak_start * timeUnitFactor;
                t_pk_end = peak_end * timeUnitFactor;
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
        
        % Отображение пика (красный маркер) - только если включено
        if slope_measurement_settings.show_peak && ~isnan(peak_time)
            if mean_results_active && ~isempty(mean_signal_data) && ~isempty(mean_signal_time)
                % В режиме среднего сигнала время пика уже нормализовано
                peak_time_display = peak_time * timeUnitFactor;
            else
                % В обычном режиме нормализуем относительно rel_shift
                peak_time_display = (peak_time - rel_shift) * timeUnitFactor;
            end
            hPeakMarker = plot(peak_time_display, peak_value, 'ro', 'MarkerSize', 10, 'MarkerFaceColor', 'r');
            text(peak_time_display, peak_value + (ylims(2) - ylims(1)) * 0.05, ...
                sprintf('Peak: %.3f', peak_time_display), ...
                'HorizontalAlignment', 'center', 'Color', 'r', 'FontWeight', 'bold');
        else
            hPeakMarker = [];
        end
        
        % Отображение онсета (фиолетовый маркер) - только если включено
        if slope_measurement_settings.show_onset && ~isnan(onset_time)
            if mean_results_active && ~isempty(mean_signal_data) && ~isempty(mean_signal_time)
                % В режиме среднего сигнала время онсета уже нормализовано
                onset_time_display = onset_time * timeUnitFactor;
            else
                % В обычном режиме нормализуем относительно rel_shift
                onset_time_display = (onset_time - rel_shift) * timeUnitFactor;
            end
            hOnsetMarker = plot(onset_time_display, onset_value, 'mo', 'MarkerSize', 8, 'MarkerFaceColor', 'm');
            text(onset_time_display, onset_value - (ylims(2) - ylims(1)) * 0.05, ...
                sprintf('Onset: %.3f', onset_time_display), ...
                'HorizontalAlignment', 'center', 'Color', 'm', 'FontWeight', 'bold');
        else
            hOnsetMarker = [];
        end
        
        % Отображение slope линии (черная линия) - только если включено
        if slope_measurement_settings.show_slope && ~isnan(regression_points.time1) && ~isnan(regression_points.time2)
            if mean_results_active && ~isempty(mean_signal_data) && ~isempty(mean_signal_time)
                % В режиме среднего сигнала времена уже нормализованы
                t_reg1 = regression_points.time1 * timeUnitFactor;
                t_reg2 = regression_points.time2 * timeUnitFactor;
            else
                % В обычном режиме нормализуем относительно rel_shift
                t_reg1 = (regression_points.time1 - rel_shift) * timeUnitFactor;
                t_reg2 = (regression_points.time2 - rel_shift) * timeUnitFactor;
            end
            hSlopeLine = line([t_reg1, t_reg2], [regression_points.value1, regression_points.value2], ...
                            'Color', 'k', 'LineWidth', 4);
            
            % Маркеры slope точек
            plot(t_reg1, regression_points.value1, 'ko', 'MarkerSize', 6, 'MarkerFaceColor', 'k');
            plot(t_reg2, regression_points.value2, 'ko', 'MarkerSize', 6, 'MarkerFaceColor', 'k');
        else
            hSlopeLine = [];
        end
        

        
        hold off;
        
        % Обновление результатов в текстовых полях
        if ~isnan(baseline_value)
            set(hBaselineText, 'String', sprintf('Baseline: %.3f', baseline_value));
        else
            set(hBaselineText, 'String', 'Baseline: -');
        end
        
        if ~isnan(peak_time) && ~isnan(peak_value)
            set(hPeakText, 'String', sprintf('Peak: (%.3f, %.3f)', peak_time * timeUnitFactor, peak_value));
        else
            set(hPeakText, 'String', 'Peak: (-, -)');
        end
        
        if ~isnan(slope_value)
            set(hSlopeText, 'String', sprintf('Slope: %.6f units/%s', slope_value, selectedUnit));
        else
            set(hSlopeText, 'String', 'Slope: -');
        end
        
        if ~isnan(slope_angle)
            set(hAngleText, 'String', sprintf('Angle: %.2f°', slope_angle));
        else
            set(hAngleText, 'String', 'Angle: -');
        end
        
        if ~isnan(onset_time) && ~isnan(onset_value)
            set(hOnsetText, 'String', sprintf('Onset: (%.3f, %.3f)', onset_time * timeUnitFactor, onset_value));
        else
            set(hOnsetText, 'String', 'Onset: (-, -)');
        end
        
        % Обновляем видимость текстовых полей в зависимости от настроек
        if slope_measurement_settings.show_baseline
            set(hBaselineText, 'Visible', 'on');
        else
            set(hBaselineText, 'Visible', 'off');
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
        
        if slope_measurement_settings.show_peak
            set(hPeakText, 'Visible', 'on');
        else
            set(hPeakText, 'Visible', 'off');
        end
        
        % Добавляем возможность перетаскивания для диапазонов
        makeDraggable();
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
        
        % Расчет baseline один раз
        [baseline_value, baseline_indices] = calculateBaseline(channel_data, time_in, ...
            slope_measurement_settings.baseline_start, slope_measurement_settings.baseline_end);
        
        % Вычисляем стандартное отклонение baseline для онсета
        if ~isempty(baseline_indices)
            baseline_data = channel_data(baseline_indices);
            baseline_std = std(baseline_data);
        else
            baseline_std = NaN;
        end
        
        % Получаем текущие результаты из расчета
        [slope_value, slope_angle, regression_points, peak_time, peak_value] = ...
            calculateSlope(channel_data, time_in, baseline_value, ...
                         slope_measurement_settings.peak_start, slope_measurement_settings.peak_end, ...
                         slope_measurement_settings.slope_percent, slope_measurement_settings.peak_polarity);
        
        % Получаем результаты онсета
        [onset_time, onset_value, onset_method] = calculateOnset(channel_data, time_in, ...
            baseline_value, baseline_std, slope_measurement_settings.peak_start, slope_measurement_settings.peak_end, ...
            slope_measurement_settings.onset_method, slope_measurement_settings.onset_threshold);
        
        % Создаем метаданные для сохранения состояния
        metadata = struct();
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
        
        % Добавляем результат в структуру
        new_result = struct('baseline_value', baseline_value, 'slope_value', slope_value, ...
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
        
        % Получаем путь и имя исходного файла из глобальных переменных
        global matFilePath matFileName
        
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
            excel_data = cell(length(slope_measurement_results) + 1, 5);
            
            % Заголовки
            excel_data{1, 1} = 'Slope';
            excel_data{1, 2} = 'Baseline';
            excel_data{1, 3} = 'Onset Time';
            excel_data{1, 4} = 'Channel';
            excel_data{1, 5} = 'Mode';
            
            % Данные
            for i = 1:length(slope_measurement_results)
                metadata = slope_measurement_results(i).metadata;
                excel_data{i+1, 1} = slope_measurement_results(i).slope_value;
                excel_data{i+1, 2} = slope_measurement_results(i).baseline_value;
                excel_data{i+1, 3} = slope_measurement_results(i).onset_time;
                excel_data{i+1, 4} = metadata.channel;
                excel_data{i+1, 5} = getNavigationStatusText(metadata);
            end
            
            % Сохраняем Excel файл
            writecell(excel_data, excel_path);
            
            % Сохраняем метаданные в .meta файл (фактически .mat формат)
            save(meta_path, 'slope_measurement_results', '-v7.3');
            
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
        table_data = cell(length(slope_measurement_results), 5);
        for i = 1:length(slope_measurement_results)
            metadata = slope_measurement_results(i).metadata;
            table_data{i, 1} = slope_measurement_results(i).slope_value; % slope
            table_data{i, 2} = slope_measurement_results(i).baseline_value; % baseline
            table_data{i, 3} = slope_measurement_results(i).onset_time; % onset time
            table_data{i, 4} = metadata.channel; % канал
            table_data{i, 5} = getNavigationStatusText(metadata); % режим с полной информацией
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
    
    function [mean_data, mean_time] = calculateMeanSignal()
        % Вычисляет средний сигнал из всех добавленных результатов
        
        if isempty(slope_measurement_results)
            mean_data = [];
            mean_time = [];
            return;
        end
        
        fprintf('DEBUG: Начинаем вычисление среднего сигнала из %d результатов\n', length(slope_measurement_results));
        
        % СОХРАНЯЕМ исходное состояние
        original_chosen_time_interval = chosen_time_interval;
        
        % Первый проход - находим точку t=0 для каждого сигнала
        zero_indices = zeros(1, length(slope_measurement_results));
        before_zero_signals = {};
        after_zero_signals = {};
        
        valid_results = 0;
        for i = 1:length(slope_measurement_results)
            metadata = slope_measurement_results(i).metadata;
            [signal_data, time_data] = getSignalDataForResult(metadata);
            
            if ~isempty(signal_data) && ~isempty(time_data)
                % Транспонируем данные если нужно
                if size(signal_data, 1) > size(signal_data, 2)
                    signal_data = signal_data';
                end
                if size(time_data, 1) > size(time_data, 2)
                    time_data = time_data';
                end
                
                % Находим ближайшую точку к t=0
                zero_idx_array = ClosestIndex(0, time_data);
                zero_idx = zero_idx_array(1); % Берем первый (и единственный) элемент
                valid_results = valid_results + 1;
                zero_indices(valid_results) = zero_idx;
                
                % Разделяем сигнал на части до и после t=0
                before_zero_signals{valid_results} = signal_data(1:zero_idx);
                after_zero_signals{valid_results} = signal_data(zero_idx+1:end);
                
                fprintf('DEBUG: Результат #%d - t=0 индекс: %d, до: %d, после: %d\n', ...
                    i, zero_idx, length(before_zero_signals{valid_results}), length(after_zero_signals{valid_results}));
            else
                fprintf('DEBUG: Результат #%d пропущен (пустые данные)\n', i);
            end
        end
        
        % Обрезаем массивы до реального количества валидных результатов
        zero_indices = zero_indices(1:valid_results);
        
        if isempty(before_zero_signals)
            mean_data = [];
            mean_time = [];
            % ВОССТАНАВЛИВАЕМ исходное состояние
            chosen_time_interval = original_chosen_time_interval;
            return;
        end
        
        % Находим минимальные длины для обеих частей
        min_before_length = min(cellfun(@length, before_zero_signals));
        min_after_length = min(cellfun(@length, after_zero_signals));
        
        fprintf('DEBUG: Минимальные длины - до t=0: %d, после t=0: %d\n', min_before_length, min_after_length);
        
        % Обрезаем все сигналы до одинаковой длины
        normalized_before_signals = {};
        normalized_after_signals = {};
        
        for i = 1:length(before_zero_signals)
            % Обрезаем часть до t=0 - убираем из начала
            signal = before_zero_signals{i};
            current_length = length(signal);
            
            if current_length > min_before_length
                % Убираем лишние точки из начала
                start_idx = current_length - min_before_length + 1;
                normalized_before_signals{i} = signal(start_idx:end);
            else
                normalized_before_signals{i} = signal;
            end
            
            % Обрезаем часть после t=0 - убираем из конца
            signal = after_zero_signals{i};
            current_length = length(signal);
            
            if current_length > min_after_length
                % Убираем лишние точки из конца
                normalized_after_signals{i} = signal(1:min_after_length);
            else
                normalized_after_signals{i} = signal;
            end
            
            fprintf('DEBUG: Результат #%d - нормализовано до: %d, после: %d\n', ...
                i, length(normalized_before_signals{i}), length(normalized_after_signals{i}));
        end
        
        % Собираем полные сигналы
        all_normalized_signals = {};
        for i = 1:length(normalized_before_signals)
            % Объединяем часть до t=0 и после t=0
            full_signal = [normalized_before_signals{i}, normalized_after_signals{i}];
            all_normalized_signals{i} = full_signal;
        end
        
        % Преобразуем в матрицу для усреднения
        signal_matrix = cell2mat(all_normalized_signals');
        
        % Вычисляем среднее
        mean_data = mean(signal_matrix, 1);
        
        % Создаем нормализованное время
        total_length = min_before_length + min_after_length;
        
        % Получаем средний шаг времени из первого результата
        metadata = slope_measurement_results(1).metadata;
        [~, time_data] = getSignalDataForResult(metadata);
        if size(time_data, 1) > size(time_data, 2)
            time_data = time_data';
        end
        time_step = mean(diff(time_data));
        
        % Время от -min_before_length до +min_after_length
        mean_time = (-min_before_length+1:min_after_length) * time_step;
        
        fprintf('DEBUG: Финальный размер mean_data: %s, mean_time: %s\n', ...
            mat2str(size(mean_data)), mat2str(size(mean_time)));
        
        % Выводим значения в начале и конце векторов
        if ~isempty(mean_data) && ~isempty(mean_time)
            fprintf('DEBUG: Начало mean_time: [%.3f, %.3f, %.3f, %.3f, %.3f]\n', ...
                mean_time(1:min(5, length(mean_time))));
            fprintf('DEBUG: Конец mean_time: [%.3f, %.3f, %.3f, %.3f, %.3f]\n', ...
                mean_time(max(1, end-4):end));
            fprintf('DEBUG: Начало mean_data: [%.6f, %.6f, %.6f, %.6f, %.6f]\n', ...
                mean_data(1:min(5, length(mean_data))));
            fprintf('DEBUG: Конец mean_data: [%.6f, %.6f, %.6f, %.6f, %.6f]\n', ...
                mean_data(max(1, end-4):end));
        end
        
        % ВОССТАНАВЛИВАЕМ исходное состояние
        chosen_time_interval = original_chosen_time_interval;
        
        fprintf('✓ Средний сигнал вычислен из %d результатов\n', size(signal_matrix, 1));
    end
    
    function [signal_data, time_data] = getSignalDataForResult(metadata)
        % Получает данные сигнала для конкретного результата
        try
            fprintf('DEBUG: getSignalDataForResult - начало обработки\n');
            
            % СОХРАНЯЕМ исходное состояние
            original_interval = chosen_time_interval;
            
            % Используем ЛОКАЛЬНУЮ копию, НЕ изменяем глобальную переменную
            local_chosen_time_interval = metadata.chosen_time_interval;
            
            fprintf('DEBUG: Временной интервал: [%.3f, %.3f]\n', local_chosen_time_interval(1), local_chosen_time_interval(2));
            
            % Получаем данные для этого временного интервала
            plot_time_interval = local_chosen_time_interval;
            plot_time_interval(1) = plot_time_interval(1) - time_back;
            
            fprintf('DEBUG: Расширенный интервал: [%.3f, %.3f]\n', plot_time_interval(1), plot_time_interval(2));
            
            cond = time >= plot_time_interval(1) & time < plot_time_interval(2);
            local_lfp = lfp(cond, :);
            
            fprintf('DEBUG: Размер local_lfp: %s\n', mat2str(size(local_lfp)));
            
            % Вычитание средних каналов если нужно
            if ~isempty(mean_group_ch) && any(mean_group_ch)
                local_lfp(:, mean_group_ch) = local_lfp(:, mean_group_ch) - mean(local_lfp(:, mean_group_ch), 2);
            end
            
            selected_channel = metadata.channel;
            signal_data = local_lfp(:, selected_channel);
            time_data = time(cond);
            
            fprintf('DEBUG: Исходный размер signal_data: %s, time_data: %s\n', ...
                mat2str(size(signal_data)), mat2str(size(time_data)));
            
            % Нормализуем время относительно rel_shift
            if strcmp(metadata.selectedCenter, 'stimulus') && stims_exist && ~isempty(stims)
                local_rel_shift = stims(metadata.stim_inx);
            else
                local_rel_shift = local_chosen_time_interval(1);
            end
            
            fprintf('DEBUG: rel_shift для нормализации = %.3f\n', local_rel_shift);
            fprintf('DEBUG: Время до нормализации: [%.3f, %.3f, %.3f, %.3f, %.3f]\n', ...
                time_data(1:min(5, length(time_data))));
            
            time_data = time_data - local_rel_shift;
            
            fprintf('DEBUG: Время после нормализации: [%.3f, %.3f, %.3f, %.3f, %.3f]\n', ...
                time_data(1:min(5, length(time_data))));
            
            % Фильтрация если включена
            if sum(filter_avaliable) > 0 && filter_avaliable(selected_channel)
                signal_data = applyFilter(signal_data, filterSettings, newFs);
                fprintf('DEBUG: После фильтрации - размер signal_data: %s\n', mat2str(size(signal_data)));
            end
            
            % Ресэмплинг убран - используем исходные данные
            fprintf('DEBUG: Ресэмплинг пропущен - используем исходные данные\n');
            
            % ВОССТАНАВЛИВАЕМ исходное состояние
            chosen_time_interval = original_interval;
            
            fprintf('DEBUG: getSignalDataForResult - финальный размер signal_data: %s, time_data: %s\n', ...
                mat2str(size(signal_data)), mat2str(size(time_data)));
            
        catch ME
            fprintf('❌ Ошибка при получении данных для результата: %s\n', ME.message);
            signal_data = [];
            time_data = [];
            % ВОССТАНАВЛИВАЕМ исходное состояние даже при ошибке
            chosen_time_interval = original_interval;
        end
    end

end 