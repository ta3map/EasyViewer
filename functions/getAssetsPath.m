function assetsPath = getAssetsPath()
    % getAssetsPath - Возвращает полный путь к папке 'assets'
    %
    % Выходные параметры:
    %   assetsPath - полный путь к папке 'assets'
    %
    % Пример использования:
    %   iconPath = fullfile(getAssetsPath(), 'icon.png');
    
    global EV_path
    if ~isempty(EV_path) && exist(EV_path, 'dir')
        projectRoot = EV_path;
    else
        stack = dbstack('-completenames');
        if length(stack) > 1
            callerFile = stack(2).file;
            callerDir = fileparts(callerFile);
            
            searchDir = callerDir;
            projectRoot = [];
            for i = 1:10
                assetsDir = fullfile(searchDir, 'assets');
                if exist(assetsDir, 'dir')
                    projectRoot = searchDir;
                    break;
                end
                [parentDir, ~] = fileparts(searchDir);
                if isempty(parentDir) || strcmp(parentDir, searchDir)
                    break;
                end
                searchDir = parentDir;
            end
            
            if isempty(projectRoot)
                currentFile = mfilename('fullpath');
                currentDir = fileparts(currentFile);
                projectRoot = fileparts(currentDir);
            end
        else
            currentFile = mfilename('fullpath');
            currentDir = fileparts(currentFile);
            projectRoot = fileparts(currentDir);
        end
    end
    assetsPath = fullfile(projectRoot, 'assets');
end

