function levels = boxplotAssignBracketLevelsForParams(pairs, paramPositions)
    % boxplotAssignBracketLevelsForParams - Определение уровней для скобок между параметрами
    % Распределяет скобки по уровням, чтобы они не пересекались
    % 
    % Входные параметры:
    %   pairs - массив структур с полями: param1, param2, pvalue
    %   paramPositions - containers.Map с позициями параметров на оси X
    %
    % Выходные параметры:
    %   levels - массив уровней для каждой пары
    
    levels = zeros(length(pairs), 1);
    
    for i = 1:length(pairs)
        pair = pairs(i);
        param1 = pair.param1;
        param2 = pair.param2;
        
        if ~isKey(paramPositions, param1) || ~isKey(paramPositions, param2)
            levels(i) = 0;
            continue
        end
        
        pos1 = paramPositions(param1);
        pos2 = paramPositions(param2);
        
        level = 0;
        for j = 1:i-1
            otherPair = pairs(j);
            if ~isKey(paramPositions, otherPair.param1) || ~isKey(paramPositions, otherPair.param2)
                continue
            end
            
            otherPos1 = paramPositions(otherPair.param1);
            otherPos2 = paramPositions(otherPair.param2);
            
            if ~(pos2 < otherPos1 || pos1 > otherPos2)
                level = max(level, levels(j) + 1);
            end
        end
        
        levels(i) = level;
    end
end

