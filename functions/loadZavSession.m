function loadZavSession(matPath, varargin)
%LOADZAVSESSION Load ZAV mat into session globals (no UI).

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
    global viewerYlim viewerYlimManual zavSessionLoadedMetadata

    p = inputParser;
    addParameter(p, 'profile', 'viewer', @(x) any(strcmp(x, {'viewer', 'analysis'})));
    addParameter(p, 'auto_set_time_windows', [], @(x) isempty(x) || islogical(x));
    addParameter(p, 'auto_set_fs', true, @islogical);
    addParameter(p, 'waitbar_handle', [], @(x) isempty(x) || ishghandle(x));
    addParameter(p, 'keep_waitbar_open', false, @islogical);
    addParameter(p, 'metadata_fields', {}, @iscell);
    addParameter(p, 'force_reload', false, @islogical);
    addParameter(p, 'notify_source', '', @ischar);
    parse(p, varargin{:});

    profileName = p.Results.profile;
    if strcmp(profileName, 'analysis')
        metadata_fields = {'hd', 'zavp'};
        auto_set_time_windows = false;
        if isempty(p.Results.auto_set_time_windows)
            auto_set_time_windows = false;
        else
            auto_set_time_windows = p.Results.auto_set_time_windows;
        end
    else
        metadata_fields = {'spks', 'hd', 'zavp', 'lfpVar', 'chnlGrp'};
        if isempty(p.Results.auto_set_time_windows)
            auto_set_time_windows = true;
        else
            auto_set_time_windows = p.Results.auto_set_time_windows;
        end
    end
    if ~isempty(p.Results.metadata_fields)
        metadata_fields = p.Results.metadata_fields;
    end

    if isZavSessionLoaded(matPath) && ~p.Results.force_reload
        ensureMetadataFields(metadata_fields);
        ensureChannelSettingsForSession();
        return;
    end

    if ~isempty(matFilePath) && ~isZavSessionLoaded(matPath)
        clearZavSession();
    end

    data = load_zav_file(matPath, ...
        'auto_set_time_windows', auto_set_time_windows, ...
        'auto_set_fs', p.Results.auto_set_fs, ...
        'waitbar_handle', p.Results.waitbar_handle, ...
        'keep_waitbar_open', p.Results.keep_waitbar_open, ...
        'metadata_fields', metadata_fields);

    [lfp_file, spks, hd, zavp, lfpVar, chnlGrp, time, stims, sweep_info, time_forward, time_back] = struct2vars(data);
    spks = sortSpikeTimestamps(spks);

    matFilePath = matPath;
    [~, matFileName, ~] = fileparts(matPath);
    evfilename = matFileName;
    spks_events = {};
    N = length(time);
    Fs = zavp.dwnSmplFrq;
    zavSessionLoadedMetadata = metadata_fields;

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

    if strcmp(profileName, 'viewer')
        binsize = 0.005;
        std_coef = 0;
        csd_smooth_coef = 5;
        csd_contrast_coef = 100;
        csd_contrast_is_display = true;
        csd_split_by_channel_gaps = false;
        t_mean_profile = 0;
        meanControlsState = struct();
        axes_background_color = '#FFFFFF';

        clearEventsState();
        lastEventsFilePath = '';
        viewerYlimManual = false;
        viewerYlim = [0 1];
    end

    settingsPath = channelSettingsPathForMat(matPath);
    if ~isChannelSettingsApplied(settingsPath)
        applyChannelSettingsFromFile(settingsPath, numChannels);
    end

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

    ensureChannelSettingsForSession();
    notifySessionPeers('fileLoaded', p.Results.notify_source);
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
