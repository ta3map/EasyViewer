function updatePlot()
    global chosen_time_interval time_back cond time lfp mean_group_ch ch_inxs m_coef Fs newFs timeUnitFactor multiax
    global ch_labels_l shiftCoeff widths_in_l colors_in_l show_spikes spks std_coef selectedUnit matFilePath stims events timeSlider
    global data time_in offsets show_CSD filterSettings filter_avaliable csd_resample_coef csd_smooth_coef
    global csd_contrast_coef csd_avaliable
    
    csd_active = csd_avaliable(ch_inxs);
    
    plot_time_interval = chosen_time_interval;
    plot_time_interval(1) = plot_time_interval(1) - time_back;

    cond = time >= plot_time_interval(1) & time < plot_time_interval(2);
    local_lfp = lfp(cond, :);% все каналы данного участка времени
    local_lfp(:, mean_group_ch) = local_lfp(:, mean_group_ch) - mean(local_lfp(:, mean_group_ch), 2); % вычитание выбранных средних каналов
    data = local_lfp(:, ch_inxs).*m_coef;
    time_in = time(cond);
    
    % Фильтруем если попросили
    if sum(filter_avaliable)>0
        ch_to_filter = filter_avaliable(ch_inxs);
        data(:, ch_to_filter) = applyFilter(data(:, ch_to_filter), filterSettings, newFs);        
    end
    
    % resample based on time interval
    raw_frq = Fs;
    lfp_frq = round(newFs);
    numRawPoints = size(data, 1); % количество точек в исходных данных
    
    numPoints = ceil(numRawPoints * lfp_frq / raw_frq); % вычисляем количество точек после ресемплинга

    data_res = zeros(numPoints, size(data, 2)); % предварительное выделение памяти

    for ch = 1:size(data, 2)
        data_res(:, ch) = resample(double(data(:, ch)), lfp_frq , raw_frq);
    end        
    time_res = linspace(time_in(1),time_in(end),size(data_res, 1));        

    % Отображение времени на графике с учетом выбранной единицы времени
    time_in_transformed = time_res * timeUnitFactor;

    % Очистка и обновление графика
    axes(multiax);
    cla(multiax);        
    hold on;
    
    if show_CSD
        numChannels = size(data_res, 2);
        offsets = zeros(1, numChannels);
        % Plot each column with specified parameters
        for p = 1:numChannels
            % Determine the offset
            offsets(p) = -(p-1) * shiftCoeff;
        end        
%         csdPlotting(time_in_transformed, data_res)
        csdPlotting(time_in_transformed, data_res, Fs, offsets, csd_smooth_coef, csd_contrast_coef, csd_active)
    end
    
    offsets = multiplot(time_in_transformed, data_res, ...
        'ChannelLabels', ch_labels_l, ...
        'shiftCoeff',shiftCoeff, ...
        'linewidth', widths_in_l, ...
        'color', colors_in_l);
    xlabel('Time, s');
    ylabel('Channels');

    % show spikes
    if show_spikes
        c = 0;
        x_coord = [];
        y_coord = [];
        for ch_inx = ch_inxs
            c = c+1;
            offset = offsets(c) ;
            spk = spks(ch_inx).tStamp/1000;
            ampl = abs(spks(ch_inx).ampl);
            cond4 = spk >= plot_time_interval(1) & spk < plot_time_interval(2) ...
                & ampl > std_coef*std(ampl);
            x_coord = [x_coord, spk(cond4)'];
            y_coord = [y_coord, zeros(1, numel(spk(cond4))) + offset];
        end
        scatter(x_coord*timeUnitFactor, y_coord, 'r|')
    end

    Xlims = plot_time_interval*timeUnitFactor;
    xlim(Xlims);
    % Установка меток оси X в соответствии с выбранными единицами времени
    xlabel('Time (' + string(selectedUnit) + ')');

    Ylims = [offsets(end)-shiftCoeff, offsets(1)+shiftCoeff];
    ylim(Ylims)
    hold off;

    [path, name, ~] = fileparts(matFilePath);
%     title(name, 'interpreter', 'none')
    hylabel_ax(Xlims(1), multiax, name)


    if not(isempty(stims))
        cond3 = stims >= plot_time_interval(1) & stims < plot_time_interval(2); 
        stims_x = stims(cond3)*timeUnitFactor;
    else
        cond3 = [];
        stims_x = [];
    end

    cond2 = events >= plot_time_interval(1) & events < plot_time_interval(2);    
    evets_x = events(cond2)*timeUnitFactor;     

    events_color = [255, 15, 107]/255;
    stims_color = [126, 237, 219]/255;

    Lines(evets_x, [], events_color, ':');
    Lines(stims_x, [], stims_color, ':');

    % events number
    text_y = Ylims(2) - diff(Ylims)*0.05;
    text_y = zeros(numel(evets_x), 1) + text_y;
    text_x = evets_x + diff(Xlims)*0.01;
    text_text = num2str(find(cond2));
    text(text_x, text_y, text_text, 'color', events_color);

    % stims number
    text_y = Ylims(2) - diff(Ylims)*0.1;
    text_y = zeros(numel(stims_x), 1) + text_y;
    text_x = stims_x + diff(Xlims)*0.01;
    text_text = num2str(find(cond3));
    text(text_x, text_y, text_text, 'color', stims_color);    

    % Обновление положения слайдера
    set(timeSlider, 'Value', chosen_time_interval(1));

    % очищаем память 
    clear local_lfp time_in_transformed data_res
end