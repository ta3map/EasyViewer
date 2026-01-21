function filePaths = addFilesDialogGUI()
    % GUI для выбора файлов: ручной выбор или рекурсивный поиск в папке
    % Возвращает cell array с путями к файлам или пустой массив при отмене
    
    filePaths = {};
    
    % Проверка на существующее окно
    figTag = 'addFilesDialogGUI';
    guiFig = findobj('Type', 'figure', 'Tag', figTag);
    if ~isempty(guiFig)
        figure(guiFig);
        return
    end
    
    % Параметры окна
    dialogWidth = 450;
    dialogHeight = 250;
    screenSize = get(0, 'ScreenSize');
    dialogX = (screenSize(3) - dialogWidth) / 2;
    dialogY = (screenSize(4) - dialogHeight) / 2;
    
    % Создание модального окна
    dialogFig = figure('Position', [dialogX, dialogY, dialogWidth, dialogHeight], ...
        'Name', 'Add Files', ...
        'NumberTitle', 'off', ...
        'MenuBar', 'none', ...
        'ToolBar', 'none', ...
        'Resize', 'off', ...
        'WindowStyle', 'modal', ...
        'Tag', figTag);
    
    % Параметры элементов
    margin = 15;
    buttonHeight = 30;
    buttonWidth = 100;
    labelHeight = 20;
    editHeight = 25;
    spacing = 10;
    radioHeight = 20;
    
    % Переменные для хранения выбора
    selectedMode = 'files'; % 'files' или 'folder'
    selectedExtension = 'all'; % 'all', '.mat', '.ev', '.zav', '.db'
    
    % Позиционирование элементов
    yPos = dialogHeight - margin - labelHeight;
    
    % Заголовок выбора режима
    uicontrol('Parent', dialogFig, 'Style', 'text', ...
        'Position', [margin, yPos, 200, labelHeight], ...
        'String', 'Select mode:', ...
        'HorizontalAlignment', 'left', ...
        'FontSize', 11, ...
        'FontWeight', 'bold');
    
    yPos = yPos - radioHeight - spacing;
    
    % Радио-кнопка: Выбрать файлы
    filesRadio = uicontrol('Parent', dialogFig, 'Style', 'radiobutton', ...
        'Position', [margin + 20, yPos, 150, radioHeight], ...
        'String', 'Select files manually', ...
        'Value', 1, ...
        'FontSize', 11, ...
        'Callback', @(src,evt) setMode('files'));
    
    yPos = yPos - radioHeight - spacing;
    
    % Радио-кнопка: Выбрать папку
    folderRadio = uicontrol('Parent', dialogFig, 'Style', 'radiobutton', ...
        'Position', [margin + 20, yPos, 150, radioHeight], ...
        'String', 'Select folder (recursive)', ...
        'Value', 0, ...
        'FontSize', 11, ...
        'Callback', @(src,evt) setMode('folder'));
    
    yPos = yPos - labelHeight - spacing * 2;
    
    % Заголовок выбора расширения
    uicontrol('Parent', dialogFig, 'Style', 'text', ...
        'Position', [margin, yPos, 200, labelHeight], ...
        'String', 'File extension filter:', ...
        'HorizontalAlignment', 'left', ...
        'FontSize', 11, ...
        'FontWeight', 'bold');
    
    yPos = yPos - editHeight - spacing;
    
    % Выпадающий список расширений
    extensionList = {'All files', '.mat', '.ev', '.zav', '.db', '.txt', '.csv'};
    extensionPopup = uicontrol('Parent', dialogFig, 'Style', 'popupmenu', ...
        'Position', [margin, yPos, dialogWidth - 2*margin, editHeight], ...
        'String', extensionList, ...
        'Value', 1, ...
        'FontSize', 11, ...
        'Callback', @extensionChanged);
    
    yPos = margin;
    
    % Кнопки
    okBtn = uicontrol('Parent', dialogFig, 'Style', 'pushbutton', ...
        'Position', [dialogWidth - 2*buttonWidth - spacing - margin, yPos, buttonWidth, buttonHeight], ...
        'String', 'OK', ...
        'FontSize', 11, ...
        'Callback', @okCallback);
    
    cancelBtn = uicontrol('Parent', dialogFig, 'Style', 'pushbutton', ...
        'Position', [dialogWidth - buttonWidth - margin, yPos, buttonWidth, buttonHeight], ...
        'String', 'Cancel', ...
        'FontSize', 11, ...
        'Callback', @cancelCallback);
    
    % Функция установки режима
    function setMode(mode)
        selectedMode = mode;
        if strcmp(mode, 'files')
            set(filesRadio, 'Value', 1);
            set(folderRadio, 'Value', 0);
        else
            set(filesRadio, 'Value', 0);
            set(folderRadio, 'Value', 1);
        end
    end
    
    % Функция изменения расширения
    function extensionChanged(src, ~)
        idx = get(src, 'Value');
        if idx == 1
            selectedExtension = 'all';
        else
            selectedExtension = extensionList{idx};
        end
    end
    
    % Функция рекурсивного поиска файлов
    function files = findFilesRecursively(folder, extension)
        files = {};
        if ~isfolder(folder)
            return
        end
        
        if strcmp(extension, 'all')
            pattern = '*';
        else
            pattern = ['*', extension];
        end
        
        try
            fileList = dir(fullfile(folder, '**', pattern));
            for i = 1:numel(fileList)
                if ~fileList(i).isdir
                    files{end+1} = fullfile(fileList(i).folder, fileList(i).name);
                end
            end
        catch ME
            warning('Error during recursive search: %s', ME.message);
        end
    end
    
    % Обработчик OK
    function okCallback(~, ~)
        extensionIdx = get(extensionPopup, 'Value');
        if extensionIdx == 1
            selectedExtension = 'all';
        else
            selectedExtension = extensionList{extensionIdx};
        end
        
        if strcmp(selectedMode, 'files')
            % Режим выбора файлов вручную
            if strcmp(selectedExtension, 'all')
                filter = {'*.*', 'All files'};
            else
                filter = {['*', selectedExtension], ['*', selectedExtension]};
            end
            
            [fileNames, basePath] = uigetfile(filter, 'Select files', 'MultiSelect', 'on');
            if isequal(fileNames, 0)
                return
            end
            
            if ischar(fileNames)
                fileNames = {fileNames};
            end
            
            for k = 1:numel(fileNames)
                fullPath = fullfile(basePath, fileNames{k});
                if exist(fullPath, 'file')
                    filePaths{end+1} = fullPath;
                end
            end
        else
            % Режим выбора папки с рекурсивным поиском
            folderPath = uigetdir(pwd, 'Select folder');
            if isequal(folderPath, 0)
                return
            end
            
            if ~isfolder(folderPath)
                msgbox('Selected path is not a folder', 'Error', 'error');
                return
            end
            
            filePaths = findFilesRecursively(folderPath, selectedExtension);
            
            if isempty(filePaths)
                msgbox(sprintf('No files found with extension "%s" in the selected folder', selectedExtension), 'Info', 'help');
                return
            end
        end
        
        close(dialogFig);
    end
    
    % Обработчик Cancel
    function cancelCallback(~, ~)
        filePaths = {};
        close(dialogFig);
    end
    
    % Ожидание закрытия окна
    uiwait(dialogFig);
end
