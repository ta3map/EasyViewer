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
    global events event_inx events_exist event_comments
    global event_amplitudes event_channels event_widths event_prominences event_metadata
    global event_title_string
    global time matFilePath
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
            
            [file, path] = uigetfile({'*.ev'; '*.mean'}, 'Load Events', initialDir);
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
    
    % Обработка данных событий
    if isfield(loadedData, 'manlDet')
        events = time(round([loadedData.manlDet.t]))'; % Обновляем таблицу событий
        
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
        fprintf('No events found in the file.\n');
    end
end

