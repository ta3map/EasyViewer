function storeDbPath(dbPath)
    global SettingsFilepath
    try
        if exist(SettingsFilepath, 'file')
            data = load(SettingsFilepath);
        else
            data = struct();
        end
        data.file_manager_db_path = dbPath;
        save(SettingsFilepath, '-struct', 'data');
    catch ME
        warning('Failed to save database path: %s', ME.message);
    end
end

