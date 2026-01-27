function result = autoHoldPotential(filePath, fileId, params)
    global zav_calling lfp
    
    metadata = zav_calling(filePath);
    if isempty(metadata)
        result = [];
        return
    end

    channelIdx = round(params.Channel);

    holdPotentialValue = median(lfp(:, channelIdx));
    
    q25 = prctile(lfp(:, channelIdx), 25);
    q75 = prctile(lfp(:, channelIdx), 75);
    holdPotentialIqr = q75 - q25;
    
    result = struct( ...
        'module_name', 'autoHoldPotential', ...
        'module_display_name', 'Auto Hold Potential', ...
        'module_description', 'Определение hold potential на втором канале', ...
        'parameters', params, ...
        'hold_potential', holdPotentialValue, ...
        'hold_potential_iqr', holdPotentialIqr, ...
        'report_path', '', ...
        'tableResultInsert', {{'hold_potential', 'hold_potential_iqr'}});
end
