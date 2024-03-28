function csdPlotting(time_in_csd, data_in_csd, Fs, offsets, csd_smooth_coef, csd_contrast_coef, csd_active)
    
%     global csd_avaliable ch_inxs

    data_in_csd(isnan(data_in_csd)) = 0;
    data_in_csd(isinf(data_in_csd)) = 0;
        

    % дополнительный ресамплинг для CSD
%     raw_frq = Fs;
%     new_frq = round(Fs/csd_resample_coef); % частота после ресемплинга в 10 раз меньше
%     numRawPoints = size(data_in_csd, 1); % количество точек в исходных данных    
%     numPoints = ceil(numRawPoints * new_frq / raw_frq); % вычисляем количество точек после ресемплинга
%     data_res = zeros(numPoints, size(data_in_csd, 2)); % предварительное выделение памяти
%     for ch = 1:size(data_in_csd, 2)
%         data_res(:, ch) = resample(double(data_in_csd(:, ch)), new_frq , raw_frq);
%     end        
%     time_res = linspace(time_in_csd(1),time_in_csd(end),size(data_res, 1));       
    data_res = double(data_in_csd);
    
    % убираем информацию от ненужных каналов
%     size(csd_active)
%     size(data_res)
    data_res = cleanData(data_res, csd_active');
%     data_res(:, ~csd_active') = nan;
    
    time_res = time_in_csd;
    
    % определяем CSD для данных выбранных каналов
    [csd_image, csd_trange, csd_chrange] = CurSrcDnsAz(data_res, time_res, 1);
    csd_image = flip(csd_image');
    
    if csd_smooth_coef>0
%         csd_image = imgaussfilt(csd_image, [0.1, csd_smooth_coef]);
%           csd_image = medfilt2(csd_image, [1, csd_smooth_coef]);
        raw_frq = Fs;
        new_frq = round(Fs/csd_smooth_coef);
        numRawPoints = size(csd_image, 2); % количество точек в исходных данных  
        numPoints = ceil(numRawPoints * new_frq / raw_frq); % вычисляем количество точек после ресемплинга
        csd_image_res = zeros(numPoints, size(csd_image, 1)); % предварительное выделение памяти
        for ch = 1:size(csd_image, 1)
%             csd_image(ch, :) = medfilt1(csd_image(ch, :), csd_smooth_coef);
%             csd_image(ch, :) = smooth(csd_image(ch, :), csd_smooth_coef);
            csd_image_res(:, ch) = resample(csd_image(ch, :), new_frq , raw_frq)';
        end
        csd_image = csd_image_res';
        
        for ch = 1:size(csd_image, 1)
            csd_image(ch, :) = medfilt1(csd_image(ch, :), csd_smooth_coef);
            csd_image(ch, :) = smooth(csd_image(ch, :), csd_smooth_coef);
        end
    end
    
%     filteredOffsets = offsets(csd_active)
%     filteredOffsets = filteredOffsets(2:end-1) % Исключаем первый и последний канал
    
%     minYData = min(filteredOffsets);
%     maxYData = max(filteredOffsets);
%     imagesc(csd_image, 'XData', csd_trange, 'YData', [minYData, maxYData]);
    imagesc(csd_image, 'XData', csd_trange, 'YData', flip([offsets(2), offsets(end-1)]))
    colormap jet
    branch_plus = prctile(csd_image, csd_contrast_coef, 'all');
    caxis([-branch_plus, branch_plus]);
end