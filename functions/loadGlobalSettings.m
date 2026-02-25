function loadGlobalSettings()
    % LOADGLOBALSETTINGS Загружает глобальные настройки из файла ev_settings.mat
    % Эта функция должна вызываться в начале каждого модуля приложения
    
    % Глобальные переменные для настроек
    global lastOpenedFiles figure_position add_event_settings
    global timeUnitFactor selectedUnit autodetection_settings
    global art_rem_settings lines_and_styles
    global auto_open_last_file SettingsFilepath import_settings
    global visualSettings
    
    % Путь к файлу настроек
    SettingsFilepath = fullfile(tempdir, 'ev_settings.mat');
    
    % Базовое положение окна по умолчанию
    base_figure_position = [20 60 1280 650] * 0.8;
    
    % Инициализируем настройки по умолчанию если файл не существует
    if ~exist(SettingsFilepath, 'file')
        try
            % Создаем настройки по умолчанию
            lastOpenedFiles = {};
            figure_position = base_figure_position;
            timeUnitFactor = 1;
            selectedUnit = 's';
            art_rem_settings = struct('artifact_window_ms', 0, 'interp_method', 'linear');
            add_event_settings = [];
            autodetection_settings = [];
            import_settings = struct();
            lines_and_styles = [];
            auto_open_last_file = true;
            visualSettings = struct('show_full_signal', true, 'auto_shift', true, ...
                'side_panel_visible', true, 'stim_show', true, ...
                'show_spikes', false, 'show_CSD', false);
            cursor_positions = struct();
            
            % Сохраняем файл настроек
            save(SettingsFilepath, ...
                'lastOpenedFiles', ...
                'figure_position', ...
                'timeUnitFactor', ...
                'selectedUnit', ...
                'art_rem_settings', ...
                'add_event_settings', ...
                'autodetection_settings', ...
                'import_settings', ...
                'lines_and_styles', ...
                'auto_open_last_file', ...
                'visualSettings', ...
                'cursor_positions');
            
            disp('Default settings file created successfully');
        catch ME
            warning('Error creating default settings file: %s', ME.message);
        end
    end
    
    if exist(SettingsFilepath, 'file')
        try
            d = load(SettingsFilepath);
            
            % Загружаем список последних открытых файлов
            if isfield(d, 'lastOpenedFiles')
                lastOpenedFiles = d.lastOpenedFiles;
            else
                lastOpenedFiles = {};
            end
            
            % Загружаем положение окна
            if isfield(d, 'figure_position')
                figure_position = d.figure_position;
            else
                figure_position = base_figure_position;
            end
            
            % Загружаем настройки добавления события
            if isfield(d, 'add_event_settings')
                add_event_settings = d.add_event_settings;
            else
                add_event_settings = struct();
            end
            
            % Загружаем глобальные настройки единиц времени
            if isfield(d, 'timeUnitFactor')
                timeUnitFactor = d.timeUnitFactor;
            else
                timeUnitFactor = 1;
            end
            
            if isfield(d, 'selectedUnit')
                selectedUnit = d.selectedUnit;
            else
                selectedUnit = 's';
            end
            
            % Загружаем настройки автодетекции
            if isfield(d, 'autodetection_settings')
                autodetection_settings = d.autodetection_settings;
            else
                autodetection_settings = [];
            end
            
            % Загружаем настройки импорта
            if isfield(d, 'import_settings')
                import_settings = d.import_settings;
            else
                import_settings = struct();
            end
            
            % Загружаем настройки удаления артефакта стимула
            if isfield(d, 'art_rem_settings')
                art_rem_settings = d.art_rem_settings;
            else
                art_rem_settings = struct('artifact_window_ms', 0, 'interp_method', 'linear');
            end
            
            % Загружаем настройки стиля линий
            if isfield(d, 'lines_and_styles')
                lines_and_styles = d.lines_and_styles;
            else
                lines_and_styles = struct();
            end
            
            % Загружаем визуальные настройки
            defaultVisualSettings = struct('show_full_signal', true, 'auto_shift', true, ...
                'side_panel_visible', true, 'stim_show', true, ...
                'show_spikes', false, 'show_CSD', false);
            if isfield(d, 'visualSettings')
                visualSettings = d.visualSettings;
                for fn = fieldnames(defaultVisualSettings)'
                    if ~isfield(visualSettings, fn{1})
                        visualSettings.(fn{1}) = defaultVisualSettings.(fn{1});
                    end
                end
            else
                visualSettings = defaultVisualSettings;
            end
            
            % Загружаем настройку автоматического открытия последнего файла
            if isfield(d, 'auto_open_last_file')
                auto_open_last_file = d.auto_open_last_file;
            else
                auto_open_last_file = false; % fallback для старых настроек - отключаем автооткрытие
            end
            
        catch ME
            warning('Ошибка при загрузке настроек: %s', ME.message);
            % В случае ошибки устанавливаем значения по умолчанию
            setDefaultGlobalSettings();
        end
    end
    
    function setDefaultGlobalSettings()
        % Устанавливает настройки по умолчанию в случае ошибки загрузки
        lastOpenedFiles = {};
        figure_position = base_figure_position;
        
        % Настройки добавления события по умолчанию
        add_event_settings.mode = 'manual';
        add_event_settings.channel = 11;
        add_event_settings.polarity = 'positive';
        add_event_settings.timeWindow = 10;
        
        % Единицы времени по умолчанию
        timeUnitFactor = 1;
        selectedUnit = 's';
        
        % Остальные настройки по умолчанию
        autodetection_settings = [];
        import_settings = struct();
        art_rem_settings = struct('artifact_window_ms', 0, 'interp_method', 'linear');
        auto_open_last_file = true;
        lines_and_styles = struct();
        visualSettings = struct('show_full_signal', true, 'auto_shift', true, ...
            'side_panel_visible', true, 'stim_show', true, ...
            'show_spikes', false, 'show_CSD', false);
    end
end
