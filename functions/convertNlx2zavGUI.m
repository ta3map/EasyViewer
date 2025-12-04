function convertNlx2zavGUI
    % GUI для конвертации Neuralynx-файлов в формат ZAV

    % Проверяем, не открыто ли уже окно GUI
    figTag = 'convertNlx2zavGUI';
    guiFig = findobj('Type', 'figure', 'Tag', figTag);

    if ~isempty(guiFig)
        figure(guiFig);
        return;
    end

    % Глобальная переменная для хранения пути к настройкам
    global SettingsFilepath zav_calling

    % Инициализация переменных
    persistent recordPath zavFilePath detectMua mua_std_coef lfp_Fs doResample selectedChannels availableChannels channelNumbers active_folder

    % Значения по умолчанию
    mua_std_coef = 3;
    lfp_Fs = 1000;
    detectMua = false;
    doResample = true;
    selectedChannels = {}; % Пустой означает все каналы
    availableChannels = {};
    channelNumbers = []; % Номера каналов, соответствующие именам
    recordPath = '';
    zavFilePath = '';
    openAfter = true;

    % Используем SettingsFilepath для определения последней используемой папки
    try
        d = load(SettingsFilepath);
        if isfield(d, 'lastOpenedFolders') && ~isempty(d.lastOpenedFolders)
            active_folder = d.lastOpenedFolders{end};
        elseif isfield(d, 'lastOpenedFiles') && ~isempty(d.lastOpenedFiles)
            active_folder = fileparts(d.lastOpenedFiles{end});
        else
            active_folder = userpath;
        end
    catch
        active_folder = userpath;
    end

    % Создаем главное окно GUI
    fig = figure('Name', 'Convert Neuralynx to ZAV', 'Position', [100, 100, 600, 600], 'NumberTitle', 'off',...
            'MenuBar', 'none', 'ToolBar', 'none', 'Resize', 'off', 'Tag', figTag);

    % Позиционные переменные
    leftMargin = 20;
    topMargin = 550;
    btnWidth = 150;
    btnHeight = 25;
    spacing = 10;
    secondcolumnshift =  170;

    % Кнопка для выбора папки с данными Neuralynx
    uicontrol('Parent', fig, 'Style', 'pushbutton', 'String', 'Select Neuralynx Folder', ...
        'Position', [leftMargin, topMargin, btnWidth, btnHeight], 'Callback', @selectRecordPath);

    % Метка для отображения выбранной папки
    recordPathLabel = uicontrol('Parent', fig, 'Style', 'text', 'String', 'No folder selected', ...
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

    lfpFsUI = uicontrol('Parent', fig, 'Style', 'edit', 'String', num2str(lfp_Fs), ...
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
    function selectRecordPath(~, ~)
        folder = uigetdir(active_folder, 'Select Neuralynx Folder');
        if isequal(folder, 0)
            disp('User canceled folder selection');
            recordPath = '';
            set(recordPathLabel, 'String', 'No folder selected');
            % Очистим таблицу каналов
            set(channelTable, 'Data', {});
            availableChannels = {};
            selectedChannels = {};
            channelNumbers = [];
            set(FsOrigLabel, 'String', '...');
        else
            recordPath = folder;
            disp(['Selected Neuralynx folder: ', recordPath]);
            set(recordPathLabel, 'String', recordPath);
            % Обновляем активную папку
            active_folder = recordPath;
            % После выбора папки извлекаем доступные каналы
            extractChannels();
        end
    end

    function extractChannels()
        % Извлечение списка каналов из папки Neuralynx
        try
            if (recordPath(end) ~= '\')
                recordPath(end + 1) = '\';
            end
            
            % Находим все .ncs файлы
            dirCnt = dir(recordPath);
            ncsFiles = struct('f', {}, 'chNum', {}, 'chName', {});
            
            for t = 1:length(dirCnt)
                if ((~dirCnt(t).isdir) && (length(dirCnt(t).name) > 3))
                    if isequal(dirCnt(t).name(end - 3:end), '.ncs')
                        % Извлекаем номер канала из имени файла (формат: префикс + номер + .ncs)
                        % Например: CSC1.ncs -> 1, или CH1.ncs -> 1
                        fileName = dirCnt(t).name(1:end-4); % убираем .ncs
                        % Ищем последние цифры в имени файла
                        numMatch = regexp(fileName, '\d+$', 'match');
                        if ~isempty(numMatch)
                            ch = str2double(numMatch{1});
                            if ~isnan(ch)
                                ncsFiles(end + 1).f = fullfile(recordPath, dirCnt(t).name);
                                ncsFiles(end).chNum = ch;
                                ncsFiles(end).chName = fileName;
                            end
                        end
                    end
                end
            end
            
            % Сортируем по номеру канала
            [~, sortIdx] = sort([ncsFiles.chNum]);
            ncsFiles = ncsFiles(sortIdx);
            
            if isempty(ncsFiles)
                warndlg('No .ncs files found in the selected folder.', 'No Channels Found');
                set(recordPathLabel, 'String', 'No folder selected');
            recordPath = '';
            availableChannels = {};
            selectedChannels = {};
            channelNumbers = [];
            set(FsOrigLabel, 'String', '...');
            set(channelTable, 'Data', {});
                return;
            end
            
            % Читаем заголовки для получения имен каналов и частоты дискретизации
            channelNames = cell(length(ncsFiles), 1);
            channelNums = zeros(length(ncsFiles), 1);
            orig_Fs = [];
            
            for i = 1:length(ncsFiles)
                fileToRead = ncsFiles(i).f;
                if exist(fileToRead, 'file')
                    cscHd = Nlx2MatCSC(fileToRead, [0 0 0 0 0], 1, 1, []);
                    % Используем сохраненное имя канала
                    channelNames{i} = ncsFiles(i).chName;
                    channelNums(i) = ncsFiles(i).chNum;
                    
                    % Получаем частоту дискретизации из первого канала
                    if isempty(orig_Fs)
                        Fs = NlxParametr(cscHd, 'SamplingFrequency');
                        orig_Fs = Fs;
                    end
                end
            end
            
            availableChannels = channelNames;
            channelNumbers = channelNums; % Сохраняем номера каналов в persistent переменную
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
            
            % Отображаем оригинальную частоту дискретизации
            if ~isempty(orig_Fs)
                set(FsOrigLabel, 'String', ['Fs (Hz): ', num2str(orig_Fs)]);
            else
                set(FsOrigLabel, 'String', 'Fs (Hz): N/A');
            end
            
        catch ME
            disp(['Error loading Neuralynx channels: ', ME.message]);
            warndlg(['An error occurred while loading Neuralynx channels: ', ME.message], 'Loading Error');
            set(recordPathLabel, 'String', 'No folder selected');
            recordPath = '';
            availableChannels = {};
            selectedChannels = {};
            channelNumbers = [];
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
        if isempty(recordPath)
            warndlg('Please select a Neuralynx folder first.', 'No Folder Selected');
            return;
        end

        % Получаем выбранные каналы из таблицы
        channelData = get(channelTable, 'Data');
        selectedChannelIndices = find([channelData{:,1}]);
        if isempty(selectedChannelIndices)
            warndlg('Please select at least one channel.', 'No Channels Selected');
            return;
        end
        
        % Преобразуем выбранные индексы в номера каналов
        channels_list = channelNumbers(selectedChannelIndices);
        
        if isempty(channels_list)
            warndlg('No channels selected.', 'Channel Error');
            return;
        end

        % Предлагаем имя для выходного файла на основе имени папки
        [~, folderName, ~] = fileparts(recordPath);
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
        hWaitBar = waitbar(0, 'Initializing conversion...', 'Name', 'Neuralynx to ZAV Conversion');

        try
            channels_n = numel(channels_list);
            lfp = []; % инициализация переменной для lfp

            % Считываем данные первого канала для определения размера матрицы lfp
            [data, ~, hd, ~, ~] = ZavNrlynx2(recordPath, [], channels_list(1), [], []);
            orig_Fs = 1e6/hd.si; % оригинальная частота дискретизации
            lfp_length = floor(length(data) * lfp_Fs / orig_Fs); % новая длина сигнала после ресемплинга
            lfp = zeros(lfp_length, channels_n); % предварительное выделение памяти для lfp

            clear spks
            ch_inx = 0;
            for ch = channels_list
                ch_inx = ch_inx + 1;
                
                [data, ~, hd, spkTS, spkSM] = ZavNrlynx2(recordPath, [], ch, [], []);

                ampl = min(spkSM.s(:, :));

                if detectMua
                    [tStamp, ampl, shape] = detectMUA(data, hd, mua_std_coef, true);
                    spks(ch_inx).tStamp = single(tStamp); % сохраняем спайки канала в миллисекундном формате
                    spks(ch_inx).ampl = single(ampl);
                    spks(ch_inx).shape = shape;
                else
                    % по ZAV формату
                    spks(ch_inx).tStamp = single(spkTS.s'); % сохраняем спайки канала в миллисекундном формате
                    spks(ch_inx).ampl = single(ampl');
                    spks(ch_inx).shape = [];
                end

                % Ресамплинг данных канала
                if doResample
                    data_resampled = resample(data, lfp_Fs, orig_Fs);
                else
                    data_resampled = data;
                end
                lfp(:, ch_inx) = data_resampled; % добавляем ресемплированные данные в матрицу lfp

                % Обновление индикатора прогресса
                waitbar(ch_inx / numel(channels_list), hWaitBar, sprintf('Channel %d from %d...', ch, numel(channels_list)));
            end
            
            % преобразуем заголовок для выбранного списка каналов
            hd.adBitVolts = hd.adBitVolts(channels_list);
            hd.dspDelay_mks = hd.dspDelay_mks(channels_list);
            hd.adBitVoltsSpk = hd.adBitVoltsSpk(channels_list);
            hd.dspDelay_mksSpk = hd.dspDelay_mksSpk(channels_list);
            hd.alignmentPt = hd.alignmentPt(channels_list);
            hd.inverted = hd.inverted(channels_list);
            hd.recChUnits = hd.recChUnits(channels_list); 
            hd.recChNames = hd.recChNames(channels_list);
            hd.ch_si = hd.ch_si(channels_list);
            
            waitbar(1, hWaitBar, 'Saving data...');
            
            % Сохранение данных
            skip_points = orig_Fs/lfp_Fs;
            clear chnlGrp lfpVar zavp
            chnlGrp = {};
            lfpVar = np_flatten(std(lfp)/10)';
            zavp.file = recordPath;
            zavp.siS = (hd.si/1000)/lfp_Fs;
            zavp.dwnSmplFrq = lfp_Fs;
            zavp.stimCh = nan;

            if size(hd.inTTL_timestamps, 2)>0 % если были ttl стимуляции
                r_i = (hd.inTTL_timestamps.t(:,1)*skip_points)/zavp.dwnSmplFrq;
                f_i = (hd.inTTL_timestamps.t(:,2)*skip_points)/zavp.dwnSmplFrq;
            else
                r_i = [];
                f_i = [];
            end
            zavp.realStim.r = r_i;
            zavp.realStim.f = f_i;
            zavp.rarStep = hd.ch_si'*0+skip_points;

            save(zavFilePath, 'chnlGrp', 'hd', 'lfp', 'lfpVar', 'spks', 'zavp');
            
            % Сохраняем информацию о последней открытой папке
            lastOpenedFolders = {recordPath};
            if exist(SettingsFilepath, 'file')
                save(SettingsFilepath, 'lastOpenedFolders', '-append');
            else
                save(SettingsFilepath, 'lastOpenedFolders');
            end

            % Сохраняем информацию о последнем открытом файле
            lastOpenedFiles = {zavFilePath};
            save(SettingsFilepath, 'lastOpenedFiles', '-append');

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
