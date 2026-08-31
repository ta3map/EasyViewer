function refreshIosPlayerChart(fig)
    state = fig.UserData;
    if ~(state.iosMode && ~isempty(state.cursors))
        return
    end
    if isempty(state.him) || ~isvalid(state.him)
        return
    end
    if ~isfield(state, 'lastDisplayedTime') || isempty(state.lastDisplayedTime)
        return
    end
    t = state.lastDisplayedTime;
    numCursors = length(state.cursors);
    if numCursors == 0 || isempty(state.chartData)
        return
    end
    if isempty(state.chartLines) || ~isvalid(state.chartLines(1))
        initIosPlayerChart(fig);
        state = fig.UserData;
    end
    w = max(1, round(state.chartSmoothWindow));
    frameForIos = state.him.CData;
    chartData = state.chartData;
    for i = 1:numCursors
        chartData(i).x = [chartData(i).x; t];
        iosVal = computeIosPlayerCursorValue(state, state.cursors(i), frameForIos, state.iosMode, state.baseframeData, []);
        chartData(i).y = [chartData(i).y, iosVal];
        yPlot = chartData(i).y;
        if w > 1 && numel(yPlot) >= w
            yPlot = smooth1(yPlot(:), w, 'moving');
            yPlot = yPlot(:)';
        end
        set(state.chartLines(i), 'Color', hex2rgb(state.cursors(i).color), 'XData', chartData(i).x, 'YData', yPlot);
    end
    state.chartData = chartData;
    fig.UserData = state;
end
