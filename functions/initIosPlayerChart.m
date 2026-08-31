function initIosPlayerChart(fig)
    state = fig.UserData;
    chartAx = state.chartAx;
    numCursors = length(state.cursors);
    cla(chartAx);
    hold(chartAx, 'on');
    chartLines = gobjects(numCursors, 1);
    chartData = repmat(struct('x', [], 'y', []), numCursors, 1);
    for i = 1:numCursors
        lineColor = hex2rgb(state.cursors(i).color);
        chartLines(i) = plot(chartAx, NaN, NaN, 'Color', lineColor, 'LineWidth', 1.5);
    end
    state.chartLines = chartLines;
    state.chartData = chartData;
    xlabel(chartAx, 'Time (s)');
    ylabel(chartAx, 'IOS');
    grid(chartAx, 'on');
    fig.UserData = state;
end
