function showHelp()
    % SHOWHELP Показывает список markdown файлов из папки docs для просмотра
    
    currentFile = mfilename('fullpath');
    appRoot = fileparts(fileparts(currentFile));
    docsPath = fullfile(appRoot, 'docs');
    
    if ~exist(docsPath, 'dir')
        errordlg(['Папка docs не найдена: ' docsPath], 'Ошибка');
        return;
    end
    
    mdFiles = dir(fullfile(docsPath, '*.md'));
    
    if isempty(mdFiles)
        msgbox('В папке docs не найдено markdown файлов.', 'Справка');
        return;
    end
    
    filePaths = cellfun(@(f) fullfile(docsPath, f), {mdFiles.name}, 'UniformOutput', false);
    displayNames = cell(size(filePaths));
    
    for i = 1:length(filePaths)
        title = extractFirstHeading(filePaths{i});
        displayNames{i} = title;
    end
    
    [selection, ok] = listdlg('ListString', displayNames, ...
        'SelectionMode', 'single', ...
        'PromptString', 'Выберите документ для просмотра:', ...
        'Name', 'Справка', ...
        'ListSize', [400, 200]);
    
    if ok && ~isempty(selection)
        showMarkdownHelp(filePaths{selection});
    end
end

function title = extractFirstHeading(mdFile)
    title = '';
    try
        content = fileread(mdFile);
        lines = strsplit(content, {'\r\n', '\n', '\r'}, 'CollapseDelimiters', false);
        
        for i = 1:length(lines)
            line = strtrim(lines{i});
            if ~isempty(line) && line(1) == '#'
                title = regexprep(line, '^#+\s*', '');
                break;
            end
        end
    catch
    end
    
    if isempty(title)
        [~, fileName, ~] = fileparts(mdFile);
        title = fileName;
    end
end
