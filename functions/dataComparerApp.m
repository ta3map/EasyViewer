function dataComparerApp()
    % Глобальные переменные для хранения данных
    global data1 data2 mergeSettings mergedData
    global mergeFig comparerFig mergeTableData
    global saveResultButton saveFigureButton d1filename
    global SettingsFilepath
    
    persistent initialDir
    
    disp('Data Comparer started')
    
    % Основное окно GUI
    comparerFig = figure('Name', 'Data Comparer', 'NumberTitle', 'off', ...
    	'MenuBar', 'none', ... % Отключение стандартного меню
    	'ToolBar', 'none',...
        'Resize', 'off',...
    	'Position', [10 45 466 584]);

    % Два сабплота
    axes1 = axes('Position', [0.13    0.55    0.7750    0.34], 'Parent', comparerFig);
    axes2 = axes('Position', [0.13    0.1    0.7750    0.34], 'Parent', comparerFig);

    % Кнопки для загрузки данных
    loadButton1 = uicontrol('Style', 'pushbutton', 'String', 'Load Data 1', ...
                            'Position', [50, 550, 100, 30], 'Callback', @(src, event) loadData(1));
    loadButton2 = uicontrol('Style', 'pushbutton', 'String', 'Load Data 2', ...
                            'Position', [200, 550, 100, 30], 'Callback', @(src, event) loadData(2));

    % Кнопка для объединения данных
    mergeButton = uicontrol('Style', 'pushbutton', 'String', 'Merge Data', ...
                            'Position', [350, 550, 100, 30], 'Callback', @mergeData);

    % Функция для загрузки данных
    function loadData(datasetNumber)
        % Получение пути к последнему открытому файлу или использование стандартной директории
        d = load(SettingsFilepath);
        lastOpenedFiles = d.lastOpenedFiles;
        initialDir = fileparts(lastOpenedFiles{end});
        
        [file, path] = uigetfile('*.mean', 'Select Data File', initialDir);
        if isequal(file, 0) || isequal(path, 0)
            disp('Data loading canceled');
            return;
        end

        loadedData = load(fullfile(path, file),'-mat');
        loadedData.channelEnabled = repmat(false, length(loadedData.ch_labels), 1);    
        loadedData.channelEnabled(loadedData.activeChannels) = true;
        loadedData.file = file;
        
        if datasetNumber == 1
            data1 = loadedData;
            plotData(loadedData, axes1);
        else
            data2 = loadedData;
            plotData(loadedData, axes2);
        end
        
        title([file, ', ' num2str(numel(loadedData.events)), ' events'], 'interpreter', 'none')
        
        if size(file,2)>18
            d1filename = file(1:19);
        else
            d1filename = 'merging';
        end
        
        % Сохраняем информацию о том какой файл открыли
        lastOpenedFiles = {fullfile(path, file)};
        save(SettingsFilepath, 'lastOpenedFiles', '-append');
    end

    % Функция для построения графика
    function plotData(data, axesHandle)

        
        cond = data.channelEnabled;
        
        timeAxis = data.timeAxis;
        meanData = data.meanData.*data.scalingCoefficients;        
        meanData = meanData(:, cond);
        ch_labels = data.ch_labels(cond);
        shiftCoeff = data.shiftCoeff;
        widths_in = data.widths_in(cond);
        colors_in = data.colors_in(cond);
        
        axes(axesHandle)
        cla(axesHandle);
        hold(axesHandle, 'on');
        if isfield(data, 'meanData') && isfield(data, 'timeAxis')
            
            
            offsets = multiplot(timeAxis, meanData, ...
                      'ChannelLabels', ch_labels, ...
                      'shiftCoeff', shiftCoeff, ...
                      'linewidth', widths_in, ...
                      'color', colors_in);
            line_time = 0;
            Lines(line_time, [], 'r', ':');
            xlabel('Time, s')
            ylim([offsets(end)-data.shiftCoeff, offsets(1)+data.shiftCoeff])
        end
    end

    % Функция для слияния данных
    function mergeData(~, ~)
        mergeFig = figure('Name', 'Merge Data', 'NumberTitle', 'off', ...
            'MenuBar', 'none', ... % Отключение стандартного меню
            'ToolBar', 'none',...
            'Resize', 'off', ...
            'Position', [500  135  600  400]);

%         initData()

        % Инициализация таблиц
        initTable(mergeFig, data1, [10, 200, 300, 190], 'Data 1', 1);
        initTable(mergeFig, data2, [10, 10, 300, 190], 'Data 2', 2);

        % Создание таблицы для настроек слияния
        initMergeTable(mergeFig, data1, [350, 50, 230, 335], 'Merge Mode');
        
        titleEdit = uicontrol('Style', 'edit', 'String', d1filename, 'Position', [350, 10, 120, 30]);
        
        % Кнопка "Apply Merging"
        uicontrol('Style', 'pushbutton', 'String', 'Apply Merging', 'Position', [480, 10, 110, 30], 'Callback', @applyMerging);

        % Функция для инициализации таблицы
        function initTable(parentFig, data, position, label, dataNumber)
            tableData = [data.ch_labels, num2cell(data.channelEnabled), num2cell(data.scalingCoefficients'), data.colors_in', num2cell(data.widths_in')];
            uicontrol('Style', 'text', 'String', label, 'Position', [position(1), position(2) + position(4) - 20, 100, 20], 'Parent', parentFig);
            uitable('Data', tableData, ...
                    'ColumnName', {'Channel', 'Enabled', 'Scale', 'Color', 'Line Width'}, ...
                    'ColumnFormat', {'char', 'logical', 'numeric', 'char', 'numeric'}, ...
                    'ColumnEditable', [true true true true true], ...
                    'Position', position, 'Parent', parentFig, ...
                    'CellEditCallback', @(src, event) tableEditCallback(src, event, dataNumber));
        end
        
        % Callback для реакции на изменение данных в таблице
        function tableEditCallback(src, ~, dataNumber)
            if dataNumber == 1
                data1 = updateDataFromTable(src, data1);                
                plotData(data1, axes1);
                n_ev = num2str(numel(data1.events));
                file = data1.file;
            else
                data2 = updateDataFromTable(src, data2);                
                plotData(data2, axes2);
                n_ev = num2str(numel(data2.events));
                file = data2.file;
            end
            title([file ', ' n_ev ' events'], 'interpreter', 'none')
        end

        % Функция инициализации таблицы слияния
        function initMergeTable(parentFig, data, position, label)
            mergeModes = repmat({'sum'}, length(data.ch_labels), 1);
            mergeEnabled = num2cell(data.channelEnabled);
            mergeTableData = [data.ch_labels, mergeModes, mergeEnabled];
            uicontrol('Style', 'text', 'String', label, 'Position', [position(1), position(2) + position(4) - 20, 100, 20], 'Parent', parentFig);
            uitable('Data', mergeTableData, ...
                    'ColumnName', {'Channel', 'Merge Mode', 'Enabled'}, ...
                    'ColumnFormat', {'char', {'sum', 'keep'}, 'logical'}, ...
                    'ColumnEditable', [false true true], ...
                    'Position', position, 'Parent', parentFig, ...
                    'Tag', 'mergeTable');
        end
        
        function initData(~, ~)
            % Инициализация и проверка данных data1
            if isempty(data1) || ~isfield(data1, 'ch_labels')
                data1.ch_labels = {};
                data1.channelEnabled = [];
                data1.scalingCoefficients = [];
                data1.colors_in = {};
                data1.widths_in = [];
            else
                data1.channelEnabled = repmat(false, length(data1.ch_labels), 1);    
                data1.channelEnabled(data1.activeChannels) = true;
            end

            % Инициализация и проверка данных data2
            if isempty(data2) || ~isfield(data2, 'ch_labels')
                data2.ch_labels = {};
                data2.channelEnabled = [];
                data2.scalingCoefficients = [];
                data2.colors_in = {};
                data2.widths_in = [];
            else
                data2.channelEnabled = repmat(false, length(data2.ch_labels), 1);    
                data2.channelEnabled(data2.activeChannels) = true;
            end
        end
        
                % Функция применения слияния и построения графика
        function applyMerging(~, ~)
            mergeTable = findobj(mergeFig, 'Tag', 'mergeTable');
            mergeSettings = mergeTable.Data(:, 2);
            mergeTableData = mergeTable.Data;
            mergedData = mergeDatasets();

            % Создание окна для отображения результата слияния
            resultFig = figure('Name', 'Merged Data', 'NumberTitle', 'off', 'Position', [100, 30, 800, 600]);
            axesHandle = axes('Parent', resultFig);

            % Кнопка для сохранения фигуры на среднем
            saveFigureButton = uicontrol('Style', 'pushbutton', 'String', 'Save Figure', 'Position', [74  10, 80, 30], 'Callback', @(src, event) saveFigure(resultFig));
        
            % Кнопка для сохранения данных
            saveResultButton = uicontrol('Style', 'pushbutton', 'String', 'Save Data', 'Position', [160  10, 80, 30], 'Callback', @saveMergedToFile);
        
            plotData(mergedData, axesHandle);
            titletext = titleEdit.String;
            m_ev = num2str(numel(mergedData.events));
            d1_ev = num2str(numel(data1.events));
            d2_ev = num2str(numel(data2.events));
            title([titletext, ', ', m_ev ' (' d1_ev ' and ' d2_ev ') events'], 'interpreter', 'none')
        end
        
        function saveMergedToFile(~,~)
            inidir = [initialDir, '/', titleEdit.String, '.mean'];
            [file, path] = uiputfile('*.mean', 'Select Data File', inidir);
            if isequal(file, 0)
                disp('File save canceled.');
                return;
            end
            filepath = fullfile(path, file);
            save(filepath, '-struct', 'mergedData'); % Сохранение в .mean файл
        end
        
        function saveFigure(fig)
            % Скрытие кнопки
            set(saveResultButton, 'Visible', 'off');
            set(saveFigureButton, 'Visible', 'off');

            % Открытие диалогового окна для сохранения файла
            inidir = [initialDir, '/', titleEdit.String, '_merged.png'];
            [fileName, filePath, filterIndex] = uiputfile('*.png', 'Save as', inidir);

            % Проверка, был ли выбран файл
            if fileName ~= 0
                % Создание полного пути к файлу
                fullFilePath = fullfile(filePath, fileName);
                saveas(fig, fullFilePath, 'png');
            else
                disp('File save cancelled.');
            end

            % Восстановление видимости кнопки
            set(saveResultButton, 'Visible', 'on');
            set(saveFigureButton, 'Visible', 'on');
        end
        
    end



    % Функция слияния данных
    function mergedData = mergeDatasets(~, ~)
        mergedData = data2; % Инициализация слиянными данными data2
        mergedData.events = [data1.events; data2.events];

        j = length(mergeSettings);
        for i = 1:length(mergeSettings)
            if strcmp(mergeSettings{i}, 'sum')
                try
                mergedData.meanData(:, i) = (data1.meanData(:, i) ...
                    + data2.meanData(:, i))/2;
                mergedData.channelEnabled(i) = mergeTableData{i, 3};
                catch
                    disp('error')
                end
            elseif strcmp(mergeSettings{i}, 'keep')                
                j = j+1;
                mergedData.meanData(:, j) = data1.meanData(:, i);
                mergedData.ch_labels(j) = data1.ch_labels(i);
                mergedData.scalingCoefficients(j) = data1.scalingCoefficients(i);
                mergedData.widths_in(j) = data1.widths_in(i);
                mergedData.colors_in(j) = data1.colors_in(i);
                mergedData.channelEnabled(j) = mergeTableData{i, 3};
            end
        end
    end

    % Функция для обновления данных data1/data2 в соответствии с таблицей
    function data = updateDataFromTable(table, data)
        tableData = table.Data;
        for i = 1:size(tableData, 1)
            data.ch_labels{i} = tableData{i, 1};
            data.channelEnabled(i) = tableData{i, 2};
            data.scalingCoefficients(i) = tableData{i, 3};
            data.colors_in{i} = tableData{i, 4};
            data.widths_in(i) = tableData{i, 5};
        end
    end
end
