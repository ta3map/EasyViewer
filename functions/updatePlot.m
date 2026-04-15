function updatePlot()
    % disp('Plot is updated')
    global chosen_time_interval time_back cond time lfp_file mean_group_ch ch_inxs m_coef Fs newFs timeUnitFactor multiax
    global ch_labels_l shiftCoeff widths_in_l colors_in_l spks std_coef selectedUnit matFilePath stims events timeSlider timeZeroEdit
    global viewerYlimManual viewerYlim yLimMinEdit yLimMaxEdit
    global data time_in filterSettings filter_avaliable csd_smooth_coef
    global csd_contrast_coef csd_avaliable lfpVar
    global csd_split_by_channel_gaps
    global csd_image csd_t_range csd_ch_range offsets
    global art_rem_settings lines_and_styles
    global visualSettings
    global selectedCenter sweep_info sweep_inx % для работы со свипами
    global baseline_subtract_available % каналы с вычитанием базовой линии
    global plot_updating loading_text_handle % флаг обновления и handle текста
    global previousSliderValue % сохраняем предыдущее значение слайдера
    global event_label_click_callback stim_label_click_callback
global event_amplitudes
global event_channels
global lastPlotTimeResForEvents lastPlotDataResForEvents lastPlotChInxsForEvents
    
    show_events = true;
    if isfield(visualSettings, 'events_show')
        show_events = visualSettings.events_show;
    end

    fprintf('[%s] updatePlot: START, chosen_time_interval=[%.3f, %.3f], selectedCenter=%s\n', datestr(now, 'HH:MM:SS.FFF'), chosen_time_interval(1), chosen_time_interval(2), selectedCenter);
    
    % Устанавливаем флаг обновления
    plot_updating = true;
    
    % Показываем "LOADING..." на графике
    axes(multiax);
    if isempty(loading_text_handle) || ~isvalid(loading_text_handle)
        loading_text_handle = text(0.5, 0.5, 'LOADING...', ...
            'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'middle', ...
            'Units', 'normalized', ...
            'FontSize', 12, ...
            'FontWeight', 'normal', ...
            'Color', 'black', ...
            'BackgroundColor', [0.8 0.8 0.8]);
    else
        set(loading_text_handle, 'Visible', 'on');
    end
    drawnow; % Принудительное обновление экрана
    
    if isempty(ch_inxs)
        axes(multiax);
        cla(multiax);
        xlabel('Time, s');
        ylabel('Channels');
        text(0.5, 0.5, 'No channels selected', 'HorizontalAlignment', 'center', 'Units', 'normalized');
        plot_updating = false;
        if ~isempty(loading_text_handle) && isvalid(loading_text_handle)
            set(loading_text_handle, 'Visible', 'off');
        end
        if strcmp(selectedCenter, 'sweep') && sweep_info.is_sweep_data
            time_origin_early = sweep_info.sweep_times(sweep_inx);
        else
            time_origin_early = chosen_time_interval(1);
        end
        set(timeZeroEdit, 'String', num2str(time_origin_early * timeUnitFactor));
        if isgraphics(multiax)
            yl = get(multiax, 'YLim');
            set(yLimMinEdit, 'String', sprintf('%.6g', yl(1)));
            set(yLimMaxEdit, 'String', sprintf('%.6g', yl(2)));
        end
        return;
    end
    
    csd_active = csd_avaliable(ch_inxs);
    
    plot_time_interval = chosen_time_interval;
    plot_time_interval(1) = plot_time_interval(1) - time_back;
    
    % Относительное время по X:
    % - обычный режим: 0 в начале выбранного окна (chosen_time_interval(1))
    % - sweep режим: 0 в начале текущего свипа
    if strcmp(selectedCenter, 'sweep') && sweep_info.is_sweep_data
        time_origin = sweep_info.sweep_times(sweep_inx);
    else
        time_origin = chosen_time_interval(1);
    end

    row_start = find(time >= plot_time_interval(1), 1, 'first');
    row_end   = find(time < plot_time_interval(2), 1, 'last');
    cond = row_start:row_end;
    local_lfp = lfp_file.lfp(cond, :);
    local_lfp(:, mean_group_ch) = local_lfp(:, mean_group_ch) - mean(local_lfp(:, mean_group_ch), 2); % вычитание выбранных средних каналов
    data = local_lfp(:, ch_inxs).*m_coef;
    time_in = time(cond);
    
    if not(isempty(stims)) && visualSettings.stim_show
        cond3 = stims >= plot_time_interval(1) & stims < plot_time_interval(2); 
        stims_x = (stims(cond3) - time_origin) * timeUnitFactor;
        % Убираем артефакт из LFP
        win_r = round(art_rem_settings.artifact_window_ms * (Fs/1000));
        debugState('updatePlot', 'Stim artifact removal: Fs=%dHz, window=%.3f ms (~%d samples)', Fs, art_rem_settings.artifact_window_ms, win_r);
        data = removeStimArtifact(data, stims(cond3), time_in, win_r, art_rem_settings.interp_method);
    
    else
        cond3 = [];
        stims_x = [];
    end

    % Фильтруем если попросили
    if sum(filter_avaliable)>0
        ch_to_filter = filter_avaliable(ch_inxs);
        data(:, ch_to_filter) = applyFilter(data(:, ch_to_filter), filterSettings, newFs);        
    end
    
    % Проверка, совпадают ли частоты дискретизации
    if Fs <= newFs
        % Если newFs >= Fs, не делаем ресемплинг (апсемплинг не нужен и вызывает краевые эффекты)
        data_res = data;
        time_res = time_in;
        lfp_Fs = Fs;
    else
        % Иначе, проводим ресемплинг (только даунсемплинг)
        raw_Fs = Fs;
        lfp_Fs = round(newFs);

        % Используем resample1 для ресемплинга (без краевых эффектов)
        % Используем ту же формулу, что и в resample1 для точного совпадения размеров
        N = size(data, 1);
        numPoints = round((N - 1) * lfp_Fs / raw_Fs) + 1;
        data_res = zeros(numPoints, size(data, 2));

        for ch = 1:size(data, 2)
            data_res(:, ch) = resample1(data(:, ch), lfp_Fs, raw_Fs);
        end

        % Создаем временной вектор для ресемплированных данных
        numPoints = size(data_res, 1);
        time_res = linspace(time_in(1), time_in(end), numPoints);
    end

    numChannels = size(data_res, 2);
    
    % Вычитание медианы первых 10% сигнала для каналов с включенным baseline subtraction
    baseline_subtract_active = baseline_subtract_available(ch_inxs);
    baseline_medians = zeros(1, numChannels); % Сохраняем вычтенную базовую линию для каждого канала
    for ch = 1:numChannels
        if baseline_subtract_active(ch)
            numPoints = size(data_res, 1);
            baselineLength = max(1, round(numPoints * 0.1));
            baselineMedian = median(data_res(1:baselineLength, ch));
            baseline_medians(ch) = baselineMedian; % Сохраняем вычтенную медиану
            data_res(:, ch) = data_res(:, ch) - baselineMedian;
        end
    end

    % Кэшируем подготовленные данные для ручных событий без повторных вычислений.
    lastPlotTimeResForEvents = time_res;
    lastPlotDataResForEvents = data_res;
    lastPlotChInxsForEvents = ch_inxs;
    
    % Отображение времени на графике с учетом выбранной единицы времени
    time_in_transformed = (time_res - time_origin) * timeUnitFactor;

    % Очистка и обновление графика
    axes(multiax);
    cla(multiax); 
    
    hold on;
    %yyaxis left
    
    if visualSettings.auto_shift
        shiftCoeff = max(std(data_res)) * 2;
    end
    
    if visualSettings.show_CSD
        
        offsets = zeros(1, numChannels);
        % Plot each column with specified parameters
        for p = 1:numChannels
            % Determine the offset
            offsets(p) = -(p-1) * shiftCoeff;
        end        
        
        params.time_in_csd = time_in_transformed;
        params.data_in_csd = data_res;
        params.Fs = Fs;
        params.offsets = offsets;
        params.csd_smooth_coef = csd_smooth_coef;
        params.csd_active = csd_active;
        params.ch_inxs_original = ch_inxs;
        params.csd_split_by_channel_gaps = csd_split_by_channel_gaps;
        
        [csd_image, csd_t_range, csd_ch_range] = csdCalc(params);
        csdPlotting(csd_image, csd_t_range, csd_ch_range, csd_contrast_coef);
    end
    
    if visualSettings.auto_shift
        [offsets, shiftCoeff] = multiplot(time_in_transformed, data_res, ...
            'ChannelLabels', ch_labels_l, ...
            'linewidth', widths_in_l, ...
            'color', colors_in_l);
    else
        [offsets, shiftCoeff] = multiplot(time_in_transformed, data_res, ...
            'ChannelLabels', ch_labels_l, ...
            'shiftCoeff', shiftCoeff, ...
            'linewidth', widths_in_l, ...
            'color', colors_in_l);
    end

    [~, gapIdx] = splitConsecutiveChannels(ch_inxs);
    if ~isempty(gapIdx)
        x1 = time_in_transformed(1);
        x2 = time_in_transformed(end);
        for k = 1:numel(gapIdx)
            i = gapIdx(k);
            y = (offsets(i) + offsets(i+1)) / 2;
            plot([x1, x2], [y, y], '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1);
        end
    end
    
    y_pixel_size = 750;             % Размер по Y в пикселях
    y_tick_min_pixel_size = 25;     % Минимальный размер тиков по Y в пикселях

    [chRanges, chRangesOffsets, chRangeIndexes] = calculateChRanges(offsets, shiftCoeff, data_res, numChannels, m_coef, y_pixel_size, y_tick_min_pixel_size);
    
    % Корректируем значения chRanges для каналов с вычитанием базовой линии
    % Добавляем обратно вычтенную базовую линию, чтобы показать реальные значения
    for ch_inx = 1:numChannels
        if baseline_subtract_active(ch_inx)
            ch_mask = chRangeIndexes == ch_inx;
            % baseline_medians уже в масштабе данных, нужно добавить обратно с учетом m_coef
            chRanges(ch_mask) = chRanges(ch_mask) + baseline_medians(ch_inx) / m_coef(ch_inx);
        end
    end
    
    rangesTimeTicks = time_in_transformed(1)+zeros(size(chRangesOffsets)) + 0.02*(time_in_transformed(end) - time_in_transformed(1));    
    rangesTimeLabels = time_in_transformed(1)+zeros(size(chRangesOffsets)) + 0.005*(time_in_transformed(end) - time_in_transformed(1)); 
    ch_inx = 0;
    for color = np_flatten(colors_in_l)
        ch_inx = ch_inx+1;
        group_index = ch_inx == chRangeIndexes;
        text(rangesTimeTicks(group_index), chRangesOffsets(group_index), num2str(chRanges(group_index)', '%.2f'), 'color', color{:}, 'backgroundcolor', 'w')
        scatter(rangesTimeLabels(group_index), chRangesOffsets(group_index), [], 'Marker', '_', 'MarkerEdgeColor', color{:})
    end

    
    % Обновляем отображение осей
    if strcmp(selectedCenter, 'sweep') && sweep_info.is_sweep_data
        xlabel(sprintf('Time, %s (Sweep %d/%d)', selectedUnit, sweep_inx, sweep_info.sweep_count));
    else
        xlabel('Time, ' + string(selectedUnit) + '');
    end
    ylabel('Channels');

    % Устанавливаем новые тики по оси Y
    %yticks(allOffsets);  % Устанавливаем уникальные тики
    %yticklabels(allLabels); % Обновляем метки: каналы, максимумы и минимумы (без текста)

    % show spikes
    if visualSettings.show_spikes && not(isempty(spks))
        prg = std_coef;        
            
        c = 0;
        x_coord = [];
        y_coord = [];
        for ch_inx = ch_inxs
            c = c+1;
            offset = offsets(c) ;
            
            % Порог MUA по модулю амплитуды
            ii = abs(double(spks(ch_inx).ampl)) >= (lfpVar(ch_inx) * prg);
            spks_in(ch_inx).tStamp = spks(ch_inx).tStamp(ii);
            spks_in(ch_inx).ampl = spks(ch_inx).ampl(ii);
            
            spk = spks_in(ch_inx).tStamp/1000;% переводим из мс в сек формат
            ampl = abs(spks_in(ch_inx).ampl);
            
            x_coord = [x_coord, spk'];
            y_coord = [y_coord, zeros(1, numel(spk)) + offset];
        end
        cond4 = x_coord >= plot_time_interval(1) & x_coord < plot_time_interval(2);
        x_coord = x_coord(cond4);
        y_coord = y_coord(cond4);
        
        if not(isempty(stims)) && visualSettings.stim_show
            stims_in = stims(cond3);
            stim_inxs = ClosestIndex(stims_in, time_in); % Индекс стимулов
            win_r = round(art_rem_settings.artifact_window_ms * (Fs/1000));
            for i = 1:length(stim_inxs) 
                start_inx = stim_inxs(i) - win_r;
                start_inx = max(start_inx, 1);
                end_inx = stim_inxs(i) + win_r;
                end_inx = min(end_inx, numel(time_in));
                cond5 = x_coord >= time_in(start_inx) & x_coord < time_in(end_inx);
                x_coord = x_coord(~cond5);
                y_coord = y_coord(~cond5);
            end
            
        end
        
        scatter((x_coord - time_origin)*timeUnitFactor, y_coord, 'r|')
    end
    
    Xlims = (plot_time_interval - time_origin) * timeUnitFactor;
    
    
    xlim(Xlims)
%     
%     % Манипуляция с тиками времени (временно отключено)
%     % Даем MATLAB самому выставлять XTick/XTickLabel.
%     % Извлечение текущих тиков оси X из графика
%%     xTicks = get(multiax, 'XTick');%(0.5*timeUnitFactor)
%%     tickInterval = xTicks(3)-xTicks(2);
%     tickInterval = (Xlims(2)-Xlims(1))/10;
%     xTicks = Xlims(1):tickInterval:Xlims(2);
%     
%     xticks(xTicks)
%     
%     % Вычисление новых тиков и меток в зависимости от режима отображения
%     if strcmp(selectedCenter, 'sweep') && sweep_info.is_sweep_data
%         % Режим свипа: показываем время относительно начала текущего свипа
%         sweep_start_time = sweep_info.sweep_times(sweep_inx);
%         newTicks = xTicks - sweep_start_time*timeUnitFactor - time_back*timeUnitFactor;
%         newTicks(abs(newTicks)<1e-4) = 0;
%         newLabels = arrayfun(@num2str, newTicks, 'UniformOutput', false);
%         newLabels{1} = [sprintf('Sweep %d, ', sweep_inx), newLabels{1}, ' ', selectedUnit];
%         
%         % Устанавливаем заголовок оси для режима свипа
%         xlabel(sprintf('Time, %s (Sweep %d/%d)', selectedUnit, sweep_inx, sweep_info.sweep_count));
%     else
%         % Обычный режим: первый тик остается без изменений, остальные равны отступу от первого
%         newTicks = xTicks - xTicks(1) - time_back*timeUnitFactor;
%         newTicks(1) = xTicks(1); % Установка первого тика в исходное значение
%         newTicks(abs(newTicks)<1e-4) = 0;
%         newLabels = arrayfun(@num2str, newTicks, 'UniformOutput', false);
%         newLabels{1} = [newLabels{1}, ' ', selectedUnit];
%         
%         % Обычный заголовок оси
%         xlabel('Time, ' + string(selectedUnit) + '');
%     end
%     
%     % Применение новых меток тиков к текущему графику
%     set(multiax, 'XTickLabel', newLabels);
    
    manualYlimValid = viewerYlimManual && numel(viewerYlim) == 2 && all(isfinite(viewerYlim)) && viewerYlim(1) < viewerYlim(2);
    if manualYlimValid
        Ylims = [viewerYlim(1), viewerYlim(2)];
    elseif visualSettings.show_full_signal
        data_with_offsets = data_res + offsets;
        yMin = min(data_with_offsets(:));
        yMax = max(data_with_offsets(:));
        margin = (yMax - yMin) * 0.05;
        Ylims = [yMin - margin, yMax + margin];
    else
        Ylims = [min(chRangesOffsets)-shiftCoeff*0.2, max(chRangesOffsets)+shiftCoeff*0.2];
    end
    if viewerYlimManual && ~manualYlimValid
        viewerYlimManual = false;
    end
    ylim(Ylims)
    hold off;

    [~, name, ~] = fileparts(matFilePath);
%     title(name, 'interpreter', 'none')
    hylabel_ax(Xlims(1), multiax, name)
    centerModes = {'stimulus', 'event', 'sweep', 'time'};
    centerLabels = {'Stimuli', 'Event', 'Sweep', 'ContinuousTime'};
    centerStyleNames = {'stimulus_lines', 'events_lines', 'stimulus_lines', 'stimulus_lines'};
    labelHeightFractions = [0.05, 0.10]; % [stimulus, event]
    centerLabel = centerLabels{find(strcmp(centerModes, selectedCenter), 1)};
    centerStyleName = centerStyleNames{find(strcmp(centerModes, selectedCenter), 1)};
    yTop = multiax.YLim(2);
    centerLabelHeightFraction = labelHeightFractions(1 + strcmp(centerStyleName, 'events_lines'));
    yPad = diff(multiax.YLim) * centerLabelHeightFraction;
    drawLabelWithBg(multiax, 0, yTop - yPad, centerLabel, lines_and_styles.(centerStyleName), [], 'right')

    % Дальше рисуем события/стимулы (в т.ч. scatter). Должен быть hold on,
    % иначе новые вызовы могут перерисовать оси и стереть трейсы.
    hold(multiax, 'on');



    if show_events && ~isempty(events)
        cond2 = events >= plot_time_interval(1) & events < plot_time_interval(2);    
        evets_x = (events(cond2) - time_origin) * timeUnitFactor;
    else
        cond2 = [];
        evets_x = [];
    end     

%     events_color = [255, 15, 107]/255;
%     stims_color = [126, 237, 219]/255;

%     Lines(evets_x, [], events_color, ':');
%     Lines(stims_x, [], stims_color, ':');
    if show_events
        xlineMod(evets_x, lines_and_styles, 'events_lines')
    end
    xlineMod(stims_x, lines_and_styles, 'stimulus_lines')
    
    % events number
    text_y = Ylims(2) - diff(Ylims)*labelHeightFractions(2);
    text_y = zeros(numel(evets_x), 1) + text_y;
    text_x = evets_x + diff(Xlims)*0.01;
    if isempty(evets_x)
        text_text = '';
    else
        ev_ix = find(cond2);
        ev_ix = ev_ix(:); % ensure column shape for consistent cell-array sizing
        event_times_absolute = events(cond2) * timeUnitFactor;
        event_times_relative = (events(cond2) - time_origin) * timeUnitFactor;
        fmtOpts = {'%.3f', '%.0f'};
        timeFmt = fmtOpts{1 + strcmp(selectedUnit, 'ms')};
        idx = (1:numel(ev_ix)).'; % column vector to force column cell output
        baseText = arrayfun( ...
            @(i) sprintf(['#%d\n', timeFmt, ' ', selectedUnit, '\nrel ', timeFmt, ' ', selectedUnit], ...
                ev_ix(i), event_times_absolute(i), event_times_relative(i)), ...
            idx, 'UniformOutput', false);
        
        ev_amps = NaN(size(ev_ix));
        if ~isempty(event_amplitudes) && numel(event_amplitudes) >= max(ev_ix)
            ev_amps = event_amplitudes(ev_ix);
        end
        
        % Если у события есть канал, показываем подпись на уровне амплитуды
        % и рисуем красную точку на соответствующем смещении канала.
        event_y = NaN(size(ev_ix));
        if ~isempty(event_channels)
            ev_chs = event_channels(:); % ожидаем 1 канал на событие
            if numel(ev_chs) >= max(ev_ix)
                for iEv = 1:numel(ev_ix)
                    ev_ch = ev_chs(ev_ix(iEv));
                    if isnan(ev_ch) || isinf(ev_ch) || isnan(ev_amps(iEv))
                        continue;
                    end
                    ch_plot_idx = find(ch_inxs == ev_ch, 1, 'first');
                    if ~isempty(ch_plot_idx)
                        event_y(iEv) = offsets(ch_plot_idx) + ev_amps(iEv);
                    end
                end
            end
        end
        
        valid_event_mask = ~isnan(event_y);
        if any(valid_event_mask)
            text_y(valid_event_mask) = event_y(valid_event_mask);
        end
        
        ampText = arrayfun(@(a) sprintf('\nAmp %.3f', a), ev_amps, 'UniformOutput', false);
        ampText(isnan(ev_amps)) = {''};
        
        text_text = cellfun(@(b, a) [b a], baseText, ampText, 'UniformOutput', false);
    end
    if show_events
        if isempty(evets_x)
            % nothing to draw
        elseif ~isempty(event_label_click_callback)
            lineStyle = lines_and_styles.events_lines;
            for i = 1:numel(ev_ix)
                drawLabelWithBg(multiax, text_x(i), text_y(i), text_text{i}, lineStyle, @(~,~) event_label_click_callback(ev_ix(i)));
            end
        else
            textMod(text_x, text_y, text_text, lines_and_styles, 'events_lines');
        end
    end
%     text(text_x, text_y, text_text, 'color', events_color);

    % stims number
    text_y = Ylims(2) - diff(Ylims)*labelHeightFractions(1);
    text_y = zeros(numel(stims_x), 1) + text_y;
    text_x = stims_x + diff(Xlims)*0.01;
    stim_ix = find(cond3);
    if isempty(stims_x)
        text_text = '';
    else
        text_text = arrayfun(@(i) sprintf('%d', stim_ix(i)), 1:numel(stim_ix), 'UniformOutput', false);
    end
%     text(text_x, text_y, text_text, 'color', stims_color);    
    if isempty(stims_x)
        % nothing to draw
    elseif ~isempty(stim_label_click_callback)
        lineStyle = lines_and_styles.stimulus_lines;
        for i = 1:numel(stim_ix)
            drawLabelWithBg(multiax, text_x(i), text_y(i), text_text{i}, lineStyle, @(~,~) stim_label_click_callback(stim_ix(i)));
        end
    else
        textMod(text_x, text_y, text_text, lines_and_styles, 'stimulus_lines')
    end
    
    % Обновление положения слайдера с фильтром
    sliderMin = get(timeSlider, 'Min');
    sliderMax = get(timeSlider, 'Max');
    sliderValue = chosen_time_interval(1);
    % Ограничиваем значение диапазоном слайдера
    sliderValue = max(sliderMin, min(sliderMax, sliderValue));
    set(timeSlider, 'Value', sliderValue);
    previousSliderValue = sliderValue; % обновляем предыдущее значение

    set(timeZeroEdit, 'String', num2str(time_origin * timeUnitFactor));

    set(yLimMinEdit, 'String', sprintf('%.6g', Ylims(1)));
    set(yLimMaxEdit, 'String', sprintf('%.6g', Ylims(2)));

    % Сбрасываем флаг обновления в самом конце
    plot_updating = false;

    % очищаем память 
    clear local_lfp time_in_transformed data_res
    
end