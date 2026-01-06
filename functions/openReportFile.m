function openReportFile(reportPath)
    if isempty(reportPath)
        return
    end
    reportPath = normalizePath(reportPath);
    if isempty(reportPath)
        return
    end
    if exist(reportPath, 'file')
        winopen(reportPath);
    else
        msgbox(sprintf('File not found: %s', reportPath), 'Error', 'error');
    end
end

