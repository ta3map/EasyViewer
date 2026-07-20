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
    csd_split_by_channel_gaps = false;
    if isfield(params, 'csd_split_by_channel_gaps')
        csd_split_by_channel_gaps = logical(params.csd_split_by_channel_gaps);
    end
    lfpVar = params.lfpVar;
    mean_group_ch = params.mean_group_ch;
    t_profile = params.t_profile;
    
    if isfield(params, 'timeUnitFactor')
        timeUnitFactor = params.timeUnitFactor;
    else
        timeUnitFactor = 1;
    end
    if isfield(params, 'customXLimits') && numel(params.customXLimits) == 2
        customXLimits = params.customXLimits;
    else
        customXLimits = [];
    end
    if isfield(params, 'csd_hp_cutoff_hz')
        csdHpCutoffHz = params.csd_hp_cutoff_hz;
    else
        csdHpCutoffHz = 0;
    end
    if isfield(params, 'csd_baseline_boundary')
        csdBaselineBoundary = params.csd_baseline_boundary;
    else
        csdBaselineBoundary = 0;
    end
    hpFilterEnabled = true;
    if isfield(params, 'hpFilterEnabled')
        hpFilterEnabled = logical(params.hpFilterEnabled);
    end
    baselineEnabled = true;
    if isfield(params, 'baselineEnabled')
        baselineEnabled = logical(params.baselineEnabled);
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

    % Применение сглаживания к meanData и originalEventsData, если задано
    if isfield(params, 'SmoothingKernel_s') && params.SmoothingKernel_s > 0
        kernel_time_scaled = params.SmoothingKernel_s;
        kernel_samples = round((kernel_time_scaled / timeUnitFactor) * Fs);
        kernel_samples = max(5, kernel_samples); % smooth1 требует минимум 5 точек
        
        % Сглаживание meanData
        for chIdx = 1:size(meanData, 2)
            meanData(:, chIdx) = smooth1(meanData(:, chIdx), kernel_samples, 'moving');
        end
        
        % Сглаживание originalEventsData
        for eventIdx = 1:length(originalEventsData)
            eventData = originalEventsData{eventIdx};
            for chIdx = 1:size(eventData, 2)
                eventData(:, chIdx) = smooth1(eventData(:, chIdx), kernel_samples, 'moving');
            end
            originalEventsData{eventIdx} = eventData;
        end
        
        kernel_time_s = kernel_time_scaled / timeUnitFactor;
        debugState('plotMeanEvents', 'Smoothing applied: kernel=%.3f s (%.1f ms, %d samples)', kernel_time_s, kernel_time_s*1000, kernel_samples);
    end

    % Применение вычитания среднего к meanData и originalEventsData, если задано
    if isfield(params, 'SubtractMean') && params.SubtractMean
        % Вычитание среднего из meanData
        for chIdx = 1:size(meanData, 2)
            meanData(:, chIdx) = meanData(:, chIdx) - mean(meanData(:, chIdx));
        end
        
        % Вычитание среднего из originalEventsData
        for eventIdx = 1:length(originalEventsData)
            eventData = originalEventsData{eventIdx};
            for chIdx = 1:size(eventData, 2)
                eventData(:, chIdx) = eventData(:, chIdx) - mean(eventData(:, chIdx));
            end
            originalEventsData{eventIdx} = eventData;
        end
        
        debugState('plotMeanEvents', 'Mean subtraction applied to meanData and originalEventsData');
    end

    % Считаем средние спайки

    % show spikes
    ev_hists = [];
    if show_spikes && not(isempty(spks))
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
                    
                    % Порог ZAV метод для положительных амплитуд:
                    % берем |ampl| и сравниваем с положительным порогом.
                    ii = abs(double(spks(ch_inx).ampl)) >= (lfpVar(ch_inx) * prg);
                    spks_in(ch_inx).tStamp = spks(ch_inx).tStamp(ii);
                    spks_in(ch_inx).ampl = abs(double(spks(ch_inx).ampl(ii)));

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
    
    axesParent = f;
    if isfield(params, 'axesContainer') && ~isempty(params.axesContainer) && isgraphics(params.axesContainer, 'uipanel')
        axesParent = params.axesContainer;
    elseif isfield(params, 'plotContainer') && ~isempty(params.plotContainer) && isgraphics(params.plotContainer, 'uipanel')
        axesParent = params.plotContainer;
    end
    ax = axes('Parent', axesParent, 'Units', 'normalized', 'Position', [0.02, 0.06, 0.96, 0.9]);
    set(ax, 'Tag', 'mean_main_axis');
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
    
    heatmap_handle = [];
    heatmap_base_clim = [];
    pl_meanDataToPlot = pl_meanData;
    hpCutoffHz = min(max(csdHpCutoffHz, 0.01), 500);
    if isempty(customXLimits)
        xlimLeft = start_time * timeUnitFactor;
        xlimRight = end_time * timeUnitFactor;
    else
        xlimLeft = customXLimits(1);
        xlimRight = customXLimits(2);
    end
    baselineRight = min(max(csdBaselineBoundary, xlimLeft), xlimRight);
    if show_CSD        % режим показа CSD
        pl_meanDataForCsd = double(pl_meanData);
        nyquistFreq = Fs / 2;
        hpCutoffHz = min(hpCutoffHz, nyquistFreq * 0.99);
        processRight = xlimRight;
        if baselineEnabled
            processRight = baselineRight;
        end
        processingMask = timeAxis >= xlimLeft & timeAxis <= processRight;
        if hpFilterEnabled && hpCutoffHz >= 0.01
            processIdx = find(processingMask);
            if numel(processIdx) >= 9
                dataBeforeFilter = pl_meanDataForCsd;
                [bHp, aHp] = butter(2, hpCutoffHz / nyquistFreq, 'high');
                pl_meanDataForCsd(processIdx, :) = filtfilt(bHp, aHp, pl_meanDataForCsd(processIdx, :));
                joinIdx = processIdx(end);
                if joinIdx < size(pl_meanDataForCsd, 1)
                    rightIdx = (joinIdx + 1):size(pl_meanDataForCsd, 1);
                    joinShift = pl_meanDataForCsd(joinIdx, :) - dataBeforeFilter(joinIdx, :);
                    pl_meanDataForCsd(rightIdx, :) = pl_meanDataForCsd(rightIdx, :) + joinShift;
                end
            end
        end
        if baselineEnabled
            baselineMask = timeAxis >= xlimLeft & timeAxis <= baselineRight;
            baselineMedian = median(pl_meanDataForCsd(baselineMask, :), 1);
            pl_meanDataForCsd = pl_meanDataForCsd - baselineMedian;
        end
        pl_meanDataToPlot = pl_meanDataForCsd;
        
        params.time_in_csd = timeAxis;
        params.data_in_csd = pl_meanDataForCsd;
        params.Fs = Fs;
        params.offsets = offsets;
        params.csd_smooth_coef = csd_smooth_coef;
        params.csd_active = csd_active;
        params.ch_inxs_original = ch_inxs;
        params.csd_split_by_channel_gaps = csd_split_by_channel_gaps;
        
        [csd_image, csd_trange, csd_ch_range] = csdCalc(params);
        
      
        csdPlotting(csd_image, csd_trange, csd_ch_range, csd_contrast_coef);
        imageHandles = findobj(ax, 'Type', 'image', '-depth', 1);
        if ~isempty(imageHandles)
            heatmap_handle = imageHandles(1);
            uistack(heatmap_handle, 'bottom');
            heatmap_base_clim = get(ax, 'CLim');
        end
        
        % Построение профиля CSD
        smoothCoef = double(csd_smooth_coef);
        smoothCoef = smoothCoef(:);
        smoothCoef = smoothCoef(isfinite(smoothCoef) & isreal(smoothCoef));
        smoothCoef = [smoothCoef; 1];
        smoothCoef = smoothCoef(1);
        smoothCoef = max(smoothCoef, 1);
        
        csd_time_zero_idx = round(ClosestIndex(t_profile, csd_trange) / smoothCoef); % находим индекс данных, соответствующий времени профиля
        csd_profile = csd_image(:, csd_time_zero_idx);
        [max_csd_profile, max_csd_prof_index] = max(csd_profile);
        [min_csd_profile, min_csd_prof_index] = min(csd_profile);
        max_csd_profile_channel = csd_ch_range(max_csd_prof_index);
        min_csd_profile_channel = csd_ch_range(min_csd_prof_index);
        
        csd_profile_ax = axes('Parent', axesParent, 'Units', 'normalized', 'Position', [0.82, 0.06, 0.16, 0.9]);
        set(csd_profile_ax, 'Tag', 'mean_secondary_axis');
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
    


if not(isempty(ev_hists))  && not(show_CSD)
    % Перед отрисовкой центрируем каждый канал по своей медиане.
    ev_hists = ev_hists - median(ev_hists, 2);
    mua_x = linspace(start_time*timeUnitFactor, end_time*timeUnitFactor, size(ev_hists, 2));
    im = imagesc(mua_x, offsets, ev_hists);
    heatmap_handle = im;
    heatmap_base_clim = get(ax, 'CLim');
    
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
    
    mua_profile_ax = axes('Parent', axesParent, 'Units', 'normalized', 'Position', [0.82, 0.06, 0.16, 0.9]);
    set(mua_profile_ax, 'Tag', 'mean_secondary_axis');
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

     

    multiplot(timeAxis, pl_meanDataToPlot, ...
    'ChannelLabels', pl_ch_labels, ...
    'shiftCoeff',pl_shiftCoeff, ...
    'linewidth', pl_widths_in, ...
    'color', pl_colors_in);
    if show_CSD && baselineEnabled
        xline(baselineRight, '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 1);
    end

    [~, gapIdx] = splitConsecutiveChannels(ch_inxs);
    if ~isempty(gapIdx)
        x1 = timeAxis(1);
        x2 = timeAxis(end);
        for k = 1:numel(gapIdx)
            i = gapIdx(k);
            y = (offsets(i) + offsets(i+1)) / 2;
            plot([x1, x2], [y, y], '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1);
        end
    end

    xlabel('Time');
    ylabel('Mean Value');
    if strcmp(sourceType, 'stimuli')
        title([titlename, ', ', num2str(numEvents), ' stimuli'], 'interpreter', 'none')
    else
        title([titlename, ', ', num2str(numEvents), ' events'], 'interpreter', 'none')
    end        

    if autoScale
        debugState('plotMeanEvents', 'Auto scale enabled');
        shiftedData = pl_meanDataToPlot + offsets;
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
    if isempty(customXLimits)
        xlim([start_time, end_time]*timeUnitFactor)
    else
        xlim(customXLimits)
    end
    
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
    calculation_result.show_CSD = show_CSD;
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
    calculation_result.heatmap_handle = heatmap_handle;
    calculation_result.heatmap_base_clim = heatmap_base_clim;
    calculation_result.csd_smooth_coef = csd_smooth_coef;
    calculation_result.csd_contrast_coef = csd_contrast_coef;
    calculation_result.csd_active = csd_active;
    calculation_result.csd_split_by_channel_gaps = csd_split_by_channel_gaps;
    calculation_result.csd_hp_cutoff_hz = hpCutoffHz;
    calculation_result.csd_baseline_boundary = baselineRight;
    calculation_result.hpFilterEnabled = hpFilterEnabled;
    calculation_result.baselineEnabled = baselineEnabled;
    secondaryAxes = findobj(axesParent, 'Type', 'axes', 'Tag', 'mean_secondary_axis');
    if ~isempty(secondaryAxes)
        calculation_result.secondary_axes_handle = secondaryAxes(1);
    else
        calculation_result.secondary_axes_handle = [];
    end

end
