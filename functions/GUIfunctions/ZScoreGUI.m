function ZScoreGUI()
    % Инициализация глобальных переменных
    global lfp_file ch_inxs lfpVar spks Fs events time evfilename std_coef
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
    btnIcon(saveDataButton, fullfile(getAssetsPath(), 'data-storage.png'), false) % ставим иконку для кнопки

    % Кнопка для сохранения изображения
    saveImageButton = uicontrol('Parent', fig,'Style', 'pushbutton', 'String', 'Save Image', 'Position', [250, 20, 80, 30], ...
        'Callback', @SaveImageCallback);
    btnIcon(saveImageButton, fullfile(getAssetsPath(), 'save_image.png'), false) % ставим иконку для кнопки
    
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
        params.lfp = lfp_file.lfp;
        params.N = size(lfp_file.lfp, 1);
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
    [timeAxis, zscore_all] = computeEventSpikeZScore(params);

    hold(axesHandle, 'on');
    plot(axesHandle, timeAxis, zscore_all, 'k');
    xlabel(axesHandle, 'Time');
    ylabel(axesHandle, 'Z-Score');
    title(axesHandle, [params.titlename, ' Z-Score', ', ', num2str(numel(params.events)), ' events'], 'interpreter', 'none');
    hold(axesHandle, 'off');
end
