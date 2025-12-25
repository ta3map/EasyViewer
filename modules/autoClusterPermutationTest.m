function result = autoClusterPermutationTest(filePath, fileId, params)
    global zav_calling timeUnitFactor
    global stims lfp time Fs N
    
    metadata = zav_calling(filePath);
    
    % Извлечение параметров из структуры params
    if isfield(params, 'visualization')
        visParams = params.visualization;
        xLimits = visParams.xLimits;
        if isfield(visParams, 'removeBaseline')
            removeBaseline = logical(visParams.removeBaseline);
            if ~isscalar(removeBaseline)
                removeBaseline = any(removeBaseline);
            end
        else
            removeBaseline = false;
        end
        if isfield(visParams, 'removeArtifact')
            removeArtifact = logical(visParams.removeArtifact);
            if ~isscalar(removeArtifact)
                removeArtifact = any(removeArtifact);
            end
        else
            removeArtifact = false;
        end
        artifactWindow_ms = 1;
        if isfield(visParams, 'artifactWindow_ms')
            artifactWindow_ms = visParams.artifactWindow_ms;
        end
    else
        xLimits = params.xLimits;
        if isfield(params, 'removeBaseline')
            removeBaseline = logical(params.removeBaseline);
            if ~isscalar(removeBaseline)
                removeBaseline = any(removeBaseline);
            end
        else
            removeBaseline = false;
        end
        if isfield(params, 'removeArtifact')
            removeArtifact = logical(params.removeArtifact);
            if ~isscalar(removeArtifact)
                removeArtifact = any(removeArtifact);
            end
        else
            removeArtifact = false;
        end
        artifactWindow_ms = 1;
        if isfield(params, 'artifactWindow_ms')
            artifactWindow_ms = params.artifactWindow_ms;
        end
    end
    
    % Извлечение параметров диапазона триалов
    startTrial = [];
    endTrial = [];
    removeEdgeTrials = false;
    if isfield(params, 'test_parameters')
        if isfield(params.test_parameters, 'startTrial') && ~isempty(params.test_parameters.startTrial)
            startTrial = params.test_parameters.startTrial;
        end
        if isfield(params.test_parameters, 'endTrial') && ~isempty(params.test_parameters.endTrial)
            endTrial = params.test_parameters.endTrial;
        end
        if isfield(params.test_parameters, 'removeEdgeTrials')
            removeEdgeTrials = logical(params.test_parameters.removeEdgeTrials);
            if ~isscalar(removeEdgeTrials)
                removeEdgeTrials = any(removeEdgeTrials);
            end
        end
    end
    
    [baselineData, postStimData, fullTrialData, timeAxis] = extractTrialData(...
        lfp, time, Fs, N, stims, xLimits, timeUnitFactor, ...
        removeBaseline, removeArtifact, artifactWindow_ms, startTrial, endTrial, removeEdgeTrials);
    
    % Количество проанализированных триалов
    numTrials = size(fullTrialData, 1);
    
    % Параметры теста
    testParams = struct();
    if isfield(params, 'test_parameters')
        testParams.numPermutations = params.test_parameters.numPermutations;
        testParams.clusterThreshold = params.test_parameters.clusterThreshold;
        if isfield(params.test_parameters, 'minClusterSize_ms')
            testParams.minClusterSize_ms = params.test_parameters.minClusterSize_ms;
        end
    else
        testParams.numPermutations = params.numPermutations;
        testParams.clusterThreshold = params.clusterThreshold;
        if isfield(params, 'minClusterSize_ms')
            testParams.minClusterSize_ms = params.minClusterSize_ms;
        end
    end
    
    testResult = clusterPermutationTest(baselineData, postStimData, fullTrialData, timeAxis, testParams);
    
    global hd channelTable
    channelSettings = get(channelTable, 'Data');
    activeChannels = find([channelSettings{:, 2}]);
    ch_labels = hd.recChNames(:);
    channelLabels = ch_labels(activeChannels);
    
    % Определяем количество каналов из результатов теста
    numChannels = size(testResult.t_observed, 2);
    
    % Вывод результатов в консоль
    fprintf('\n=== Cluster Permutation Test Results ===\n');
    fprintf('Parameters: %d permutations, threshold = %.3f\n', ...
        testParams.numPermutations, testParams.clusterThreshold);
    fprintf('Threshold t-statistic: %.3f\n', testResult.threshold_t);
    fprintf('Number of channels: %d\n', numChannels);
    fprintf('Number of timepoints: %d\n', size(testResult.t_observed, 1));
    fprintf('\n');
    
    totalSignificantClusters = 0;
    for ch = 1:numChannels
        clusters = testResult.clusters{ch};
        significantClusters = 0;
        for c = 1:length(clusters)
            if isfield(clusters(c), 'p_value') && ~isnan(clusters(c).p_value) && clusters(c).p_value < 0.05
                significantClusters = significantClusters + 1;
            end
        end
        
        if significantClusters > 0 || length(clusters) > 0
            fprintf('Channel %s: %d cluster(s) found', channelLabels{ch}, length(clusters));
            if significantClusters > 0
                fprintf(', %d significant (p < 0.05)', significantClusters);
                fprintf('\n');
                for c = 1:length(clusters)
                    if isfield(clusters(c), 'p_value') && ~isnan(clusters(c).p_value) && clusters(c).p_value < 0.05
                        fprintf('  Cluster %d: size = %d timepoints, p = %.4f, t_sum = %.2f\n', ...
                            c, length(clusters(c).timepoints), clusters(c).p_value, clusters(c).t_sum);
                    end
                end
            else
                fprintf(' (none significant)');
                % Выводим информацию о кластерах даже если они не значимы
                for c = 1:length(clusters)
                    if isfield(clusters(c), 'p_value')
                        fprintf('\n  Cluster %d: size = %d timepoints, p = %.4f (not significant)', ...
                            c, length(clusters(c).timepoints), clusters(c).p_value);
                    end
                end
                fprintf('\n');
            end
        end
        totalSignificantClusters = totalSignificantClusters + significantClusters;
    end
    
    fprintf('\nTotal significant clusters: %d\n', totalSignificantClusters);
    fprintf('==========================================\n\n');
    
    % Собираем онсеты значимых кластеров всех каналов в одномерный массив (в миллисекундах)
    cluster_onsets_ms = [];
    for ch = 1:numChannels
        clusters = testResult.clusters{ch};
        for c = 1:length(clusters)
            if isfield(clusters(c), 'p_value') && ~isnan(clusters(c).p_value) && clusters(c).p_value < 0.05
                if isfield(clusters(c), 'onset_timepoint')
                    onset_idx = clusters(c).onset_timepoint;
                    if onset_idx > 0 && onset_idx <= length(timeAxis)
                        onset_time_sec = timeAxis(onset_idx);
                        onset_time_ms = onset_time_sec * 1000; % преобразуем в миллисекунды
                        cluster_onsets_ms(end+1) = onset_time_ms;
                    end
                end
            end
        end
    end
    
    % Параметр показа baseline периода
    showBaseline = true;
    if isfield(params, 'visualization') && isfield(params.visualization, 'showBaselinePeriod')
        showBaseline = params.visualization.showBaselinePeriod;
    elseif isfield(params, 'showBaselinePeriod')
        showBaseline = params.showBaselinePeriod;
    end
    
    % Параметр показа среднего сигнала
    showMeanSignal = false;
    if isfield(params, 'visualization') && isfield(params.visualization, 'showMeanSignal')
        showMeanSignal = logical(params.visualization.showMeanSignal);
        if ~isscalar(showMeanSignal)
            showMeanSignal = any(showMeanSignal);
        end
    elseif isfield(params, 'showMeanSignal')
        showMeanSignal = logical(params.showMeanSignal);
        if ~isscalar(showMeanSignal)
            showMeanSignal = any(showMeanSignal);
        end
    end
    
    % Получаем имя файла из metadata
    [~, fileName, ~] = fileparts(metadata.filePath);
    fig = plotClusterPermutationResults(testResult, timeAxis, channelLabels, timeUnitFactor, showBaseline, fileName, numTrials, fullTrialData, showMeanSignal);
    
    [folder, baseName, ~] = fileparts(metadata.filePath);
    baseName = updateBaseName(baseName, params);
    
    if isfield(params, 'output')
        figureFormat = params.output.figureFormat;
    else
        figureFormat = params.figureFormat;
    end
    
    if strcmpi(figureFormat, 'png')
        figPath = fullfile(folder, [baseName, '_cluster_perm.png']);
        saveas(fig, figPath, 'png');
    else
        figPath = fullfile(folder, [baseName, '_cluster_perm.fig']);
        savefig(fig, figPath);
    end
    
    dataPath = fullfile(folder, [baseName, '_cluster_perm.meta']);
    save(dataPath, 'testResult', 'params', 'timeAxis', 'cluster_onsets_ms', '-mat');
    
    result = struct( ...
        'module_name', 'autoClusterPermutationTest', ...
        'module_display_name', 'Cluster Permutation Test', ...
        'module_description', 'Кластерный пермутационный тест', ...
        'report_path', figPath, ...
        'data_path', dataPath, ...
        'parameters', params, ...
        'test_result', testResult);
end

