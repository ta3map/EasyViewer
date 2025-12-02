function data = load_zav_file(filepath, varargin)
% LOAD_ZAV_FILE - Загрузка ZAV файлов с сохранением всех нюансов
%
% Входные параметры:
%   filepath - путь к .mat файлу (ZAV или Heka формат)
%   varargin - дополнительные параметры:
%       'load_events' - загружать ли события (по умолчанию false)
%       'load_settings' - загружать ли настройки каналов (по умолчанию false)
%       'auto_set_time_windows' - автоматически устанавливать временные окна для свипов (по умолчанию true)
%       'auto_set_fs' - автоматически устанавливать newFs на основе Fs (по умолчанию true)
%
% Выходные параметры:
%   data - структура с полями:
%       lfp - матрица LFP данных
%       spks - данные спайков
%       hd - заголовок записи
%       zavp - параметры ZAV
%       lfpVar - вариация LFP
%       chnlGrp - группы каналов
%       time - временная ось
%       stims - времена стимулов
%       sweep_info - информация о свипах
%       time_forward - временное окно вперед (секунды)
%       time_back - временное окно назад (секунды)
%       events - события (если загружались)
%       event_comments - комментарии к событиям
%       event_amplitudes - амплитуды событий
%       event_channels - каналы событий
%       event_widths - ширина пиков событий
%       event_prominences - выраженность пиков событий
%       event_metadata - метаданные событий
%
% Пример использования:
%   data = load_zav_file('data.mat');
%   [lfp, spks, hd, zavp, lfpVar, chnlGrp, time, stims, sweep_info, time_forward, time_back] = struct2vars(data);
%   
%   data = load_zav_file('data.mat', 'load_events', true);
%   [lfp, spks, hd, zavp, lfpVar, chnlGrp, time, stims, sweep_info, time_forward, time_back, events] = struct2vars(data);

% Парсинг входных параметров
p = inputParser;
addParameter(p, 'load_events', false, @islogical);
addParameter(p, 'load_settings', false, @islogical);
addParameter(p, 'auto_set_time_windows', true, @islogical);
addParameter(p, 'auto_set_fs', true, @islogical);
parse(p, varargin{:});

load_events = p.Results.load_events;
load_settings = p.Results.load_settings;
auto_set_time_windows = p.Results.auto_set_time_windows;
auto_set_fs = p.Results.auto_set_fs;

% Проверка существования файла
if ~exist(filepath, 'file')
    error('File %s not found', filepath);
end

% Получение информации о файле
[~, filename, ext] = fileparts(filepath);
if isempty(ext)
    filepath = [filepath '.mat'];
end

fprintf('Loading file: %s\n', filename);

% Создаем waitbar для отображения прогресса загрузки
hWaitBar = waitbar(0, 'Initializing...', 'Name', 'Loading file');

% Проверяем, является ли файл Heka форматом
if detectHekaFormat(filepath)
    waitbar(0.1, hWaitBar, 'Heka format detected, converting to ZAV...');
    fprintf('Heka format detected, converting to ZAV...\n');
    [lfp, spks, hd, zavp, lfpVar, chnlGrp] = hekaToZav(filepath);
    % Создаем структуру d для совместимости с остальным кодом
    d.lfp = lfp;
    d.spks = spks;
    d.hd = hd;
    d.zavp = zavp;
    d.lfpVar = lfpVar;
    d.chnlGrp = chnlGrp;
else
    waitbar(0.1, hWaitBar, 'Loading data in ZAV format...');
    fprintf('Loading data in ZAV format...\n');
    d = load(filepath); % Загружаем данные в структуру как обычно
end

% Извлечение основных переменных с проверкой наличия полей
if isfield(d, 'spks')
    spks = d.spks;
else
    spks = [];
    fprintf('Field spks not found, using empty array\n');
end

if isfield(d, 'lfp')
    lfp = d.lfp;
else
    error('Field lfp is required for loading ZAV file');
end

if isfield(d, 'hd')
    hd = d.hd;
else
    error('Field hd is required for loading ZAV file');
end

if isfield(d, 'zavp')
    zavp = d.zavp;
    if isfield(zavp, 'dwnSmplFrq')
        Fs = zavp.dwnSmplFrq;
    else
        error('Field zavp.dwnSmplFrq is required for loading ZAV file');
    end
else
    error('Field zavp is required for loading ZAV file');
end

% Попытка восстановить оригинальную частоту дискретизации
orig_Fs = [];
if isfield(zavp, 'siS')
    if zavp.siS > 0
        orig_Fs_from_siS = 1 / zavp.siS;
        if abs(orig_Fs_from_siS - Fs) > 0.1
            orig_Fs = orig_Fs_from_siS;
        end
    end
end

if isfield(d, 'lfpVar')
    lfpVar = d.lfpVar;
else
    lfpVar = [];
    fprintf('Field lfpVar not found, using empty array\n');
end

if isfield(d, 'chnlGrp')
    chnlGrp = d.chnlGrp;
else
    chnlGrp = [];
    fprintf('Field chnlGrp not found, using empty array\n');
end

fprintf('Sampling rate (after downsampling): %.1f Hz\n', Fs);
if ~isempty(orig_Fs)
    fprintf('Original sampling rate: %.1f Hz\n', orig_Fs);
    fprintf('Downsampling factor: %.2f\n', orig_Fs / Fs);
else
    fprintf('Original sampling rate: not determined\n');
end

% Получение размеров исходной матрицы
[m, n, p] = size(lfp);

% Обработка свипов
if p > 1 % случай со свипами
    waitbar(0.3, hWaitBar, sprintf('Processing %d sweeps...', p));
    fprintf('Sweeps detected (count: %d)\n', p);
    [lfp, spks, stims, lfpVar, sweep_info] = sweepProcessData(p, spks, n, m, lfp, Fs, zavp, lfpVar, hWaitBar);
    stims_exist = ~isempty(stims);
    
    % Сохраняем информацию о свипах
    sweep_inx = 1; % по умолчанию показываем первый свип
    
    fprintf('Duration of one sweep: %.3f s\n', m/Fs);
    waitbar(0.7, hWaitBar, 'Sweeps processed, finalizing...');
else
    waitbar(0.5, hWaitBar, 'Processing regular data...');
    fprintf('Regular data without sweeps\n');
    if isfield(zavp, 'realStim') 
        stims = zavp.realStim(:).r(:) * zavp.siS;  
        stims_exist = ~isempty(stims);
        if stims_exist
            fprintf('Number of stimuli: %d\n', length(stims));
        end
    else
        stims = [];
        stims_exist = false;
    end
    
    % Для данных без свипов создаем пустую структуру sweep_info
    sweep_info = struct();
    sweep_info.is_sweep_data = false;
    sweep_inx = 1;
end

% Создание временной оси
waitbar(0.8, hWaitBar, 'Creating time axis...');
N = size(lfp, 1);
time = (0:N-1) / Fs; % в секундах
fprintf('Total recording duration: %.3f s\n', time(end));

% Установка time_back и time_forward на основе флага auto_set_time_windows
if auto_set_time_windows && p > 1
    % Если есть свипы, показываем весь первый свип
    time_back = 0;
    % Используем исходную длину свипа m (до "распрямления" в sweepProcessData)
    time_forward = m / Fs; % длительность одного свипа в секундах
    fprintf('Time window automatically set: %.3f s\n', time_forward);
else
    % Используем значения по умолчанию
    time_forward = 0.6;
    time_back = 0.6;
    fprintf('Standard time window used: %.3f s\n', time_forward);
end

% chosen_time_interval теперь устанавливается в loadMatFile после выбора режима
% chosen_time_interval = [0, time_forward];

% Установка newFs на основе флага auto_set_fs
if auto_set_fs
    newFs = Fs; % используем частоту даунсемплинга
    fprintf('Sampling rate automatically set: %.1f Hz\n', newFs);
else
    newFs = 1000; % используем фиксированное значение
    fprintf('Fixed sampling rate used: %.1f Hz\n', newFs);
end

% Автоматический выбор режима центра для файлов со свипами
if p > 1 && stims_exist
    selectedCenter = 'stimulus';
    fprintf('Viewing mode automatically selected: stimulus\n');
else
    selectedCenter = 'time';
    fprintf('Viewing mode automatically selected: time\n');
end

% Инициализация переменных событий
events = [];
event_comments = {};
event_amplitudes = [];
event_channels = [];
event_widths = [];
event_prominences = [];
event_metadata = [];

% Загрузка событий если требуется
if load_events
    waitbar(0.85, hWaitBar, 'Loading events...');
    fprintf('Loading events...\n');
    [events, event_comments, event_amplitudes, event_channels, event_widths, event_prominences, event_metadata] = load_events_from_file(filepath, time);
    if ~isempty(events)
        fprintf('Events loaded: %d\n', length(events));
    end
end

% Загрузка настроек каналов если требуется
if load_settings
    waitbar(0.9, hWaitBar, 'Loading channel settings...');
    fprintf('Loading channel settings...\n');
    [channelNames, channelEnabled, scalingCoefficients, colorsIn, lineCoefficients, mean_group_ch, csd_avaliable, filter_avaliable, filterSettings] = load_channel_settings(filepath, hd.recChNames);
    fprintf('Channel settings loaded\n');
end

% Вывод информации о каналах
fprintf('Number of channels: %d\n', n);
fprintf('Channel names: ');
for i = 1:min(5, n)
    fprintf('%s ', hd.recChNames{i});
end
if n > 5
    fprintf('... and %d more channels', n-5);
end
fprintf('\n');

% Вывод итоговой информации
fprintf('\n=== SUMMARY ===\n');
fprintf('LFP data size: %dx%dx%d\n', size(lfp));
fprintf('Spike data size: %dx%dx%d\n', size(spks));
fprintf('Time window: forward=%.3f s, back=%.3f s\n', time_forward, time_back);
fprintf('Stimuli: %s\n', ternary(stims_exist, 'yes', 'no'));
fprintf('Sweeps: %s\n', ternary(sweep_info.is_sweep_data, 'yes', 'no'));
fprintf('Events: %s\n', ternary(~isempty(events), 'yes', 'no'));
fprintf('File successfully loaded!\n');

% Закрываем waitbar
waitbar(1, hWaitBar, 'Loading complete!');
if ~isempty(hWaitBar) && isvalid(hWaitBar)
    close(hWaitBar);
end

% Собираем все данные в структуру
data = struct();
data.lfp = lfp;
data.spks = spks;
data.hd = hd;
data.zavp = zavp;
data.lfpVar = lfpVar;
data.chnlGrp = chnlGrp;
data.time = time;
data.stims = stims;
data.sweep_info = sweep_info;
data.time_forward = time_forward;
data.time_back = time_back;
data.events = events;
data.event_comments = event_comments;
data.event_amplitudes = event_amplitudes;
data.event_channels = event_channels;
data.event_widths = event_widths;
data.event_prominences = event_prominences;
data.event_metadata = event_metadata;

end

% Вспомогательные функции

function result = ternary(condition, true_value, false_value)
% Простая тернарная операция
if condition
    result = true_value;
else
    result = false_value;
end
end

function [events, event_comments, event_amplitudes, event_channels, event_widths, event_prominences, event_metadata] = load_events_from_file(filepath, time)
% Загрузка событий из файла
[path, name, ~] = fileparts(filepath);
event_file = fullfile(path, [name '_events.ev']);

if exist(event_file, 'file')
    try
        loadedData = load(event_file, '-mat');
        if isfield(loadedData, 'manlDet')
            events = time(round([loadedData.manlDet.t]))';
            
            if ~isfield(loadedData, 'event_comments')
                event_comments = repmat({'...'}, numel(events), 1);
            else
                event_comments = loadedData.event_comments;
            end
            
            % Загрузка новых полей с обратной совместимостью
            if isfield(loadedData.manlDet, 'amplitude')
                event_amplitudes = [loadedData.manlDet.amplitude]';
            else
                event_amplitudes = NaN(size(events));
            end
            
            if isfield(loadedData.manlDet, 'channels')
                first_channels = loadedData.manlDet(1).channels;
                if isscalar(first_channels)
                    event_channels = [loadedData.manlDet.channels]';
                else
                    max_channels = max(cellfun(@length, {loadedData.manlDet.channels}));
                    event_channels = NaN(length(events), max_channels);
                    for i = 1:length(events)
                        chs = loadedData.manlDet(i).channels;
                        event_channels(i, 1:length(chs)) = chs;
                    end
                end
            elseif isfield(loadedData.manlDet, 'ch')
                event_channels = [loadedData.manlDet.ch]';
            else
                event_channels = ones(size(events));
            end
            
            if isfield(loadedData.manlDet, 'width')
                event_widths = [loadedData.manlDet.width]';
            else
                event_widths = NaN(size(events));
            end
            
            if isfield(loadedData.manlDet, 'prominence')
                event_prominences = [loadedData.manlDet.prominence]';
            else
                event_prominences = NaN(size(events));
            end
            
            if isfield(loadedData.manlDet, 'metadata')
                event_metadata = [loadedData.manlDet.metadata]';
            else
                event_metadata = repmat(struct('source', 'loaded'), length(events), 1);
            end
        else
            events = [];
            event_comments = {};
            event_amplitudes = [];
            event_channels = [];
            event_widths = [];
            event_prominences = [];
            event_metadata = [];
        end
    catch ME
        warning('Error loading events: %s', ME.message);
        events = [];
        event_comments = {};
        event_amplitudes = [];
        event_channels = [];
        event_widths = [];
        event_prominences = [];
        event_metadata = [];
    end
else
    events = [];
    event_comments = {};
    event_amplitudes = [];
    event_channels = [];
    event_widths = [];
    event_prominences = [];
    event_metadata = [];
end
end

function [channelNames, channelEnabled, scalingCoefficients, colorsIn, lineCoefficients, mean_group_ch, csd_avaliable, filter_avaliable, filterSettings] = load_channel_settings(filepath, defaultChannelNames)
% Загрузка настроек каналов
[path, name, ~] = filepath;
settings_file = fullfile(path, [name '_channelSettings.stn']);

if exist(settings_file, 'file')
    try
        loadedSettings = load(settings_file, '-mat');
        if isfield(loadedSettings, 'EV_version')
            channelNames = np_flatten(loadedSettings.channelNames);
            channelEnabled = np_flatten(loadedSettings.channelEnabled);
            scalingCoefficients = np_flatten(loadedSettings.scalingCoefficients);
            colorsIn = np_flatten(loadedSettings.colorsIn);
            lineCoefficients = np_flatten(loadedSettings.lineCoefficients);
            mean_group_ch = np_flatten(loadedSettings.mean_group_ch);
            csd_avaliable = np_flatten(loadedSettings.csd_avaliable);
            filter_avaliable = np_flatten(loadedSettings.filter_avaliable);
        else
            warning('Old channel settings');
            updatedData = loadedSettings.channelSettings;
            channelNames = updatedData(:, 1)';
            channelEnabled = [updatedData{:, 2}];
            scalingCoefficients = [updatedData{:, 3}];
            colorsIn = updatedData(:, 4)';
            lineCoefficients = [updatedData{:, 5}];
            mean_group_ch = np_flatten(loadedSettings.mean_group_ch);
            csd_avaliable = np_flatten(loadedSettings.csd_avaliable);
            filter_avaliable = np_flatten(loadedSettings.filter_avaliable);
        end
        
        if isfield(loadedSettings, 'filterSettings') && ~(isempty(loadedSettings.filterSettings))
            filterSettings = loadedSettings.filterSettings;
        else
            filterSettings.filterType = 'highpass';
            filterSettings.freqLow = 10;
            filterSettings.freqHigh = 50;
            filterSettings.order = 4;
            filterSettings.channelsToFilter = false(length(defaultChannelNames), 1);
        end
    catch ME
        warning('Error loading channel settings: %s', ME.message);
        [channelNames, channelEnabled, scalingCoefficients, colorsIn, lineCoefficients, mean_group_ch, csd_avaliable, filter_avaliable, filterSettings] = create_default_channel_settings(defaultChannelNames);
    end
else
    [channelNames, channelEnabled, scalingCoefficients, colorsIn, lineCoefficients, mean_group_ch, csd_avaliable, filter_avaliable, filterSettings] = create_default_channel_settings(defaultChannelNames);
end
end

function [channelNames, channelEnabled, scalingCoefficients, colorsIn, lineCoefficients, mean_group_ch, csd_avaliable, filter_avaliable, filterSettings] = create_default_channel_settings(defaultChannelNames)
% Создание настроек каналов по умолчанию
channelNames = defaultChannelNames;
channelEnabled = true(1, length(defaultChannelNames));
scalingCoefficients = ones(1, length(defaultChannelNames));
colorsIn = repmat({'black'}, 1, length(defaultChannelNames));
lineCoefficients = ones(1, length(defaultChannelNames)) * 0.5;
mean_group_ch = false(1, length(defaultChannelNames));
csd_avaliable = true(1, length(defaultChannelNames));
filter_avaliable = false(1, length(defaultChannelNames));

filterSettings.filterType = 'highpass';
filterSettings.freqLow = 10;
filterSettings.freqHigh = 50;
filterSettings.order = 4;
filterSettings.channelsToFilter = false(length(defaultChannelNames), 1);
end 