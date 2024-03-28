function firstMatFile = findFirstMatFile(folder, fileName)
    fileList = searchFilesContaining(folder, fileName); % Получение списка файлов
    matFiles = {}; % Инициализация списка .mat файлов
    
    % Поиск .mat файлов
    for k = 1:length(fileList)
        if endsWith(fileList{k}, '.mat')
            matFiles{end+1} = fileList{k}; % Добавление .mat файла в список
        end
    end
    
    % Выбор первого .mat файла из списка, если таковые имеются
    if ~isempty(matFiles)
        firstMatFile = matFiles{1};
    else
        firstMatFile = ''; % Если .mat файлы не найдены
    end
end
