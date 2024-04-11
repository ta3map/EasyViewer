function outputPath = downloadAndExtractIcons()
    outputPath = ''; % Инициализация пустого пути на случай ошибки
    try
        % Определение пути к папке, где находится функция
        appPath = fileparts(mfilename('fullpath'));
        iconsFolderPath = appPath;
        
        % URL архива
        url = 'http://easyviewer.ru/EVinstallers/icons.zip';
        
        % Путь для временного сохранения архива
        tempZipFilePath = fullfile(appPath, 'icons.zip');
        
        % Скачивание файла
        websave(tempZipFilePath, url);
        
        % Распаковка архива
        unzip(tempZipFilePath, iconsFolderPath);
        
        % Удаление временного ZIP-файла
        delete(tempZipFilePath);
        
        % Возврат пути к папке с иконками
        outputPath = iconsFolderPath;
    catch
        disp('Could not download icons')% В случае ошибки, outputPath останется пустым
    end
end
