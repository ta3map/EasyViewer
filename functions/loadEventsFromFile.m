function loadEventsFromFile(filepath, options)
    % Универсальная функция загрузки событий из файла
    % Использует только глобальные переменные и callback функции
    % 
    % Параметры:
    %   filepath - путь к файлу событий (опционально, если не указан - запрашивается диалог)
    %   options - структура с опциями (опционально):
    %     .skip_mode_change - если true, не меняет selectedCenter на 'event'
    %     .skip_callbacks - если true, не вызывает callback функции
    
    % Глобальные переменные для данных
    global events event_inx events_exist event_comments event_indices
    global event_amplitudes event_channels event_widths event_prominences event_metadata
    global event_title_string
    global time matFilePath Fs spks
    global selectedCenter chosen_time_interval time_forward
    global lastOpenedFiles outside_calling_filepath
    
    % Глобальные callback функции
    global table_calling zav_calling updatePlotFunc
    
    % Обработка опций
    if nargin < 2
        options = struct();
    end
    if ~isfield(options, 'skip_mode_change')
        options.skip_mode_change = false;
    end
    if ~isfield(options, 'skip_callbacks')
        options.skip_callbacks = false;
    end
    
    % Если filepath не передан, запрашиваем у пользователя
    if nargin < 1 || isempty(filepath)
        if ~isempty(outside_calling_filepath)
            filepath = outside_calling_filepath;
            outside_calling_filepath = [];
        else
            initialDir = pwd;
            if exist('lastOpenedFiles', 'var') && ~isempty(lastOpenedFiles)
                initialDir = fileparts(lastOpenedFiles{end});
            end
            
            [file, path] = uigetfile({'*.ev;*.mua;*.mean', 'Event files (*.ev, *.mua, *.mean)'}, 'Load Events', initialDir);
            if isequal(file, 0)
                disp('File selection canceled.');
                return;
            end
            filepath = fullfile(path, file);
        end
    end
    
    % Загружаем данные
    try
        loadedData = load(filepath, '-mat');
    catch ME
        fprintf('Error loading events file: %s\n', ME.message);
        return;
    end
    
    [path, file, ext] = fileparts(filepath);
    file = [file, ext];
    
    % Если не был загружен mat файл, инициируем поиск
    if ~exist('time', 'var') || isempty(time)
        [~, evfilename, ~] = fileparts(filepath);
        if length(evfilename) >= 19
            fileName = evfilename(1:19);
            firstMatFile = findFirstMatFile(path, fileName);
            if ~isempty(firstMatFile) && exist('zav_calling', 'var') && ~isempty(zav_calling)
                zav_calling(firstMatFile);
            end
        end
    end
    
    % Проверяем наличие time для конвертации индексов
    if ~exist('time', 'var') || isempty(time)
        fprintf('Error: time variable not available. Please load .mat file first.\n');
        return;
    end
    
    is_mua_file = strcmpi(ext, '.mua');
    if is_mua_file || isfield(loadedData, 'spks')
        if isfield(loadedData, 'spks')
            spks = loadedData.spks;
            loaded_count = sum(cellfun(@numel, {spks.tStamp}));
        elseif isfield(loadedData, 'manlDet')
            [spks, loaded_count] = assign_mua_to_spks(loadedData.manlDet, Fs, spks);
        else
            loaded_count = 0;
        end
        events = [];
        event_indices = [];
        event_comments = {};
        event_amplitudes = [];
        event_channels = [];
        event_widths = [];
        event_prominences = [];
        event_metadata = [];
        events_exist = false;
        event_inx = 1;
        event_title_string = [file ' (MUA)'];

        if ~options.skip_callbacks && exist('updatePlotFunc', 'var') && ~isempty(updatePlotFunc)
            try
                updatePlotFunc();
            catch ME
                warning('Error calling updatePlotFunc: %s', ME.message);
            end
        end
        fprintf('✓ MUA loaded: %d spikes from %s\n', loaded_count, file);
        return;
    end

    % Обработка данных событий
    if isfield(loadedData, 'manlDet')
        event_indices = round([loadedData.manlDet.t])';
        events = time(event_indices)';
        
        % Загрузка комментариев
        if ~isfield(loadedData, 'event_comments') % если комментариев не было
            event_comments = repmat({'...'}, numel(events), 1); % Инициализация комментариев
        else % если были комментарии
            event_comments = loadedData.event_comments;
        end
        
        % Загрузка новых полей с обратной совместимостью
        if isfield(loadedData.manlDet, 'amplitude')
            event_amplitudes = [loadedData.manlDet.amplitude]';
        else
            event_amplitudes = NaN(size(events)); % default для старых файлов
            disp('Old format detected: amplitude data not available');
        end
        
        if isfield(loadedData.manlDet, 'channels')
            % Проверяем, одноканальные или многоканальные данные
            first_channels = loadedData.manlDet(1).channels;
            if isscalar(first_channels)
                event_channels = [loadedData.manlDet.channels]';
            else
                % Многоканальные данные - собираем в матрицу
                max_channels = max(cellfun(@length, {loadedData.manlDet.channels}));
                event_channels = NaN(length(events), max_channels);
                for i = 1:length(events)
                    chs = loadedData.manlDet(i).channels;
                    event_channels(i, 1:length(chs)) = chs;
                end
            end
        elseif isfield(loadedData.manlDet, 'ch')
            event_channels = [loadedData.manlDet.ch]'; % Используем старое поле ch
        else
            event_channels = ones(size(events)); % default
            disp('Old format detected: channel data not available');
        end
        
        if isfield(loadedData.manlDet, 'width')
            event_widths = [loadedData.manlDet.width]';
        else
            event_widths = NaN(size(events)); % default для старых файлов
            disp('Old format detected: width data not available');
        end
        
        if isfield(loadedData.manlDet, 'prominence')
            event_prominences = [loadedData.manlDet.prominence]';
        else
            event_prominences = NaN(size(events)); % default для старых файлов
            disp('Old format detected: prominence data not available');
        end
        
        if isfield(loadedData.manlDet, 'metadata')
            event_metadata = [loadedData.manlDet.metadata]';
        else
            % Создаем default metadata для старых файлов
            event_metadata = createDefaultEventMetadata('loaded', length(events));
            disp('Old format detected: metadata not available');
        end
        
        event_title_string = file;
        events_exist = true;
        event_inx = 1;
        
        % Устанавливаем режим 'event' если нужно
        if ~options.skip_mode_change
            selectedCenter = 'event';
        end
        
        % Обновляем временной интервал
        if exist('time_forward', 'var') && ~isempty(time_forward)
            chosen_time_interval(1) = events(event_inx);
            chosen_time_interval(2) = events(event_inx) + time_forward;
        end
        
        % Вызываем callback функции если они установлены и не пропущены
        if ~options.skip_callbacks
            if exist('table_calling', 'var') && ~isempty(table_calling)
                try
                    table_calling();
                catch ME
                    warning('Error calling table_calling: %s', ME.message);
                end
            end
            
            if exist('updatePlotFunc', 'var') && ~isempty(updatePlotFunc)
                try
                    updatePlotFunc();
                catch ME
                    warning('Error calling updatePlotFunc: %s', ME.message);
                end
            end
        end
        
        fprintf('✓ Events loaded: %d events from %s\n', length(events), file);
    else
        event_indices = [];
        fprintf('No events found in the file.\n');
    end
end

function [spks_out, loaded_count] = assign_mua_to_spks(manlDet, Fs, spks_in)
    loaded_count = 0;
    spks_out = spks_in;

    if isempty(manlDet) || isempty(Fs) || ~isfinite(Fs) || Fs <= 0
        return;
    end

    event_indices = round([manlDet.t])';
    event_indices = max(1, event_indices);
    tStampMs = ((double(event_indices) - 1) ./ Fs) * 1000;
    loaded_count = numel(tStampMs);

    if isfield(manlDet, 'amplitude')
        amplitudes = [manlDet.amplitude]';
    else
        amplitudes = NaN(size(event_indices));
    end

    if isfield(manlDet, 'channels')
        raw_channels = [manlDet.channels]';
    elseif isfield(manlDet, 'ch')
        raw_channels = [manlDet.ch]';
    else
        raw_channels = ones(size(event_indices));
    end

    mua_channels = round(raw_channels);
    mua_channels(~isfinite(mua_channels) | mua_channels < 1) = 1;

    maxChannel = max(mua_channels);
    emptySpk = struct('tStamp', [], 'ampl', [], 'shape', []);
    spks_out = repmat(emptySpk, maxChannel, 1);

    [sortedChannels, sortOrder] = sort(mua_channels);
    sortedTime = tStampMs(sortOrder);
    sortedAmpl = amplitudes(sortOrder);
    channelBoundaries = [1; find(diff(sortedChannels) > 0) + 1; numel(sortedChannels) + 1];

    for b = 1:(numel(channelBoundaries) - 1)
        startIdx = channelBoundaries(b);
        endIdx = channelBoundaries(b + 1) - 1;
        ch = sortedChannels(startIdx);
        spks_out(ch).tStamp = sortedTime(startIdx:endIdx);
        spks_out(ch).ampl = sortedAmpl(startIdx:endIdx);
    end
end

