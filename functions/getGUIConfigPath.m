function configPath = getGUIConfigPath(configFileName)
    % getGUIConfigPath - Возвращает полный путь к конфигурационному файлу GUI
    % 
    % Входные параметры:
    %   configFileName - имя конфигурационного файла (например, 'signalViewerGUI_coords.json')
    %                    или относительный путь от configs/window_coords/
    %
    % Выходные параметры:
    %   configPath - полный путь к конфигурационному файлу
    %
    % Пример использования:
    %   coordsFile = getGUIConfigPath('signalViewerGUI_coords.json');
    
    % Пытаемся использовать глобальную переменную EV_path, если она установлена
    global EV_path
    if ~isempty(EV_path) && exist(EV_path, 'dir')
        projectRoot = EV_path;
    else
        % Определяем путь относительно вызывающей функции
        % Получаем стек вызовов
        stack = dbstack('-completenames');
        if length(stack) > 1
            % Берем путь вызывающей функции
            callerFile = stack(2).file;
            callerDir = fileparts(callerFile);
            
            % Определяем корень проекта, поднимаясь вверх по директориям
            % Ищем папку configs в родительских директориях
            searchDir = callerDir;
            projectRoot = [];
            for i = 1:10  % Максимум 10 уровней вверх
                configsPath = fullfile(searchDir, 'configs');
                if exist(configsPath, 'dir')
                    projectRoot = searchDir;
                    break;
                end
                [parentDir, ~] = fileparts(searchDir);
                if isempty(parentDir) || strcmp(parentDir, searchDir)
                    break;
                end
                searchDir = parentDir;
            end
            
            % Если не нашли, используем путь относительно getGUIConfigPath.m
            if isempty(projectRoot)
                currentFile = mfilename('fullpath');
                currentDir = fileparts(currentFile);
                % getGUIConfigPath.m находится в functions/, поднимаемся на 1 уровень
                projectRoot = fileparts(currentDir);
            end
        else
            % Если нет стека вызовов, используем путь относительно getGUIConfigPath.m
            currentFile = mfilename('fullpath');
            currentDir = fileparts(currentFile);
            projectRoot = fileparts(currentDir);
        end
    end
    
    % Формируем путь к конфигурационному файлу
    configPath = fullfile(projectRoot, 'configs', 'window_coords', configFileName);
end

