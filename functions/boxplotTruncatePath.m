function pathStr = boxplotTruncatePath(fullPath)
    % boxplotTruncatePath - Усечение длинного пути к файлу
    % Если путь длиннее 50 символов, показывает только имя файла с префиксом "..."
    
    if length(fullPath) > 50
        [~, name, ext] = fileparts(fullPath);
        pathStr = ['...' filesep name ext];
    else
        pathStr = fullPath;
    end
end

