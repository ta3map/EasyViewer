function val = getStructValue(structVar, fieldName, defaultVal)
    if isfield(structVar, fieldName) && ~isempty(structVar.(fieldName))
        val = structVar.(fieldName);
    else
        val = defaultVal;
    end
end

