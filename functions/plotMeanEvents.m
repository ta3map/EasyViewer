function [f, calculation_result] = plotMeanEvents(params)

    % Распаковка переменных из params
    timePoints = params.timePoints;
    if isfield(params, 'sourceType')
        sourceType = params.sourceType;
    else
        sourceType = 'events'; % обратная совместимость
    end
    meanWindow = params.meanWindow;
    hd = params.hd;
    channelSettings = params.channelSettings;
    Fs = params.Fs;
    lfp = params.lfp;
    N = params.N;
    time = params.time;
    binsize = params.binsize;
    prg = params.spk_threshold;
    spks = params.spks;
    shiftCoeff = params.shiftCoeff;
    titlename = params.titlename;
    show_spikes = params.show_spikes;
    ch_inxs = params.ch_inxs; % Индексы активированных каналов
    show_CSD = params.show_CSD;
    csd_smooth_coef = params.csd_smooth_coef;
    csd_contrast_coef = params.csd_contrast_coef;
    csd_active = params.csd_active;
    lfpVar = params.lfpVar;
    mean_group_ch = params.mean_group_ch;
    t_profile = params.t_profile;
    
    if isfield(params, 'timeUnitFactor')
        timeUnitFactor = params.timeUnitFactor;
    else
        timeUnitFactor = 1;
    end
    
    % Получение данных событий и настроек каналов
    ch_labels = hd.recChNames(:);

    activeChannels = find([channelSettings{:, 2}]); % Индексы активных каналов
    scalingCoefficients = [channelSettings{:, 3}]; % Масштабирующие коэффициенты

    colors_in = channelSettings(:, 4)';
    widths_in = [channelSettings{:, 5}];

    % Подготовка данных для среднего
    meanData = zeros(round(meanWindow * Fs), size(lfp, 2));
    numEvents = length(timePoints);
    
    removeBaseline = isfield(params, 'removeBaseline') && logical(params.removeBaseline);
    
    if removeBaseline
        lfp(:, mean_group_ch) = lfp(:, mean_group_ch) - nanmean(lfp(:, mean_group_ch), 2); % вычитание выбранных средних каналов
    end
    
    ch_enabled = false(length(ch_labels), 1);    
    ch_enabled(activeChannels) = true;
    originalEventsData = {}; % Сохраняем данные каждого события отдельно
    
    % Проверяем, нужно ли показывать waitbar
    showWaitbar = true; % по умолчанию показываем
    if isfield(params, 'showWaitbar')
        showWaitbar = logical(params.showWaitbar);
    end
    
    % Создаем waitbar для обработки событий (если нужно)
    wb = [];
    if showWaitbar
        wb = waitbar(0, 'Processing events...', 'Name', 'Calculating mean events');
    end
    
    for i = 1:numEvents
        % Вычисление индексов окна вокруг временной точки
        eventIdx = round(timePoints(i) * Fs);
        windowStart = max(eventIdx - round(meanWindow * Fs / 2), 1);
        windowEnd = min(windowStart + round(meanWindow * Fs) - 1, N);

        if windowEnd < size(lfp, 1)
            eventDataRaw = lfp(windowStart:windowEnd, :);
            if removeBaseline
                eventDataProcessed = eventDataRaw - nanmedian(eventDataRaw);
            else
                eventDataProcessed = eventDataRaw;
            end
            
            % Добавление данных в среднее
            meanData = meanData + eventDataProcessed;
            
            % Сохраняем обработанные данные события для возможной детекции
            eventDataScaled = eventDataProcessed(:, ch_enabled) .* scalingCoefficients(ch_enabled);
            originalEventsData{end+1} = eventDataScaled;
        end
        
        % Обновляем waitbar (если он создан)
        if showWaitbar && ~isempty(wb)
            waitbar(i / numEvents, wb, sprintf('Processing event %d of %d', i, numEvents));
        end
    end

    % Нормализация среднего
    meanData = meanData / numEvents;

    % Считаем средние спайки

    % show spikes
    ev_hists = [];
    if show_spikes && not(isempty(spks)) && not(show_CSD)
        clear evs
        for i = 1:numEvents
            % Вычисление индексов окна вокруг временной точки
            eventIdx = round(timePoints(i) * Fs);
            windowStart = max(eventIdx - round(meanWindow * Fs / 2), 1);
            windowEnd = min(windowStart + round(meanWindow * Fs) - 1, N);

            if windowEnd < size(lfp, 1)                      
                % Окно события
                time_start = time(windowStart);
                time_end = time(windowEnd);
                c = 0;

                time_interval = [time_start, time_end];% s
                edges = time_interval(1):binsize:time_interval(2);

                % Смотрим что на каждом канале для этого эвента
                ch_hists = [];
                for ch_inx = ch_inxs
                    c = c+1;
                    
                    % Порог ZAV метод
                    ii = double(spks(ch_inx).ampl) <= (-lfpVar(ch_inx) * prg);
                    spks_in(ch_inx).tStamp = spks(ch_inx).tStamp(ii);
                    spks_in(ch_inx).ampl = spks(ch_inx).ampl(ii);

                    spk = spks_in(ch_inx).tStamp/1000;
                    
                    hist_data = histcounts(spk, edges);
                    ch_hists = [ch_hists; hist_data];
                end
                evs(i, :, :) = ch_hists;
            end
            % Обновляем waitbar (если он создан)
            if showWaitbar && ~isempty(wb)
                waitbar(i / numEvents, wb, sprintf('Processing spikes: event %d of %d', i, numEvents));
            end
        end
        if exist('evs')
            ev_hists = squeeze(mean(evs,1));
        else
            ev_hists = [];
        end
    end
    
    % Закрываем waitbar (если он создан)
    if showWaitbar && ~isempty(wb)
        close(wb);
    end


    % Отображение среднего
    f = params.figure; % Создание нового окна для графика
%     clf

    start_time = -meanWindow / 2;
    end_time = meanWindow / 2;

    timeAxis = linspace(start_time, end_time, size(meanData, 1))*timeUnitFactor;% время в секундах
    pl_meanData =  meanData.* scalingCoefficients;

    pl_meanData = pl_meanData(:, ch_enabled);
    pl_ch_labels = ch_labels(ch_enabled);
    autoScale = isfield(params, 'autoScale') && logical(params.autoScale);
    pl_shiftCoeff = shiftCoeff;
    pl_widths_in = widths_in(ch_enabled);
    pl_colors_in = colors_in(ch_enabled);     
    
    numChannels = size(pl_meanData, 2);
    
    % Используем tiledlayout для основной оси
    if isfield(params, 'tiledlayout')
        t = params.tiledlayout;
        % Проверяем размер tiledlayout и используем соответствующий размер тайла
        gridSize = t.GridSize;
        if gridSize(1) >= 2
            % Если есть минимум 2 строки, используем [2, 1]
            ax = nexttile(t, [2, 1]);
        else
            % Если только 1 строка, используем [1, 1]
            ax = nexttile(t);
        end
    else
        ax = axes('Position', [0.13,0.11,0.72,0.82]); % fallback для обратной совместимости
    end
    hold on  
        
     % Initialize offsets array
    offsets = zeros(1, numChannels);
    for p = 1:numChannels
        offsets(p) = -(p-1) * pl_shiftCoeff;
    end
    
    showOriginalTraces = isfield(params, 'showOriginalTraces') && logical(params.showOriginalTraces);
    allOriginalData = [];
    if showOriginalTraces && not(show_CSD)
        for i = 1:length(originalEventsData)
            eventData = originalEventsData{i};
            allOriginalData = [allOriginalData; eventData];
            
            for chIdx = 1:numChannels
                plot(timeAxis, eventData(:, chIdx) + offsets(chIdx), ...
                    'Color', [0.7 0.7 0.7], 'LineWidth', 0.3);
            end
        end
    end
    
    if show_CSD        % режим показа CSD
        
        params.time_in_csd = timeAxis;
        params.data_in_csd = pl_meanData;
        params.Fs = Fs;
        params.offsets = offsets;
        params.csd_smooth_coef = csd_smooth_coef;
        params.csd_active = csd_active;
        
        [csd_image, csd_trange, csd_ch_range] = csdCalc(params);
        csd_ch_range = linspace(csd_ch_range(1), csd_ch_range(2), size(csd_image, 1));
        
      
        csdPlotting(csd_image, csd_trange, csd_ch_range, csd_contrast_coef);
        
        % Построение профиля CSD
        csd_time_zero_idx = round(ClosestIndex(t_profile, csd_trange)/csd_smooth_coef); % находим индекс данных, соответствующий времени профиля
        csd_profile = csd_image(:, csd_time_zero_idx);
        [max_csd_profile, max_csd_prof_index] = max(csd_profile);
        [min_csd_profile, min_csd_prof_index] = min(csd_profile);
        max_csd_profile_channel = csd_ch_range(max_csd_prof_index);
        min_csd_profile_channel = csd_ch_range(min_csd_prof_index);
        
        csd_profile_ax = axes('Position', [0.86,0.11,0.11,0.82]);
        hold on
        plot(csd_profile, csd_ch_range, 'k');
        text(max_csd_profile, max_csd_profile_channel, num2str(max_csd_profile, 3))
        text(min_csd_profile, min_csd_profile_channel, num2str(min_csd_profile, 3))
        
        title(csd_profile_ax,  ['CSD (t=', num2str(t_profile, 3) ' sec)']);       
        
        ylim([offsets(end)-pl_shiftCoeff, offsets(1)+pl_shiftCoeff])
        xline(0, 'r--')
        axis off
        
        axes(ax)% возвращаемся на основную ось
    end
    


if not(isempty(ev_hists))  && not(show_CSD)      % режим показа MUA (не работает если выбран CSD)
    mua_x = linspace(start_time*timeUnitFactor, end_time*timeUnitFactor, size(ev_hists, 2));
    im = imagesc(mua_x, offsets, ev_hists);
    
    % Построение профиля MUA
    mua_time_profile_idx = round(ClosestIndex(t_profile, mua_x)); % находим индекс данных, соответствующий времени профиля
    mua_profile = ev_hists(:, mua_time_profile_idx);
    [max_mua_profile, max_mua_prof_index] = max(mua_profile);
    [min_mua_profile, min_mua_prof_index] = min(mua_profile);
    max_mua_profile_channel = offsets(max_mua_prof_index);
    min_mua_profile_channel = offsets(min_mua_prof_index);
    
    % Пересчёт в спайки/сек (unit/sec)
    max_mua_profile_persec = max_mua_profile / binsize;
    min_mua_profile_persec = min_mua_profile / binsize;
    
    mua_profile_ax = axes('Position', [0.86,0.11,0.11,0.82]);
    hold on
    plot(mua_profile, offsets, 'k');
    % Подписи с переносом строки для экономии места
    text(max_mua_profile, max_mua_profile_channel, sprintf('%s\nunit/sec', num2str(max_mua_profile_persec, 3)))
    text(min_mua_profile, min_mua_profile_channel, sprintf('%s\nunit/sec', num2str(min_mua_profile_persec, 3)))
    
    title(mua_profile_ax, ['MUA (unit/sec, t=', num2str(t_profile, 3) ' sec)']);       
    
    ylim([offsets(end)-pl_shiftCoeff, offsets(1)+pl_shiftCoeff])
    xline(0, 'r--')
    axis off
    
    axes(ax) % возвращаемся на основную ось
end

     

    multiplot(timeAxis, pl_meanData, ...
    'ChannelLabels', pl_ch_labels, ...
    'shiftCoeff',pl_shiftCoeff, ...
    'linewidth', pl_widths_in, ...
    'color', pl_colors_in);

    xlabel('Time');
    ylabel('Mean Value');
    if strcmp(sourceType, 'stimuli')
        title([titlename, ', ', num2str(numEvents), ' stimuli'], 'interpreter', 'none')
    else
        title([titlename, ', ', num2str(numEvents), ' events'], 'interpreter', 'none')
    end        

    if autoScale
        debugState('plotMeanEvents', 'Auto scale enabled');
        shiftedData = pl_meanData + offsets;
        if showOriginalTraces && not(isempty(allOriginalData))
            shiftedOriginalData = allOriginalData + repmat(offsets, size(allOriginalData, 1), 1);
            dataRange = [min([shiftedData(:); shiftedOriginalData(:)]), max([shiftedData(:); shiftedOriginalData(:)])];
        else
            dataRange = [min(shiftedData(:)), max(shiftedData(:))];
        end
        span = diff(dataRange);
        if span <= 0
            span = max(abs(dataRange));
            if span == 0
                span = 1;
            end
        end
        pad = span * 0.05;
        debugState('plotMeanEvents', 'Auto scale range: [%f, %f] span=%f pad=%f', dataRange(1), dataRange(2), span, pad);
        ylim([dataRange(1) - pad, dataRange(2) + pad]);
    else
        ylim([offsets(end)-pl_shiftCoeff, offsets(1)+pl_shiftCoeff]);
    end
    xlim([start_time, end_time]*timeUnitFactor)
    
    calculation_result = struct();

    calculation_result.meanData = meanData;
    calculation_result.timePoints = timePoints;
    calculation_result.sourceType = sourceType;
    calculation_result.channelSettings = channelSettings;
    calculation_result.activeChannels = activeChannels;
    calculation_result.scalingCoefficients = scalingCoefficients;
    calculation_result.Fs = Fs;
    calculation_result.N = N;
%     calculation_result.time = time;
    calculation_result.show_spikes = show_spikes;
    calculation_result.binsize = binsize;
    calculation_result.std_coef = prg;
    calculation_result.ch_inxs = ch_inxs;
    calculation_result.ev_hists = ev_hists;
    calculation_result.timeAxis = timeAxis/timeUnitFactor;
    calculation_result.timeAxisScaled = timeAxis;
    calculation_result.timeUnitFactor = timeUnitFactor;
    calculation_result.ch_labels = ch_labels;
    calculation_result.shiftCoeff = pl_shiftCoeff;
    calculation_result.widths_in = widths_in;
    calculation_result.colors_in = colors_in;
    calculation_result.originalEventsData = originalEventsData;
    
    % Вычисляем медиану для каждого канала как базовую линию
    baseline_medians = zeros(1, numChannels);
    for ch = 1:numChannels
        baseline_medians(ch) = median(pl_meanData(:, ch));
    end
    calculation_result.baseline_medians = baseline_medians;

end
