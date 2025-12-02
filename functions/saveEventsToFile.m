function saveEventsToFile(events, time, matFilePath, varargin)
% saveEventsToFile - Универсальная функция сохранения событий в .ev файл
%
% Использование:
%   saveEventsToFile(events, time, matFilePath)
%   saveEventsToFile(events, time, matFilePath, 'Name', Value, ...)
%
% Обязательные параметры:
%   events - массив времен событий
%   time - временная шкала для преобразования времен в индексы
%   matFilePath - путь к mat файлу (используется для имени файла по умолчанию)
%
% Опциональные параметры (пары 'Name', Value):
%   'event_comments' - массив комментариев к событиям (по умолчанию: {'...'})
%   'event_amplitudes' - массив амплитуд событий
%   'event_channels' - массив каналов событий (может быть вектор или матрица)
%   'event_widths' - массив ширин событий
%   'event_prominences' - массив выраженности событий
%   'event_metadata' - массив структур с метаданными событий
%   'dialogTitle' - заголовок диалога сохранения (по умолчанию: 'Save Events')
%   'defaultFileNameSuffix' - суффикс для имени файла (по умолчанию: '_events')
%   'viewer_data' - структура viewer_data (если не указана, создается автоматически)
%   'matFileName' - имя mat файла (для viewer_data)
%   'autodetection_settings' - настройки автодетекции
%   'add_event_settings' - настройки добавления событий
%   'EV_version' - версия EV

    % Парсинг опциональных параметров
    p = inputParser;
    addParameter(p, 'event_comments', [], @(x) iscell(x) || ischar(x) || isstring(x));
    addParameter(p, 'event_amplitudes', [], @isnumeric);
    addParameter(p, 'event_channels', [], @isnumeric);
    addParameter(p, 'event_widths', [], @isnumeric);
    addParameter(p, 'event_prominences', [], @isnumeric);
    addParameter(p, 'event_metadata', [], @(x) isstruct(x) || iscell(x));
    addParameter(p, 'dialogTitle', 'Save Events', @(x) ischar(x) || isstring(x));
    addParameter(p, 'defaultFileNameSuffix', '_events', @(x) ischar(x) || isstring(x));
    addParameter(p, 'viewer_data', [], @isstruct);
    addParameter(p, 'matFileName', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'autodetection_settings', [], @(x) isstruct(x) || isempty(x));
    addParameter(p, 'add_event_settings', [], @(x) isstruct(x) || isempty(x));
    addParameter(p, 'EV_version', [], @(x) ischar(x) || isstring(x) || isempty(x));
    
    parse(p, varargin{:});
    params = p.Results;
    
    % Инициализация waitbar
    wb = waitbar(0, 'Preparing to save events...', 'Name', 'Saving Events');
    
    % Подготовка имени файла по умолчанию
    waitbar(0.05, wb, 'Preparing file path...');
    [path, name, ~] = fileparts(matFilePath);
    defaultFileName = fullfile(path, [name params.defaultFileNameSuffix '.ev']);
    
    % Диалог выбора файла
    waitbar(0.1, wb, 'Selecting save location...');
    [file, path] = uiputfile('*.ev', params.dialogTitle, defaultFileName);
    if isequal(file, 0)
        close(wb);
        fprintf('File save canceled.\n');
        return;
    end
    filepath = fullfile(path, file);
    
    % Подготовка комментариев
    waitbar(0.15, wb, 'Preparing event comments...');
    if isempty(params.event_comments)
        event_comments = repmat({'...'}, numel(events), 1);
    else
        event_comments = params.event_comments;
        if numel(event_comments) < numel(events)
            event_comments = [event_comments(:); repmat({'...'}, numel(events) - numel(event_comments), 1)];
        end
    end
    
    % Преаллокация структуры manlDet
    waitbar(0.2, wb, 'Allocating memory...');
    clear manlDet
    manlDet(numel(events)) = struct('t', [], 'ch', [], 'subT', [], 'subCh', [], 'sw', [], ...
                                   'amplitude', [], 'channels', [], 'width', [], 'prominence', [], 'metadata', []);
    
    % Заполнение manlDet
    numEvents = numel(events);
    for i = 1:numEvents
        progress = 0.2 + 0.6 * (i / numEvents);
        waitbar(progress, wb, sprintf('Processing event %d of %d...', i, numEvents));
        [~, idx] = min(abs(time - events(i)));
        manlDet(i).t = idx;
        
        % Обработка каналов
        if ~isempty(params.event_channels) && i <= size(params.event_channels, 1)
            if size(params.event_channels, 2) == 1
                manlDet(i).ch = params.event_channels(i);
                manlDet(i).channels = params.event_channels(i);
            else
                manlDet(i).ch = params.event_channels(i, 1);
                manlDet(i).channels = params.event_channels(i, :);
            end
        else
            manlDet(i).ch = 1;
            manlDet(i).channels = 1;
        end
        
        % Амплитуды
        if ~isempty(params.event_amplitudes) && i <= length(params.event_amplitudes)
            manlDet(i).amplitude = params.event_amplitudes(i);
        else
            manlDet(i).amplitude = NaN;
        end
        
        % Ширины
        if ~isempty(params.event_widths) && i <= length(params.event_widths)
            manlDet(i).width = params.event_widths(i);
        else
            manlDet(i).width = NaN;
        end
        
        % Выраженность
        if ~isempty(params.event_prominences) && i <= length(params.event_prominences)
            manlDet(i).prominence = params.event_prominences(i);
        else
            manlDet(i).prominence = NaN;
        end
        
        % Метаданные
        if ~isempty(params.event_metadata) && i <= length(params.event_metadata)
            if iscell(params.event_metadata)
                manlDet(i).metadata = params.event_metadata{i};
            else
                manlDet(i).metadata = params.event_metadata(i);
            end
        else
            manlDet(i).metadata = struct('source', 'unknown');
        end
        
        % Старые поля для совместимости
        manlDet(i).subT = [];
        manlDet(i).subCh = 2;
        manlDet(i).sw = 1;
    end
    
    % Подготовка viewer_data
    waitbar(0.85, wb, 'Preparing metadata...');
    if isempty(params.viewer_data)
        clear viewer_data
        viewer_data.matFileName = params.matFileName;
        viewer_data.matFilePath = matFilePath;
        
        if ~isempty(params.autodetection_settings)
            viewer_data.autodetection_settings = params.autodetection_settings;
        end
        
        if ~isempty(params.add_event_settings)
            viewer_data.add_event_settings = params.add_event_settings;
        end
        
        if ~isempty(params.EV_version)
            viewer_data.EV_version = params.EV_version;
        end
    else
        viewer_data = params.viewer_data;
    end
    
    % Сохранение файла
    waitbar(0.9, wb, 'Saving to file...');
    save(filepath, 'manlDet', 'event_comments', 'viewer_data');
    
    waitbar(1.0, wb, 'Complete');
    close(wb);
    
    fprintf('Saved %d events to %s\n', numel(events), file);
end

