function foundFile = searchFile(folder, fileName)
    foundFile = '';
    filesAndFolders = dir(folder);
    files = filesAndFolders(~[filesAndFolders.isdir]);
    folders = filesAndFolders([filesAndFolders.isdir] & ~ismember({filesAndFolders.name}, {'.', '..'}));

    % Поиск файла в текущей папке
    for k = 1:length(files)
        if strcmp(files(k).name, fileName)
            foundFile = fullfile(folder, files(k).name);
            return;
        end
    end

    % Рекурсивный поиск в подпапках
    for k = 1:length(folders)
        foundFile = searchFile(fullfile(folder, folders(k).name), fileName);
        if ~isempty(foundFile)
            break;
        end
    end
end