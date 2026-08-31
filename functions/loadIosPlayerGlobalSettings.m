function settings = loadIosPlayerGlobalSettings()
    global SettingsFilepath
    settings = struct();
    if isempty(SettingsFilepath)
        SettingsFilepath = fullfile(tempdir, 'ev_settings.mat');
    end
    if exist(SettingsFilepath, 'file') ~= 2
        return
    end
    d = load(SettingsFilepath);
    if isfield(d, 'iosplayer_global_settings')
        settings = d.iosplayer_global_settings;
    end
end
