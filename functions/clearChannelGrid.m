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
