function rows = jdbcResultToCell(resultSet)
    rows = {};
    if isempty(resultSet)
        return
    end
    try
        meta = resultSet.getMetaData();
        colCount = double(meta.getColumnCount());
        data = cell(0, colCount);
        rowIdx = 1;
        while resultSet.next()
            row = cell(1, colCount);
            for col = 1:colCount
                value = getResultSetValue(resultSet, meta, col);
                row{col} = value;
            end
            data(rowIdx, :) = row;
            rowIdx = rowIdx + 1;
        end
        rows = data;
    catch ME
        warning('SQL result reading error: %s', ME.message);
        rows = {};
    end
end

