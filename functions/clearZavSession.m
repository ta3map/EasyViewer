function clearZavSession()
    global lfp_file spks hd zavp lfpVar chnlGrp time stims sweep_info spks_events
    global time_forward time_back matFilePath matFileName evfilename
    global Fs N newFs shiftCoeff stims_exist stim_inx sweep_inx selectedCenter
    global chosen_time_interval windowSize numChannels ch_inxs
    global channelNames channelEnabled scalingCoefficients colorsIn lineCoefficients
    global mean_group_ch csd_avaliable filter_avaliable baseline_subtract_available filterSettings
    global zavSessionSettingsPath zavSessionLoadedMetadata

    lfp_file = [];
    spks = [];
    hd = [];
    zavp = [];
    lfpVar = [];
    chnlGrp = [];
    time = [];
    stims = [];
    spks_events = {};
    sweep_info = struct('is_sweep_data', false, 'sweep_count', 0, 'sweep_times', []);
    time_forward = [];
    time_back = [];
    matFilePath = '';
    matFileName = '';
    evfilename = '';
    Fs = [];
    N = [];
    newFs = [];
    shiftCoeff = [];
    stims_exist = false;
    stim_inx = 1;
    sweep_inx = 1;
    selectedCenter = 'continuous';
    chosen_time_interval = [0, 0];
    windowSize = [];
    numChannels = [];
    ch_inxs = [];
    channelNames = {};
    channelEnabled = [];
    scalingCoefficients = [];
    colorsIn = {};
    lineCoefficients = [];
    mean_group_ch = [];
    csd_avaliable = [];
    filter_avaliable = [];
    baseline_subtract_available = [];
    filterSettings = struct();
    zavSessionSettingsPath = '';
    zavSessionLoadedMetadata = {};
end
