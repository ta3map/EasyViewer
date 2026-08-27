function pd = prepareViewerPlotData()
%PREPAREVIEWERPLOTDATA Slice / filter / resample current viewer time window.

global chosen_time_interval time_back cond time lfp_file mean_group_ch ch_inxs m_coef Fs newFs
global timeUnitFactor data time_in filterSettings filter_avaliable
global art_rem_settings visualSettings stims
global baseline_subtract_available
global lastPlotTimeResForEvents lastPlotDataResForEvents lastPlotChInxsForEvents
global viewerPlotDataCache

pd = struct();
pd.show_events = true;
if isfield(visualSettings, 'events_show')
    pd.show_events = visualSettings.events_show;
end

pd.plot_time_interval = chosen_time_interval;
pd.plot_time_interval(1) = pd.plot_time_interval(1) - time_back;
pd.time_origin = chosen_time_interval(1);

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

[row_start, row_end] = timeWindowIndices(time, pd.plot_time_interval(1), pd.plot_time_interval(2));
if isempty(row_start)
    row_start = 1;
    row_end = 0;
end
cond = row_start:row_end;
lfpDims = lfp_size(lfp_file);
nCh = lfpDims(2);
mg = false(1, nCh);
if ~isempty(mean_group_ch) && any(mean_group_ch(:))
    rawMg = mean_group_ch(:);
    if islogical(rawMg)
        n = min(numel(rawMg), nCh);
        mg(1:n) = rawMg(1:n);
    else
        idx = rawMg(isfinite(rawMg) & rawMg >= 1 & rawMg <= nCh);
        mg(idx) = true;
    end
end
chNeed = unique(ch_inxs(:)', 'stable');
chNeed = chNeed(chNeed >= 1 & chNeed <= nCh);
cols = unique([chNeed, find(mg)], 'stable');
local_lfp = lfp_file.lfp(row_start:row_end, cols);
if any(mg)
    meanLocal = ismember(cols, find(mg));
    local_lfp(:, meanLocal) = local_lfp(:, meanLocal) - mean(local_lfp(:, meanLocal), 2);
end
[~, chLocal] = ismember(ch_inxs(:), cols);
data = local_lfp(:, chLocal) .* m_coef(:)';
time_in = time(cond);

if ~isempty(stims) && visualSettings.stim_show
    pd.cond3 = stims >= pd.plot_time_interval(1) & stims < pd.plot_time_interval(2);
    pd.stims_x = (stims(pd.cond3) - pd.time_origin) * timeUnitFactor;
    win_r = round(art_rem_settings.artifact_window_ms * (Fs / 1000));
    debugState('updatePlot', 'Stim artifact removal: Fs=%dHz, window=%.3f ms (~%d samples)', Fs, art_rem_settings.artifact_window_ms, win_r);
    data = removeStimArtifact(data, stims(pd.cond3), time_in, win_r, art_rem_settings.interp_method);
else
    pd.cond3 = [];
    pd.stims_x = [];
end

if sum(filter_avaliable) > 0
    ch_to_filter = filter_avaliable(ch_inxs);
    data(:, ch_to_filter) = applyFilter(data(:, ch_to_filter), filterSettings, newFs);
end

if Fs <= newFs
    pd.data_res = data;
    pd.time_res = time_in;
else
    pd.data_res = resample1(data, round(newFs), Fs);
    numPoints = size(pd.data_res, 1);
    pd.time_res = linspace(time_in(1), time_in(end), numPoints);
end

pd.numChannels = size(pd.data_res, 2);
pd.baseline_subtract_active = logical(baseline_subtract_available(ch_inxs));
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
lastPlotChInxsForEvents = ch_inxs;

viewerPlotDataCache = struct( ...
    'signature', sig, ...
    'data_res', pd.data_res, ...
    'time_res', pd.time_res, ...
    'time_in', time_in, ...
    'numChannels', pd.numChannels, ...
    'baseline_subtract_active', pd.baseline_subtract_active, ...
    'baseline_medians', pd.baseline_medians);

pd.time_in_transformed = (pd.time_res - pd.time_origin) * timeUnitFactor;
pd.Xlims = (pd.plot_time_interval - pd.time_origin) * timeUnitFactor;
pd.timeSpan = diff(pd.Xlims);
pd = appendViewerOverlayMeta(pd);
end
