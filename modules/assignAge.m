function fileTable = assignAge(fileTable)
    if isempty(fileTable) || width(fileTable) < 3
        return
    end
    
    varNames = fileTable.Properties.VariableNames;
    if ~any(strcmp(varNames, 'Path'))
        return
    end
    
    paths = fileTable.('Path');
    numRows = height(fileTable);
    
    age = cell(numRows, 1);
    
    for i = 1:numRows
        p = paths{i};
        if isempty(p) || (~ischar(p) && ~isstring(p))
            age{i} = '';
            continue
        end
        
        p = char(p);
        tokens = regexp(p, '_[pP](\d+)', 'tokens', 'once');
        
        if ~isempty(tokens)
            age{i} = str2double(tokens{1});
        else
            age{i} = '';
        end
    end
    
    fileTable.age = age;
end

