function tf = isChannelSettingsApplied(settingsPath)
    global zavSessionSettingsPath channelEnabled channelNames numChannels

    if isempty(settingsPath) || exist(settingsPath, 'file') ~= 2
        tf = false;
        return;
    end
    tf = strcmp(zavSessionSettingsPath, settingsPath) ...
        && numChannels >= 1 ...
        && length(channelEnabled) == numChannels ...
        && length(channelNames) == numChannels;
end
