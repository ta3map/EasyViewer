function eventCrossCorrelationGUI()
    % Global variables
    global time events1 events2 lastOpenedFiles

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
                  'Position', [100, 100, 450, 350], 'Resize', 'off', ...
                  'NumberTitle', 'off', 'MenuBar', 'none', 'ToolBar', 'none', ...
                  'Tag', figTag, 'WindowStyle', 'normal');

    % Create UI elements
    uicontrol('Style', 'text', 'Position', [20, 300, 150, 20], ...
              'String', 'Select Event File 1:');
    uicontrol('Style', 'pushbutton', 'Position', [20, 270, 150, 30], ...
              'String', 'Load Event 1', 'Callback', @(~,~) loadEventFile(1));

    uicontrol('Style', 'text', 'Position', [220, 300, 150, 20], ...
              'String', 'Select Event File 2:');
    uicontrol('Style', 'pushbutton', 'Position', [220, 270, 150, 30], ...
              'String', 'Load Event 2', 'Callback', @(~,~) loadEventFile(2));

    normalizeCheckbox = uicontrol('Style', 'checkbox', 'Position', [20, 240, 150, 20], ...
                                  'String', 'Normalize');

    uicontrol('Style', 'text', 'Position', [20, 210, 150, 20], ...
              'String', 'Window Size (s):');
    windowEdit = uicontrol('Style', 'edit', 'Position', [20, 190, 150, 20], ...
                           'String', '10');

    uicontrol('Style', 'text', 'Position', [20, 160, 150, 20], ...
              'String', 'Bin Size (ms):');
    binSizeEdit = uicontrol('Style', 'edit', 'Position', [20, 140, 150, 20], ...
                            'String', '10');

    uicontrol('Style', 'text', 'Position', [20, 110, 150, 20], ...
              'String', 'X-Axis Unit:');
    xAxisPopup = uicontrol('Style', 'popupmenu', 'Position', [20, 90, 150, 20], ...
                           'String', {'Seconds', 'Minutes', 'Milliseconds'});

    analyzeButton = uicontrol('Style', 'pushbutton', 'Position', [220, 90, 150, 30], ...
                              'String', 'Analyze', 'Callback', @analyzeData);

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
            if eventNum == 1
                events1 = time(round([loadedData.manlDet.t]))'; % Update events1
            else
                events2 = time(round([loadedData.manlDet.t]))'; % Update events2
            end
        end

        lastOpenedFiles{end + 1} = filepath; % Update last opened files
    end

    function analyzeData(~, ~)
        normalize = get(normalizeCheckbox, 'Value');
        windowSize = str2double(get(windowEdit, 'String')); % seconds
        binSize = str2double(get(binSizeEdit, 'String')) / 1000; % convert ms to seconds
        xAxisUnit = get(xAxisPopup, 'Value');

        if isempty(events1) || isempty(events2)
            errordlg('Please load both event files.', 'File Load Error');
            return;
        end

        % Compute histograms of events
        edges1 = min(events1):binSize:max(events1);
        edges2 = min(events2):binSize:max(events2);
        eventHist1 = histcounts(events1, edges1, 'Normalization', 'count');
        eventHist2 = histcounts(events2, edges2, 'Normalization', 'count');

        % Compute cross-correlation
        if normalize
            [crossCorr, lags] = xcorr(eventHist1, eventHist2, 'normalized');
        else
            [crossCorr, lags] = xcorr(eventHist1, eventHist2);
        end

        % Convert lags to time in seconds
        sampleRate = 1 / binSize;
        lagTimes = lags / sampleRate;

        % Convert lag times to desired unit
        switch xAxisUnit
            case 1 % Seconds
                xAxisLabel = 'Time (s)';
            case 2 % Minutes
                lagTimes = lagTimes / 60;
                xAxisLabel = 'Time (min)';
                windowSize = windowSize / 60;
            case 3 % Milliseconds
                lagTimes = lagTimes * 1000;
                xAxisLabel = 'Time (ms)';
                windowSize = windowSize * 1000;
        end

        % Trim the cross-correlation result to the specified window size
        validIndices = abs(lagTimes) <= windowSize / 2;
        lagTimes = lagTimes(validIndices);
        crossCorr = crossCorr(validIndices);

        % Plot the result
        figure('Name', 'Cross-Correlation Result', 'NumberTitle', 'off');
        plot(lagTimes, crossCorr);
        xline(0, 'r:');
        xlabel(xAxisLabel);
        ylabel('Cross-Correlation');
        title('Cross-Correlation Between Events');
    end

    uiwait(hFig);
end
