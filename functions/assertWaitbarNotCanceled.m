function assertWaitbarNotCanceled(hWaitBar)
    if isempty(hWaitBar)
        return;
    end
    drawnow;
    if isWaitbarCanceled(hWaitBar)
        error('EasyViewer:UserCancel', 'Conversion stopped by user');
    end
end
