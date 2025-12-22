function baseName = updateBaseName(baseName, params)
    % Обновляет базовое имя файла с учетом параметров именования
    % baseName - исходное базовое имя файла (без расширения)
    % params - структура параметров модуля
    % Возвращает обновленное базовое имя (без расширения)
    % 
    % Если params.ResultSuffix не пустое, добавляет его после baseName
    % Если params.AddTimestamp == true, добавляет время в формате yyyy-MM-dd_HH-mm-ss
    % Порядок: baseName_ResultSuffix_Timestamp (если оба включены)
    
    if nargin < 2 || isempty(params)
        return
    end
    
    resultSuffix = '';
    if isfield(params, 'ResultSuffix') && ~isempty(params.ResultSuffix)
        resultSuffix = char(params.ResultSuffix);
        resultSuffix = strtrim(resultSuffix);
        if isempty(resultSuffix)
            resultSuffix = '';
        end
    end
    
    addTimestamp = false;
    if isfield(params, 'AddTimestamp')
        addTimestamp = logical(params.AddTimestamp);
    end
    
    parts = {baseName};
    
    if ~isempty(resultSuffix)
        parts{end+1} = resultSuffix;
    end
    
    if addTimestamp
        timestamp = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
        parts{end+1} = timestamp;
    end
    
    if length(parts) > 1
        baseName = strjoin(parts, '_');
    end
end

