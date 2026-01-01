function rows = sqlFetchWithConn(conn, query)
    rows = {};
    if isempty(conn)
        return
    end
    stmt = [];
    rs = [];
    try
        stmt = conn.createStatement();
        rs = stmt.executeQuery(query);
        rows = jdbcResultToCell(rs);
    catch ME
        warning('SQL fetch error: %s', ME.message);
        rows = {};
    end
    closeJdbcResource(rs);
    closeJdbcResource(stmt);
end

