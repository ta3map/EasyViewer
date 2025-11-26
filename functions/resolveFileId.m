function fileId = resolveFileId(fileIdOrPath)
    fileId = [];
    
    if isnumeric(fileIdOrPath) && ~isempty(fileIdOrPath)
        fileId = fileIdOrPath;
        return
    end
    
    if ischar(fileIdOrPath) || isstring(fileIdOrPath)
        filePath = char(fileIdOrPath);
        record = sqlFetch(sprintf('SELECT id FROM files WHERE file_path = ''%s'' LIMIT 1', escapeSql(filePath)));
        if ~isempty(record)
            fileId = record{1};
        else
            [~, name, ext] = fileparts(filePath);
            fileName = [name, ext];
            insertFile = sprintf('INSERT INTO files (file_path, file_name, created_at) VALUES (''%s'', ''%s'', CURRENT_TIMESTAMP)', ...
                escapeSql(filePath), escapeSql(fileName));
            sqlExec(insertFile);
            record = sqlFetch(sprintf('SELECT id FROM files WHERE file_path = ''%s'' LIMIT 1', escapeSql(filePath)));
            if ~isempty(record)
                fileId = record{1};
            end
        end
    end
end

