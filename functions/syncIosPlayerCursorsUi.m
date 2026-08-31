function syncIosPlayerCursorsUi(fig, ax, refreshFrame)
    updateIosPlayerCursorsTable(fig);
    drawIosPlayerCursors(fig, ax);
    showHideIosPlayerChart(fig);
    if ~refreshFrame
        return
    end
    state = fig.UserData;
    if state.iosMode && iosPlayerHasValidMeta(fig)
        refreshIosPlayerView(fig, ax);
    end
end
