function applyChannelVisualSettings(loadedVisual)
global visualSettings

if ~isstruct(loadedVisual)
    return;
end
if isfield(loadedVisual, 'show_spikes')
    visualSettings.show_spikes = logical(loadedVisual.show_spikes);
end
if isfield(loadedVisual, 'show_CSD')
    visualSettings.show_CSD = logical(loadedVisual.show_CSD);
end
if isfield(loadedVisual, 'mua_use_mask')
    visualSettings.mua_use_mask = logical(loadedVisual.mua_use_mask);
end
if isfield(loadedVisual, 'mua_color') && ~isempty(loadedVisual.mua_color)
    visualSettings.mua_color = loadedVisual.mua_color;
end
if isfield(loadedVisual, 'mua_alpha')
    visualSettings.mua_alpha = min(max(double(loadedVisual.mua_alpha), 0), 1);
end
if isfield(loadedVisual, 'viewer_display_mode') && ~isempty(loadedVisual.viewer_display_mode)
    visualSettings.viewer_display_mode = char(loadedVisual.viewer_display_mode);
end
end
