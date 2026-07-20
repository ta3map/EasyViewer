function testResult = clusterPermutationTest(fullTrialData, timeAxis, params)
    % Выполняет кластерный пермутационный тест для сравнения baseline и post-stimulus периодов
    %
    % Входные параметры:
    %   fullTrialData - массив полных триалов для всего окна (trials × timepoints × channels)
    %   timeAxis - временная ось для всего окна (относительно стимула, в секундах)
    %   params - структура с параметрами:
    %       numPermutations - количество пермутаций
    %       alpha_level - уровень значимости (например, 0.001, 0.01, 0.05)
    %       minClusterSize_ms - минимальный размер кластера в мс
    %       polarity - полярность ('positive' или 'negative')
    %
    % Выходные данные:
    %   testResult - структура с результатами:
    %       t_observed - наблюдаемые t-статистики (timepoints × channels)
    %       clusters - массив структур кластеров для каждого канала
    %       perm_percentiles - перцентили пермутированных t-статистик (2 × timepoints × channels)
    %       threshold_t - порог t-статистики
    
    numPermutations = params.numPermutations;
    alpha_level = params.alpha_level;
    minClusterSize_ms = params.minClusterSize_ms;
    polarity = params.polarity;
    
    % Размеры данных
    numTrials = size(fullTrialData, 1);
    numTimepoints = size(fullTrialData, 2); % ВСЕ точки (baseline + post-stimulus)
    numChannels = size(fullTrialData, 3);
    
    % Вычисляем порог t-статистики из уровня значимости
    % Для одностороннего t-теста: df = numTrials - 1
    df = numTrials - 1;
    threshold_t_abs = tinv(1 - alpha_level, df);
    
    % Применяем знак порога в зависимости от полярности
    if strcmpi(polarity, 'positive')
        threshold_t = threshold_t_abs;
    else
        threshold_t = -threshold_t_abs;
    end
    
    % Определяем индексы baseline и post-stimulus по временной оси
    baselineIdx = timeAxis <= 0;
    postStimIdx = timeAxis > 0;
    numBaselinePoints = sum(baselineIdx);
    numPostStimPoints = sum(postStimIdx);
    
    % Предварительно вычисляем средние baseline для каждого триала
    baseline_means = mean(fullTrialData(:, baselineIdx, :), 2, 'omitnan');
    baseline_means = reshape(baseline_means, numTrials, numChannels);
    
    % Парный t-тест: разницы point - baseline_mean
    diffs = fullTrialData - reshape(baseline_means, numTrials, 1, numChannels);
    t_observed = tObservedFromDiffs(diffs);
    
    % Определение кластеров значимых точек
    clusters = cell(numChannels, 1);
    for ch = 1:numChannels
        if strcmpi(polarity, 'positive')
            significant_mask = t_observed(:, ch) > threshold_t;
        else
            significant_mask = t_observed(:, ch) < threshold_t;
        end
        
        % Используем bwlabel для поиска связных компонентов (для 1D массива)
        % bwlabel работает с 2D, поэтому преобразуем в столбец
        [labeled, numClusters] = bwlabel(significant_mask(:));
        labeled = labeled(:); % убеждаемся, что это вектор
        
        channelClusters = struct('timepoints', {}, 't_sum', {}, 'p_value', {}, 'onset_timepoint', {});
        
        for c = 1:numClusters
            cluster_tp = find(labeled == c);
            
            % Проверка минимального размера кластера (если задан)
            if minClusterSize_ms > 0
                % Оценка временного шага из timeAxis
                if ~isempty(cluster_tp) && length(timeAxis) > 1
                    dt = mean(diff(timeAxis));
                    cluster_size_ms = length(cluster_tp) * dt * 1000; % в миллисекундах
                    if cluster_size_ms < minClusterSize_ms
                        continue;
                    end
                end
            end
            
            % Сумма t-статистик в кластере
            t_sum = sum(t_observed(cluster_tp, ch));
            
            % Первая временная точка кластера (onset эффекта)
            onset_timepoint = min(cluster_tp);
            
            % Фильтруем кластеры с онсетами до нуля
            if timeAxis(onset_timepoint) <= 0
                continue;
            end
            
            cluster = struct('timepoints', cluster_tp, 't_sum', t_sum, 'p_value', nan, 'onset_timepoint', onset_timepoint);
            channelClusters(end+1) = cluster;
        end
        
        clusters{ch} = channelClusters;
    end
    
    % Пермутации для вычисления p-значений
    % Перемешиваем метки baseline/post-stimulus между триалами для всего окна
    
    % Массив для хранения пермутированных t-статистик
    perm_t_stats = nan(numPermutations, numTimepoints, numChannels);
    
    % Создаем waitbar для индикации прогресса пермутаций
    wb = waitbar(0, 'Starting permutations...', 'Name', 'Cluster Permutation Test');
    
    for perm = 1:numPermutations
        % Для парного t-теста в within-trials: случайно меняем знаки разниц для каждого триала
        perm_signs = 2 * (rand(numTrials, numChannels) > 0.5) - 1;
        perm_diffs = diffs .* reshape(perm_signs, numTrials, 1, numChannels);
        perm_t_stats(perm, :, :) = tObservedFromDiffs(perm_diffs);
        
        % Обновляем waitbar
        if mod(perm, max(1, round(numPermutations/100))) == 0 || perm == numPermutations
            waitbar(perm / numPermutations, wb, sprintf('Permutation %d of %d (%.1f%%)', perm, numPermutations, 100*perm/numPermutations));
        end
    end
    
    % Закрываем waitbar
    try
        if ishandle(wb)
            close(wb);
        end
    catch
        % Игнорируем ошибки при закрытии waitbar
    end
    
    % Вычисляем перцентили для "облака" пермутаций (векторизованно)
    perm_percentiles = nan(2, numTimepoints, numChannels);
    for ch = 1:numChannels
        % Берем все данные для канала сразу
        ch_data = perm_t_stats(:, :, ch); % numPermutations × numTimepoints
        % Вычисляем перцентили по первому измерению (по пермутациям)
        perm_percentiles(1, :, ch) = prctile(ch_data, 2.5, 1);
        perm_percentiles(2, :, ch) = prctile(ch_data, 97.5, 1);
    end
    
    % Вычисляем p-значения для кластеров
    % Оптимизация: вычисляем максимальные статистики кластеров для каждой пермутации заранее
    max_cluster_stats = nan(numPermutations, numChannels);
    for perm = 1:numPermutations
        for ch = 1:numChannels
            perm_t_ch = perm_t_stats(perm, :, ch);
            if strcmpi(polarity, 'positive')
                perm_significant = perm_t_ch > threshold_t;
            else
                perm_significant = perm_t_ch < threshold_t;
            end
            
            if any(perm_significant)
                [perm_labeled, perm_numClusters] = bwlabel(perm_significant);
                perm_cluster_sums = [];
                for pc = 1:perm_numClusters
                    perm_cluster_tp = find(perm_labeled == pc);
                    % Фильтруем кластеры с онсетами до нуля
                    perm_onset = min(perm_cluster_tp);
                    if timeAxis(perm_onset) <= 0
                        continue;
                    end
                    perm_cluster_sums(end+1) = sum(perm_t_ch(perm_cluster_tp));
                end
                if isempty(perm_cluster_sums)
                    max_cluster_stats(perm, ch) = 0;
                elseif strcmpi(polarity, 'positive')
                    max_cluster_stats(perm, ch) = max(perm_cluster_sums);
                else
                    max_cluster_stats(perm, ch) = min(perm_cluster_sums);
                end
            else
                max_cluster_stats(perm, ch) = 0;
            end
        end
    end
    
    % Теперь можем освободить память от perm_t_stats (он больше не нужен)
    clear perm_t_stats;
    
    % Вычисляем p-значения используя сохраненные максимальные статистики
    for ch = 1:numChannels
        channelClusters = clusters{ch};
        max_perm_t_sums = max_cluster_stats(:, ch);
        
        % Диагностика: выводим информацию о распределении пермутаций
        if ~isempty(channelClusters)
            fprintf('\n=== Диагностика для канала %d ===\n', ch);
            fprintf('Уровень значимости (alpha): %.4f\n', alpha_level);
            fprintf('Порог t-статистики: %.4f (df = %d)\n', threshold_t, df);
            fprintf('Количество пермутаций: %d\n', numPermutations);
            fprintf('Максимальная статистика кластера в пермутациях:\n');
            fprintf('  Min: %.2f, Max: %.2f, Median: %.2f, Mean: %.2f\n', ...
                min(max_perm_t_sums), max(max_perm_t_sums), median(max_perm_t_sums), mean(max_perm_t_sums));
            fprintf('Наблюдаемые кластеры (первые 10):\n');
            for c = 1:min(10, length(channelClusters))
                cluster = channelClusters(c);
                fprintf('  Cluster %d: size=%d, t_sum=%.2f\n', c, length(cluster.timepoints), cluster.t_sum);
            end
            if length(channelClusters) > 10
                fprintf('  ... и еще %d кластеров\n', length(channelClusters) - 10);
            end
            % Находим самые большие кластеры
            cluster_sizes = arrayfun(@(x) length(x.timepoints), channelClusters);
            cluster_sums = arrayfun(@(x) x.t_sum, channelClusters);
            [sorted_sizes, idx] = sort(cluster_sizes, 'descend');
            fprintf('Самые большие кластеры (по размеру):\n');
            for i = 1:min(5, length(idx))
                c = idx(i);
                cluster = channelClusters(c);
                fprintf('  Cluster %d: size=%d, t_sum=%.2f\n', c, length(cluster.timepoints), cluster.t_sum);
            end
            [sorted_sums, idx2] = sort(cluster_sums, 'descend');
            fprintf('Кластеры с наибольшей статистикой:\n');
            for i = 1:min(5, length(idx2))
                c = idx2(i);
                cluster = channelClusters(c);
                fprintf('  Cluster %d: size=%d, t_sum=%.2f\n', c, length(cluster.timepoints), cluster.t_sum);
            end
        end
        
        for c = 1:length(channelClusters)
            cluster = channelClusters(c);
            
            % P-значение: доля пермутаций с кластерами >= наблюдаемого (для одностороннего теста)
            if strcmpi(polarity, 'positive')
                num_exceeding = sum(max_perm_t_sums >= cluster.t_sum);
            else
                num_exceeding = sum(max_perm_t_sums <= cluster.t_sum);
            end
            p_value = num_exceeding / numPermutations;
            if p_value == 0
                p_value = 1 / numPermutations; % минимальное p-значение
            end
            
            % Дополнительная диагностика для больших кластеров
            if length(cluster.timepoints) > 100 && p_value > 0.9
                fprintf('  Кластер %d (size=%d, t_sum=%.2f): %d пермутаций >= наблюдаемого (p=%.4f)\n', ...
                    c, length(cluster.timepoints), cluster.t_sum, num_exceeding, p_value);
            end
            
            channelClusters(c).p_value = p_value;
        end
        clusters{ch} = channelClusters;
    end
    
    % Освобождаем память
    clear max_cluster_stats;
    
    % Формируем результат
    testResult = struct();
    testResult.t_observed = t_observed;
    testResult.clusters = clusters;
    testResult.perm_percentiles = perm_percentiles;
    testResult.threshold_t = threshold_t;
end

function t = tObservedFromDiffs(diffs)
% diffs: trials × timepoints × channels
    mu = mean(diffs, 1, 'omitnan');
    sd = std(diffs, 0, 1, 'omitnan');
    n = sum(~isnan(diffs), 1);
    t = mu ./ (sd ./ sqrt(double(n)));
    t(sd == 0 | n < 2 | ~isfinite(t)) = 0;
    t = reshape(t, size(diffs, 2), size(diffs, 3));
end

