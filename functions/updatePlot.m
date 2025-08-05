function updatePlot()
    % disp('Plot is updated')
    global chosen_time_interval time_back cond time lfp mean_group_ch ch_inxs m_coef Fs newFs timeUnitFactor multiax
    global ch_labels_l shiftCoeff widths_in_l colors_in_l show_spikes spks std_coef selectedUnit matFilePath stims events timeSlider
    global data time_in show_CSD filterSettings filter_avaliable csd_smooth_coef
    global csd_contrast_coef csd_avaliable show_power power_window lfpVar
    global csd_image csd_t_range csd_ch_range offsets
    global art_rem_window_ms stimShowFlag lines_and_styles
    global selectedCenter sweep_info sweep_inx % для работы со свипами
    
    csd_active = csd_avaliable(ch_inxs);
    
    plot_time_interval = chosen_time_interval;
    plot_time_interval(1) = plot_time_interval(1) - time_back;

    cond = time >= plot_time_interval(1) & time < plot_time_interval(2);
    local_lfp = lfp(cond, :);% все каналы данного участка времени
    local_lfp(:, mean_group_ch) = local_lfp(:, mean_group_ch) - mean(local_lfp(:, mean_group_ch), 2); % вычитание выбранных средних каналов
    data = local_lfp(:, ch_inxs).*m_coef;
    time_in = time(cond);
    
    if not(isempty(stims)) && stimShowFlag
        cond3 = stims >= plot_time_interval(1) & stims < plot_time_interval(2); 
        stims_x = stims(cond3)*timeUnitFactor;
        % Убираем артефакт из LFP
        data = removeStimArtifact(data, stims(cond3), time_in, art_rem_window_ms);
    
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
    if Fs == newFs
        % Если частоты Fs совпадают, просто копируем данные без ресемплинга
        data_res = data;
        time_res = time_in;
        lfp_Fs = newFs;
    else
        % Иначе, проводим ресемплинг
        raw_Fs = Fs;
        lfp_Fs = round(newFs);
        numRawPoints = size(data, 1); % количество точек в исходных данных

        numPoints = ceil(numRawPoints * lfp_Fs / raw_Fs); % вычисляем количество точек после ресемплинга

        data_res = zeros(numPoints, size(data, 2)); % предварительное выделение памяти

        for ch = 1:size(data, 2)
            data_res(:, ch) = resample(double(data(:, ch)), lfp_Fs , raw_Fs);
        end

        time_res = linspace(time_in(1),time_in(end),size(data_res, 1));
    end

    numChannels = size(data_res, 2);
    
    % Отображение времени на графике с учетом выбранной единицы времени
    time_in_transformed = time_res * timeUnitFactor;

    % Очистка и обновление графика
    axes(multiax);
    cla(multiax); 
    
    hold on;
    %yyaxis left
    
    if show_CSD
        
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
        
        [csd_image, csd_t_range, csd_ch_range] = csdCalc(params);
        csdPlotting(csd_image, csd_t_range, csd_ch_range, csd_contrast_coef);
    end
    
    if show_power
        windowSize = round(power_window * lfp_Fs); % Размер окна для RMS, примерно 25 мс
        for ch = 1:size(data_res, 2)
            % Вычисление RMS мощности сигнала
            data_res(:, ch) = sqrt(movmean(data_res(:, ch).^2, windowSize));
        end
    end
    
    % Сначала вызываем multiplot и получаем необходимые данные
    offsets = multiplot(time_in_transformed, data_res, ...
        'ChannelLabels', ch_labels_l, ...
        'shiftCoeff',shiftCoeff, ...
        'linewidth', widths_in_l, ...
        'color', colors_in_l);
    
    y_pixel_size = 750;             % Размер по Y в пикселях
    y_tick_min_pixel_size = 25;     % Минимальный размер тиков по Y в пикселях

    [chRanges, chRangesOffsets, chRangeIndexes] = calculateChRanges(offsets, shiftCoeff, data_res, numChannels, m_coef, y_pixel_size, y_tick_min_pixel_size);
    rangesTimeTicks = time_in_transformed(1)+zeros(size(chRangesOffsets)) + 0.02*(time_in_transformed(end) - time_in_transformed(1));    
    rangesTimeLabels = time_in_transformed(1)+zeros(size(chRangesOffsets)) + 0.005*(time_in_transformed(end) - time_in_transformed(1)); 
    ch_inx = 0;
    for color = np_flatten(colors_in_l)
        ch_inx = ch_inx+1;
        group_index = ch_inx == chRangeIndexes;
        text(rangesTimeTicks(group_index), chRangesOffsets(group_index), num2str(chRanges(group_index)', '%.2f'), 'color', color{:}, 'backgroundcolor', 'w')
        scatter(rangesTimeLabels(group_index), chRangesOffsets(group_index), '_', color{:})
    end

    
    % Обновляем отображение осей
    xlabel('Time, s');
    ylabel('Channels');

    % Устанавливаем новые тики по оси Y
    %yticks(allOffsets);  % Устанавливаем уникальные тики
    %yticklabels(allLabels); % Обновляем метки: каналы, максимумы и минимумы (без текста)

    % show spikes
    if show_spikes && not(isempty(spks))
        prg = std_coef;        
            
        c = 0;
        x_coord = [];
        y_coord = [];
        for ch_inx = ch_inxs
            c = c+1;
            offset = offsets(c) ;
            
            % Порог ZAV метод
            ii = double(spks(ch_inx).ampl) <= (-lfpVar(ch_inx) * prg);
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
        
        if not(isempty(stims)) && stimShowFlag
            stims_in = stims(cond3);
            stim_inxs = ClosestIndex(stims_in, time_in); % Индекс стимулов
            win_r = art_rem_window_ms;
            for i = 1:length(stim_inxs) 
                start_inx = stim_inxs(i) - win_r;
                start_inx(start_inx<1) = 1;
                end_inx = stim_inxs(i) + win_r;
                cond5 = x_coord >= time_in(start_inx) & x_coord < time_in(end_inx);
                x_coord = x_coord(~cond5);
                y_coord = y_coord(~cond5);
            end
            
        end
        
        scatter(x_coord*timeUnitFactor, y_coord, 'r|')
    end
    
    Xlims = plot_time_interval*timeUnitFactor;
    
    
    % Манипуляция с тиками времени
    % Извлечение текущих тиков оси X из графика
%     xTicks = get(multiax, 'XTick');%(0.5*timeUnitFactor)
%     tickInterval = xTicks(3)-xTicks(2);
    tickInterval = (Xlims(2)-Xlims(1))/10;
    xTicks = Xlims(1):tickInterval:Xlims(2);
    
    xticks(xTicks)
    xlim(Xlims)
    
    % Вычисление новых тиков и меток в зависимости от режима отображения
    if strcmp(selectedCenter, 'sweep') && sweep_info.is_sweep_data
        % Режим свипа: показываем время относительно начала текущего свипа
        sweep_start_time = sweep_info.sweep_times(sweep_inx);
        newTicks = xTicks - sweep_start_time*timeUnitFactor - time_back*timeUnitFactor;
        newTicks(abs(newTicks)<1e-4) = 0;
        newLabels = arrayfun(@num2str, newTicks, 'UniformOutput', false);
        newLabels{1} = [sprintf('Sweep %d, ', sweep_inx), newLabels{1}, ' ', selectedUnit];
        
        % Устанавливаем заголовок оси для режима свипа
        xlabel(sprintf('Time, %s (Sweep %d/%d)', selectedUnit, sweep_inx, sweep_info.sweep_count));
    else
        % Обычный режим: первый тик остается без изменений, остальные равны отступу от первого
        newTicks = xTicks - xTicks(1) - time_back*timeUnitFactor;
        newTicks(1) = xTicks(1); % Установка первого тика в исходное значение
        newTicks(abs(newTicks)<1e-4) = 0;
        newLabels = arrayfun(@num2str, newTicks, 'UniformOutput', false);
        newLabels{1} = [newLabels{1}, ' ', selectedUnit];
        
        % Обычный заголовок оси
        xlabel('Time, ' + string(selectedUnit) + '');
    end
    
    % Применение новых меток тиков к текущему графику
    set(multiax, 'XTickLabel', newLabels);
    
    Ylims = [min(chRangesOffsets)-shiftCoeff*0.2, max(chRangesOffsets)+shiftCoeff*0.2];
    ylim(Ylims)
    hold off;

    [~, name, ~] = fileparts(matFilePath);
%     title(name, 'interpreter', 'none')
    hylabel_ax(Xlims(1), multiax, name)



    cond2 = events >= plot_time_interval(1) & events < plot_time_interval(2);    
    evets_x = events(cond2)*timeUnitFactor;     

%     events_color = [255, 15, 107]/255;
%     stims_color = [126, 237, 219]/255;

%     Lines(evets_x, [], events_color, ':');
%     Lines(stims_x, [], stims_color, ':');
    xlineMod(evets_x, lines_and_styles, 'events_lines')
    xlineMod(stims_x, lines_and_styles, 'stimulus_lines')
    
    % events number
    text_y = Ylims(2) - diff(Ylims)*0.05;
    text_y = zeros(numel(evets_x), 1) + text_y;
    text_x = evets_x + diff(Xlims)*0.01;
    text_text = num2str(find(cond2));
    textMod(text_x, text_y, text_text, lines_and_styles, 'events_lines')
%     text(text_x, text_y, text_text, 'color', events_color);

    % stims number
    text_y = Ylims(2) - diff(Ylims)*0.1;
    text_y = zeros(numel(stims_x), 1) + text_y;
    text_x = stims_x + diff(Xlims)*0.01;
    text_text = num2str(find(cond3));
%     text(text_x, text_y, text_text, 'color', stims_color);    
    textMod(text_x, text_y, text_text, lines_and_styles, 'stimulus_lines')
    
    % Обновление положения слайдера
    set(timeSlider, 'Value', chosen_time_interval(1));

    % очищаем память 
    clear local_lfp time_in_transformed data_res
    
end