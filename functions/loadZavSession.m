function loadZavSession(matPath, varargin)
%LOADZAVSESSION Load ZAV mat into session globals (no UI).
%
%   loadZavSession(matPath)
%   loadZavSession(matPath, 'auto_set_time_windows', true, 'auto_set_fs', true, ...)
%
%   Name-value args are forwarded to load_zav_file where applicable.

    global lfp_file spks hd zavp lfpVar chnlGrp time stims sweep_info
    global time_forward time_back matFilePath matFileName evfilename
    global Fs N newFs shiftCoeff stims_exist stim_inx sweep_inx selectedCenter
    global chosen_time_interval windowSize spks_events numChannels
    global channelNames channelEnabled scalingCoefficients colorsIn lineCoefficients
    global mean_group_ch csd_avaliable filter_avaliable baseline_subtract_available filterSettings
    global visualSettings binsize std_coef
    global csd_smooth_coef csd_contrast_coef csd_contrast_is_display csd_split_by_channel_gaps
    global t_mean_profile meanControlsState axes_background_color
    global ch_inxs events event_indices event_comments event_amplitudes
    global event_channels event_widths event_prominences event_metadata
    global events_exist event_inx event_title_string lastEventsFilePath channelLayoutFilePath channelLayoutNameGrid
    global viewerYlim viewerYlimManual

    p = inputParser;
    addParameter(p, 'auto_set_time_windows', true, @islogical);
    addParameter(p, 'auto_set_fs', true, @islogical);
    addParameter(p, 'waitbar_handle', [], @(x) isempty(x) || ishghandle(x));
    addParameter(p, 'keep_waitbar_open', false, @islogical);
    parse(p, varargin{:});

    data = load_zav_file(matPath, ...
        'auto_set_time_windows', p.Results.auto_set_time_windows, ...
        'auto_set_fs', p.Results.auto_set_fs, ...
        'waitbar_handle', p.Results.waitbar_handle, ...
        'keep_waitbar_open', p.Results.keep_waitbar_open);

    [lfp_file, spks, hd, zavp, lfpVar, chnlGrp, time, stims, sweep_info, time_forward, time_back] = struct2vars(data);
    spks = sortSpikeTimestamps(spks);

    matFilePath = matPath;
    [~, matFileName, ~] = fileparts(matPath);
    evfilename = matFileName;
    spks_events = {};
    N = length(time);
    Fs = zavp.dwnSmplFrq;

    if p.Results.auto_set_fs
        newFs = Fs;
    else
        newFs = 1000;
    end

    shiftCoeff = 200;
    stims_exist = ~isempty(stims);
    stim_inx = 1;
    sweep_inx = 1;
    windowSize = time_forward;
    selectedCenter = 'continuous';
    chosen_time_interval = [0, windowSize];
    if stims_exist && numel(stims) > 1
        selectedCenter = 'stimulus';
        chosen_time_interval = [stims(stim_inx), stims(stim_inx) + windowSize];
    end

    channelNames = np_flatten(hd.recChNames);
    numChannels = length(channelNames);
    applyStandardChannelSettings(numChannels);

    binsize = 0.005;
    std_coef = 0;
    csd_smooth_coef = 5;
    csd_contrast_coef = 100;
    csd_contrast_is_display = true;
    csd_split_by_channel_gaps = false;
    t_mean_profile = 0;
    meanControlsState = struct();
    axes_background_color = '#FFFFFF';
    visualSettings.show_spikes = false;
    visualSettings.show_CSD = false;

    clearEventsState();
    lastEventsFilePath = '';
    channelLayoutFilePath = '';
    channelLayoutNameGrid = [];
    viewerYlimManual = false;
    viewerYlim = [0 1];

    settingsPath = fullfile(fileparts(matPath), [matFileName '_channelSettings.stn']);
    applyChannelSettingsFile(settingsPath, numChannels);

    stims_exist = ~isempty(stims);
    ch_inxs = find(channelEnabled);
    windowSize = time_forward;
    if stims_exist && numel(stims) > 1
        selectedCenter = 'stimulus';
        chosen_time_interval = [stims(stim_inx), stims(stim_inx) + windowSize];
    else
        selectedCenter = 'continuous';
        chosen_time_interval = [0, windowSize];
    end
end

function applyStandardChannelSettings(numChannels)
    global channelNames channelEnabled scalingCoefficients colorsIn lineCoefficients
    global mean_group_ch csd_avaliable filter_avaliable baseline_subtract_available filterSettings

    channelNames = np_flatten(channelNames);
    channelEnabled = true(1, numChannels);
    scalingCoefficients = ones(1, numChannels);
    colorsIn = np_flatten(getColors(numChannels));
    lineCoefficients = ones(1, numChannels) * 0.5;
    mean_group_ch = false(1, numChannels);
    csd_avaliable = true(1, numChannels);
    filter_avaliable = false(1, numChannels);
    baseline_subtract_available = true(1, numChannels);
    filterSettings = struct( ...
        'filterType', 'highpass', ...
        'freqLow', 10, ...
        'freqHigh', 50, ...
        'order', 4, ...
        'channelsToFilter', false(numChannels, 1), ...
        'smoothSpan', 0, ...
        'smoothMethod', 'moving');
end

function applyChannelSettingsFile(settingsPath, numChannels)
    global channelNames channelEnabled scalingCoefficients colorsIn lineCoefficients
    global mean_group_ch csd_avaliable filter_avaliable baseline_subtract_available filterSettings
    global visualSettings binsize std_coef newFs shiftCoeff time_back time_forward
    global csd_smooth_coef csd_contrast_coef csd_split_by_channel_gaps
    global meanControlsState axes_background_color stims lastEventsFilePath channelLayoutFilePath channelLayoutNameGrid event_inx
    global viewerYlim viewerYlimManual
    global autodetection_settings

    if exist(settingsPath, 'file') ~= 2
        return
    end

    loadedSettings = load(settingsPath, '-mat');

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

    if isfield(loadedSettings, 'filterSettings') && ~isempty(loadedSettings.filterSettings)
        filterSettings = loadedSettings.filterSettings;
        if ~isfield(filterSettings, 'smoothSpan')
            filterSettings.smoothSpan = 0;
        end
        if ~isfield(filterSettings, 'smoothMethod')
            filterSettings.smoothMethod = 'moving';
        end
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
end
