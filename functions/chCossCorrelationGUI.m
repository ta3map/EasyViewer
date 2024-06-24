function chCossCorrelationGUI()
    % Global variables
    global lfp time channelNames

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
                  'Position', [100, 100, 450, 600], 'Resize', 'off', ...
                  'NumberTitle', 'off', 'MenuBar', 'none', 'ToolBar', 'none', ...
                  'Tag', figTag, 'WindowStyle', 'normal');

    % Create UI elements
    uicontrol('Style', 'text', 'Position', [20, 570, 150, 20], ...
              'String', 'Select Channels from Group 1:');
    channelList1 = uicontrol('Style', 'listbox', 'Position', [20, 320, 150, 250], ...
                             'String', channelNames, 'Max', length(channelNames), 'Min', 1);
    
    uicontrol('Style', 'text', 'Position', [220, 570, 150, 20], ...
              'String', 'Select Channels from Group 2:');
    channelList2 = uicontrol('Style', 'listbox', 'Position', [220, 320, 150, 250], ...
                             'String', channelNames, 'Max', length(channelNames), 'Min', 1);

    normalizeCheckbox = uicontrol('Style', 'checkbox', 'Position', [20, 290, 150, 20], ...
                                  'String', 'Normalize');

    uicontrol('Style', 'text', 'Position', [20, 260, 150, 20], ...
              'String', 'Window Size (s):');
    windowEdit = uicontrol('Style', 'edit', 'Position', [20, 240, 150, 20], ...
                           'String', '10');

    uicontrol('Style', 'text', 'Position', [20, 210, 150, 20], ...
              'String', 'X-Axis Unit:');
    xAxisPopup = uicontrol('Style', 'popupmenu', 'Position', [20, 190, 150, 20], ...
                           'String', {'Seconds', 'Minutes', 'Milliseconds'});

    analyzeButton = uicontrol('Style', 'pushbutton', 'Position', [220, 190, 150, 30], ...
                              'String', 'Analyze', 'Callback', @analyzeData);

    function analyzeData(~, ~)
        selectedChannels1 = channelList1.Value;
        selectedChannels2 = channelList2.Value;
        normalize = get(normalizeCheckbox, 'Value');
        windowSize = str2double(get(windowEdit, 'String')); % seconds
        
        xAxisUnit = get(xAxisPopup, 'Value');
        
        if isempty(selectedChannels1) || isempty(selectedChannels2)
            errordlg('Please select channels from both groups.', 'Selection Error');
            return;
        end

        % Compute the sum of the selected channels
        sumSignal1 = sum(lfp(:, selectedChannels1), 2);
        sumSignal2 = sum(lfp(:, selectedChannels2), 2);

        % Compute cross-correlation
        sampleRate = 1 / (time(2) - time(1));
        
        
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

        % Plot the result
        figure('Name', 'Cross-Correlation Result', 'NumberTitle', 'off');
        plot(lagTimes, crossCorr);
        xline(0, 'r:')
        xlabel(xAxisLabel);
        ylabel('Cross-Correlation');
        title('Cross-Correlation Between Selected Channels');
    end

    uiwait(hFig);
end
