function showHideIosPlayerChart(fig)
    state = fig.UserData;
    chartAx = state.chartAx;
    shouldShow = state.iosMode && ~isempty(state.cursors);
    if shouldShow
        state.h.clearIosPlayerChartBtn.Visible = 'on';
        state.h.showChartCheck.Visible = 'on';
        state.h.chartSmoothText.Visible = 'on';
        state.h.chartSmoothEdit.Visible = 'on';
        chartAx.Visible = 'off';
        if state.h.showChartCheck.Value
            chartAx.Visible = 'on';
        end
    else
        chartAx.Visible = 'off';
        state.h.clearIosPlayerChartBtn.Visible = 'off';
        state.h.showChartCheck.Visible = 'off';
        state.h.chartSmoothText.Visible = 'off';
        state.h.chartSmoothEdit.Visible = 'off';
        clearIosPlayerChart(fig);
    end
    fig.UserData = state;
end
