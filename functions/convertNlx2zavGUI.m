function convertNlx2zavGUI
    global SettingsFilepath
    
    try
        d = load(SettingsFilepath);
        active_folder = fileparts(d.lastOpenedFiles{end});
    catch
        active_folder = userpath;
    end
            
    persistent recordPath detectMua hWaitBar channels_n lfp hd orig_Fs spks mua_std_coef
    persistent lfp_Fs channels_list
    
    % Порог MUA
    mua_std_coef = 3;
    lfp_Fs = 1000;
    
    % Создаем главное окно GUI
    fig = figure('Name', 'Convert to ZAV', 'Position', [100, 100, 280, 200], 'NumberTitle', 'off',...
            'MenuBar', 'none', ... % Отключение стандартного меню
            'ToolBar', 'none', 'Resize', 'off');
    
    % Кнопка для выбора пути к записи
    uicontrol('Style', 'pushbutton', 'String', 'Select Record Path', ...
        'Position', [50, 150, 150, 25], 'Callback', @selectRecordPath);
    
    % Toggle switch для детекции MUA
    detectMuaToggle = uicontrol('Style', 'checkbox', 'String', 'Detect MUA', ...
        'Position', [50, 100, 150, 25], 'Value', 0);
    
    % Окошко для значения коэффициента порога MUA   
    muaCoefUITitlecoords = [160, 100, 50, 25];
    muaCoefTitleUI = uicontrol('Style', 'text', 'String', 'threshold (n*STD)', 'Position', muaCoefUITitlecoords);
    
    muaCoefUIcoords = [208, 100, 20, 25];
    muaCoefUI = uicontrol('Style', 'edit', 'String', num2str(mua_std_coef), 'Position', muaCoefUIcoords, 'Callback', @muaCoefUICallback);
    
    % Окошко для значения частоты дикретизации lfp   
    lfpFsTitlecoords = [160, 45, 50, 25];
    lfpFsTitleUI = uicontrol('Style', 'text', 'String', 'Fs, Hz', 'Position', lfpFsTitlecoords);
    
    lfpFsUIcoords = [208, 50, 60, 25];
    lfpFsUI = uicontrol('Style', 'edit', 'String', num2str(lfp_Fs), 'Position', lfpFsUIcoords, 'Callback', @lfpFsUICallback);
    
    uicontrol('Style', 'text', ...
          'Position', [10 65 120 25], ...
          'String', 'Chosen channels:');
    h = uicontrol('Style', 'edit', ...
              'Position', [10 50 120 25], ...
              'String', 'all channels', ...
              'Callback', @chosenChannelsCallback);
    
    % Кнопка для запуска конвертации
    uicontrol('Style', 'pushbutton', 'String', 'Start Conversion', ...
        'Position', [50, 10, 150, 25], 'Callback', @startConversion);
    
    % Глобальные переменные
    recordPath = '';
    detectMua = false;
    
    
    function muaCoefUICallback(source, ~)
        mua_std_coef = str2double(get(source, 'String'));
    end

    function lfpFsUICallback(source, ~)
        lfp_Fs = str2double(get(source, 'String'));
    end

    % Функция обратного вызова для выбора пути к записи
    function selectRecordPath(~, ~)
        recordPath = uigetdir(active_folder);
        if recordPath == 0
            recordPath = '';
        else
            active_folder = recordPath;
            disp(['Selected record path: ', recordPath]);
        end
    end
    
    function chosenChannelsCallback(hObject, ~)
        
        if isempty(recordPath)
            warndlg('Please select a record path first.', 'Warning');
            return;
        end
        
        channels_n = countChannels(recordPath);  % number of channels
        disp(['channels total: ' num2str(channels_n)]);
        
        val = get(hObject, 'String');

        % Проверка, если введено 'all channels'
        if strcmp(val, 'all channels')
            channels_list = 1:channels_n;
            disp('all channels chosen')
        else
            % Пытаемся интерпретировать введенное значение как диапазон или список каналов
            try
                channels_list = eval(['[', val, ']']);
            catch
                % В случае ошибки возвращаем пустой массив и выводим сообщение об ошибке
                channels_list = [];
                disp('Invalid input. Please enter channels like "1,2,3" or "1:5".');
            end
        end

        % Демонстрация полученного списка каналов (можно убрать или заменить на другое действие)
        disp(['channel list: ' num2str(channels_list)]);
    end

    % Функция обратного вызова для запуска конвертации
    function startConversion(~, ~)
        detectMua = get(detectMuaToggle, 'Value');
        if isempty(recordPath)
            warndlg('Please select a record path first.', 'Warning');
            return;
        end
        
        disp(['Starting conversion. Detect MUA: ', num2str(detectMua)]);
        
        chosenChannelsCallback(h, [])
        
        channels_n = numel(channels_list);
        
        disp(['channels total: ' num2str(channels_n)]);
        disp(['channel list: ' num2str(channels_list)]);
        
        lfp = []; % инициализация переменной для lfp

        % Создание окна прогресса
        hWaitBar = waitbar(0,'Wait...', 'Name', 'Conversion to NLX to ZAV');

        % Считываем данные первого канала для определения размера матрицы lfp
        [data, ~, hd, ~, ~] = ZavNrlynx2(recordPath, [], 1, [], []);
        orig_Fs = 1e6/hd.si; % оригинальная частота дискретизации
        lfp_length = floor(length(data) * lfp_Fs / orig_Fs); % новая длина сигнала после ресемплинга
        lfp = zeros(lfp_length, channels_n); % предварительное выделение памяти для lfp

        clear spks
        ch_inx = 0;
        for ch = channels_list
            ch_inx = ch_inx+1;
            
            [data, ~, hd, spkTS, spkSM] = ZavNrlynx2(recordPath, [], ch, [], []);

            ampl = min(spkSM.s(:, :));

            if detectMua
                [tStamp, ampl, shape] = detectMUA(data, hd, mua_std_coef, true);
                spks(ch_inx).tStamp = single(tStamp); % сохраняем спайки канала в миллисекундном формате
                spks(ch_inx).ampl = single(ampl);
                spks(ch_inx).shape = shape;
            else
                % по ZAV формату
                spks(ch_inx).tStamp = single(spkTS.s'); % сохраняем спайки канала в миллисекундном формате
                spks(ch_inx).ampl = single(ampl');
                spks(ch_inx).shape = [];
            end

            % Ресамплинг данных канала
            data_resampled = resample(data, lfp_Fs, orig_Fs);
            lfp(:, ch_inx) = data_resampled; % добавляем ресемплированные данные в матрицу lfp

            % Обновление индикатора прогресса
            waitbar(ch_inx / numel(channels_list), hWaitBar, sprintf('Channel %d from %d...', ch, numel(channels_list)));
        end
        
        % преобразуем заголовок для выбранного списка каналов
        hd.adBitVolts = hd.adBitVolts(channels_list);
        hd.dspDelay_mks = hd.dspDelay_mks(channels_list);
        hd.adBitVoltsSpk = hd.adBitVoltsSpk(channels_list);
        hd.dspDelay_mksSpk = hd.dspDelay_mksSpk(channels_list);
        hd.alignmentPt = hd.alignmentPt(channels_list);
        hd.inverted = hd.inverted(channels_list);
        hd.recChUnits = hd.recChUnits(channels_list); 
        hd.recChNames = hd.recChNames(channels_list);
        hd.ch_si = hd.ch_si(channels_list);
        
        close(hWaitBar); % Закрытие окна прогресса
        disp('over')

        saveDialog()
    end
    
    function saveDialog()
        choice = questdlg('Save data?', 'Save Confirmation', ...
                          'Yes','No','Yes');
        switch choice
            case 'Yes'
                saveData();  % Предполагается, что функция saveData уже определена в вашем коде
            case 'No'
                disp('User selected Cancel')
        end
    end


    % Функция обратного вызова для сохранения данных
    function saveData()
        % Cохранения данных
        [parent_folder, active_name, ~] = fileparts(active_folder);
        [file, path] = uiputfile([active_name, '.mat'], 'Save File As', parent_folder);
        if isequal(file, 0) || isequal(path, 0)
            disp('User selected Cancel');
        else
            disp(['User selected ', fullfile(path, file)]);
            
            skip_points = orig_Fs/lfp_Fs;
            clear chnlGrp lfpVar zavp
            chnlGrp = {};
            lfpVar = np_flatten(std(lfp)/10)'; % не знаю что это
            zavp.file = recordPath;
            zavp.siS = (hd.si/1000)/lfp_Fs;
            zavp.dwnSmplFrq = lfp_Fs;
            zavp.stimCh = nan;

            if size(hd.inTTL_timestamps, 2)>0 % если были ttl стимуляции
                r_i = (hd.inTTL_timestamps.t(:,1)*skip_points)/zavp.dwnSmplFrq;
                f_i = (hd.inTTL_timestamps.t(:,2)*skip_points)/zavp.dwnSmplFrq;
            else
                r_i = [];
                f_i = [];
            end
            zavp.realStim.r = r_i;
            zavp.realStim.f = f_i;
            zavp.rarStep = hd.ch_si'*0+skip_points;

            new_lfp_filepath = fullfile(path, file);
            save(new_lfp_filepath, 'chnlGrp', 'hd', 'lfp', 'lfpVar' , 'spks', 'zavp');
            
            % Сохраняем информацию о том какой файл сохранили
            lastOpenedFiles = {new_lfp_filepath};
            save(SettingsFilepath, 'lastOpenedFiles', '-append');
            
            disp('file saved')
        end
    end
end