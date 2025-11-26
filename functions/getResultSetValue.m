function value = getResultSetValue(resultSet, meta, col)
    value = [];
    try
        typeName = char(meta.getColumnTypeName(col));
        switch lower(typeName)
            case {'integer', 'int', 'bigint'}
                val = resultSet.getLong(col);
                if resultSet.wasNull()
                    value = [];
                else
                    value = double(val);
                end
            case {'real', 'double', 'float', 'numeric'}
                val = resultSet.getDouble(col);
                if resultSet.wasNull()
                    value = [];
                else
                    value = double(val);
                end
            case {'text', 'varchar', 'char'}
                val = resultSet.getString(col);
                if isempty(val) || resultSet.wasNull()
                    value = [];
                else
                    value = char(val);
                end
            case {'blob'}
                val = resultSet.getBytes(col);
                if isempty(val) || resultSet.wasNull()
                    value = [];
                else
                    value = val;
                end
            otherwise
                val = resultSet.getString(col);
                if isempty(val) || resultSet.wasNull()
                    value = [];
                else
                    value = char(val);
                end
        end
    catch
        try
            obj = resultSet.getObject(col);
            if isempty(obj) || resultSet.wasNull()
                value = [];
            else
                value = char(obj.toString());
            end
        catch
            value = [];
        end
    end
end

