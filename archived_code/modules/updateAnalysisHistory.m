function updateAnalysisHistory(fileId, moduleName)
    if isempty(fileId) || isempty(moduleName)
        return
    end
    
    dbPath = getDbPath();
    if isempty(dbPath) || ~isfile(dbPath)
        return
    end
    
    fieldName = 'Analysis History';
    
    currentValue = sqlFetch(sprintf(['SELECT field_value FROM file_metadata ' ...
        'WHERE file_id = %d AND field_name = ''%s'' LIMIT 1'], ...
        fileId, escapeSql(fieldName)));
    
    timeStr = datestr(now, 'HH:MM');
    dateStr = datestr(now, 'dd.mm.yy');
    newEntry = sprintf('%s %s, %s', moduleName, timeStr, dateStr);
    
    if isempty(currentValue) || isempty(currentValue{1})
        newValue = newEntry;
    else
        existingValue = currentValue{1};
        if isempty(existingValue)
            newValue = newEntry;
        else
            newValue = sprintf('%s; %s', existingValue, newEntry);
        end
    end
    
    escapedFieldName = escapeSql(fieldName);
    escapedFieldValue = escapeSql(newValue);
    
    exists = sqlFetch(sprintf(['SELECT id FROM file_metadata ' ...
        'WHERE file_id = %d AND field_name = ''%s'' LIMIT 1'], fileId, escapedFieldName));
    
    if ~isempty(exists)
        query = sprintf(['UPDATE file_metadata SET field_value = ''%s'', updated_at = CURRENT_TIMESTAMP ' ...
            'WHERE file_id = %d AND field_name = ''%s'''], escapedFieldValue, fileId, escapedFieldName);
    else
        query = sprintf(['INSERT INTO file_metadata (file_id, field_name, field_value, updated_at) ' ...
            'VALUES (%d, ''%s'', ''%s'', CURRENT_TIMESTAMP)'], fileId, escapedFieldName, escapedFieldValue);
    end
    
    sqlExec(query);
end

