function ZScoreGUI()
    % Инициализация глобальных переменных
    global lfp ch_inxs lfpVar spks Fs events time evfilename std_coef
    global matFilePath app_path channelNames
    
    persistent dataToSave
%     
    
    [mat_file_folder, ~, ~] = fileparts(matFilePath);
    
    % Идентификатор (tag) для GUI фигуры
    figTag = 'ZScoreGUI';

    % Поиск открытой фигуры с заданным идентификатором
    guiFig = findobj('Type', 'figure', 'Tag', figTag);

    if ~isempty(guiFig)
        % Делаем существующее окно текущим (активным)
        figure(guiFig);
        return
    end

    % Создание графического окна
    fig = figure('Name', 'Z-Score', 'Tag', figTag, ...
        'Resize', 'off', 'NumberTitle', 'off', 'Position', [100, 100, 600, 400]);
    
    
    % Список выбора каналов
    channelList = uicontrol('Style', 'listbox', 'Position', [20, 70, 100, 300], ...
        'String', channelNames(ch_inxs), ...
        'Max', length(ch_inxs), 'Min', 1);

    % Кнопка построить z-score
    uicontrol('Style', 'pushbutton', 'Position', [20, 20, 100, 30], 'String', 'Plot Z-Score', ...
        'Callback', @plotZScoreCallback);

    % Область для графика
    axesHandle = axes('Parent', fig, 'Units', 'pixels', 'Position', [160, 50, 400, 300]);

    % Кнопка для сохранения данных
    saveDataButton = uicontrol('Parent', fig,'Style', 'pushbutton', 'String', 'Save Data', 'Position', [150, 20, 80, 30], ...
        'Callback', @SaveDataCallback);
    btnIcon(saveDataButton, [app_path, '\icons\data-storage.png'], false) % ставим иконку для кнопки

    % Кнопка для сохранения изображения
    saveImageButton = uicontrol('Parent', fig,'Style', 'pushbutton', 'String', 'Save Image', 'Position', [250, 20, 80, 30], ...
        'Callback', @SaveImageCallback);
    btnIcon(saveImageButton, [app_path, '\icons\save image.png'], false) % ставим иконку для кнопки
    
    btn_list = [saveDataButton, saveImageButton];
    set(fig, 'WindowButtonMotionFcn', @(src, event)autoHideBtn(src, event, btn_list));

    function plotZScoreCallback(~, ~)
        % Получение выбранных каналов
        selectedChannels = get(channelList, 'Value');
%         ch_inxs = ;

        % Обновление параметров
        params = struct();
        params.events = events;
        params.meanWindow = 2; % Пример: окно среднего в секундах
        params.Fs = Fs;
        params.lfp = lfp;
        params.N = size(lfp, 1);
        params.time = time;
        params.binsize = 0.01; % Пример: размер бина в секундах
        params.spks = spks;
        params.ch_inxs = selectedChannels;
        params.lfpVar = lfpVar;
        params.spk_threshold = std_coef; % Пример: порог для спайков
        params.titlename = evfilename;

        % Очистка текущей области графика
        cla(axesHandle);
        
        % Вызов функции plotZScore
        [timeAxis, zscore_all] = plotZScore(params, axesHandle);
        dataToSave = struct('timeAxis', timeAxis, 'zscore_all', zscore_all);
    end

    function SaveDataCallback(~, ~)
        set(saveDataButton, 'Visible', 'off')
        [file, path] = uiputfile([mat_file_folder '/' evfilename '.zsc'], 'Save file name');
        if isequal(file, 0) || isequal(path, 0)
           disp('User pressed cancel');
        else
           filename = fullfile(path, file);
           save(filename, '-struct', 'dataToSave');
           disp(['Data saved to ', filename]);
        end
    end

    function SaveImageCallback(~, ~)
        set(saveImageButton, 'Visible', 'off')
        [file, path, filterindex] = uiputfile(...
            {'*.pdf', 'PDF files (*.pdf)';...
             '*.eps', 'EPS files (*.eps)';...
             '*.png', 'PNG files (*.png)';...
             '*.*', 'All Files (*.*)'},...
             'Save file name', [mat_file_folder '/' evfilename '_zscore']);
        if isequal(file, 0) || isequal(path, 0)
           disp('User pressed cancel');
        else
           filename = fullfile(path, file);      
           switch filterindex
               case 1
                   print(fig, filename, '-dpdf', '-bestfit');
               case 2
                   print(fig, filename, '-depsc');
               case 3
                   saveas(fig, filename, 'png');
               otherwise
                   saveas(fig, filename);
           end
           disp(['Image saved to ', filename]);
        end
    end
end

function [timeAxis, zscore_all] = plotZScore(params, axesHandle)
    % Распаковка переменных из params
    events = params.events;
    meanWindow = params.meanWindow;
    Fs = params.Fs;
    lfp = params.lfp;
    N = params.N;
    time = params.time;
    binsize = params.binsize;
    spks = params.spks;
    ch_inxs = params.ch_inxs; % Индексы активированных каналов
    lfpVar = params.lfpVar;
    prg = params.spk_threshold;
    titlename = params.titlename;

    if isfield(params, 'timeUnitFactor')
        timeUnitFactor = params.timeUnitFactor;
    else
        timeUnitFactor = 1;
    end

    % Подготовка данных для среднего
    numEvents = length(events);

    % Считаем все спайки и их Z-score
    all_hists = [];
    if not(isempty(spks))
        for i = 1:numEvents
            % Вычисление индексов окна вокруг события
            eventIdx = round(events(i) * Fs);
            windowStart = max(eventIdx - round(meanWindow * Fs / 2), 1);
            windowEnd = min(windowStart + round(meanWindow * Fs) - 1, N);

            if windowEnd < size(lfp, 1)
                % Окно события
                time_start = time(windowStart);
                time_end = time(windowEnd);

                time_interval = [time_start, time_end]; % s
                edges = time_interval(1):binsize:time_interval(2);

                % Смотрим что на каждом канале для этого эвента
                for ch_inx = ch_inxs
                    % Порог ZAV метод
                    ii = double(spks(ch_inx).ampl) <= (-lfpVar(ch_inx) * prg);
                    spks_in(ch_inx).tStamp = spks(ch_inx).tStamp(ii);
                    spks_in(ch_inx).ampl = spks(ch_inx).ampl(ii);

                    spk = spks_in(ch_inx).tStamp / 1000;

                    hist_data = histcounts(spk, edges);
                    all_hists = [all_hists; hist_data];
                end
            end
            disp(['event #' num2str(i) ' of ' num2str(numEvents)])
        end
    end

    % Рассчитываем Z-score
    if ~isempty(all_hists)
        mean_hists = mean(all_hists, 1);
        std_hists = std(all_hists, 0, 1);
        zscore_all = (mean_hists - mean(mean_hists)) / std(mean_hists);
    else
        zscore_all = [];
    end

    % Отображение Z-score
    hold(axesHandle, 'on')

    start_time = -meanWindow / 2;
    end_time = meanWindow / 2;

    timeAxis = linspace(start_time * timeUnitFactor, end_time * timeUnitFactor, length(zscore_all));
    
    plot(axesHandle, timeAxis, zscore_all, 'k');
    xlabel(axesHandle, 'Time');
    ylabel(axesHandle, 'Z-Score');
    title(axesHandle, [titlename, ' Z-Score', ', ', num2str(numEvents), ' events'], 'interpreter', 'none');
    
    hold(axesHandle, 'off');
end
