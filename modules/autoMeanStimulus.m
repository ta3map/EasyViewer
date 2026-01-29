function result = autoMeanStimulus(filePath, fileId, params)
    global zav_calling autodetection_settings timeUnitFactor
    
    metadata = zav_calling(filePath);
    if isempty(metadata)
        result = [];
        return
    end

    % Подготовка opts для calculateAndPlotMeanEvents
    % tiledlayoutSize: [4, 1] - основной график (2 строки), таблица (1 строка), scatter (1 строка)
    opts = struct('autoScale', params.autoScale, 'xLimits', params.xLimits, 'showOriginalTraces', params.showOriginalTraces, 'removeBaseline', params.removeBaseline, 'tiledlayoutSize', [4, 1]);
    if isfield(params, 'removeArtifact')
        opts.removeArtifact = params.removeArtifact;
        if isfield(params, 'artifactWindow_ms')
            opts.artifactWindow_ms = params.artifactWindow_ms;
        end
    end
    if isfield(params, 'SmoothingKernel_s')
        opts.SmoothingKernel_s = params.SmoothingKernel_s;
    end
    if isfield(params, 'SubtractMean')
        opts.SubtractMean = params.SubtractMean;
    end
    [meanFig, calcResult] = calculateAndPlotMeanEvents('stimuli', opts);

    % Подготовка detParams для детекции пиков
    % Масштабируем параметры времени для findpeaks (params в секундах, нужно умножить на timeUnitFactor)
    detParams = struct('Polarity', params.Polarity, ...
        'MinPeakProminence', params.MinPeakProminence, ...
        'MinPeakDistance', params.MinPeakDistance_s * timeUnitFactor, ...
        'MaxPeakWidth', params.MaxPeakWidth_s * timeUnitFactor, ...
        'SmoothingKernel_s', params.SmoothingKernel_s * timeUnitFactor); 

    % Детекция пиков: выбираем функцию в зависимости от параметров
    useOriginalData = isfield(params, 'UseOriginalData') && logical(params.UseOriginalData);
    if useOriginalData && isfield(calcResult, 'originalEventsData') && ~isempty(calcResult.originalEventsData)
        events = detectPeaksInOriginalData(calcResult, detParams);
    else
        events = detectPeaksInMeanData(calcResult, detParams);
    end
    
        
    % Добавляем графики и таблицы
    figure(meanFig);
    meanFig = plotEvents(meanFig, events, calcResult);
    addResultsTable(meanFig, events, calcResult);
    plotEventsScatter(meanFig, events, calcResult);
    
    [folder, baseName, ~] = fileparts(metadata.filePath);
    baseName = updateBaseName(baseName, params);
    figureFormat = params.figureFormat;
    if strcmpi(figureFormat, 'png')
        figPath = fullfile(folder, [baseName, '_auto_mean.png']);
        saveas(meanFig, figPath, 'png');
    else
        figPath = fullfile(folder, [baseName, '_auto_mean.fig']);
        savefig(meanFig, figPath);
    end
    
    result = struct( ...
        'module_name', 'autoMeanStimulus', ...
        'module_display_name', 'Auto Mean Stimulus', ...
        'module_description', 'Автоусреднение стимулов', ...
        'report_path', figPath, ...
        'parameters', params, ...
        'calcResult', calcResult, ...
        'events', events, ...
        'tableResultInsert', {{'events.first_onset_by_channel', 'events.median_first_onset', 'events.paired_ttest_pvalue_by_channel', 'events.more_responses_after_zero_by_channel'}});
end

