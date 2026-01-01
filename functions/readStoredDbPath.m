function path = readStoredDbPath()
    global SettingsFilepath
    path = '';
    try
        if exist(SettingsFilepath, 'file')
            data = load(SettingsFilepath, 'file_manager_db_path');
            if isfield(data, 'file_manager_db_path')
                path = data.file_manager_db_path;
            end
        end
    catch
        path = '';
    end
end

