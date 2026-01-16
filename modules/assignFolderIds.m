function fileTable = assignFolderIds(fileTable)
    if isempty(fileTable) || width(fileTable) < 3
        return
    end
    
    paths = fileTable.Path;
    folders = cellfun(@(p) fileparts(p), paths, 'UniformOutput', false);
    
    [~, ~, folderIdx] = unique(folders);
    fileTable.folder_id = folderIdx;
end
