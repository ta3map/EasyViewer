function ax = openResultPreview(reportPath, parentPanel)
    % openResultPreview - Открывает результат анализа и отображает его в панели
    % 
    % Входные параметры:
    %   reportPath - путь к файлу результата
    %   parentPanel - uipanel для отображения превью
    % 
    % Выходные параметры:
    %   ax - axes с построенным результатом или [] при ошибке
    
    ax = [];
    
    if isempty(reportPath) || isempty(parentPanel)
        return
    end
    
    reportPath = normalizePath(reportPath);
    if isempty(reportPath) || ~exist(reportPath, 'file')
        return
    end
    
    [~, ~, ext] = fileparts(reportPath);
    ext = lower(ext);
    
    try
        if strcmp(ext, '.fig')
            tempFig = openfig(reportPath, 'invisible');
            axesList = findobj(tempFig, 'Type', 'axes');
            if ~isempty(axesList)
                ax = copyobj(axesList(1), parentPanel);
                ax.Position = [0.1, 0.1, 0.8, 0.8];
            end
            close(tempFig);
        elseif any(strcmp(ext, {'.png', '.jpg', '.jpeg', '.bmp', '.tif', '.tiff'}))
            ax = axes('Parent', parentPanel, 'Position', [0, 0, 1, 1]);
            img = imread(reportPath);
            imshow(img, 'Parent', ax);
            axis(ax, 'off');
        end
    catch ME
        warning('openResultPreview: Failed to open result: %s', ME.message);
        ax = [];
    end
end
