function clearIosPlayerChart(fig)
    state = fig.UserData;
    chartAx = state.chartAx;
    if ~isempty(chartAx) && ishghandle(chartAx)
        cla(chartAx);
    end
    if ~isempty(state.chartLines)
        for i = 1:length(state.chartLines)
            if ~isempty(state.chartLines(i)) && ishghandle(state.chartLines(i))
                delete(state.chartLines(i));
            end
        end
    end
    state.chartLines = [];
    state.chartData = [];
    fig.UserData = state;
end
