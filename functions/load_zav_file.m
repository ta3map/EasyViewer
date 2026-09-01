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
%       lfp_file - matfile объект (v7.3) или struct с полем .lfp (матрица LFP)
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
%   [lfp_file, spks, hd, zavp, lfpVar, chnlGrp, time, stims, sweep_info, time_forward, time_back] = struct2vars(data);
%   
%   data = load_zav_file('data.mat', 'load_events', true);
%   [lfp_file, spks, hd, zavp, lfpVar, chnlGrp, time, stims, sweep_info, time_forward, time_back, events] = struct2vars(data);

% Парсинг входных параметров
p = inputParser;
addParameter(p, 'load_events', false, @islogical);
addParameter(p, 'load_settings', false, @islogical);
addParameter(p, 'auto_set_time_windows', true, @islogical);
addParameter(p, 'auto_set_fs', true, @islogical);
addParameter(p, 'waitbar_handle', [], @(x) isempty(x) || ishghandle(x));
addParameter(p, 'keep_waitbar_open', false, @islogical);
addParameter(p, 'metadata_fields', {'spks', 'hd', 'zavp', 'lfpVar', 'chnlGrp'}, @iscell);
parse(p, varargin{:});

load_events = p.Results.load_events;
load_settings = p.Results.load_settings;
auto_set_time_windows = p.Results.auto_set_time_windows;
auto_set_fs = p.Results.auto_set_fs;
waitbar_handle = p.Results.waitbar_handle;
keep_waitbar_open = p.Results.keep_waitbar_open;
metadata_fields = p.Results.metadata_fields;

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

% Создаем/используем waitbar для отображения прогресса загрузки
if ~isempty(waitbar_handle) && isvalid(waitbar_handle)
    hWaitBar = waitbar_handle;
    waitbar(0.1, hWaitBar, 'Loading data in ZAV format...');
else
    hWaitBar = waitbar(0, 'Initializing...', 'Name', 'Loading file');
end

fileInfo = whos('-file', filepath);
var_names = {fileInfo.name};
is_heka = detectHekaFormat(filepath, fileInfo);
is_v73 = false;

if is_heka
    waitbar(0.1, hWaitBar, 'Heka format detected, converting to ZAV...');
    fprintf('Heka format detected, converting to ZAV...\n');
    [heka_lfp, spks_h, hd_h, zavp_h, lfpVar_h, chnlGrp_h] = hekaToZav(filepath);
    d = struct('spks', spks_h, 'hd', hd_h, 'zavp', zavp_h, 'lfpVar', lfpVar_h, 'chnlGrp', chnlGrp_h);
    lfp_dims = size(heka_lfp);
else
    waitbar(0.1, hWaitBar, 'Loading data in ZAV format...');
    fprintf('Loading data in ZAV format...\n');

    lfp_idx = find(strcmp(var_names, 'lfp'), 1);
    if isempty(lfp_idx)
        error('Field lfp is required for loading ZAV file');
    end
    lfp_dims = fileInfo(lfp_idx).size;
    vars_to_load = intersect(metadata_fields, var_names, 'stable');

    try
        mf = matfile(filepath);
        is_v73 = true;
        fprintf('v7.3 format detected, lazy LFP access enabled\n');
        d = struct();
        for vi = 1:numel(vars_to_load)
            d.(vars_to_load{vi}) = mf.(vars_to_load{vi});
        end
    catch
        load_fields = union(vars_to_load, {'lfp'}, 'stable');
        d_raw = load(filepath, load_fields{:});
        lfp_dims = size(d_raw.lfp);
        d = struct('lfp', d_raw.lfp);
        for vi = 1:numel(vars_to_load)
            d.(vars_to_load{vi}) = d_raw.(vars_to_load{vi});
        end
    end
end

% Извлечение основных переменных с проверкой наличия полей
if isfield(d, 'spks')
    spks = d.spks;
else
    spks = [];
    fprintf('Field spks not found, using empty array\n');
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

% Получение размеров исходной матрицы lfp (без загрузки в память)
m = lfp_dims(1);
n = lfp_dims(2);
p = 1;
if length(lfp_dims) >= 3
    p = lfp_dims(3);
end

% Приводим метаданные каналов к фактическому числу каналов в lfp
hd = normalize_channel_metadata(hd, n);

% Обработка свипов и создание lfp_file
if p > 1 % случай со свипами
    waitbar(0.3, hWaitBar, sprintf('Processing %d sweeps...', p));
    fprintf('Sweeps detected (count: %d)\n', p);
    
    % Для свипов необходимо загрузить lfp в память
    if is_heka
        lfp = heka_lfp;
        clear heka_lfp;
    elseif is_v73
        lfp = mf.lfp;
    else
        lfp = d.lfp;
    end
    [lfp, spks, stims, lfpVar, sweep_info] = sweepProcessData(p, spks, n, m, lfp, Fs, zavp, lfpVar, hWaitBar);
    lfp_file = struct('lfp', lfp);
    N = size(lfp, 1);
    clear lfp;
    stims_exist = ~isempty(stims);
    
    sweep_inx = 1;
    fprintf('Duration of one sweep: %.3f s\n', m/Fs);
    waitbar(0.7, hWaitBar, 'Sweeps processed, finalizing...');
else
    waitbar(0.5, hWaitBar, 'Processing regular data...');
    fprintf('Regular data without sweeps\n');
    
    % Создаём lfp_file: matfile для v7.3, struct для остального
    if is_v73
        lfp_file = mf;
    elseif is_heka
        lfp_file = struct('lfp', heka_lfp);
        clear heka_lfp;
    else
        lfp_file = struct('lfp', d.lfp);
    end
    N = m;
    
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
    
    sweep_info = struct();
    sweep_info.is_sweep_data = false;
    sweep_inx = 1;
end

clear d;

% Создание временной оси
waitbar(0.8, hWaitBar, 'Creating time axis...');
time = (0:N-1) / Fs;
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
    selectedCenter = 'continuous';
    fprintf('Viewing mode automatically selected: continuous\n');
end

% Инициализация переменных событий
events = [];
event_indices = [];
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
    [events, event_comments, event_amplitudes, event_channels, event_widths, event_prominences, event_metadata, event_indices] = load_events_from_file(filepath, time);
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
for i = 1:min(5, numel(hd.recChNames))
    fprintf('%s ', hd.recChNames{i});
end
if n > 5
    fprintf('... and %d more channels', n-5);
end
fprintf('\n');

% Вывод итоговой информации
fprintf('\n=== SUMMARY ===\n');
fprintf('LFP samples: %d, channels: %d\n', N, n);
fprintf('Spike data size: %dx%dx%d\n', size(spks));
fprintf('Time window: forward=%.3f s, back=%.3f s\n', time_forward, time_back);
fprintf('Stimuli: %s\n', ternary(stims_exist, 'yes', 'no'));
fprintf('Sweeps: %s\n', ternary(sweep_info.is_sweep_data, 'yes', 'no'));
fprintf('Events: %s\n', ternary(~isempty(events), 'yes', 'no'));
fprintf('File successfully loaded!\n');

% Закрываем waitbar
waitbar(1, hWaitBar, 'Loading complete!');
if ~keep_waitbar_open && ~isempty(hWaitBar) && isvalid(hWaitBar)
    close(hWaitBar);
end

% Собираем все данные в структуру
data = struct();
data.lfp_file = lfp_file;
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
data.event_indices = event_indices;
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

function hd = normalize_channel_metadata(hd, n)
if ~isfield(hd, 'recChNames') || isempty(hd.recChNames)
    hd.recChNames = cell(1, n);
else
    if iscell(hd.recChNames)
        hd.recChNames = reshape(hd.recChNames, 1, []);
    else
        hd.recChNames = reshape(cellstr(hd.recChNames), 1, []);
    end
end

names_count = numel(hd.recChNames);
if names_count < n
    if isfield(hd, 'chNumList') && ~isempty(hd.chNumList)
        ch_numbers = reshape(hd.chNumList, 1, []);
    else
        ch_numbers = 1:n;
    end
    for idx = (names_count + 1):n
        if idx <= numel(ch_numbers)
            hd.recChNames{idx} = sprintf('CSC%d', ch_numbers(idx));
        else
            hd.recChNames{idx} = sprintf('Channel_%d', idx);
        end
    end
end
if numel(hd.recChNames) > n
    hd.recChNames = hd.recChNames(1:n);
end

hd.nADCNumChannels = n;
end

function [events, event_comments, event_amplitudes, event_channels, event_widths, event_prominences, event_metadata, event_indices] = load_events_from_file(filepath, time)
% Загрузка событий из файла
[path, name, ~] = fileparts(filepath);
event_file = fullfile(path, [name '_events.ev']);

if exist(event_file, 'file')
    try
        loadedData = load(event_file, '-mat');
        if isfield(loadedData, 'manlDet')
            event_indices = round([loadedData.manlDet.t])';
            events = time(event_indices(:));
            
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
                event_metadata = normalizeEventMetadata({loadedData.manlDet.metadata}, length(events), 'loaded');
            else
                event_metadata = createDefaultEventMetadata('loaded', length(events));
            end
            event_channels = normalizeEventChannels(event_channels, length(events));
        else
            events = [];
            event_indices = [];
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
        event_indices = [];
        event_comments = {};
        event_amplitudes = [];
        event_channels = [];
        event_widths = [];
        event_prominences = [];
        event_metadata = [];
    end
else
    events = [];
    event_indices = [];
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
            if ~isfield(filterSettings, 'smoothSpan')
                filterSettings.smoothSpan = 0;
            end
            if ~isfield(filterSettings, 'smoothMethod')
                filterSettings.smoothMethod = 'moving';
            end
        else
            filterSettings.filterType = 'highpass';
            filterSettings.freqLow = 10;
            filterSettings.freqHigh = 50;
            filterSettings.order = 4;
            filterSettings.channelsToFilter = false(length(defaultChannelNames), 1);
            filterSettings.smoothSpan = 0;
            filterSettings.smoothMethod = 'moving';
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
filterSettings.smoothSpan = 0;
filterSettings.smoothMethod = 'moving';
end 