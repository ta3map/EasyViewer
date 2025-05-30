function performChannelOperations()
    % Global variables
    global channelTable ch_labels_l colors_in_l widths_in_l matFileName matFilePath
    global lfp ch_inxs pca_params spks filterSettings
    global csd_avaliable filter_avaliable channelNames mean_group_ch channelSettings m_coef
    global pca_flag hd zav_saving chnlGrp lfpVar numChannels channelEnabled scalingCoefficients colorsIn lineCoefficients

    % Tag for GUI figure
    figTag = 'performChannelOperations';

    % Search for an open figure with the given tag
    guiFig = findobj('Type', 'figure', 'Tag', figTag);

    if ~isempty(guiFig)
        % Make the existing window the current figure
        figure(guiFig);
        return
    end

    % Initialize GUI
    fig = figure('Name', 'Perform Channel Operations', 'NumberTitle', 'off', ...
                  'Position', [100, 100, 600, 500], 'Resize', 'off', ...
                  'MenuBar', 'none', 'ToolBar', 'none', ...
                  'Tag', figTag, 'WindowStyle', 'normal');

    % Channel List A
    uicontrol('Style', 'text', 'Position', [50, 430, 200, 20], 'String', 'Select Channels A:');
    sumChannelsA = uicontrol('Style', 'checkbox', 'Position', [50, 410, 200, 20], ...
                             'String', 'Sum Channels', 'Value', 0);
    channelListA = uicontrol('Style', 'listbox', 'Position', [50, 200, 200, 200], ...
                             'String', channelNames, 'Max', length(channelNames), 'Min', 1);

    % Channel List B
    uicontrol('Style', 'text', 'Position', [350, 430, 200, 20], 'String', 'Select Channels B:');
    sumChannelsB = uicontrol('Style', 'checkbox', 'Position', [350, 410, 200, 20], ...
                             'String', 'Sum Channels', 'Value', 0);
    channelListB = uicontrol('Style', 'listbox', 'Position', [350, 200, 200, 200], ...
                             'String', channelNames, 'Max', length(channelNames), 'Min', 1);

    % Operation Selection
    uicontrol('Style', 'text', 'Position', [250, 150, 100, 20], 'String', 'Select Operation:');
    operationMenu = uicontrol('Style', 'popupmenu', 'Position', [225, 120, 150, 25], ...
                              'String', {'A + B', 'A - B', 'A * B', 'A / B'});

    % Perform Operation Button
    uicontrol('Style', 'pushbutton', 'Position', [250, 50, 100, 40], 'String', 'Perform Operation', ...
              'Callback', @performOperation);

    function performOperation(~, ~)
        % Get selected channels
        selectedChannelsA = get(channelListA, 'Value');
        selectedChannelsB = get(channelListB, 'Value');

        % Get sum channels options
        isSumA = get(sumChannelsA, 'Value');
        isSumB = get(sumChannelsB, 'Value');

        % Get selected operation
        operations = get(operationMenu, 'String');
        selectedOperation = operations{get(operationMenu, 'Value')};

        % Extract data for selected channels
        dataA = lfp(:, selectedChannelsA);
        dataB = lfp(:, selectedChannelsB);

        % Sum channels if selected
        if isSumA
            dataA = sum(dataA, 2);
        end

        if isSumB
            dataB = sum(dataB, 2);
        end

        % Ensure dataA and dataB are cell arrays if not summed
        if ~isSumA && numel(selectedChannelsA) > 1
            dataA = mat2cell(dataA, size(dataA,1), ones(1, size(dataA,2)));
        else
            dataA = {dataA};
        end

        if ~isSumB && numel(selectedChannelsB) > 1
            dataB = mat2cell(dataB, size(dataB,1), ones(1, size(dataB,2)));
        else
            dataB = {dataB};
        end

        % Handle different number of channels
        numChannelsA = numel(dataA);
        numChannelsB = numel(dataB);
        maxChannels = max(numChannelsA, numChannelsB);

        % Extend dataA or dataB if necessary
        if numChannelsA < maxChannels
            dataA(end+1:maxChannels) = dataA(end);
        end
        if numChannelsB < maxChannels
            dataB(end+1:maxChannels) = dataB(end);
        end

        % Perform operation
        resultData = cell(1, maxChannels);
        for i = 1:maxChannels
            switch selectedOperation
                case 'A + B'
                    resultData{i} = dataA{i} + dataB{i};
                case 'A - B'
                    resultData{i} = dataA{i} - dataB{i};
                case 'A * B'
                    resultData{i} = dataA{i} .* dataB{i};
                case 'A / B'
                    resultData{i} = dataA{i} ./ dataB{i};
                otherwise
                    errordlg('Invalid operation selected.');
                    return;
            end
        end

        % Convert resultData back to matrix
        resultDataMat = cell2mat(resultData);

        resultChannelNames = arrayfun(@(x) sprintf('Result_%d', x), 1:maxChannels, 'UniformOutput', false);

        if isempty(resultChannelNames)
            disp('Operation canceled by user.');
            return;
        end

        % Update results
        lfp = resultDataMat;
        channelNames = resultChannelNames;
        numChannels = size(lfp, 2); % Number of channels equals number of sources
        ch_inxs = 1:numChannels;
                
        % Clear MUA data
        spks = [];

        % Form new header
        hd.recChNames = channelNames;            

        chnlGrp = {};
        % Расчет вариации LFP по каналам.
        [m, n, p] = size(lfp);  % получение размеров исходной матрицы        
        if p > 1 % случай со свипами
            lfpVar = squeeze(var(lfp));        
        else
            lfpVar = var(reshape(lfp, [], numChannels));
        end
                   
        % Form properties table   
        channelEnabled = true(1, numChannels); % All channels enabled by default
        scalingCoefficients = ones(1, numChannels); % Default scaling coefficients
        colorsIn = repmat({'black'}, numChannels, 1); % Initialize colors
        lineCoefficients = ones(1, numChannels) * 0.5; % Initialize line widths
        mean_group_ch = false(1, numChannels); % No channel involved in averaging
        csd_avaliable = true(1, numChannels); % All channels involved in CSD
        filter_avaliable = false(1, numChannels); % No channel involved in filtering

        filterSettings.filterType = 'highpass';
        filterSettings.freqLow = 10;
        filterSettings.freqHigh = 50;
        filterSettings.order = 4;
        filterSettings.channelsToFilter = false(numChannels, 1); % No channel involved in filtering

        tableData = [channelNames', num2cell(channelEnabled)', num2cell(scalingCoefficients)', colorsIn, num2cell(lineCoefficients)', num2cell(mean_group_ch)', num2cell(csd_avaliable)', num2cell(filter_avaliable)'];

        set(channelTable, 'Data', tableData, ... % Update table data
                   'ColumnName', {'Channel', 'Enabled', 'Scale', 'Color', 'Line Width', 'Averaging', 'CSD', 'Filter'}, ...
                   'ColumnFormat', {'char', 'logical', 'numeric', 'char', 'numeric', 'logical', 'logical', 'logical'}, ...
                   'ColumnEditable', [false true true true true true true true]);

        ch_inxs = find(channelEnabled); % Indices of enabled channels
        m_coef = scalingCoefficients(ch_inxs); % Updated scaling coefficients
        ch_labels_l = channelNames(ch_inxs);
        colors_in_l = colorsIn(ch_inxs);
        widths_in_l = lineCoefficients(ch_inxs);
            
        % Update plot
        updatePlot()
        % Notify user
        msgbox('Operation completed.', 'Success');
        % Закрываем окно GUI после успешной конвертации
        close(fig);
    end
end
