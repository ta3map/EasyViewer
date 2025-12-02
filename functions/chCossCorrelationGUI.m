function chCossCorrelationGUI()
    % Global variables
    global lfp time channelNames events Fs

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

        % Compute the sum of the selected channels
        sumSignal1 = nansum(lfp(:, selectedChannels1), 2);
        sumSignal2 = nansum(lfp(:, selectedChannels2), 2);
        
        % Invert signals if checkboxes are enabled
        if get(invertCheckbox1, 'Value')
            sumSignal1 = -sumSignal1;
        end
        if get(invertCheckbox2, 'Value')
            sumSignal2 = -sumSignal2;
        end
        
        % Apply signal preprocessing
        switch preprocessingMethod
            case 2 % Detrend
                sumSignal1 = detrend(sumSignal1);
                sumSignal2 = detrend(sumSignal2);
            case 3 % Demean
                sumSignal1 = sumSignal1 - nanmean(sumSignal1);
                sumSignal2 = sumSignal2 - nanmean(sumSignal2);
            case 4 % Baseline correction
                sumSignal1 = sumSignal1 - nanmedian(sumSignal1);
                sumSignal2 = sumSignal2 - nanmedian(sumSignal2);
        end

        % Apply events windows if enabled
        if useEvents
            if isempty(events) || ~exist('events', 'var')
                fprintf('Events are not loaded. Please load events first.\n');
                return;
            end
            
            eventWindow = str2double(get(eventWindowEdit, 'String'));
            numEvents = length(events);
            
            eventSegments1 = [];
            eventSegments2 = [];
            
            for i = 1:numEvents
                eventTime = events(i);
                eventIdx = round(eventTime * Fs);
                windowStart = max(eventIdx - round(eventWindow * Fs / 2), 1);
                windowEnd = min(windowStart + round(eventWindow * Fs) - 1, size(lfp, 1));
                
                if windowEnd <= size(lfp, 1) && windowStart < windowEnd
                    eventSegments1 = [eventSegments1; sumSignal1(windowStart:windowEnd)];
                    eventSegments2 = [eventSegments2; sumSignal2(windowStart:windowEnd)];
                end
            end
            
            if isempty(eventSegments1)
                fprintf('No valid event windows found.\n');
                return;
            end
            
            sumSignal1 = eventSegments1;
            sumSignal2 = eventSegments2;
            timeFiltered = (0:length(sumSignal1)-1) / Fs;
        elseif useTimeRange
            startTime = str2double(get(startTimeEdit, 'String'));
            endTime = str2double(get(endTimeEdit, 'String'));
            
            timeIndices = time >= startTime & time <= endTime;
            sumSignal1 = sumSignal1(timeIndices);
            sumSignal2 = sumSignal2(timeIndices);
            timeFiltered = time(timeIndices);
        else
            timeFiltered = time;
        end

        % Compute cross-correlation
        sampleRate = 1 / (timeFiltered(2) - timeFiltered(1));
        
        % Normalize if required
        if normalize
            [crossCorr, lags] = xcorr(sumSignal1, sumSignal2, 'normalized');
        else
            [crossCorr, lags] = xcorr(sumSignal1, sumSignal2);
        end
        
        % Convert lags to time in seconds
        lagTimes = lags / sampleRate;

        % Convert lag times to desired unit
        switch xAxisUnit
            case 1 % Seconds
                xAxisLabel = 'Time (s)';
            case 2 % Minutes
                lagTimes = lagTimes / 60;
                xAxisLabel = 'Time (min)';
                windowSize = windowSize/60;
            case 3 % Milliseconds
                lagTimes = lagTimes * 1000;
                xAxisLabel = 'Time (ms)';
                windowSize = windowSize * 1000;
        end

        % Trim the cross-correlation result to the specified window size
        validIndices = abs(lagTimes) <= windowSize/2;
        lagTimes = lagTimes(validIndices);
        crossCorr = crossCorr(validIndices);

        % Apply result processing
        peakLag = [];
        peakValue = [];
        switch resultProcessing
            case 2 % Smoothing
                windowSize_samples = round(length(crossCorr) * 0.05); % 5% of data points
                windowSize_samples = max(3, windowSize_samples); % Minimum 3 points
                crossCorr = smooth(crossCorr, windowSize_samples);
            case 3 % Peak detection
                [peakValue, peakIdx] = max(crossCorr);
                peakLag = lagTimes(peakIdx);
        end

        % Plot the result
        figure('Name', 'Cross-Correlation Result', 'NumberTitle', 'off');
        plot(lagTimes, crossCorr);
        xline(0, 'r:')
        xlabel(xAxisLabel);
        ylabel('Cross-Correlation');
        
        titleStr = 'Cross-Correlation Between Selected Channels';
        if useEvents && exist('numEvents', 'var')
            titleStr = sprintf('%s (using %d events)', titleStr, numEvents);
        end
        if resultProcessing == 3 && ~isempty(peakLag)
            % Extract unit from xAxisLabel (e.g., "Time (s)" -> "s")
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
