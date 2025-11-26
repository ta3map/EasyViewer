function sqlExecWithConn(conn, query)
    if isempty(conn)
        return
    end
    stmt = [];
    try
        stmt = conn.createStatement();
        stmt.executeUpdate(query);
    catch ME
        warning('SQL exec error: %s', ME.message);
        rethrow(ME);
    end
    closeJdbcResource(stmt);
end

