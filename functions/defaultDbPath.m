function path = defaultDbPath()
    currentFile = mfilename('fullpath');
    projectRoot = fileparts(fileparts(fileparts(currentFile)));
    path = fullfile(projectRoot, 'database', 'app.db');
end

