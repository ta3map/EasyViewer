function csdPlotting(time_in_csd, data_in_csd)

    method = 1;
    
    data_in_csd(isnan(data_in_csd)) = 0;
    data_in_csd(isinf(data_in_csd)) = 0;
    
    global data time_in ch_inxs lfp mean_group_ch time chosen_time_interval time_back
    global csd_avaliable offsets shiftCoeff newFs

    % переводим из логического в цифровой индекс
    csd_inxs = find(csd_avaliable(ch_inxs)); 

    % дополнительный ресамплинг для CSD
    raw_frq = newFs;
    new_frq = round(newFs/10); % частота после ресемплинга в 10 раз меньше
    numRawPoints = size(data_in_csd, 1); % количество точек в исходных данных    
    numPoints = ceil(numRawPoints * new_frq / raw_frq); % вычисляем количество точек после ресемплинга
    data_res = zeros(numPoints, size(data, 2)); % предварительное выделение памяти
    for ch = 1:size(data_in_csd, 2)
        data_res(:, ch) = resample(double(data_in_csd(:, ch)), new_frq , raw_frq);
    end        
    time_res = linspace(time_in_csd(1),time_in_csd(end),size(data_res, 1));       
    
    % определяем CSD для данных выбранных каналов
    [csd_image, csd_trange, csd_chrange] = CurSrcDnsAz(data_res(:, csd_inxs), time_res, 1);
    csd_image = flip(csd_image');
    
    if method == 1
        imagesc(csd_image, 'XData', csd_trange, 'YData', flip([offsets(2), offsets(end-1)]))
    end
    
    if method == 2
        % вытаскиваем куски соответствующих каналов
        csd_chrangef = floor(csd_chrange);
        csd_chrangef(end) = csd_chrangef(end-1);
        csd_chrangef = flip(csd_chrangef);
        % csd_chrangef = unique(csd_chrangef)';

        % csd_chrangef = 2:(numel(csd_inxs)-1);
        original_vector = 2:(numel(csd_inxs)-1);
        extended_vector = repmat(original_vector', 8, 1);

        clear csd_data
        cch_i = 0;
        for cch = unique(csd_chrangef)'
            cch_i = cch_i + 1;
            csd_data(cch_i).part = csd_image(csd_chrangef == cch, :);
            csd_data(cch_i).ch_inxs_inx = csd_inxs(cch);
            csd_data(cch_i).real_ch_inxs = ch_inxs(csd_inxs(cch));
            csd_data(cch_i).offset = offsets(csd_inxs(cch));
            csd_data(cch_i).cch = cch;
        end

        cch_i = 0;
        for cch = [csd_data.cch]
            cch_i = cch_i + 1;
            part_size = size(csd_data(cch_i).part,1);
            csd_data(cch_i).YData = linspace(csd_data(cch_i).offset, csd_data(cch_i).offset - shiftCoeff, part_size);
        end

        % fCSD = figure(4);
        % clf, hold on
        % Это симуляция части из updatePlot


        % csd_offsets = offsets(csd_inxs);
        cch_i = 0;
        for cch = [csd_data.cch]
            cch_i = cch_i + 1;

            YData = csd_data(cch_i).YData;

            csd_ch_part = csd_data(cch_i).part;
            csd_ch_part = csd_ch_part - median(csd_ch_part);
            imagesc(csd_ch_part, 'YData', YData, 'XData', csd_trange)

        end
    end
    % multiplot(time_in_transformed, data_res, 'shiftCoeff', shiftCoeff)
    colormap jet
    branch_plus = prctile(csd_image, 99.99, 'all');
    caxis([-branch_plus, branch_plus]);
end
%%