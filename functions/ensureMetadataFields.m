function ensureMetadataFields(fields)
    global matFilePath spks lfpVar chnlGrp zavSessionLoadedMetadata

    if isempty(matFilePath) || isempty(fields)
        return;
    end

    if isempty(zavSessionLoadedMetadata)
        zavSessionLoadedMetadata = {};
    end

    missing = setdiff(fields(:)', zavSessionLoadedMetadata, 'stable');
    if isempty(missing)
        return;
    end

    mf = matfile(matFilePath);
    varNames = who(mf);
    for i = 1:numel(missing)
        fieldName = missing{i};
        if ~any(strcmp(varNames, fieldName))
            continue;
        end
        switch fieldName
            case 'spks'
                spks = mf.spks;
                spks = sortSpikeTimestamps(spks);
            case 'lfpVar'
                lfpVar = mf.lfpVar;
            case 'chnlGrp'
                chnlGrp = mf.chnlGrp;
            otherwise
                continue;
        end
        zavSessionLoadedMetadata{end + 1} = fieldName; %#ok<AGROW>
    end
end
