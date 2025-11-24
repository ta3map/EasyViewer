function result = autoMeanStimulus(filePath)
    global zav_calling
    metadata = zav_calling(filePath);
    opts = struct('autoScale', true, 'xLimits', [-100, 300]);
    [meanFig, calcResult] = calculateAndPlotMeanEvents('stimuli', opts);
    figure(meanFig);
    [folder, baseName, ~] = fileparts(metadata.filePath);
    imagePath = fullfile(folder, [baseName, '_auto_mean.png']);
    dataPath = fullfile(folder, [baseName, '_auto_mean.meta']);
    save(dataPath, '-struct', 'calcResult');
    saveas(meanFig, imagePath, 'png');
    
    result = struct( ...
        'module_name', 'autoMeanStimulus', ...
        'module_display_name', 'Auto Mean Stimulus', ...
        'module_description', 'Автоусреднение стимулов', ...
        'report_path', imagePath, ...
        'data_path', dataPath, ...
        'parameters', opts);
end

