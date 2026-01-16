function saveFileMetadataBatch(fileIds, fieldName, fieldValues)
    if isempty(fileIds) || isempty(fieldName) || isempty(fieldValues)
        return
    end
    
    if numel(fileIds) ~= numel(fieldValues)
        warning('saveFileMetadataBatch: fileIds and fieldValues must have the same length');
        return
    end
    
    escapedFieldName = escapeSql(fieldName);
    
    fieldValueStrs = cell(numel(fieldValues), 1);
    for i = 1:numel(fieldValues)
        fieldValue = fieldValues{i};
        
        if isempty(fieldValue)
            fieldValueStrs{i} = '';
        elseif iscell(fieldValue)
            if isempty(fieldValue{1})
                fieldValueStrs{i} = '';
            elseif isnumeric(fieldValue{1})
                fieldValueStrs{i} = num2str(fieldValue{1});
            else
                fieldValueStrs{i} = char(fieldValue{1});
            end
        elseif isnumeric(fieldValue)
            fieldValueStrs{i} = num2str(fieldValue);
        elseif islogical(fieldValue)
            if fieldValue
                fieldValueStrs{i} = 'true';
            else
                fieldValueStrs{i} = 'false';
            end
        else
            fieldValueStrs{i} = char(fieldValue);
        end
    end
    
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
        sqlExecWithConn(conn, 'CREATE TEMP TABLE IF NOT EXISTS temp_file_metadata_batch (file_id INTEGER, field_name TEXT, field_value TEXT)');
        
        valuesParts = cell(numel(fileIds), 1);
        for i = 1:numel(fileIds)
            escapedFieldValue = escapeSql(fieldValueStrs{i});
            valuesParts{i} = sprintf('(%d, ''%s'', ''%s'')', fileIds(i), escapedFieldName, escapedFieldValue);
        end
        
        valuesStr = strjoin(valuesParts, ', ');
        sqlExecWithConn(conn, ['INSERT INTO temp_file_metadata_batch (file_id, field_name, field_value) VALUES ' valuesStr]);
        
        sqlExecWithConn(conn, ['INSERT OR REPLACE INTO file_metadata (file_id, field_name, field_value, updated_at) ' ...
            'SELECT file_id, field_name, field_value, CURRENT_TIMESTAMP FROM temp_file_metadata_batch']);
        
        sqlExecWithConn(conn, 'DROP TABLE temp_file_metadata_batch');
    catch ME
        warning('SQL exec error in saveFileMetadataBatch: %s', ME.message);
    end
    
    closeJdbcResource(conn);
end
