function eventCrossCorrelationGUI()
    % Global variables
    global time events1 events2 lastOpenedFiles timeUnitFactor selectedUnit
    global eventcorrelation_settings SettingsFilepath
    global app_path matFilePath
    
    % Tag for GUI figure
    figTag = 'eventCrossCorrelationGUI';

    % Search for an open figure with the given tag
    guiFig = findobj('Type', 'figure', 'Tag', figTag);

    if ~isempty(guiFig)
        % Make the existing window the current figure
        figure(guiFig);
        return
    end

    % Initialize GUI
    hFig = figure('Name', 'Cross-Correlation Between Events', 'NumberTitle', 'off', ...
                  'Position', [100, 100, 1100, 500], 'Resize', 'off', ...
                  'MenuBar', 'none', 'ToolBar', 'none', ...
                  'Tag', figTag);
    
    % Создаем оси для графиков
    ax1 = axes('Position', [0.35    0.27    0.20    0.65]);
    ax3 = axes('Position', [0.58    0.27    0.15    0.65]);
    ax4 = axes('Position', [0.81    0.27    0.15    0.65]);
    
    set(ax1, 'visible', 'off')
    set(ax3, 'visible', 'off')
    set(ax4, 'visible', 'off')

    % Система позиций для элементов
    ypos = linspace(450, 150, 8);
    
    % Create UI elements
    uicontrol(hFig, 'Style', 'text', 'Position', [10, ypos(1), 150, 20], ...
              'String', 'Select Event File A:');
    uicontrol(hFig, 'Style', 'pushbutton', 'Position', [160, ypos(1), 130, 20], ...
              'String', 'Load Event A', 'Callback', @(~,~) loadEventFile(1));
    eventA_filename_text = uicontrol(hFig, 'Style', 'text', 'Position', [10, ypos(1)-20, 260, 20], ...
              'String', '', 'HorizontalAlignment', 'left');

    uicontrol(hFig, 'Style', 'text', 'Position', [10, ypos(2), 150, 20], ...
              'String', 'Select Event File B:');
    uicontrol(hFig, 'Style', 'pushbutton', 'Position', [160, ypos(2), 130, 20], ...
              'String', 'Load Event B', 'Callback', @(~,~) loadEventFile(2));
    eventB_filename_text = uicontrol(hFig, 'Style', 'text', 'Position', [10, ypos(2)-20, 260, 20], ...
              'String', '', 'HorizontalAlignment', 'left');

    normalizeCheckbox = uicontrol(hFig, 'Style', 'checkbox', 'Position', [10, ypos(3), 150, 20], ...
                                  'String', 'Normalize');

    windowEdit_text = uicontrol(hFig, 'Style', 'text', 'Position', [10, ypos(4), 150, 20], ...
              'String', ['Window Size (' selectedUnit '):']);
    windowEdit = uicontrol(hFig, 'Style', 'edit', 'Position', [160, ypos(4), 130, 20], ...
                           'String', num2str(10*timeUnitFactor));

    binSizeEdit_text = uicontrol(hFig, 'Style', 'text', 'Position', [10, ypos(5), 150, 20], ...
              'String', ['Bin Size (' selectedUnit '):']);
    binSizeEdit = uicontrol(hFig, 'Style', 'edit', 'Position', [160, ypos(5), 130, 20], ...
                            'String', num2str(0.01*timeUnitFactor));

    analyzeButton = uicontrol(hFig, 'Style', 'pushbutton', 'Position', [10, ypos(7), 280, 30], ...
                              'String', 'Analyze', 'Callback', @analyzeData);
    
    % Переменная для хранения результатов анализа
    correlation_result = struct();
    
    % Переменные для хранения путей к загруженным файлам
    eventA_filepath = '';
    eventB_filepath = '';
    
    % Инициализация значений из настроек, если они существуют
    if ~isempty(eventcorrelation_settings)
        if isfield(eventcorrelation_settings, 'Normalize')
            set(normalizeCheckbox, 'Value', eventcorrelation_settings.Normalize);
        end
        if isfield(eventcorrelation_settings, 'WindowSize')
            set(windowEdit, 'String', num2str(eventcorrelation_settings.WindowSize*timeUnitFactor));
        end
        if isfield(eventcorrelation_settings, 'BinSize')
            set(binSizeEdit, 'String', num2str(eventcorrelation_settings.BinSize*timeUnitFactor));
        end
    end

    function loadEventFile(eventNum)
        initialDir = pwd;
        if ~isempty(lastOpenedFiles)
            initialDir = fileparts(lastOpenedFiles{end});
        end

        [file, path] = uigetfile({'*.ev'; '*.mean'}, 'Load Events', initialDir);
        if isequal(file, 0)
            disp('File selection canceled.');
            return;
        end
        filepath = fullfile(path, file);
        loadedData = load(filepath, '-mat'); % Load data into structure

        if isfield(loadedData, 'manlDet')
            indices = round([loadedData.manlDet.t]);
            indices = max(1, min(indices, length(time)));
            [~, filename_only, ~] = fileparts(file);
            if eventNum == 1
                events1 = time(indices)'; % Update events1
                eventA_filepath = filepath; % Сохраняем путь к файлу
                set(eventA_filename_text, 'String', filename_only); % Показываем имя файла
            else
                events2 = time(indices)'; % Update events2
                eventB_filepath = filepath; % Сохраняем путь к файлу
                set(eventB_filename_text, 'String', filename_only); % Показываем имя файла
            end
        end
    end

    function analyzeData(~, ~)
        % Показываем "Analyzing ..." на осях
        axes(ax1);
        set(ax1, 'visible', 'on');
        cla;
        text(0.5, 0.5, 'Analyzing ...', 'HorizontalAlignment', 'center', ...
             'VerticalAlignment', 'middle', 'FontSize', 14, 'Units', 'normalized');
        axis off;
        
        axes(ax3);
        set(ax3, 'visible', 'on');
        cla;
        text(0.5, 0.5, 'Analyzing ...', 'HorizontalAlignment', 'center', ...
             'VerticalAlignment', 'middle', 'FontSize', 14, 'Units', 'normalized');
        axis off;
        
        axes(ax4);
        set(ax4, 'visible', 'on');
        cla;
        text(0.5, 0.5, 'Analyzing ...', 'HorizontalAlignment', 'center', ...
             'VerticalAlignment', 'middle', 'FontSize', 14, 'Units', 'normalized');
        axis off;
        
        drawnow;
        
        normalize = get(normalizeCheckbox, 'Value');
        windowSize = str2double(get(windowEdit, 'String')) / timeUnitFactor; % convert to seconds
        binSize = str2double(get(binSizeEdit, 'String')) / timeUnitFactor; % convert to seconds

        if isempty(events1) || isempty(events2)
            errordlg('Please load both event files.', 'Error');
            return;
        end
        
        if isempty(eventA_filepath) || isempty(eventB_filepath)
            errordlg('Event file paths are missing. Please reload event files.', 'Error');
            return;
        end

        % Compute histograms of events with common edges
        minTime = min([min(events1), min(events2)]);
        maxTime = max([max(events1), max(events2)]);
        edges = minTime:binSize:maxTime;
        eventHist1 = histcounts(events1, edges, 'Normalization', 'count');
        eventHist2 = histcounts(events2, edges, 'Normalization', 'count');

        % Compute cross-correlation
        if normalize
            [crossCorr, lags] = xcorr(eventHist1, eventHist2, 'normalized');
        else
            [crossCorr, lags] = xcorr(eventHist1, eventHist2);
        end

        % Convert lags to time in seconds
        sampleRate = 1 / binSize;
        lagTimes = lags / sampleRate;

        % Единое ограничение оси X для всех графиков (в секундах)
        Xlims_seconds = [-windowSize/2, windowSize/2];
        
        % Конвертируем в единицы отображения
        Xlims = Xlims_seconds * timeUnitFactor;
        lagTimes_scaled = lagTimes * timeUnitFactor;
        xAxisLabel = ['Time, ' selectedUnit];

        % Trim the cross-correlation result to the specified window size
        validIndices = abs(lagTimes) <= windowSize / 2;
        lagTimes_scaled = lagTimes_scaled(validIndices);
        crossCorr = crossCorr(validIndices);

        % Plot the cross-correlation result on ax1
        axes(ax1);
        set(ax1, 'visible', 'on');
        cla; hold on;
        plot(lagTimes_scaled, crossCorr);
        xline(0, 'r:');
        xlabel(xAxisLabel);
        ylabel('Cross-Correlation');
        title('Cross-Correlation: Event A relative to Event B');
        xlim(Xlims);
        grid on;
        hold off;
        
        % Вычисляем относительное время событий (events1 относительно ближайших events2)
        rel_times = [];
        for i = 1:length(events1)
            event_time = events1(i);
            % Находим ближайшее событие из events2
            [~, closest_idx] = min(abs(events2 - event_time));
            closest_event2 = events2(closest_idx);
            rel_time = event_time - closest_event2;
            rel_times = [rel_times; rel_time];
        end
        
        % Конвертируем относительные времена в единицы отображения
        rel_times_scaled = rel_times * timeUnitFactor;
        
        % Строим боксплот на ax3
        axes(ax3);
        set(ax3, 'visible', 'on');
        cla; hold on;
        
        boxplot(rel_times_scaled, 'Orientation', 'horizontal');
        hold on;
        
        % Добавляем точки данных с небольшим jitter по вертикали, смещенные ниже боксплота
        y_jitter = 0.5 + 0.15 * (rand(size(rel_times_scaled)) - 0.5);
        scatter(rel_times_scaled, y_jitter, 20, 'k', '.', 'MarkerFaceAlpha', 0.6);
        
        xlabel(['Relative time from Event B, ' xAxisLabel]);
        ylabel('Events');
        title(sprintf('Event A timing relative to Event B (n=%d)', length(rel_times)));
        xlim(Xlims);
        grid on;
        hold off;
        
        % Строим гистограмму на ax4 с использованием BinSize
        axes(ax4);
        set(ax4, 'visible', 'on');
        cla; hold on;
        
        % Используем BinSize для создания edges гистограммы
        binSize_scaled = binSize * timeUnitFactor; % BinSize в единицах отображения
        edges_hist = Xlims(1):binSize_scaled:Xlims(2);
        histogram(rel_times_scaled, edges_hist, 'Normalization', 'probability', 'FaceColor', [0.3 0.6 0.9], 'EdgeColor', 'k');
        
        xlabel(['Relative time from Event B, ' xAxisLabel]);
        ylabel('Probability');
        title('Distribution of relative event times');
        xlim(Xlims);
        grid on;
        hold off;
        
        % Сохранение настроек после анализа (в секундах)
        eventcorrelation_settings.Normalize = get(normalizeCheckbox, 'Value');
        eventcorrelation_settings.WindowSize = windowSize; % уже в секундах
        eventcorrelation_settings.BinSize = binSize; % уже в секундах
        
        save(SettingsFilepath, 'eventcorrelation_settings', '-append');
        
        % Сохраняем результаты для возможности сохранения
        correlation_result.crossCorr = crossCorr;
        correlation_result.lagTimes = lagTimes_scaled;
        correlation_result.rel_times = rel_times_scaled;
        correlation_result.rel_times_seconds = rel_times;
        correlation_result.windowSize = windowSize;
        correlation_result.binSize = binSize;
        correlation_result.normalize = normalize;
        correlation_result.timeUnitFactor = timeUnitFactor;
        correlation_result.selectedUnit = selectedUnit;
        correlation_result.Xlims = Xlims;
        correlation_result.numEventsA = length(events1);
        correlation_result.numEventsB = length(events2);
        
        % Сохраняем метаданные о событиях
        correlation_result.eventA_filepath = eventA_filepath;
        correlation_result.eventB_filepath = eventB_filepath;
        correlation_result.eventA_timestamps = events1;
        correlation_result.eventB_timestamps = events2;
        
        % Создаем кнопки сохранения после анализа
        createSaveButtons();
    end
    
    function createSaveButtons()
        [mat_file_folder, original_filename, ~] = fileparts(matFilePath);
        
        % Формируем имя файла из имен загруженных файлов
        if ~isempty(eventA_filepath) && ~isempty(eventB_filepath)
            [~, nameA, ~] = fileparts(eventA_filepath);
            [~, nameB, ~] = fileparts(eventB_filepath);
            local_filename = [nameA '_vs_' nameB];
        else
            local_filename = 'event_correlation';
        end
        
        % Удаляем старые кнопки, если они есть
        old_buttons = findobj(hFig, 'Style', 'pushbutton', '-regexp', 'String', 'Save');
        if ~isempty(old_buttons)
            delete(old_buttons);
        end
        
        % Кнопка для сохранения результата
        save_btn_coords = [10, ypos(7)-40, 280, 30];
        savebutton = uicontrol('Parent', hFig, 'Style', 'pushbutton', 'String', 'Save Result', 'Visible', 'on', 'Position', save_btn_coords, 'Callback', @SaveResultClb);
        btnIcon(savebutton, [app_path, '\icons\data-storage.png'], false);
        
        function SaveResultClb(~,~)
            [file, path, filterindex] = uiputfile(...
                {'*.pdf', 'PDF files (*.pdf)';...
                 '*.eps', 'EPS files (*.eps)';...
                 '*.png', 'PNG files (*.png)';...
                 '*.*', 'All Files (*.*)'},...
                 'Save file name', [mat_file_folder '/' local_filename '_correlation']);
            if isequal(file,0) || isequal(path,0)
                disp('User pressed cancel');
                return;
            end
            
            % Сохраняем фигуру
            filename_fig = fullfile(path, file);
            switch filterindex
                case 1
                    print(hFig, filename_fig, '-dpdf', '-bestfit');
                case 2
                    print(hFig, filename_fig, '-depsc');
                case 3
                    saveas(hFig, filename_fig, 'png');
                otherwise
                    saveas(hFig, filename_fig);
            end
            disp(['Image saved to ', filename_fig]);
            
            % Автоматически сохраняем данные в .meta файл в той же папке
            [~, name_fig, ~] = fileparts(filename_fig);
            filename_meta = fullfile(path, [name_fig '.meta']);
            save(filename_meta, '-struct', 'correlation_result');
            save(filename_meta, 'original_filename', '-append');
            disp(['Data saved to ', filename_meta]);
        end
    end
end
