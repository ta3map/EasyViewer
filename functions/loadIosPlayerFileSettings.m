function settings = loadIosPlayerFileSettings(iosPath)
    settings = struct();
    settingsPath = getIosPlayerFileSettingsPath(iosPath);
    if exist(settingsPath, 'file') ~= 2
        return
    end
    d = load(settingsPath, '-mat', 'iosplayer_file_settings');
    if ~isfield(d, 'iosplayer_file_settings')
        return
    end
    settings = d.iosplayer_file_settings;
    canonicalPath = canonicalIosPath(iosPath);
    if isfield(settings, 'sourcePath') && ~strcmp(settings.sourcePath, canonicalPath)
        settings = struct();
    end
end
