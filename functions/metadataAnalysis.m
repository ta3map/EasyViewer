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
    
    savePath = chooseSavePath();
    if isempty(savePath)
        debugState('metadataAnalysis', 'Save cancelled by user');
        return
    end
    
    debugState('metadataAnalysis', 'Save path selected: %s', savePath);
    
    [~, ~, ext] = fileparts(savePath);
    if strcmpi(ext, '.h5') || strcmpi(ext, '.hdf5')
        debugState('metadataAnalysis', 'Saving directly to HDF5 file (streaming)');
        success = saveToHDF5Direct(metaPaths, fileIds, selectedFields, savePath);
    elseif strcmpi(ext, '.mat')
        debugState('metadataAnalysis', 'Saving directly to MAT file (streaming)');
        success = saveToMatDirect(metaPaths, fileIds, selectedFields, savePath);
    else
        collectedData = collectDataFromFiles(metaPaths, fileIds, selectedFields);
        if isempty(collectedData)
            debugState('metadataAnalysis', 'No data collected from files');
            msgbox('No data collected from files', 'Error', 'error');
            return
        end
        
        debugState('metadataAnalysis', 'Collected data from %d file(s)', numel(collectedData.fileIds));
        
        debugState('metadataAnalysis', 'Creating and saving table directly to file');
        success = createAndSaveTable(collectedData, selectedFields, savePath);
    end
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

function savePath = chooseSavePath()
    choice = questdlg('Select save format:', 'Save Metadata Analysis', 'HDF5 File', 'MAT File', 'Excel File', 'HDF5 File');
    
    if strcmp(choice, 'Cancel')
        savePath = '';
        return
    end
    
    if strcmp(choice, 'HDF5 File')
        [file, path] = uiputfile({'*.h5', 'HDF5 Files (*.h5)'; '*.hdf5', 'HDF5 Files (*.hdf5)'}, ...
            'Save Metadata Analysis', 'metadata_analysis.h5');
    elseif strcmp(choice, 'MAT File')
        [file, path] = uiputfile('*.mat', 'Save Metadata Analysis', 'metadata_analysis.mat');
    else
        [file, path] = uiputfile({'*.xlsx', 'Excel Files (*.xlsx)'; '*.xls', 'Excel Files (*.xls)'}, ...
            'Save Metadata Analysis', 'metadata_analysis.xlsx');
    end
    
    if isequal(file, 0)
        savePath = '';
        return
    end
    
    savePath = fullfile(path, file);
end

function success = saveToHDF5Direct(metaPaths, fileIds, selectedFields, savePath)
    success = false;
    
    if isempty(metaPaths) || isempty(selectedFields)
        return
    end
    
    numFiles = numel(metaPaths);
    
    try
        if exist(savePath, 'file')
            delete(savePath);
        end
        
        debugState('metadataAnalysis', 'Creating HDF5 file: %s', savePath);
        
        datasetsCreated = false;
        fieldInfo = cell(numel(selectedFields), 1);
        totalRows = 0;
        
        h5create(savePath, '/FileID', [Inf], 'ChunkSize', [1000]);
        
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
            
            fileRows = 0;
            fileData = cell(numel(selectedFields), 1);
            
            for fieldIdx = 1:numel(selectedFields)
                fieldPath = selectedFields{fieldIdx};
                value = getFieldValue(meta, fieldPath);
                
                if isempty(value)
                    continue
                end
                
                dims = size(value);
                if isscalar(value)
                    rows = 1;
                elseif numel(dims) == 2
                    if dims(1) == 1 || dims(2) == 1
                        rows = max(dims);
                    else
                        rows = dims(2);
                    end
                else
                    rows = numel(value);
                end
                
                fileRows = max(fileRows, rows);
                
                if isempty(fieldInfo{fieldIdx})
                    fieldInfo{fieldIdx} = struct('isText', false, 'isMatrix', false, 'matrixDim', 0);
                    if ischar(value) || isstring(value) || (iscell(value) && all(cellfun(@(x) ischar(x) || isstring(x), value(:))))
                        fieldInfo{fieldIdx}.isText = true;
                    end
                    if numel(dims) == 2 && dims(1) > 1 && dims(2) > 1
                        fieldInfo{fieldIdx}.isMatrix = true;
                        fieldInfo{fieldIdx}.matrixDim = dims(1);
                    end
                end
                
                fileData{fieldIdx} = value;
            end
            
            if fileRows == 0
                clear meta;
                continue
            end
            
            if ~datasetsCreated
                for fieldIdx = 1:numel(selectedFields)
                    info = fieldInfo{fieldIdx};
                    fieldName = selectedFields{fieldIdx};
                    safeName = strrep(fieldName, '.', '_');
                    
                    if info.isMatrix && info.matrixDim > 1
                        for subIdx = 1:info.matrixDim
                            datasetPath = sprintf('/%s_%d', safeName, subIdx);
                            if info.isText
                                h5create(savePath, datasetPath, [Inf], 'Datatype', 'string', 'ChunkSize', [1000]);
                            else
                                h5create(savePath, datasetPath, [Inf], 'ChunkSize', [1000]);
                            end
                        end
                    else
                        datasetPath = sprintf('/%s', safeName);
                        if info.isText
                            h5create(savePath, datasetPath, [Inf], 'Datatype', 'string', 'ChunkSize', [1000]);
                        else
                            h5create(savePath, datasetPath, [Inf], 'ChunkSize', [1000]);
                        end
                    end
                end
                datasetsCreated = true;
            end
            
            h5write(savePath, '/FileID', repmat(fileId, fileRows, 1), [totalRows + 1], [fileRows]);
            
            for fieldIdx = 1:numel(selectedFields)
                value = fileData{fieldIdx};
                info = fieldInfo{fieldIdx};
                fieldName = selectedFields{fieldIdx};
                safeName = strrep(fieldName, '.', '_');
                
                if isempty(value)
                    continue
                end
                
                if info.isMatrix && info.matrixDim > 1
                    for subIdx = 1:info.matrixDim
                        datasetPath = sprintf('/%s_%d', safeName, subIdx);
                        dims = size(value);
                        if numel(dims) == 2 && dims(1) >= subIdx
                            rowData = value(subIdx, 1:min(dims(2), fileRows))';
                            if info.isText
                                if iscell(rowData)
                                    rowData = string(rowData);
                                else
                                    rowData = string(rowData);
                                end
                            end
                            h5write(savePath, datasetPath, rowData, [totalRows + 1], [numel(rowData)]);
                        end
                    end
                else
                    datasetPath = sprintf('/%s', safeName);
                    
                    if isscalar(value)
                        rowData = value;
                        if info.isText
                            if ischar(value) || isstring(value)
                                rowData = string(value);
                            else
                                rowData = string(num2str(value));
                            end
                        end
                        h5write(savePath, datasetPath, rowData, [totalRows + 1], [1]);
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
                            rowData = string(value(1:min(numel(value), fileRows)));
                        else
                            value = value(:);
                            rowData = value(1:min(numel(value), fileRows));
                            if info.isText
                                rowData = string(num2str(rowData));
                            end
                        end
                        h5write(savePath, datasetPath, rowData, [totalRows + 1], [numel(rowData)]);
                    end
                end
            end
            
            totalRows = totalRows + fileRows;
            clear meta fileData;
        end
        
        if totalRows > 0
            h5writeatt(savePath, '/', 'numRows', int64(totalRows));
            h5writeatt(savePath, '/', 'numFields', int64(numel(selectedFields)));
            for i = 1:numel(selectedFields)
                h5writeatt(savePath, '/', sprintf('field_%d', i), selectedFields{i});
            end
            success = true;
            debugState('metadataAnalysis', 'Successfully saved %d rows to HDF5 file', totalRows);
        end
    catch ME
        debugState('metadataAnalysis', 'Failed to save HDF5 file: %s', ME.message);
    end
end

function success = createAndSaveTable(collectedData, selectedFields, savePath)
    success = false;
    
    [~, ~, ext] = fileparts(savePath);
    success = saveToExcelStreaming(collectedData, selectedFields, savePath);
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
                    dims = size(value);
                    fieldInfo{fieldIdx} = struct('isText', false, 'isMatrix', false, 'matrixDim', 0, 'maxSize', 0);
                    if ischar(value) || isstring(value) || (iscell(value) && all(cellfun(@(x) ischar(x) || isstring(x), value(:))))
                        fieldInfo{fieldIdx}.isText = true;
                    end
                    if numel(dims) == 2 && dims(1) > 1 && dims(2) > 1
                        fieldInfo{fieldIdx}.isMatrix = true;
                        fieldInfo{fieldIdx}.matrixDim = dims(1);
                    end
                end
                
                dims = size(value);
                if isscalar(value)
                    fieldInfo{fieldIdx}.maxSize = max(fieldInfo{fieldIdx}.maxSize, 1);
                elseif numel(dims) == 2
                    if dims(1) == 1 || dims(2) == 1
                        fieldInfo{fieldIdx}.maxSize = max(fieldInfo{fieldIdx}.maxSize, max(dims));
                    else
                        fieldInfo{fieldIdx}.maxSize = max(fieldInfo{fieldIdx}.maxSize, dims(2));
                        fieldInfo{fieldIdx}.matrixDim = max(fieldInfo{fieldIdx}.matrixDim, dims(1));
                    end
                else
                    fieldInfo{fieldIdx}.maxSize = max(fieldInfo{fieldIdx}.maxSize, numel(value));
                end
                
                globalMaxSize = max(globalMaxSize, fieldInfo{fieldIdx}.maxSize);
            end
            clear meta;
        end
        
        for fieldIdx = 1:numel(selectedFields)
            if isempty(fieldInfo{fieldIdx})
                fieldInfo{fieldIdx} = struct('isText', false, 'isMatrix', false, 'matrixDim', 0, 'maxSize', 0);
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
                    if rowIdx <= numel(fieldColumn)
                        if info.isText
                            if ischar(value) || isstring(value)
                                fieldColumn{rowIdx} = char(value);
                            else
                                fieldColumn{rowIdx} = num2str(value);
                            end
                        else
                            fieldColumn(rowIdx) = value;
                        end
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
                        if actualSize > 0 && rowIdx <= numel(fieldColumn)
                            endIdx = min(rowIdx + actualSize - 1, numel(fieldColumn));
                            for vIdx = 1:min(actualSize, endIdx - rowIdx + 1)
                                if rowIdx + vIdx - 1 <= numel(fieldColumn)
                                    fieldColumn{rowIdx + vIdx - 1} = char(value{vIdx});
                                end
                            end
                        end
                    else
                        value = value(:);
                        actualSize = min(numel(value), globalMaxSize);
                        if actualSize > 0 && rowIdx <= numel(fieldColumn)
                            endIdx = min(rowIdx + actualSize - 1, numel(fieldColumn));
                            if info.isText
                                for vIdx = 1:min(actualSize, endIdx - rowIdx + 1)
                                    if rowIdx + vIdx - 1 <= numel(fieldColumn)
                                        fieldColumn{rowIdx + vIdx - 1} = num2str(value(vIdx));
                                    end
                                end
                            else
                                fieldColumn(rowIdx:endIdx) = value(1:min(actualSize, endIdx - rowIdx + 1));
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


function success = saveToExcelStreaming(collectedData, selectedFields, savePath)
    success = false;
    
    if isempty(collectedData.fileIds)
        return
    end
    
    numFiles = numel(collectedData.fileIds);
    numFields = numel(selectedFields);
    
    debugState('metadataAnalysis', 'Analyzing field sizes');
    fieldInfo = analyzeFieldSizes(collectedData, selectedFields, numFiles, numFields);
    globalMaxSize = getGlobalMaxSize(fieldInfo);
    
    if globalMaxSize == 0
        return
    end
    
    debugState('metadataAnalysis', 'Global max size: %d, files: %d', globalMaxSize, numFiles);
    
    try
        maxRowsPerBatch = 10000;
        maxRowsPerSheet = 1048576;
        
        totalRows = numFiles * globalMaxSize;
        numSheets = ceil(totalRows / maxRowsPerSheet);
        
        debugState('metadataAnalysis', 'Total rows: %d, will create %d sheet(s)', totalRows, numSheets);
        
        for sheetIdx = 1:numSheets
            sheetStartRow = (sheetIdx - 1) * maxRowsPerSheet + 1;
            sheetEndRow = min(sheetIdx * maxRowsPerSheet, totalRows);
            sheetName = sprintf('Sheet%d', sheetIdx);
            
            debugState('metadataAnalysis', 'Creating sheet %d/%d: rows %d-%d', sheetIdx, numSheets, sheetStartRow, sheetEndRow);
            
            fileStartIdx = ceil(sheetStartRow / globalMaxSize);
            fileEndIdx = min(ceil(sheetEndRow / globalMaxSize), numFiles);
            
            sheetTable = createTableBatch(collectedData, selectedFields, fieldInfo, globalMaxSize, ...
                fileStartIdx, fileEndIdx, sheetStartRow, sheetEndRow);
            
            if ~isempty(sheetTable)
                writetable(sheetTable, savePath, 'Sheet', sheetName);
                clear sheetTable;
            end
        end
        
        success = true;
    catch ME
        debugState('metadataAnalysis', 'Failed to save Excel file: %s', ME.message);
    end
end

function fieldInfo = analyzeFieldSizes(collectedData, selectedFields, numFiles, numFields)
    fieldInfo = cell(numFields, 1);
    
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
        
        fieldInfo{fieldIdx} = struct('maxSize', fieldMaxSize, 'isMatrix', fieldIsMatrix, ...
            'matrixDim', matrixDim, 'isText', fieldIsText);
    end
end

function globalMaxSize = getGlobalMaxSize(fieldInfo)
    globalMaxSize = 0;
    for i = 1:numel(fieldInfo)
        globalMaxSize = max(globalMaxSize, fieldInfo{i}.maxSize);
    end
end

function batchTable = createTableBatch(collectedData, selectedFields, fieldInfo, globalMaxSize, ...
    fileStartIdx, fileEndIdx, sheetStartRow, sheetEndRow)
    
    numFiles = fileEndIdx - fileStartIdx + 1;
    numFields = numel(selectedFields);
    
    fileIdColumn = [];
    for fileIdx = fileStartIdx:fileEndIdx
        fileId = collectedData.fileIds(fileIdx);
        fileIdColumn = [fileIdColumn; repmat(fileId, globalMaxSize, 1)];
    end
    
    batchStartRow = (fileStartIdx - 1) * globalMaxSize + 1;
    batchEndRow = fileEndIdx * globalMaxSize;
    
    actualStartRow = max(1, sheetStartRow - batchStartRow + 1);
    actualEndRow = min(numel(fileIdColumn), sheetEndRow - batchStartRow + 1);
    
    if actualStartRow > actualEndRow || actualStartRow > numel(fileIdColumn)
        batchTable = [];
        return
    end
    
    fileIdColumn = fileIdColumn(actualStartRow:actualEndRow);
    
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
                for fileIdx = fileStartIdx:fileEndIdx
                    fileValues = collectedData.values{fileIdx};
                    value = fileValues{fieldIdx};
                    
                    if isempty(value)
                        actualSize = 0;
                    else
                        dims = size(value);
                        if numel(dims) == 2 && dims(1) >= subIdx
                            actualSize = min(dims(2), globalMaxSize);
                            if actualSize > 0 && rowIdx <= numel(fieldColumn)
                                endIdx = min(rowIdx + actualSize - 1, numel(fieldColumn));
                                if info.isText
                                    rowData = value(subIdx, 1:min(actualSize, endIdx - rowIdx + 1));
                                    if iscell(rowData)
                                        for vIdx = 1:min(actualSize, endIdx - rowIdx + 1)
                                            if rowIdx + vIdx - 1 <= numel(fieldColumn)
                                                fieldColumn{rowIdx + vIdx - 1} = char(rowData{vIdx});
                                            end
                                        end
                                    else
                                        for vIdx = 1:min(actualSize, endIdx - rowIdx + 1)
                                            if rowIdx + vIdx - 1 <= numel(fieldColumn)
                                                fieldColumn{rowIdx + vIdx - 1} = num2str(rowData(vIdx));
                                            end
                                        end
                                    end
                                else
                                    fieldColumn(rowIdx:endIdx) = value(subIdx, 1:min(actualSize, endIdx - rowIdx + 1))';
                                end
                            end
                        else
                            actualSize = 0;
                        end
                    end
                    
                    rowIdx = rowIdx + globalMaxSize;
                    if rowIdx > numel(fieldColumn)
                        break
                    end
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
            for fileIdx = fileStartIdx:fileEndIdx
                fileValues = collectedData.values{fileIdx};
                value = fileValues{fieldIdx};
                
                if isempty(value)
                    actualSize = 0;
                elseif isscalar(value)
                    actualSize = 1;
                    if rowIdx <= numel(fieldColumn)
                        if info.isText
                            if ischar(value) || isstring(value)
                                fieldColumn{rowIdx} = char(value);
                            else
                                fieldColumn{rowIdx} = num2str(value);
                            end
                        else
                            fieldColumn(rowIdx) = value;
                        end
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
                        if actualSize > 0 && rowIdx <= numel(fieldColumn)
                            endIdx = min(rowIdx + actualSize - 1, numel(fieldColumn));
                            for vIdx = 1:min(actualSize, endIdx - rowIdx + 1)
                                if rowIdx + vIdx - 1 <= numel(fieldColumn)
                                    fieldColumn{rowIdx + vIdx - 1} = char(value{vIdx});
                                end
                            end
                        end
                    else
                        value = value(:);
                        actualSize = min(numel(value), globalMaxSize);
                        if actualSize > 0 && rowIdx <= numel(fieldColumn)
                            endIdx = min(rowIdx + actualSize - 1, numel(fieldColumn));
                            if info.isText
                                for vIdx = 1:min(actualSize, endIdx - rowIdx + 1)
                                    if rowIdx + vIdx - 1 <= numel(fieldColumn)
                                        fieldColumn{rowIdx + vIdx - 1} = num2str(value(vIdx));
                                    end
                                end
                            else
                                fieldColumn(rowIdx:endIdx) = value(1:min(actualSize, endIdx - rowIdx + 1));
                            end
                        end
                    end
                end
                
                rowIdx = rowIdx + globalMaxSize;
                if rowIdx > numel(fieldColumn)
                    break
                end
            end
            
            columnData{end+1} = fieldColumn;
        end
    end
    
    tableData = [{fileIdColumn}, columnData];
    batchTable = table(tableData{:}, 'VariableNames', columnNames);
end
