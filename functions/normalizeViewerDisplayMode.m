function normalizeViewerDisplayMode()
global visualSettings channelLayoutNameGrid

if ~isfield(visualSettings, 'viewer_display_mode') || isempty(visualSettings.viewer_display_mode)
    visualSettings.viewer_display_mode = 'linear';
    if ~isempty(channelLayoutNameGrid)
        visualSettings.viewer_display_mode = 'grid';
    end
end
if strcmp(visualSettings.viewer_display_mode, 'grid') && isempty(channelLayoutNameGrid)
    visualSettings.viewer_display_mode = 'linear';
end
end
