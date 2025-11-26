function sqlExec(query)
    dbPath = getDbPath();
    if isempty(dbPath) || ~isfile(dbPath)
        warning('Database not found: %s', dbPath);
        return
    end
    conn = openSqliteConnection(dbPath);
    if isempty(conn)
        return
    end
    try
        sqlExecWithConn(conn, query);
    catch ME
        warning('SQL exec error: %s', ME.message);
    end
    closeJdbcResource(conn);
end

