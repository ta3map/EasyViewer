function pd = prepareViewerPlotData(context)
%PREPAREVIEWERPLOTDATA Slice / filter / resample current viewer time window.
%   prepareViewerPlotData() — globals (viewer).
%   prepareViewerPlotData(context) — optional ch_inxs, m_coef, mean_group_ch,
%   filter_avaliable, baseline_subtract_available; skips cache.

global chosen_time_interval time_back time lfp_file mean_group_ch ch_inxs m_coef Fs newFs
global timeUnitFactor data time_in filterSettings filter_avaliable
global art_rem_settings visualSettings stims
global baseline_subtract_available
global lastPlotTimeResForEvents lastPlotDataResForEvents lastPlotChInxsForEvents
global viewerPlotDataCache

if nargin < 1
    context = struct();
end

useContext = isfield(context, 'ch_inxs') && ~isempty(context.ch_inxs);
work_ch_inxs = ch_inxs;
work_m_coef = m_coef;
work_mean_group_ch = mean_group_ch;
work_filter_avaliable = filter_avaliable;
work_baseline_subtract_available = baseline_subtract_available;

if useContext
    work_ch_inxs = context.ch_inxs(:)';
    if isfield(context, 'm_coef')
        work_m_coef = context.m_coef;
    end
    if isfield(context, 'mean_group_ch')
        work_mean_group_ch = context.mean_group_ch;
    end
    if isfield(context, 'filter_avaliable')
        work_filter_avaliable = context.filter_avaliable;
    end
    if isfield(context, 'baseline_subtract_available')
        work_baseline_subtract_available = context.baseline_subtract_available;
    end
end

pd = struct();
pd.show_events = true;
if isfield(visualSettings, 'events_show')
    pd.show_events = visualSettings.events_show;
end

if isfield(context, 'plot_time_interval') && numel(context.plot_time_interval) >= 2
    pd.plot_time_interval = context.plot_time_interval(:)';
else
    pd.plot_time_interval = chosen_time_interval;
    pd.plot_time_interval(1) = pd.plot_time_interval(1) - time_back;
end
pd.time_origin = chosen_time_interval(1);

skipCache = useContext;
if ~skipCache
    sig = buildViewerPlotDataSignature(pd.plot_time_interval);
    cacheHit = ~isempty(viewerPlotDataCache) && isstruct(viewerPlotDataCache) ...
        && isfield(viewerPlotDataCache, 'signature') ...
        && isequal(viewerPlotDataCache.signature, sig) ...
        && isfield(viewerPlotDataCache, 'data_res') ...
        && ~isempty(viewerPlotDataCache.data_res);

    if cacheHit
        pd.data_res = viewerPlotDataCache.data_res;
        pd.time_res = viewerPlotDataCache.time_res;
        pd.numChannels = viewerPlotDataCache.numChannels;
        pd.baseline_subtract_active = viewerPlotDataCache.baseline_subtract_active;
        pd.baseline_medians = viewerPlotDataCache.baseline_medians;
        if isfield(viewerPlotDataCache, 'time_in')
            time_in = viewerPlotDataCache.time_in;
        end
        if ~isempty(stims) && visualSettings.stim_show
            pd.cond3 = stims >= pd.plot_time_interval(1) & stims < pd.plot_time_interval(2);
            pd.stims_x = (stims(pd.cond3) - pd.time_origin) * timeUnitFactor;
        else
            pd.cond3 = [];
            pd.stims_x = [];
        end
        lastPlotTimeResForEvents = pd.time_res;
        lastPlotDataResForEvents = pd.data_res;
        lastPlotChInxsForEvents = ch_inxs;
        pd.time_in_transformed = (pd.time_res - pd.time_origin) * timeUnitFactor;
        pd.Xlims = (pd.plot_time_interval - pd.time_origin) * timeUnitFactor;
        pd.timeSpan = diff(pd.Xlims);
        pd = appendViewerOverlayMeta(pd);
        return;
    end
end

lfpDims = lfp_size(lfp_file);
nCh = lfpDims(2);
chNeed = unique(work_ch_inxs(:)', 'stable');
chNeed = chNeed(chNeed >= 1 & chNeed <= nCh);

[local_lfp, time_in, cols] = readLfpChannelsForInterval( ...
    lfp_file, time, pd.plot_time_interval, chNeed, work_mean_group_ch);

if isempty(local_lfp)
    data = zeros(0, numel(chNeed));
else
    [~, chLocal] = ismember(work_ch_inxs(:), cols);
    work_m_coef = work_m_coef(:)';
    nWorkCh = numel(work_ch_inxs);
    if numel(work_m_coef) < nWorkCh
        work_m_coef = [work_m_coef, ones(1, nWorkCh - numel(work_m_coef))];
    end
    data = local_lfp(:, chLocal) .* work_m_coef(1:nWorkCh);
end

stims_in = [];
if ~isempty(stims) && visualSettings.stim_show
    pd.cond3 = stims >= pd.plot_time_interval(1) & stims < pd.plot_time_interval(2);
    pd.stims_x = (stims(pd.cond3) - pd.time_origin) * timeUnitFactor;
    stims_in = stims(pd.cond3);
    debugState('updatePlot', 'Stim artifact removal: Fs=%dHz, window=%.3f ms (~%d samples)', ...
        Fs, art_rem_settings.artifact_window_ms, round(art_rem_settings.artifact_window_ms * (Fs / 1000)));
else
    pd.cond3 = [];
    pd.stims_x = [];
end

procOpts = struct( ...
    'profile', 'viewer', ...
    'remove_artifact', ~isempty(stims) && visualSettings.stim_show, ...
    'stims_in', stims_in, ...
    'artifact_window_ms', art_rem_settings.artifact_window_ms, ...
    'artifact_interp_method', art_rem_settings.interp_method, ...
    'Fs', Fs, ...
    'newFs', newFs, ...
    'filterSettings', filterSettings, ...
    'filter_mask', false(1, max(1, size(data, 2))));
if sum(work_filter_avaliable) > 0 && size(data, 2) > 0
    procOpts.filter_mask = work_filter_avaliable(work_ch_inxs);
end

[pd.data_res, pd.time_res] = processSignalChannels(data, time_in, procOpts);

pd.numChannels = size(pd.data_res, 2);
pd.baseline_subtract_active = logical(work_baseline_subtract_available(work_ch_inxs));
pd.baseline_subtract_active = reshape(pd.baseline_subtract_active, 1, []);
if numel(pd.baseline_subtract_active) ~= pd.numChannels
    tmp = false(1, pd.numChannels);
    n = min(numel(pd.baseline_subtract_active), pd.numChannels);
    tmp(1:n) = pd.baseline_subtract_active(1:n);
    pd.baseline_subtract_active = tmp;
end
pd.baseline_medians = zeros(1, pd.numChannels);
baselineLength = max(1, round(size(pd.data_res, 1) * 0.1));
med = median(pd.data_res(1:baselineLength, :), 1);
if any(pd.baseline_subtract_active)
    pd.baseline_medians(pd.baseline_subtract_active) = med(pd.baseline_subtract_active);
    pd.data_res(:, pd.baseline_subtract_active) = pd.data_res(:, pd.baseline_subtract_active) - med(pd.baseline_subtract_active);
end

lastPlotTimeResForEvents = pd.time_res;
lastPlotDataResForEvents = pd.data_res;
lastPlotChInxsForEvents = work_ch_inxs;

if ~skipCache
    viewerPlotDataCache = struct( ...
        'signature', sig, ...
        'data_res', pd.data_res, ...
        'time_res', pd.time_res, ...
        'time_in', time_in, ...
        'numChannels', pd.numChannels, ...
        'baseline_subtract_active', pd.baseline_subtract_active, ...
        'baseline_medians', pd.baseline_medians);
end

pd.time_in_transformed = (pd.time_res - pd.time_origin) * timeUnitFactor;
pd.Xlims = (pd.plot_time_interval - pd.time_origin) * timeUnitFactor;
pd.timeSpan = diff(pd.Xlims);
pd = appendViewerOverlayMeta(pd);
end
