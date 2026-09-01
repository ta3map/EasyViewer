function handles = updatePlotScaleBars(ax, handles, ampValue, timeSpan, selectedUnit, xlimsOverride, ylimsOverride)
%UPDATEPLOTSCALEBARS Update or create four scale-bar graphics handles.

g = plotScaleBarGeometry(ax, ampValue, timeSpan, selectedUnit, xlimsOverride, ylimsOverride);
live = numel(handles) >= 4 && all(isgraphics(handles(1:4)));

if ~live
    delete(handles(isgraphics(handles)));
    hold(ax, 'on');
    hAmpLine = plot(ax, g.ampLineX, g.ampLineY, 'k-', 'LineWidth', 3, ...
        'Tag', 'plotScaleBar', 'HitTest', 'off', 'Clipping', 'on');
    hAmpText = text(ax, g.ampLabelPos(1), g.ampLabelPos(2), g.ampLabelStr, ...
        'FontSize', 10, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
        'Tag', 'plotScaleBar', 'HitTest', 'off', 'Clipping', 'on');
    hTimeLine = plot(ax, g.timeLineX, g.timeLineY, 'k-', 'LineWidth', 3, ...
        'Tag', 'plotScaleBar', 'HitTest', 'off', 'Clipping', 'on');
    hTimeText = text(ax, g.timeLabelPos(1), g.timeLabelPos(2), g.timeLabelStr, ...
        'FontSize', 10, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
        'Tag', 'plotScaleBar', 'HitTest', 'off', 'Clipping', 'on');
    handles = [hAmpLine; hAmpText; hTimeLine; hTimeText];
    return;
end

set(handles(1), 'XData', g.ampLineX, 'YData', g.ampLineY, 'Visible', 'on');
set(handles(2), 'Position', g.ampLabelPos, 'String', g.ampLabelStr, 'Visible', 'on');
set(handles(3), 'XData', g.timeLineX, 'YData', g.timeLineY, 'Visible', 'on');
set(handles(4), 'Position', g.timeLabelPos, 'String', g.timeLabelStr, 'Visible', 'on');

end
