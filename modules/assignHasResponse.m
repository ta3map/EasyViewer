function fileTable = assignHasResponse(fileTable)
    if isempty(fileTable) || ~ismember("cluster_first_onset_ms", string(fileTable.Properties.VariableNames))
        return
    end
    
    clusterOnset = fileTable.cluster_first_onset_ms;
    numRows = height(fileTable);
    hasResponse = false(numRows, 1);
    
    for i = 1:numRows
        val = clusterOnset(i);
        if iscell(val)
            val = val{1};
        end
        if isnumeric(val)
            hasResponse(i) = ~isempty(val) && ~isnan(val);
        else
            valStr = string(val);
            hasResponse(i) = ~ismissing(valStr) && strlength(strtrim(valStr)) > 0;
        end
    end
    
    fileTable.has_response = hasResponse;
end

