function deleteAnalysisResults(reportPaths, callbackAfterDelete)
    if isempty(reportPaths)
        return
    end
    
    validPaths = reportPaths(~cellfun(@isempty, reportPaths));
    if isempty(validPaths)
        return
    end
    
    choice = questdlg(sprintf('Delete %d selected analysis result(s)?', numel(validPaths)), ...
        'Confirm Delete', 'Delete with metadata', 'Delete record', 'Cancel', 'Cancel');
    
    if strcmp(choice, 'Cancel')
        return
    end
    
    if strcmp(choice, 'Delete with metadata')
        deleteFiles(validPaths);
    end
    
    deleteRecords(validPaths);
    
    if nargin > 1 && ~isempty(callbackAfterDelete)
        callbackAfterDelete();
    end
end

function deleteFiles(paths)
    for i = 1:numel(paths)
        deleteIfExists(paths{i});
        metaPath = replaceFileExt(paths{i}, '.meta');
        deleteIfExists(metaPath);
    end
end

function deleteRecords(paths)
    if isempty(paths)
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
        escaped = cellfun(@(p) ['''' escapeSql(p) ''''], paths, 'UniformOutput', false);
        inClause = strjoin(escaped, ',');
        query = sprintf('DELETE FROM analysis_results WHERE report_path IN (%s)', inClause);
        sqlExecWithConn(conn, query);
    catch ME
        warning('Failed to delete records: %s', ME.message);
    end
    closeJdbcResource(conn);
end

function deleteIfExists(pathStr)
    if exist(pathStr, 'file')
        delete(pathStr);
    end
end


