function applied = ensureChannelSettingsForSession()
%ENSURECHANNELSETTINGSFORSESSION Repair channel globals to match session channel count.

    global hd numChannels matFilePath channelNames channelEnabled
    global scalingCoefficients colorsIn lineCoefficients mean_group_ch
    global csd_avaliable filter_avaliable baseline_subtract_available filterSettings
    global zavSessionSettingsPath channelLayoutFilePath channelLayoutNameGrid visualSettings

    expectedN = sessionChannelCount(hd, numChannels);
    if expectedN < 1
        applied = false;
        return;
    end
    numChannels = expectedN;

    settingsPath = channelSettingsPathForMat(matFilePath);
    if isChannelSettingsApplied(settingsPath)
        applied = true;
        return;
    end

    if ~channelArraysMatch(expectedN)
        layoutPath = channelLayoutFilePath;
        layoutGrid = channelLayoutNameGrid;
        displayMode = '';
        if isstruct(visualSettings) && isfield(visualSettings, 'viewer_display_mode')
            displayMode = visualSettings.viewer_display_mode;
        end

        zavSessionSettingsPath = '';
        channelNames = channelNamesFromHd(hd, expectedN);
        applyStandardChannelArrays(expectedN);

        channelLayoutFilePath = layoutPath;
        channelLayoutNameGrid = layoutGrid;
        if ~isempty(displayMode)
            visualSettings.viewer_display_mode = displayMode;
        end
    end

    if exist(settingsPath, 'file') == 2
        applied = applyChannelSettingsFromFile(settingsPath, expectedN);
        return;
    end

    applied = channelArraysMatch(expectedN);
end

function expectedN = sessionChannelCount(hd, numChannels)
    if isstruct(hd) && isfield(hd, 'recChNames') && ~isempty(hd.recChNames)
        expectedN = numel(np_flatten(hd.recChNames));
        return;
    end
    if ~isempty(numChannels) && numChannels >= 1
        expectedN = numChannels;
        return;
    end
    expectedN = 0;
end

function ok = channelArraysMatch(n)
    global channelNames channelEnabled scalingCoefficients colorsIn lineCoefficients
    ok = length(channelNames) == n ...
        && length(channelEnabled) == n ...
        && length(scalingCoefficients) == n ...
        && length(colorsIn) == n ...
        && length(lineCoefficients) == n;
end

function names = channelNamesFromHd(hd, numChannels)
    if isstruct(hd) && isfield(hd, 'recChNames') && ~isempty(hd.recChNames)
        names = np_flatten(hd.recChNames);
        names = names(1:min(numChannels, numel(names)));
    else
        names = {};
    end
    while numel(names) < numChannels
        names{end + 1} = sprintf('Ch%d', numel(names) + 1);
    end
end

function applyStandardChannelArrays(numChannels)
    global channelNames channelEnabled scalingCoefficients colorsIn lineCoefficients
    global mean_group_ch csd_avaliable filter_avaliable baseline_subtract_available filterSettings

    channelEnabled = true(1, numChannels);
    scalingCoefficients = ones(1, numChannels);
    colorsIn = np_flatten(getColors(numChannels));
    lineCoefficients = ones(1, numChannels) * 0.5;
    mean_group_ch = false(1, numChannels);
    csd_avaliable = true(1, numChannels);
    filter_avaliable = false(1, numChannels);
    baseline_subtract_available = true(1, numChannels);
    filterSettings = struct( ...
        'filterType', 'highpass', ...
        'freqLow', 10, ...
        'freqHigh', 50, ...
        'order', 4, ...
        'channelsToFilter', false(numChannels, 1), ...
        'smoothSpan', 0, ...
        'smoothMethod', 'moving');
end
