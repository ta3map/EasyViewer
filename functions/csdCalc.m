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
    
    data = double(data_in_csd);
    time_res = time_in_csd;
    numCh = size(data, 2);
    
    splitByGaps = isfield(params, 'csd_split_by_channel_gaps') && logical(params.csd_split_by_channel_gaps);
    
    if splitByGaps
        if isempty(ch_inxs_original)
            ch_inxs_original = 1:numCh;
        end
        ch_inxs_original = ch_inxs_original(:);
        activeMask = logical(csd_active(:));
        activeMask = activeMask(1:numCh);
        activePos = find(activeMask);
        segmentStartPos = zeros(0, 1);
        segmentEndPos = zeros(0, 1);
        if ~isempty(activePos)
            activeOriginal = ch_inxs_original(activePos);
            [segmentsActive, ~] = splitConsecutiveChannels(activeOriginal);
            segmentStartPos = activePos(segmentsActive(:, 1));
            segmentEndPos = activePos(segmentsActive(:, 2));
        end
    else
        data = cleanData(data, csd_active');
        segmentStartPos = 1;
        segmentEndPos = numCh;
    end
    
    csd_image = zeros(1, numel(time_res));
    csd_t_range = time_res(:);
    csd_ch_range = 0;
    
    if numCh >= 4
        geom = csdCachedGeometry(size(data, 1), numCh, offsets, time_res, splitByGaps);
        csd_t_range = geom.csd_t_range;
        csd_ch_range = geom.csd_ch_range;
        numY = geom.numY;
        numT = geom.numT;
        csd_image = zeros(numY, numT);
        
        for s = 1:numel(segmentStartPos)
            segStart = segmentStartPos(s);
            segEnd = segmentEndPos(s);
            if segEnd - segStart + 1 < 4
                continue;
            end
            
            [csd_seg, ~, ~] = CurSrcDnsAz(data(:, segStart:segEnd), time_res, 1);
            csd_seg = flip(csd_seg');
            csd_seg(~isfinite(csd_seg)) = 0;
            segMedian = median(csd_seg(:));
            segIqr = iqr(csd_seg(:));
            segScale = segIqr * (isfinite(segIqr) & (segIqr > 0)) + ~(isfinite(segIqr) & (segIqr > 0));
            csd_seg = (csd_seg - segMedian) / segScale;
            
            ySeg = linspace(offsets(segEnd - 1), offsets(segStart + 1), size(csd_seg, 1)).';
            yMask = csd_ch_range >= ySeg(1) & csd_ch_range <= ySeg(end);
            csd_image(yMask, :) = interp1(ySeg, csd_seg, csd_ch_range(yMask), 'linear', 0);
        end
    end
    
    if csd_smooth_coef>0
        
        raw_frq = Fs;
        new_frq = round(Fs/csd_smooth_coef);
        csd_image = resample1(csd_image', new_frq, raw_frq)';
        
        span = csd_smooth_coef;
        if mod(span, 2) == 0
            span = span + 1;
        end
        csd_image = medfilt1(csd_image.', span).';
        csd_image = movmean(csd_image.', csd_smooth_coef, 1, 'Endpoints', 'shrink').';
    end
    
end

function geom = csdCachedGeometry(nRows, numCh, offsets, time_res, splitByGaps)
persistent cacheKey cacheGeom

key = struct('nRows', nRows, 'numCh', numCh, 'split', splitByGaps, ...
    'offsets', offsets(:)', 'nTime', numel(time_res));
if ~isempty(cacheKey) && isequal(cacheKey, key)
    geom = cacheGeom;
    return;
end

[csd_ref, csd_t_range, ~] = CurSrcDnsAz(zeros(nRows, numCh), time_res, 1);
csd_ref = flip(csd_ref');
geom = struct();
geom.csd_t_range = csd_t_range;
geom.numY = size(csd_ref, 1);
geom.numT = size(csd_ref, 2);
geom.csd_ch_range = linspace(offsets(end - 1), offsets(2), geom.numY).';
cacheKey = key;
cacheGeom = geom;

end
