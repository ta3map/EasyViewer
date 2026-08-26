function saveChannelSettings(varargin)
    % SAVECHANNELSETTINGS Сохраняет настройки каналов в файл
    % Использует глобальные переменные для получения данных
    
    % Глобальные переменные
    global matFilePath newFs shiftCoeff time_forward time_back
    global channelNames channelEnabled scalingCoefficients colorsIn lineCoefficients
    global mean_group_ch csd_avaliable filter_avaliable baseline_subtract_available filterSettings
    global stims EV_version csd_smooth_coef csd_contrast_coef csd_contrast_is_display
    global csd_split_by_channel_gaps
    global std_coef binsize
    global visualSettings
    global axes_background_color
    global lastEventsFilePath
    global channelLayoutFilePath
    global channelLayoutNameGrid
    global event_inx
    global meanControlsState
    global autodetection_settings
    global viewerYlim viewerYlimManual
    
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
            'csd_contrast_is_display'
            'csd_split_by_channel_gaps'
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
            'channelLayoutFilePath'
            'channelLayoutNameGrid'
            'event_inx'
            'meanControlsState'
            'autodetection_settings'
            'viewerYlim'
            'viewerYlimManual'
            'EV_version'
        };
    end

    % Не затирать сохранённую автодетекцию пустым global
    saveAuto = true;
    for i = 1:numel(varsToSave)
        if strcmp(varsToSave{i}, 'autodetection_settings') && ~isstruct(autodetection_settings)
            saveAuto = false;
            break;
        end
    end
    if ~saveAuto
        varsToSave = varsToSave(~strcmp(varsToSave, 'autodetection_settings'));
    end
    if isempty(varsToSave)
        return;
    end

    if exist(channelSettingsFilePath, 'file') == 2
        save(channelSettingsFilePath, varsToSave{:}, '-append');
    else
        save(channelSettingsFilePath, varsToSave{:});
    end
end
