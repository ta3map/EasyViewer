function yLabelText = getYAxisLabelFromGroupParams(paramsInGroup, mode)
    % getYAxisLabelFromGroupParams - Получение подписи Y оси из параметров группы
    % 
    % Входные параметры:
    %   paramsInGroup - массив структур параметров группы (cell array)
    %   mode - режим работы: 'all' (объединить все уникальные колонки) или 'first' (первая колонка)
    %
    % Выходные параметры:
    %   yLabelText - строка с подписью для Y оси
    
    if nargin < 2
        mode = 'all';
    end
    
    if isempty(paramsInGroup)
        yLabelText = '';
        return
    end
    
    if strcmp(mode, 'first')
        % Берем первую колонку
        if isfield(paramsInGroup{1}, 'column') && ~isempty(paramsInGroup{1}.column)
            yLabelText = paramsInGroup{1}.column;
        else
            yLabelText = '';
        end
    else
        % Собираем все уникальные колонки
        uniqueColumns = {};
        for p = 1:length(paramsInGroup)
            if isfield(paramsInGroup{p}, 'column') && ~isempty(paramsInGroup{p}.column)
                col = paramsInGroup{p}.column;
                if ~ismember(col, uniqueColumns)
                    uniqueColumns{end+1} = col;
                end
            end
        end
        if ~isempty(uniqueColumns)
            yLabelText = strjoin(uniqueColumns, ', ');
        else
            yLabelText = '';
        end
    end
end
