function path = initDbPath()
    global FileManagerDbPath
    stored = readStoredDbPath();
    if ~isempty(stored) && isfile(stored)
        FileManagerDbPath = stored;
        path = stored;
        return
    end
    defaultPath = defaultDbPath();
    if isfile(defaultPath)
        FileManagerDbPath = defaultPath;
        storeDbPath(defaultPath);
        path = defaultPath;
    else
        FileManagerDbPath = '';
        path = '';
    end
end

