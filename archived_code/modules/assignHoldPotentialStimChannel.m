function fileTable = assignHoldPotentialStimChannel(fileTable)
    if isempty(fileTable) || width(fileTable) < 3
        return
    end
    
    varNames = fileTable.Properties.VariableNames;
    if ~any(strcmp(varNames, 'File Name'))
        return
    end
    
    fileNames = fileTable.('File Name');
    numRows = height(fileTable);
    
    holdPotential = cell(numRows, 1);
    stim = cell(numRows, 1);
    channel = cell(numRows, 1);
    
    for i = 1:numRows
        fileName = fileNames{i};
        if isempty(fileName) || (~ischar(fileName) && ~isstring(fileName))
            holdPotential{i} = '';
            stim{i} = '';
            channel{i} = '';
            continue
        end
        
        fileName = char(fileName);
        
        pattern = '^([+-]?\d+)mV_([+-]?\d+)V_ch([+-]?\d+)(\.[^.]+)?$';
        tokens = regexp(fileName, pattern, 'tokens', 'once');
        
        if ~isempty(tokens) && numel(tokens) >= 3
            holdPotential{i} = str2double(tokens{1});
            stim{i} = str2double(tokens{2});
            channel{i} = str2double(tokens{3});
        else
            holdPotential{i} = '';
            stim{i} = '';
            channel{i} = '';
        end
    end
    
    fileTable.hold_potential = holdPotential;
    fileTable.stim = stim;
    fileTable.channel = channel;
end
