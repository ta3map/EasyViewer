function plotYValuesOnAxes(ax, xPositions, yPositions, yValues, xOffset, yOffset, formatStr, useAbsoluteOffset)
    % plotYValuesOnAxes - Отображение Y значений рядом с точками на графике
    % Входные параметры:
    %   ax - handle оси
    %   xPositions - массив X координат точек
    %   yPositions - массив Y координат точек
    %   yValues - массив Y значений для отображения (может быть равен yPositions)
    %   xOffset - смещение по X (относительно диапазона или абсолютное)
    %   yOffset - смещение по Y (относительно диапазона или абсолютное)
    %   formatStr - формат строки (например, '%.3f' или '(%.3f,%.3f)')
    %   useAbsoluteOffset - если true, смещения абсолютные; если false или не указано - относительные
    
    if nargin < 8
        useAbsoluteOffset = false;
    end
    
    if isempty(yValues) || length(yValues) ~= length(xPositions)
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
        if contains(formatStr, ',')
            % Формат для пар значений (x, y)
            textStr = sprintf(formatStr, xPositions(i), yPositions(i));
        else
            % Формат для одного значения
            textStr = sprintf(formatStr, yValues(i));
        end
        text(ax, xPositions(i) + xOffsetFinal, yPositions(i) + yOffsetFinal, textStr, ...
            'HorizontalAlignment', 'left', ...
            'VerticalAlignment', 'bottom', ...
            'FontSize', 7, ...
            'Color', [0 0 0], ...
            'BackgroundColor', [1 1 1], ...
            'Interpreter', 'none');
    end
end
