function reorderChannelsGUI()
    global channelNames channelFileOrder
    global channelEnabled scalingCoefficients colorsIn lineCoefficients
    global mean_group_ch csd_avaliable filter_avaliable baseline_subtract_available filterSettings
    global spks lfpVar

    figTag = 'reorderChannelsGUI';
    guiFig = findobj('Type', 'figure', 'Tag', figTag);
    if ~isempty(guiFig)
        figure(guiFig);
        return
    end

    n = numel(channelNames);
    order = 1:n;

    fig = figure('Name', 'Reorder channels', 'NumberTitle', 'off', ...
        'Position', [120, 120, 420, 460], 'Resize', 'off', ...
        'MenuBar', 'none', 'ToolBar', 'none', ...
        'Tag', figTag, 'WindowStyle', 'modal');

    channelList = uicontrol('Parent', fig, 'Style', 'listbox', ...
        'Position', [20, 70, 250, 370], ...
        'String', channelNames(order), 'Value', 1);

    uicontrol('Parent', fig, 'Style', 'pushbutton', 'String', 'Up', ...
        'Position', [290, 380, 110, 32], 'Callback', @moveUp);
    uicontrol('Parent', fig, 'Style', 'pushbutton', 'String', 'Down', ...
        'Position', [290, 340, 110, 32], 'Callback', @moveDown);
    uicontrol('Parent', fig, 'Style', 'pushbutton', 'String', 'Top', ...
        'Position', [290, 300, 110, 32], 'Callback', @moveTop);
    uicontrol('Parent', fig, 'Style', 'pushbutton', 'String', 'Bottom', ...
        'Position', [290, 260, 110, 32], 'Callback', @moveBottom);

    saveBtn = uicontrol('Parent', fig, 'Style', 'pushbutton', 'String', 'Save', ...
        'Position', [20, 20, 120, 36], 'Enable', 'off', 'Callback', @saveOrder);

    function moveUp(~, ~)
        k = get(channelList, 'Value');
        if k <= 1
            return
        end
        order([k - 1, k]) = order([k, k - 1]);
        showOrder(k - 1);
    end

    function moveDown(~, ~)
        k = get(channelList, 'Value');
        if k >= n
            return
        end
        order([k, k + 1]) = order([k + 1, k]);
        showOrder(k + 1);
    end

    function moveTop(~, ~)
        k = get(channelList, 'Value');
        order = [order(k), order(1:k - 1), order(k + 1:end)];
        showOrder(1);
    end

    function moveBottom(~, ~)
        k = get(channelList, 'Value');
        order = [order(1:k - 1), order(k + 1:end), order(k)];
        showOrder(n);
    end

    function showOrder(selected)
        set(channelList, 'String', channelNames(order), 'Value', selected);
        state = 'off';
        if ~isequal(order, 1:n)
            state = 'on';
        end
        set(saveBtn, 'Enable', state);
    end

    function saveOrder(~, ~)
        applyDisplayOrder(order);
        saveChannelSettings();
        refreshViewer();
        order = 1:n;
        showOrder(get(channelList, 'Value'));
    end

    function applyDisplayOrder(perm)
        if numel(channelFileOrder) ~= n
            channelFileOrder = 1:n;
        end
        channelFileOrder = channelFileOrder(perm);
        channelNames = channelNames(perm);
        channelEnabled = channelEnabled(perm);
        scalingCoefficients = scalingCoefficients(perm);
        colorsIn = colorsIn(perm);
        lineCoefficients = lineCoefficients(perm);
        mean_group_ch = mean_group_ch(perm);
        csd_avaliable = csd_avaliable(perm);
        filter_avaliable = filter_avaliable(perm);
        baseline_subtract_available = baseline_subtract_available(perm);
        filterSettings.channelsToFilter = reorderChannelDim(filterSettings.channelsToFilter, perm);
        spks = reorderChannelVector(spks, perm);
        lfpVar = reorderChannelDim(lfpVar, perm);
    end
end

function refreshViewer()
    viewer = findobj('Type', 'figure', 'Tag', 'SignalViewerGUI');
    ud = get(viewer, 'UserData');
    ud.updateTable();
    ud.updateLocalCoefs();
    ud.updatePlot('visual');
end
