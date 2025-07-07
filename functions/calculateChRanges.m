function [chRanges, chRangesOffsets, chRangeIndexes] = calculateChRanges(offsets, shiftCoeff, data_res, numChannels, m_coef, y_pixel_size, y_tick_min_pixel_size)
    
    data_res(isinf(data_res)) = NaN;

    chRanges = [];
    chRangesOffsets = [];
    chRangeIndexes = [];
    ch_inx = 0;

    for offset = offsets
        ch_inx = ch_inx + 1;
     
        minChValue = -shiftCoeff / 2.5;
        maxChValue = shiftCoeff / 2.5;
        valueStep = shiftCoeff / 10;
        
        if ch_inx == 1
            maxChValue = nanmax(max(data_res(:, ch_inx)), maxChValue);
        end
        
        if ch_inx == numChannels
            minChValue = nanmin(min(data_res(:, ch_inx)), minChValue);
        end
       
        thisRange = (minChValue:valueStep:maxChValue);
        
        chRanges =  [chRanges, thisRange/m_coef(ch_inx)];
        
        chRangesOffsets = [chRangesOffsets, thisRange + offset];
        
        chRangeIndexes = [chRangeIndexes, zeros(size(thisRange))+ch_inx];
    end
    
    chRanges = np_flatten(chRanges);
    chRangesOffsets = np_flatten(chRangesOffsets);
    
    y_offset_range = max(chRangesOffsets) - min(chRangesOffsets);
    y_tick_min_offset_size = y_offset_range * (y_tick_min_pixel_size / y_pixel_size);
    
    good_diff = filterOffsetsFromStart(chRangesOffsets, y_tick_min_offset_size);   
    good_diff(argmax(chRangesOffsets)) = true;
    good_diff(argmin(chRangesOffsets)) = true;
    
    chRangesOffsets = chRangesOffsets(good_diff);
    chRanges = chRanges(good_diff);
    chRangeIndexes = chRangeIndexes(good_diff);
end
