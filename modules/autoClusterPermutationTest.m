function result = autoClusterPermutationTest(filePath, fileId, params)
    global zav_calling timeUnitFactor
    global stims lfp time Fs N
    
    metadata = zav_calling(filePath);
    
    % Извлечение параметров из структуры params
    xLimits = params.xLimits;
    removeBaseline = params.removeBaseline;
    removeArtifact = params.removeArtifact;
    artifactWindow_ms = params.artifactWindow_ms;
    
    [~, ~, fullTrialData, timeAxis] = extractTrialData(...
        lfp, time, Fs, N, stims, xLimits, timeUnitFactor, ...
        removeBaseline, removeArtifact, artifactWindow_ms, [], [], false);
    
    % Количество проанализированных триалов
    numTrials = size(fullTrialData, 1);
    
    % Параметры теста
    testParams.numPermutations = params.numPermutations;
    testParams.threshold_t = params.threshold_t;
    testParams.polarity = params.polarity;
    testParams.minClusterSize_ms = params.minClusterSize_ms;
    
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
    fprintf('Parameters: %d permutations, threshold_t = %.3f\n', ...
        testParams.numPermutations, testParams.threshold_t);
    fprintf('Threshold t-statistic: %.3f\n', testResult.threshold_t);
    fprintf('Number of channels: %d\n', numChannels);
    fprintf('Number of timepoints: %d\n', size(testResult.t_observed, 1));
    fprintf('\n');
    
    totalSignificantClusters = 0;
    significantChannels = {};
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
        
        if significantClusters > 0
            significantChannels{end+1} = channelLabels{ch};
        end
        
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
    
    % Определение значимости ответа для tableResultInsert
    if ~isempty(significantChannels)
        response = strjoin(significantChannels, ', ');
    else
        response = '';
    end
    
    % Собираем онсеты значимых кластеров всех каналов в одномерный массив (в миллисекундах)
    % Кластеры с онсетами до нуля уже отфильтрованы в clusterPermutationTest
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
    
    % Первый онсет ответа
    cluster_first_onset_ms = [];
    if ~isempty(cluster_onsets_ms)
        cluster_first_onset_ms = min(cluster_onsets_ms);
    end
    
    % Определение has_response на основе cluster_first_onset_ms
    has_response = ~isempty(cluster_first_onset_ms);
    
    % Параметры визуализации
    showBaseline = params.showBaselinePeriod;
    showMeanSignal = params.showMeanSignal;
    
    % Получаем имя файла из metadata
    [~, fileName, ~] = fileparts(metadata.filePath);
    fig = plotClusterPermutationResults(testResult, timeAxis, channelLabels, timeUnitFactor, showBaseline, fileName, numTrials, fullTrialData, showMeanSignal);
    
    [folder, baseName, ~] = fileparts(metadata.filePath);
    baseName = updateBaseName(baseName, params);
    
    figureFormat = params.figureFormat;
    
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
        'cluster_first_onset_ms', cluster_first_onset_ms, ...
        'has_response', has_response, ...
        'response', response, ...
        'tableResultInsert', {{'cluster_first_onset_ms', 'has_response'}});
end

