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
                  'Position', [100, 100, 1100, 500], 'Resize', 'on', ...
                  'MenuBar', 'none', 'ToolBar', 'figure', ...
                  'Visible', 'off', ...
                  'Tag', figTag);

    % Аналог "особого приема" из autoEventDetectionGUI:
    % не отключаем toolbar при создании, а потом делаем его невидимым
    hToolbar = findall(hFig, 'Type', 'uitoolbar');
    if ~isempty(hToolbar)
        set(hToolbar, 'Visible', 'off');
    end
    
    % Контейнер для графиков и раскладка через tiledlayout
    plotPanel = uipanel('Parent', hFig, ...
        'Units', 'normalized', ...
        'Position', [0.32 0.06 0.68 0.88], ...
        'Tag', 'eventCorr_plotPanel');
    t = tiledlayout(plotPanel, 3, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    
    % Axes:
    % - ax1: сверху большой блок (занимает все строки, 1-й столбец)
    % - ax3/ax4/ax5: вертикальная колонка (2-й столбец)
    ax1 = nexttile(t, [3 1]);
    ax3 = nexttile(t);
    ax4 = nexttile(t);
    ax5 = nexttile(t);
    
    set(ax1, 'visible', 'off')
    set(ax3, 'visible', 'off')
    set(ax4, 'visible', 'off')
    set(ax5, 'visible', 'off')

    % Текст под графиками: число событий A и B после фильтрации (если была)
    eventsCountText = uicontrol(hFig, 'Style', 'text', 'Position', [385, 45, 550, 22], ...
        'String', '', 'HorizontalAlignment', 'left', 'FontSize', 9);

    % Система позиций для элементов (под блоками A/B — кнопка Swap, затем Normalize и ниже)
    ypos = [460, 381, 295, 246, 197, 149, 100, 52];
    
    % Create UI elements
    selectEventLabelA = uicontrol(hFig, 'Style', 'text', 'Position', [10, ypos(1), 150, 20], ...
              'String', 'Select Event File A:');
    loadEventButtonA = uicontrol(hFig, 'Style', 'pushbutton', 'Position', [160, ypos(1), 130, 20], ...
              'String', 'Load Event A', 'Callback', @(~,~) loadEventFile(1), 'ForegroundColor', [0 0 1]);
    eventA_filename_text = uicontrol(hFig, 'Style', 'text', 'Position', [10, ypos(1)-20, 260, 20], ...
              'String', '', 'HorizontalAlignment', 'left');
    eventA_range_text = uicontrol(hFig, 'Style', 'text', 'Position', [10, ypos(1)-40, 260, 18], ...
              'String', '', 'HorizontalAlignment', 'left', 'FontSize', 9);

    selectEventLabelB = uicontrol(hFig, 'Style', 'text', 'Position', [10, ypos(2), 150, 20], ...
              'String', 'Select Event File B:');
    loadEventButtonB = uicontrol(hFig, 'Style', 'pushbutton', 'Position', [160, ypos(2), 130, 20], ...
              'String', 'Load Event B', 'Callback', @(~,~) loadEventFile(2), 'ForegroundColor', [1 0 0]);
    eventB_filename_text = uicontrol(hFig, 'Style', 'text', 'Position', [10, ypos(2)-20, 260, 20], ...
              'String', '', 'HorizontalAlignment', 'left');
    eventB_range_text = uicontrol(hFig, 'Style', 'text', 'Position', [10, ypos(2)-40, 260, 18], ...
              'String', '', 'HorizontalAlignment', 'left', 'FontSize', 9);

    swapButton = uicontrol(hFig, 'Style', 'pushbutton', 'Position', [10, ypos(2)-62, 280, 20], ...
              'String', 'Swap A and B', 'Callback', @swapEventsAB);

    % Названия для групп A и B (используются во всех подписях на графиках)
    uicontrol(hFig, 'Style', 'text', 'Position', [300, ypos(1), 70, 20], ...
              'String', 'Label A:');
    labelAEdit = uicontrol(hFig, 'Style', 'edit', 'Position', [370, ypos(1), 200, 20], ...
              'String', 'A', 'HorizontalAlignment', 'left');
    uicontrol(hFig, 'Style', 'text', 'Position', [300, ypos(2), 70, 20], ...
              'String', 'Label B:');
    labelBEdit = uicontrol(hFig, 'Style', 'edit', 'Position', [370, ypos(2), 200, 20], ...
              'String', 'B', 'HorizontalAlignment', 'left');

    normalizeCheckbox = uicontrol(hFig, 'Style', 'checkbox', 'Position', [10, ypos(3), 150, 20], ...
                                  'String', 'Normalize');
    plotModeOptions = {'Cross-Correlation', 'Timing Boxplot', 'Timing Histogram', 'Amplitude Comparison'};
    uicontrol(hFig, 'Style', 'text', 'Position', [300, ypos(3), 90, 20], ...
              'String', 'Show plots:');
    plotModeCheckboxes = gobjects(numel(plotModeOptions), 1);
    plotModeCheckboxes(1) = uicontrol(hFig, 'Style', 'checkbox', 'Position', [390, ypos(3), 180, 20], ...
        'String', plotModeOptions{1}, 'Value', 1);
    plotModeCheckboxes(2) = uicontrol(hFig, 'Style', 'checkbox', 'Position', [390, ypos(3)-22, 180, 20], ...
        'String', plotModeOptions{2}, 'Value', 0);
    plotModeCheckboxes(3) = uicontrol(hFig, 'Style', 'checkbox', 'Position', [390, ypos(3)-44, 180, 20], ...
        'String', plotModeOptions{3}, 'Value', 0);
    plotModeCheckboxes(4) = uicontrol(hFig, 'Style', 'checkbox', 'Position', [390, ypos(3)-66, 180, 20], ...
        'String', plotModeOptions{4}, 'Value', 0);

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
    % Амплитуды детектированных событий (если есть в файле)
    eventAmplitudes1 = [];
    eventAmplitudes2 = [];
    
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
        if isfield(eventcorrelation_settings, 'LabelA')
            set(labelAEdit, 'String', eventcorrelation_settings.LabelA);
        end
        if isfield(eventcorrelation_settings, 'LabelB')
            set(labelBEdit, 'String', eventcorrelation_settings.LabelB);
        end
        if isfield(eventcorrelation_settings, 'PlotModes')
            for iMode = 1:numel(plotModeOptions)
                set(plotModeCheckboxes(iMode), 'Value', any(strcmp(eventcorrelation_settings.PlotModes, plotModeOptions{iMode})));
            end
        elseif isfield(eventcorrelation_settings, 'PlotMode')
            storedPlotMode = find(strcmp(plotModeOptions, eventcorrelation_settings.PlotMode), 1);
            if ~isempty(storedPlotMode)
                set(plotModeCheckboxes, 'Value', 0);
                set(plotModeCheckboxes(storedPlotMode), 'Value', 1);
            end
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
    updateLoadButtonsState();

    set(hFig, 'Visible', 'on');
    drawnow;
    hFig.WindowState = 'maximized';

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
        tmp = eventAmplitudes1; eventAmplitudes1 = eventAmplitudes2; eventAmplitudes2 = tmp;
        tmpLabel = get(labelAEdit, 'String');
        set(labelAEdit, 'String', get(labelBEdit, 'String'));
        set(labelBEdit, 'String', tmpLabel);
        [~, nA, ~] = fileparts(eventA_filepath); set(eventA_filename_text, 'String', nA);
        [~, nB, ~] = fileparts(eventB_filepath); set(eventB_filename_text, 'String', nB);
        updateRangeText(1);
        updateRangeText(2);
        updateLoadButtonsState();
    end

    function loadEventFile(eventNum)
        initialDir = pwd;
        if ~isempty(lastOpenedFiles)
            initialDir = fileparts(lastOpenedFiles{end});
        end
        [file, path] = uigetfile({'*.ev;*.mean', 'Event files (*.ev, *.mean)'}, 'Load Events', initialDir);
        if isequal(file, 0)
            disp('File selection canceled.');
            return;
        end
        loadEventFromPath(fullfile(path, file), eventNum);
    end

    function loadEventFromPath(filepath, eventNum)
        loadedData = load(filepath, '-mat');
        [eventTimesSec, amplitudes] = extractEventDataForCorrelation(loadedData);
        if isempty(eventTimesSec)
            warndlg('Selected file does not contain supported event data.', 'Load Events');
            return;
        end

        [~, filename_only, ~] = fileparts(filepath);
        if eventNum == 1
            events1 = eventTimesSec;
            eventAmplitudes1 = amplitudes;
            eventA_filepath = filepath;
            set(eventA_filename_text, 'String', filename_only);
            updateRangeText(1);
        else
            events2 = eventTimesSec;
            eventAmplitudes2 = amplitudes;
            eventB_filepath = filepath;
            set(eventB_filename_text, 'String', filename_only);
            updateRangeText(2);
        end
        updateLoadButtonsState();
        if eventNum == 1
            eventcorrelation_settings.EventA_filepath = eventA_filepath;
        else
            eventcorrelation_settings.EventB_filepath = eventB_filepath;
        end
        save(SettingsFilepath, 'eventcorrelation_settings', '-append');
    end

    function [eventTimesSec, amplitudes] = extractEventDataForCorrelation(loadedData)
        eventTimesSec = [];
        amplitudes = [];
        if ~isfield(loadedData, 'manlDet') || isempty(loadedData.manlDet)
            return;
        end
        if isempty(time)
            warndlg('Time axis is not loaded. Open a .mat file first.', 'Load Events');
            return;
        end

        indices = round([loadedData.manlDet.t]);
        indices = max(1, min(indices, length(time)));
        eventTimesSec = time(indices)';

        if isfield(loadedData.manlDet, 'amplitude')
            amplitudes = [loadedData.manlDet.amplitude]';
        else
            amplitudes = NaN(size(indices(:)));
        end

        amplitudes = amplitudes(:);
        if numel(amplitudes) ~= numel(eventTimesSec)
            amplitudes = NaN(size(eventTimesSec));
        end
    end

    function updateRangeText(eventNum)
        labelA = get(labelAEdit, 'String');
        labelB = get(labelBEdit, 'String');
        if isempty(labelA), labelA = 'A'; end
        if isempty(labelB), labelB = 'B'; end
        if eventNum == 1
            if isempty(events1)
                set(eventA_range_text, 'String', sprintf('%s: —', labelA));
            else
                set(eventA_range_text, 'String', sprintf('%s: [%.2f, %.2f] %s, n=%d', ...
                    labelA, min(events1)*timeUnitFactor, max(events1)*timeUnitFactor, selectedUnit, length(events1)));
            end
        else
            if isempty(events2)
                set(eventB_range_text, 'String', sprintf('%s: —', labelB));
            else
                set(eventB_range_text, 'String', sprintf('%s: [%.2f, %.2f] %s, n=%d', ...
                    labelB, min(events2)*timeUnitFactor, max(events2)*timeUnitFactor, selectedUnit, length(events2)));
            end
        end
    end

    function analyzeData(~, ~)
        selectedPlotMask = false(size(plotModeOptions));
        for iMode = 1:numel(plotModeOptions)
            selectedPlotMask(iMode) = get(plotModeCheckboxes(iMode), 'Value') == 1;
        end
        selectedPlotModes = plotModeOptions(selectedPlotMask);
        if isempty(selectedPlotModes)
            errordlg('Select at least one plot.', 'Error');
            return;
        end
        clearPlotAxes();
        for iMode = 1:numel(selectedPlotModes)
            targetAxis = getAxisByPlotMode(selectedPlotModes{iMode});
            axes(targetAxis);
            set(targetAxis, 'visible', 'on');
            cla;
            text(0.5, 0.5, 'Analyzing ...', 'HorizontalAlignment', 'center', ...
                 'VerticalAlignment', 'middle', 'FontSize', 14, 'Units', 'normalized');
            axis off;
        end
        drawnow;
        
        normalize = get(normalizeCheckbox, 'Value');
        windowSize = str2double(get(windowEdit, 'String')) / timeUnitFactor; % convert to seconds
        binSize = str2double(get(binSizeEdit, 'String')) / timeUnitFactor; % convert to seconds
        
        labelA = get(labelAEdit, 'String');
        labelB = get(labelBEdit, 'String');
        if isempty(labelA), labelA = 'A'; end
        if isempty(labelB), labelB = 'B'; end

        if isempty(events1) || isempty(events2)
            errordlg('Please load both event files.', 'Error');
            return;
        end
        
        if isempty(eventA_filepath) || isempty(eventB_filepath)
            errordlg('Event file paths are missing. Please reload event files.', 'Error');
            return;
        end

        ev1 = events1(:);
        ev2 = events2(:);
        amp1 = eventAmplitudes1(:);
        amp2 = eventAmplitudes2(:);
        useTimeRange = get(useTimeRangeCheckbox, 'Value');
        if useTimeRange
            tStart = str2double(get(timeStartEdit, 'String')) / timeUnitFactor;
            tEnd = str2double(get(timeEndEdit, 'String')) / timeUnitFactor;
            if tStart >= tEnd
                errordlg('Time start must be less than time end.', 'Error');
                return;
            end
            sel1 = ev1 >= tStart & ev1 <= tEnd;
            sel2 = ev2 >= tStart & ev2 <= tEnd;
            ev1 = ev1(sel1);
            ev2 = ev2(sel2);
            amp1 = amp1(sel1);
            amp2 = amp2(sel2);
            if isempty(ev1) || isempty(ev2)
                errordlg('No events in the selected time range for one or both event sets.', 'Error');
                return;
            end
        end

        % Единое ограничение оси X для всех графиков (в секундах)
        Xlims_seconds = [-windowSize/2, windowSize/2];
        
        % Конвертируем в единицы отображения
        Xlims = Xlims_seconds * timeUnitFactor;
        % Ноль оси = события B (время A относительно B)
        xAxisLabel = ['Time ' labelB ' (' selectedUnit ')'];
        amplitudeTest = struct('nA', NaN, 'nB', NaN, 'pvalue', NaN, 'tstat', NaN);
        rel_times = [];
        rel_times_scaled = [];
        lagTimes_scaled = [];
        crossCorr = [];

        if any(strcmp(selectedPlotModes, 'Cross-Correlation'))
            minTime = min([min(ev1), min(ev2)]);
            maxTime = max([max(ev1), max(ev2)]);
            maxTimeForEdges = max(maxTime, minTime + binSize);
            edges = minTime:binSize:maxTimeForEdges;
            eventHist1 = histcounts(ev1, edges, 'Normalization', 'count');
            eventHist2 = histcounts(ev2, edges, 'Normalization', 'count');
            if normalize
                [crossCorrRaw, lags] = xcorr(eventHist1, eventHist2, 'normalized');
            else
                [crossCorrRaw, lags] = xcorr(eventHist1, eventHist2);
            end
            lagTimes = lags * binSize;
            lagTimes_scaled = lagTimes * timeUnitFactor;
            validIndices = abs(lagTimes) <= windowSize / 2;
            lagTimes_scaled = lagTimes_scaled(validIndices);
            crossCorr = crossCorrRaw(validIndices);
            crossCorrToPlot = crossCorr;
            crossCorrYLabel = 'Cross-Correlation';
            if normalize
                crossCorrToPlot = crossCorr * 100;
                crossCorrYLabel = 'Cross-Correlation (%)';
            end

            axes(ax1);
            set(ax1, 'visible', 'on');
            cla; hold on;
            bar(lagTimes_scaled, crossCorrToPlot, 1, 'FaceColor', [0 0 0.8], 'EdgeColor', [0 0 0.6]);
            xline(0, 'r:');
            xlabel(xAxisLabel);
            ylabel(crossCorrYLabel);
            title(sprintf('Cross-Corr. %s rel. %s', labelA, labelB));
            xlim(Xlims);
            grid on;
            set(ax1, 'XColor', [1 0 0]);
            hold off;
        end

        if any(strcmp(selectedPlotModes, 'Timing Boxplot')) || any(strcmp(selectedPlotModes, 'Timing Histogram'))
            rel_times = computeRelativeTimes(ev1, ev2);
            rel_times_scaled = rel_times * timeUnitFactor;
            boxplotXLim = computeWhiskerLimitedXLim(rel_times_scaled, Xlims, binSize * timeUnitFactor);

            if any(strcmp(selectedPlotModes, 'Timing Boxplot'))
                axes(ax3);
                set(ax3, 'visible', 'on');
                cla; hold on;
                boxplot(rel_times_scaled, 'Orientation', 'horizontal', 'Symbol', '');
                hBox = findobj(gca, 'Tag', 'Box');
                set(hBox, 'Color', [0 0 0.8]);
                y_jitter = 0.5 + 0.15 * (rand(size(rel_times_scaled)) - 0.5);
                scatter(rel_times_scaled, y_jitter, 20, [0 0 0.8], '.', 'MarkerFaceAlpha', 0.6);
                xlabel(xAxisLabel);
                ylabel('Events');
                title(sprintf('Event %s timing rel. %s (n=%d)', labelA, labelB, length(rel_times)));
                xlim(ax3, boxplotXLim);
                grid on;
                set(ax3, 'XColor', [1 0 0]);
                hold off;
            end

            if any(strcmp(selectedPlotModes, 'Timing Histogram'))
                axes(ax4);
                set(ax4, 'visible', 'on');
                cla; hold on;
                binSize_scaled = binSize * timeUnitFactor;
                edges_hist = Xlims(1):binSize_scaled:Xlims(2);
                histogram(rel_times_scaled, edges_hist, 'Normalization', 'probability', 'FaceColor', [0 0 0.8], 'EdgeColor', [0 0 0.6]);
                xlabel(xAxisLabel);
                ylabel('Probability');
                title('Distr. of rel. event times');
                xlim(ax4, boxplotXLim);
                grid on;
                set(ax4, 'XColor', [1 0 0]);
                hold off;
            end
        end

        if any(strcmp(selectedPlotModes, 'Amplitude Comparison'))
            axes(ax5);
            set(ax5, 'visible', 'on');
            cla;
            hold on;

            ampA = amp1(:);
            ampB = amp2(:);
            validAmpA = ampA(~isnan(ampA) & ~isinf(ampA));
            validAmpB = ampB(~isnan(ampB) & ~isinf(ampB));
            amplitudeTest.nA = numel(validAmpA);
            amplitudeTest.nB = numel(validAmpB);
            ampColorA = [0 0 0.8];
            ampColorB = [1 0 0];

            hasAmplitudeData = ~isempty(validAmpA) && ~isempty(validAmpB);
            if hasAmplitudeData
                ampData = [validAmpA; validAmpB];
                ampGroups = [ones(numel(validAmpA), 1); 2 * ones(numel(validAmpB), 1)];
                boxplot(ampData, ampGroups, 'Labels', {labelA, labelB}, 'Symbol', '');

                hBoxes = findobj(gca, 'Tag', 'Box');
                if numel(hBoxes) >= 2
                    xMeans = zeros(numel(hBoxes), 1);
                    for i = 1:numel(hBoxes)
                        xData = get(hBoxes(i), 'XData');
                        if isempty(xData)
                            vertices = get(hBoxes(i), 'Vertices');
                            if ~isempty(vertices)
                                xMeans(i) = mean(vertices(:, 1));
                            else
                                xMeans(i) = NaN;
                            end
                        else
                            xMeans(i) = mean(xData);
                        end
                    end
                    [~, order] = sort(xMeans);
                    hBoxes = hBoxes(order);
                    set(hBoxes(1), 'Color', ampColorA, 'LineWidth', 1.2);
                    set(hBoxes(2), 'Color', ampColorB, 'LineWidth', 1.2);
                end

                q1A = prctile(validAmpA, 25);
                q3A = prctile(validAmpA, 75);
                iqrA = q3A - q1A;
                lowBoundA = q1A - 1.5 * iqrA;
                highBoundA = q3A + 1.5 * iqrA;
                lowAdjA = min([validAmpA(validAmpA >= lowBoundA); lowBoundA]);
                highAdjA = max([validAmpA(validAmpA <= highBoundA); highBoundA]);

                q1B = prctile(validAmpB, 25);
                q3B = prctile(validAmpB, 75);
                iqrB = q3B - q1B;
                lowBoundB = q1B - 1.5 * iqrB;
                highBoundB = q3B + 1.5 * iqrB;
                lowAdjB = min([validAmpB(validAmpB >= lowBoundB); lowBoundB]);
                highAdjB = max([validAmpB(validAmpB <= highBoundB); highBoundB]);
                ylim(ax5, [min([lowAdjA lowAdjB]) max([highAdjA highAdjB])]);

                xlabel('Group');
                ylabel('Amplitude');
                title(sprintf('Amplitude comparison %s vs %s', labelA, labelB));
                grid on;

                try
                    [~, pvalue, ~, stats] = ttest2(validAmpA, validAmpB);
                    amplitudeTest.pvalue = pvalue;
                    if isfield(stats, 'tstat')
                        amplitudeTest.tstat = stats.tstat;
                    end
                catch
                end

                txt = sprintf('p=%.4g, t=%.3f', amplitudeTest.pvalue, amplitudeTest.tstat);
                text(0.5, 0.98, txt, 'Units', 'normalized', ...
                    'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', ...
                    'FontSize', 9, 'BackgroundColor', 'w');
            else
                set(ax5, 'visible', 'off');
            end

            hold off;
        end
        
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
        eventcorrelation_settings.LabelA = labelA;
        eventcorrelation_settings.LabelB = labelB;
        eventcorrelation_settings.PlotModes = selectedPlotModes;
        eventcorrelation_settings.PlotMode = selectedPlotModes{1};
        save(SettingsFilepath, 'eventcorrelation_settings', '-append');
        
        % Сохраняем результаты для возможности сохранения
        correlation_result = struct();
        correlation_result.plotModes = selectedPlotModes;
        correlation_result.plotMode = selectedPlotModes{1};
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
        correlation_result.amplitudeTest = amplitudeTest;
        
        % Сохраняем метаданные о событиях (отфильтрованные при Use time range)
        correlation_result.eventA_filepath = eventA_filepath;
        correlation_result.eventB_filepath = eventB_filepath;
        correlation_result.eventA_timestamps = ev1;
        correlation_result.eventB_timestamps = ev2;
        correlation_result.labelA = labelA;
        correlation_result.labelB = labelB;
        
        % Текст под графиками: сколько событий A и B пошло в анализ
        if useTimeRange
            set(eventsCountText, 'String', sprintf('After time filter: Events %s: %d, Events %s: %d', labelA, length(ev1), labelB, length(ev2)));
        else
            set(eventsCountText, 'String', sprintf('Events %s: %d, Events %s: %d', labelA, length(ev1), labelB, length(ev2)));
        end
        
        % Создаем кнопки сохранения после анализа
        createSaveButtons();
    end

    function targetAxis = getAxisByPlotMode(plotMode)
        switch plotMode
            case 'Cross-Correlation'
                targetAxis = ax1;
            case 'Timing Boxplot'
                targetAxis = ax3;
            case 'Timing Histogram'
                targetAxis = ax4;
            case 'Amplitude Comparison'
                targetAxis = ax5;
        end
    end

    function clearPlotAxes()
        axesList = [ax1, ax3, ax4, ax5];
        for iAx = 1:numel(axesList)
            cla(axesList(iAx));
            axis(axesList(iAx), 'on');
            set(axesList(iAx), 'visible', 'off');
        end
    end

    function rel_times = computeRelativeTimes(ev1Input, ev2Input)
        rel_times = zeros(length(ev1Input), 1);
        for i = 1:length(ev1Input)
            [~, closest_idx] = min(abs(ev2Input - ev1Input(i)));
            rel_times(i) = ev1Input(i) - ev2Input(closest_idx);
        end
    end

    function xLimResult = computeWhiskerLimitedXLim(dataScaled, xLimBase, padStep)
        q1 = prctile(dataScaled, 25);
        q3 = prctile(dataScaled, 75);
        iqrValue = q3 - q1;
        lowBound = q1 - 1.5 * iqrValue;
        highBound = q3 + 1.5 * iqrValue;
        lowAdj = min([dataScaled(dataScaled >= lowBound); lowBound]);
        highAdj = max([dataScaled(dataScaled <= highBound); highBound]);
        xlimCandidate = [max(xLimBase(1), lowAdj), min(xLimBase(2), highAdj)];
        xLeft = min(xlimCandidate);
        xRight = max(xlimCandidate);
        xPad = max(eps(max(abs(xlimCandidate))), padStep);
        xLimResult = [xLeft, xRight + (xRight == xLeft) * xPad];
    end

    function updateLoadButtonsState()
        set(loadEventButtonA, 'Enable', 'on');
        set(loadEventButtonB, 'Enable', 'on');
        set(swapButton, 'Enable', 'on');
        set(selectEventLabelA, 'ForegroundColor', [0 0 0]);
        set(selectEventLabelB, 'ForegroundColor', [0 0 0]);
        updateRangeText(1);
        updateRangeText(2);
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
        
        % Чекбокс: открывать сохраненный файл системными средствами
        old_open_checkbox = findobj(hFig, 'Type', 'uicontrol', 'Style', 'checkbox', 'Tag', 'eventcorr_open_after_export_cb');
        if ~isempty(old_open_checkbox)
            delete(old_open_checkbox);
        end
        openAfterExportCheckbox = uicontrol('Parent', hFig, ...
            'Style', 'checkbox', ...
            'Tag', 'eventcorr_open_after_export_cb', ...
            'String', 'Open after export', ...
            'Position', [10, ypos(7)-80, 220, 20], ...
            'Value', 0);
        
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
            
            % Сохраняем ТОЛЬКО контейнер с графикой (plotPanel)
            filename_fig = fullfile(path, file);
            switch filterindex
                case 1
                    exportgraphics(plotPanel, filename_fig, 'ContentType', 'vector');
                case 2
                    exportgraphics(plotPanel, filename_fig, 'ContentType', 'vector');
                case 3
                    exportgraphics(plotPanel, filename_fig, 'Resolution', 300);
                otherwise
                    exportgraphics(plotPanel, filename_fig);
            end
            disp(['Image saved to ', filename_fig]);
            
            % Открываем сохраненный файл ассоциированным приложением
            if get(openAfterExportCheckbox, 'Value') == 1
                system(sprintf('cmd /c start "" "%s"', filename_fig));
            end
            
            % Автоматически сохраняем данные в .meta файл в той же папке
            [~, name_fig, ~] = fileparts(filename_fig);
            filename_meta = fullfile(path, [name_fig '.meta']);
            save(filename_meta, '-struct', 'correlation_result');
            save(filename_meta, 'original_filename', '-append');
            disp(['Data saved to ', filename_meta]);
        end
    end
end
