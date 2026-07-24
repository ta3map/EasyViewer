function clearMainAxesPlotContent(ax, keepHandles)
% Delete axes children except keepHandles; drop drawLabelWithBg listeners first.

if nargin < 2 || isempty(keepHandles)
    keepHandles = gobjects(0);
end
keepHandles = keepHandles(isgraphics(keepHandles));

children = get(ax, 'Children');
toDelete = setdiff(children, keepHandles, 'stable');

for i = 1:numel(toDelete)
    h = toDelete(i);
    if ~isgraphics(h)
        continue;
    end
    if isappdata(h, 'drawLabelWithBgListeners')
        listeners = getappdata(h, 'drawLabelWithBgListeners');
        listeners = listeners(isvalid(listeners));
        delete(listeners);
        rmappdata(h, 'drawLabelWithBgListeners');
    end
end

toDelete = toDelete(isgraphics(toDelete));
delete(toDelete);

end
