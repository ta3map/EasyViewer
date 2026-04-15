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
    persistent recordPath zavFilePath detectMua mua_std_coef lfp_Fs doResample selectedChannels availableChannels channelNumbers channelFilePaths active_folder channelBytes

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

    btnDeselectEmpty = uicontrol('Parent', channelPanel, 'Style', 'pushbutton', 'String', 'Deselect empty channels', ...
        'Units', 'normalized', 'Position', [0.34, 0.92, 0.22, 0.06], 'Callback', @deselectEmptyChannels);

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
            channelFilePaths = {};
            channelBytes = [];
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
        wb = waitbar(0, 'Loading Neuralynx channels...', 'Name', 'Loading Channels');

        if (recordPath(end) ~= '\')
            recordPath(end + 1) = '\';
        end

        waitbar(0.1, wb, 'Scanning for .ncs files...');

        dirCnt = dir(recordPath);
        ncsFiles = struct('f', {}, 'chNum', {}, 'chName', {}, 'bytes', {});

        for t = 1:length(dirCnt)
            if ((~dirCnt(t).isdir) && (length(dirCnt(t).name) > 3))
                if isequal(dirCnt(t).name(end - 3:end), '.ncs')
                    fileName = dirCnt(t).name(1:end-4);
                    numMatch = regexp(fileName, '\d+$', 'match');
                    if ~isempty(numMatch)
                        ch = str2double(numMatch{1});
                        if ~isnan(ch)
                            ncsFiles(end + 1).f = fullfile(recordPath, dirCnt(t).name);
                            ncsFiles(end).chNum = ch;
                            ncsFiles(end).chName = fileName;
                            ncsFiles(end).bytes = dirCnt(t).bytes;
                        end
                    end
                end
            end
        end

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
            channelFilePaths = {};
            channelBytes = [];
            set(FsOrigLabel, 'String', '...');
            set(channelTable, 'Data', {});
            return;
        end

        waitbar(0.2, wb, 'Reading header (Fs)...');
        channelNames = cell(length(ncsFiles), 1);
        channelNums = zeros(length(ncsFiles), 1);
        for i = 1:length(ncsFiles)
            channelNames{i} = ncsFiles(i).chName;
            channelNums(i) = ncsFiles(i).chNum;
        end
        orig_Fs = [];
        if ~isempty(ncsFiles) && exist(ncsFiles(1).f, 'file')
            cscHd = Nlx2MatCSC(ncsFiles(1).f, [0 0 0 0 0], 1, 1, []);
            orig_Fs = NlxParametr(cscHd, 'SamplingFrequency');
        end

        waitbar(0.9, wb, 'Updating channel list...');

        availableChannels = channelNames;
        channelNumbers = channelNums;
        channelFilePaths = {ncsFiles.f};
        channelBytes = [ncsFiles.bytes];
        numChannels = numel(availableChannels);

        channelData = cell(numChannels, 2);
        for i = 1:numChannels
            channelData{i, 1} = true;
            channelData{i, 2} = availableChannels{i};
        end

        set(channelTable, 'Data', channelData);
        selectedChannels = availableChannels;

        if ~isempty(orig_Fs)
            set(FsOrigLabel, 'String', ['Fs (Hz): ', num2str(orig_Fs)]);
        else
            set(FsOrigLabel, 'String', 'Fs (Hz): N/A');
        end

        waitbar(1, wb, 'Complete');
        close(wb);
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

    function deselectEmptyChannels(~, ~)
        % Снимает выделение с каналов, у которых файл 16 КБ (пустой)
        if isempty(channelBytes)
            return;
        end
        channelData = get(channelTable, 'Data');
        if isempty(channelData)
            return;
        end
        emptyThreshold = 16 * 1024;
        for i = 1:min(size(channelData, 1), numel(channelBytes))
            if channelBytes(i) <= emptyThreshold
                channelData{i, 1} = false;
            end
        end
        set(channelTable, 'Data', channelData);
        selectedChannelIndices = find([channelData{:, 1}]);
        selectedChannels = availableChannels(selectedChannelIndices);
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

        hWaitBar = waitbar(0, 'Initializing conversion...', 'Name', 'Neuralynx to ZAV Conversion');

        channels_n = numel(channels_list);
            ncsFilePaths = channelFilePaths(selectedChannelIndices);
            conversion_tic = tic;
            formatEta = @(sec) sprintf('~%d min %d s left', floor(sec / 60), round(rem(sec, 60)));

            m = matfile(zavFilePath, 'Writable', true);
            spks(channels_n) = struct('tStamp', [], 'ampl', [], 'shape', []);
            lfpVar = zeros(1, channels_n);
            hd = [];

            for ch_inx = 1:channels_n
                if ch_inx == 1
                    [data, ~, hd_one] = ZavNrlynx2(recordPath, [], channels_list(1), [], [], ncsFilePaths(1));
                    orig_Fs = 1e6 / hd_one.si;
                    if doResample
                        lfp_length = floor(size(data, 1) * lfp_Fs / orig_Fs);
                    else
                        lfp_length = size(data, 1);
                    end
                    waitbar(0, hWaitBar, 'Initializing MAT file...');
                    m.lfp(lfp_length, channels_n) = single(0);
                    hd = hd_one;
                    hd.nADCNumChannels = channels_n;
                else
                    [data, ~, hd_one] = ZavNrlynx2(recordPath, [], channels_list(ch_inx), [], [], ncsFilePaths(ch_inx));
                    hd.adBitVolts = [hd.adBitVolts; hd_one.adBitVolts];
                    hd.dspDelay_mks = [hd.dspDelay_mks; hd_one.dspDelay_mks];
                    hd.adBitVoltsSpk = [hd.adBitVoltsSpk; hd_one.adBitVoltsSpk];
                    hd.dspDelay_mksSpk = [hd.dspDelay_mksSpk; hd_one.dspDelay_mksSpk];
                    hd.alignmentPt = [hd.alignmentPt; hd_one.alignmentPt];
                    hd.inverted = [hd.inverted; hd_one.inverted];
                    hd.recChUnits = [hd.recChUnits; hd_one.recChUnits];
                    hd.recChNames = [hd.recChNames; hd_one.recChNames];
                    hd.ch_si = [hd.ch_si; hd_one.ch_si];
                end

                data_col = data(:);

                hd_ch.adBitVolts = hd_one.adBitVolts(1);
                hd_ch.dspDelay_mks = hd_one.dspDelay_mks(1);
                hd_ch.si = hd_one.si;
                hd_ch.fADCSampleInterval = hd_one.fADCSampleInterval;
                hd_ch.recChNames = hd_one.recChNames(1);
                hd_ch.recChUnits = hd_one.recChUnits(1);
                hd_ch.inTTL_timestamps = hd_one.inTTL_timestamps;

                if detectMua
                    [tStamp, ampl, shape] = detectMUAzav(data_col, hd_ch, mua_std_coef, true);
                    spks(ch_inx).tStamp = single(tStamp);
                    spks(ch_inx).ampl = single(ampl);
                    spks(ch_inx).shape = shape;
                else
                    spks(ch_inx).tStamp = single([]);
                    spks(ch_inx).ampl = single([]);
                    spks(ch_inx).shape = [];
                end

                if doResample
                    data_processed = resample1(data_col, lfp_Fs, orig_Fs);
                else
                    data_processed = data_col;
                end
                data_processed = data_processed(:);

                if length(data_processed) > lfp_length
                    data_processed = data_processed(1:lfp_length);
                elseif length(data_processed) < lfp_length
                    data_processed = [data_processed; zeros(lfp_length - length(data_processed), 1)];
                end

                lfpVar(ch_inx) = std(data_processed) / 10;
                m.lfp(:, ch_inx) = single(data_processed);

                elapsed = toc(conversion_tic);
                remain_sec = (ch_inx > 0) * (elapsed / ch_inx) * (channels_n - ch_inx);
                waitbar(ch_inx / channels_n, hWaitBar, sprintf('%d/%d: Channel %d %s', ch_inx, channels_n, ch_inx, formatEta(remain_sec)));
                clear data;
            end

            hd.chNumList = channels_list(:)';
            
            waitbar(0.95, hWaitBar, 'Finalizing data...');
            lfpVar = np_flatten(lfpVar)';

            if doResample
                actual_Fs = lfp_Fs;
                skip_points = orig_Fs / lfp_Fs;
            else
                actual_Fs = orig_Fs;
                skip_points = 1;
            end
            
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
    end
end
