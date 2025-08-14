function createGroupSettings(groupSettingsPath, numChannels, Fs, EV_version)
    % CREATEGROUPSETTINGS Создает файл групповых настроек с значениями по умолчанию
    % 
    % Входные параметры:
    %   groupSettingsPath - путь к файлу групповых настроек
    %   numChannels - количество каналов
    %   Fs - частота дискретизации исходных данных
    %   EV_version - версия EasyViewer
    
    % Устанавливаем значения по умолчанию для групповых настроек
    [newFs, shiftCoeff, time_back, time_forward, stim_offset] = setDefaultGroupSettings(numChannels, Fs);
    
    % Сохраняем групповые настройки
    try
        save(groupSettingsPath, ...
            'newFs', ...
            'shiftCoeff', ...
            'time_back', ...
            'time_forward', ...
            'stim_offset', ...
            'EV_version');
        disp('New group settings file created (without filter settings, with stim offset)')
    catch ME
        warning('Error creating group settings: %s', ME.message)
    end
end 