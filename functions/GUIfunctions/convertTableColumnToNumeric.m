function numericData = convertTableColumnToNumeric(columnData)
    % convertTableColumnToNumeric - Конвертация данных колонки таблицы в числовой формат
    % Принимает данные любого типа и возвращает числовой массив (double)
    % Строковые значения конвертируются через str2double (неконвертируемые → NaN)
    % Cell arrays обрабатываются: если внутри числа - извлекаются, если строки - конвертируются
    
    if isnumeric(columnData)
        numericData = double(columnData);
    elseif islogical(columnData)
        numericData = double(columnData);
    elseif iscell(columnData)
        numericData = nan(length(columnData), 1);
        for i = 1:length(columnData)
            value = columnData{i};
            if isnumeric(value) && isscalar(value)
                numericData(i) = double(value);
            elseif islogical(value) && isscalar(value)
                numericData(i) = double(value);
            elseif ischar(value) || isstring(value)
                numericData(i) = str2double(value);
            elseif isempty(value)
                numericData(i) = NaN;
            end
        end
    else
        numericData = str2double(columnData);
    end
end
