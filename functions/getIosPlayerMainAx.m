function ax = getIosPlayerMainAx(fig)
    state = fig.UserData;
    if ~isempty(state.him) && isvalid(state.him)
        ax = state.him.Parent;
        return
    end
    allAxes = findobj(fig, 'Type', 'axes');
    chartAx = state.chartAx;
    for i = 1:length(allAxes)
        if allAxes(i) ~= chartAx
            ax = allAxes(i);
            return
        end
    end
    error('getIosPlayerMainAx: main axes not found');
end
