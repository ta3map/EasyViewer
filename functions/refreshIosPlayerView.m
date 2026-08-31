function refreshIosPlayerView(fig, ax)
    if ~iosPlayerHasValidMeta(fig)
        return
    end
    state = fig.UserData;
    showIosPlayerFrame(fig, ax, getIosPlayerCurrentFrame(state));
end
