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
        wb = [];
        try
            wb = waitbar(0, 'Loading Neuralynx channels...', 'Name', 'Loading Channels');
            
            if (recordPath(end) ~= '\')
                recordPath(end + 1) = '\';
            end
            
            waitbar(0.1, wb, 'Scanning for .ncs files...');
            
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
                close(wb);
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
            
            waitbar(0.2, wb, sprintf('Reading headers from %d channels...', length(ncsFiles)));
            
            % Читаем заголовки для получения имен каналов и частоты дискретизации
            channelNames = cell(length(ncsFiles), 1);
            channelNums = zeros(length(ncsFiles), 1);
            orig_Fs = [];
            
            for i = 1:length(ncsFiles)
                fileToRead = ncsFiles(i).f;
                if exist(fileToRead, 'file')
                    waitbar(0.2 + 0.7 * (i / length(ncsFiles)), wb, sprintf('Reading channel %d of %d...', i, length(ncsFiles)));
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
            
            waitbar(0.9, wb, 'Updating channel list...');
            
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
            
            waitbar(1, wb, 'Complete');
            close(wb);
            
        catch ME
            if ~isempty(wb) && ishandle(wb)
                close(wb);
            end
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

        % Предлагаем имя для выходного файла на основе имени папки Neuralynx
        recordPathClean = recordPath;
        if recordPathClean(end) == '\' || recordPathClean(end) == '/'
            recordPathClean = recordPathClean(1:end-1);
        end
        [~, folderName, ~] = fileparts(recordPathClean);
        defaultOutputName = [folderName, '.mat'];
        % Предлагаем сохранить в той же папке, где находится папка Neuralynx
        [file, path] = uiputfile('*.mat', 'Save ZAV File As', fullfile(fileparts(recordPathClean), defaultOutputName));
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

            % Считываем данные первого канала для определения размера матрицы lfp
            fprintf('DEBUG: Requesting first channel: %d, channels_list: %s\n', channels_list(1), mat2str(channels_list));
            fprintf('DEBUG: Calling ZavNrlynx2 with rCh = %d (type: %s)\n', channels_list(1), class(channels_list(1)));
            [data, ~, hd] = ZavNrlynx2(recordPath, [], channels_list(1), [], []);
            fprintf('DEBUG: First channel data size: %s, hd.nADCNumChannels: %d\n', mat2str(size(data)), hd.nADCNumChannels);
            orig_Fs = 1e6/hd.si; % оригинальная частота дискретизации
            
            % Вычисляем размер lfp в зависимости от того, будет ли ресемплинг
            if doResample
                lfp_length = floor(length(data) * lfp_Fs / orig_Fs); % новая длина сигнала после ресемплинга
                fprintf('DEBUG: RESAMPLING will be applied: lfp_length = floor(%d * %f / %f) = %d\n', length(data), lfp_Fs, orig_Fs, lfp_length);
            else
                lfp_length = length(data); % без ресемплинга используем оригинальную длину
                fprintf('DEBUG: NO RESAMPLING: lfp_length = length(data) = %d\n', lfp_length);
            end
            fprintf('DEBUG: lfp_length: %d, channels_n: %d\n', lfp_length, channels_n);
            
            % Создаем MAT-файл v7.3 и инициализируем переменные для прямого доступа
            waitbar(0, hWaitBar, 'Initializing MAT file...');
            m = matfile(zavFilePath, 'Writable', true);
            
            % Инициализируем lfp в файле (не в памяти)
            m.lfp = zeros(lfp_length, channels_n, 'single');
            fprintf('DEBUG: Initialized lfp in file, size: [%d %d]\n', lfp_length, channels_n);

            clear spks
            ch_inx = 0;
            for ch_idx = 1:length(channels_list)
                ch = channels_list(ch_idx);
                ch_inx = ch_inx + 1;
                
                fprintf('DEBUG: Requesting channel %d (index %d)\n', ch, ch_inx);
                fprintf('DEBUG: Calling ZavNrlynx2 with rCh = %d (type: %s, size: %s)\n', ch, class(ch), mat2str(size(ch)));
                [data, ~, hd_ch] = ZavNrlynx2(recordPath, [], ch, [], []);
                fprintf('DEBUG: Channel %d data size: %s, hd_ch.nADCNumChannels: %d\n', ch, mat2str(size(data)), hd_ch.nADCNumChannels);
                
                % Убеждаемся, что data - вектор-столбец (один канал)
                if size(data, 2) > 1
                    fprintf('DEBUG: WARNING - data has %d columns, extracting first column\n', size(data, 2));
                    data = data(:, 1);
                end
                data = data(:);

                if detectMua
                    [tStamp, ampl, shape] = detectMUA(data, hd_ch, mua_std_coef, true);
                    spks(ch_inx).tStamp = single(tStamp); % сохраняем спайки канала в миллисекундном формате
                    spks(ch_inx).ampl = single(ampl);
                    spks(ch_inx).shape = shape;
                else
                    % Пустые спайки, если не детектируем MUA
                    spks(ch_inx).tStamp = single([]);
                    spks(ch_inx).ampl = single([]);
                    spks(ch_inx).shape = [];
                end

                % Обработка данных канала (ресамплинг или без)
                if doResample
                    fprintf('DEBUG: RESAMPLING: YES - from %f Hz to %f Hz\n', orig_Fs, lfp_Fs);
                    data_processed = resample1(data, lfp_Fs, orig_Fs);
                else
                    fprintf('DEBUG: RESAMPLING: NO - keeping original %f Hz\n', orig_Fs);
                    data_processed = data;
                end
                
                % Убеждаемся, что data_processed - вектор-столбец
                data_processed = data_processed(:);
                
                fprintf('DEBUG: data_processed size: %s, expected lfp_length: %d\n', mat2str(size(data_processed)), lfp_length);
                
                % Проверяем размер перед записью
                if length(data_processed) ~= lfp_length
                    fprintf('DEBUG: WARNING - size mismatch! data_processed length: %d, lfp_length: %d\n', length(data_processed), lfp_length);
                    if length(data_processed) > lfp_length
                        fprintf('DEBUG: Truncating data_processed to lfp_length\n');
                        data_processed = data_processed(1:lfp_length);
                    elseif length(data_processed) < lfp_length
                        fprintf('DEBUG: Padding data_processed with zeros to lfp_length\n');
                        data_processed = [data_processed; zeros(lfp_length - length(data_processed), 1)];
                    end
                end
                
                % Записываем данные канала напрямую в файл (не держим в памяти)
                m.lfp(:, ch_inx) = single(data_processed);

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
            
            waitbar(0.95, hWaitBar, 'Finalizing data...');
            
            % Вычисляем lfpVar из данных в файле (читаем по частям для экономии памяти)
            lfpVar = zeros(1, channels_n);
            for ch_idx = 1:channels_n
                channel_data = m.lfp(:, ch_idx);
                lfpVar(ch_idx) = std(channel_data) / 10;
            end
            lfpVar = np_flatten(lfpVar)';
            
            % Сохранение остальных данных
            % Определяем фактическую частоту дискретизации сохраненных данных
            if doResample
                actual_Fs = lfp_Fs; % если ресемплинг применен, используем lfp_Fs
                skip_points = orig_Fs/lfp_Fs;
            else
                actual_Fs = orig_Fs; % если ресемплинг НЕ применен, используем оригинальную частоту
                skip_points = 1; % без ресемплинга нет пропуска точек
            end
            fprintf('DEBUG: actual_Fs (saved data frequency): %f Hz, skip_points: %f\n', actual_Fs, skip_points);
            
            chnlGrp = {};
            zavp.file = recordPath;
            zavp.siS = 1 / actual_Fs;
            zavp.dwnSmplFrq = actual_Fs;
            zavp.stimCh = nan;

            if size(hd.inTTL_timestamps, 2)>0 % если были ttl стимуляции
                % hd.inTTL_timestamps.t в микросекундах (из ZavNrlynx2.m строка 107)
                % Конвертируем в сэмплы сохраненных данных
                % Сначала в сэмплы оригинальных данных: микросекунды / hd.si
                % Затем пересчитываем в сэмплы сохраненных данных
                if doResample
                    % Для ресемплинга: сэмплы_ориг -> сэмплы_ресампл
                    r_i = (hd.inTTL_timestamps.t(:,1) / hd.si) * (lfp_Fs / orig_Fs);
                    f_i = (hd.inTTL_timestamps.t(:,2) / hd.si) * (lfp_Fs / orig_Fs);
                else
                    % Без ресемплинга: просто сэмплы оригинальных данных
                    r_i = hd.inTTL_timestamps.t(:,1) / hd.si;
                    f_i = hd.inTTL_timestamps.t(:,2) / hd.si;
                end
            else
                r_i = [];
                f_i = [];
            end
            zavp.realStim.r = r_i;
            zavp.realStim.f = f_i;
            zavp.rarStep = hd.ch_si'*0+skip_points;

            % Записываем остальные переменные в файл
            m.chnlGrp = chnlGrp;
            m.hd = hd;
            m.lfpVar = lfpVar;
            m.spks = spks;
            m.zavp = zavp;
            
            waitbar(1, hWaitBar, 'Complete');
            
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
