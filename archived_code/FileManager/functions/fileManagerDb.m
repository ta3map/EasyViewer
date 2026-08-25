function varargout = fileManagerDb(operation, varargin)
    switch operation
        case 'fetchProjects'
            varargout{1} = fetchProjects();
        case 'insertProject'
            varargout{1} = insertProject(varargin{1});
        case 'insertProjectWithConn'
            varargout{1} = insertProjectWithConn(varargin{1}, varargin{2});
        case 'fetchProjectFilesWithConn'
            varargout{1} = fetchProjectFilesWithConn(varargin{1}, varargin{2});
        case 'fetchProjectFilesWithMetadata'
            [varargout{1}, varargout{2}] = fetchProjectFilesWithMetadata(varargin{1}, varargin{2});
        case 'ensureFileInProject'
            ensureFileInProject(varargin{1}, varargin{2});
        case 'unlinkFileFromProject'
            unlinkFileFromProject(varargin{1}, varargin{2});
        case 'saveFileMetadata'
            saveFileMetadata(varargin{1}, varargin{2}, varargin{3});
        case 'makeSafeFieldName'
            varargout{1} = makeSafeFieldName(varargin{1});
        case 'getOriginalFieldName'
            varargout{1} = getOriginalFieldName(varargin{1}, varargin{2});
        case 'processMetadataRows'
            varargout{1} = processMetadataRows(varargin{1});
        otherwise
            error('Unknown operation: %s', operation);
    end
end

function projects = fetchProjects()
    rows = sqlFetch('SELECT id, name FROM projects ORDER BY created_at DESC');
    if isempty(rows)
        projects = [];
        return
    end
    count = size(rows, 1);
    projects = repmat(struct('id', 0, 'name', ''), count, 1);
    for i = 1:count
        projects(i).id = rows{i, 1};
        projects(i).name = rows{i, 2};
    end
end

function projectId = insertProject(projectName)
    projectId = [];
    if isempty(projectName)
        return
    end
    escapedName = escapeSql(projectName);
    query = sprintf('INSERT INTO projects (name, created_at) VALUES (''%s'', CURRENT_TIMESTAMP)', escapedName);
    sqlExec(query);
    result = sqlFetch(sprintf('SELECT id FROM projects WHERE name = ''%s'' ORDER BY created_at DESC LIMIT 1', escapedName));
    if ~isempty(result)
        projectId = result{1};
    end
end

function projectId = insertProjectWithConn(conn, projectName)
    projectId = [];
    if isempty(projectName) || isempty(conn)
        return
    end
    escapedName = escapeSql(projectName);
    query = sprintf('INSERT INTO projects (name, created_at) VALUES (''%s'', CURRENT_TIMESTAMP)', escapedName);
    sqlExecWithConn(conn, query);
    result = sqlFetchWithConn(conn, sprintf('SELECT id FROM projects WHERE name = ''%s'' ORDER BY created_at DESC LIMIT 1', escapedName));
    if ~isempty(result)
        projectId = result{1, 1};
    end
end

function files = fetchProjectFilesWithConn(conn, projectId)
    query = sprintf(['SELECT f.id, f.file_name, f.file_path, pf.group_id ' ...
        'FROM project_files pf ' ...
        'JOIN files f ON f.id = pf.file_id ' ...
        'WHERE pf.project_id = %d ORDER BY f.created_at DESC'], projectId);
    rows = sqlFetchWithConn(conn, query);
    if isempty(rows)
        files = [];
        return
    end
    count = size(rows, 1);
    files = repmat(struct('id', 0, 'name', '', 'path', '', 'group_id', []), count, 1);
    for i = 1:count
        files(i).id = rows{i, 1};
        files(i).name = rows{i, 2};
        files(i).path = rows{i, 3};
        files(i).group_id = rows{i, 4};
    end
end

function [files, metadataRows] = fetchProjectFilesWithMetadata(conn, projectId)
    filesQuery = sprintf(['SELECT f.id, f.file_name, f.file_path, pf.group_id ' ...
        'FROM project_files pf ' ...
        'JOIN files f ON f.id = pf.file_id ' ...
        'WHERE pf.project_id = %d ORDER BY f.created_at DESC'], projectId);
    filesRows = sqlFetchWithConn(conn, filesQuery);
    
    if isempty(filesRows)
        files = [];
        metadataRows = {};
        return
    end
    
    count = size(filesRows, 1);
    files = repmat(struct('id', 0, 'name', '', 'path', '', 'group_id', []), count, 1);
    fileIds = zeros(count, 1);
    
    for i = 1:count
        files(i).id = filesRows{i, 1};
        files(i).name = filesRows{i, 2};
        files(i).path = filesRows{i, 3};
        files(i).group_id = filesRows{i, 4};
        fileIds(i) = filesRows{i, 1};
    end
    
    if isempty(fileIds)
        metadataRows = {};
        return
    end
    
    idsStr = sprintf('%d,', fileIds);
    idsStr = idsStr(1:end-1);
    metadataQuery = sprintf(['SELECT file_id, field_name, field_value ' ...
        'FROM file_metadata ' ...
        'WHERE file_id IN (%s)'], idsStr);
    metadataRows = sqlFetchWithConn(conn, metadataQuery);
    
    if isempty(metadataRows)
        metadataRows = {};
    end
end

function ensureFileInProject(filePath, projectId)
    filePath = char(filePath);
    record = sqlFetch(sprintf('SELECT id FROM files WHERE file_path = ''%s'' LIMIT 1', escapeSql(filePath)));
    if isempty(record)
        [~, name, ext] = fileparts(filePath);
        fileName = [name, ext];
        insertFile = sprintf('INSERT INTO files (file_path, file_name, created_at) VALUES (''%s'', ''%s'', CURRENT_TIMESTAMP)', ...
            escapeSql(filePath), escapeSql(fileName));
        sqlExec(insertFile);
        record = sqlFetch(sprintf('SELECT id FROM files WHERE file_path = ''%s'' LIMIT 1', escapeSql(filePath)));
    end
    fileId = record{1};
    existsLink = sqlFetch(sprintf('SELECT 1 FROM project_files WHERE project_id = %d AND file_id = %d LIMIT 1', projectId, fileId));
    if ~isempty(existsLink)
        return
    end
    insertLink = sprintf('INSERT INTO project_files (project_id, file_id, created_at) VALUES (%d, %d, CURRENT_TIMESTAMP)', ...
        projectId, fileId);
    sqlExec(insertLink);
end

function unlinkFileFromProject(fileId, projectId)
    if isempty(fileId) || isempty(projectId)
        return
    end
    deleteLink = sprintf('DELETE FROM project_files WHERE project_id = %d AND file_id = %d', projectId, fileId);
    sqlExec(deleteLink);
    usageCount = sqlFetch(sprintf('SELECT COUNT(*) FROM project_files WHERE file_id = %d', fileId));
    if isempty(usageCount)
        return
    end
    countValue = usageCount{1};
    if countValue > 0
        return
    end
    sqlExec(sprintf('DELETE FROM files WHERE id = %d', fileId));
end

function safeName = makeSafeFieldName(originalName)
    if isempty(originalName)
        safeName = 'field';
        return
    end
    
    safeName = originalName;
    safeName = regexprep(safeName, '[^a-zA-Z0-9_]', '_');
    
    if ~isempty(safeName) && ~isletter(safeName(1))
        safeName = ['f_', safeName];
    end
    
    if isempty(safeName)
        safeName = 'field';
    end
end

function originalName = getOriginalFieldName(safeFieldName, stateVar)
    if ~isfield(stateVar, 'fieldNameMap') || ~isfield(stateVar.fieldNameMap, safeFieldName)
        originalName = safeFieldName;
        return
    end
    originalName = stateVar.fieldNameMap.(safeFieldName);
end

function saveFileMetadata(fileId, fieldName, fieldValue)
    if isempty(fileId) || isempty(fieldName)
        return
    end
    if isempty(fieldValue)
        fieldValue = '';
    end
    
    escapedFieldName = escapeSql(fieldName);
    escapedFieldValue = escapeSql(fieldValue);
    
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

function metadataState = processMetadataRows(metadataRows)
    if isempty(metadataRows)
        metadataState.metadataFields = {};
        metadataState.metadataData = struct();
        metadataState.fieldNameMap = struct();
        return
    end
    
    numRows = size(metadataRows, 1);
    
    fileIds = cell(numRows, 1);
    fieldNames = cell(numRows, 1);
    fieldValues = cell(numRows, 1);
    
    for i = 1:numRows
        fileIds{i} = metadataRows{i, 1};
        fieldNames{i} = metadataRows{i, 2};
        fieldValue = metadataRows{i, 3};
        if isempty(fieldValue)
            fieldValue = '';
        end
        fieldValues{i} = fieldValue;
    end
    
    allFields = unique(fieldNames);
    numFields = numel(allFields);
    
    fieldNameMap = struct();
    for i = 1:numFields
        originalFieldName = allFields{i};
        safeFieldName = makeSafeFieldName(originalFieldName);
        fieldNameMap.(safeFieldName) = originalFieldName;
    end
    
    uniqueFileIds = unique([fileIds{:}]);
    numUniqueFiles = numel(uniqueFileIds);
    
    metadataMap = struct();
    for i = 1:numUniqueFiles
        fileId = uniqueFileIds(i);
        fileIdStr = sprintf('f%d', fileId);
        metadataMap.(fileIdStr) = struct();
    end
    
    for i = 1:numRows
        fileId = fileIds{i};
        originalFieldName = fieldNames{i};
        fieldValue = fieldValues{i};
        
        safeFieldName = makeSafeFieldName(originalFieldName);
        fileIdStr = sprintf('f%d', fileId);
        
        metadataMap.(fileIdStr).(safeFieldName) = fieldValue;
    end
    
    metadataState.metadataFields = allFields;
    metadataState.metadataData = metadataMap;
    metadataState.fieldNameMap = fieldNameMap;
end
