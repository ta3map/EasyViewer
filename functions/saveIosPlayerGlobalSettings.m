function saveIosPlayerGlobalSettings(settings)
    global SettingsFilepath
    if isempty(SettingsFilepath)
        SettingsFilepath = fullfile(tempdir, 'ev_settings.mat');
    end
    iosplayer_global_settings = settings;
    save(SettingsFilepath, 'iosplayer_global_settings', '-append');
end
