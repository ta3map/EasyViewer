function fileManagerGUI()
    
    
    
    % Идентификатор (tag) для GUI фигуры
    figTag = 'fileManagerGUI';
    
    % Поиск открытой фигуры с заданным идентификатором
    guiFig = findobj('Type', 'figure', 'Tag', figTag);
    
    if ~isempty(guiFig)
        % Делаем существующее окно текущим (активным)
        figure(guiFig);
        return
    else    
        persistent choice data listpath
        choice = 1;       
        
        % Главное окно интерфейса
        fig = figure('Position', [100, 100, 600, 400],...
            'Name', 'File Manager', ...
            'NumberTitle', 'off',...
            'MenuBar', 'none', ... % Отключение стандартного меню
            'ToolBar', 'none', ...
            'Tag', figTag);

        % Кнопки
        uicontrol('Style', 'pushbutton', 'Position', [10, 350, 100, 25], 'String', 'Load list', 'Callback', @loadList);
        uicontrol('Style', 'pushbutton', 'Position', [120, 350, 100, 25], 'String', 'Save list', 'Callback', @saveList);
        uicontrol('Style', 'pushbutton', 'Position', [230, 350, 100, 25], 'String', 'Open file', 'Callback', @openFile);
        uicontrol('Style', 'pushbutton', 'Position', [340, 350, 100, 25], 'String', 'Delete file', 'Callback', @deleteFile);
        uicontrol('Style', 'pushbutton', 'Position', [450, 350, 100, 25], 'String', 'Add file', 'Callback', @addFile);
        

        % Таблица для отображения списка файлов
        t = uitable('Position', [10, 10, 580, 330],...
            'ColumnWidth', {555}, 'ColumnName', {'file_path'});
    end

    % Callback функции
    function loadList(~,~)
        [file, listpath] = uigetfile({'*.xlsx';'*.xls'}, 'Select the Excel file');
        if file ~= 0
            try
                data = readtable(fullfile(listpath,file), 'Format', 'auto');
                choice = listdlg('PromptString', 'Select the file path column:', ...
                                 'SelectionMode', 'single', ...
                                 'ListString', data.Properties.VariableNames);
                if ~isempty(choice)
                    t.Data = table2cell(data(:, :));
                    cellArray = repmat({'auto'}, 1, size(data, 2));
                    t.ColumnWidth = cellArray;
                    t.ColumnWidth(choice) = {500};
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
                end
            catch
                errordlg('Failed to load file.', 'Error');
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
                global event_calling outside_calling_filepath zav_calling

                file2open = t.Data{t.UserData, choice};
                
                disp(file2open)
                
                % в случае если у нас просто имена файлов, путь к протоколу
                % будет использоваться для поиска
                [~,~,ext] = fileparts(file2open);
                if isempty(ext)
                    ext = '.ev';                    
                    file2open = searchFile(listpath, [file2open, ext]);   
                    disp(file2open)
                end    
                
                outside_calling_filepath = file2open;
                switch ext                    
                    case '.ev'
                        event_calling(); 
                    case '.mat'
                        zav_calling();
                end
            catch
                errordlg('Failed to open file.', 'Error');
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
            newRow{choice} = fullfile(path, file);
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
