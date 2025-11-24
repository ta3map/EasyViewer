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
    
    collectedData = collectDataFromFiles(metaPaths, fileIds, selectedFields);
    if isempty(collectedData)
        debugState('metadataAnalysis', 'No data collected from files');
        msgbox('No data collected from files', 'Error', 'error');
        return
    end
    
    debugState('metadataAnalysis', 'Collected data from %d file(s)', numel(collectedData.fileIds));
    
    debugState('metadataAnalysis', 'Creating flat table');
    flatTable = createFlatTable(collectedData, selectedFields);
    if isempty(flatTable)
        debugState('metadataAnalysis', 'Failed to create flat table');
        msgbox('Failed to create flat table', 'Error', 'error');
        return
    end
    
    [numRows, numCols] = size(flatTable);
    debugState('metadataAnalysis', 'Flat table created: %d rows x %d columns', numRows, numCols);
    
    saveData(flatTable);
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
        
        for fileIdx = 1:numFiles
            fileValues = collectedData.values{fileIdx};
            value = fileValues{fieldIdx};
            if isempty(value)
                continue
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
        
        fieldInfo{fieldIdx} = struct('maxSize', fieldMaxSize, 'isMatrix', fieldIsMatrix, 'matrixDim', matrixDim);
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
                fieldColumn = nan(numel(fileIdColumn), 1);
                
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
                                fieldColumn(rowIdx:rowIdx+actualSize-1) = value(subIdx, 1:actualSize)';
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
            fieldColumn = nan(numel(fileIdColumn), 1);
            
            rowIdx = 1;
            for fileIdx = 1:numFiles
                fileValues = collectedData.values{fileIdx};
                value = fileValues{fieldIdx};
                
                if isempty(value)
                    actualSize = 0;
                elseif isscalar(value)
                    actualSize = 1;
                    fieldColumn(rowIdx) = value;
                else
                    dims = size(value);
                    value = value(:);
                    actualSize = min(numel(value), globalMaxSize);
                    if actualSize > 0
                        fieldColumn(rowIdx:rowIdx+actualSize-1) = value(1:actualSize);
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
                columnData{i} = [columnData{i}; nan(totalRows - numel(columnData{i}), 1)];
            else
                columnData{i} = columnData{i}(1:totalRows);
            end
        end
    end
    
    tableData = [{fileIdColumn}, columnData];
    flatTable = table(tableData{:}, 'VariableNames', columnNames);
end

function saveData(flatTable)
    [numRows, numCols] = size(flatTable);
    
    choice = questdlg(sprintf('Table size: %d rows x %d columns\n\nSelect save format:', numRows, numCols), ...
        'Save Metadata Analysis', 'MAT File', 'Excel File', 'Cancel', 'Excel File');
    
    if strcmp(choice, 'Cancel')
        debugState('metadataAnalysis', 'Save cancelled by user');
        return
    end
    
    if strcmp(choice, 'MAT File')
        saveToMat(flatTable);
    else
        saveToExcel(flatTable);
    end
end

function saveToMat(flatTable)
    [file, path] = uiputfile('*.mat', 'Save Metadata Analysis', 'metadata_analysis.mat');
    if isequal(file, 0)
        debugState('metadataAnalysis', 'Save cancelled by user');
        return
    end
    
    fullPath = fullfile(path, file);
    debugState('metadataAnalysis', 'Saving to MAT file: %s', fullPath);
    
    try
        save(fullPath, 'flatTable', '-v7.3');
        debugState('metadataAnalysis', 'Successfully saved to MAT file: %s', fullPath);
        msgbox(sprintf('Data saved to %s', fullPath), 'Success', 'help');
    catch ME
        debugState('metadataAnalysis', 'Failed to save MAT file: %s', ME.message);
        msgbox(sprintf('Failed to save file: %s', ME.message), 'Error', 'error');
    end
end

function saveToExcel(flatTable)
    [file, path] = uiputfile({'*.xlsx', 'Excel Files (*.xlsx)'; '*.xls', 'Excel Files (*.xls)'}, ...
        'Save Metadata Analysis', 'metadata_analysis.xlsx');
    if isequal(file, 0)
        debugState('metadataAnalysis', 'Save cancelled by user');
        return
    end
    
    fullPath = fullfile(path, file);
    [numRows, numCols] = size(flatTable);
    
    debugState('metadataAnalysis', 'Saving to Excel file: %s (%d rows x %d columns)', fullPath, numRows, numCols);
    
    maxRowsPerSheet = 1048576;
    
    try
        if numRows <= maxRowsPerSheet
            debugState('metadataAnalysis', 'Saving entire table in one sheet');
            writetable(flatTable, fullPath);
            debugState('metadataAnalysis', 'Successfully saved to Excel file: %s', fullPath);
            msgbox(sprintf('Data saved to %s', fullPath), 'Success', 'help');
        else
            debugState('metadataAnalysis', 'Table too large (%d rows), saving in parts', numRows);
            numSheets = ceil(numRows / maxRowsPerSheet);
            
            for sheetIdx = 1:numSheets
                startRow = (sheetIdx - 1) * maxRowsPerSheet + 1;
                endRow = min(sheetIdx * maxRowsPerSheet, numRows);
                
                debugState('metadataAnalysis', 'Saving sheet %d/%d: rows %d-%d', sheetIdx, numSheets, startRow, endRow);
                
                sheetTable = flatTable(startRow:endRow, :);
                sheetName = sprintf('Sheet%d', sheetIdx);
                
                writetable(sheetTable, fullPath, 'Sheet', sheetName);
            end
            
            debugState('metadataAnalysis', 'Successfully saved to Excel file with %d sheet(s): %s', numSheets, fullPath);
            msgbox(sprintf('Data saved to %s (%d sheets)', fullPath, numSheets), 'Success', 'help');
        end
    catch ME
        debugState('metadataAnalysis', 'Failed to save Excel file: %s', ME.message);
        msgbox(sprintf('Failed to save file: %s', ME.message), 'Error', 'error');
    end
end
