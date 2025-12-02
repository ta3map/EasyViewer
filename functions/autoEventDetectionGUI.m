function autoEventDetectionGUI()
    % Загрузка настроек
    global autodetection_settings events_exist event_inx
    global table_calling event_title_string
    global timeUnitFactor selectedUnit
    
    settings = autodetection_settings;
    
    global events event_comments hd events_detected matFilePath evfilename eventDeleteEdit
    global hMinPeakProminence hDetectionType hChPos hChNeg hMaxPeakWidth
    global hMinPeakDistance
    global hSourceType selectedCenter timeCenterPopup windowSize chosen_time_interval
    global hSearchAroundStimuli hSearchWindow stims_exist
    
    % Переменные для хранения результатов детекции в области видимости GUI
    amplitudes_detected = [];
    widths_detected = [];
    channels_detected = [];
    metadata_detected = [];
    
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
    hMinPeakDistance_text = uicontrol(detectionFig, 'Style', 'text', 'Position', [10, ypos(4), 150, 30], 'String', ['Minimal Time Between Peaks (' selectedUnit '):']);
    hMinPeakDistance = uicontrol(detectionFig, 'Style', 'edit', 'Position', [160, ypos(4), 130, 20], 'String', num2str(3*timeUnitFactor));

    % Чекбокс для поиска вокруг стимулов
    hSearchAroundStimuli = uicontrol(detectionFig, 'Style', 'checkbox', 'Position', [10, ypos(5), 280, 20], 'String', 'Search around stimuli', 'Value', 0, 'Callback', @changeDetectionType);
    
    % Поле ввода размера окна поиска
    hSearchWindow_text = uicontrol(detectionFig, 'Style', 'text', 'Position', [10, ypos(6), 150, 20], 'String', ['Search window (' selectedUnit '):']);
    hSearchWindow = uicontrol(detectionFig, 'Style', 'edit', 'Position', [160, ypos(6), 130, 20], 'String', num2str(0.5*timeUnitFactor));

    hMaxPeakWidth_text = uicontrol(detectionFig, 'Style', 'text', 'Position', [10, ypos(7), 150, 20], 'String', ['Max peak width (' selectedUnit '):']);
    hMaxPeakWidth = uicontrol(detectionFig, 'Style', 'edit', 'Position', [160, ypos(7), 130, 20], 'String', num2str(0.05*timeUnitFactor));

    % Инициализация видимости элементов в зависимости от наличия стимулов
    changeDetectionType();

    ax1 = axes('Position', [0.40    0.27    0.25    0.65]);
    ax2 = axes('Position', [0.70    0.27    0.25    0.65]);
    
    set(ax1, 'visible', 'off')
    set(ax2, 'visible', 'off')
    
    % Инициализация значений из настроек, если они существуют
    if ~isempty(settings)
        
                safeSetPopupValue(hChPos, settings.ChPos, numel(hd.recChNames), 'Positive Channel');
        safeSetPopupValue(hChNeg, settings.ChNeg, numel(hd.recChNames), 'Negative Channel');
        
        safeSetPopupValue(hSourceType, settings.SourceTypeIndex, ...
                          numel(get(hSourceType,'String')), 'SourceType');

        safeSetPopupValue(hDetectionType, settings.DetectionTypeIndex, ...
                          numel(get(hDetectionType,'String')), 'DetectionType');
                      
        set(hMinPeakProminence, 'String', num2str(settings.MinPeakProminence));

        set(hMinPeakDistance, 'String', num2str(settings.MinPeakDistance*timeUnitFactor));
        set(hMinPeakDistance_text, 'String', ['Minimal Time Between Peaks (' selectedUnit '):']);
        
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
                set(hMaxPeakWidth, 'String', num2str(settings.MaxPeakWidth*timeUnitFactor));
            else
                set(hMaxPeakWidth, 'String', num2str(0.05*timeUnitFactor));
            end
        end
        set(hMaxPeakWidth_text, 'String', ['Max peak width (' selectedUnit '):']);
        
        % Вызовите функции изменения режима/типа детекции, если необходимо
        changeDetectionType()
        
        % Инициализация новых параметров из настроек
        if isfield(settings, 'SearchAroundStimuli')
            set(hSearchAroundStimuli, 'Value', settings.SearchAroundStimuli);
        end
        if isfield(settings, 'SearchWindow')
            set(hSearchWindow, 'String', num2str(settings.SearchWindow*timeUnitFactor));
        end
    end
    
    % Кнопка 'Check Detection'
    uicontrol(detectionFig, 'Style', 'pushbutton', 'String', 'Check Detection',...
        'Position', [340, 10, 280, 40], 'Callback', @checkDetectionCallback);

    % Кнопка 'Apply'
    applybutton = uicontrol(detectionFig, 'Style', 'pushbutton', 'String', 'Apply',...
        'Position', [650, 10, 120, 40], 'Callback', @detectButtonCallback);
    set(applybutton, 'Enable', 'off')

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
        
        % Показывать/скрывать элементы поиска вокруг стимулов
        if stims_exist
            set(hSearchAroundStimuli, 'visible', 'on')
            set(hSearchWindow_text, 'visible', 'on')
            set(hSearchWindow, 'visible', 'on')
        else
            set(hSearchAroundStimuli, 'visible', 'off')
            set(hSearchWindow_text, 'visible', 'off')
            set(hSearchWindow, 'visible', 'off')
            set(hSearchAroundStimuli, 'Value', 0)
        end
        
%         previewData()

    end

    function previewData()
        % Предварительная прорисовка
        % Сбор значений параметров и упаковка их в структуру
        params.MinPeakProminence = str2double(get(hMinPeakProminence, 'String'));
        params.ChPos = get(hChPos, 'Value');
        params.ChNeg = get(hChNeg, 'Value');
        params.MinPeakDistance = str2double(get(hMinPeakDistance, 'String')) / timeUnitFactor;
        DetectionTypes = get(hDetectionType, 'String');
        params.DetectionType = DetectionTypes{get(hDetectionType, 'Value')};
        SourceTypes = get(hSourceType, 'String');
        params.SourceType = SourceTypes{get(hSourceType, 'Value')};
        params.detect = false;
        params.max_peak_width = str2double(get(hMaxPeakWidth, 'String')) / timeUnitFactor;
        params.SearchAroundStimuli = get(hSearchAroundStimuli, 'Value');
        params.SearchWindow = str2double(get(hSearchWindow, 'String')) / timeUnitFactor;
               
        [events_detected, Trace_out, time_res, amplitudes_detected, widths_detected, channels_detected, metadata_detected] = autoEventDetection(params);
        
        Trace_out(isnan(Trace_out)) = 0;
        Trace_out(isinf(Trace_out)) = 0;
        
        outlier = plotRequest(events_detected, Trace_out, time_res, params);
        set(hMinPeakProminence, 'String', num2str(outlier));
    end

    function checkDetectionCallback(~, ~)
        
        % Показываем "Detecting ..." на осях
        axes(ax1);
        set(ax1, 'visible', 'on');
        cla;
        text(0.5, 0.5, 'Detecting ...', 'HorizontalAlignment', 'center', ...
             'VerticalAlignment', 'middle', 'FontSize', 14, 'Units', 'normalized');
        axis off;
        
        axes(ax2);
        set(ax2, 'visible', 'on');
        cla;
        text(0.5, 0.5, 'Detecting ...', 'HorizontalAlignment', 'center', ...
             'VerticalAlignment', 'middle', 'FontSize', 14, 'Units', 'normalized');
        axis off;
        drawnow;
        
        % Сбор значений параметров и упаковка их в структуру
        params.MinPeakProminence = str2double(get(hMinPeakProminence, 'String'));
        params.ChPos = get(hChPos, 'Value');
        params.ChNeg = get(hChNeg, 'Value');
        params.MinPeakDistance = str2double(get(hMinPeakDistance, 'String')) / timeUnitFactor;
        DetectionTypes = get(hDetectionType, 'String');
        params.DetectionType = DetectionTypes{get(hDetectionType, 'Value')};
        SourceTypes = get(hSourceType, 'String');
        params.SourceType = SourceTypes{get(hSourceType, 'Value')};
        params.detect = true;
        params.max_peak_width = str2double(get(hMaxPeakWidth, 'String')) / timeUnitFactor;
        params.SearchAroundStimuli = get(hSearchAroundStimuli, 'Value');
        params.SearchWindow = str2double(get(hSearchWindow, 'String')) / timeUnitFactor;
        
        [events_detected, Trace_out, time_res, amplitudes_detected, widths_detected, channels_detected, metadata_detected] = autoEventDetection(params);
        
        Trace_out(isnan(Trace_out)) = 0;
        Trace_out(isinf(Trace_out)) = 0;
        
        plotRequest(events_detected, Trace_out, time_res, params);
        
        set(applybutton, 'Enable', 'on')
        
    end

    function outlier = plotRequest(events_detected, Trace_out, time_res, params)
                
        outlier = quantile(Trace_out, [0.999]);
        std3 = 3*nanstd(Trace_out);
        
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
%         stem(time_res*timeUnitFactor, Trace_out, 'Marker', '|')
        stairs(time_res*timeUnitFactor, Trace_out)
        
        xlabel(['Time, ' selectedUnit]);
%         ylim([0, max(Trace_out)])
        
        yline(chosen_th, 'k:')
        
        xlim([time_res(1), time_res(end)]*timeUnitFactor)

        Lines(events_detected*timeUnitFactor, [], 'r',':');
        
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
        global event_amplitudes event_channels event_widths event_prominences event_metadata
        
        % Проверяем что переменные с результатами детекции существуют
        if ~exist('amplitudes_detected', 'var') || ~exist('channels_detected', 'var') || ...
           ~exist('widths_detected', 'var') || ~exist('metadata_detected', 'var')
            fprintf('Please run "Check Detection" first before applying results.\n');
            return;
        end
        
        % Обновление таблицы событий
        events = events_detected(:); % Преобразуем в столбец
        
        if not(isempty(events))
            event_comments = repmat({'...'}, numel(events), 1); % Инициализация комментариев
            
            [events, ev_inxs] = sort(events);
            event_comments = event_comments(ev_inxs);
            
            % Сортируем метаданные в том же порядке что и события
            event_amplitudes = amplitudes_detected(ev_inxs);
            
            % Безопасная обработка channels_detected (может быть матрицей или вектором)
            if size(channels_detected, 2) > 1
                event_channels = channels_detected(ev_inxs, :);
            else
                event_channels = channels_detected(ev_inxs);
            end
            
            event_widths = widths_detected(ev_inxs);
            
            % Извлекаем prominence из metadata для сортировки
            temp_prominences = NaN(size(events));
            for i = 1:length(metadata_detected)
                temp_prominences(i) = metadata_detected(i).prominence;
            end
            event_prominences = temp_prominences(ev_inxs);
            
            event_metadata = metadata_detected(ev_inxs);
        else
            event_amplitudes = [];
            event_channels = [];
            event_widths = [];
            event_prominences = [];
            event_metadata = [];
        end
        
        [~, filename, ~] = fileparts(matFilePath);
        
        evfilename = [filename '_auto'];
        event_title_string = 'Autodetected';
        table_calling()
        event_inx = 1;     
        set(eventDeleteEdit, 'String', num2str(event_inx));
                        
        % Сохранение настроек перед закрытием
        saveSettings();
        
        % Проверяем наличие событий перед установкой параметров
        if ~isempty(events)
            events_exist = true;
            event_inx = 1;
            selectedCenter = 'event';
            set(timeCenterPopup, 'Value', 3);
            
            chosen_time_interval(1) = events(event_inx);
            chosen_time_interval(2) = events(event_inx)+windowSize;
        else
            % Если событий нет, не меняем режим и не устанавливаем временной интервал
            events_exist = false;
            % Не меняем selectedCenter и timeCenterPopup
            % Не меняем chosen_time_interval
            fprintf('No events detected. Please adjust detection parameters.\n');
        end
                        
        updatePlot(); % Обновление графика с новыми событиями        
    
        % Закрыть окно Auto Event Detection
        close(detectionFig);
    end

end

function saveSettings()
    global hMinPeakProminence hDetectionType hChPos hChNeg hMaxPeakWidth
    global hMinPeakDistance
    global autodetection_settings SettingsFilepath
    global hSourceType timeUnitFactor hSearchAroundStimuli hSearchWindow
    
    settings.MinPeakProminence = str2double(get(hMinPeakProminence, 'String'));
    settings.DetectionTypeIndex = get(hDetectionType, 'Value');
    settings.ChPos = get(hChPos, 'Value');
    settings.ChNeg = get(hChNeg, 'Value');
    settings.MinPeakDistance = str2double(get(hMinPeakDistance, 'String')) / timeUnitFactor;
    settings.SourceTypeIndex = get(hSourceType, 'Value');
    settings.MaxPeakWidth = str2double(get(hMaxPeakWidth, 'String')) / timeUnitFactor;
    settings.SearchAroundStimuli = get(hSearchAroundStimuli, 'Value');
    settings.SearchWindow = str2double(get(hSearchWindow, 'String')) / timeUnitFactor;
    
    autodetection_settings = settings;
    % сохраняем фактор в глобальные настройки              
    save(SettingsFilepath, 'autodetection_settings', '-append');
end

function [events_detected, Trace_out, time_res, amplitudes_detected, widths_detected, channels_detected, metadata_detected] = autoEventDetection(params)
    global Fs time newFs lfp wb ch_inxs csd_avaliable filterSettings filter_avaliable mean_group_ch 
    global stims_exist stims time art_rem_window_ms
    
    data_in = lfp;
    fprintf('Please wait...\n');
    
    % Инициализация waitbar если не существует
    if isempty(wb) || ~isvalid(wb)
        wb = waitbar(0, 'Initializing...', 'Name', 'Event Detection');
    end
    
    % Распаковка параметров из структуры
    DetectionType = params.DetectionType;
    MinPeakProminence = params.MinPeakProminence;
    ChPos = params.ChPos;
    ChNeg = params.ChNeg;
    MinPeakDistance = params.MinPeakDistance;
    SourceType = params.SourceType;
    
    detect = params.detect;
    
    max_peak_width = params.max_peak_width;
    
    raw_frq = Fs;
    lfp_frq = round(newFs);
    
    % Фильтруем если попросили
    waitbar(0.1, wb, 'Applying filters...');
    try
        if sum(filter_avaliable)>0
            ch_to_filter = filterSettings.channelsToFilter;
            data_in(:, ch_to_filter) = applyFilter(data_in(:, ch_to_filter), filterSettings, newFs);        
        end
    catch ME
        fprintf('An error occurred: %s\n', ME.message);
    end

    % Убираем артефакт стимула если включено
    waitbar(0.2, wb, 'Removing stimulus artifacts...');
    if stims_exist && ~isempty(stims) && ~isempty(art_rem_window_ms) && art_rem_window_ms > 0
        win_r = round(art_rem_window_ms * (Fs/1000));
        data_in = removeStimArtifact(data_in, stims, time, win_r);
    end
    
    % Вычитаем среднее из запрошенных
    waitbar(0.3, wb, 'Subtracting mean...');
    data_in(:, mean_group_ch) = data_in(:, mean_group_ch) - mean(data_in(:, mean_group_ch), 2); % вычитание выбранных средних каналов
    
    % Если источником выбран CSD
    waitbar(0.4, wb, 'Computing CSD...');
    switch SourceType
        case 'CSD'
        % Выборка только разрешенных каналов, которым доступен CSD
        allowed_ch_inxs = ch_inxs(csd_avaliable(ch_inxs) == 1);
        data_in = -globalCSD(data_in, allowed_ch_inxs);
    end

    % Создание Trace_out
    waitbar(0.5, wb, 'Creating detection trace...');
    switch DetectionType
        case 'two channels difference'

            NegTrace = resample(double(data_in(:, ChNeg)), lfp_frq , raw_frq)';
            PosTrace = resample(double(data_in(:, ChPos)), lfp_frq , raw_frq)';           
            Reversion = PosTrace - NegTrace;
%             Reversion = medfilt1(Reversion, smooth_coef);
%             baseline = medfilt1(Reversion, 1000);
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
%             Trace_out = -medfilt1(NegTrace, smooth_coef);
            Trace_out = -NegTrace;
        case 'one channel positive'
            PosTrace = resample(double(data_in(:, ChPos)), lfp_frq , raw_frq)'; 
%             Trace_out = medfilt1(PosTrace, smooth_coef);
            Trace_out = PosTrace;
    end
    Trace_out(isnan(Trace_out)) = nanmean(Trace_out);
    Trace_out = Trace_out - mean(Trace_out);
    Trace_out = np_flatten(Trace_out);
    
    time_res = linspace(time(1),time(end),numel(Trace_out));
    
    waitbar(0.6, wb, 'Preparing detection...');
    
    if detect
        fprintf('=== DEBUG: Detection parameters ===\n');
        fprintf('MinPeakProminence: %.3f\n', MinPeakProminence);
        fprintf('MinPeakDistance: %.6f sec (%.6f samples at %d Hz)\n', MinPeakDistance, MinPeakDistance*lfp_frq, lfp_frq);
        fprintf('MaxPeakWidth: %.6f sec (%.6f samples at %d Hz)\n', max_peak_width, max_peak_width*lfp_frq, lfp_frq);
        fprintf('DetectionType: %s\n', DetectionType);
        fprintf('SourceType: %s\n', SourceType);
        fprintf('ChPos: %d, ChNeg: %d\n', ChPos, ChNeg);
        fprintf('\n=== DEBUG: Trace_out statistics ===\n');
        fprintf('Trace_out length: %d samples\n', numel(Trace_out));
        fprintf('Trace_out min: %.3f\n', min(Trace_out));
        fprintf('Trace_out max: %.3f\n', max(Trace_out));
        fprintf('Trace_out mean: %.3f\n', mean(Trace_out));
        fprintf('Trace_out std: %.3f\n', std(Trace_out));
        fprintf('Trace_out median: %.3f\n', median(Trace_out));
        fprintf('Trace_out 99.9%% quantile: %.3f\n', quantile(Trace_out, 0.999));
        fprintf('\n');
        
        % Проверяем, нужно ли искать вокруг стимулов
        SearchAroundStimuli = false;
        SearchWindow = 0;
        if isfield(params, 'SearchAroundStimuli')
            SearchAroundStimuli = params.SearchAroundStimuli;
        end
        if isfield(params, 'SearchWindow')
            SearchWindow = params.SearchWindow;
        end
        
        if SearchAroundStimuli && stims_exist && ~isempty(stims)
            fprintf('=== DEBUG: Searching around stimuli ===\n');
            fprintf('Number of stimuli: %d\n', length(stims));
            fprintf('Search window: ±%.6f sec\n', SearchWindow);
            fprintf('\n');
            
            waitbar(0.65, wb, sprintf('Detecting events around %d stimuli...', length(stims)));
            
            % Инициализация массивов для объединения результатов
            all_peak_times = [];
            all_peaks = [];
            all_widths = [];
            all_prominences = [];
            
            % Детекция в окнах вокруг каждого стимула
            num_stims = length(stims);
            for stim_idx = 1:num_stims
                waitbar(0.65 + 0.25 * (stim_idx / num_stims), wb, ...
                    sprintf('Processing stimulus %d of %d...', stim_idx, num_stims));
                stim = stims(stim_idx);
                window_start = stim - SearchWindow;
                window_end = stim + SearchWindow;
                
                % Находим индексы, попадающие в окно
                window_mask = (time_res >= window_start) & (time_res <= window_end);
                
                if sum(window_mask) == 0
                    continue;
                end
                
                % Выделяем участок сигнала
                Trace_out_window = Trace_out(window_mask);
                time_res_window = time_res(window_mask);
                
                % Детекция в окне
                [peaks_window, peak_times_window, widths_window, prominences_window] = ...
                    findpeaks(Trace_out_window, time_res_window, ...
                    'MinPeakHeight', MinPeakProminence, ...
                    'MinPeakDistance', MinPeakDistance, ...
                    'WidthReference', 'halfheight');
                
                % Фильтрация по ширине
                if ~isempty(widths_window)
                    wide_mask = widths_window <= max_peak_width;
                    peaks_window = peaks_window(wide_mask);
                    peak_times_window = peak_times_window(wide_mask);
                    widths_window = widths_window(wide_mask);
                    prominences_window = prominences_window(wide_mask);
                end
                
                % Добавляем результаты в общие массивы
                if ~isempty(peak_times_window)
                    all_peak_times = [all_peak_times; peak_times_window(:)];
                    all_peaks = [all_peaks; peaks_window(:)];
                    all_widths = [all_widths; widths_window(:)];
                    all_prominences = [all_prominences; prominences_window(:)];
                end
            end
            
            fprintf('=== DEBUG: After window detection ===\n');
            fprintf('Total peaks found in all windows: %d\n', length(all_peak_times));
            fprintf('\n');
            
            waitbar(0.9, wb, 'Removing duplicates...');
            
            % Удаление дубликатов (если окна перекрываются)
            if ~isempty(all_peak_times)
                [sorted_times, sort_idx] = sort(all_peak_times);
                sorted_peaks = all_peaks(sort_idx);
                sorted_widths = all_widths(sort_idx);
                sorted_prominences = all_prominences(sort_idx);
                
                % Удаляем события, которые слишком близко друг к другу
                unique_mask = true(size(sorted_times));
                for i = 2:length(sorted_times)
                    if (sorted_times(i) - sorted_times(i-1)) < MinPeakDistance
                        unique_mask(i) = false;
                    end
                end
                
                all_peak_times = sorted_times(unique_mask);
                all_peaks = sorted_peaks(unique_mask);
                all_widths = sorted_widths(unique_mask);
                all_prominences = sorted_prominences(unique_mask);
                
                fprintf('=== DEBUG: After duplicate removal ===\n');
                fprintf('Remaining peaks: %d\n', length(all_peak_times));
                fprintf('\n');
            end
            
            if ~isempty(all_peak_times)
                events_detected = all_peak_times(:);
                amplitudes_detected = all_peaks(:);
                widths_detected = all_widths(:);
                prominences = all_prominences(:);
            else
                events_detected = [];
                amplitudes_detected = [];
                widths_detected = [];
                prominences = [];
            end
            
        else
            % Детекция по всему сигналу (как раньше)
            waitbar(0.7, wb, 'Detecting peaks in full signal...');
            [peaks,peak_times,widths,prominences] = findpeaks(Trace_out, time_res, 'MinPeakHeight',MinPeakProminence, 'MinPeakDistance', MinPeakDistance,'WidthReference','halfheight');
            
            fprintf('=== DEBUG: After findpeaks ===\n');
            fprintf('Found %d peaks\n', length(peaks));
            if ~isempty(peaks)
                fprintf('Peak amplitudes range: [%.3f, %.3f]\n', min(peaks), max(peaks));
                fprintf('Peak widths range: [%.6f, %.6f] sec\n', min(widths), max(widths));
                fprintf('Peak prominences range: [%.3f, %.3f]\n', min(prominences), max(prominences));
            end
            fprintf('\n');
            
            waitbar(0.85, wb, 'Filtering peaks by width...');
            
            % убираем слишком широкие пики
            wide_peaks_mask = widths > max_peak_width;
            num_wide_peaks = sum(wide_peaks_mask);
            peak_times(wide_peaks_mask) = [];
            peaks(wide_peaks_mask) = [];
            widths(wide_peaks_mask) = [];
            prominences(wide_peaks_mask) = [];
            
            fprintf('=== DEBUG: After width filtering ===\n');
            fprintf('Removed %d peaks (too wide, > %.6f sec)\n', num_wide_peaks, max_peak_width);
            fprintf('Remaining peaks: %d\n', length(peaks));
            fprintf('\n');
            
            events_detected = peak_times(:);
            amplitudes_detected = peaks(:);
            widths_detected = widths(:);
            prominences = prominences(:);
        end
        
        waitbar(0.95, wb, 'Finalizing results...');
        
        % Формируем каналы и метаданные
        channels_detected = [];
        if strcmp(DetectionType, 'two channels difference') || strcmp(DetectionType, 'two channels multiplied')
            % Для двухканальных методов сохраняем оба канала
            channels_detected = repmat([ChPos, ChNeg], length(events_detected), 1);
        elseif strcmp(DetectionType, 'one channel positive')
            channels_detected = repmat(ChPos, length(events_detected), 1);
        elseif strcmp(DetectionType, 'one channel negative')
            channels_detected = repmat(ChNeg, length(events_detected), 1);
        end
        
        % Создаем метаданные для каждого события
        metadata_detected = repmat(struct(...
            'source', 'auto', ...
            'method', 'peaks', ...
            'data_type', SourceType, ...
            'polarity', DetectionType, ...
            'prominence', NaN, ...
            'detection_params', struct(...
                'MinPeakProminence', MinPeakProminence, ...
                'MinPeakDistance', MinPeakDistance, ...
                'MaxPeakWidth', max_peak_width ...
            ) ...
        ), length(events_detected), 1);
        
        % Добавляем prominence для каждого события
        for i = 1:length(events_detected)
            metadata_detected(i).prominence = prominences(i);
        end
        
        fprintf('=== DEBUG: Final results ===\n');
        fprintf('Total events detected: %d\n', length(events_detected));
        fprintf('===================================\n\n');
        
    else
        waitbar(0.9, wb, 'Preview mode - no detection');
        events_detected = [];
        amplitudes_detected = [];
        widths_detected = [];
        channels_detected = [];
        metadata_detected = [];
    end
    
    waitbar(1.0, wb, 'Complete');
    fprintf('Events detected.\n');
    
    % Закрываем waitbar только если detect = true (в режиме детекции)
    if detect && ~isempty(wb) && isvalid(wb)
        close(wb);
    end
end

function safeSetPopupValue(hPopup, requestedValue, maxItems, popupLabel)
    % Если popupLabel не передали, сделаем его пустым
    if nargin < 4
        popupLabel = '';
    end

    if isempty(requestedValue) || ~isnumeric(requestedValue) || isnan(requestedValue)
        requestedValue = 1;
        warning("%s: value restored to default (was empty or invalid) ", popupLabel)
    end
    
    requestedValue = round(requestedValue);
    if requestedValue < 1
        requestedValue = 1;
        warning("%s: value < 1, restored to default ", popupLabel)
    elseif requestedValue > maxItems
        requestedValue = maxItems;
        warning("%s: value too big, restored to default ", popupLabel)
    end
    
    set(hPopup, 'Value', requestedValue);
end
