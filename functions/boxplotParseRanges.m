function parsedRanges = boxplotParseRanges(rangesStr)
    % boxplotParseRanges - Парсинг синтаксиса диапазонов и равенств для разбиения данных
    % 
    % Входные параметры:
    %   rangesStr - строка с синтаксисом:
    %     - Диапазоны: "age == [1,10 ; 10, 15]" (запятая между значениями)
    %     - Равенства: "stim == [10; 20]" (без запятой, только точка с запятой)
    %
    % Выходные параметры:
    %   parsedRanges - структура с полями:
    %     columnName - имя колонки для разбиения
    %     ranges - массив структур с полями:
    %       Для диапазонов: min, max, label, isEquality=false, value=[]
    %       Для равенств: value, label, isEquality=true, min=[], max=[]
    %   Если парсинг не удался, возвращает пустую структуру
    
    parsedRanges = struct('columnName', '', 'ranges', []);
    
    if isempty(rangesStr)
        return
    end
    
    if ~ischar(rangesStr) && ~isstring(rangesStr)
        return
    end
    
    if isstring(rangesStr)
        rangesStr = char(rangesStr);
    end
    
    rangesStr = strtrim(rangesStr);
    
    if isempty(rangesStr)
        return
    end
    
    % Парсим синтаксис: "columnName == [min1,max1 ; min2,max2 ; ...]" или "columnName == [val1; val2; ...]"
    % Ищем "=="
    eqPos = strfind(rangesStr, '==');
    if isempty(eqPos)
        return
    end
    
    % Извлекаем имя колонки
    columnName = strtrim(rangesStr(1:eqPos(1)-1));
    if isempty(columnName)
        return
    end
    
    % Извлекаем часть с диапазонами после "=="
    rangesPart = strtrim(rangesStr(eqPos(1)+2:end));
    
    % Проверяем, что начинается с "["
    if ~strncmp(rangesPart, '[', 1)
        return
    end
    
    % Убираем квадратные скобки
    rangesPart = strtrim(rangesPart(2:end));
    if isempty(rangesPart) || rangesPart(end) ~= ']'
        return
    end
    rangesPart = strtrim(rangesPart(1:end-1));
    
    % Разбиваем по ";"
    rangeStrings = strsplit(rangesPart, ';');
    
    ranges = [];
    for i = 1:length(rangeStrings)
        rangeStr = strtrim(rangeStrings{i});
        if isempty(rangeStr)
            continue
        end
        
        % Проверяем, есть ли запятая - если есть, это диапазон, если нет - равенство
        if contains(rangeStr, ',')
            % Диапазон: [min,max]
            parts = strsplit(rangeStr, ',');
            if length(parts) ~= 2
                continue
            end
            
            minStr = strtrim(parts{1});
            maxStr = strtrim(parts{2});
            
            % Парсим числа
            minVal = str2double(minStr);
            maxVal = str2double(maxStr);
            
            if isnan(minVal) || isnan(maxVal)
                continue
            end
            
            % Создаем метку диапазона
            if mod(minVal, 1) == 0 && mod(maxVal, 1) == 0
                label = sprintf('%d-%d', minVal, maxVal);
            else
                label = sprintf('%.2f-%.2f', minVal, maxVal);
            end
            
            % Добавляем диапазон
            rangeStruct = struct('min', minVal, 'max', maxVal, 'label', label, 'isEquality', false, 'value', []);
        else
            % Равенство: [val]
            valueStr = strtrim(rangeStr);
            value = str2double(valueStr);
            
            if isnan(value)
                continue
            end
            
            % Создаем метку для равенства
            if mod(value, 1) == 0
                label = sprintf('%d', value);
            else
                label = sprintf('%.2f', value);
            end
            
            % Добавляем равенство
            rangeStruct = struct('min', [], 'max', [], 'label', label, 'isEquality', true, 'value', value);
        end
        
        if isempty(ranges)
            ranges = rangeStruct;
        else
            ranges(end+1) = rangeStruct;
        end
    end
    
    if isempty(ranges)
        return
    end
    
    parsedRanges.columnName = columnName;
    parsedRanges.ranges = ranges;
end
