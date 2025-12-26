function logAnalysisResult(fileIdOrPath, result)
    if isempty(result) || ~isstruct(result)
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
        fileId = [];
        if isnumeric(fileIdOrPath) && ~isempty(fileIdOrPath)
            fileId = fileIdOrPath;
        elseif ischar(fileIdOrPath) || isstring(fileIdOrPath)
            filePath = char(fileIdOrPath);
            record = sqlFetchWithConn(conn, sprintf('SELECT id FROM files WHERE file_path = ''%s'' LIMIT 1', escapeSql(filePath)));
            if ~isempty(record)
                fileId = record{1};
            else
                [~, name, ext] = fileparts(filePath);
                fileName = [name, ext];
                insertFile = sprintf('INSERT INTO files (file_path, file_name, created_at) VALUES (''%s'', ''%s'', CURRENT_TIMESTAMP)', ...
                    escapeSql(filePath), escapeSql(fileName));
                sqlExecWithConn(conn, insertFile);
                record = sqlFetchWithConn(conn, sprintf('SELECT id FROM files WHERE file_path = ''%s'' LIMIT 1', escapeSql(filePath)));
                if ~isempty(record)
                    fileId = record{1};
                end
            end
        end
        
        if isempty(fileId)
            closeJdbcResource(conn);
            return
        end
        
        paramsJson = '';
        if isfield(result, 'parameters') && ~isempty(result.parameters)
            paramsJson = jsonencode(result.parameters);
        end
        
        moduleName = getStructValue(result, 'module_name', 'macro');
        moduleDisplay = getStructValue(result, 'module_display_name', moduleName);
        moduleDesc = getStructValue(result, 'module_description', '');
        reportPath = getStructValue(result, 'report_path', '');
        
        if isempty(reportPath)
            closeJdbcResource(conn);
            return
        end
        
        % Проверяем, есть ли уже запись с таким report_path
        checkQuery = sprintf('SELECT id FROM analysis_results WHERE report_path = ''%s'' LIMIT 1', ...
            escapeSql(reportPath));
        existingRecord = sqlFetchWithConn(conn, checkQuery);
        
        if ~isempty(existingRecord)
            debugState('logAnalysisResult', 'Analysis result already exists for report_path=%s. Skipping insert.', reportPath);
            closeJdbcResource(conn);
            return
        end
        
        analysisTs = round(posixtime(datetime('now'))*1000);
        query = sprintf(['INSERT INTO analysis_results (file_id, module_name, module_display_name, module_description, ' ...
            'analysis_timestamp, report_path, parameters_json, created_at) VALUES (%d, ''%s'', ''%s'', ''%s'', %d, ''%s'', ''%s'', CURRENT_TIMESTAMP)'], ...
            fileId, escapeSql(moduleName), escapeSql(moduleDisplay), escapeSql(moduleDesc), analysisTs, escapeSql(reportPath), escapeSql(paramsJson));
        sqlExecWithConn(conn, query);
    catch ME
        warning('logAnalysisResult: Failed to log analysis result: %s', ME.message);
    end
    closeJdbcResource(conn);
end

