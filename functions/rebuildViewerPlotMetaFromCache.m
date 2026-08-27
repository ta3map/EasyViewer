function pd = rebuildViewerPlotMetaFromCache()
%REBUILDVIEWERPLOTMETAFROMCACHE Overlay/chrome meta without re-reading LFP.

global chosen_time_interval time_back timeUnitFactor
global lastPlotTimeResForEvents lastPlotDataResForEvents lastPlotChInxsForEvents
global ch_inxs visualSettings stims

pd = struct();
pd.show_events = true;
if isfield(visualSettings, 'events_show')
    pd.show_events = visualSettings.events_show;
end

pd.plot_time_interval = chosen_time_interval;
pd.plot_time_interval(1) = pd.plot_time_interval(1) - time_back;
pd.time_origin = chosen_time_interval(1);
pd.data_res = lastPlotDataResForEvents;
pd.time_res = lastPlotTimeResForEvents;
pd.numChannels = size(pd.data_res, 2);
pd.baseline_subtract_active = false(1, max(1, pd.numChannels));
pd.baseline_medians = zeros(1, max(1, pd.numChannels));
pd.time_in_transformed = (pd.time_res - pd.time_origin) * timeUnitFactor;
pd.Xlims = (pd.plot_time_interval - pd.time_origin) * timeUnitFactor;
pd.timeSpan = diff(pd.Xlims);

if ~isempty(stims) && visualSettings.stim_show
    pd.cond3 = stims >= pd.plot_time_interval(1) & stims < pd.plot_time_interval(2);
    pd.stims_x = (stims(pd.cond3) - pd.time_origin) * timeUnitFactor;
else
    pd.cond3 = [];
    pd.stims_x = [];
end

pd = appendViewerOverlayMeta(pd);
pd.ch_inxs = ch_inxs;
if isempty(pd.data_res) || ~isequal(ch_inxs(:)', lastPlotChInxsForEvents(:)')
    pd.needFreshData = true;
else
    pd.needFreshData = false;
end
end
