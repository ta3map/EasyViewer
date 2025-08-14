function loadGroupSettingsAndCreateIndividual(matFilePath, numChannels, Fs, EV_version)
    % LOADGROUPSETTINGSANDCREATEINDIVIDUAL Загружает групповые настройки и создает индивидуальные
    % 
    % Входные параметры:
    %   matFilePath - путь к текущему .mat файлу
    %   numChannels - количество каналов
    %   Fs - частота дискретизации исходных данных
    %   EV_version - версия EasyViewer
    
    % Глобальные переменные для функций обновления
    global updateTableFunc updateLocalCoefsFunc updatePlotFunc saveChannelSettingsFunc
    
    % Глобальные переменные для настроек (будут созданы в createIndividualSettingsFromGroup)
    global channelNames channelEnabled scalingCoefficients colorsIn lineCoefficients
    global mean_group_ch csd_avaliable filter_avaliable filterSettings
    global stims stims_exist stims_loaded_from_settings
    global newFs shiftCoeff time_back time_forward stim_offset EV_version
    
    [path, ~, ~] = fileparts(matFilePath);
    [~, folderName, ~] = fileparts(path);
    
    % Путь к групповым настройкам
    groupSettingsPath = fullfile(path, [folderName '.stn']);
    
    if isfile(groupSettingsPath)
        % Групповые настройки существуют - загружаем их
        disp('Loading group settings...')
        groupSettings = loadGroupSettings(groupSettingsPath);
        
        % Применяем загруженные групповые настройки к глобальным переменным
        applyGroupSettings(groupSettings);
        
    else
        % Групповых настроек нет - создаем их
        disp('Creating new group settings file...')
        createGroupSettings(groupSettingsPath, numChannels, Fs, EV_version);
        
        % Применяем настройки по умолчанию
        [newFs, shiftCoeff, time_back, time_forward, stim_offset] = setDefaultGroupSettings(numChannels, Fs);
        
        % Применяем настройки к глобальным переменным
        applyGroupSettingsToGlobals(newFs, shiftCoeff, time_back, time_forward, stim_offset);
    end
    
    % Создаем индивидуальные настройки на основе групповых (БЕЗ СОХРАНЕНИЯ)
    createIndividualSettingsFromGroup(numChannels, matFilePath);
    
    % ЕСЛИ это файл со свипами И есть времена стимулов И есть stim_offset, применяем его
    global sweep_info stims stims_exist stim_offset
    if sweep_info.is_sweep_data && stims_exist && stim_offset ~= 0
        % Применяем нормализованный сдвиг времен стимулов
        applyStimulusOffset();
    end
    
    % Обновляем таблицу и локальные коэффициенты
    updateTableFunc();
    updateLocalCoefsFunc();
    
    % Сохраняем созданные индивидуальные настройки
    saveChannelSettingsFunc();
    
    % Обновляем график
    updatePlotFunc();
end

function applyGroupSettings(groupSettings)
    % Применяет загруженные групповые настройки к глобальным переменным
    
    global newFs shiftCoeff time_back time_forward stim_offset
    
    if isfield(groupSettings, 'newFs')
        newFs = groupSettings.newFs;
    end
    
    if isfield(groupSettings, 'shiftCoeff')
        shiftCoeff = groupSettings.shiftCoeff;
    end
    
    if isfield(groupSettings, 'time_back')
        time_back = groupSettings.time_back;
    end
    
    if isfield(groupSettings, 'time_forward')
        time_forward = groupSettings.time_forward;
    end
    
    if isfield(groupSettings, 'stim_offset')
        stim_offset = groupSettings.stim_offset;
    end
end

function applyGroupSettingsToGlobals(newFs_in, shiftCoeff_in, time_back_in, time_forward_in, stim_offset_in)
    % Применяет переданные настройки к глобальным переменным
    
    global newFs shiftCoeff time_back time_forward stim_offset
    
    newFs = newFs_in;
    shiftCoeff = shiftCoeff_in;
    time_back = time_back_in;
    time_forward = time_forward_in;
    stim_offset = stim_offset_in;
end

function createIndividualSettingsFromGroup(numChannels, matFilePath)
    % Создает полные индивидуальные настройки на основе групповых
    
    global channelNames channelEnabled scalingCoefficients colorsIn lineCoefficients
    global mean_group_ch csd_avaliable filter_avaliable filterSettings
    global stims stims_exist stims_loaded_from_settings
    global newFs shiftCoeff time_back time_forward stim_offset EV_version
    
    % Устанавливаем стандартные настройки каналов
    channelNames = np_flatten(channelNames);
    channelEnabled = true(1, numChannels);
    scalingCoefficients = ones(1, numChannels);
    colorsIn = np_flatten(repmat({'black'}, numChannels, 1));
    lineCoefficients = ones(1, numChannels)*0.5;
    mean_group_ch = false(1, numChannels);
    csd_avaliable = true(1, numChannels);
    
    % Устанавливаем настройки фильтрации по умолчанию (только в индивидуальных настройках)
    filter_avaliable = false(1, numChannels);
    filterSettings.filterType = 'highpass';
    filterSettings.freqLow = 10;
    filterSettings.freqHigh = 50;
    filterSettings.order = 4;
    filterSettings.channelsToFilter = false(1, numChannels);
    
    % Инициализируем переменные для стимулов (если они есть)
    if ~isempty(stims)
        stims_exist = true;
        stims_loaded_from_settings = false; % Это не загружено из настроек, а применено из групповых
    else
        stims_exist = false;
        stims_loaded_from_settings = false;
    end
    
    % УБРАНО: Сохранение индивидуальных настроек теперь происходит в основной функции
    % после применения stim_offset, чтобы сохранились новые времена стимулов
    
    disp('Individual settings created from group settings (with default filter settings)')
end

function applyStimulusOffset()
    % Применяет сдвиг времен стимулов к глобальным переменным stims
    
    global stims stims_exist stim_offset
    if stims_exist && ~isempty(stims)
        % Шаг 1: Вычитаем из всех времен время первого стимула (первый станет 0)
        firstStimTime = stims(1);
        stims = stims - firstStimTime;
        
        % Шаг 2: Применяем stim_offset (первый будет иметь значение stim_offset)
        if stim_offset ~= 0
            stims = stims + stim_offset;
            disp(['Applied stimulus offset: ' num2str(stim_offset) ' seconds']);
        end
        
        disp(['Normalized stimulus times: first stimulus at ' num2str(stims(1)) ' seconds']);
    end
end 