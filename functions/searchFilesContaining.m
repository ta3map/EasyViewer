function fileList = searchFilesContaining(folder, fileName)
    fileList = {};
    filesAndFolders = dir(folder); % Получить список файлов и папок
    files = filesAndFolders(~[filesAndFolders.isdir]); % Отфильтровать только файлы
    folders = filesAndFolders([filesAndFolders.isdir] & ~ismember({filesAndFolders.name}, {'.', '..'})); % Отфильтровать подпапки

    % Поиск файлов, содержащих fileName в текущей папке
    for k = 1:length(files)
        if contains(files(k).name, fileName)
            fileList{end+1} = fullfile(folder, files(k).name); % Добавление файла в список
        end
    end

    % Рекурсивный поиск в подпапках
    for k = 1:length(folders)
        subFolderList = searchFilesContaining(fullfile(folder, folders(k).name), fileName); % Рекурсивный вызов для подпапки
        fileList = [fileList, subFolderList]; % Объединение результатов поиска
    end
end
