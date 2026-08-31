function [row, col, frameSize] = iosPlayerClickToOriginal(fig, ax)
    state = fig.UserData;
    frameSize = size(state.him.CData);
    cp = get(ax, 'CurrentPoint');
    [row, col] = iosPlayerDisplayToOriginal(cp(1, 1), cp(1, 2), state.rotationAngle, state.offsetX, state.offsetY, state.zoomFactor, frameSize);
    row = round(row);
    col = round(col);
    row = max(1, min(frameSize(1), row));
    col = max(1, min(frameSize(2), col));
end
