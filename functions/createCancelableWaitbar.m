function wb = createCancelableWaitbar(frac, msg, name)
    % Stop sets cancel flag and deletes the figure.
    % Use delete(h), not close(h): CreateCancelBtn overrides CloseRequestFcn,
    % so close() only re-runs the cancel callback and leaves the window open.
    wb = waitbar(frac, msg, 'Name', name, ...
        'CreateCancelBtn', 'setappdata(gcbf,''canceling'',1); delete(gcbf);');
    setappdata(wb, 'canceling', 0);
    set(findall(wb, 'Style', 'pushbutton'), 'String', 'Stop');
end
