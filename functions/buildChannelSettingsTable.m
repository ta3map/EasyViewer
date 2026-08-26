function tableData = buildChannelSettingsTable()
%BUILDCHANNELSETTINGSTABLE Channel settings cell (9 cols) from session globals.

    global channelNames channelEnabled scalingCoefficients colorsIn lineCoefficients
    global mean_group_ch csd_avaliable filter_avaliable baseline_subtract_available

    numCh = length(channelNames);
    tableData = cell(numCh, 9);
    for i = 1:numCh
        tableData{i, 1} = channelNames{i};
        tableData{i, 2} = channelEnabled(i);
        tableData{i, 3} = scalingCoefficients(i);
        tableData{i, 4} = colorsIn{i};
        tableData{i, 5} = lineCoefficients(i);
        tableData{i, 6} = mean_group_ch(i);
        tableData{i, 7} = csd_avaliable(i);
        tableData{i, 8} = filter_avaliable(i);
        tableData{i, 9} = baseline_subtract_available(i);
    end
end
