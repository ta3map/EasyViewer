function fileTable = assignStimulusPairId(fileTable)
    if isempty(fileTable) || width(fileTable) < 3
        return
    end
    
    varNames = fileTable.Properties.VariableNames;
    outputFields = {'folder_id', 'current_type', 'pair_id'};
    for i = 1:numel(outputFields)
        if any(strcmp(varNames, outputFields{i}))
            fileTable = removevars(fileTable, outputFields{i});
        end
    end
    
    paths = fileTable.Path;
    folders = cellfun(@(p) fileparts(p), paths, 'UniformOutput', false);
    [~, ~, folderIdx] = unique(folders);
    fileTable.folder_id = folderIdx;
    
    varNames = fileTable.Properties.VariableNames;
    requiredCols = {'hold_potential', 'stim'};
    if ~all(ismember(requiredCols, varNames))
        return
    end
    
    numRows = height(fileTable);
    currentType = cell(numRows, 1);
    pairId = cell(numRows, 1);
    
    holdPotentialRaw = fileTable.hold_potential;
    holdPotential = nan(numRows, 1);
    
    if iscell(holdPotentialRaw)
        for i = 1:numRows
            val = holdPotentialRaw{i};
            if isempty(val)
                holdPotential(i) = NaN;
            elseif ischar(val) || isstring(val)
                numVal = str2double(val);
                if ~isnan(numVal)
                    holdPotential(i) = numVal;
                end
            elseif isnumeric(val)
                holdPotential(i) = val;
            end
        end
    elseif isnumeric(holdPotentialRaw)
        holdPotential = holdPotentialRaw;
    end
    
    folderIds = fileTable.folder_id;
    stims = fileTable.stim;
    uniqueFolders = unique(folderIds);
    nextPairId = 1;
    
    for folderIdx = 1:numel(uniqueFolders)
        folderId = uniqueFolders(folderIdx);
        folderMask = folderIds == folderId;
        validMask = folderMask & ~isnan(holdPotential);
        
        if ~any(validMask)
            continue
        end
        
        gabaMask = validMask & holdPotential >= 0;
        ampaMask = validMask & holdPotential < 0;
        
        currentType(gabaMask) = {'GABA'};
        currentType(ampaMask) = {'AMPA'};
        
        folderStims = stims(validMask);
        uniqueStims = unique(folderStims);
        
        for stimIdx = 1:numel(uniqueStims)
            if iscell(uniqueStims)
                stim = uniqueStims{stimIdx};
                stimMask = validMask & cellfun(@(x) isequal(x, stim), stims);
            else
                stim = uniqueStims(stimIdx);
                stimMask = validMask & stims == stim;
            end
            
            hasGABA = any(gabaMask & stimMask);
            hasAMPA = any(ampaMask & stimMask);
            
            if hasGABA && hasAMPA
                pairId(stimMask) = {nextPairId};
                nextPairId = nextPairId + 1;
            end
        end
    end
    
    fileTable.current_type = currentType;
    fileTable.pair_id = pairId;
end
