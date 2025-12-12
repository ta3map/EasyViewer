function groupFilters = boxplotParseGroupFilters(filtersStr)
    % boxplotParseGroupFilters - Парсинг фильтра для группировки данных
    % Преобразует строку с условием фильтрации в структуру
    % 
    % Входные параметры:
    %   filtersStr - строка с условием фильтрации (MATLAB выражение)
    %
    % Выходные параметры:
    %   groupFilters - cell array структур с полями: condition, groupLabel
    
    if isempty(filtersStr)
        groupFilters = {};
        return
    end
    
    if ~ischar(filtersStr) && ~isstring(filtersStr)
        groupFilters = {};
        return
    end
    
    if isstring(filtersStr)
        filtersStr = char(filtersStr);
    end
    
    filtersStr = strtrim(filtersStr);
    
    if ~isempty(filtersStr)
        groupFilters{1} = struct('condition', filtersStr, 'groupLabel', 'Group1');
    else
        groupFilters = {};
    end
end

