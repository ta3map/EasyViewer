function tf = isChannelSettingsApplied(settingsPath)
    global zavSessionSettingsPath channelEnabled

    if isempty(settingsPath) || exist(settingsPath, 'file') ~= 2
        tf = false;
        return;
    end
    tf = strcmp(zavSessionSettingsPath, settingsPath) && ~isempty(channelEnabled);
end
