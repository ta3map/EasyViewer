function state = applyRangesSplit(state, i, fieldName, columnName, paramStruct, parsedColor, gn, filterStr, parsedRanges, filteredTable)
    % applyRangesSplit - Разбиение данных по диапазонам или равенствам
    % 
    % Входные параметры:
    %   state - структура состояния GUI
    %   i - индекс параметра
    %   fieldName - базовое имя поля
    %   columnName - имя колонки для данных
    %   paramStruct - структура параметра
    %   parsedColor - RGB цвет
    %   gn - имя группы
    %   filterStr - строка фильтра
    %   parsedRanges - структура с распарсенными диапазонами
    %   filteredTable - отфильтрованная таблица
    %
    % Выходные параметры:
    %   state - обновленная структура состояния
    
    % Разбиение по диапазонам
    rangeColumnName = parsedRanges.columnName;
    
    % Проверяем, что колонка для диапазонов существует и числовая
    if ~ismember(rangeColumnName, filteredTable.Properties.VariableNames)
        % Колонка не существует - работаем как раньше
        columnData = filteredTable{:, columnName};
        if isnumeric(columnData)
            filteredData = double(columnData);
        else
            filteredData = [];
        end
        
        fileIds = [];
        if ismember('FileID', filteredTable.Properties.VariableNames)
            fileIds = filteredTable{:, 'FileID'};
        end
        
        stats = statProc(filteredData);
        
        validFieldName = matlab.lang.makeValidName(fieldName);
        state.parameterToFieldName{i} = validFieldName;
        state.filteredData.(validFieldName) = struct(...
            'data', filteredData, ...
            'column', columnName, ...
            'label', paramStruct.label, ...
            'color', paramStruct.color, ...
            'parsedColor', parsedColor, ...
            'lineWidth', paramStruct.lineWidth, ...
            'groupName', gn, ...
            'filter', filterStr, ...
            'fieldName', validFieldName, ...
            'stats', stats, ...
            'fileIds', fileIds);
        
        filterDisplay = filterStr;
        if isempty(filterDisplay)
            filterDisplay = '';
        end
        fprintf('%s: filter: ''%s'', size: %d, median: %.3f, std: %.3f\n', ...
            fieldName, filterDisplay, stats.count, stats.median, stats.std);
    else
        % Получаем данные колонки для диапазонов
        rangeColumnData = filteredTable{:, rangeColumnName};
        if ~isnumeric(rangeColumnData)
            % Колонка не числовая - работаем как раньше
            columnData = filteredTable{:, columnName};
            if isnumeric(columnData)
                filteredData = double(columnData);
            else
                filteredData = [];
            end
            
            fileIds = [];
            if ismember('FileID', filteredTable.Properties.VariableNames)
                fileIds = filteredTable{:, 'FileID'};
            end
            
            stats = statProc(filteredData);
            
            validFieldName = matlab.lang.makeValidName(fieldName);
            state.parameterToFieldName{i} = validFieldName;
            state.filteredData.(validFieldName) = struct(...
                'data', filteredData, ...
                'column', columnName, ...
                'label', paramStruct.label, ...
                'color', paramStruct.color, ...
                'parsedColor', parsedColor, ...
                'lineWidth', paramStruct.lineWidth, ...
                'groupName', gn, ...
                'filter', filterStr, ...
                'fieldName', validFieldName, ...
                'stats', stats, ...
                'fileIds', fileIds);
            
            filterDisplay = filterStr;
            if isempty(filterDisplay)
                filterDisplay = '';
            end
            fprintf('%s: filter: ''%s'', size: %d, median: %.3f, std: %.3f\n', ...
                fieldName, filterDisplay, stats.count, stats.median, stats.std);
        else
            % Разбиваем данные по диапазонам
            rangeColumnData = double(rangeColumnData);
            numRanges = length(parsedRanges.ranges);
            
            % Получаем данные основной колонки
            columnData = filteredTable{:, columnName};
            if ~isnumeric(columnData)
                return
            end
            columnData = double(columnData);
            
            % Получаем File ID
            fileIds = [];
            if ismember('FileID', filteredTable.Properties.VariableNames)
                fileIds = filteredTable{:, 'FileID'};
            end
            
            % Обрабатываем каждый диапазон или значение равенства
            for rangeIdx = 1:numRanges
                range = parsedRanges.ranges(rangeIdx);
                
                % Создаем маску для диапазона или равенства
                if isfield(range, 'isEquality') && range.isEquality
                    % Проверка на равенство
                    mask = rangeColumnData == range.value & ~isnan(rangeColumnData);
                else
                    % Диапазон
                    if rangeIdx == numRanges
                        % Последний диапазон: >= min & <= max
                        mask = rangeColumnData >= range.min & rangeColumnData <= range.max & ~isnan(rangeColumnData);
                    else
                        % Промежуточные диапазоны: >= min & < max
                        mask = rangeColumnData >= range.min & rangeColumnData < range.max & ~isnan(rangeColumnData);
                    end
                end
                
                % Фильтруем данные по маске
                rangeData = columnData(mask);
                rangeFileIds = [];
                if ~isempty(fileIds) && length(fileIds) == length(columnData)
                    rangeFileIds = fileIds(mask);
                end
                
                % Рассчитываем статистику
                stats = statProc(rangeData);
                
                % Создаем уникальное имя поля для диапазона
                rangeFieldName = sprintf('%s_range%d', fieldName, rangeIdx);
                validRangeFieldName = matlab.lang.makeValidName(rangeFieldName);
                
                % Создаем метку с диапазоном
                rangeLabel = sprintf('%s (%s)', paramStruct.label, range.label);
                
                % Сохраняем в структуру
                % Для диапазонов используем последний созданный fieldName
                if rangeIdx == numRanges
                    state.parameterToFieldName{i} = validRangeFieldName;
                end
                state.filteredData.(validRangeFieldName) = struct(...
                    'data', rangeData, ...
                    'column', columnName, ...
                    'label', rangeLabel, ...
                    'color', paramStruct.color, ...
                    'parsedColor', parsedColor, ...
                    'lineWidth', paramStruct.lineWidth, ...
                    'groupName', gn, ...
                    'filter', filterStr, ...
                    'fieldName', validRangeFieldName, ...
                    'stats', stats, ...
                    'fileIds', rangeFileIds);
                
                % Выводим превью в консоль
                filterDisplay = filterStr;
                if isempty(filterDisplay)
                    filterDisplay = '';
                end
                fprintf('%s: filter: ''%s'', range: %s, size: %d, median: %.3f, std: %.3f\n', ...
                    validRangeFieldName, filterDisplay, range.label, stats.count, stats.median, stats.std);
            end
        end
    end
end
