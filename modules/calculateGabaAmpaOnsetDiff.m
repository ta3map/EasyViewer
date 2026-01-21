function fileTable = calculateGabaAmpaOnsetDiff(fileTable)
    if isempty(fileTable) || width(fileTable) < 3
        return
    end
    
    varNames = fileTable.Properties.VariableNames;
    outputFields = {'onsets_GABA_AMPA_medians', 'onsets_GABA_AMPA_clusters'};
    for i = 1:numel(outputFields)
        if any(strcmp(varNames, outputFields{i}))
            fileTable = removevars(fileTable, outputFields{i});
        end
    end
    
    varNames = fileTable.Properties.VariableNames;
    requiredCols = {'pair_id', 'current_type', 'median_first_onset', 'cluster_first_onset_ms'};
    if ~all(ismember(requiredCols, varNames))
        return
    end
    
    if ~ismember('has_response', varNames)
        numRows = height(fileTable);
        gabaAmpaDiffMedian = cell(numRows, 1);
        gabaAmpaDiffCluster = cell(numRows, 1);
        fileTable.('onsets_GABA_AMPA_medians') = gabaAmpaDiffMedian;
        fileTable.('onsets_GABA_AMPA_clusters') = gabaAmpaDiffCluster;
        return
    end
    
    numRows = height(fileTable);
    gabaAmpaDiffMedian = cell(numRows, 1);
    gabaAmpaDiffCluster = cell(numRows, 1);
    
    pairIdRaw = fileTable.('pair_id');
    currentTypeRaw = fileTable.('current_type');
    medianOnsetRaw = fileTable.('median_first_onset');
    clusterOnsetRaw = fileTable.('cluster_first_onset_ms');
    hasResponseRaw = fileTable.('has_response');
    
    hasResponse = false(numRows, 1);
    if iscell(hasResponseRaw)
        for i = 1:numRows
            val = hasResponseRaw{i};
            if ischar(val) || isstring(val)
                hasResponse(i) = strcmpi(strtrim(string(val)), 'true');
            elseif islogical(val)
                hasResponse(i) = val;
            end
        end
    elseif islogical(hasResponseRaw)
        hasResponse = hasResponseRaw;
    end
    
    medianOnset = nan(numRows, 1);
    if iscell(medianOnsetRaw)
        for i = 1:numRows
            val = medianOnsetRaw{i};
            if isempty(val)
                medianOnset(i) = NaN;
            elseif ischar(val) || isstring(val)
                numVal = str2double(val);
                if ~isnan(numVal)
                    medianOnset(i) = numVal;
                end
            elseif isnumeric(val)
                medianOnset(i) = val;
            end
        end
    elseif isnumeric(medianOnsetRaw)
        medianOnset = medianOnsetRaw;
    end
    
    clusterOnset = nan(numRows, 1);
    if iscell(clusterOnsetRaw)
        for i = 1:numRows
            val = clusterOnsetRaw{i};
            if isempty(val)
                clusterOnset(i) = NaN;
            elseif ischar(val) || isstring(val)
                numVal = str2double(val);
                if ~isnan(numVal)
                    clusterOnset(i) = numVal;
                end
            elseif isnumeric(val)
                clusterOnset(i) = val;
            end
        end
    elseif isnumeric(clusterOnsetRaw)
        clusterOnset = clusterOnsetRaw;
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
        
        gabaIndices = find(gabaMask);
        ampaIndices = find(ampaMask);
        
        gabaWithResponse = gabaIndices(hasResponse(gabaIndices) & ~isnan(medianOnset(gabaIndices)));
        ampaWithResponse = ampaIndices(hasResponse(ampaIndices) & ~isnan(medianOnset(ampaIndices)));
        
        if numel(gabaWithResponse) == 1 && numel(ampaWithResponse) == 1
            gabaOnsetMedian = medianOnset(gabaWithResponse);
            ampaOnsetMedian = medianOnset(ampaWithResponse);
            diff = gabaOnsetMedian - ampaOnsetMedian;
            gabaAmpaDiffMedian{gabaWithResponse} = diff;
        end
        
        gabaWithResponseCluster = gabaIndices(hasResponse(gabaIndices) & ~isnan(clusterOnset(gabaIndices)));
        ampaWithResponseCluster = ampaIndices(hasResponse(ampaIndices) & ~isnan(clusterOnset(ampaIndices)));
        
        if numel(gabaWithResponseCluster) == 1 && numel(ampaWithResponseCluster) == 1
            gabaOnsetCluster = clusterOnset(gabaWithResponseCluster);
            ampaOnsetCluster = clusterOnset(ampaWithResponseCluster);
            diff = gabaOnsetCluster - ampaOnsetCluster;
            gabaAmpaDiffCluster{gabaWithResponseCluster} = diff;
        end
    end
    
    fileTable.('onsets_GABA_AMPA_medians') = gabaAmpaDiffMedian;
    fileTable.('onsets_GABA_AMPA_clusters') = gabaAmpaDiffCluster;
end
