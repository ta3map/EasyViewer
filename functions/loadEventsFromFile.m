function loadEventsFromFile(filepath, options)
    % Универсальная функция загрузки событий из файла
    % Использует только глобальные переменные и callback функции
    % 
    % Параметры:
    %   filepath - путь к файлу событий (опционально, если не указан - запрашивается диалог)
    %   options - структура с опциями (опционально):
    %     .skip_mode_change - если true, не меняет selectedCenter на 'events'
    %     .skip_callbacks - если true, не вызывает callback функции
    
    % Глобальные переменные для данных
    global events event_inx events_exist event_comments event_indices
    global event_amplitudes event_channels event_widths event_prominences event_metadata
    global event_title_string lastEventsFilePath
    global time matFilePath Fs
    global selectedCenter chosen_time_interval time_forward
    global lastOpenedFiles outside_calling_filepath
    
    % Глобальные callback функции
    global table_calling zav_calling
    
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
    if ~isfield(options, 'gui_tag')
        options.gui_tag = 'SignalViewerGUI';
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
            
            [file, path] = uigetfile({'*.ev;*.mean', 'Event files (*.ev, *.mean)'}, 'Load Events', initialDir);
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
        loadedIndices = round([loadedData.manlDet.t])';
        loadedTimes = time(loadedIndices(:));

        loadedComments = {};
        if isfield(loadedData, 'event_comments')
            loadedComments = loadedData.event_comments;
        end

        loadedAmps = [];
        if isfield(loadedData.manlDet, 'amplitude')
            loadedAmps = [loadedData.manlDet.amplitude]';
        end

        loadedChannels = [];
        if isfield(loadedData.manlDet, 'channels')
            first_channels = loadedData.manlDet(1).channels;
            if isscalar(first_channels)
                loadedChannels = [loadedData.manlDet.channels]';
            else
                max_channels = max(cellfun(@length, {loadedData.manlDet.channels}));
                loadedChannels = NaN(length(loadedTimes), max_channels);
                for i = 1:length(loadedTimes)
                    chs = loadedData.manlDet(i).channels;
                    loadedChannels(i, 1:length(chs)) = chs;
                end
            end
        elseif isfield(loadedData.manlDet, 'ch')
            loadedChannels = [loadedData.manlDet.ch]';
        end

        loadedWidths = [];
        if isfield(loadedData.manlDet, 'width')
            loadedWidths = [loadedData.manlDet.width]';
        end

        loadedProm = [];
        if isfield(loadedData.manlDet, 'prominence')
            loadedProm = [loadedData.manlDet.prominence]';
        end

        loadedMeta = [];
        if isfield(loadedData.manlDet, 'metadata')
            loadedMeta = {loadedData.manlDet.metadata};
        end

        setEventsState(loadedTimes, ...
            'indices', loadedIndices(:), ...
            'comments', loadedComments, ...
            'amplitudes', loadedAmps, ...
            'channels', loadedChannels, ...
            'widths', loadedWidths, ...
            'prominences', loadedProm, ...
            'metadata', loadedMeta, ...
            'source', 'loaded', ...
            'title', file, ...
            'event_inx', 1, ...
            'sync', ~options.skip_callbacks);

        lastEventsFilePath = filepath;

        if ~options.skip_mode_change
            selectedCenter = 'events';
        end

        if exist('time_forward', 'var') && ~isempty(time_forward) && ~isempty(events)
            chosen_time_interval(1) = events(event_inx);
            chosen_time_interval(2) = events(event_inx) + time_forward;
        end

        if ~options.skip_callbacks
            guiSessionCallback(options.gui_tag, 'updatePlot');
        end

        fprintf('✓ Events loaded: %d events from %s\n', length(events), file);
    else
        event_indices = [];
        fprintf('No events found in the file.\n');
    end
end
