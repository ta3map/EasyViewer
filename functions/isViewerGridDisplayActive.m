function active = isViewerGridDisplayActive()
global channelLayoutNameGrid visualSettings

active = ~isempty(channelLayoutNameGrid) ...
    && isfield(visualSettings, 'viewer_display_mode') ...
    && strcmp(visualSettings.viewer_display_mode, 'grid');
end
