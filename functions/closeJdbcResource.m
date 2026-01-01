function closeJdbcResource(object)
    if isempty(object)
        return
    end
    try
        object.close();
    catch
    end
end

