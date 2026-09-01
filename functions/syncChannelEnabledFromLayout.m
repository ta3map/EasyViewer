function syncChannelEnabledFromLayout()
%SYNCCHANNELENABLEDFROMLAYOUT Enable channels in layout grid, disable others.

    global channelLayoutNameGrid channelNames channelEnabled

    if isempty(channelLayoutNameGrid)
        return
    end

    nCh = numel(channelNames);
    indexGrid = matchChannelLayout(channelLayoutNameGrid, channelNames, true(nCh, 1));
    matched = indexGrid(indexGrid > 0);
    channelEnabled = false(nCh, 1);
    channelEnabled(matched) = true;
end
