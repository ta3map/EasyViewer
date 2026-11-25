function reorderChannelsGUI()
    global channelNames matFilePath matFileName
    global lfp_file spks lfpVar hd
    global channelEnabled scalingCoefficients colorsIn lineCoefficients
    global mean_group_ch csd_avaliable filter_avaliable baseline_subtract_available filterSettings
    global event_channels stims zavp numChannels

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
        'Position', [20, 20, 120, 36], 'Enable', 'off', 'Callback', @saveOver);
    saveAsBtn = uicontrol('Parent', fig, 'Style', 'pushbutton', 'String', 'Save as', ...
        'Position', [150, 20, 120, 36], 'Enable', 'off', 'Callback', @saveAs);

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
        changed = ~isequal(order, 1:n);
        state = 'off';
        if changed
            state = 'on';
        end
        set(saveBtn, 'Enable', state);
        set(saveAsBtn, 'Enable', state);
    end

    function saveOver(~, ~)
        set(fig, 'WindowStyle', 'normal');
        choice = questdlg(['Overwrite ', matFilePath, '?'], ...
            'Reorder channels', 'Save', 'Cancel', 'Cancel');
        set(fig, 'WindowStyle', 'modal');
        if ~strcmp(choice, 'Save')
            return
        end
        commit(matFilePath);
    end

    function saveAs(~, ~)
        set(fig, 'WindowStyle', 'normal');
        [file, path] = uiputfile('*.mat', 'Save ZAV (.mat) File', matFilePath);
        set(fig, 'WindowStyle', 'modal');
        if isequal(file, 0) || isequal(path, 0)
            return
        end
        commit(fullfile(path, file));
    end

    function commit(filepath)
        applyChannelOrder(order);
        zavp.realStim = struct('r', stims' / zavp.siS);
        matFilePath = filepath;
        [~, matFileName, ~] = fileparts(filepath);
        saveZavFile(filepath);
        saveChannelSettings();
        refreshViewer();
        order = 1:n;
        showOrder(get(channelList, 'Value'));
    end

    function applyChannelOrder(perm)
        lfp_file.lfp = lfp_file.lfp(:, perm, :);
        spks = spks(perm);
        lfpVar = takeChannels(lfpVar, perm, n);
        hd = takeHeaderChannels(hd, perm, n);
        channelNames = takeChannels(channelNames, perm, n);
        channelEnabled = takeChannels(channelEnabled, perm, n);
        scalingCoefficients = takeChannels(scalingCoefficients, perm, n);
        colorsIn = takeChannels(colorsIn, perm, n);
        lineCoefficients = takeChannels(lineCoefficients, perm, n);
        mean_group_ch = takeChannels(mean_group_ch, perm, n);
        csd_avaliable = takeChannels(csd_avaliable, perm, n);
        filter_avaliable = takeChannels(filter_avaliable, perm, n);
        baseline_subtract_available = takeChannels(baseline_subtract_available, perm, n);
        filterSettings.channelsToFilter = takeChannels(filterSettings.channelsToFilter, perm, n);
        event_channels = remapEventChannels(event_channels, perm, n);
        numChannels = n;
    end
end

function values = takeChannels(values, perm, n)
    dim = find(size(values) == n, 1);
    idx = repmat({':'}, 1, max(ndims(values), dim));
    idx{dim} = perm;
    values = values(idx{:});
end

function hd = takeHeaderChannels(hd, perm, n)
    names = {'recChNames', 'recChUnits', 'ch_si'};
    for i = 1:numel(names)
        name = names{i};
        if isfield(hd, name) && numel(hd.(name)) == n
            hd.(name) = takeChannels(hd.(name), perm, n);
        end
    end
end

function channels = remapEventChannels(channels, perm, n)
    rank = zeros(1, n);
    rank(perm) = 1:n;
    mask = channels >= 1 & channels <= n;
    channels(mask) = rank(channels(mask));
end

function refreshViewer()
    viewer = findobj('Type', 'figure', 'Tag', 'SignalViewerGUI');
    ud = get(viewer, 'UserData');
    ud.updateTable();
    ud.updateLocalCoefs();
    ud.updatePlot('visual');
end
