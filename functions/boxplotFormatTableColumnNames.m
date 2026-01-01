function table = boxplotFormatTableColumnNames(table)
    % boxplotFormatTableColumnNames - Форматирует названия колонок таблицы
    % Транскрибирует кириллические буквы в латиницу, затем делает имя валидным для MATLAB
    % Использует transliterateColumnName для транскрипции
    % 
    % Входные параметры:
    %   table - таблица с исходными названиями колонок
    %
    % Выходные параметры:
    %   table - таблица с отформатированными названиями колонок
    
    originalNames = table.Properties.VariableNames;
    validNames = cell(size(originalNames));
    for i = 1:length(originalNames)
        validNames{i} = transliterateColumnName(originalNames{i});
    end
    table.Properties.VariableNames = validNames;
end

