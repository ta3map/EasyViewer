function a = viewerPlotActions(reason)
%VIEWERPLOTACTIONS Flags for which viewer plot layers to refresh.

a = struct( ...
    'needData', true, ...
    'showLoading', true, ...
    'invalidate', false, ...
    'layoutSwitch', false, ...
    'traces', true, ...
    'csd', true, ...
    'mua', true, ...
    'overlays', true, ...
    'chrome', true, ...
    'ui', true);

switch reason
    case 'overlay_toggle'
        a.needData = false;
        a.showLoading = false;
        a.traces = false;
        a.csd = false;
        a.mua = false;
    case 'style_change'
        a.needData = false;
        a.showLoading = false;
        a.csd = false;
        a.mua = false;
    case 'ylim_shift'
        global visualSettings
        a.needData = isfield(visualSettings, 'auto_shift') && logical(visualSettings.auto_shift);
        a.showLoading = a.needData;
        a.csd = false;
        a.mua = false;
    case 'amp_labels'
        a.needData = false;
        a.showLoading = false;
        a.traces = false;
        a.csd = false;
        a.mua = false;
        a.overlays = false;
    case 'csd_toggle'
        % needData stays true; prepareViewerPlotData cache hits when window unchanged
        a.mua = false;
    case 'spikes_toggle'
        % needData stays true; prepareViewerPlotData cache hits when window unchanged
        a.csd = false;
    case 'layout_mode'
        a.layoutSwitch = true;
        a.invalidate = true;
    case 'full_rebuild'
        a.invalidate = true;
    case {'navigation', 'time_window', 'channel_change', 'filter_change', 'visual'}
        % full data path defaults
    otherwise
        % unknown reason -> visual defaults
end
end
