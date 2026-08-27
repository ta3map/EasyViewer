function deleteGraphicsWithListeners(handles)
%DELETEGRAPHICSWITHLISTENERS Delete graphics and drawLabelWithBg listeners.

handles = handles(isgraphics(handles));
for i = 1:numel(handles)
    h = handles(i);
    if isappdata(h, 'drawLabelWithBgListeners')
        listeners = getappdata(h, 'drawLabelWithBgListeners');
        listeners = listeners(isvalid(listeners));
        delete(listeners);
        rmappdata(h, 'drawLabelWithBgListeners');
    end
end
delete(handles(isgraphics(handles)));
end
