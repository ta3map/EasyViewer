function fileTable = calculateGabaAmpaOnsetDiff(fileTable)
    outputFields = {'onsets_GABA_AMPA_medians', 'onsets_GABA_AMPA_clusters', 'median_diff_state', 'median_silent'};
    for i = 1:numel(outputFields)
        if ismember(outputFields{i}, fileTable.Properties.VariableNames)
            fileTable = removevars(fileTable, outputFields{i});
        end
    end
    
    numRows = height(fileTable);
    gabaAmpaDiffMedian = cell(numRows, 1);
    gabaAmpaDiffCluster = cell(numRows, 1);
    gabaAmpaDiffMedianSmall = cell(numRows, 1);
    gabaAmpaSilent = cell(numRows, 1);
    
    pairIdRaw = fileTable.('pair_id');
    currentTypeRaw = fileTable.('current_type');
    medianOnsetRaw = fileTable.('median_first_onset');
    clusterOnsetRaw = fileTable.('cluster_first_onset_ms');
    
    hasResponseRaw = fileTable.('has_response');
    moreResponsesRaw = fileTable.('more_responses_after_zero_by_channel');
    
    hasResponse = false(numRows, 1);
    moreResponsesAfterZero = false(numRows, 1);
    medianOnset = nan(numRows, 1);
    clusterOnset = nan(numRows, 1);
    pairIds = cell(numRows, 1);
    
    for i = 1:numRows
        hasResponse(i) = strcmpi(strtrim(hasResponseRaw{i}), 'true');
        moreResponsesAfterZero(i) = strcmpi(strtrim(moreResponsesRaw{i}), 'true');
        medianOnset(i) = str2double(medianOnsetRaw{i});
        clusterOnset(i) = str2double(clusterOnsetRaw{i});
        pairIds{i} = str2double(pairIdRaw{i});
    end
    
    pairIdsNumeric = cell2mat(pairIds(~cellfun(@isempty, pairIds)));
    uniquePairs = unique(pairIdsNumeric(~isnan(pairIdsNumeric)));
    
    for pairIdx = 1:numel(uniquePairs)
        pairId = uniquePairs(pairIdx);
        
        pairMask = cellfun(@(x) isequal(x, pairId), pairIds);
        gabaMask = pairMask & cellfun(@(x) strcmpi(strtrim(x), 'GABA'), currentTypeRaw);
        ampaMask = pairMask & cellfun(@(x) strcmpi(strtrim(x), 'AMPA'), currentTypeRaw);
        
        gabaIndices = find(gabaMask);
        ampaIndices = find(ampaMask);
        
        gabaWithResponse = gabaIndices(moreResponsesAfterZero(gabaIndices) & ~isnan(medianOnset(gabaIndices)));
        ampaWithResponse = ampaIndices(moreResponsesAfterZero(ampaIndices) & ~isnan(medianOnset(ampaIndices)));
        
        if numel(ampaWithResponse) >= 1
            ampaIdx = ampaWithResponse(1);
            if medianOnset(ampaIdx) >= 0
                if numel(gabaIndices) >= 1
                    gabaIdx = gabaIndices(1);
                    if ~moreResponsesAfterZero(gabaIdx) || isnan(medianOnset(gabaIdx))
                        gabaAmpaSilent{gabaIdx} = 'true';
                    end
                end
            end
        end
        
        if numel(gabaWithResponse) >= 1 && numel(ampaWithResponse) >= 1
            gabaIdx = gabaWithResponse(1);
            ampaIdx = ampaWithResponse(1);
            if medianOnset(gabaIdx) >= 0 && medianOnset(ampaIdx) >= 0
                diff = medianOnset(gabaIdx) - medianOnset(ampaIdx);
                gabaAmpaDiffMedian{gabaIdx} = diff;
                if diff < 0.1
                    gabaAmpaDiffMedianSmall{gabaIdx} = 'small';
                else
                    gabaAmpaDiffMedianSmall{gabaIdx} = 'normal';
                end
            end
        end
    end
    
    for pairIdx = 1:numel(uniquePairs)
        pairId = uniquePairs(pairIdx);
        
        pairMask = cellfun(@(x) isequal(x, pairId), pairIds);
        gabaMask = pairMask & cellfun(@(x) strcmpi(strtrim(x), 'GABA'), currentTypeRaw);
        ampaMask = pairMask & cellfun(@(x) strcmpi(strtrim(x), 'AMPA'), currentTypeRaw);
        
        gabaIndices = find(gabaMask);
        ampaIndices = find(ampaMask);
        
        gabaWithResponse = gabaIndices(hasResponse(gabaIndices) & ~isnan(clusterOnset(gabaIndices)));
        ampaWithResponse = ampaIndices(hasResponse(ampaIndices) & ~isnan(clusterOnset(ampaIndices)));
        
        if numel(gabaWithResponse) >= 1 && numel(ampaWithResponse) >= 1
            gabaIdx = gabaWithResponse(1);
            ampaIdx = ampaWithResponse(1);
            if clusterOnset(gabaIdx) >= 0 && clusterOnset(ampaIdx) >= 0
                diff = clusterOnset(gabaIdx) - clusterOnset(ampaIdx);
                gabaAmpaDiffCluster{gabaIdx} = diff;
            end
        end
    end
    
    fileTable.('onsets_GABA_AMPA_medians') = gabaAmpaDiffMedian;
    fileTable.('onsets_GABA_AMPA_clusters') = gabaAmpaDiffCluster;
    fileTable.('median_diff_state') = gabaAmpaDiffMedianSmall;
    fileTable.('median_silent') = gabaAmpaSilent;
end
