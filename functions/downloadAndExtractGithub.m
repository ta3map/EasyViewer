function outputPath = downloadAndExtractGithub(app_path, target_folder)
    outputPath = ''; % Инициализация пустого пути на случай ошибки
    try        
        % Путь, куда будет распакован архив
        tempFolderPath = fullfile(app_path, 'tempEasyViewer');
        
        % Путь для сохранения распакованной папки target_folder
        iconsFolderPath = app_path;
        
        % URL архива репозитория
        url = 'https://github.com/ta3map/EasyViewer/archive/refs/heads/main.zip';
        
        % Путь для временного сохранения архива
        tempZipFilePath = fullfile(app_path, 'EasyViewer-main.zip');
        
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
        outputPath = fullfile(app_path, target_folder);
        
        disp('data downloaded from github')
    catch ME
        % В случае ошибки, outputPath останется пустым
        disp(ME)
    end
end
