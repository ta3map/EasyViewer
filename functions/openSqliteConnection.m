function conn = openSqliteConnection(dbPath)
    persistent driverInstance driverLoaded
    conn = [];
    if isempty(dbPath)
        return
    end
    
    functionsDir = fileparts(mfilename('fullpath'));
    driverPath = fullfile(functionsDir, 'sqlite-jdbc.jar');
    driverPath = char(java.io.File(driverPath).getAbsolutePath());
    
    if isempty(driverLoaded) || ~driverLoaded || isempty(driverInstance)
        if ~jdbcDriverLoaded(driverPath)
            return
        end
        try
            javaaddpath(driverPath);
            driverInstance = javaObject('org.sqlite.JDBC');
            driverLoaded = true;
        catch ME
            warning('Failed to load SQLite driver: %s', ME.message);
            driverLoaded = false;
            driverInstance = [];
            return
        end
    end
    
    try
        dbUrl = ['jdbc:sqlite:' strrep(dbPath, '\', '/')];
        props = java.util.Properties();
        conn = driverInstance.connect(dbUrl, props);
    catch ME
        warning('SQLite connection error: %s', ME.message);
        conn = [];
        driverLoaded = false;
        driverInstance = [];
    end
end

