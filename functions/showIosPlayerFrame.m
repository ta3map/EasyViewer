function showIosPlayerFrame(fig, ax, k)
    if ~iosPlayerHasValidMeta(fig)
        return
    end
    state = fig.UserData;
    [displayFrame, baseRange, state, t] = processIosPlayerFrame(state, k);
    fig.UserData = state;
    if isempty(displayFrame)
        debugState('showIosPlayerFrame', 'Empty frame %d', k);
        state.h.timeEdit.String = iosPlayerSec2timeStr(t(1));
        state.h.slider.Value = k;
        fig.UserData = state;
        return
    end
    presentIosPlayerFrame(fig, ax, displayFrame, baseRange);
    state = fig.UserData;
    state.h.timeEdit.String = iosPlayerSec2timeStr(t(1));
    state.h.slider.Value = k;
    state.lastDisplayedTime = t(1);
    fig.UserData = state;
    syncIosPlayerReferenceButtons(fig);
    refreshIosPlayerChart(fig);
end

function presentIosPlayerFrame(fig, ax, displayFrame, baseRange)
    state = fig.UserData;
    if isempty(state.him) || ~isvalid(state.him)
        cla(ax);
        state.him = imagesc(ax, displayFrame);
        axis(ax, 'image');
        axis(ax, 'off');
        state.him.ButtonDownFcn = state.imageClickCallback;
    else
        state.him.CData = displayFrame;
    end
    ax.YDir = 'normal';
    fig.UserData = state;
    drawIosPlayerCursors(fig, ax);
    c = double(state.h.contrastSlider.Value);
    applyIosPlayerContrast(ax, baseRange, c);
end
