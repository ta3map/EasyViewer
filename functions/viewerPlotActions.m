function a = viewerPlotActions(reason)
%VIEWERPLOTACTIONS Flags for which viewer plot layers to refresh.

a = struct( ...
    'needData', true, ...
    'showLoading', true, ...
    'invalidate', false, ...
    'layoutSwitch', false, ...
    'background', false, ...
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
        a.needData = false;
        a.showLoading = false;
        a.csd = false;
        a.mua = false;
    case 'ylim_manual'
        a.needData = false;
        a.showLoading = false;
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
        a.mua = false;
        a.traces = false;
        a.overlays = false;
        a.chrome = false;
        a.showLoading = false;
    case 'spikes_toggle'
        a.csd = false;
        a.traces = false;
        a.overlays = false;
        a.chrome = false;
        a.showLoading = false;
    case 'layout_mode'
        a.layoutSwitch = true;
        a.invalidate = true;
    case 'full_rebuild'
        a.invalidate = true;
        a.showLoading = false;
    case {'navigation', 'time_window'}
        a.showLoading = false;
    case 'peer_sync'
        a.showLoading = false;
        a.background = true;
    case {'channel_change', 'filter_change', 'visual'}
        % full data path defaults
    otherwise
        % unknown reason -> visual defaults
end
end
