function fileTable = calculateGabaAmpaOnsetDiff(fileTable)
    if isempty(fileTable) || width(fileTable) < 3
        return
    end
    
    varNames = fileTable.Properties.VariableNames;
    outputFields = {'GABA-AMPA'};
    for i = 1:numel(outputFields)
        if any(strcmp(varNames, outputFields{i}))
            fileTable = removevars(fileTable, outputFields{i});
        end
    end
    
    varNames = fileTable.Properties.VariableNames;
    requiredCols = {'pair_id', 'current_type', 'first_onset_by_channel_1'};
    if ~all(ismember(requiredCols, varNames))
        return
    end
    
    numRows = height(fileTable);
    gabaAmpaDiff = cell(numRows, 1);
    
    pairIdRaw = fileTable.('pair_id');
    currentTypeRaw = fileTable.('current_type');
    firstOnsetRaw = fileTable.('first_onset_by_channel_1');
    
    firstOnset = nan(numRows, 1);
    
    if iscell(firstOnsetRaw)
        for i = 1:numRows
            val = firstOnsetRaw{i};
            if isempty(val)
                firstOnset(i) = NaN;
            elseif ischar(val) || isstring(val)
                numVal = str2double(val);
                if ~isnan(numVal)
                    firstOnset(i) = numVal;
                end
            elseif isnumeric(val)
                firstOnset(i) = val;
            end
        end
    elseif isnumeric(firstOnsetRaw)
        firstOnset = firstOnsetRaw;
    end
    
    if iscell(pairIdRaw)
        pairIds = cell(numRows, 1);
        for i = 1:numRows
            val = pairIdRaw{i};
            if isnumeric(val) && isscalar(val)
                pairIds{i} = val;
            elseif ischar(val) || isstring(val)
                numVal = str2double(val);
                if ~isnan(numVal)
                    pairIds{i} = numVal;
                end
            end
        end
        validPairIds = pairIds(~cellfun(@isempty, pairIds));
        if ~isempty(validPairIds)
            uniquePairs = unique(cell2mat(validPairIds));
        else
            uniquePairs = [];
        end
    else
        pairIds = pairIdRaw;
        uniquePairs = unique(pairIds(~isnan(pairIds)));
    end
    
    for pairIdx = 1:numel(uniquePairs)
        pairId = uniquePairs(pairIdx);
        
        if iscell(pairIds)
            pairMask = cellfun(@(x) isequal(x, pairId), pairIds);
        else
            pairMask = pairIds == pairId;
        end
        
        if iscell(currentTypeRaw)
            gabaMask = pairMask & cellfun(@(x) isequal(x, 'GABA'), currentTypeRaw);
            ampaMask = pairMask & cellfun(@(x) isequal(x, 'AMPA'), currentTypeRaw);
        else
            gabaMask = pairMask & strcmp(currentTypeRaw, 'GABA');
            ampaMask = pairMask & strcmp(currentTypeRaw, 'AMPA');
        end
        
        gabaOnsets = firstOnset(gabaMask & ~isnan(firstOnset));
        ampaOnsets = firstOnset(ampaMask & ~isnan(firstOnset));
        
        if ~isempty(gabaOnsets) && ~isempty(ampaOnsets)
            gabaMedian = median(gabaOnsets);
            ampaMedian = median(ampaOnsets);
            diff = gabaMedian - ampaMedian;
            for idx = find(gabaMask)'
                gabaAmpaDiff{idx} = diff;
            end
        end
    end
    
    fileTable.('GABA-AMPA') = gabaAmpaDiff;
end
