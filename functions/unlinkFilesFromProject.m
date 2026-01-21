function unlinkFilesFromProject(fileIds, projectId)
    if isempty(fileIds) || isempty(projectId)
        return
    end
    
    if ~isnumeric(fileIds) || ~isnumeric(projectId)
        return
    end
    
    fileIds = fileIds(:);
    validIds = fileIds(~isnan(fileIds) & fileIds > 0);
    if isempty(validIds)
        return
    end
    
    dbPath = getDbPath();
    if isempty(dbPath) || ~isfile(dbPath)
        return
    end
    
    conn = openSqliteConnection(dbPath);
    if isempty(conn)
        return
    end
    
    try
        idsStr = sprintf('%d,', validIds);
        idsStr = idsStr(1:end-1);
        
        deleteLinkQuery = sprintf('DELETE FROM project_files WHERE project_id = %d AND file_id IN (%s)', projectId, idsStr);
        sqlExecWithConn(conn, deleteLinkQuery);
        
        unusedQuery = sprintf(['SELECT id FROM files WHERE id IN (%s) ' ...
            'AND NOT EXISTS (SELECT 1 FROM project_files WHERE file_id = files.id)'], idsStr);
        unusedRows = sqlFetchWithConn(conn, unusedQuery);
        
        if ~isempty(unusedRows)
            unusedIds = cellfun(@(idx) unusedRows{idx, 1}, num2cell(1:size(unusedRows, 1)));
            unusedIdsStr = sprintf('%d,', unusedIds);
            unusedIdsStr = unusedIdsStr(1:end-1);
            deleteFilesQuery = sprintf('DELETE FROM files WHERE id IN (%s)', unusedIdsStr);
            sqlExecWithConn(conn, deleteFilesQuery);
        end
    catch ME
        warning('Failed to unlink files from project: %s', ME.message);
    end
    
    closeJdbcResource(conn);
end
