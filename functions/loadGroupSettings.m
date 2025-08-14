function groupSettings = loadGroupSettings(groupSettingsPath)
    % LOADGROUPSETTINGS Загружает групповые настройки из файла
    % 
    % Входные параметры:
    %   groupSettingsPath - путь к файлу групповых настроек
    %
    % Выходные параметры:
    %   groupSettings - структура с загруженными настройками
    
    try
        loadedGroupSettings = load(groupSettingsPath, '-mat');
        
        % Инициализируем структуру настроек
        groupSettings = struct();
        
        % Загружаем только групповые параметры
        % Настройки фильтрации убраны из групповых настроек
        if isfield(loadedGroupSettings, 'newFs')
            groupSettings.newFs = loadedGroupSettings.newFs;
        end
        
        if isfield(loadedGroupSettings, 'shiftCoeff')
            groupSettings.shiftCoeff = loadedGroupSettings.shiftCoeff;
        end
        
        if isfield(loadedGroupSettings, 'time_back')
            groupSettings.time_back = loadedGroupSettings.time_back;
        end
        
        if isfield(loadedGroupSettings, 'time_forward')
            groupSettings.time_forward = loadedGroupSettings.time_forward;
        end
        
        if isfield(loadedGroupSettings, 'stim_offset')
            groupSettings.stim_offset = loadedGroupSettings.stim_offset;
        end
        
        disp('Group settings loaded successfully (with stim offset support)')
        
    catch ME
        warning('Error loading group settings: %s', ME.message)
        % В случае ошибки возвращаем пустую структуру
        groupSettings = struct();
    end
end 