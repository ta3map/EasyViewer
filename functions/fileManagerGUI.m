function fileManagerGUI()
    global SettingsFilepath ME

    % Идентификатор (tag) для GUI фигуры
    figTag = 'fileManagerGUI';
    
    % Поиск открытой фигуры с заданным идентификатором
    guiFig = findobj('Type', 'figure', 'Tag', figTag);
    
    if ~isempty(guiFig)
        % Делаем существующее окно текущим (активным)
        figure(guiFig);
        return
    else    
        persistent file_manager_list_choise data listpath
             
        file_manager_list_choise = 1;  
        
    
        % Главное окно интерфейса
        fig = figure('Position', [100, 100, 600, 385],...
            'Name', 'File Manager', ...
            'NumberTitle', 'off',...
            'MenuBar', 'none', ... % Отключение стандартного меню
            'ToolBar', 'none', ...
            'Resize', 'off',...
            'Tag', figTag);

        % Кнопки
        uicontrol('Style', 'pushbutton', 'Position', [10, 350, 100, 25], 'String', 'Load list', 'Callback', @loadList);
%         uicontrol('Style', 'pushbutton', 'Position', [120, 380, 100, 25], 'String', 'Save list', 'Callback', @saveList);
        uicontrol('Style', 'pushbutton', 'Position', [230, 350, 100, 25], 'String', 'Open file', 'Callback', @openFile);
%         uicontrol('Style', 'pushbutton', 'Position', [480, 380, 100, 25], 'String', 'Delete file', 'Callback', @deleteFile);
%         uicontrol('Style', 'pushbutton', 'Position', [480, 350, 100, 25], 'String', 'Add file', 'Callback', @addFile);
        

        % Таблица для отображения списка файлов
        t = uitable('Position', [10, 10, 580, 330],...
            'ColumnWidth', {555}, 'ColumnName', {'file_path'});

        % Переменная для отслеживания времени последнего клика
        t.UserData.lastClickTime = now;

        % Установка callback на выбор ячейки
        t.CellSelectionCallback = @cellSelectionCallback;
    
        % Заполняем таблицу из предыдущего списка
        try
            d = load(SettingsFilepath);
            if isfield(d, 'file_manager_list_filepath')
                file_manager_list_filepath = d.file_manager_list_filepath;
                file_manager_list_choise = d.file_manager_list_choise;    
                data = readtable(file_manager_list_filepath, 'Format', 'auto');
                t.Data = table2cell(data(:, :));
                cellArray = repmat({'auto'}, 1, size(data, 2));
                t.ColumnWidth = cellArray;
                t.ColumnWidth(file_manager_list_choise) = {500};
                t.ColumnName = data.Properties.VariableNames;
                t.ColumnEditable = repmat([true], 1, size(data, 2));
                
                % добавляем пустую колонку для верной нумерации
                % Количество колонок в таблице
                numColumns = width(t.Data);
                % Создаем строку с NaN для всех колонок
                newRow = cell(1, numColumns);
                % Добавляем новую строку в данные таблицы
                t.Data = [newRow; t.Data];
                
                % Ставим название в заголовок фигуры
                [listpath,filename,ext] = fileparts(file_manager_list_filepath);
                set(fig, 'Name', ['File Manager: ' filename, ext]);
            end
        catch ME
            errordlg('Failed to load list.', 'Error');
            disp(ME)
        end
    end
    
    function cellSelectionCallback(src, event)
        % Текущее время
        currentTime = now;

        % Проверяем, был ли предыдущий клик менее чем 0.5 секунды назад
        if (currentTime - src.UserData.lastClickTime) * 24 * 60 * 60 < 0.5
            % Двойной клик был обнаружен
            if ~isempty(event.Indices)
                row = event.Indices(1);
                % Ваш код для обработки двойного клика по строке
                disp(['Double clicked row: ', num2str(row)]);
                openFile();
            end
        end

        % Обновляем время последнего клика
        src.UserData.lastClickTime = currentTime;
    end

    % Callback функции
    function loadList(~,~)
        [filename, listpath] = uigetfile({'*.xlsx';'*.xls'}, 'Select the Excel file');
        file_manager_list_filepath = fullfile(listpath,filename);
        if filename ~= 0
            try
                data = readtable(file_manager_list_filepath, 'Format', 'auto');
                file_manager_list_choise = listdlg('PromptString', 'Select the file path column:', ...
                                 'SelectionMode', 'single', ...
                                 'ListString', data.Properties.VariableNames);
                if ~isempty(file_manager_list_choise)
                    t.Data = table2cell(data(:, :));
                    cellArray = repmat({'auto'}, 1, size(data, 2));
                    t.ColumnWidth = cellArray;
                    t.ColumnWidth(file_manager_list_choise) = {500};
                    t.ColumnName = data.Properties.VariableNames;
                    t.ColumnEditable = repmat([true], 1, size(data, 2));   
                    
                    % добавляем пустую колонку для верной нумерации
                    % Количество колонок в таблице
                    numColumns = width(t.Data);
                    % Создаем строку с NaN для всех колонок
                    newRow = cell(1, numColumns);
%                     [newRow{:}] = deal(NaN);
                    % Заменяем элемент в выбранной колонке на путь к файлу
%                     newRow{choice} = fullfile(path, file);
                    % Добавляем новую строку в данные таблицы
                    t.Data = [newRow; t.Data];
                    
                    % Ставим название в заголовок фигуры
                    [~,filename,ext] = fileparts(file_manager_list_filepath);
                    set(fig, 'Name', ['File Manager: ' filename, ext]);
                
                    % Добавляем выбор в файл настроек для следующего раза
                    save(SettingsFilepath, 'file_manager_list_filepath', 'file_manager_list_choise', '-append')
                    
                end
            catch ME
                errordlg('Failed to load file.', 'Error');
                disp(ME)
            end
        end
    end

    function saveList(~,~)
        [file, path] = uiputfile({'*.xlsx'}, 'Save as Excel file');
        if file ~= 0
            try
                T = cell2table(t.Data, 'VariableNames', data.Properties.VariableNames);
                writetable(T, fullfile(path, file));
            catch
                errordlg('Failed to save file.', 'Error');
            end
        end
    end

    function openFile(~,~)
        if size(t.Data,1) > 0 && ~isempty(t.UserData)
            try
                global event_calling outside_calling_filepath 
                global zav_calling wb table_calling events event_inx event_title_string

                file2open = t.Data{t.UserData, file_manager_list_choise};
                
                disp(file2open)
                
                % в случае если у нас просто имена файлов, путь к протоколу
                % будет использоваться для поиска
                [~,~,ext] = fileparts(file2open);
                if isempty(ext)                         
                    ext = '.ev';                    
                    file2open = searchFile(listpath, [file2open, ext]);   
                    disp(file2open)                    
                end    
                
                wb = msgbox('Please wait...', 'Status');   
                outside_calling_filepath = file2open;
                switch ext                    
                    case '.ev'
                        event_calling(); 
                    case '.mat'
                        zav_calling();
                        events = [];
                        event_title_string = 'Events';
                        table_calling()
                        event_inx = 1;                        
                end
                close(wb)
                
            catch ME
                errordlg('Failed to open file.', 'Error');
                disp(ME)
            end
        end
    end
    
    function deleteFile(~,~)
        if size(t.Data,1) > 0 && ~isempty(t.UserData)
            t.Data(t.UserData, :) = [];
        end
    end

    function addFile(~,~)
        [file, path] = uigetfile('*.*', 'Select a file');
        if file ~= 0
            % Количество колонок в таблице
            numColumns = width(t.Data);
            % Создаем строку с NaN для всех колонок
            newRow = cell(1, numColumns);
            [newRow{:}] = deal(NaN);
            % Заменяем элемент в выбранной колонке на путь к файлу
            newRow{file_manager_list_choise} = fullfile(path, file);
            % Добавляем новую строку в данные таблицы
            t.Data = [t.Data; newRow];
        end
    end


    % Установка обработчика для выбора строки в таблице
    t.CellSelectionCallback = @(src,event) setSelectedRow(src, event);
end

function setSelectedRow(src, event)
    if ~isempty(event.Indices)
        src.UserData = event.Indices(1);
    else
        src.UserData = [];
    end
end
