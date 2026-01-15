function isNumeric = isNumericCellArray(cellData)
    % isNumericCellArray - Определение, является ли cell-массив числовым
    % Проверяет элементы cell-массива: если все (или большинство) элементы 
    % числовые или логические скаляры, возвращает true
    % Если есть текстовые элементы, возвращает false
    
    isNumeric = false;
    
    if ~iscell(cellData) || isempty(cellData)
        return
    end
    
    % Проверяем первые элементы (или все, если их немного)
    numToCheck = min(100, length(cellData));
    numericCount = 0;
    textCount = 0;
    emptyCount = 0;
    
    for i = 1:numToCheck
        value = cellData{i};
        if isnumeric(value) && isscalar(value)
            numericCount = numericCount + 1;
        elseif islogical(value) && isscalar(value)
            numericCount = numericCount + 1;
        elseif ischar(value) || isstring(value)
            textCount = textCount + 1;
        elseif isempty(value)
            emptyCount = emptyCount + 1;
        end
    end
    
    % Если есть хотя бы одно текстовое значение, cell-массив НЕ числовой
    if textCount > 0
        isNumeric = false;
        return
    end
    
    % Если все непустые значения числовые или логические, считаем числовым
    totalChecked = numericCount + textCount;
    if totalChecked > 0
        % Если есть только числовые элементы (нет текстовых), считаем числовым
        isNumeric = true;
    elseif emptyCount == numToCheck
        % Если все элементы пустые, не считаем числовым
        isNumeric = false;
    end
end
