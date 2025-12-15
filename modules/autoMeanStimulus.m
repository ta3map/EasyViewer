function result = autoMeanStimulus(filePath, fileId, params)
    global zav_calling autodetection_settings timeUnitFactor
    
    metadata = zav_calling(filePath);
    
    % Подготовка opts для calculateAndPlotMeanEvents
    % tiledlayoutSize: [4, 1] - основной график (2 строки), таблица (1 строка), scatter (1 строка)
    opts = struct('autoScale', params.autoScale, 'xLimits', params.xLimits, 'showOriginalTraces', params.showOriginalTraces, 'removeBaseline', params.removeBaseline, 'tiledlayoutSize', [4, 1]);
    if isfield(params, 'removeArtifact')
        opts.removeArtifact = params.removeArtifact;
        if isfield(params, 'artifactWindow_ms')
            opts.artifactWindow_ms = params.artifactWindow_ms;
        end
    end
    [meanFig, calcResult] = calculateAndPlotMeanEvents('stimuli', opts);

    % Подготовка detParams для detectPeaksInMeanData
    detParams = struct('Polarity', params.Polarity, ...
        'MinPeakProminence', params.MinPeakProminence, ...
        'MinPeakDistance', params.MinPeakDistance_s, ...
        'MaxPeakWidth', params.MaxPeakWidth_s, ...
        'SmoothingKernel_s', params.SmoothingKernel_s, ...
        'UseOriginalData', params.UseOriginalData); 

    % Детекция пиков
    events = detectPeaksInMeanData(calcResult, detParams);
        
    % Добавляем графики и таблицы
    figure(meanFig);
    meanFig = plotEvents(meanFig, events, calcResult);
    addResultsTable(meanFig, events, calcResult);
    plotEventsScatter(meanFig, events, calcResult);
    
    [folder, baseName, ~] = fileparts(metadata.filePath);
    figureFormat = params.figureFormat;
    if strcmpi(figureFormat, 'png')
        figPath = fullfile(folder, [baseName, '_auto_mean.png']);
        saveas(meanFig, figPath, 'png');
    else
        figPath = fullfile(folder, [baseName, '_auto_mean.fig']);
        savefig(meanFig, figPath);
    end
    dataPath = fullfile(folder, [baseName, '_auto_mean.meta']);
    save(dataPath, 'calcResult', 'params', '-mat');
    
    result = struct( ...
        'module_name', 'autoMeanStimulus', ...
        'module_display_name', 'Auto Mean Stimulus', ...
        'module_description', 'Автоусреднение стимулов', ...
        'report_path', figPath, ...
        'data_path', dataPath, ...
        'parameters', params, ...
        'events', events);
end

