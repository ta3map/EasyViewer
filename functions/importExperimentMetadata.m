function importExperimentMetadata(jsonFilePath)
    dbPath = getDbPath();
    if isempty(dbPath) || ~isfile(dbPath)
        warning('Database not found: %s', dbPath);
        return
    end
    
    if ~isfile(jsonFilePath)
        warning('JSON file not found: %s', jsonFilePath);
        return
    end
    
    try
        jsonText = fileread(jsonFilePath);
        data = jsondecode(jsonText);
    catch ME
        warning('Failed to read JSON file: %s', ME.message);
        return
    end
    
    conn = openSqliteConnection(dbPath);
    if isempty(conn)
        return
    end
    
    try
        projectId = createOrFindProject(conn, data);
        if isempty(projectId)
            closeJdbcResource(conn);
            return
        end
        
        groupId = createOrFindGroup(conn, projectId, data);
        if isempty(groupId)
            closeJdbcResource(conn);
            return
        end
        
        importCommonMetadata(conn, groupId, data);
        
        importFileTables(conn, projectId, groupId, data);
        
    catch ME
        warning('Import failed: %s', ME.message);
    end
    
    closeJdbcResource(conn);
end

function projectId = createOrFindProject(conn, data)
    projectId = [];
    
    if ~isfield(data, 'CommonTable') || ~isfield(data.CommonTable, 'ProjectName')
        return
    end
    
    projectName = data.CommonTable.ProjectName;
    if isempty(projectName)
        return
    end
    
    query = sprintf('SELECT id FROM projects WHERE name = ''%s'' LIMIT 1', escapeSql(projectName));
    record = sqlFetchWithConn(conn, query);
    
    if ~isempty(record)
        projectId = record{1};
    else
        query = sprintf('INSERT INTO projects (name, created_at, updated_at) VALUES (''%s'', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)', ...
            escapeSql(projectName));
        sqlExecWithConn(conn, query);
        record = sqlFetchWithConn(conn, sprintf('SELECT id FROM projects WHERE name = ''%s'' LIMIT 1', escapeSql(projectName)));
        if ~isempty(record)
            projectId = record{1};
        end
    end
end

function groupId = createOrFindGroup(conn, projectId, data)
    groupId = [];
    
    if ~isfield(data, 'ExperimentID')
        return
    end
    
    groupName = data.ExperimentID;
    if isempty(groupName)
        return
    end
    
    query = sprintf('SELECT id FROM groups WHERE project_id = %d AND name = ''%s'' LIMIT 1', projectId, escapeSql(groupName));
    record = sqlFetchWithConn(conn, query);
    
    if ~isempty(record)
        groupId = record{1};
    else
        query = sprintf('INSERT INTO groups (project_id, name, created_at) VALUES (%d, ''%s'', CURRENT_TIMESTAMP)', ...
            projectId, escapeSql(groupName));
        sqlExecWithConn(conn, query);
        record = sqlFetchWithConn(conn, sprintf('SELECT id FROM groups WHERE project_id = %d AND name = ''%s'' LIMIT 1', projectId, escapeSql(groupName)));
        if ~isempty(record)
            groupId = record{1};
        end
    end
end

function importCommonMetadata(conn, groupId, data)
    if ~isfield(data, 'CommonTable')
        return
    end
    
    commonTable = data.CommonTable;
    fields = fieldnames(commonTable);
    
    for i = 1:length(fields)
        fieldName = fields{i};
        fieldValue = commonTable.(fieldName);
        
        if ischar(fieldValue) || isstring(fieldValue)
            valueStr = char(fieldValue);
        elseif isnumeric(fieldValue) || islogical(fieldValue)
            valueStr = num2str(fieldValue);
        else
            valueStr = jsonencode(fieldValue);
        end
        
        metadataFieldName = ['common_', fieldName];
        
        query = sprintf(['INSERT OR REPLACE INTO group_metadata (group_id, field_name, field_value, updated_at) ' ...
            'VALUES (%d, ''%s'', ''%s'', CURRENT_TIMESTAMP)'], ...
            groupId, escapeSql(metadataFieldName), escapeSql(valueStr));
        sqlExecWithConn(conn, query);
    end
end

function importFileTables(conn, projectId, groupId, data)
    fields = fieldnames(data);
    
    for i = 1:length(fields)
        fieldName = fields{i};
        
        if strcmp(fieldName, 'CommonTable') || strcmp(fieldName, 'ExperimentID')
            continue
        end
        
        fieldValue = data.(fieldName);
        
        if iscell(fieldValue) || (isstruct(fieldValue) && length(fieldValue) > 1)
            if iscell(fieldValue)
                tableArray = fieldValue;
            else
                tableArray = num2cell(fieldValue);
            end
            
            tablePrefix = [lower(fieldName), '_'];
            
            for j = 1:length(tableArray)
                record = tableArray{j};
                if isstruct(record) && isfield(record, 'FilePath')
                    importFileRecord(conn, projectId, groupId, record, tablePrefix);
                end
            end
        end
    end
end

function importFileRecord(conn, projectId, groupId, record, tablePrefix)
    filePath = record.FilePath;
    if isempty(filePath)
        return
    end
    
    fileId = findOrCreateFile(conn, filePath);
    if isempty(fileId)
        return
    end
    
    linkFileToProject(conn, projectId, fileId, groupId);
    
    importFileMetadata(conn, fileId, record, tablePrefix);
end

function fileId = findOrCreateFile(conn, filePath)
    fileId = [];
    
    query = sprintf('SELECT id FROM files WHERE file_path = ''%s'' LIMIT 1', escapeSql(filePath));
    record = sqlFetchWithConn(conn, query);
    
    if ~isempty(record)
        fileId = record{1};
    else
        [~, name, ext] = fileparts(filePath);
        fileName = [name, ext];
        if isempty(fileName)
            fileName = filePath;
        end
        
        query = sprintf('INSERT INTO files (file_path, file_name, created_at) VALUES (''%s'', ''%s'', CURRENT_TIMESTAMP)', ...
            escapeSql(filePath), escapeSql(fileName));
        sqlExecWithConn(conn, query);
        
        record = sqlFetchWithConn(conn, sprintf('SELECT id FROM files WHERE file_path = ''%s'' LIMIT 1', escapeSql(filePath)));
        if ~isempty(record)
            fileId = record{1};
        end
    end
end

function linkFileToProject(conn, projectId, fileId, groupId)
    query = sprintf('SELECT project_id FROM project_files WHERE project_id = %d AND file_id = %d LIMIT 1', projectId, fileId);
    record = sqlFetchWithConn(conn, query);
    
    if isempty(record)
        query = sprintf('INSERT INTO project_files (project_id, file_id, group_id, created_at) VALUES (%d, %d, %d, CURRENT_TIMESTAMP)', ...
            projectId, fileId, groupId);
        sqlExecWithConn(conn, query);
    else
        query = sprintf('UPDATE project_files SET group_id = %d WHERE project_id = %d AND file_id = %d', ...
            groupId, projectId, fileId);
        sqlExecWithConn(conn, query);
    end
end

function importFileMetadata(conn, fileId, record, tablePrefix)
    fields = fieldnames(record);
    
    for i = 1:length(fields)
        fieldName = fields{i};
        
        if strcmp(fieldName, 'FilePath')
            continue
        end
        
        fieldValue = record.(fieldName);
        metadataFieldName = [tablePrefix, fieldName];
        
        if ischar(fieldValue) || isstring(fieldValue)
            valueStr = char(fieldValue);
            
            if strncmp(valueStr, '[', 1) || strncmp(valueStr, '{', 1)
                try
                    parsed = jsondecode(valueStr);
                    importNestedMetadata(conn, fileId, metadataFieldName, parsed);
                    continue
                catch
                end
            end
        elseif isnumeric(fieldValue) || islogical(fieldValue)
            valueStr = num2str(fieldValue);
        else
            valueStr = jsonencode(fieldValue);
        end
        
        query = sprintf(['INSERT OR REPLACE INTO file_metadata (file_id, field_name, field_value, updated_at) ' ...
            'VALUES (%d, ''%s'', ''%s'', CURRENT_TIMESTAMP)'], ...
            fileId, escapeSql(metadataFieldName), escapeSql(valueStr));
        sqlExecWithConn(conn, query);
    end
end

function importNestedMetadata(conn, fileId, baseFieldName, nestedData)
    if isstruct(nestedData)
        fields = fieldnames(nestedData);
        for i = 1:length(fields)
            fieldName = fields{i};
            fieldValue = nestedData.(fieldName);
            
            if ischar(fieldValue) || isstring(fieldValue)
                valueStr = char(fieldValue);
            elseif isnumeric(fieldValue) || islogical(fieldValue)
                valueStr = num2str(fieldValue);
            else
                valueStr = jsonencode(fieldValue);
            end
            
            metadataFieldName = [baseFieldName, '_', fieldName];
            query = sprintf(['INSERT OR REPLACE INTO file_metadata (file_id, field_name, field_value, updated_at) ' ...
                'VALUES (%d, ''%s'', ''%s'', CURRENT_TIMESTAMP)'], ...
                fileId, escapeSql(metadataFieldName), escapeSql(valueStr));
            sqlExecWithConn(conn, query);
        end
    elseif iscell(nestedData)
        for i = 1:length(nestedData)
            item = nestedData{i};
            if isstruct(item)
                indexStr = num2str(i);
                importNestedMetadata(conn, fileId, [baseFieldName, '_', indexStr], item);
            end
        end
    end
end

