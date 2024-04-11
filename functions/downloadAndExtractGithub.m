function outputPath = downloadAndExtractGithub(target_folder)
    outputPath = ''; % Инициализация пустого пути на случай ошибки
    try
        % Определение пути к папке, где находится функция
        appPath = fileparts(mfilename('fullpath'));
        
        % Путь, куда будет распакован архив
        tempFolderPath = fullfile(appPath, 'tempEasyViewer');
        
        % Путь для сохранения распакованной папки target_folder
        iconsFolderPath = appPath;
        
        % URL архива репозитория
        url = 'https://github.com/ta3map/EasyViewer/archive/refs/heads/main.zip';
        
        % Путь для временного сохранения архива
        tempZipFilePath = fullfile(appPath, 'EasyViewer-main.zip');
        
        % Скачивание архива репозитория
        websave(tempZipFilePath, url);
        
        % Распаковка архива
        unzip(tempZipFilePath, tempFolderPath);
        
        % Перемещение нужной папки target_folder в целевую директорию
        movefile(fullfile(tempFolderPath, 'EasyViewer-main', target_folder), iconsFolderPath);
        
        % Удаление временных файлов и папок
        delete(tempZipFilePath);
        rmdir(tempFolderPath, 's');
        
        % Возврат пути к папке target_folder
        outputPath = fullfile(appPath, target_folder);
        
        disp('data downloaded from github')
    catch
        % В случае ошибки, outputPath останется пустым
    end
end
