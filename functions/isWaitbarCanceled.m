function tf = isWaitbarCanceled(wb)
    tf = isempty(wb) || ~isvalid(wb);
    if tf
        return;
    end
    tf = isequal(getappdata(wb, 'canceling'), 1);
end
