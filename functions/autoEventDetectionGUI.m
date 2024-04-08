function autoEventDetectionGUI()
    % Загрузка настроек
    global autodetection_settings events_exist event_inx
    global timeUnitFactor 
    
    settings = autodetection_settings;
    
    global events event_comments hd events_detected eventTable
    global hd hMinPeakProminence hDetectionType hChPos hChNeg hMaxPeakWidth
    global hMinPeakDistance hSmoothCoefWindow hDetectionMode hOnsetThreshold hOnsetSearchWindow
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

    ypos = [linspace(300, 70, 9), 340, 365];
    % Окно выбора источника данных LFP или CSD
    uicontrol(detectionFig, 'Style', 'text', 'Position', [10, ypos(11), 150, 20], 'String', 'Source:');
    hSourceType = uicontrol(detectionFig, 'Style', 'popupmenu', 'Position', [160, ypos(11), 130, 20], 'String', {'LFP', 'CSD'}, 'Callback', @changeDetectionType);

    % Окно выбора типа детекции (1 или 2 канала)
    uicontrol(detectionFig, 'Style', 'text', 'Position', [10, ypos(10), 150, 20], 'String', 'Detection Type:');
    hDetectionType = uicontrol(detectionFig, 'Style', 'popupmenu', 'Position', [160, ypos(10), 130, 20], 'String', {'two channels difference', 'two channels multiplied', 'one channel positive', 'one channel negative'}, 'Callback', @changeDetectionType);

    % Окошко для ввода MinPeakHeight
    uicontrol(detectionFig, 'Style', 'text', 'Position', [10, ypos(1), 150, 20], 'String', 'Minimal Peak Amplitude:');
    hMinPeakProminence = uicontrol(detectionFig, 'Style', 'edit', 'Position', [160, ypos(1), 130, 20], 'String', '50');

    % Окно выбора ChPos и ChNeg из списка каналов
    hChPos_text = uicontrol(detectionFig, 'Style', 'text', 'Position', [10, ypos(2), 150, 20], 'String', 'Positive Channel:');
    hChPos = uicontrol(detectionFig, 'Style', 'popupmenu', 'Position', [160, ypos(2), 130, 20], 'String', hd.recChNames, 'Callback', @changeDetectionType);
    hChNeg_text = uicontrol(detectionFig, 'Style', 'text', 'Position', [10, ypos(3), 150, 20], 'String', 'Negative Channel:');
    hChNeg = uicontrol(detectionFig, 'Style', 'popupmenu', 'Position', [160, ypos(3), 130, 20], 'String', hd.recChNames, 'Callback', @changeDetectionType);

    % Окошко для ввода MinPeakDistance
    uicontrol(detectionFig, 'Style', 'text', 'Position', [10, ypos(4), 150, 30], 'String', 'Minimal Time Between Peaks (s):');
    hMinPeakDistance = uicontrol(detectionFig, 'Style', 'edit', 'Position', [160, ypos(4), 130, 20], 'String', '3');

    uicontrol(detectionFig, 'Style', 'text', 'Position', [10, ypos(5), 150, 20], 'String', 'Smooth coefficient (ms):');
    hSmoothCoefWindow = uicontrol(detectionFig, 'Style', 'edit', 'Position', [160, ypos(5), 130, 20], 'String', '20');

    uicontrol(detectionFig, 'Style', 'text', 'Position', [10, ypos(6), 150, 20], 'String', 'Max peak width (ms):');
    hMaxPeakWidth = uicontrol(detectionFig, 'Style', 'edit', 'Position', [160, ypos(6), 130, 20], 'String', '50');
    
    % Окно выбора режима детекции
    uicontrol(detectionFig, 'Style', 'text', 'Position', [10, ypos(7), 150, 20], 'String', 'Detection Mode:');
    hDetectionMode = uicontrol(detectionFig, 'Style', 'popupmenu', 'Position', [160, ypos(7), 130, 20], 'String', {'peaks', 'onsets'}, 'Callback', @changeDetectionType);

    % Окошко для ввода Onset Threshold
    hOnsetThreshold_text = uicontrol(detectionFig, 'Style', 'text', 'Position', [10, ypos(8), 150, 20], 'visible', 'off', 'String', 'Onset Threshold:');
    hOnsetThreshold = uicontrol(detectionFig, 'Style', 'edit', 'Position', [160, ypos(8), 130, 20], 'visible', 'off', 'String', '10');

    % Окошко для ввода Onset Search Window
    hOnsetSearchWindow_text = uicontrol(detectionFig, 'Style', 'text', 'Position', [10, ypos(9), 150, 20], 'visible', 'off', 'String', 'Onset Search Window (s):');
    hOnsetSearchWindow = uicontrol(detectionFig, 'Style', 'edit', 'Position', [160, ypos(9), 130, 20], 'visible', 'off', 'String', '1');

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
        
        if isfield(settings, 'MaxPeakWidth')
            if ~isempty(settings.MaxPeakWidth)
                set(hMaxPeakWidth, 'String', num2str(settings.MaxPeakWidth));
            else
                set(hMaxPeakWidth, 'String', 50);
            end
        end
        
        % Вызовите функции изменения режима/типа детекции, если необходимо
        changeDetectionType()
    end
    
    % Кнопка 'Check Detection'
    uicontrol(detectionFig, 'Style', 'pushbutton', 'String', 'Check Detection',...
        'Position', [340, 10, 280, 40], 'Callback', @checkDetectionCallback);

    % Кнопка 'Apply'
    applybutton = uicontrol(detectionFig, 'Style', 'pushbutton', 'String', 'Apply',...
        'Position', [650, 10, 120, 40], 'Callback', @detectButtonCallback);
    set(applybutton, 'Enable', 'off')

    function changeDetectionType(~,~)
        
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
        
        previewData()

    end

    function previewData()
        % Предварительная прорисовка
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
        params.detect = false;
        params.max_peak_width = str2double(get(hMaxPeakWidth, 'String'));
        
        [events_detected, Trace_out, time_res] = autoEventDetection(params);
        
        outlier = plotRequest(events_detected, Trace_out, time_res, params);
        set(hMinPeakProminence, 'String', num2str(outlier));
    end

    function checkDetectionCallback(~, ~)
        
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
        params.detect = true;
        params.max_peak_width = str2double(get(hMaxPeakWidth, 'String'));
        
        [events_detected, Trace_out, time_res] = autoEventDetection(params);

        plotRequest(events_detected, Trace_out, time_res, params);
        
        set(applybutton, 'Enable', 'on')
        
    end

    function outlier = plotRequest(events_detected, Trace_out, time_res, params)
                
        outlier = quantile(Trace_out, [0.999]);
        
        numSegments = 100;
        Trace_out = findSegmentMaxima(Trace_out, numSegments);
        time_res = linspace(time_res(1),time_res(end),numSegments);
        
        if params.detect % если идет детекция
            chosen_th = params.MinPeakProminence;
        else % если предварительная прорисовка
            chosen_th = outlier;
        end
        
        axes(ax1)
        set(ax1, 'visible', 'on')
        
        cla, hold on
        localTimeUnitFactor = 1/60; % секунды в минуты
%         stem(time_res*localTimeUnitFactor, Trace_out, 'Marker', '|')
        stairs(time_res*localTimeUnitFactor, Trace_out)
        
        xlabel('Time, min');
%         ylim([0, max(Trace_out)])
        
        yline(chosen_th, 'k:')
        
        xlim([time_res(1), time_res(end)]*localTimeUnitFactor)

        Lines(events_detected*localTimeUnitFactor, [], 'r',':');
        
        numEvents = numel(events_detected);
        if params.detect
            title([ num2str(numEvents), ' events'], 'interpreter', 'none')     
        else
            title('')
        end


        % Визуализация
        axes(ax2);
        set(ax2, 'visible', 'on')
        
        cla; hold on;
        % Автоматическое определение количества бинов для улучшения визуализации
        h = histogram(Trace_out, 50,'Normalization','probability');        
        
        xline(outlier, 'k:')
        
        outlier_h = max(h.Values)*0.9;
        
        text(outlier, outlier_h, 'outlier')
        text(outlier, outlier_h*0.95, num2str(outlier, 3))
        
        std3 = 3*nanstd(Trace_out);
        std3_h = max(h.Values);
        
        xline(std3, 'k:')
        text(std3, std3_h, '3*STD')
        text(std3, std3_h*0.95, num2str(std3, 3))
        
        
        
        chosen_th_h = std3_h*0.5;
        xline(chosen_th, 'r:')
        text(chosen_th, chosen_th_h, 'now')
        text(chosen_th, std3_h*0.45, num2str(chosen_th, 3), 'color', 'r')
        
        hold off;
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
    global hMinPeakProminence hDetectionType hChPos hChNeg hMaxPeakWidth
    global hMinPeakDistance hSmoothCoefWindow hDetectionMode hOnsetThreshold hOnsetSearchWindow
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
    settings.MaxPeakWidth = str2double(get(hMaxPeakWidth, 'String'));
    
    autodetection_settings = settings;
    % сохраняем фактор в глобальные настройки              
    save(SettingsFilepath, 'autodetection_settings', '-append');
end

function [events_detected, Trace_out, time_res] = autoEventDetection(params)
    global Fs time newFs lfp wb ch_inxs csd_avaliable filterSettings filter_avaliable mean_group_ch
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
    
    detect = params.detect;
    
    max_peak_width = params.max_peak_width;
    
    raw_frq = Fs;
    lfp_frq = round(newFs);
    
    % Фильтруем если попросили
    try
        if sum(filter_avaliable)>0
            ch_to_filter = filterSettings.channelsToFilter;
            data_in(:, ch_to_filter) = applyFilter(data_in(:, ch_to_filter), filterSettings, newFs);        
        end
    catch ME
        uiwait(errordlg(['An error occurred: ', ME.message], 'Error'));
    end
    
    % Вычитаем среднее из запрошенных
    data_in(:, mean_group_ch) = data_in(:, mean_group_ch) - mean(data_in(:, mean_group_ch), 2); % вычитание выбранных средних каналов
    
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
    Trace_out(isnan(Trace_out)) = nanmean(Trace_out);
    Trace_out = Trace_out - mean(Trace_out);
    Trace_out = np_flatten(Trace_out);
    
    time_res = linspace(time(1),time(end),numel(Trace_out));
    
    if detect         
        [~,peak_times,widths,~] = findpeaks(Trace_out, time_res, 'MinPeakHeight',MinPeakProminence, 'MinPeakDistance', MinPeakDistance,'WidthReference','halfheight');
        
        % убираем слишком широкие пики
        peak_times(widths > max_peak_width/lfp_frq) = [];
        
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
    else
        events_detected = [];
    end
    close(wb)
end