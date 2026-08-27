function viewerModeLabelClick(~, ~)
%VIEWERMODELABELCLICK Cycle selectedCenter via timeCenterPopup.

global timeCenterPopup selectedCenter
if isempty(timeCenterPopup) || ~isgraphics(timeCenterPopup)
    return;
end
popupItems = get(timeCenterPopup, 'String');
if isempty(popupItems)
    return;
end
if ischar(popupItems)
    popupItems = cellstr(popupItems);
end
currentIdx = find(strcmp(popupItems, selectedCenter), 1, 'first');
if isempty(currentIdx)
    currentIdx = 1;
end
nextIdx = mod(currentIdx, numel(popupItems)) + 1;
set(timeCenterPopup, 'Value', nextIdx);
popupCallback = get(timeCenterPopup, 'Callback');
if isa(popupCallback, 'function_handle')
    popupCallback(timeCenterPopup, []);
end
end
