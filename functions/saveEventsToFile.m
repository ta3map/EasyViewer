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
%   'saveExcel' - сохранить также в Excel файл (по умолчанию: false)

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
    addParameter(p, 'saveExcel', false, @islogical);
    
    parse(p, varargin{:});
    params = p.Results;
    
    % Инициализация waitbar
    wb = waitbar(0, 'Preparing to save events...', 'Name', 'Saving Events');
    
    % Подготовка имени файла по умолчанию
    waitbar(0.05, wb, 'Preparing file path...');
    [path, name, ~] = fileparts(matFilePath);
    
    % Диалог выбора файла в зависимости от формата
    waitbar(0.1, wb, 'Selecting save location...');
    if params.saveExcel
        defaultFileName = fullfile(path, [name params.defaultFileNameSuffix '.xlsx']);
        [file, path] = uiputfile('*.xlsx', params.dialogTitle, defaultFileName);
        if isequal(file, 0)
            close(wb);
            fprintf('File save canceled.\n');
            return;
        end
        filepath = fullfile(path, file);
    else
        defaultFileName = fullfile(path, [name params.defaultFileNameSuffix '.ev']);
        [file, path] = uiputfile('*.ev', params.dialogTitle, defaultFileName);
        if isequal(file, 0)
            close(wb);
            fprintf('File save canceled.\n');
            return;
        end
        filepath = fullfile(path, file);
    end
    
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
    if params.saveExcel
        % Сохранение только в Excel
        waitbar(0.92, wb, 'Preparing Excel file...');
        excelPath = filepath;
        
        try
            % Подготовка данных для листа Raw Data
            waitbar(0.94, wb, 'Preparing raw data...');
            rawData = cell(numEvents + 1, 7);
            rawData(1, :) = {'Event Index', 'Time (s)', 'Channel(s)', 'Amplitude', 'Width', 'Prominence', 'Comment'};
            
            for i = 1:numEvents
                rawData{i+1, 1} = i;
                rawData{i+1, 2} = events(i);
                
                % Обработка каналов
                if isscalar(manlDet(i).channels)
                    rawData{i+1, 3} = manlDet(i).channels;
                else
                    channelsStr = mat2str(manlDet(i).channels);
                    rawData{i+1, 3} = channelsStr;
                end
                
                rawData{i+1, 4} = manlDet(i).amplitude;
                rawData{i+1, 5} = manlDet(i).width;
                rawData{i+1, 6} = manlDet(i).prominence;
                
                if i <= length(event_comments)
                    if iscell(event_comments)
                        rawData{i+1, 7} = event_comments{i};
                    else
                        rawData{i+1, 7} = event_comments(i);
                    end
                else
                    rawData{i+1, 7} = '...';
                end
            end
            
            % Запись листа Raw Data
            waitbar(0.96, wb, 'Writing raw data to Excel...');
            writecell(rawData, excelPath, 'Sheet', 'Raw Data');
            
            % Подготовка статистики
            waitbar(0.97, wb, 'Calculating statistics...');
            statsData = cell(1, 9);
            statsData(1, :) = {'Parameter', 'Count', 'Mean', 'Std', 'Median', 'Q25', 'Q75', 'Min', 'Max'};
            row = 2;
            
            % Статистика по времени событий
            timeStats = calculateVectorStatistics(events);
            statsData{row, 1} = 'Time (s)';
            statsData{row, 2} = timeStats.count;
            statsData{row, 3} = timeStats.mean;
            statsData{row, 4} = timeStats.std;
            statsData{row, 5} = timeStats.median;
            statsData{row, 6} = timeStats.q25;
            statsData{row, 7} = timeStats.q75;
            statsData{row, 8} = timeStats.min;
            statsData{row, 9} = timeStats.max;
            row = row + 1;
            
            % Статистика по интервалам между событиями (среднее время между событиями)
            intervals = diff(events);
            intervalStats = calculateVectorStatistics(intervals);
            statsData{row, 1} = 'Inter-event interval (s)';
            statsData{row, 2} = intervalStats.count;
            statsData{row, 3} = intervalStats.mean;
            statsData{row, 4} = intervalStats.std;
            statsData{row, 5} = intervalStats.median;
            statsData{row, 6} = intervalStats.q25;
            statsData{row, 7} = intervalStats.q75;
            statsData{row, 8} = intervalStats.min;
            statsData{row, 9} = intervalStats.max;
            row = row + 1;
            
            % Статистика по амплитудам
            amplitudes = [manlDet.amplitude]';
            if ~all(isnan(amplitudes))
                ampStats = calculateVectorStatistics(amplitudes);
                statsData{row, 1} = 'Amplitude';
                statsData{row, 2} = ampStats.count;
                statsData{row, 3} = ampStats.mean;
                statsData{row, 4} = ampStats.std;
                statsData{row, 5} = ampStats.median;
                statsData{row, 6} = ampStats.q25;
                statsData{row, 7} = ampStats.q75;
                statsData{row, 8} = ampStats.min;
                statsData{row, 9} = ampStats.max;
                row = row + 1;
            end
            
            % Статистика по ширинам
            widths = [manlDet.width]';
            if ~all(isnan(widths))
                widthStats = calculateVectorStatistics(widths);
                statsData{row, 1} = 'Width';
                statsData{row, 2} = widthStats.count;
                statsData{row, 3} = widthStats.mean;
                statsData{row, 4} = widthStats.std;
                statsData{row, 5} = widthStats.median;
                statsData{row, 6} = widthStats.q25;
                statsData{row, 7} = widthStats.q75;
                statsData{row, 8} = widthStats.min;
                statsData{row, 9} = widthStats.max;
                row = row + 1;
            end
            
            % Статистика по выраженности
            prominences = [manlDet.prominence]';
            if ~all(isnan(prominences))
                promStats = calculateVectorStatistics(prominences);
                statsData{row, 1} = 'Prominence';
                statsData{row, 2} = promStats.count;
                statsData{row, 3} = promStats.mean;
                statsData{row, 4} = promStats.std;
                statsData{row, 5} = promStats.median;
                statsData{row, 6} = promStats.q25;
                statsData{row, 7} = promStats.q75;
                statsData{row, 8} = promStats.min;
                statsData{row, 9} = promStats.max;
                row = row + 1;
            end
            
            % Статистика по каналам (первый канал или среднее для многоканальных)
            channels = zeros(numEvents, 1);
            for i = 1:numEvents
                if isscalar(manlDet(i).channels)
                    channels(i) = manlDet(i).channels;
                else
                    channels(i) = mean(manlDet(i).channels(~isnan(manlDet(i).channels) & ~isinf(manlDet(i).channels)));
                end
            end
            chStats = calculateVectorStatistics(channels);
            statsData{row, 1} = 'Channel';
            statsData{row, 2} = chStats.count;
            statsData{row, 3} = chStats.mean;
            statsData{row, 4} = chStats.std;
            statsData{row, 5} = chStats.median;
            statsData{row, 6} = chStats.q25;
            statsData{row, 7} = chStats.q75;
            statsData{row, 8} = chStats.min;
            statsData{row, 9} = chStats.max;
            
            % Запись листа Statistics
            waitbar(0.98, wb, 'Writing statistics to Excel...');
            writecell(statsData, excelPath, 'Sheet', 'Statistics');
            
            fprintf('Saved Excel file to %s\n', excelPath);
        catch ME
            fprintf('Warning: Failed to save Excel file: %s\n', ME.message);
        end
        fprintf('Saved %d events to %s\n', numel(events), file);
    else
        % Сохранение только в .ev файл
        waitbar(0.9, wb, 'Saving to file...');
        save(filepath, 'manlDet', 'event_comments', 'viewer_data');
        fprintf('Saved %d events to %s\n', numel(events), file);
    end
    
    waitbar(1.0, wb, 'Complete');
    close(wb);
end

