function saveMeanFigureImage(fig, filename)
%SAVEMEANFIGUREIMAGE Save mean figure plot area to image file (png/pdf/eps).
%   Same export path as the Mean figure Save button.

    [~, ~, ext] = fileparts(filename);
    plotContainerHandle = getappdata(fig, 'meanPlotContainer');
    if isempty(plotContainerHandle) || ~isgraphics(plotContainerHandle, 'uipanel')
        saveas(fig, filename);
        return
    end

    tempFig = figure('Visible', 'off', 'Color', [1 1 1], 'MenuBar', 'none', 'ToolBar', 'none');
    cleanupTempFigure = onCleanup(@() deleteIfGraphic(tempFig));
    set(tempFig, 'Units', get(fig, 'Units'), 'Position', get(fig, 'Position'));
    plotContainerCopy = copyobj(plotContainerHandle, tempFig);
    set(plotContainerCopy, 'Units', 'normalized', 'Position', [0 0 1 1], 'BorderType', 'none');

    switch lower(ext)
        case '.pdf'
            print(tempFig, filename, '-dpdf', '-bestfit');
        case '.eps'
            print(tempFig, filename, '-depsc');
        case '.png'
            saveas(tempFig, filename, 'png');
        otherwise
            saveas(tempFig, filename);
    end
end

function deleteIfGraphic(h)
    if ~isempty(h) && isgraphics(h)
        delete(h);
    end
end
