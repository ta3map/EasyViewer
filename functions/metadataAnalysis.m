function metadataAnalysis(metaPaths, fileIds)
    if isempty(metaPaths)
        return
    end
    
    debugState('metadataAnalysis', 'Starting metadata analysis with %d file(s)', numel(metaPaths));
    
    if nargin < 2 || isempty(fileIds)
        fileIds = zeros(numel(metaPaths), 1);
    end
    
    if numel(fileIds) ~= numel(metaPaths)
        fileIds = zeros(numel(metaPaths), 1);
    end
    
    firstMetaPath = metaPaths{1};
    if ~exist(firstMetaPath, 'file')
        debugState('metadataAnalysis', 'First .meta file not found: %s', firstMetaPath);
        msgbox(sprintf('First .meta file not found: %s', firstMetaPath), 'Error', 'error');
        return
    end
    
    debugState('metadataAnalysis', 'Loading first .meta file: %s', firstMetaPath);
    try
        firstMeta = load(firstMetaPath, '-mat');
    catch ME
        debugState('metadataAnalysis', 'Failed to load first .meta file: %s', ME.message);
        msgbox(sprintf('Failed to load first .meta file: %s', ME.message), 'Error', 'error');
        return
    end
    
    debugState('metadataAnalysis', 'Extracting all fields from metadata structure');
    allFields = extractAllFields(firstMeta);
    if isempty(allFields)
        debugState('metadataAnalysis', 'No fields found in metadata structure');
        msgbox('No fields found in metadata structure', 'Error', 'error');
        return
    end
    
    debugState('metadataAnalysis', 'Found %d metadata fields', numel(allFields));
    
    selectedFields = showFieldSelectionDialog(allFields);
    if isempty(selectedFields)
        debugState('metadataAnalysis', 'No fields selected, cancelling');
        return
    end
    
    debugState('metadataAnalysis', 'Selected %d field(s) for analysis', numel(selectedFields));
    
    [file, path] = uiputfile('*.mat', 'Save Metadata Analysis', 'metadata_analysis.mat');
    if isequal(file, 0)
        debugState('metadataAnalysis', 'Save cancelled by user');
        return
    end
    
    savePath = fullfile(path, file);
    debugState('metadataAnalysis', 'Save path selected: %s', savePath);
    
    debugState('metadataAnalysis', 'Saving directly to MAT file (streaming)');
    success = saveToMatDirect(metaPaths, fileIds, selectedFields, savePath);
    if ~success
        debugState('metadataAnalysis', 'Failed to create and save table');
        msgbox('Failed to create and save table', 'Error', 'error');
        return
    end
    
    debugState('metadataAnalysis', 'Table successfully saved to: %s', savePath);
    msgbox(sprintf('Data saved to %s', savePath), 'Success', 'help');
end

function fields = extractAllFields(structData)
    fields = {};
    fieldNames = fieldnames(structData);
    for i = 1:numel(fieldNames)
        fieldName = fieldNames{i};
        fields = extractFieldsRecursive(structData.(fieldName), fieldName, fields);
    end
end

function fields = extractFieldsRecursive(value, prefix, fields)
    if isstruct(value)
        fieldNames = fieldnames(value);
        for i = 1:numel(fieldNames)
            subFieldName = fieldNames{i};
            newPrefix = sprintf('%s.%s', prefix, subFieldName);
            fields = extractFieldsRecursive(value.(subFieldName), newPrefix, fields);
        end
    else
        fields{end+1} = prefix;
    end
end

function selectedFields = showFieldSelectionDialog(allFields)
    selectedFields = [];
    
    fig = figure('Position', [300, 300, 500, 400], ...
        'Name', 'Select Metadata Fields', ...
        'NumberTitle', 'off', ...
        'MenuBar', 'none', ...
        'Resize', 'on');
    
    data = [allFields', num2cell(false(numel(allFields), 1))];
    fieldTable = uitable('Parent', fig, ...
        'Position', [10, 50, 480, 310], ...
        'Data', data, ...
        'ColumnName', {'Field Name', 'Select'}, ...
        'ColumnEditable', [false, true], ...
        'ColumnWidth', {380, 80}, ...
        'ColumnFormat', {'char', 'logical'});
    
    selectAllBtn = uicontrol('Parent', fig, ...
        'Style', 'pushbutton', ...
        'Position', [10, 10, 120, 30], ...
        'String', 'Select All', ...
        'Callback', @(src,evt) selectAllCallback(fieldTable, allFields, true));
    
    deselectAllBtn = uicontrol('Parent', fig, ...
        'Style', 'pushbutton', ...
        'Position', [140, 10, 120, 30], ...
        'String', 'Deselect All', ...
        'Callback', @(src,evt) selectAllCallback(fieldTable, allFields, false));
    
    okBtn = uicontrol('Parent', fig, ...
        'Style', 'pushbutton', ...
        'Position', [350, 10, 70, 30], ...
        'String', 'OK', ...
        'Callback', @(src,evt) uiresume(fig));
    
    cancelBtn = uicontrol('Parent', fig, ...
        'Style', 'pushbutton', ...
        'Position', [430, 10, 60, 30], ...
        'String', 'Cancel', ...
        'Callback', @(src,evt) close(fig));
    
    uiwait(fig);
    
    if ishandle(fig)
        data = fieldTable.Data;
        selectedIndices = cellfun(@(x) islogical(x) && x, data(:, 2));
        selectedFields = allFields(selectedIndices);
        close(fig);
    end
end

function selectAllCallback(table, allFields, select)
    data = table.Data;
    for i = 1:numel(allFields)
        data{i, 2} = select;
    end
    table.Data = data;
end

function collectedData = collectDataFromFiles(metaPaths, fileIds, selectedFields)
    collectedData = struct();
    collectedData.fileIds = [];
    collectedData.fields = selectedFields;
    collectedData.values = {};
    
    totalFiles = numel(metaPaths);
    validFileIdx = 0;
    
    debugState('metadataAnalysis', 'Starting data collection from %d file(s)', totalFiles);
    
    for fileIdx = 1:totalFiles
        metaPath = metaPaths{fileIdx};
        fileId = fileIds(fileIdx);
        
        debugState('metadataAnalysis', 'Processing file %d/%d: %s', fileIdx, totalFiles, metaPath);
        
        if ~exist(metaPath, 'file')
            debugState('metadataAnalysis', 'File not found, skipping: %s', metaPath);
            continue
        end
        
        try
            meta = load(metaPath, '-mat');
        catch ME
            debugState('metadataAnalysis', 'Failed to load file, skipping: %s (%s)', metaPath, ME.message);
            continue
        end
        
        validFileIdx = validFileIdx + 1;
        collectedData.fileIds(end+1) = fileId;
        
        fileValues = cell(1, numel(selectedFields));
        for fieldIdx = 1:numel(selectedFields)
            fieldPath = selectedFields{fieldIdx};
            value = getFieldValue(meta, fieldPath);
            fileValues{fieldIdx} = value;
        end
        collectedData.values{validFileIdx} = fileValues;
        
        debugState('metadataAnalysis', 'File %d/%d processed successfully (valid: %d)', fileIdx, totalFiles, validFileIdx);
    end
    
    debugState('metadataAnalysis', 'Data collection completed: %d valid file(s) out of %d', validFileIdx, totalFiles);
end

function value = getFieldValue(structData, fieldPath)
    parts = strsplit(fieldPath, '.');
    value = structData;
    for i = 1:numel(parts)
        if isstruct(value) && isfield(value, parts{i})
            value = value.(parts{i});
        else
            value = [];
            return
        end
    end
end

function flatTable = createFlatTable(collectedData, selectedFields)
    if isempty(collectedData.fileIds)
        flatTable = [];
        return
    end
    
    numFiles = numel(collectedData.fileIds);
    numFields = numel(selectedFields);
    
    fieldInfo = cell(numFields, 1);
    globalMaxSize = 0;
    
    for fieldIdx = 1:numFields
        fieldMaxSize = 0;
        fieldIsMatrix = false;
        matrixDim = 0;
        fieldIsText = false;
        
        for fileIdx = 1:numFiles
            fileValues = collectedData.values{fileIdx};
            value = fileValues{fieldIdx};
            if isempty(value)
                continue
            end
            
            if ischar(value) || isstring(value) || iscellstr(value)
                fieldIsText = true;
            end
            
            dims = size(value);
            if isscalar(value)
                fieldMaxSize = max(fieldMaxSize, 1);
            elseif numel(dims) == 2
                if dims(1) == 1 || dims(2) == 1
                    fieldMaxSize = max(fieldMaxSize, max(dims));
                else
                    fieldMaxSize = max(fieldMaxSize, dims(2));
                    if ~fieldIsMatrix
                        fieldIsMatrix = true;
                        matrixDim = dims(1);
                    else
                        matrixDim = max(matrixDim, dims(1));
                    end
                end
            else
                fieldMaxSize = max(fieldMaxSize, numel(value));
            end
        end
        
        fieldInfo{fieldIdx} = struct('maxSize', fieldMaxSize, 'isMatrix', fieldIsMatrix, 'matrixDim', matrixDim, 'isText', fieldIsText);
        globalMaxSize = max(globalMaxSize, fieldMaxSize);
    end
    
    if globalMaxSize == 0
        flatTable = [];
        return
    end
    
    fileIdColumn = [];
    for fileIdx = 1:numFiles
        fileId = collectedData.fileIds(fileIdx);
        fileIdColumn = [fileIdColumn; repmat(fileId, globalMaxSize, 1)];
    end
    
    columnNames = {'File ID'};
    columnData = cell(0, 1);
    
    for fieldIdx = 1:numFields
        fieldName = selectedFields{fieldIdx};
        info = fieldInfo{fieldIdx};
        
        if info.isMatrix && info.matrixDim > 1
            for subIdx = 1:info.matrixDim
                subColumnName = sprintf('%s.%d', fieldName, subIdx);
                columnNames{end+1} = subColumnName;
                
                if info.isText
                    fieldColumn = cell(numel(fileIdColumn), 1);
                else
                    fieldColumn = nan(numel(fileIdColumn), 1);
                end
                
                rowIdx = 1;
                for fileIdx = 1:numFiles
                    fileValues = collectedData.values{fileIdx};
                    value = fileValues{fieldIdx};
                    
                    if isempty(value)
                        actualSize = 0;
                    else
                        dims = size(value);
                        if numel(dims) == 2 && dims(1) >= subIdx
                            actualSize = min(dims(2), globalMaxSize);
                            if actualSize > 0
                                if info.isText
                                    rowData = value(subIdx, 1:actualSize);
                                    if iscell(rowData)
                                        for vIdx = 1:actualSize
                                            fieldColumn{rowIdx + vIdx - 1} = char(rowData{vIdx});
                                        end
                                    else
                                        for vIdx = 1:actualSize
                                            fieldColumn{rowIdx + vIdx - 1} = num2str(rowData(vIdx));
                                        end
                                    end
                                else
                                    fieldColumn(rowIdx:rowIdx+actualSize-1) = value(subIdx, 1:actualSize)';
                                end
                            end
                        else
                            actualSize = 0;
                        end
                    end
                    
                    rowIdx = rowIdx + globalMaxSize;
                end
                
                columnData{end+1} = fieldColumn;
            end
        else
            columnNames{end+1} = fieldName;
            
            if info.isText
                fieldColumn = cell(numel(fileIdColumn), 1);
            else
                fieldColumn = nan(numel(fileIdColumn), 1);
            end
            
            rowIdx = 1;
            for fileIdx = 1:numFiles
                fileValues = collectedData.values{fileIdx};
                value = fileValues{fieldIdx};
                
                if isempty(value)
                    actualSize = 0;
                elseif isscalar(value)
                    actualSize = 1;
                    if info.isText
                        if ischar(value) || isstring(value)
                            fieldColumn{rowIdx} = char(value);
                        else
                            fieldColumn{rowIdx} = num2str(value);
                        end
                    else
                        fieldColumn(rowIdx) = value;
                    end
                else
                    dims = size(value);
                    if ischar(value) || isstring(value) || (iscell(value) && all(cellfun(@(x) ischar(x) || isstring(x), value(:))))
                        if ischar(value)
                            value = cellstr(value);
                        elseif isstring(value)
                            value = cellstr(value);
                        end
                        if iscell(value)
                            value = value(:);
                        end
                        actualSize = min(numel(value), globalMaxSize);
                        if actualSize > 0
                            for vIdx = 1:actualSize
                                fieldColumn{rowIdx + vIdx - 1} = char(value{vIdx});
                            end
                        end
                    else
                        value = value(:);
                        actualSize = min(numel(value), globalMaxSize);
                        if actualSize > 0
                            if info.isText
                                for vIdx = 1:actualSize
                                    fieldColumn{rowIdx + vIdx - 1} = num2str(value(vIdx));
                                end
                            else
                                fieldColumn(rowIdx:rowIdx+actualSize-1) = value(1:actualSize);
                            end
                        end
                    end
                end
                
                rowIdx = rowIdx + globalMaxSize;
            end
            
            columnData{end+1} = fieldColumn;
        end
    end
    
    totalRows = numel(fileIdColumn);
    
    for i = 1:numel(columnData)
        if numel(columnData{i}) ~= totalRows
            if numel(columnData{i}) < totalRows
                if iscell(columnData{i})
                    columnData{i} = [columnData{i}; cell(totalRows - numel(columnData{i}), 1)];
                else
                    columnData{i} = [columnData{i}; nan(totalRows - numel(columnData{i}), 1)];
                end
            else
                columnData{i} = columnData{i}(1:totalRows);
            end
        end
    end
    
    tableData = [{fileIdColumn}, columnData];
    flatTable = table(tableData{:}, 'VariableNames', columnNames);
end

function success = saveToMatDirect(metaPaths, fileIds, selectedFields, savePath)
    success = false;
    
    if isempty(metaPaths) || isempty(selectedFields)
        return
    end
    
    numFiles = numel(metaPaths);
    
    try
        debugState('metadataAnalysis', 'Analyzing field structure from all files');
        
        fieldInfo = cell(numel(selectedFields), 1);
        globalMaxSize = 0;
        
        for fileIdx = 1:numFiles
            metaPath = metaPaths{fileIdx};
            if ~exist(metaPath, 'file')
                continue
            end
            try
                meta = load(metaPath, '-mat');
            catch
                continue
            end
            
            for fieldIdx = 1:numel(selectedFields)
                fieldPath = selectedFields{fieldIdx};
                value = getFieldValue(meta, fieldPath);
                
                if isempty(value)
                    continue
                end
                
                if isempty(fieldInfo{fieldIdx})
                    fieldInfo{fieldIdx} = struct('isText', false, 'maxSize', 0);
                    if ischar(value) || isstring(value) || (iscell(value) && all(cellfun(@(x) ischar(x) || isstring(x), value(:))))
                        fieldInfo{fieldIdx}.isText = true;
                    end
                end
                
                if isscalar(value)
                    fieldInfo{fieldIdx}.maxSize = max(fieldInfo{fieldIdx}.maxSize, 1);
                else
                    flattenedSize = numel(value);
                    fieldInfo{fieldIdx}.maxSize = max(fieldInfo{fieldIdx}.maxSize, flattenedSize);
                end
                
                globalMaxSize = max(globalMaxSize, fieldInfo{fieldIdx}.maxSize);
            end
            clear meta;
        end
        
        for fieldIdx = 1:numel(selectedFields)
            if isempty(fieldInfo{fieldIdx})
                fieldInfo{fieldIdx} = struct('isText', false, 'maxSize', 0);
            end
        end
        
        if globalMaxSize == 0
            return
        end
        
        debugState('metadataAnalysis', 'Creating MAT file: %s (globalMaxSize: %d)', savePath, globalMaxSize);
        
        allTables = {};
        
        for fileIdx = 1:numFiles
            metaPath = metaPaths{fileIdx};
            fileId = fileIds(fileIdx);
            
            debugState('metadataAnalysis', 'Processing file %d/%d: %s', fileIdx, numFiles, metaPath);
            
            if ~exist(metaPath, 'file')
                debugState('metadataAnalysis', 'File not found, skipping: %s', metaPath);
                continue
            end
            
            try
                meta = load(metaPath, '-mat');
            catch ME
                debugState('metadataAnalysis', 'Failed to load file, skipping: %s (%s)', metaPath, ME.message);
                continue
            end
            
            fileData = struct();
            fileData.fileIds = [];
            fileData.values = {};
            fileData.fileIds(1) = fileId;
            
            fileValues = cell(1, numel(selectedFields));
            for fieldIdx = 1:numel(selectedFields)
                fieldPath = selectedFields{fieldIdx};
                value = getFieldValue(meta, fieldPath);
                fileValues{fieldIdx} = value;
            end
            fileData.values{1} = fileValues;
            
            batchTable = createFlatTableWithStructure(fileData, selectedFields, fieldInfo, globalMaxSize);
            clear meta fileData;
            
            if ~isempty(batchTable)
                allTables{end+1} = batchTable;
                clear batchTable;
                
                if numel(allTables) >= 5
                    debugState('metadataAnalysis', 'Combining %d tables to free memory', numel(allTables));
                    combined = allTables{1};
                    for i = 2:numel(allTables)
                        combined = vertcat(combined, allTables{i});
                    end
                    allTables = {combined};
                    clear combined;
                end
            end
        end
        
        if isempty(allTables)
            return
        end
        
        debugState('metadataAnalysis', 'Final combining and saving to MAT file');
        if numel(allTables) == 1
            flatTable = allTables{1};
        else
            flatTable = allTables{1};
            for i = 2:numel(allTables)
                flatTable = vertcat(flatTable, allTables{i});
            end
        end
        clear allTables;
        
        save(savePath, 'flatTable', '-v7.3');
        clear flatTable;
        success = true;
    catch ME
        debugState('metadataAnalysis', 'Failed to save MAT file: %s', ME.message);
    end
end

function flatTable = createFlatTableWithStructure(collectedData, selectedFields, fieldInfo, globalMaxSize)
    if isempty(collectedData.fileIds)
        flatTable = [];
        return
    end
    
    numFiles = numel(collectedData.fileIds);
    numFields = numel(selectedFields);
    
    debugState('metadataAnalysis', 'createFlatTableWithStructure: numFiles=%d, numFields=%d, globalMaxSize=%d', numFiles, numFields, globalMaxSize);
    
    fileIdColumn = [];
    for fileIdx = 1:numFiles
        fileId = collectedData.fileIds(fileIdx);
        fileIdColumn = [fileIdColumn; repmat(fileId, globalMaxSize, 1)];
    end
    
    debugState('metadataAnalysis', 'createFlatTableWithStructure: fileIdColumn size=%d', numel(fileIdColumn));
    
    columnNames = {'File ID'};
    columnData = cell(0, 1);
    
    for fieldIdx = 1:numFields
        fieldName = selectedFields{fieldIdx};
        info = fieldInfo{fieldIdx};
        axisColumnName = [fieldName, 'Axis'];
        
        debugState('metadataAnalysis', 'createFlatTableWithStructure: Processing field %d/%d: %s (isText=%d, maxSize=%d)', fieldIdx, numFields, fieldName, info.isText, info.maxSize);
        
        columnNames{end+1} = fieldName;
        columnNames{end+1} = axisColumnName;
        
        if info.isText
            fieldColumn = cell(numel(fileIdColumn), 1);
        else
            fieldColumn = nan(numel(fileIdColumn), 1);
        end
        axisColumn = nan(numel(fileIdColumn), 1);
        
        debugState('metadataAnalysis', 'createFlatTableWithStructure: Created columns for field %s, sizes: fieldColumn=%d, axisColumn=%d', fieldName, numel(fieldColumn), numel(axisColumn));
        
        rowIdx = 1;
        for fileIdx = 1:numFiles
            try
                fileValues = collectedData.values{fileIdx};
                value = fileValues{fieldIdx};
                
                debugState('metadataAnalysis', 'createFlatTableWithStructure: File %d/%d, field %s, rowIdx=%d, value empty=%d', fileIdx, numFiles, fieldName, rowIdx, isempty(value));
                
                if isempty(value)
                    actualSize = 0;
                    debugState('metadataAnalysis', 'createFlatTableWithStructure: Value is empty');
                elseif isscalar(value)
                    actualSize = globalMaxSize;
                    endIdx = min(rowIdx + actualSize - 1, numel(fieldColumn));
                    debugState('metadataAnalysis', 'createFlatTableWithStructure: Scalar value, actualSize=%d, endIdx=%d, fieldColumn size=%d', actualSize, endIdx, numel(fieldColumn));
                    
                    if rowIdx <= numel(fieldColumn)
                        if info.isText
                            if ischar(value) || isstring(value)
                                scalarValue = char(value);
                            else
                                scalarValue = num2str(value);
                            end
                            for vIdx = rowIdx:endIdx
                                if vIdx <= numel(fieldColumn)
                                    fieldColumn{vIdx} = scalarValue;
                                end
                            end
                        else
                            debugState('metadataAnalysis', 'createFlatTableWithStructure: Setting scalar numeric value, rowIdx=%d, endIdx=%d', rowIdx, endIdx);
                            fieldColumn(rowIdx:endIdx) = value;
                        end
                        debugState('metadataAnalysis', 'createFlatTableWithStructure: Setting axis column for scalar, rowIdx=%d, endIdx=%d, axisColumn size=%d', rowIdx, endIdx, numel(axisColumn));
                        axisColumn(rowIdx:endIdx) = 1;
                    else
                        debugState('metadataAnalysis', 'createFlatTableWithStructure: WARNING - rowIdx (%d) > fieldColumn size (%d)', rowIdx, numel(fieldColumn));
                    end
                else
                    dims = size(value);
                    
                    if info.isText
                        dimsChar = size(value);
                        if ischar(value)
                            if dimsChar(1) == 1 && dimsChar(2) > 1
                                flattened = {char(value)};
                                actualSize = 1;
                            else
                                flattened = cellstr(value);
                                flattened = flattened(:);
                                actualSize = min(numel(flattened), globalMaxSize);
                            end
                        elseif isstring(value)
                            flattened = cellstr(value);
                            flattened = flattened(:);
                            actualSize = min(numel(flattened), globalMaxSize);
                        else
                            flattened = value(:);
                            actualSize = min(numel(flattened), globalMaxSize);
                        end
                    else
                        flattened = value(:);
                        actualSize = min(numel(flattened), globalMaxSize);
                    end
                    
                    debugState('metadataAnalysis', 'createFlatTableWithStructure: Non-scalar value, dims=%s, flattened size=%d, actualSize=%d, rowIdx=%d, fieldColumn size=%d', mat2str(dims), numel(flattened), actualSize, rowIdx, numel(fieldColumn));
                    
                    if actualSize > 0 && rowIdx <= numel(fieldColumn)
                        endIdx = min(rowIdx + actualSize - 1, numel(fieldColumn));
                        debugState('metadataAnalysis', 'createFlatTableWithStructure: endIdx=%d', endIdx);
                        
                        if info.isText
                            debugState('metadataAnalysis', 'createFlatTableWithStructure: Text processing, dims=%s, flattened size=%d, actualSize=%d', mat2str(dimsChar), numel(flattened), actualSize);
                            numToCopy = min([actualSize, endIdx - rowIdx + 1, numel(flattened)]);
                            debugState('metadataAnalysis', 'createFlatTableWithStructure: numToCopy=%d, rowIdx=%d, endIdx=%d, fieldColumn size=%d', numToCopy, rowIdx, endIdx, numel(fieldColumn));
                            for vIdx = 1:numToCopy
                                if rowIdx + vIdx - 1 <= numel(fieldColumn) && vIdx <= numel(flattened)
                                    fieldColumn{rowIdx + vIdx - 1} = char(flattened{vIdx});
                                end
                            end
                        else
                            debugState('metadataAnalysis', 'createFlatTableWithStructure: Numeric processing, setting fieldColumn(rowIdx:endIdx), rowIdx=%d, endIdx=%d, flattened size=%d', rowIdx, endIdx, numel(flattened));
                            fieldColumn(rowIdx:endIdx) = flattened(1:min(actualSize, endIdx - rowIdx + 1));
                        end
                        
                        debugState('metadataAnalysis', 'createFlatTableWithStructure: Generating axis indices, dims=%s, actualSize=%d', mat2str(dims), actualSize);
                        axisIndices = generateAxisIndices(dims, actualSize);
                        debugState('metadataAnalysis', 'createFlatTableWithStructure: Generated axis indices, size=%d, setting axisColumn(rowIdx:endIdx), rowIdx=%d, endIdx=%d, axisColumn size=%d', numel(axisIndices), rowIdx, endIdx, numel(axisColumn));
                        axisColumn(rowIdx:endIdx) = axisIndices(1:min(actualSize, endIdx - rowIdx + 1));
                    else
                        debugState('metadataAnalysis', 'createFlatTableWithStructure: Skipping - actualSize=%d or rowIdx (%d) > fieldColumn size (%d)', actualSize, rowIdx, numel(fieldColumn));
                    end
                end
            catch ME
                debugState('metadataAnalysis', 'createFlatTableWithStructure: ERROR at file %d/%d, field %s, rowIdx=%d: %s', fileIdx, numFiles, fieldName, rowIdx, ME.message);
                debugState('metadataAnalysis', 'createFlatTableWithStructure: Stack trace: %s', getReport(ME));
                rethrow(ME);
            end
            
            rowIdx = rowIdx + globalMaxSize;
        end
        
        columnData{end+1} = fieldColumn;
        columnData{end+1} = axisColumn;
    end
    
    totalRows = numel(fileIdColumn);
    
    for i = 1:numel(columnData)
        if numel(columnData{i}) ~= totalRows
            if numel(columnData{i}) < totalRows
                if iscell(columnData{i})
                    columnData{i} = [columnData{i}; cell(totalRows - numel(columnData{i}), 1)];
                else
                    columnData{i} = [columnData{i}; nan(totalRows - numel(columnData{i}), 1)];
                end
            else
                columnData{i} = columnData{i}(1:totalRows);
            end
        end
    end
    
    tableData = [{fileIdColumn}, columnData];
    flatTable = table(tableData{:}, 'VariableNames', columnNames);
end

function indices = generateAxisIndices(dims, numElements)
    debugState('metadataAnalysis', 'generateAxisIndices: dims=%s, numElements=%d', mat2str(dims), numElements);
    
    if numel(dims) == 2 && dims(1) > 1 && dims(2) > 1
        debugState('metadataAnalysis', 'generateAxisIndices: Matrix case, dims(1)=%d, dims(2)=%d', dims(1), dims(2));
        indices = zeros(numElements, 1);
        idx = 1;
        for col = 1:dims(2)
            for row = 1:dims(1)
                if idx <= numElements
                    indices(idx) = col;
                    idx = idx + 1;
                else
                    debugState('metadataAnalysis', 'generateAxisIndices: WARNING - idx (%d) > numElements (%d)', idx, numElements);
                    break
                end
            end
            if idx > numElements
                break
            end
        end
        debugState('metadataAnalysis', 'generateAxisIndices: Generated %d indices', numel(indices));
    else
        debugState('metadataAnalysis', 'generateAxisIndices: Vector/scalar case, creating ones');
        indices = ones(numElements, 1);
        debugState('metadataAnalysis', 'generateAxisIndices: Generated %d indices', numel(indices));
    end
end
