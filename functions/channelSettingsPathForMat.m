function settingsPath = channelSettingsPathForMat(matPath)
    [path, name, ~] = fileparts(matPath);
    settingsPath = fullfile(path, [name '_channelSettings.stn']);
end
