function fileTable = assignFileTypeId(fileTable)
    if isempty(fileTable) || width(fileTable) < 3
        return
    end
    
    paths = fileTable.Path;
    extensions = cell(numel(paths), 1);
    for i = 1:numel(paths)
        [~, ~, ext] = fileparts(paths{i});
        extensions{i} = ext;
    end
    
    fileTable.file_extension = extensions;
end
