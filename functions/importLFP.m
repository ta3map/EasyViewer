function importLFP()
    % Global variables
    global lastOpenedFiles lfp time N time_forward time_back chosen_time_interval
    global shiftCoeff newFs selectedCenter stim_inx show_spikes show_CSD channelNames
    global numChannels lfpVar matFileName matFilePath Fs
    global call_updateTable
    global call_setStandardChannelSettings
    global call_resetMainWindowButtons
    global spks stims zavp hd
    global new_channelNames new_spks 
    
    % Tag for GUI figure
    figTag = 'importLFP';

    % Search for an open figure with the given tag
    guiFig = findobj('Type', 'figure', 'Tag', figTag);

    if ~isempty(guiFig)
        % Make the existing window the current figure
        figure(guiFig);
        return
    end
    
    % Инициализация переменных
    persistent filepath selectedChannels availableChannels active_folder
    
    if isempty(filepath)
        filepath = '';
    end
    if isempty(selectedChannels)
        selectedChannels = [];
    end
    if isempty(availableChannels)
        availableChannels = {};
    end
    
    % Определяем активную папку
    try
        if ~isempty(lastOpenedFiles)
            active_folder = fileparts(lastOpenedFiles{end});
        else
            active_folder = pwd;
        end
    catch
        active_folder = pwd;
    end
    
    % Initialize GUI
    fig = figure('Name', 'Import data from ZAV(.mat) file', 'NumberTitle', 'off', ...
                  'Position', [100, 100, 600, 600], 'Resize', 'off', ...
                  'MenuBar', 'none', 'ToolBar', 'none', ...
                  'Tag', figTag, 'WindowStyle', 'normal');

    % Позиционные переменные
    leftMargin = 20;
    topMargin = 550;
    btnWidth = 150;
    btnHeight = 25;
    spacing = 10;
    secondcolumnshift = 170;

    % Кнопка для выбора файла
    uicontrol('Parent', fig, 'Style', 'pushbutton', 'String', 'Select ZAV File', ...
              'Position', [leftMargin, topMargin, btnWidth, btnHeight], 'Callback', @selectFile);

    % Метка для отображения выбранного файла
    fileLabel = uicontrol('Parent', fig, 'Style', 'text', 'String', 'No file selected', ...
        'Position', [leftMargin + btnWidth + spacing, topMargin, 400, btnHeight], 'HorizontalAlignment', 'left');

    % Метка для отображения оригинальной частоты дискретизации
    shiftdown = btnHeight + 20;
    FsLabel = uicontrol('Parent', fig, 'Style', 'text', 'String', '...', ...
        'Position', [leftMargin + btnWidth + spacing, topMargin - shiftdown, 400, btnHeight], 'HorizontalAlignment', 'left');

    % Метка для отображения длительности записи
    shiftdown = btnHeight + 40;
    durationLabel = uicontrol('Parent', fig, 'Style', 'text', 'String', '...', ...
        'Position', [leftMargin + btnWidth + spacing, topMargin - shiftdown, 400, btnHeight], 'HorizontalAlignment', 'left');

    % Режим импорта
    shiftdown = 80;
    uicontrol('Parent', fig, 'Style', 'text', 'String', 'Import Mode:', ...
        'Position', [leftMargin, topMargin - (btnHeight + spacing) + 30 - shiftdown, 150, btnHeight], 'HorizontalAlignment', 'right');
    importMode = uicontrol('Parent', fig, 'Style', 'popupmenu', ...
        'Position', [leftMargin + secondcolumnshift, topMargin - (btnHeight + spacing) + 30 - shiftdown, 150, btnHeight], ...
        'String', {'Replace all', 'Append Data'});
    set(importMode, 'Value', 2);

    % Панель для выбора временного интервала
    timePanel = uipanel('Parent', fig, 'Title', 'Select Time Interval', 'Position', [0.05, 0.2, 0.9, 0.12]);

    uicontrol('Parent', timePanel, 'Style', 'text', 'String', 'Start (s):', ...
        'Units', 'normalized', 'Position', [0.05, 0.5, 0.2, 0.4], 'HorizontalAlignment', 'left');
    startTimeBox = uicontrol('Parent', timePanel, 'Style', 'edit', 'String', '0', ...
        'Units', 'normalized', 'Position', [0.3, 0.5, 0.25, 0.4]);

    uicontrol('Parent', timePanel, 'Style', 'text', 'String', 'End (s):', ...
        'Units', 'normalized', 'Position', [0.6, 0.5, 0.2, 0.4], 'HorizontalAlignment', 'left');
    endTimeBox = uicontrol('Parent', timePanel, 'Style', 'edit', 'String', '', ...
        'Units', 'normalized', 'Position', [0.85, 0.5, 0.1, 0.4]);

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

    % Кнопка для запуска импорта
    uicontrol('Parent', fig, 'Style', 'pushbutton', 'String', 'Import', ...
              'Position', [leftMargin + secondcolumnshift, 20, btnWidth, btnHeight], 'Callback', @importData);

    append_start_time = 0;

    % File selection callback function
    function selectFile(~, ~)
        if isempty(active_folder)
            active_folder = pwd;
        end
        [file, path] = uigetfile('*.mat', 'Load ZAV File', active_folder);
        if isequal(file, 0)
            disp('File selection canceled.');
            filepath = '';
            set(fileLabel, 'String', 'No file selected');
            set(FsLabel, 'String', '...');
            set(durationLabel, 'String', '...');
            set(channelTable, 'Data', {});
            availableChannels = {};
            selectedChannels = [];
            return;
        end
        filepath = fullfile(path, file);
        active_folder = path;
        set(fileLabel, 'String', filepath);

        % Load metadata
        try
            info = matfile(filepath);
            lfp_info = whos(info, 'lfp');
            if size(lfp_info.size, 2) == 2
                N = lfp_info.size(1);
            else            
                N = lfp_info.size(1)*lfp_info.size(3);
            end

            data = load(filepath, 'zavp', 'hd', 'spks');
            Fs = data.zavp.dwnSmplFrq;
            new_channelNames = data.hd.recChNames;
            new_spks = data.spks; % ms
            
            availableChannels = new_channelNames;
            numChannels = numel(availableChannels);

            % Подготавливаем данные для таблицы
            channelData = cell(numChannels, 2);
            for i = 1:numChannels
                channelData{i, 1} = true; % По умолчанию все каналы выбраны
                channelData{i, 2} = availableChannels{i};
            end

            % Обновляем таблицу каналов
            set(channelTable, 'Data', channelData);
            selectedChannels = 1:numChannels; % Все каналы выбраны
            
            % Обновляем информацию о файле
            set(FsLabel, 'String', ['Fs (Hz): ', num2str(Fs)]);
            duration = (N-1)/Fs;
            set(durationLabel, 'String', ['Duration: ', num2str(duration), ' s']);
            set(endTimeBox, 'String', num2str(duration));
            
        catch ME
            disp(['Error loading file: ', ME.message]);
            warndlg(['An error occurred while loading file: ', ME.message], 'Loading Error');
            filepath = '';
            set(fileLabel, 'String', 'No file selected');
            set(FsLabel, 'String', '...');
            set(durationLabel, 'String', '...');
            set(channelTable, 'Data', {});
            availableChannels = {};
            selectedChannels = [];
        end
    end

    function channelSelectionCallback(src, event)
        % Обновляем список выбранных каналов при изменении галочек
        channelData = get(src, 'Data');
        selectedChannels = find([channelData{:,1}]);
    end

    function selectAllChannels(~, ~)
        % Выбираем все каналы
        channelData = get(channelTable, 'Data');
        if ~isempty(channelData)
            for i = 1:size(channelData, 1)
                channelData{i, 1} = true;
            end
            set(channelTable, 'Data', channelData);
            selectedChannels = 1:numel(availableChannels);
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
            selectedChannels = [];
        end
    end

    % Import data callback function
    function importData(~, ~)
        % Проверяем, что файл выбран
        try
            currentFilepath = filepath;
        catch
            currentFilepath = '';
        end
        
        if isempty(currentFilepath)
            warndlg('Please load data first. Select a ZAV file before importing.', 'No File Selected', 'modal');
            return;
        end

        try
            currentSelectedChannels = selectedChannels;
        catch
            currentSelectedChannels = [];
        end
        
        if isempty(currentSelectedChannels)
            warndlg('Please select at least one channel.', 'No Channels Selected', 'modal');
            return;
        end

        time_start = str2double(get(startTimeBox, 'String'));
        time_end = str2double(get(endTimeBox, 'String'));

        if isnan(time_start) || isnan(time_end) || time_start < 0 || time_end < time_start
            warndlg('Please enter valid time interval values.', 'Invalid Time Interval', 'modal');
            return;
        end

        start_index = max(1, round(time_start * Fs) + 1); % s
        end_index = min(N, round(time_end * Fs) + 1); % s

        % Load selected data
        d = load(currentFilepath, 'lfp', 'lfpVar', 'zavp');
        new_lfp = d.lfp;
        
        [m, n, p] = size(new_lfp);  % получение размеров исходной матрицы
        if p > 1 % случай со свипами 
            disp('sweep case')
            [new_lfp, new_spks, ~, new_lfpVar, ~] = sweepProcessData(p, new_spks, n, m, new_lfp, Fs, d.zavp, d.lfpVar);
        else            
            new_lfpVar = d.lfpVar(currentSelectedChannels);
        end
        new_lfp = new_lfp(start_index:end_index, currentSelectedChannels);
        
        clear d
        
        mode = get(importMode, 'Value');
        if mode == 1 % Replace all
            if ~isempty(new_lfp)
                lfp = new_lfp;
            end
            if ~isempty(new_lfpVar)
                lfpVar = new_lfpVar;
            end
            try
                currentAvailableChannels = availableChannels;
            catch
                currentAvailableChannels = {};
            end
            if ~isempty(currentAvailableChannels) && ~isempty(currentSelectedChannels)
                channelNames = currentAvailableChannels(currentSelectedChannels)';
            end
            if ~isempty(new_spks) && ~isempty(currentSelectedChannels)
                % Берем только выбранные каналы из spks
                if isstruct(new_spks)
                    spks = new_spks(currentSelectedChannels);
                else
                    spks = new_spks;
                end
            else
                spks = [];
            end
        else % Append Data
            append_start_time = str2double(inputdlg('Enter the start (in seconds) time for appending data:', 'Append Data', 1, {'0'}));
            if isnan(append_start_time)
                append_start_time = 0;
            end
            append_start_index = round(append_start_time * Fs) + 1;
            if append_start_index < 1
                % Shift existing data to the right
                shift_amount = abs(append_start_index) + 1;
                if ~isempty(lfp)
                    lfp = [nan(shift_amount, size(lfp, 2)); lfp];
                end
                append_start_index = 1;
            end
            if ~isempty(new_lfp)
                % Определяем размеры существующего lfp
                if isempty(lfp)
                    numExistingChannels = 0;
                    numExistingSamples = 0;
                else
                    numExistingChannels = size(lfp, 2);
                    numExistingSamples = size(lfp, 1);
                end
                
                % Вычисляем необходимый размер
                requiredRows = size(new_lfp, 1) + append_start_index - 1;
                requiredCols = numExistingChannels + length(currentSelectedChannels);
                
                % Расширяем lfp, если необходимо
                if requiredRows > numExistingSamples || requiredCols > numExistingChannels
                    newRows = max(requiredRows, numExistingSamples);
                    newCols = max(requiredCols, numExistingChannels);
                    if isempty(lfp)
                        lfp = nan(newRows, newCols);
                    else
                        expandedLfp = nan(newRows, newCols);
                        expandedLfp(1:numExistingSamples, 1:numExistingChannels) = lfp;
                        lfp = expandedLfp;
                    end
                end
                
                % Добавляем новые данные
                rowRange = append_start_index:append_start_index + size(new_lfp, 1) - 1;
                colRange = (numExistingChannels + 1):(numExistingChannels + length(currentSelectedChannels));
                lfp(rowRange, colRange) = new_lfp;
            end
            if ~isempty(new_lfpVar)
                lfpVar = [lfpVar; new_lfpVar];
            end
            try
                currentAvailableChannels = availableChannels;
            catch
                currentAvailableChannels = {};
            end
            if ~isempty(channelNames) && ~isempty(currentAvailableChannels) && ~isempty(currentSelectedChannels)
                channelNames = [np_flatten(channelNames)'; np_flatten(currentAvailableChannels(currentSelectedChannels))'];
            end
            if ~isempty(lfp)
                lfp(lfp == 0) = nan;
            end

            if append_start_time < 0
                if ~isempty(new_spks) && ~isempty(currentSelectedChannels)
                    % Создаем временную структуру для выбранных каналов
                    temp_spks = [];
                    for idx = 1:length(currentSelectedChannels)
                        ch_inx = currentSelectedChannels(idx);
                        if ch_inx <= length(new_spks) && ~isempty(new_spks(ch_inx).tStamp)
                            time_cond = new_spks(ch_inx).tStamp / 1000 >= time_start & new_spks(ch_inx).tStamp / 1000 <= time_end;
                            temp_spks(idx).tStamp = new_spks(ch_inx).tStamp(time_cond); % ms
                            temp_spks(idx).ampl = new_spks(ch_inx).ampl(time_cond);
                            if isfield(new_spks, 'shape') && isfield(new_spks(ch_inx), 'shape') && ~isempty(new_spks(ch_inx).shape)
                                try
                                    shape_data = new_spks(ch_inx).shape;
                                    if isnumeric(shape_data) && numel(shape_data) == length(new_spks(ch_inx).tStamp)
                                        temp_spks(idx).shape = shape_data(time_cond);
                                    else
                                        temp_spks(idx).shape = [];
                                    end
                                catch
                                    temp_spks(idx).shape = [];
                                end
                            else
                                temp_spks(idx).shape = [];
                            end
                        else
                            temp_spks(idx).tStamp = [];
                            temp_spks(idx).ampl = [];
                            if isfield(new_spks, 'shape')
                                temp_spks(idx).shape = [];
                            end
                        end
                    end
                    new_spks = temp_spks;
                end

                if ~isempty(spks)
                    for ch_inx = 1:numel(spks)
                        if ~isempty(spks(ch_inx).tStamp)
                            spks(ch_inx).tStamp = spks(ch_inx).tStamp - append_start_time * 1000;
                        end
                    end
                end

                if ~isempty(stims)
                    stims = stims - append_start_time;
                end
                % Обратное помещение измененных значений в структуру zavp
                if ~isempty(zavp) && ~isempty(stims)
                    for i = 1:length(zavp.realStim)
                        zavp.realStim(i).r(:) = stims((i-1)*length(zavp.realStim(i).r)+1:i*length(zavp.realStim(i).r)) / zavp.siS;
                    end
                end
            else
                if ~isempty(new_spks) && ~isempty(currentSelectedChannels)
                    % Создаем временную структуру для выбранных каналов
                    temp_spks = [];
                    for idx = 1:length(currentSelectedChannels)
                        ch_inx = currentSelectedChannels(idx);
                        if ch_inx <= length(new_spks) && ~isempty(new_spks(ch_inx).tStamp)
                            time_cond = new_spks(ch_inx).tStamp / 1000 >= time_start & new_spks(ch_inx).tStamp / 1000 <= time_end;
                            temp_spks(idx).tStamp = new_spks(ch_inx).tStamp(time_cond) + append_start_time * 1000; % ms
                            temp_spks(idx).ampl = new_spks(ch_inx).ampl(time_cond);
                            if isfield(new_spks, 'shape') && isfield(new_spks(ch_inx), 'shape') && ~isempty(new_spks(ch_inx).shape)
                                try
                                    shape_data = new_spks(ch_inx).shape;
                                    if isnumeric(shape_data) && numel(shape_data) == length(new_spks(ch_inx).tStamp)
                                        temp_spks(idx).shape = shape_data(time_cond);
                                    else
                                        temp_spks(idx).shape = [];
                                    end
                                catch
                                    temp_spks(idx).shape = [];
                                end
                            else
                                temp_spks(idx).shape = [];
                            end
                        else
                            temp_spks(idx).tStamp = [];
                            temp_spks(idx).ampl = [];
                            if isfield(new_spks, 'shape')
                                temp_spks(idx).shape = [];
                            end
                        end
                    end
                    new_spks = temp_spks;
                end
            end

            if ~isempty(new_spks) && ~isempty(currentSelectedChannels)
                if isempty(spks)
                    spks = new_spks;
                else
                    % Объединяем структуры поэлементно для избежания проблем с размерами
                    num_existing = length(spks);
                    num_new = length(new_spks);
                    
                    % Убеждаемся, что структуры имеют одинаковые поля
                    spks_fields = fieldnames(spks);
                    new_spks_fields = fieldnames(new_spks);
                    all_fields = unique([spks_fields; new_spks_fields]);
                    
                    % Добавляем недостающие поля в существующую структуру
                    for i = 1:num_existing
                        for j = 1:length(all_fields)
                            if ~isfield(spks(i), all_fields{j})
                                spks(i).(all_fields{j}) = [];
                            end
                        end
                    end
                    
                    % Добавляем недостающие поля в новую структуру и объединяем
                    for i = 1:num_new
                        for j = 1:length(all_fields)
                            if ~isfield(new_spks(i), all_fields{j})
                                new_spks(i).(all_fields{j}) = [];
                            end
                        end
                        % Добавляем каждый элемент новой структуры к существующей
                        spks(num_existing + i) = new_spks(i);
                    end
                end
            end
        end

        
        % Обновляем hd.recChNames и numChannels
        if ~isempty(channelNames)
            hd.recChNames = channelNames';
            numChannels = length(channelNames);
        else
            % Если channelNames пуст, используем количество столбцов в lfp
            numChannels = size(lfp, 2);
            if numChannels > 0
                hd.recChNames = cell(numChannels, 1);
                for i = 1:numChannels
                    hd.recChNames{i} = ['Channel ' num2str(i)];
                end
                channelNames = hd.recChNames';
            end
        end
        
        % Убеждаемся, что numChannels соответствует размеру lfp
        if size(lfp, 2) ~= numChannels
            numChannels = size(lfp, 2);
            if numChannels > 0 && (isempty(channelNames) || length(channelNames) ~= numChannels)
                hd.recChNames = cell(numChannels, 1);
                for i = 1:numChannels
                    if i <= length(channelNames)
                        hd.recChNames{i} = channelNames{i};
                    else
                        hd.recChNames{i} = ['Channel ' num2str(i)];
                    end
                end
                channelNames = hd.recChNames';
            end
        end

        % Update time and other settings
        N = size(lfp, 1);
        time = (0:N-1) / Fs;

        time_forward = 0.6;
        time_back = 0.6;
        chosen_time_interval = [0, time_forward];
        shiftCoeff = 200;
        newFs = 1000;
        selectedCenter = 'time';
        stim_inx = 1;
        show_spikes = false;
        show_CSD = false;

        % Update file path with selected channels
        [folder, matFileName, ext] = fileparts(currentFilepath);
        try
            currentAvailableChannels = availableChannels;
        catch
            currentAvailableChannels = {};
        end
        if ~isempty(currentAvailableChannels) && ~isempty(currentSelectedChannels)
            matFilePath = [folder, '\', matFileName ' ' [currentAvailableChannels{currentSelectedChannels}], ext];
        else
            matFilePath = currentFilepath;
        end
        [~, matFileName, ~] = fileparts(matFilePath);

        % Инициализируем sweep_info, если она не определена
        global sweep_info sweep_inx
        if ~exist('sweep_info', 'var') || isempty(sweep_info) || ~isstruct(sweep_info)
            sweep_info = struct();
            sweep_info.is_sweep_data = false;
        end
        if ~exist('sweep_inx', 'var') || isempty(sweep_inx)
            sweep_inx = 1;
        end

        % Call external functions
        call_setStandardChannelSettings();
        call_updateTable();
        updatePlot();
        call_resetMainWindowButtons();

        close(fig);
    end
end
