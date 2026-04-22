function [csd_image, csd_t_range, csd_ch_range] = csdCalc(params)

    time_in_csd = params.time_in_csd;
    data_in_csd = params.data_in_csd;
    Fs = params.Fs;
    offsets = params.offsets;
    csd_smooth_coef = params.csd_smooth_coef;
    csd_active = params.csd_active;
    
    ch_inxs_original = [];
    if isfield(params, 'ch_inxs_original')
        ch_inxs_original = params.ch_inxs_original;
    end

    data_in_csd(isnan(data_in_csd)) = 0;
    data_in_csd(isinf(data_in_csd)) = 0;
         
    time_res = time_in_csd;
    
    [csd_image, csd_t_range, csd_ch_range] = csdCalcSplitByGaps(double(data_in_csd), time_res, offsets, csd_active, ch_inxs_original);
    
    if csd_smooth_coef>0
        
        raw_frq = Fs;
        new_frq = round(Fs/csd_smooth_coef);
        numChannels = size(csd_image, 1);
        firstResampled = resample1(csd_image(1, :)', new_frq, raw_frq);
        numPoints = numel(firstResampled);
        csd_image_res = zeros(numPoints, numChannels);
        csd_image_res(:, 1) = firstResampled;
        
        for ch = 2:numChannels
            csd_image_res(:, ch) = resample1(csd_image(ch, :)', new_frq, raw_frq);            
        end
        
%         csd_t_range = resample(csd_t_range, new_frq , raw_frq);
        csd_image = csd_image_res';
        
        for ch = 1:size(csd_image, 1)
            csd_image(ch, :) = medfilt1(csd_image(ch, :), csd_smooth_coef);
            csd_image(ch, :) = smooth1(csd_image(ch, :), csd_smooth_coef);
        end
    end
    
end

function [csd_image_full, csd_t_range, csd_ch_range_full] = csdCalcSplitByGaps(data_in_csd, time_res, offsets, csd_active, ch_inxs_original)
    numCh = size(data_in_csd, 2);
    
    if isempty(ch_inxs_original)
        ch_inxs_original = 1:numCh;
    end
    ch_inxs_original = ch_inxs_original(:);
    
    activeMask = logical(csd_active(:));
    activeMask = activeMask(1:numCh);
    
    activePos = find(activeMask);
    activeOriginal = ch_inxs_original(activePos);
    
    segmentStartPos = [];
    segmentEndPos = [];
    if ~isempty(activePos)
        [segmentsActive, ~] = splitConsecutiveChannels(activeOriginal);
        if ~isempty(segmentsActive)
            segmentStartPos = activePos(segmentsActive(:, 1));
            segmentEndPos = activePos(segmentsActive(:, 2));
        end
    end
    
    csd_image_full = [];
    csd_t_range = [];
    csd_ch_range_full = [];
    
    yRows = [];
    if numCh >= 4
        yRows = (2:(1/3):(numCh-1)).';
    end
    numY = numel(yRows);
    
    for s = 1:numel(segmentStartPos)
        segStart = segmentStartPos(s);
        segEnd = segmentEndPos(s);
        segLen = segEnd - segStart + 1;
        if segLen < 4
            continue;
        end
        
        segData = data_in_csd(:, segStart:segEnd);
        [csd_seg, t_seg, ch_seg] = CurSrcDnsAz(segData, time_res, 1);
        csd_seg = flip(csd_seg');
        csd_seg(~isfinite(csd_seg)) = 0;
        segMedian = median(csd_seg(:));
        segIqr = iqr(csd_seg(:));
        segScale = segIqr * (isfinite(segIqr) & (segIqr > 0)) + ~(isfinite(segIqr) & (segIqr > 0));
        csd_seg = (csd_seg - segMedian) / segScale;
        
        mappedCh = (segStart - 1) + flipud(ch_seg(:));
        idxUnflipped = round((mappedCh - 2) * 3) + 1;
        idx = numY - idxUnflipped + 1;
        inRange = idx >= 1 & idx <= numY;
        idx = idx(inRange);
        csd_seg = csd_seg(inRange, :);
        
        if isempty(csd_image_full)
            csd_image_full = zeros(numY, size(csd_seg, 2));
            csd_t_range = t_seg;
            csd_ch_range_full = linspace(offsets(end-1), offsets(2), numY);
        end
        
        csd_image_full(idx, :) = csd_seg;
    end
    
    if isempty(csd_image_full)
        csd_image_full = zeros(max(numY, 1), numel(time_res));
        csd_t_range = time_res(:);
        if isempty(yRows)
            csd_ch_range_full = 0;
        else
            csd_ch_range_full = linspace(offsets(end-1), offsets(2), max(numY, 1));
        end
    end
end