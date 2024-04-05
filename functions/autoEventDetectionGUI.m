function autoEventDetectionGUI()
    % Загрузка настроек
    global autodetection_settings events_exist event_inx
    global timeUnitFactor
    
    settings = autodetection_settings;
    
    global events event_comments hd events_detected eventTable
    global hd hMinPeakProminence hDetectionType hChPos hChNeg hMinPeakDistance hSmoothCoefWindow hDetectionMode hOnsetThreshold hOnsetSearchWindow
    global hSourceType selectedCenter timeCenterPopup windowSize chosen_time_interval
    
    % Идентификатор (tag) для GUI фигуры
    figTag = 'EventDetection';
    
    % Поиск открытой фигуры с заданным идентификатором
    guiFig = findobj('Type', 'figure', 'Tag', figTag);
    
    if ~isempty(guiFig)
        % Делаем существующее окно текущим (активным)
        figure(guiFig);
        return
    end
        
    % Окно Auto Event Detection
    detectionFig = figure('Name', 'Auto Event Detection', 'Tag', figTag, ...
        'Resize', 'off', ...
        'NumberTitle', 'off', 'MenuBar', 'none', 'ToolBar', 'none', 'Position', [100, 100, 800, 400]);

    ypos = [linspace(300, 70, 8), 340, 365];
    % Окно выбора источника данных LFP или CSD
    uicontrol(detectionFig, 'Style', 'text', 'Position', [10, ypos(10), 150, 20], 'String', 'Source:');
    hSourceType = uicontrol(detectionFig, 'Style', 'popupmenu', 'Position', [160, ypos(10), 130, 20], 'String', {'LFP', 'CSD'});

    % Окно выбора типа детекции (1 или 2 канала)
    uicontrol(detectionFig, 'Style', 'text', 'Position', [10, ypos(9), 150, 20], 'String', 'Detection Type:');
    hDetectionType = uicontrol(detectionFig, 'Style', 'popupmenu', 'Position', [160, ypos(9), 130, 20], 'String', {'two channels difference', 'two channels multiplied', 'one channel positive', 'one channel negative'}, 'Callback', @changeDetectionType);

    % Окошко для ввода MinPeakHeight
    uicontrol(detectionFig, 'Style', 'text', 'Position', [10, ypos(1), 150, 20], 'String', 'Minimal Peak Amplitude:');
    hMinPeakProminence = uicontrol(detectionFig, 'Style', 'edit', 'Position', [160, ypos(1), 130, 20], 'String', '50');

    % Окно выбора ChPos и ChNeg из списка каналов
    hChPos_text = uicontrol(detectionFig, 'Style', 'text', 'Position', [10, ypos(2), 150, 20], 'String', 'Positive Channel:');
    hChPos = uicontrol(detectionFig, 'Style', 'popupmenu', 'Position', [160, ypos(2), 130, 20], 'String', hd.recChNames);
    hChNeg_text = uicontrol(detectionFig, 'Style', 'text', 'Position', [10, ypos(3), 150, 20], 'String', 'Negative Channel:');
    hChNeg = uicontrol(detectionFig, 'Style', 'popupmenu', 'Position', [160, ypos(3), 130, 20], 'String', hd.recChNames);

    % Окошко для ввода MinPeakDistance
    uicontrol(detectionFig, 'Style', 'text', 'Position', [10, ypos(4), 150, 30], 'String', 'Minimal Time Between Peaks (s):');
    hMinPeakDistance = uicontrol(detectionFig, 'Style', 'edit', 'Position', [160, ypos(4), 130, 20], 'String', '3');

    uicontrol(detectionFig, 'Style', 'text', 'Position', [10, ypos(5), 150, 20], 'String', 'Smooth coefficient :');
    hSmoothCoefWindow = uicontrol(detectionFig, 'Style', 'edit', 'Position', [160, ypos(5), 130, 20], 'String', '20');

    % Окно выбора режима детекции
    uicontrol(detectionFig, 'Style', 'text', 'Position', [10, ypos(6), 150, 20], 'String', 'Detection Mode:');
    hDetectionMode = uicontrol(detectionFig, 'Style', 'popupmenu', 'Position', [160, ypos(6), 130, 20], 'String', {'peaks', 'onsets'}, 'Callback', @changeDetectionMode);

    % Окошко для ввода Onset Threshold
    hOnsetThreshold_text = uicontrol(detectionFig, 'Style', 'text', 'Position', [10, ypos(7), 150, 20], 'visible', 'off', 'String', 'Onset Threshold:');
    hOnsetThreshold = uicontrol(detectionFig, 'Style', 'edit', 'Position', [160, ypos(7), 130, 20], 'visible', 'off', 'String', '10');

    % Окошко для ввода Onset Search Window
    hOnsetSearchWindow_text = uicontrol(detectionFig, 'Style', 'text', 'Position', [10, ypos(8), 150, 20], 'visible', 'off', 'String', 'Onset Search Window (s):');
    hOnsetSearchWindow = uicontrol(detectionFig, 'Style', 'edit', 'Position', [160, ypos(8), 130, 20], 'visible', 'off', 'String', '1');

    ax1 = axes('Position', [0.40    0.27    0.25    0.65]);
    ax2 = axes('Position', [0.70    0.27    0.25    0.65]);
    
    set(ax1, 'visible', 'off')
    set(ax2, 'visible', 'off')
    
    % Инициализация значений из настроек, если они существуют
    if ~isempty(settings)
        set(hMinPeakProminence, 'String', num2str(settings.MinPeakProminence));
        set(hDetectionType, 'Value', settings.DetectionTypeIndex);
        set(hChPos, 'Value', settings.ChPos);
        set(hChNeg, 'Value', settings.ChNeg);
        set(hMinPeakDistance, 'String', num2str(settings.MinPeakDistance));
        set(hSmoothCoefWindow, 'String', num2str(settings.SmoothCoef));
        set(hDetectionMode, 'Value', settings.DetectionModeIndex);
        set(hOnsetThreshold, 'String', num2str(settings.OnsetThreshold));
        set(hOnsetSearchWindow, 'String', num2str(settings.OnsetSearchWindow));
        
        if isfield(settings, 'SourceTypeIndex')
            if ~isempty(settings.SourceTypeIndex)
                set(hSourceType, 'Value', settings.SourceTypeIndex);
            else
                set(hSourceType, 'Value', 1);
            end
        else
            set(hSourceType, 'Value', 1);
        end
        
        % Вызовите функции изменения режима/типа детекции, если необходимо
        changeDetectionMode(hDetectionMode)
        changeDetectionType(hDetectionType)
    end
    
    % Кнопка 'Check Detection'
    uicontrol(detectionFig, 'Style', 'pushbutton', 'String', 'Check Detection',...
        'Position', [340, 10, 280, 40], 'Callback', @checkDetectionCallback);

    % Кнопка 'Apply'
    applybutton = uicontrol(detectionFig, 'Style', 'pushbutton', 'String', 'Apply',...
        'Position', [650, 10, 120, 40], 'Callback', @detectButtonCallback);
    set(applybutton, 'Enable', 'off')
    
    function changeDetectionMode(~,~)
        DetectionModes = get(hDetectionMode, 'String');
        DetectionMode = DetectionModes{get(hDetectionMode, 'Value')};
        switch DetectionMode
            case 'onsets'
                set(hOnsetThreshold_text, 'visible', 'on')
                set(hOnsetThreshold, 'visible', 'on')
                set(hOnsetSearchWindow_text, 'visible', 'on')
                set(hOnsetSearchWindow, 'visible', 'on')
            case 'peaks'
                set(hOnsetThreshold, 'visible', 'off')
                set(hOnsetThreshold_text, 'visible', 'off')
                set(hOnsetSearchWindow_text, 'visible', 'off')
                set(hOnsetSearchWindow, 'visible', 'off')
        end
    end

    function changeDetectionType(~,~)
        DetectionTypes = get(hDetectionType, 'String');
        DetectionType = DetectionTypes{get(hDetectionType, 'Value')};
        switch DetectionType
            case 'two channels difference'
                set(hChPos_text, 'visible', 'on')
                set(hChPos, 'visible', 'on')
                set(hChNeg_text, 'visible', 'on')
                set(hChNeg, 'visible', 'on')
            case 'two channels multiplied'
                set(hChPos_text, 'visible', 'on')
                set(hChPos, 'visible', 'on')
                set(hChNeg_text, 'visible', 'on')
                set(hChNeg, 'visible', 'on')
            case 'one channel negative'
                set(hChPos_text, 'visible', 'off')
                set(hChPos, 'visible', 'off')
                set(hChNeg_text, 'visible', 'on')
                set(hChNeg, 'visible', 'on')
            case 'one channel positive'
                set(hChPos_text, 'visible', 'on')
                set(hChPos, 'visible', 'on')
                set(hChNeg_text, 'visible', 'off')
                set(hChNeg, 'visible', 'off')
        end
    end

    function checkDetectionCallback(~, ~)
        clc
        % Сбор значений параметров и упаковка их в структуру
        params.MinPeakProminence = str2double(get(hMinPeakProminence, 'String'));
        params.ChPos = get(hChPos, 'Value');
        params.ChNeg = get(hChNeg, 'Value');
        params.MinPeakDistance = str2double(get(hMinPeakDistance, 'String'));
        params.OnsetThreshold = str2double(get(hOnsetThreshold, 'String'));
        params.OnsetSearchWindow = str2double(get(hOnsetSearchWindow, 'String'));
        DetectionModes = get(hDetectionMode, 'String');
        params.DetectionMode = DetectionModes{get(hDetectionMode, 'Value')};
        DetectionTypes = get(hDetectionType, 'String');
        params.DetectionType = DetectionTypes{get(hDetectionType, 'Value')};
        params.smooth_coef = str2double(get(hSmoothCoefWindow, 'String'));
        SourceTypes = get(hSourceType, 'String');
        params.SourceType = SourceTypes{get(hSourceType, 'Value')};
        
        [events_detected, Trace_out, time_res] = autoEventDetection(params);


        axes(ax1)
        set(ax1, 'visible', 'on')
        
        cla, hold on
        localTimeUnitFactor = 1/60; % секунды в минуты
        plot(time_res*localTimeUnitFactor, Trace_out)
        xlabel('Time, min');
        ylim([0, max(Trace_out)])
        
        yline(params.MinPeakProminence, 'k:')
        
        xlim([time_res(1), time_res(end)]*localTimeUnitFactor)

        Lines(events_detected*localTimeUnitFactor, [], 'r',':');
        
        numEvents = numel(events_detected);
        
        title([ num2str(numEvents), ' events'], 'interpreter', 'none')     
        
        % Предварительная обработка данных для удаления выбросов
        % Вычисляем квантили
        q = quantile(Trace_out, [0.05 0.95]);
        % Интерквартильный размах
        iqr = q(2) - q(1);
        % Границы для определения выбросов
        lowerBound = q(1) - 1.5*iqr;
        upperBound = q(2) + 1.5*iqr;

        % Отфильтровываем выбросы
        Trace_filtered = Trace_out(Trace_out >= lowerBound & Trace_out <= upperBound);

        % Визуализация
        axes(ax2);
        set(ax2, 'visible', 'on')
        
        cla; hold on;
        % Автоматическое определение количества бинов для улучшения визуализации
        h = histogram(Trace_filtered, 50,'Normalization','probability');
        std3 = 3*std(Trace_filtered);
        std3_h = max(h.Values);
        
        xline(std3, 'k:')
        text(std3, std3_h, '3*STD')
        text(std3, std3_h*0.95, num2str(std3, 3))
        
        chosen_th = params.MinPeakProminence;
        chosen_th_h = std3_h*0.5;
        xline(chosen_th, 'r:')
        text(chosen_th, chosen_th_h, 'now')
        text(chosen_th, std3_h*0.45, num2str(chosen_th, 3), 'color', 'r')
        
        hold off;
        
        set(applybutton, 'Enable', 'on')
        
    end

    function detectButtonCallback(~, ~)
        % Обновление таблицы событий
        events = events_detected;
        event_comments = repmat({'...'}, numel(events), 1); % Инициализация комментариев
        if not(isempty(events))
            [events, ev_inxs] = sort(events);
            event_comments = event_comments(ev_inxs);
            eventTable.Data = [num2cell(events*timeUnitFactor), event_comments];
        end
        
        % Сохранение настроек перед закрытием
        saveSettings();
        
        events_exist = true;
        event_inx = 1;
        selectedCenter = 'event';
        set(timeCenterPopup, 'Value', 3);
        
        chosen_time_interval(1) = events(event_inx);
        chosen_time_interval(2) = events(event_inx)+windowSize;
                        
        updatePlot(); % Обновление графика с новыми событиями        
    
        % Закрыть окно Auto Event Detection
        close(detectionFig);
    end

end

function saveSettings()
    global hMinPeakProminence hDetectionType hChPos hChNeg hMinPeakDistance hSmoothCoefWindow hDetectionMode hOnsetThreshold hOnsetSearchWindow
    global autodetection_settings SettingsFilepath
    global hSourceType
    
    settings.MinPeakProminence = str2double(get(hMinPeakProminence, 'String'));
    settings.DetectionTypeIndex = get(hDetectionType, 'Value');
    settings.ChPos = get(hChPos, 'Value');
    settings.ChNeg = get(hChNeg, 'Value');
    settings.MinPeakDistance = str2double(get(hMinPeakDistance, 'String'));
    settings.SmoothCoef = str2double(get(hSmoothCoefWindow, 'String'));
    settings.DetectionModeIndex = get(hDetectionMode, 'Value');
    settings.OnsetThreshold = str2double(get(hOnsetThreshold, 'String'));
    settings.OnsetSearchWindow = str2double(get(hOnsetSearchWindow, 'String'));
    settings.SourceTypeIndex = get(hSourceType, 'Value');
    
    autodetection_settings = settings;
    % сохраняем фактор в глобальные настройки              
    save(SettingsFilepath, 'autodetection_settings', '-append');
end

function [events_detected, Trace_out, time_res] = autoEventDetection(params)
    global Fs time newFs lfp wb ch_inxs csd_avaliable filterSettings filter_avaliable
    data_in = lfp;
    wb = msgbox('Please wait...', 'Status');
    
    % Распаковка параметров из структуры
    DetectionType = params.DetectionType;
    smooth_coef = params.smooth_coef;
    OnsetSearchWindow = params.OnsetSearchWindow;
    MinPeakProminence = params.MinPeakProminence;
    ChPos = params.ChPos;
    ChNeg = params.ChNeg;
    MinPeakDistance = params.MinPeakDistance;
    onset_threshold = params.OnsetThreshold;
    DetectionMode = params.DetectionMode;
    SourceType = params.SourceType;
    
    raw_frq = Fs;
    lfp_frq = round(newFs);
    
    % Фильтруем если попросили
    try
        if sum(filter_avaliable)>0
            ch_to_filter = filterSettings.channelsToFilter;
            data_in(:, ch_to_filter) = applyFilter(data_in(:, ch_to_filter), filterSettings, newFs);        
        end
    catch ME
        errordlg(['An error occurred: ', ME.message], 'Error');
    end
    
    % Если источником выбран CSD
    switch SourceType
        case 'CSD'
        % Выборка только разрешенных каналов, которым доступен CSD
        allowed_ch_inxs = ch_inxs(csd_avaliable(ch_inxs) == 1);
        data_in = -globalCSD(data_in, allowed_ch_inxs);
    end

        
    switch DetectionType
        case 'two channels difference'

            NegTrace = resample(double(data_in(:, ChNeg)), lfp_frq , raw_frq)';
            PosTrace = resample(double(data_in(:, ChPos)), lfp_frq , raw_frq)';           
            Reversion = PosTrace - NegTrace;
            Reversion = medfilt1(Reversion, smooth_coef);
            baseline = medfilt1(Reversion, 1000);
            Filtered_Reversion = Reversion;
            Filtered_Reversion(Filtered_Reversion<baseline) = baseline(Filtered_Reversion<baseline);
            Trace_out = Filtered_Reversion - baseline;
        case 'two channels multiplied'
            NegTrace = resample(double(data_in(:, ChNeg)), lfp_frq , raw_frq)';
            PosTrace = resample(double(data_in(:, ChPos)), lfp_frq , raw_frq)';              
            Trace_out = -(NegTrace.*PosTrace);        
        case 'one channel negative'
            NegTrace = resample(double(data_in(:, ChNeg)), lfp_frq , raw_frq)';
            Trace_out = -medfilt1(NegTrace, smooth_coef);
        case 'one channel positive'
            PosTrace = resample(double(data_in(:, ChPos)), lfp_frq , raw_frq)'; 
            Trace_out = medfilt1(PosTrace, smooth_coef);
    end

    time_res = linspace(time(1),time(end),numel(Trace_out));

    [~, peak_times] = findpeaks(Trace_out, time_res, 'MinPeakHeight',MinPeakProminence, 'MinPeakDistance', MinPeakDistance);
    peak_locs_inx = ClosestIndex(peak_times, time_res);

    switch DetectionMode
        case 'peaks'
            events_detected = peak_times';
        case 'onsets'
            % onset of peaks by Khazipov method
            onset_locs_inx = zeros(size(peak_locs_inx));
            sig_part_window_inx = ClosestIndex(OnsetSearchWindow, time_res);
            o_i = 0;
            for peak_loc_inx = peak_locs_inx
                o_i = o_i + 1;

                start_inx = peak_loc_inx - sig_part_window_inx;
                end_inx = peak_loc_inx + sig_part_window_inx;

                if start_inx > 1 && end_inx < numel(Trace_out)
                    signal_part = Trace_out(start_inx : end_inx);
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
    
    close(wb)
end