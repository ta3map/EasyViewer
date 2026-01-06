function newPath = replaceFileExt(pathStr, newExt)
    [folder, name, ~] = fileparts(pathStr);
    newPath = fullfile(folder, [name, newExt]);
end

