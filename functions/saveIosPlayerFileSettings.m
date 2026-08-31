function saveIosPlayerFileSettings(iosPath, fileSettings)
    settingsPath = getIosPlayerFileSettingsPath(iosPath);
    settingsDir = fileparts(settingsPath);
    if exist(settingsDir, 'dir') ~= 7
        mkdir(settingsDir);
    end
    iosplayer_file_settings = fileSettings;
    if exist(settingsPath, 'file') == 2
        save(settingsPath, 'iosplayer_file_settings', '-mat', '-append');
    else
        save(settingsPath, 'iosplayer_file_settings', '-mat');
    end
end
