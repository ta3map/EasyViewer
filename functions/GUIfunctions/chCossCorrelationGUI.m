function chCossCorrelationGUI()
    % Global variables
    global lfp_file time channelNames events Fs

    % Tag for GUI figure
    figTag = 'chCrossCorrelationGUI';

    % Search for an open figure with the given tag
    guiFig = findobj('Type', 'figure', 'Tag', figTag);

    if ~isempty(guiFig)
        % Make the existing window the current figure
        figure(guiFig);
        return
    end

    % Initialize GUI
    hFig = figure('Name', 'Cross-Correlation Between Channels', 'NumberTitle', 'off', ...
                  'Position', [100, 100, 450, 750], 'Resize', 'off', ...
                  'NumberTitle', 'off', 'MenuBar', 'none', 'ToolBar', 'none', ...
                  'Tag', figTag, 'WindowStyle', 'normal');

    % Create UI elements
    uicontrol('Style', 'text', 'Position', [20, 600, 150, 20], ...
              'String', 'Select Channels from Group 1:');
    channelList1 = uicontrol('Style', 'listbox', 'Position', [20, 350, 150, 250], ...
                             'String', channelNames, 'Max', length(channelNames), 'Min', 1);
    invertCheckbox1 = uicontrol('Style', 'checkbox', 'Position', [20, 330, 150, 20], ...
                                 'String', 'Invert signal');
    
    uicontrol('Style', 'text', 'Position', [220, 600, 150, 20], ...
              'String', 'Select Channels from Group 2:');
    channelList2 = uicontrol('Style', 'listbox', 'Position', [220, 350, 150, 250], ...
                             'String', channelNames, 'Max', length(channelNames), 'Min', 1);
    invertCheckbox2 = uicontrol('Style', 'checkbox', 'Position', [220, 330, 150, 20], ...
                                 'String', 'Invert signal');

    normalizeCheckbox = uicontrol('Style', 'checkbox', 'Position', [20, 320, 150, 20], ...
                                  'String', 'Normalize');

    uicontrol('Style', 'text', 'Position', [20, 290, 150, 20], ...
              'String', 'Signal preprocessing:');
    preprocessingPopup = uicontrol('Style', 'popupmenu', 'Position', [20, 270, 150, 20], ...
                                   'String', {'None', 'Detrend', 'Demean', 'Baseline correction'});

    timeRangeCheckbox = uicontrol('Style', 'checkbox', 'Position', [20, 240, 150, 20], ...
                                  'String', 'Use time range', ...
                                  'Callback', @timeRangeCallback);

    startTimeLabel = uicontrol('Style', 'text', 'Position', [20, 210, 80, 20], ...
                               'String', 'Start (s):', 'Visible', 'off');
    startTimeEdit = uicontrol('Style', 'edit', 'Position', [100, 210, 70, 20], ...
                              'String', num2str(time(1)), 'Visible', 'off');

    endTimeLabel = uicontrol('Style', 'text', 'Position', [20, 180, 80, 20], ...
                             'String', 'End (s):', 'Visible', 'off');
    endTimeEdit = uicontrol('Style', 'edit', 'Position', [100, 180, 70, 20], ...
                            'String', num2str(time(end)), 'Visible', 'off');

    eventsCheckbox = uicontrol('Style', 'checkbox', 'Position', [20, 150, 150, 20], ...
                               'String', 'Use events windows', ...
                               'Callback', @eventsCallback);

    eventWindowLabel = uicontrol('Style', 'text', 'Position', [20, 120, 150, 20], ...
                                 'String', 'Event window (s):', 'Visible', 'off');
    eventWindowEdit = uicontrol('Style', 'edit', 'Position', [20, 100, 150, 20], ...
                                'String', '2', 'Visible', 'off');

    uicontrol('Style', 'text', 'Position', [220, 150, 150, 20], ...
              'String', 'Result processing:');
    resultProcessingPopup = uicontrol('Style', 'popupmenu', 'Position', [220, 130, 150, 20], ...
                                      'String', {'None', 'Smoothing', 'Peak detection'});

    uicontrol('Style', 'text', 'Position', [220, 110, 150, 20], ...
              'String', 'Window Size (s):');
    windowEdit = uicontrol('Style', 'edit', 'Position', [220, 90, 150, 20], ...
                           'String', '10');

    uicontrol('Style', 'text', 'Position', [220, 70, 150, 20], ...
              'String', 'X-Axis Unit:');
    xAxisPopup = uicontrol('Style', 'popupmenu', 'Position', [220, 50, 150, 20], ...
                           'String', {'Seconds', 'Minutes', 'Milliseconds'});

    analyzeButton = uicontrol('Style', 'pushbutton', 'Position', [20, 5, 410, 30], ...
                              'String', 'Analyze', 'Callback', @analyzeData);

    function timeRangeCallback(~, ~)
        isChecked = get(timeRangeCheckbox, 'Value');
        if isChecked
            set(eventsCheckbox, 'Value', 0);
            set(eventWindowLabel, 'Visible', 'off');
            set(eventWindowEdit, 'Visible', 'off');
        end
        if isChecked
            set(startTimeLabel, 'Visible', 'on');
            set(startTimeEdit, 'Visible', 'on');
            set(endTimeLabel, 'Visible', 'on');
            set(endTimeEdit, 'Visible', 'on');
        else
            set(startTimeLabel, 'Visible', 'off');
            set(startTimeEdit, 'Visible', 'off');
            set(endTimeLabel, 'Visible', 'off');
            set(endTimeEdit, 'Visible', 'off');
        end
    end

    function eventsCallback(~, ~)
        isChecked = get(eventsCheckbox, 'Value');
        if isChecked
            set(timeRangeCheckbox, 'Value', 0);
            set(startTimeLabel, 'Visible', 'off');
            set(startTimeEdit, 'Visible', 'off');
            set(endTimeLabel, 'Visible', 'off');
            set(endTimeEdit, 'Visible', 'off');
        end
        if isChecked
            set(eventWindowLabel, 'Visible', 'on');
            set(eventWindowEdit, 'Visible', 'on');
        else
            set(eventWindowLabel, 'Visible', 'off');
            set(eventWindowEdit, 'Visible', 'off');
        end
    end

    function analyzeData(~, ~)
        selectedChannels1 = channelList1.Value;
        selectedChannels2 = channelList2.Value;
        normalize = get(normalizeCheckbox, 'Value');
        preprocessingMethod = get(preprocessingPopup, 'Value');
        useTimeRange = get(timeRangeCheckbox, 'Value');
        useEvents = get(eventsCheckbox, 'Value');
        resultProcessing = get(resultProcessingPopup, 'Value');
        windowSize = str2double(get(windowEdit, 'String')); % seconds
        
        xAxisUnit = get(xAxisPopup, 'Value');
        
        if isempty(selectedChannels1) || isempty(selectedChannels2)
            fprintf('Please select channels from both groups.\n');
            return;
        end

        opts = struct();
        opts.chA = selectedChannels1;
        opts.chB = selectedChannels2;
        opts.invertA = get(invertCheckbox1, 'Value') ~= 0;
        opts.invertB = get(invertCheckbox2, 'Value') ~= 0;
        opts.preprocess = preprocessingMethod;
        opts.normalize = normalize ~= 0;
        opts.windowSize_sec = windowSize;
        opts.resultProcessing = resultProcessing;
        opts.useEvents = useEvents ~= 0;
        opts.useTimeRange = useTimeRange ~= 0;
        opts.time = time;
        opts.events = events;
        opts.eventWindow_sec = str2double(get(eventWindowEdit, 'String'));
        opts.startTime = str2double(get(startTimeEdit, 'String'));
        opts.endTime = str2double(get(endTimeEdit, 'String'));

        result = channelCrossCorrelation(lfp_file.lfp, Fs, opts);
        if ~result.ok
            fprintf('%s\n', result.message);
            return;
        end

        lagTimes = result.lagTimes;
        crossCorr = result.crossCorr;
        peakLag = result.peakLag;
        peakValue = result.peakValue;

        switch xAxisUnit
            case 1
                xAxisLabel = 'Time (s)';
            case 2
                lagTimes = lagTimes / 60;
                if ~isempty(peakLag)
                    peakLag = peakLag / 60;
                end
                xAxisLabel = 'Time (min)';
            case 3
                lagTimes = lagTimes * 1000;
                if ~isempty(peakLag)
                    peakLag = peakLag * 1000;
                end
                xAxisLabel = 'Time (ms)';
        end

        figure('Name', 'Cross-Correlation Result', 'NumberTitle', 'off');
        plot(lagTimes, crossCorr);
        xline(0, 'r:')
        xlabel(xAxisLabel);
        ylabel('Cross-Correlation');
        
        titleStr = 'Cross-Correlation Between Selected Channels';
        if useEvents
            titleStr = sprintf('%s (using %d events)', titleStr, numel(events));
        end
        if resultProcessing == 3 && ~isempty(peakLag)
            unitMatch = regexp(xAxisLabel, '\(([^)]+)\)', 'tokens');
            if ~isempty(unitMatch)
                unit = unitMatch{1}{1};
            else
                unit = '';
            end
            titleStr = sprintf('%s\nPeak at %.3f %s (value: %.3f)', titleStr, peakLag, unit, peakValue);
        end
        title(titleStr);
        
        if resultProcessing == 3 && ~isempty(peakLag)
            hold on;
            plot(peakLag, peakValue, 'ro', 'MarkerSize', 10, 'LineWidth', 2);
            hold off;
        end
    end

    uiwait(hFig);
end
