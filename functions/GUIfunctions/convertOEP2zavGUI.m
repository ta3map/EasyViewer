function convertOEP2zavGUI
    % GUI для конвертации OEP-файлов в формат ZAV с использованием функции oep_to_zav

    % Проверяем, не открыто ли уже окно GUI
    figTag = 'convertOEP2zavGUI';
    guiFig = findobj('Type', 'figure', 'Tag', figTag);

    if ~isempty(guiFig)
        figure(guiFig);
        return;
    end

    % Глобальная переменная для хранения пути к настройкам
    global SettingsFilepath zav_calling

    % Инициализация переменных
    persistent recPath zavFilePath newFs detectMua mua_std_coef doResample selectedChannels availableChannels active_folder

    % Значения по умолчанию
    mua_std_coef = 3;
    newFs = 1000; % Гц
    detectMua = true;
    doResample = true;
    selectedChannels = {}; % Пустой означает все каналы
    availableChannels = {};
    recPath = '';
    zavFilePath = '';
    openAfter = true;

    % Используем SettingsFilepath для определения последней используемой папки
    try
        d = load(SettingsFilepath);
        if isfield(d, 'lastOpenedFolders') && ~isempty(d.lastOpenedFolders)
            active_folder = d.lastOpenedFolders{end};
        else
            active_folder = userpath;
        end
    catch
        active_folder = userpath;
    end

    % Создаем главное окно GUI
    fig = figure('Name', 'Convert OEP to ZAV', 'Position', [100, 100, 600, 600], 'NumberTitle', 'off',...
            'MenuBar', 'none', 'ToolBar', 'none', 'Resize', 'off', 'Tag', figTag);

    % Позиционные переменные
    leftMargin = 20;
    topMargin = 550;
    btnWidth = 150;
    btnHeight = 25;
    spacing = 10;
    secondcolumnshift =  170;

    % Кнопка для выбора папки с данными OEP
    uicontrol('Parent', fig, 'Style', 'pushbutton', 'String', 'Select OEP Folder', ...
        'Position', [leftMargin, topMargin, btnWidth, btnHeight], 'Callback', @selectOepFolder);

    % Метка для отображения выбранной папки
    recPathLabel = uicontrol('Parent', fig, 'Style', 'text', 'String', 'No folder selected', ...
        'Position', [leftMargin + btnWidth + spacing, topMargin, 400, btnHeight], 'HorizontalAlignment', 'left');

    % Метка для отображения оригинальной частоты дискретизации
    shiftdown = btnHeight + 20;
    FsOrigLabel = uicontrol('Parent', fig, 'Style', 'text', 'String', '...', ...
        'Position', [leftMargin + btnWidth + spacing, topMargin - shiftdown, 400, btnHeight], 'HorizontalAlignment', 'left');

    % Checkbox для обнаружения MUA
    shiftdown = 80;
    detectMuaToggle = uicontrol('Parent', fig, 'Style', 'checkbox', 'String', 'Detect MUA', ...
        'Position', [leftMargin, topMargin - (btnHeight + spacing) + 30 - shiftdown, btnWidth, btnHeight], 'Value', detectMua, 'Callback', @detectMuaCallback);

    % Поле для ввода коэффициента порога MUA    
    uicontrol('Parent', fig, 'Style', 'text', 'String', 'MUA Threshold (n*STD):', ...
        'Position', [leftMargin, topMargin - (btnHeight + spacing) - shiftdown, 150, btnHeight], 'HorizontalAlignment', 'right');    

    muaCoefUI = uicontrol('Parent', fig, 'Style', 'edit', 'String', num2str(mua_std_coef), ...
        'Position', [leftMargin + secondcolumnshift, topMargin - (btnHeight + spacing) - shiftdown, 50, btnHeight], 'Callback', @muaCoefUICallback);

    % Поле для ввода частоты дискретизации LFP
    shiftdown = 120;
    uicontrol('Parent', fig, 'Style', 'text', 'String', 'New Fs (Hz):', ...
        'Position', [leftMargin, topMargin - 2*(btnHeight + spacing) - shiftdown, 150, btnHeight], 'HorizontalAlignment', 'right');

    lfpFsUI = uicontrol('Parent', fig, 'Style', 'edit', 'String', num2str(newFs), ...
        'Position', [leftMargin + secondcolumnshift, topMargin - 2*(btnHeight + spacing) - shiftdown, 50, btnHeight], 'Callback', @lfpFsUICallback);

    % Checkbox для ресемплинга
    doResampleToggle = uicontrol('Parent', fig, 'Style', 'checkbox', 'String', 'Resample LFP', ...
        'Position', [leftMargin, topMargin - 2*(btnHeight + spacing) + 30 - shiftdown, 100, btnHeight], 'Value', doResample, 'Callback', @doResampleCallback);

    % Панель для выбора каналов
    channelPanel = uipanel('Parent', fig, 'Title', 'Select Channels', 'Position', [0.05, 0.1, 0.9, 0.45]);

    % Кнопки для выбора/отмены всех каналов
    btnSelectAll = uicontrol('Parent', channelPanel, 'Style', 'pushbutton', 'String', 'Select All', ...
        'Units', 'normalized', 'Position', [0.02, 0.92, 0.15, 0.06], 'Callback', @selectAllChannels);
    
    btnDeselectAll = uicontrol('Parent', channelPanel, 'Style', 'pushbutton', 'String', 'Deselect All', ...
        'Units', 'normalized', 'Position', [0.18, 0.92, 0.15, 0.06], 'Callback', @deselectAllChannels);

    % Таблица для отображения списка каналов с галочками
    channelTable = uitable('Parent', channelPanel, 'Data', {}, 'ColumnName', {'Use', 'Channel Name'}, ...
        'ColumnEditable', [true, false], 'Units', 'normalized', 'Position', [0, 0, 1, 0.92], 'CellEditCallback', @channelSelectionCallback);
    
    % Checkbox для открытия файла    
    openafterConvToggle = uicontrol('Parent', fig, 'Style', 'checkbox', 'String', 'Open after conversion', ...
        'Position', [leftMargin, 20, btnWidth, btnHeight], 'Value', openAfter, 'Callback', @openafterConvCallback);
    
    % Кнопка для запуска конвертации
    uicontrol('Parent', fig, 'Style', 'pushbutton', 'String', 'Start Conversion', ...
        'Position', [leftMargin + secondcolumnshift, 20, btnWidth, btnHeight], 'Callback', @startConversion);

    % Функции обратного вызова
    function selectOepFolder(~, ~)
        folder = uigetdir(active_folder, 'Select OpenEphys Folder');
        if isequal(folder, 0)
            disp('User canceled folder selection');
            recPath = '';
            set(recPathLabel, 'String', 'No folder selected');
            % Очистим таблицу каналов
            set(channelTable, 'Data', {});
            availableChannels = {};
            selectedChannels = {};
            set(FsOrigLabel, 'String', '...');
        else
            recPath = folder;
            disp(['Selected OEP folder: ', recPath]);
            set(recPathLabel, 'String', recPath);
            % Обновляем активную папку
            active_folder = recPath;
            % После выбора папки извлекаем доступные каналы
            extractChannels();
        end
    end

    function extractChannels()
        % Загрузка только метаданных для получения информации о каналах и частоте дискретизации
        try
            metadataTable = readOpenEphysMetadata(recPath);
            
            % Берем первый поток для отображения частоты дискретизации
            if ~isempty(metadataTable) && ~isempty(metadataTable.Sample_Rate{1})
                Fs = metadataTable.Sample_Rate{1}; % Оригинальная частота дискретизации (Hz)
                set(FsOrigLabel, 'String', ['Fs (Hz): ', num2str(Fs)]);
            else
                set(FsOrigLabel, 'String', 'Fs (Hz): N/A');
            end

            % Получение имен каналов из первого потока
            if ~isempty(metadataTable) && ~isempty(metadataTable.Channel_Names{1})
                channelNames = metadataTable.Channel_Names{1}';
                availableChannels = channelNames;
                numChannels = numel(availableChannels);

                % Подготавливаем данные для таблицы
                channelData = cell(numChannels, 2);
                for i = 1:numChannels
                    channelData{i, 1} = true; % По умолчанию все каналы выбраны
                    channelData{i, 2} = availableChannels{i};
                end

                % Обновляем таблицу каналов
                set(channelTable, 'Data', channelData);
                % Инициализируем выбранные каналы
                selectedChannels = availableChannels; % Все каналы выбраны
            else
                availableChannels = {};
                selectedChannels = {};
                set(channelTable, 'Data', {});
            end
        catch ME
            disp(['Error loading OEP metadata: ', ME.message]);
            warndlg(['An error occurred while loading OEP metadata: ', ME.message], 'Loading Error');
            set(recPathLabel, 'String', 'No folder selected');
            recPath = '';
            availableChannels = {};
            selectedChannels = {};
            set(FsOrigLabel, 'String', '...');
            set(channelTable, 'Data', {});
        end
    end

    function channelSelectionCallback(src, event)
        % Обновляем список выбранных каналов при изменении галочек
        channelData = get(src, 'Data');
        selectedChannelIndices = find([channelData{:,1}]);
        selectedChannels = availableChannels(selectedChannelIndices);
    end

    function selectAllChannels(~, ~)
        % Выбираем все каналы
        channelData = get(channelTable, 'Data');
        if ~isempty(channelData)
            for i = 1:size(channelData, 1)
                channelData{i, 1} = true;
            end
            set(channelTable, 'Data', channelData);
            selectedChannels = availableChannels;
        end
    end

    function deselectAllChannels(~, ~)
        % Отменяем выбор всех каналов
        channelData = get(channelTable, 'Data');
        if ~isempty(channelData)
            for i = 1:size(channelData, 1)
                channelData{i, 1} = false;
            end
            set(channelTable, 'Data', channelData);
            selectedChannels = {};
        end
    end

    function detectMuaCallback(source, ~)
        detectMua = get(source, 'Value');
    end

    function openafterConvCallback(source, ~)
        openAfter = get(source, 'Value');
    end

    function muaCoefUICallback(source, ~)
        mua_std_coef = str2double(get(source, 'String'));
        if isnan(mua_std_coef) || mua_std_coef <= 0
            warndlg('Please enter a valid positive number for MUA threshold.', 'Invalid Input');
            set(source, 'String', num2str(3));
            mua_std_coef = 3;
        end
    end

    function lfpFsUICallback(source, ~)
        newFs = str2double(get(source, 'String'));
        if isnan(newFs) || newFs <= 0
            warndlg('Please enter a valid positive number for LFP Fs.', 'Invalid Input');
            set(source, 'String', num2str(1000));
            newFs = 1000;
        end
    end

    function doResampleCallback(source, ~)
        doResample = get(source, 'Value');
    end

    function startConversion(~, ~)
        if isempty(recPath)
            warndlg('Please select an OpenEphys folder first.', 'No Folder Selected');
            return;
        end

        % Получаем выбранные каналы из таблицы
        channelData = get(channelTable, 'Data');
        selectedChannelIndices = find([channelData{:,1}]);
        if isempty(selectedChannelIndices)
            warndlg('Please select at least one channel.', 'No Channels Selected');
            return;
        end
        selectedChannels = availableChannels(selectedChannelIndices);

        % Предлагаем имя для выходного файла на основе имени папки
        [~, folderName, ~] = fileparts(recPath);
        defaultOutputName = [folderName, '.mat'];
        [file, path] = uiputfile('*.mat', 'Save ZAV File As', fullfile(active_folder, defaultOutputName));
        if isequal(file, 0)
            disp('User canceled file save');
            return;
        else
            zavFilePath = fullfile(path, file);
            % Обновляем активную папку
            active_folder = path;
        end

        % Создаем окно прогресса
        hWaitBar = waitbar(0, 'Initializing conversion...', 'Name', 'OEP to ZAV Conversion');

        try
            % Получаем метаданные для частоты дискретизации
            metadataTable = readOpenEphysMetadata(recPath);
            Fs = metadataTable.Sample_Rate{1}; % Оригинальная частота дискретизации (Hz)

            % Вызов функции конвертации с потоковым чтением
            fprintf('\n[convertOEP2zavGUI] Calling oep_to_zav_streaming (NEW STREAMING VERSION)...\n');
            debugState('convertOEP2zavGUI', 'Calling oep_to_zav_streaming...');
            debugState('convertOEP2zavGUI', 'recPath: %s', recPath);
            debugState('convertOEP2zavGUI', 'zavFilePath: %s', zavFilePath);
            debugState('convertOEP2zavGUI', 'Fs: %f, newFs: %f, detectMua: %d, doResample: %d', ...
                Fs, newFs, detectMua, doResample);
            
            % Проверяем, что функция существует
            if ~exist('oep_to_zav_streaming', 'file')
                error('oep_to_zav_streaming function not found in path!');
            end
            
            oep_to_zav_streaming(recPath, zavFilePath, Fs, newFs, detectMua, mua_std_coef, doResample, availableChannels, selectedChannelIndices, hWaitBar);
            
            debugState('convertOEP2zavGUI', 'oep_to_zav_streaming completed');
            fprintf('[convertOEP2zavGUI] oep_to_zav_streaming completed successfully\n');

            % Сохраняем информацию о последней открытой папке
            lastOpenedFolders = {recPath};
            if exist(SettingsFilepath, 'file')
                save(SettingsFilepath, 'lastOpenedFolders', '-append');
            else
                save(SettingsFilepath, 'lastOpenedFolders');
            end

            disp('Conversion completed successfully.');
            
            % Закрываем окно прогресса
            if isvalid(hWaitBar)
                close(hWaitBar);
            end

            % Закрываем окно GUI после успешной конвертации
            close(fig);

            % Открываем если хотели
            if openAfter
                zav_calling(zavFilePath)
            end
            
        catch ME
            disp(['Error during conversion: ', ME.message]);
            warndlg(['An error occurred during conversion: ', ME.message], 'Conversion Error');
            % Закрываем окно прогресса при ошибке
            if exist('hWaitBar', 'var') && isvalid(hWaitBar)
                close(hWaitBar);
            end
        end
    end
end
