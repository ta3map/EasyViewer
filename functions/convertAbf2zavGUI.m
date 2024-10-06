function convertAbf2zavGUI
    % GUI для конвертации ABF-файлов в формат ZAV с использованием функции abf_to_zav

    % Проверяем, не открыто ли уже окно GUI
    figTag = 'convertAbf2zavGUI';
    guiFig = findobj('Type', 'figure', 'Tag', figTag);

    if ~isempty(guiFig)
        figure(guiFig);
        return;
    end

    % Глобальная переменная для хранения пути к настройкам
    global SettingsFilepath

    % Инициализация переменных
    persistent abfFilePath detectMua lfp_Fs mua_std_coef doResample selectedChannels availableChannels active_folder

    % Значения по умолчанию
    mua_std_coef = 1;
    lfp_Fs = 1000;
    detectMua = false;
    doResample = true;
    selectedChannels = {}; % Пустой означает все каналы
    availableChannels = {};
    abfFilePath = '';

    % Используем SettingsFilepath для определения последней используемой папки
    try
        d = load(SettingsFilepath);
        if isfield(d, 'lastOpenedFiles') && ~isempty(d.lastOpenedFiles)
            active_folder = fileparts(d.lastOpenedFiles{end});
        else
            active_folder = userpath;
        end
    catch
        active_folder = userpath;
    end

    % Создаем главное окно GUI
    fig = figure('Name', 'Convert ABF to ZAV', 'Position', [100, 100, 600, 500], 'NumberTitle', 'off',...
            'MenuBar', 'none', 'ToolBar', 'none', 'Resize', 'off', 'Tag', figTag);

    % Позиционные переменные
    leftMargin = 20;
    topMargin = 450;
    btnWidth = 150;
    btnHeight = 25;
    spacing = 10;
    secondcolumnshift =  150;
    % Кнопка для выбора ABF-файла
    uicontrol('Parent', fig, 'Style', 'pushbutton', 'String', 'Select ABF File', ...
        'Position', [leftMargin, topMargin, btnWidth, btnHeight], 'Callback', @selectAbfFile);

    % Метка для отображения выбранного файла
    abfFileLabel = uicontrol('Parent', fig, 'Style', 'text', 'String', 'No file selected', ...
        'Position', [leftMargin + btnWidth + spacing, topMargin, 400, btnHeight], 'HorizontalAlignment', 'left');
    
    % Метка для отображения оригинальной частоты дискретизации
    shiftdown = btnHeight+10;
    FsOrigLabel = uicontrol('Parent', fig, 'Style', 'text', 'String', '...', ...
        'Position', [leftMargin + btnWidth + spacing, topMargin-shiftdown, 400, btnHeight], 'HorizontalAlignment', 'left');
    
    % Checkbox для обнаружения MUA
    shiftdown = 50;
    detectMuaToggle = uicontrol('Parent', fig, 'Style', 'checkbox', 'String', 'Detect MUA', ...
        'Position', [leftMargin, topMargin - (btnHeight + spacing)+30-shiftdown, btnWidth, btnHeight], 'Value', detectMua, 'Callback', @detectMuaCallback);
    
    % Поле для ввода коэффициента порога MUA    
    uicontrol('Parent', fig, 'Style', 'text', 'String', 'MUA Threshold (n*STD):', ...
        'Position', [leftMargin, topMargin - (btnHeight + spacing)-shiftdown, 150, btnHeight], 'HorizontalAlignment', 'right');    
    
    muaCoefUI = uicontrol('Parent', fig, 'Style', 'edit', 'String', num2str(mua_std_coef), ...
        'Position', [leftMargin + secondcolumnshift, topMargin - (btnHeight + spacing)-shiftdown, 50, btnHeight], 'Callback', @muaCoefUICallback);
    
    shiftdown = 70;
    % Поле для ввода частоты дискретизации LFP
    uicontrol('Parent', fig, 'Style', 'text', 'String', 'New Fs (Hz):', ...
        'Position', [leftMargin, topMargin - 2*(btnHeight + spacing)-shiftdown, 150, btnHeight], 'HorizontalAlignment', 'right');
    
    lfpFsUI = uicontrol('Parent', fig, 'Style', 'edit', 'String', num2str(lfp_Fs), ...
        'Position', [leftMargin + secondcolumnshift, topMargin - 2*(btnHeight + spacing)-shiftdown, 50, btnHeight], 'Callback', @lfpFsUICallback);
   
    % Checkbox для ресемплинга
    doResampleToggle = uicontrol('Parent', fig, 'Style', 'checkbox', 'String', 'Resample LFP', ...
        'Position', [leftMargin, topMargin - 2*(btnHeight + spacing)+30-shiftdown, 100, btnHeight], 'Value', doResample, 'Callback', @doResampleCallback);

    % Панель для выбора каналов
    channelPanel = uipanel('Parent', fig, 'Title', 'Select Channels', 'Position', [0.05, 0.1, 0.9, 0.5]);

    % Таблица для отображения списка каналов с галочками
    channelTable = uitable('Parent', channelPanel, 'Data', {}, 'ColumnName', {'Use', 'Channel Name'}, ...
        'ColumnEditable', [true, false], 'Units', 'normalized', 'Position', [0, 0, 1, 1], 'CellEditCallback', @channelSelectionCallback);

    % Кнопка для запуска конвертации
    uicontrol('Parent', fig, 'Style', 'pushbutton', 'String', 'Start Conversion', ...
        'Position', [leftMargin, 20, btnWidth, btnHeight], 'Callback', @startConversion);

    % Функции обратного вызова
    function selectAbfFile(~, ~)
        [file, path] = uigetfile('*.abf', 'Select ABF File', active_folder);
        if isequal(file, 0)
            disp('User canceled file selection');
            abfFilePath = '';
            set(abfFileLabel, 'String', 'No file selected');
            % Очистим таблицу каналов
            set(channelTable, 'Data', {});
            availableChannels = {};
            selectedChannels = {};
        else
            abfFilePath = fullfile(path, file);
            disp(['Selected ABF file: ', abfFilePath]);
            set(abfFileLabel, 'String', abfFilePath);
            % Обновляем активную папку
            active_folder = path;
            % После выбора файла извлекаем доступные каналы
            extractChannels();
        end
    end

    function extractChannels()
        % Чтение заголовка для получения имен каналов
        [~, ~, hd_abf] = abfload(abfFilePath, 'stop', 1, 'doDispInfo', false);
        availableChannels = hd_abf.recChNames;
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
        
        % Оригинальная частота дискретизации.
        orig_Fs = 1e6 / hd_abf.si; % hd_abf.si в микросекундах на сэмпл.
        set(FsOrigLabel, 'String', ['Fs (Hz):', num2str(orig_Fs)]);
    end

    function channelSelectionCallback(src, event)
        % Обновляем список выбранных каналов при изменении галочек
        channelData = get(src, 'Data');
        selectedChannelIndices = find([channelData{:,1}]);
        selectedChannels = availableChannels(selectedChannelIndices);
    end

    function detectMuaCallback(source, ~)
        detectMua = get(source, 'Value');
    end

    function muaCoefUICallback(source, ~)
        mua_std_coef = str2double(get(source, 'String'));
        if isnan(mua_std_coef) || mua_std_coef <= 0
            warndlg('Please enter a valid positive number for MUA threshold.', 'Invalid Input');
            set(source, 'String', num2str(5));
            mua_std_coef = 5;
        end
    end

    function lfpFsUICallback(source, ~)
        lfp_Fs = str2double(get(source, 'String'));
        if isnan(lfp_Fs) || lfp_Fs <= 0
            warndlg('Please enter a valid positive number for LFP Fs.', 'Invalid Input');
            set(source, 'String', num2str(1000));
            lfp_Fs = 1000;
        end
    end

    function doResampleCallback(source, ~)
        doResample = get(source, 'Value');
    end

    function startConversion(~, ~)
        if isempty(abfFilePath)
            warndlg('Please select an ABF file first.', 'No File Selected');
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

        % Предлагаем имя для выходного файла на основе имени ABF-файла
        [~, abfName, ~] = fileparts(abfFilePath);
        defaultOutputName = [abfName, '_converted.mat'];
        [file, path] = uiputfile('*.mat', 'Save ZAV File As', fullfile(active_folder, defaultOutputName));
        if isequal(file, 0)
            disp('User canceled file save');
            return;
        else
            zavFilePath = fullfile(path, file);
            % Обновляем активную папку
            active_folder = path;
        end

        % Проверяем и удаляем файл настроек, если он существует
        settingsFilePath = [zavFilePath(1:end-4), '_channelSettings.stn'];
        if exist(settingsFilePath, 'file')
            delete(settingsFilePath);
            disp(['Deleted existing settings file: ', settingsFilePath]);
        end

        % Показываем окно прогресса
        hWaitBar = waitbar(0, 'Converting...', 'Name', 'ABF to ZAV Conversion');

        % Обновление окна прогресса
        waitbar(0, hWaitBar, 'Starting conversion...');

        try
            collectSweeps = true;
            % Запускаем конвертацию с учетом выбранных каналов и параметров
            abf_to_zav(abfFilePath, zavFilePath, lfp_Fs, detectMua, doResample, collectSweeps, selectedChannels, mua_std_coef, hWaitBar);
            %abf_to_zav(abfFilePath, zavFilePath, lfp_Fs, detectMua, doResample, collectSweeps)
            % Обновление окна прогресса
            waitbar(1, hWaitBar, 'Conversion completed!');
            pause(1); % Пауза для отображения завершения

            % Сохраняем информацию о последнем открытом файле
            lastOpenedFiles = {zavFilePath};
            save(SettingsFilepath, 'lastOpenedFiles', '-append');

            disp('Conversion completed successfully.');

            % Закрываем окно прогресса
            close(hWaitBar);

            % Закрываем окно GUI после успешной конвертации
            close(fig);

        catch ME
            disp(['Error during conversion: ', ME.message]);
            warndlg(['An error occurred during conversion: ', ME.message], 'Conversion Error');
            % Закрываем окно прогресса при ошибке
            close(hWaitBar);
        end
    end
end
