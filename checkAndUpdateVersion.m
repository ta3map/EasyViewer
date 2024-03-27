function [isNewVersionAvailable, newVersion] = checkAndUpdateVersion(currentVersion, saveDirectory)
    % Адрес для проверки номера текущей версии
    versionUrl = 'http://easyviewer.ru/EVinstallers/version.txt';
    
    % Считывание номера версии с сайта
    onlineVersion = webread(versionUrl);
    
    % Проверка, отличается ли онлайн версия от текущей
    if ~strcmp(onlineVersion, currentVersion)
        isNewVersionAvailable = true;
        newVersion = onlineVersion;
        disp(['A new version is available: ', onlineVersion]);
        
        % Составление полного имени файла для скачивания новой версии
        newFilename = fullfile(saveDirectory, ['EasyView ', newVersion, '.exe']);
        
        % Адрес для скачивания новой версии программы
        downloadUrl = 'http://easyviewer.ru/EVinstallers/EVlast.exe';
        
        % Скачивание новой версии
        websave(newFilename, downloadUrl);
    else
        isNewVersionAvailable = false;
        newVersion = currentVersion;
        disp('You have the latest version installed.');
    end
end
