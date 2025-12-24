function fig = plotClusterPermutationResults(testResult, timeAxis, channelLabels, timeUnitFactor, showBaseline)
    if nargin < 5
        showBaseline = false; % по умолчанию не показываем baseline
    end
    % Вспомогательная функция для определения единиц времени
    function unitLabel = getTimeUnitLabel(factor)
        if abs(factor - 1000) < 0.1
            unitLabel = 'ms';
        elseif abs(factor - 1) < 0.1
            unitLabel = 's';
        elseif abs(factor - 1/60) < 0.001
            unitLabel = 'min';
        else
            unitLabel = '';
        end
    end
    numChannels = size(testResult.t_observed, 2);
    numTimepoints = size(testResult.t_observed, 1);
    
    % Оптимизация: уменьшаем детализацию для большого количества точек
    % Если точек слишком много, прореживаем для визуализации
    maxPointsForVisualization = 5000;
    downsampleFactor = 1;
    if numTimepoints > maxPointsForVisualization
        downsampleFactor = ceil(numTimepoints / maxPointsForVisualization);
    end
    
    fig = figure('Name', 'Cluster Permutation Test Results', 'Tag', 'clusterPermutationResult');
    fig.Position = [32, 64, 1024, 768];
    
    t = tiledlayout(fig, numChannels, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    
    % Теперь timeAxis должен соответствовать numTimepoints (весь трейс)
    % Проверяем соответствие размеров
    if length(timeAxis) ~= numTimepoints
        % Если размеры не совпадают, используем timeAxis как есть или создаем новую ось
        if numTimepoints > 0
            if length(timeAxis) > numTimepoints
                timeAxis = timeAxis(1:numTimepoints);
            elseif length(timeAxis) < numTimepoints
                % Дополняем временную ось
                dt = mean(diff(timeAxis));
                additionalPoints = numTimepoints - length(timeAxis);
                additionalTimes = (timeAxis(end) + dt:dt:timeAxis(end) + additionalPoints*dt)';
                timeAxis = [timeAxis; additionalTimes];
            end
        end
    end
    
    % Выделяем baseline и post-stimulus части для визуализации
    baselineIdx = timeAxis <= 0;
    postStimIdx = timeAxis > 0;
    baselineTimeAxis = timeAxis(baselineIdx);
    
    % Масштабируем время с учетом timeUnitFactor (уже учитывает единицы)
    timeAxis_scaled = timeAxis * timeUnitFactor;
    baselineTimeAxis_scaled = baselineTimeAxis * timeUnitFactor;
    
    % Прореживаем данные для визуализации, если нужно
    if downsampleFactor > 1
        idx_vis = 1:downsampleFactor:numTimepoints;
        timeAxis_vis = timeAxis_scaled(idx_vis);
    else
        idx_vis = 1:numTimepoints;
        timeAxis_vis = timeAxis_scaled;
    end
    
    for ch = 1:numChannels
        ax = nexttile(t);
        
        t_obs = testResult.t_observed(:, ch);
        perm_lower = squeeze(testResult.perm_percentiles(1, :, ch));
        perm_upper = squeeze(testResult.perm_percentiles(2, :, ch));
        
        % Прореживаем для визуализации
        if downsampleFactor > 1
            t_obs_vis = t_obs(idx_vis);
            perm_lower_vis = perm_lower(idx_vis);
            perm_upper_vis = perm_upper(idx_vis);
        else
            t_obs_vis = t_obs;
            perm_lower_vis = perm_lower;
            perm_upper_vis = perm_upper;
        end
        
        hold(ax, 'on');
        
        % Облако пермутаций (упрощенная версия для производительности)
        % Для большого количества точек используем упрощенную визуализацию
        if ~isempty(timeAxis_vis) && length(perm_lower_vis) == length(timeAxis_vis)
            if length(timeAxis_vis) > 1000
                % Для большого количества точек используем только линии вместо fill
                plot(ax, timeAxis_vis, perm_lower_vis, '--', 'Color', [0.6, 0.6, 0.6], 'LineWidth', 0.5);
                plot(ax, timeAxis_vis, perm_upper_vis, '--', 'Color', [0.6, 0.6, 0.6], 'LineWidth', 0.5);
            else
                % Для малого количества точек используем fill
                x_fill = [timeAxis_vis(:); flipud(timeAxis_vis(:))];
                y_fill = [perm_lower_vis(:); flipud(perm_upper_vis(:))];
                fill(ax, x_fill, y_fill, [0.9, 0.9, 0.9], 'FaceAlpha', 0.4, 'EdgeColor', 'none');
            end
        end
        
        % Наблюдаемая t-статистика (весь трейс)
        if ~isempty(timeAxis_vis)
            plot(ax, timeAxis_vis, t_obs_vis, 'b-', 'LineWidth', 2);
        end
        
        % Пороги значимости убраны по запросу пользователя
        
        % Выделение значимых кластеров (используем полные данные для точности)
        clusters = testResult.clusters{ch};
        if ~isempty(clusters) && ~isempty(timeAxis_scaled)
            for c = 1:length(clusters)
                cluster = clusters(c);
                % Проверяем p-значение
                if isfield(cluster, 'p_value') && ~isnan(cluster.p_value) && cluster.p_value < 0.05
                    cluster_tp = cluster.timepoints;
                    % Проверяем, что индексы кластера не выходят за границы данных
                    if ~isempty(cluster_tp) && max(cluster_tp) <= length(t_obs) && max(cluster_tp) <= length(timeAxis_scaled)
                        % Используем полные данные (без даунсэмплинга) для кластеров
                        cluster_times = timeAxis_scaled(cluster_tp);
                        cluster_t_values = t_obs(cluster_tp);
        
                        % Визуализация кластера - заливка от порога до значения
                        threshold = testResult.threshold_t;
                        % Определяем направление кластера
                        if mean(cluster_t_values) > 0
                            y_bottom = threshold;
                        else
                            y_bottom = -threshold;
                        end
                        
                        if length(cluster_times) > 100
                            % Для больших кластеров используем только контур с заливкой
                            x_cluster = [cluster_times(:); flipud(cluster_times(:))];
                            y_cluster = [cluster_t_values(:); repmat(y_bottom, size(cluster_t_values(:)))];
                            fill(ax, x_cluster, y_cluster, [0, 0.8, 0], 'FaceAlpha', 0.5, 'EdgeColor', [0, 0.6, 0], 'LineWidth', 2);
                        else
                            % Для малых кластеров - заливка от порога до значения
                            x_cluster = [cluster_times(:); flipud(cluster_times(:))];
                            y_cluster = [cluster_t_values(:); repmat(y_bottom, size(cluster_t_values(:)))];
                            fill(ax, x_cluster, y_cluster, [0, 0.8, 0], 'FaceAlpha', 0.5, 'EdgeColor', [0, 0.6, 0], 'LineWidth', 2);
                            % Также рисуем линию поверх для лучшей видимости
                            plot(ax, cluster_times, cluster_t_values, 'Color', [0, 0.7, 0], 'LineWidth', 2.5);
                        end
                        
                        % Отмечаем точку онсета красным маркером
                        if isfield(cluster, 'onset_timepoint') && ~isnan(cluster.onset_timepoint)
                            onset_idx = cluster.onset_timepoint;
                            if onset_idx > 0 && onset_idx <= length(timeAxis_scaled) && onset_idx <= length(t_obs) && onset_idx <= length(timeAxis)
                                onset_time_scaled = timeAxis_scaled(onset_idx);
                                onset_time_sec = timeAxis(onset_idx);  % исходное время в секундах
                                onset_value = t_obs(onset_idx);
                                
                                % Красный маркер (уменьшенный в 3 раза: было 8, стало ~3)
                                plot(ax, onset_time_scaled, onset_value, 'ro', 'MarkerSize', 3, 'MarkerFaceColor', 'r', 'MarkerEdgeColor', 'r', 'LineWidth', 1);
                                
                                % Подпись с временем в мс (всегда в миллисекундах)
                                time_ms = onset_time_sec * 1000;
                                time_label = sprintf('%.1f ms', time_ms);
                                
                                % Добавляем текст с фоном (под значением t-статистики)
                                % Получаем текущие пределы оси Y для правильного позиционирования
                                ylim_current = ylim(ax);
                                y_range = ylim_current(2) - ylim_current(1);
                                % Позиционируем текст ниже точки онсета
                                text_y = onset_value - y_range * 0.05;  % на 5% диапазона ниже
                                
                                text(ax, onset_time_scaled, text_y, time_label, ...
                                    'Color', 'k', ...
                                    'BackgroundColor', [0.9, 0.9, 0.9], ...
                                    'FontSize', 8, ...
                                    'HorizontalAlignment', 'left', ...
                                    'VerticalAlignment', 'top', ...
                                    'Margin', 2);
                            end
                        end
                    end
                end
            end
        end
        
        % Вертикальная линия на t=0 (момент стимула)
        xline(ax, 0, 'k-', 'LineWidth', 1.5);
        
        % Baseline период уже включен в t_obs, так что ничего дополнительного не нужно
        
        % Убираем дублирование подписей - оставляем только title
        title(ax, sprintf('%s', channelLabels{ch}));
        grid(ax, 'on');
        
        hold(ax, 'off');
    end
    
    % Подписи осей только на tiledlayout
    xlabel(t, sprintf('Time (%s)', getTimeUnitLabel(timeUnitFactor)), 'FontSize', 12);
    ylabel(t, 't-statistic', 'FontSize', 12);
end

