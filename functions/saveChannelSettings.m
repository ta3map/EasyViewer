function saveChannelSettings(varargin)
    % SAVECHANNELSETTINGS Сохраняет настройки каналов в файл
    % Использует глобальные переменные для получения данных
    
    % Глобальные переменные
    global matFilePath newFs shiftCoeff time_forward time_back
    global channelNames channelEnabled scalingCoefficients colorsIn lineCoefficients
    global mean_group_ch csd_avaliable filter_avaliable baseline_subtract_available filterSettings
    global stims EV_version csd_smooth_coef csd_contrast_coef channelSettings
    
    if exist(matFilePath, 'file') ~= 2
        return;
    end

    [path, name, ~] = fileparts(matFilePath);
    channelSettingsFilePath = fullfile(path, [name '_channelSettings.stn']);

    varsToSave = varargin;
    if isempty(varsToSave)
        varsToSave = {
            'channelSettings'
            'newFs'
            'shiftCoeff'
            'time_forward'
            'time_back'
            'filterSettings'
            'csd_smooth_coef'
            'csd_contrast_coef'
            'channelNames'
            'channelEnabled'
            'scalingCoefficients'
            'colorsIn'
            'lineCoefficients'
            'mean_group_ch'
            'csd_avaliable'
            'filter_avaliable'
            'baseline_subtract_available'
            'stims'
            'EV_version'
        };
    end

    save(channelSettingsFilePath, varsToSave{:}, '-append');
end
