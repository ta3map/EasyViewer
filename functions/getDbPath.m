function dbPath = getDbPath()
    global FileManagerDbPath
    if isempty(FileManagerDbPath)
        FileManagerDbPath = initDbPath();
    end
    dbPath = FileManagerDbPath;
end

