function plotFileIdsOnAxes(ax, xPositions, yPositions, fileIds, xOffset, yOffset, useAbsoluteOffset)
    % plotFileIdsOnAxes - Отображение File IDs рядом с точками на графике
    % Входные параметры:
    %   ax - handle оси
    %   xPositions - массив X координат точек
    %   yPositions - массив Y координат точек
    %   fileIds - массив File IDs (может быть пустым)
    %   xOffset - смещение по X (относительно диапазона или абсолютное)
    %   yOffset - смещение по Y (относительно диапазона или абсолютное)
    %   useAbsoluteOffset - если true, смещения абсолютные; если false или не указано - относительные
    
    if nargin < 7
        useAbsoluteOffset = false;
    end
    
    if isempty(fileIds) || length(fileIds) ~= length(xPositions)
        return
    end
    
    if useAbsoluteOffset
        xOffsetFinal = xOffset;
        yOffsetFinal = yOffset;
    else
        xRange = max(xPositions) - min(xPositions);
        yRange = max(yPositions) - min(yPositions);
        
        if xRange == 0
            if length(xPositions) == 1
                xRange = abs(xPositions(1)) * 0.01;
            else
                xRange = 1;
            end
            if xRange == 0
                xRange = 1;
            end
        end
        
        if yRange == 0
            yRange = abs(max(yPositions)) * 0.01;
            if yRange == 0
                yRange = 1;
            end
        end
        
        xOffsetFinal = xOffset * xRange;
        yOffsetFinal = yOffset * yRange;
    end
    
    for i = 1:length(xPositions)
        if ~isnan(fileIds(i))
            text(ax, xPositions(i) + xOffsetFinal, yPositions(i) + yOffsetFinal, num2str(fileIds(i)), ...
                'HorizontalAlignment', 'right', ...
                'VerticalAlignment', 'bottom', ...
                'FontSize', 7, ...
                'Color', [1 1 1], ...
                'BackgroundColor', [0 0 0], ...
                'Interpreter', 'none');
        end
    end
end
