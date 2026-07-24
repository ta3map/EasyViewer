function zavFilePath = autoConvertAbfToZav(abfFilePath)
    % Автоматически конвертирует ABF файл в ZAV формат с параметрами по умолчанию.
    %
    % Параметры:
    %   abfFilePath - путь к ABF файлу
    %
    % Возвращает:
    %   zavFilePath - путь к сконвертированному ZAV файлу (.mat)
    %                 Если произошла ошибка, возвращает пустую строку
    %
    % Параметры конвертации по умолчанию:
    %   - doResample = false (без ресемплинга)
    %   - collectSweeps = false (свипы канала объединены в один трейс)
    %   - detectMua = false
    %   - все каналы из файла
    
    zavFilePath = '';
    
    % Проверка существования файла
    if ~exist(abfFilePath, 'file')
        warning('autoConvertAbfToZav: ABF file not found: %s', abfFilePath);
        return;
    end
    
    % Чтение заголовка для получения имен каналов
    try
        [~, ~, hd_abf] = abfload(abfFilePath, 'stop', 1, 'doDispInfo', false);
        selectedChannels = hd_abf.recChNames;
    catch ME
        warning('autoConvertAbfToZav: Error reading ABF file header: %s', ME.message);
        return;
    end
    
    % Формирование пути для сохранения (то же имя, но расширение .mat)
    [zavPath, zavName, ~] = fileparts(abfFilePath);
    zavFilePath = fullfile(zavPath, [zavName, '.mat']);
    
    % Проверка существования уже сконвертированного файла
    if exist(zavFilePath, 'file')
        return;
    end
    
    % Создание waitbar для отображения прогресса
    hWaitBar = createCancelableWaitbar(0, 'Converting ABF to ZAV...', 'ABF to ZAV Conversion');
    
    try
        % Параметры конвертации по умолчанию
        lfp_Fs = 1000; % не используется при doResample = false
        detectMua = false;
        doResample = false;
        collectSweeps = false;
        mua_std_coef = 1; % не используется при detectMua = false
        
        % Вызов функции конвертации
        abf_to_zav(abfFilePath, zavFilePath, lfp_Fs, detectMua, doResample, collectSweeps, selectedChannels, mua_std_coef, hWaitBar);
        
        deleteCancelableWaitbar(hWaitBar);
        
    catch ME
        deleteCancelableWaitbar(hWaitBar);
        if strcmp(ME.identifier, 'EasyViewer:UserCancel')
            disp('Conversion stopped by user.');
            zavFilePath = '';
            return;
        end
        warning('autoConvertAbfToZav: Error during ABF conversion: %s', ME.message);
        zavFilePath = ''; % Возвращаем пустую строку при ошибке
    end
end
