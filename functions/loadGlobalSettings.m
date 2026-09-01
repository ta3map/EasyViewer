function loadGlobalSettings()
%LOADGLOBALSETTINGS App-level settings from ev_settings.mat (not ZAV session state).

    global lastOpenedFiles figure_position add_event_settings
    global timeUnitFactor selectedUnit autodetection_settings
    global art_rem_settings lines_and_styles
    global auto_open_last_file SettingsFilepath import_settings
    global visualSettings

    SettingsFilepath = fullfile(tempdir, 'ev_settings.mat');
    defaults = getDefaultGlobalSettings();
    sessionActive = isZavSessionLoaded();

    if ~exist(SettingsFilepath, 'file')
        try
            applyDefaultsToGlobals(defaults, sessionActive);
            cursor_positions = defaults.cursor_positions;
            saveGlobalSettingsFile(SettingsFilepath, cursor_positions);
            disp('Default settings file created successfully');
        catch ME
            warning('Error creating default settings file: %s', ME.message);
        end
    end

    if exist(SettingsFilepath, 'file')
        try
            d = load(SettingsFilepath);

            lastOpenedFiles = pickField(d, 'lastOpenedFiles', defaults.lastOpenedFiles);
            figure_position = pickField(d, 'figure_position', defaults.figure_position);
            add_event_settings = pickField(d, 'add_event_settings', defaults.add_event_settings);
            timeUnitFactor = pickField(d, 'timeUnitFactor', defaults.timeUnitFactor);
            selectedUnit = pickField(d, 'selectedUnit', defaults.selectedUnit);
            autodetection_settings = pickField(d, 'autodetection_settings', defaults.autodetection_settings);
            import_settings = pickField(d, 'import_settings', defaults.import_settings);
            art_rem_settings = pickField(d, 'art_rem_settings', defaults.art_rem_settings);
            lines_and_styles = pickField(d, 'lines_and_styles', defaults.lines_and_styles);

            if ~sessionActive
                if isfield(d, 'visualSettings')
                    visualSettings = d.visualSettings;
                    for fn = fieldnames(defaults.visualSettings)'
                        if ~isfield(visualSettings, fn{1})
                            visualSettings.(fn{1}) = defaults.visualSettings.(fn{1});
                        end
                    end
                else
                    visualSettings = defaults.visualSettings;
                end
                normalizeViewerDisplayMode();
            end

            if isfield(d, 'auto_open_last_file')
                auto_open_last_file = d.auto_open_last_file;
            else
                auto_open_last_file = false;
            end

        catch ME
            warning('Ошибка при загрузке настроек: %s', ME.message);
            applyDefaultsToGlobals(defaults, sessionActive);
            try
                delete(SettingsFilepath);
            catch
            end
            cursor_positions = defaults.cursor_positions;
            try
                saveGlobalSettingsFile(SettingsFilepath, cursor_positions);
            catch ME2
                warning('Не удалось записать новый файл настроек: %s', ME2.message);
            end
        end
    end
end

function value = pickField(d, name, defaultValue)
    if isfield(d, name)
        value = d.(name);
    else
        value = defaultValue;
    end
end

function applyDefaultsToGlobals(defaults, sessionActive)
    global lastOpenedFiles figure_position add_event_settings
    global timeUnitFactor selectedUnit autodetection_settings
    global art_rem_settings lines_and_styles
    global auto_open_last_file import_settings
    global visualSettings

    if nargin < 2
        sessionActive = isZavSessionLoaded();
    end

    lastOpenedFiles = defaults.lastOpenedFiles;
    figure_position = defaults.figure_position;
    timeUnitFactor = defaults.timeUnitFactor;
    selectedUnit = defaults.selectedUnit;
    art_rem_settings = defaults.art_rem_settings;
    add_event_settings = defaults.add_event_settings;
    autodetection_settings = defaults.autodetection_settings;
    import_settings = defaults.import_settings;
    lines_and_styles = defaults.lines_and_styles;
    auto_open_last_file = defaults.auto_open_last_file;
    if ~sessionActive
        visualSettings = defaults.visualSettings;
    end
end

function saveGlobalSettingsFile(SettingsFilepath, cursor_positions)
    global lastOpenedFiles figure_position add_event_settings
    global timeUnitFactor selectedUnit autodetection_settings
    global art_rem_settings lines_and_styles
    global auto_open_last_file import_settings
    global visualSettings

    save(SettingsFilepath, ...
        'lastOpenedFiles', ...
        'figure_position', ...
        'timeUnitFactor', ...
        'selectedUnit', ...
        'art_rem_settings', ...
        'add_event_settings', ...
        'autodetection_settings', ...
        'import_settings', ...
        'lines_and_styles', ...
        'auto_open_last_file', ...
        'visualSettings', ...
        'cursor_positions');
end
