function syncIosPlayerModeUi(fig)
    state = fig.UserData;
    vis = 'off';
    if state.iosMode
        vis = 'on';
    end
    state.h.iosCheck.Value = double(state.iosMode);
    if state.floatingBaseMode && state.iosMode
        visBase = 'off';
        visDelay = 'on';
    else
        visBase = vis;
        visDelay = 'off';
    end
    setControlVisible(state.h, {'floatingBaseCheck'}, vis);
    setControlVisible(state.h, {'baseDelayEdit', 'baseDelayText'}, visDelay);
    setControlVisible(state.h, {'baseStartText', 'baseStartEdit', 'baseEndText', 'baseEndEdit', 'setBaseBtn'}, visBase);
    setControlVisible(state.h, {'referenceSizeText', 'referenceSizeEdit', 'referenceFullSizeCheck'}, vis);
    setControlVisible(state.h, {'iosMinText', 'iosMinEdit', 'iosMaxText', 'iosMaxEdit'}, vis);
    fig.UserData = state;
    syncIosPlayerReferenceButtons(fig);
    showHideIosPlayerChart(fig);
end

function setControlVisible(h, keys, vis)
    for i = 1:numel(keys)
        h.(keys{i}).Visible = vis;
    end
end
