function applied = applyChannelSettingsFromFile(settingsPath, numChannels)
    global channelNames channelEnabled scalingCoefficients colorsIn lineCoefficients
    global mean_group_ch csd_avaliable filter_avaliable baseline_subtract_available filterSettings
    global visualSettings binsize std_coef newFs shiftCoeff time_back time_forward
    global csd_smooth_coef csd_contrast_coef csd_split_by_channel_gaps
    global meanControlsState axes_background_color stims stims_exist lastEventsFilePath
    global channelLayoutFilePath channelLayoutNameGrid event_inx viewerYlim viewerYlimManual
    global autodetection_settings zavSessionSettingsPath stims_loaded_from_settings

    applied = false;
    if exist(settingsPath, 'file') ~= 2
        return;
    end

    loadedSettings = load(settingsPath, '-mat');

    if isfield(loadedSettings, 'EV_version')
        channelNames = np_flatten(loadedSettings.channelNames);
        channelEnabled = np_flatten(loadedSettings.channelEnabled);
        scalingCoefficients = np_flatten(loadedSettings.scalingCoefficients);
        colorsIn = np_flatten(loadedSettings.colorsIn);
        lineCoefficients = np_flatten(loadedSettings.lineCoefficients);
        mean_group_ch = np_flatten(loadedSettings.mean_group_ch);
        csd_avaliable = np_flatten(loadedSettings.csd_avaliable);
        filter_avaliable = np_flatten(loadedSettings.filter_avaliable);
        baseline_subtract_available = true(1, numChannels);
        if isfield(loadedSettings, 'baseline_subtract_available')
            baseline_subtract_available = np_flatten(loadedSettings.baseline_subtract_available);
        end
    else
        warning('Old settings format detected');
        updatedData = loadedSettings.channelSettings;
        channelNames = updatedData(:, 1)';
        channelEnabled = [updatedData{:, 2}];
        scalingCoefficients = [updatedData{:, 3}];
        colorsIn = updatedData(:, 4)';
        lineCoefficients = [updatedData{:, 5}];
        mean_group_ch = np_flatten(loadedSettings.mean_group_ch);
        csd_avaliable = np_flatten(loadedSettings.csd_avaliable);
        filter_avaliable = np_flatten(loadedSettings.filter_avaliable);
        baseline_subtract_available = true(1, numChannels);
        if isfield(loadedSettings, 'baseline_subtract_available')
            baseline_subtract_available = np_flatten(loadedSettings.baseline_subtract_available);
        end
    end

    if isfield(loadedSettings, 'filterSettings') && ~isempty(loadedSettings.filterSettings)
        filterSettings = loadedSettings.filterSettings;
        if ~isfield(filterSettings, 'smoothSpan')
            filterSettings.smoothSpan = 0;
        end
        if ~isfield(filterSettings, 'smoothMethod')
            filterSettings.smoothMethod = 'moving';
        end
    else
        filterSettings.filterType = 'highpass';
        filterSettings.freqLow = 10;
        filterSettings.freqHigh = 50;
        filterSettings.order = 4;
        filterSettings.channelsToFilter = false(numChannels, 1);
        filterSettings.smoothSpan = 0;
        filterSettings.smoothMethod = 'moving';
    end
    if ~islogical(filterSettings.channelsToFilter) || numel(filterSettings.channelsToFilter) ~= numel(filter_avaliable)
        filterSettings.channelsToFilter = np_flatten(filter_avaliable);
    end

    if isfield(loadedSettings, 'newFs')
        newFs = loadedSettings.newFs;
    end
    if isfield(loadedSettings, 'shiftCoeff')
        shiftCoeff = loadedSettings.shiftCoeff;
    end
    if isfield(loadedSettings, 'time_back')
        time_back = loadedSettings.time_back;
    end
    if isfield(loadedSettings, 'time_forward')
        time_forward = loadedSettings.time_forward;
    end
    if isfield(loadedSettings, 'binsize')
        binsize = loadedSettings.binsize;
    end
    if isfield(loadedSettings, 'std_coef')
        std_coef = min(max(double(loadedSettings.std_coef), 0), 10);
    end
    if isfield(loadedSettings, 'csd_smooth_coef')
        csd_smooth_coef = loadedSettings.csd_smooth_coef;
    end
    csd_contrast_coef = loadCsdContrastCoefFromSettings(loadedSettings);
    csd_contrast_is_display = true;
    if isfield(loadedSettings, 'csd_split_by_channel_gaps')
        csd_split_by_channel_gaps = logical(loadedSettings.csd_split_by_channel_gaps);
    end
    if isfield(loadedSettings, 'visualSettings')
        applyChannelVisualSettings(loadedSettings.visualSettings);
    end
    if isfield(loadedSettings, 'meanControlsState') && isstruct(loadedSettings.meanControlsState)
        meanControlsState = loadedSettings.meanControlsState;
    end
    if isfield(loadedSettings, 'axes_background_color') && ~isempty(loadedSettings.axes_background_color)
        axes_background_color = loadedSettings.axes_background_color;
    end
    if isfield(loadedSettings, 'stims') && ~isempty(loadedSettings.stims)
        stims = loadedSettings.stims;
        stims_exist = ~isempty(stims);
        stims_loaded_from_settings = true;
    end
    if isfield(loadedSettings, 'lastEventsFilePath')
        lastEventsFilePath = loadedSettings.lastEventsFilePath;
    end
    channelLayoutFilePath = '';
    channelLayoutNameGrid = [];
    if isfield(loadedSettings, 'channelLayoutNameGrid') && ~isempty(loadedSettings.channelLayoutNameGrid)
        channelLayoutNameGrid = loadedSettings.channelLayoutNameGrid;
    end
    if isfield(loadedSettings, 'channelLayoutFilePath')
        channelLayoutFilePath = loadedSettings.channelLayoutFilePath;
    end
    normalizeViewerDisplayMode();
    if isfield(loadedSettings, 'viewerYlim') && numel(loadedSettings.viewerYlim) == 2
        viewerYlim = double(loadedSettings.viewerYlim(:)');
    end
    if isfield(loadedSettings, 'viewerYlimManual')
        viewerYlimManual = logical(loadedSettings.viewerYlimManual);
    end
    if isfield(loadedSettings, 'event_inx')
        loaded_event_inx = round(double(loadedSettings.event_inx));
        if isfinite(loaded_event_inx) && loaded_event_inx >= 1
            event_inx = loaded_event_inx;
        end
    end
    if isfield(loadedSettings, 'autodetection_settings') && isstruct(loadedSettings.autodetection_settings)
        autodetection_settings = loadedSettings.autodetection_settings;
    end

    zavSessionSettingsPath = settingsPath;
    applied = true;
end
