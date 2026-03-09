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

    % Текст под графиками: число событий A и B после фильтрации (если была)
    eventsCountText = uicontrol(hFig, 'Style', 'text', 'Position', [385, 45, 550, 22], ...
        'String', '', 'HorizontalAlignment', 'left', 'FontSize', 9);

    % Система позиций для элементов (под блоками A/B — кнопка Swap, затем Normalize и ниже)
    ypos = [460, 381, 295, 246, 197, 149, 100, 52];
    
    % Create UI elements
    uicontrol(hFig, 'Style', 'text', 'Position', [10, ypos(1), 150, 20], ...
              'String', 'Select Event File A:');
    uicontrol(hFig, 'Style', 'pushbutton', 'Position', [160, ypos(1), 130, 20], ...
              'String', 'Load Event A', 'Callback', @(~,~) loadEventFile(1), 'ForegroundColor', [0 0 1]);
    eventA_filename_text = uicontrol(hFig, 'Style', 'text', 'Position', [10, ypos(1)-20, 260, 20], ...
              'String', '', 'HorizontalAlignment', 'left');
    eventA_range_text = uicontrol(hFig, 'Style', 'text', 'Position', [10, ypos(1)-40, 260, 18], ...
              'String', '', 'HorizontalAlignment', 'left', 'FontSize', 9);

    uicontrol(hFig, 'Style', 'text', 'Position', [10, ypos(2), 150, 20], ...
              'String', 'Select Event File B:');
    uicontrol(hFig, 'Style', 'pushbutton', 'Position', [160, ypos(2), 130, 20], ...
              'String', 'Load Event B', 'Callback', @(~,~) loadEventFile(2), 'ForegroundColor', [1 0 0]);
    eventB_filename_text = uicontrol(hFig, 'Style', 'text', 'Position', [10, ypos(2)-20, 260, 20], ...
              'String', '', 'HorizontalAlignment', 'left');
    eventB_range_text = uicontrol(hFig, 'Style', 'text', 'Position', [10, ypos(2)-40, 260, 18], ...
              'String', '', 'HorizontalAlignment', 'left', 'FontSize', 9);

    uicontrol(hFig, 'Style', 'pushbutton', 'Position', [10, ypos(2)-62, 280, 20], ...
              'String', 'Swap A and B', 'Callback', @swapEventsAB);

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

    useTimeRangeCheckbox = uicontrol(hFig, 'Style', 'checkbox', 'Position', [10, ypos(6), 110, 20], ...
        'String', ['Time range (' selectedUnit ')'], 'Value', 0, 'Callback', @timeRangeCallback);
    timeStartLabel = uicontrol(hFig, 'Style', 'text', 'Position', [125, ypos(6), 30, 20], ...
        'String', 'Start:', 'Visible', 'off');
    timeStartEdit = uicontrol(hFig, 'Style', 'edit', 'Position', [158, ypos(6), 55, 20], ...
        'String', '', 'Visible', 'off');
    timeEndLabel = uicontrol(hFig, 'Style', 'text', 'Position', [218, ypos(6), 28, 20], ...
        'String', 'End:', 'Visible', 'off');
    timeEndEdit = uicontrol(hFig, 'Style', 'edit', 'Position', [248, ypos(6), 55, 20], ...
        'String', '', 'Visible', 'off');

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
        if isfield(eventcorrelation_settings, 'UseTimeRange')
            set(useTimeRangeCheckbox, 'Value', eventcorrelation_settings.UseTimeRange);
        end
        if isfield(eventcorrelation_settings, 'TimeStart')
            set(timeStartEdit, 'String', num2str(eventcorrelation_settings.TimeStart*timeUnitFactor));
        end
        if isfield(eventcorrelation_settings, 'TimeEnd')
            set(timeEndEdit, 'String', num2str(eventcorrelation_settings.TimeEnd*timeUnitFactor));
        end
    end
    timeRangeCallback();
    % Попытка открыть последние использованные эвенты
    if ~isempty(eventcorrelation_settings) && isfield(eventcorrelation_settings, 'EventA_filepath') && ~isempty(eventcorrelation_settings.EventA_filepath) && exist(eventcorrelation_settings.EventA_filepath, 'file')
        loadEventFromPath(eventcorrelation_settings.EventA_filepath, 1);
    end
    if ~isempty(eventcorrelation_settings) && isfield(eventcorrelation_settings, 'EventB_filepath') && ~isempty(eventcorrelation_settings.EventB_filepath) && exist(eventcorrelation_settings.EventB_filepath, 'file')
        loadEventFromPath(eventcorrelation_settings.EventB_filepath, 2);
    end

    function timeRangeCallback(~, ~)
        isChecked = get(useTimeRangeCheckbox, 'Value');
        set(timeStartLabel, 'Visible', onOff(isChecked));
        set(timeStartEdit, 'Visible', onOff(isChecked));
        set(timeEndLabel, 'Visible', onOff(isChecked));
        set(timeEndEdit, 'Visible', onOff(isChecked));
        if isChecked && isempty(get(timeStartEdit, 'String')) && ~isempty(eventA_filepath) && ~isempty(eventB_filepath) && ~isempty(events1) && ~isempty(events2)
            tMin = min(min(events1), min(events2)) * timeUnitFactor;
            tMax = max(max(events1), max(events2)) * timeUnitFactor;
            set(timeStartEdit, 'String', num2str(tMin));
            set(timeEndEdit, 'String', num2str(tMax));
        end
    end

    function v = onOff(x)
        if x, v = 'on'; else, v = 'off'; end
    end

    function swapEventsAB(~, ~)
        tmp = events1; events1 = events2; events2 = tmp;
        tmp = eventA_filepath; eventA_filepath = eventB_filepath; eventB_filepath = tmp;
        [~, nA, ~] = fileparts(eventA_filepath); set(eventA_filename_text, 'String', nA);
        [~, nB, ~] = fileparts(eventB_filepath); set(eventB_filename_text, 'String', nB);
        updateRangeText(1);
        updateRangeText(2);
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
        loadEventFromPath(fullfile(path, file), eventNum);
    end

    function loadEventFromPath(filepath, eventNum)
        loadedData = load(filepath, '-mat');
        if ~isfield(loadedData, 'manlDet')
            return;
        end
        indices = round([loadedData.manlDet.t]);
        indices = max(1, min(indices, length(time)));
        [~, filename_only, ~] = fileparts(filepath);
        if eventNum == 1
            events1 = time(indices)';
            eventA_filepath = filepath;
            set(eventA_filename_text, 'String', filename_only);
            updateRangeText(1);
        else
            events2 = time(indices)';
            eventB_filepath = filepath;
            set(eventB_filename_text, 'String', filename_only);
            updateRangeText(2);
        end
        if eventNum == 1
            eventcorrelation_settings.EventA_filepath = eventA_filepath;
        else
            eventcorrelation_settings.EventB_filepath = eventB_filepath;
        end
        save(SettingsFilepath, 'eventcorrelation_settings', '-append');
    end

    function updateRangeText(eventNum)
        if eventNum == 1
            if isempty(events1)
                set(eventA_range_text, 'String', 'A: —');
            else
                set(eventA_range_text, 'String', sprintf('A: [%.2f, %.2f] %s, n=%d', ...
                    min(events1)*timeUnitFactor, max(events1)*timeUnitFactor, selectedUnit, length(events1)));
            end
        else
            if isempty(events2)
                set(eventB_range_text, 'String', 'B: —');
            else
                set(eventB_range_text, 'String', sprintf('B: [%.2f, %.2f] %s, n=%d', ...
                    min(events2)*timeUnitFactor, max(events2)*timeUnitFactor, selectedUnit, length(events2)));
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

        ev1 = events1;
        ev2 = events2;
        useTimeRange = get(useTimeRangeCheckbox, 'Value');
        if useTimeRange
            tStart = str2double(get(timeStartEdit, 'String')) / timeUnitFactor;
            tEnd = str2double(get(timeEndEdit, 'String')) / timeUnitFactor;
            if tStart >= tEnd
                errordlg('Time start must be less than time end.', 'Error');
                return;
            end
            ev1 = events1(events1 >= tStart & events1 <= tEnd);
            ev2 = events2(events2 >= tStart & events2 <= tEnd);
            if isempty(ev1) || isempty(ev2)
                errordlg('No events in the selected time range for one or both event sets.', 'Error');
                return;
            end
        end

        % Compute histograms of events with common edges
        minTime = min([min(ev1), min(ev2)]);
        maxTime = max([max(ev1), max(ev2)]);
        edges = minTime:binSize:maxTime;
        eventHist1 = histcounts(ev1, edges, 'Normalization', 'count');
        eventHist2 = histcounts(ev2, edges, 'Normalization', 'count');

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
        % Ноль оси = события B (время A относительно B)
        xAxisLabel = ['Time B (' selectedUnit ')'];

        % Trim the cross-correlation result to the specified window size
        validIndices = abs(lagTimes) <= windowSize / 2;
        lagTimes_scaled = lagTimes_scaled(validIndices);
        crossCorr = crossCorr(validIndices);

        % Plot the cross-correlation result on ax1 (столбиками по бинам)
        axes(ax1);
        set(ax1, 'visible', 'on');
        cla; hold on;
        bar(lagTimes_scaled, crossCorr, 1, 'FaceColor', [0 0 0.8], 'EdgeColor', [0 0 0.6]);
        xline(0, 'r:');
        xlabel(xAxisLabel);
        ylabel('Cross-Correlation');
        title('Cross-Corr. A rel. B');
        xlim(Xlims);
        grid on;
        set(ax1, 'XColor', [1 0 0]);
        hold off;
        
        % Вычисляем относительное время событий (ev1 относительно ближайших ev2)
        rel_times = [];
        for i = 1:length(ev1)
            event_time = ev1(i);
            [~, closest_idx] = min(abs(ev2 - event_time));
            closest_event2 = ev2(closest_idx);
            rel_time = event_time - closest_event2;
            rel_times = [rel_times; rel_time];
        end
        
        % Конвертируем относительные времена в единицы отображения
        rel_times_scaled = rel_times * timeUnitFactor;
        
        % Debug: диапазон данных и ограничение по окну (ev1 относительно ev2 = имена файлов A/B)
        rel_min = min(rel_times_scaled);
        rel_max = max(rel_times_scaled);
        nInWindow = sum(rel_times_scaled >= Xlims(1) & rel_times_scaled <= Xlims(2));
        nBelow = sum(rel_times_scaled < Xlims(1));
        nAbove = sum(rel_times_scaled > Xlims(2));
        [~, name1, ~] = fileparts(eventA_filepath);
        [~, name2, ~] = fileparts(eventB_filepath);
        fprintf('[eventCrossCorrelation] %s relative to %s: n=%d, rel_times range [%.2f, %.2f] %s\n', name1, name2, length(rel_times_scaled), rel_min, rel_max, selectedUnit);
        fprintf('  Window Xlims [%.2f, %.2f] %s: inside=%d, below=%d, above=%d\n', Xlims(1), Xlims(2), selectedUnit, nInWindow, nBelow, nAbove);
        
        % Строим боксплот на ax3
        axes(ax3);
        set(ax3, 'visible', 'on');
        cla; hold on;
        
        boxplot(rel_times_scaled, 'Orientation', 'horizontal');
        hBox = findobj(gca, 'Tag', 'Box');
        set(hBox, 'Color', [0 0 0.8]);
        hold on;
        
        % Добавляем точки данных с небольшим jitter по вертикали, смещенные ниже боксплота (A — синий)
        y_jitter = 0.5 + 0.15 * (rand(size(rel_times_scaled)) - 0.5);
        scatter(rel_times_scaled, y_jitter, 20, [0 0 0.8], '.', 'MarkerFaceAlpha', 0.6);
        
        xlabel(xAxisLabel);
        ylabel('Events');
        title(sprintf('Event A timing rel. B (n=%d)', length(rel_times)));
        xlim(Xlims);
        grid on;
        set(ax3, 'XColor', [1 0 0]);
        hold off;
        
        % Строим гистограмму на ax4 с использованием BinSize
        axes(ax4);
        set(ax4, 'visible', 'on');
        cla; hold on;
        
        % Используем BinSize для создания edges гистограммы
        binSize_scaled = binSize * timeUnitFactor; % BinSize в единицах отображения
        edges_hist = Xlims(1):binSize_scaled:Xlims(2);
        histogram(rel_times_scaled, edges_hist, 'Normalization', 'probability', 'FaceColor', [0 0 0.8], 'EdgeColor', [0 0 0.6]);
        
        xlabel(xAxisLabel);
        ylabel('Probability');
        title('Distr. of rel. event times');
        xlim(Xlims);
        grid on;
        set(ax4, 'XColor', [1 0 0]);
        hold off;
        
        % Сохранение настроек после анализа (в секундах)
        eventcorrelation_settings.Normalize = get(normalizeCheckbox, 'Value');
        eventcorrelation_settings.WindowSize = windowSize; % уже в секундах
        eventcorrelation_settings.BinSize = binSize; % уже в секундах
        eventcorrelation_settings.UseTimeRange = useTimeRange;
        if useTimeRange
            eventcorrelation_settings.TimeStart = tStart;
            eventcorrelation_settings.TimeEnd = tEnd;
        end
        eventcorrelation_settings.EventA_filepath = eventA_filepath;
        eventcorrelation_settings.EventB_filepath = eventB_filepath;
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
        correlation_result.numEventsA = length(ev1);
        correlation_result.numEventsB = length(ev2);
        
        % Сохраняем метаданные о событиях (отфильтрованные при Use time range)
        correlation_result.eventA_filepath = eventA_filepath;
        correlation_result.eventB_filepath = eventB_filepath;
        correlation_result.eventA_timestamps = ev1;
        correlation_result.eventB_timestamps = ev2;
        
        % Текст под графиками: сколько событий A и B пошло в анализ
        if useTimeRange
            set(eventsCountText, 'String', sprintf('After time filter: Events A: %d, Events B: %d', length(ev1), length(ev2)));
        else
            set(eventsCountText, 'String', sprintf('Events A: %d, Events B: %d', length(ev1), length(ev2)));
        end
        
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
        old_buttons = findobj(hFig, 'Type', 'uicontrol', 'Style', 'pushbutton', 'Tag', 'eventcorr_save_btn');
        if ~isempty(old_buttons)
            delete(old_buttons);
        end
        
        % Кнопка для сохранения результата
        save_btn_coords = [10, ypos(7)-45, 280, 30];
        savebutton = uicontrol('Parent', hFig, 'Style', 'pushbutton', 'String', 'Save Result', 'Tag', 'eventcorr_save_btn', 'Visible', 'on', 'Position', save_btn_coords, 'Callback', @SaveResultClb);
        btnIcon(savebutton, fullfile(getAssetsPath(), 'data-storage.png'), false);
        
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
