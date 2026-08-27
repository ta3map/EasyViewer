function sig = buildViewerPlotDataSignature(plot_time_interval)
%BUILDVIEWERPLOTDATASIGNATURE Key for viewer processed-window cache.

global chosen_time_interval time_back ch_inxs m_coef mean_group_ch Fs newFs
global filterSettings filter_avaliable baseline_subtract_available
global art_rem_settings visualSettings stims matFilePath

if nargin < 1 || isempty(plot_time_interval)
    plot_time_interval = chosen_time_interval;
    plot_time_interval(1) = plot_time_interval(1) - time_back;
end

sig = struct();
sig.matFilePath = char(string(matFilePath));
sig.plot_time_interval = plot_time_interval(:)';
sig.ch_inxs = ch_inxs(:)';
sig.m_coef = m_coef(:)';
sig.mean_group_ch = logical(mean_group_ch(:));
sig.Fs = Fs;
sig.newFs = newFs;
sig.filter_avaliable = logical(filter_avaliable(ch_inxs));
sig.baseline_subtract = logical(baseline_subtract_available(ch_inxs));
sig.stim_show = isfield(visualSettings, 'stim_show') && logical(visualSettings.stim_show);

sig.filterType = '';
sig.freqLow = [];
sig.freqHigh = [];
sig.order = [];
sig.smoothSpan = [];
sig.smoothMethod = '';
sig.channelsToFilter = logical([]);
if ~isempty(filterSettings) && isstruct(filterSettings)
    if isfield(filterSettings, 'filterType')
        sig.filterType = char(string(filterSettings.filterType));
    end
    if isfield(filterSettings, 'freqLow')
        sig.freqLow = filterSettings.freqLow;
    end
    if isfield(filterSettings, 'freqHigh')
        sig.freqHigh = filterSettings.freqHigh;
    end
    if isfield(filterSettings, 'order')
        sig.order = filterSettings.order;
    end
    if isfield(filterSettings, 'smoothSpan')
        sig.smoothSpan = filterSettings.smoothSpan;
    end
    if isfield(filterSettings, 'smoothMethod')
        sig.smoothMethod = char(string(filterSettings.smoothMethod));
    end
    if isfield(filterSettings, 'channelsToFilter')
        sig.channelsToFilter = logical(filterSettings.channelsToFilter(:));
    end
end

sig.artifact_window_ms = [];
sig.interp_method = '';
if ~isempty(art_rem_settings) && isstruct(art_rem_settings)
    if isfield(art_rem_settings, 'artifact_window_ms')
        sig.artifact_window_ms = art_rem_settings.artifact_window_ms;
    end
    if isfield(art_rem_settings, 'interp_method')
        sig.interp_method = char(string(art_rem_settings.interp_method));
    end
end

sig.stims_in_window = [];
if sig.stim_show && ~isempty(stims)
    sig.stims_in_window = stims(stims >= plot_time_interval(1) & stims < plot_time_interval(2));
    sig.stims_in_window = sig.stims_in_window(:)';
end
end
