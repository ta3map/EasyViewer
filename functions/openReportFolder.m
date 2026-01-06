function openReportFolder(reportPath)
    if isempty(reportPath)
        return
    end
    reportPath = normalizePath(reportPath);
    if isempty(reportPath)
        return
    end
    if exist(reportPath, 'file')
        folder = fileparts(reportPath);
        if exist(folder, 'dir')
            winopen(folder);
        else
            msgbox(sprintf('Folder not found: %s', folder), 'Error', 'error');
        end
    else
        msgbox(sprintf('File not found: %s', reportPath), 'Error', 'error');
    end
end

