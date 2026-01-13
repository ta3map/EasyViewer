function result = autoClusterPermutationTest(filePath, fileId, params)
    global zav_calling timeUnitFactor
    global stims lfp time Fs N
    
    metadata = zav_calling(filePath);
    
    % Извлечение параметров из структуры params
    if isfield(params, 'visualization')
        sourceParams = params.visualization;
        xLimits = sourceParams.xLimits;
    else
        sourceParams = params;
        xLimits = params.xLimits;
    end
    
    removeBaseline = getBoolParam(sourceParams, 'removeBaseline', false);
    removeArtifact = getBoolParam(sourceParams, 'removeArtifact', false);
    artifactWindow_ms = getNumericParam(sourceParams, 'artifactWindow_ms', 1);
    
    % Извлечение параметров диапазона триалов
    startTrial = [];
    endTrial = [];
    removeEdgeTrials = false;
    if isfield(params, 'test_parameters')
        testParamsSource = params.test_parameters;
        if isfield(testParamsSource, 'startTrial') && ~isempty(testParamsSource.startTrial)
            startTrial = testParamsSource.startTrial;
        end
        if isfield(testParamsSource, 'endTrial') && ~isempty(testParamsSource.endTrial)
            endTrial = testParamsSource.endTrial;
        end
        removeEdgeTrials = getBoolParam(testParamsSource, 'removeEdgeTrials', false);
    end
    
    [~, ~, fullTrialData, timeAxis] = extractTrialData(...
        lfp, time, Fs, N, stims, xLimits, timeUnitFactor, ...
        removeBaseline, removeArtifact, artifactWindow_ms, startTrial, endTrial, removeEdgeTrials);
    
    % Количество проанализированных триалов
    numTrials = size(fullTrialData, 1);
    
    % Параметры теста
    if isfield(params, 'test_parameters')
        testParamsSource = params.test_parameters;
    else
        testParamsSource = params;
    end
    testParams = struct();
    testParams.numPermutations = testParamsSource.numPermutations;
    testParams.clusterThreshold = testParamsSource.clusterThreshold;
    if isfield(testParamsSource, 'minClusterSize_ms')
        testParams.minClusterSize_ms = testParamsSource.minClusterSize_ms;
    end
    
    testResult = clusterPermutationTest(fullTrialData, timeAxis, testParams);
    
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
        if isempty(clusters)
            continue;
        end
        
        % Подсчет значимых кластеров одним проходом
        significantMask = false(length(clusters), 1);
        for c = 1:length(clusters)
            if isfield(clusters(c), 'p_value') && ~isnan(clusters(c).p_value) && clusters(c).p_value < 0.05
                significantMask(c) = true;
            end
        end
        significantClusters = sum(significantMask);
        totalSignificantClusters = totalSignificantClusters + significantClusters;
        
        fprintf('Channel %s: %d cluster(s) found', channelLabels{ch}, length(clusters));
        if significantClusters > 0
            fprintf(', %d significant (p < 0.05)\n', significantClusters);
            for c = find(significantMask)'
                fprintf('  Cluster %d: size = %d timepoints, p = %.4f, t_sum = %.2f\n', ...
                    c, length(clusters(c).timepoints), clusters(c).p_value, clusters(c).t_sum);
            end
        else
            fprintf(' (none significant)');
            for c = 1:length(clusters)
                if isfield(clusters(c), 'p_value')
                    fprintf('\n  Cluster %d: size = %d timepoints, p = %.4f (not significant)', ...
                        c, length(clusters(c).timepoints), clusters(c).p_value);
                end
            end
            fprintf('\n');
        end
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
                        cluster_onsets_ms(end+1) = timeAxis(onset_idx) * 1000;
                    end
                end
            end
        end
    end
    
    % Первый онсет ответа (первый онсет больше нуля)
    positive_onsets = cluster_onsets_ms(cluster_onsets_ms > 0);
    first_onset_ms = [];
    if ~isempty(positive_onsets)
        first_onset_ms = min(positive_onsets);
    end
    
    % Параметры визуализации
    showBaseline = getBoolParam(params, 'showBaselinePeriod', true, 'visualization');
    showMeanSignal = getBoolParam(params, 'showMeanSignal', false, 'visualization');
    
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
    
    result = struct( ...
        'module_name', 'autoClusterPermutationTest', ...
        'module_display_name', 'Cluster Permutation Test', ...
        'module_description', 'Кластерный пермутационный тест', ...
        'report_path', figPath, ...
        'parameters', params, ...
        'test_result', testResult, ...
        'timeAxis', timeAxis, ...
        'cluster_onsets_ms', cluster_onsets_ms, ...
        'first_onset_ms', first_onset_ms);
end

% Вспомогательная функция для извлечения boolean параметров
function val = getBoolParam(params, fieldName, defaultValue, subStruct)
    if nargin < 4
        subStruct = '';
    end
    
    if ~isempty(subStruct) && isfield(params, subStruct) && isfield(params.(subStruct), fieldName)
        source = params.(subStruct);
    elseif isfield(params, fieldName)
        source = params;
    else
        val = defaultValue;
        return;
    end
    
    val = logical(source.(fieldName));
    if ~isscalar(val)
        val = any(val);
    end
end

% Вспомогательная функция для извлечения числовых параметров
function val = getNumericParam(params, fieldName, defaultValue, subStruct)
    if nargin < 4
        subStruct = '';
    end
    
    if ~isempty(subStruct) && isfield(params, subStruct) && isfield(params.(subStruct), fieldName)
        val = params.(subStruct).(fieldName);
    elseif isfield(params, fieldName)
        val = params.(fieldName);
    else
        val = defaultValue;
    end
end

