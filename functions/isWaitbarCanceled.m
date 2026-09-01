function tf = isWaitbarCanceled(wb)
    if isempty(wb)
        tf = false;
        return;
    end
    if ~isvalid(wb)
        tf = true;
        return;
    end
    tf = isequal(getappdata(wb, 'canceling'), 1);
end
