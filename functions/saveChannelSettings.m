function saveChannelSettings(varargin)
    % SAVECHANNELSETTINGS Сохраняет настройки каналов в файл
    % Использует глобальные переменные для получения данных
    
    % Глобальные переменные
    global matFilePath newFs shiftCoeff time_forward time_back
    global channelNames channelEnabled scalingCoefficients colorsIn lineCoefficients
    global mean_group_ch csd_avaliable filter_avaliable baseline_subtract_available filterSettings
    global stims EV_version csd_smooth_coef csd_contrast_coef
    global std_coef binsize
    global visualSettings
    global axes_background_color
    global lastEventsFilePath
    global event_inx
    global meanControlsState
    global autodetection_settings
    
    if exist(matFilePath, 'file') ~= 2
        return;
    end

    [path, name, ~] = fileparts(matFilePath);
    channelSettingsFilePath = fullfile(path, [name '_channelSettings.stn']);

    varsToSave = varargin;
    if isempty(varsToSave)
        varsToSave = {
            'newFs'
            'shiftCoeff'
            'time_forward'
            'time_back'
            'filterSettings'
            'csd_smooth_coef'
            'csd_contrast_coef'
            'std_coef'
            'binsize'
            'visualSettings'
            'channelNames'
            'channelEnabled'
            'scalingCoefficients'
            'colorsIn'
            'lineCoefficients'
            'mean_group_ch'
            'csd_avaliable'
            'filter_avaliable'
            'baseline_subtract_available'
            'axes_background_color'
            'stims'
            'lastEventsFilePath'
            'event_inx'
            'meanControlsState'
            'autodetection_settings'
            'EV_version'
        };
    end

    if exist(channelSettingsFilePath, 'file') == 2
        save(channelSettingsFilePath, varsToSave{:}, '-append');
    else
        save(channelSettingsFilePath, varsToSave{:});
    end
end
