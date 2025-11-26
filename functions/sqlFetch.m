function rows = sqlFetch(query)
    dbPath = getDbPath();
    if isempty(dbPath) || ~isfile(dbPath)
        warning('Database not found: %s', dbPath);
        rows = {};
        return
    end
    conn = openSqliteConnection(dbPath);
    if isempty(conn)
        rows = {};
        return
    end
    rows = sqlFetchWithConn(conn, query);
    closeJdbcResource(conn);
end

