function [csd_image, csd_t_range, csd_ch_range] = csdCalc(params)

    time_in_csd = params.time_in_csd;
    data_in_csd = params.data_in_csd;
    Fs = params.Fs;
    offsets = params.offsets;
    csd_smooth_coef = params.csd_smooth_coef;
    csd_active = params.csd_active;

    data_in_csd(isnan(data_in_csd)) = 0;
    data_in_csd(isinf(data_in_csd)) = 0;
         
    % убираем информацию от ненужных каналов
    
    data_res = cleanData(double(data_in_csd), csd_active');
    
    time_res = time_in_csd;
    
    % определяем CSD для данных выбранных каналов
    [csd_image, csd_t_range, ~] = CurSrcDnsAz(data_res, time_res, 1);
    csd_image = flip(csd_image');
    
    if csd_smooth_coef>0
        
        raw_frq = Fs;
        new_frq = round(Fs/csd_smooth_coef);
        numRawPoints = size(csd_image, 2); % количество точек в исходных данных  
        numPoints = ceil(numRawPoints * new_frq / raw_frq); % вычисляем количество точек после ресемплинга
        csd_image_res = zeros(numPoints, size(csd_image, 1)); % предварительное выделение памяти
        
        for ch = 1:size(csd_image, 1)
            csd_image_res(:, ch) = resample(csd_image(ch, :), new_frq , raw_frq)';            
        end
        
%         csd_t_range = resample(csd_t_range, new_frq , raw_frq);
        csd_image = csd_image_res';
        
        for ch = 1:size(csd_image, 1)
            csd_image(ch, :) = medfilt1(csd_image(ch, :), csd_smooth_coef);
            csd_image(ch, :) = smooth(csd_image(ch, :), csd_smooth_coef);
        end
    end
    csd_ch_range = flip([offsets(2), offsets(end-1)]);
    
end