function deleteCancelableWaitbar(hWaitBar)
    if ~isempty(hWaitBar) && isvalid(hWaitBar)
        delete(hWaitBar);
    end
end
