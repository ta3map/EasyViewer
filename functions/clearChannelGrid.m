function clearChannelGrid()
%CLEARCHANNELGRID Delete only the grid host panel; keep multiax.

    global channelGridGfx

    if isempty(channelGridGfx) || ~isstruct(channelGridGfx)
        channelGridGfx = emptyChannelGridGfx();
        return;
    end

    if isfield(channelGridGfx, 'host') && ~isempty(channelGridGfx.host) && isgraphics(channelGridGfx.host)
        delete(channelGridGfx.host);
    end
    channelGridGfx = emptyChannelGridGfx();
end

function gfx = emptyChannelGridGfx()
    gfx = struct( ...
        'host', gobjects(0), ...
        'layout', [], ...
        'axes', gobjects(0), ...
        'size', [0 0], ...
        'spacing', '', ...
        'indexGrid', []);
end
