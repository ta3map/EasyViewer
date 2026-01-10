function metadataAnalysis(metaPaths, fileIds, fileTableData, fileTableColumns)
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
        handleMetadataError(ME, 'Failed to load first .meta file', true);
        return
    end
    
    debugState('metadataAnalysis', 'Extracting all fields from metadata structure');
    allFields = extractAllFields(firstMeta);
    if isempty(allFields)
        debugState('metadataAnalysis', 'No fields found in metadata structure');
        msgbox('No fields found in metadata structure', 'Error', 'error');
        return
    end
    
    % Sort fields for better readability (parent fields first, then subfields)
    allFields = sort(allFields);
    
    % Add SQL fields if fileTableData provided
    if nargin >= 3 && ~isempty(fileTableData) && nargin >= 4 && ~isempty(fileTableColumns)
        sqlFields = {};
        if numel(fileTableColumns) > 3
            for i = 4:numel(fileTableColumns)
                sqlFields{end+1} = fileTableColumns{i};
            end
        end
        allFields = [allFields, sqlFields];
        debugState('metadataAnalysis', 'Added %d SQL fields from file table', numel(sqlFields));
    end
    
    debugState('metadataAnalysis', 'Found %d metadata fields', numel(allFields));
    
    if nargin >= 4 && ~isempty(fileTableColumns)
        selectionResult = showFieldSelectionDialog(allFields, fileTableColumns);
    else
        selectionResult = showFieldSelectionDialog(allFields, {});
    end
    if isempty(selectionResult) || isempty(selectionResult.fields)
        debugState('metadataAnalysis', 'No fields selected, cancelling');
        return
    end
    
    selectedFields = selectionResult.fields;
    sqlFormats = selectionResult.sqlFormats;
    
    debugState('metadataAnalysis', 'Selected %d field(s) for analysis', numel(selectedFields));
    
    [file, path] = uiputfile('*.mat', 'Save Metadata Analysis', 'metadata_analysis.mat');
    if isequal(file, 0)
        debugState('metadataAnalysis', 'Save cancelled by user');
        return
    end
    
    savePath = fullfile(path, file);
    debugState('metadataAnalysis', 'Save path selected: %s', savePath);
    
    debugState('metadataAnalysis', 'Saving directly to MAT file (streaming)');
    if nargin >= 3 && ~isempty(fileTableData) && nargin >= 4 && ~isempty(fileTableColumns)
        [success, errorInfo] = saveToMatDirect(metaPaths, fileIds, selectedFields, savePath, fileTableData, fileTableColumns, sqlFormats);
    else
        [success, errorInfo] = saveToMatDirect(metaPaths, fileIds, selectedFields, savePath, [], [], sqlFormats);
    end
    if ~success
        if ~isempty(errorInfo)
            handleMetadataError(errorInfo, 'Failed to create and save table', true);
        else
            fprintf('ERROR in metadataAnalysis: Failed to create and save table\n');
            fprintf('Check debug logs for details\n');
            msgbox('Failed to create and save table', 'Error', 'error');
        end
        return
    end
    
    debugState('metadataAnalysis', 'Table successfully saved to: %s', savePath);
    
    % Offer to view results
    choice = questdlg(sprintf('Data saved to:\n%s\n\nHow would you like to view the results?', savePath), ...
        'View Results', 'Plot', 'Cancel', 'Cancel');
    
    switch choice
        case 'Plot'
            plotFromTableGUI(savePath);
        case 'Cancel'
            % Do nothing
    end
end


function fields = extractAllFields(structData)
    fields = {};
    fieldNames = fieldnames(structData);
    maxDepth = 3;
    currentDepth = 0;
    withParent = true;
    for i = 1:numel(fieldNames)
        fieldName = fieldNames{i};
        fields = extractFieldsRecursive(structData.(fieldName), fieldName, fields, maxDepth, currentDepth, withParent);
    end
end

function fields = extractFieldsRecursive(value, prefix, fields, maxDepth, currentDepth, withParent)
    if nargin < 4
        maxDepth = 3;
    end
    if nargin < 5
        currentDepth = 0;
    end
    if nargin < 6
        withParent = true;
    end
    
    if currentDepth >= maxDepth
        fields{end+1} = prefix;
        return
    end
    
    if isstruct(value)
        if withParent
            fields{end+1} = prefix;
        end
        
        if numel(value) == 1
            fieldNames = fieldnames(value);
            for i = 1:numel(fieldNames)
                subFieldName = fieldNames{i};
                newPrefix = sprintf('%s.%s', prefix, subFieldName);
                fields = extractFieldsRecursive(value.(subFieldName), newPrefix, fields, maxDepth, currentDepth + 1, withParent);
            end
        else
            fieldNames = fieldnames(value(1));
            for i = 1:numel(fieldNames)
                subFieldName = fieldNames{i};
                newPrefix = sprintf('%s.%s', prefix, subFieldName);
                fields = extractFieldsRecursive(value(1).(subFieldName), newPrefix, fields, maxDepth, currentDepth + 1, withParent);
            end
        end
    elseif iscell(value) && numel(value) > 0 && isstruct(value{1})
        if withParent
            fields{end+1} = prefix;
        end
        
        if numel(value) == 1
            fieldNames = fieldnames(value{1});
            for i = 1:numel(fieldNames)
                subFieldName = fieldNames{i};
                newPrefix = sprintf('%s.%s', prefix, subFieldName);
                fields = extractFieldsRecursive(value{1}.(subFieldName), newPrefix, fields, maxDepth, currentDepth + 1, withParent);
            end
        else
            fieldNames = fieldnames(value{1});
            for i = 1:numel(fieldNames)
                subFieldName = fieldNames{i};
                newPrefix = sprintf('%s.%s', prefix, subFieldName);
                fields = extractFieldsRecursive(value{1}.(subFieldName), newPrefix, fields, maxDepth, currentDepth + 1, withParent);
            end
        end
    else
        fields{end+1} = prefix;
    end
end

function result = showFieldSelectionDialog(allFields, fileTableColumns)
    result = struct('fields', {}, 'sqlFormats', containers.Map());
    
    fig = figure('Position', [300, 300, 600, 400], ...
        'Name', 'Select Metadata Fields', ...
        'NumberTitle', 'off', ...
        'MenuBar', 'none', ...
        'Resize', 'on');
    
    numFields = numel(allFields);
    formatColumn = cell(numFields, 1);
    isSqlField = false(numFields, 1);
    
    for i = 1:numFields
        if numel(fileTableColumns) > 3
            isSqlField(i) = any(strcmp(allFields{i}, fileTableColumns(4:end)));
        end
        if isSqlField(i)
            formatColumn{i} = 'Text';
        else
            formatColumn{i} = '';
        end
    end
    
    data = [allFields', num2cell(false(numFields, 1)), formatColumn];
    
    columnEditable = [false, true, true];
    
    columnFormat = {'char', 'logical', {'Text', 'Number', 'Logical', 'Date', 'DateTime'}};
    
    fieldTable = uitable('Parent', fig, ...
        'Position', [10, 50, 580, 310], ...
        'Data', data, ...
        'ColumnName', {'Field Name', 'Select', 'Format'}, ...
        'ColumnEditable', columnEditable, ...
        'ColumnWidth', {300, 80, 150}, ...
        'ColumnFormat', columnFormat);
    
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
        'Position', [450, 10, 70, 30], ...
        'String', 'OK', ...
        'Callback', @(src,evt) uiresume(fig));
    
    cancelBtn = uicontrol('Parent', fig, ...
        'Style', 'pushbutton', ...
        'Position', [530, 10, 60, 30], ...
        'String', 'Cancel', ...
        'Callback', @(src,evt) close(fig));
    
    uiwait(fig);
    
    if ishandle(fig)
        data = fieldTable.Data;
        selectedIndices = cellfun(@(x) islogical(x) && x, data(:, 2));
        selectedFields = allFields(selectedIndices);
        
        sqlFormats = containers.Map();
        for i = 1:numFields
            if selectedIndices(i) && isSqlField(i)
                formatValue = data{i, 3};
                if ischar(formatValue)
                    formatLower = lower(formatValue);
                    if strcmp(formatLower, 'number')
                        sqlFormats(allFields{i}) = 'number';
                    elseif strcmp(formatLower, 'logical')
                        sqlFormats(allFields{i}) = 'logical';
                    elseif strcmp(formatLower, 'date')
                        sqlFormats(allFields{i}) = 'date';
                    elseif strcmp(formatLower, 'datetime')
                        sqlFormats(allFields{i}) = 'datetime';
                    else
                        sqlFormats(allFields{i}) = 'text';
                    end
                else
                    sqlFormats(allFields{i}) = 'text';
                end
            end
        end
        
        result = struct('fields', {selectedFields}, 'sqlFormats', sqlFormats);
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
        if isstruct(value) && numel(value) == 1 && isfield(value, parts{i})
            value = value.(parts{i});
        elseif isstruct(value) && numel(value) > 1 && isfield(value(1), parts{i})
            % Extract field from each structure in array
            extractedValues = cellfun(@(x) x.(parts{i}), num2cell(value), 'UniformOutput', false);
            % If all values are scalars of the same type, convert to array
            try
                if all(cellfun(@(x) isnumeric(x) && isscalar(x), extractedValues))
                    value = cell2mat(extractedValues);
                elseif all(cellfun(@(x) ischar(x) || isstring(x), extractedValues))
                    value = cellstr(extractedValues);
                else
                    % Keep as cell array if values are not all scalars or have different types
                    value = extractedValues;
                end
            catch
                % Keep as cell array if conversion fails
                value = extractedValues;
            end
        elseif iscell(value) && numel(value) > 0 && isstruct(value{1}) && isfield(value{1}, parts{i})
            value = cellfun(@(x) x.(parts{i}), value, 'UniformOutput', false);
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

function [success, errorInfo] = saveToMatDirect(metaPaths, fileIds, selectedFields, savePath, fileTableData, fileTableColumns, sqlFormats)
    success = false;
    errorInfo = [];
    
    if isempty(metaPaths) || isempty(selectedFields)
        return
    end
    
    numFiles = numel(metaPaths);
    hasFileTableData = nargin >= 5 && ~isempty(fileTableData) && nargin >= 6 && ~isempty(fileTableColumns);
    
    if nargin < 7 || isempty(sqlFormats)
        sqlFormats = containers.Map();
    end
    
    try
        wb = waitbar(0, 'Initializing metadata analysis...', 'Name', 'Metadata Analysis');
        debugState('metadataAnalysis', 'Initializing metadata analysis...');
        
        debugState('metadataAnalysis', 'Processing files and creating table...');
        waitbar(0.01, wb, 'Processing files and creating table...');
        
        fieldInfo = cell(numel(selectedFields), 1);
        
        for fieldIdx = 1:numel(selectedFields)
            fieldPath = selectedFields{fieldIdx};
            isSqlField = hasFileTableData && numel(fileTableColumns) > 3 && any(strcmp(fieldPath, fileTableColumns(4:end)));
            if isSqlField
                isText = true;
                if sqlFormats.isKey(fieldPath)
                    formatValue = sqlFormats(fieldPath);
                    if strcmp(formatValue, 'number') || strcmp(formatValue, 'logical') || strcmp(formatValue, 'date') || strcmp(formatValue, 'datetime')
                        isText = false;
                    end
                end
                fieldInfo{fieldIdx} = struct('isText', isText, 'isStruct', false, 'isCellArray', false, 'maxSize', 1, 'typeDetermined', true);
            else
                fieldInfo{fieldIdx} = struct('isText', false, 'isStruct', false, 'isCellArray', false, 'maxSize', 1, 'typeDetermined', false);
            end
        end
        
        allTables = {};
        
        for fileIdx = 1:numFiles
            progress = 0.01 + 0.94 * (fileIdx / numFiles);
            waitbar(progress, wb, sprintf('Processing file %d/%d...', fileIdx, numFiles));
            
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
                
                isSqlField = hasFileTableData && numel(fileTableColumns) > 3 && any(strcmp(fieldPath, fileTableColumns(4:end)));
                if isSqlField
                    colIdx = [];
                    for c = 1:numel(fileTableColumns)
                        if strcmp(fileTableColumns{c}, fieldPath)
                            colIdx = c;
                            break
                        end
                    end
                    
                    value = [];
                    if ~isempty(colIdx)
                        for r = 1:size(fileTableData, 1)
                            if isequal(fileTableData{r, 1}, fileId)
                                value = fileTableData{r, colIdx};
                                if isempty(value)
                                    value = '';
                                end
                                break
                            end
                        end
                    end
                    
                    if isempty(value)
                        value = '';
                    end
                    
                    if sqlFormats.isKey(fieldPath)
                        formatType = sqlFormats(fieldPath);
                        
                        if strcmp(formatType, 'number')
                            if ischar(value) || isstring(value)
                                if isempty(value)
                                    value = NaN;
                                else
                                    numValue = str2double(value);
                                    if ~isnan(numValue)
                                        value = numValue;
                                    end
                                end
                            elseif isnumeric(value)
                                value = value;
                            end
                        elseif strcmp(formatType, 'logical')
                            if ischar(value) || isstring(value)
                                if isempty(value)
                                    value = false;
                                else
                                    valueLower = lower(strtrim(char(value)));
                                    if strcmp(valueLower, 'true') || strcmp(valueLower, '1') || strcmp(valueLower, 'yes') || strcmp(valueLower, 'on')
                                        value = true;
                                    elseif strcmp(valueLower, 'false') || strcmp(valueLower, '0') || strcmp(valueLower, 'no') || strcmp(valueLower, 'off')
                                        value = false;
                                    else
                                        numValue = str2double(value);
                                        if ~isnan(numValue)
                                            value = logical(numValue ~= 0);
                                        end
                                    end
                                end
                            elseif isnumeric(value)
                                value = logical(value ~= 0);
                            elseif islogical(value)
                                value = value;
                            end
                        elseif strcmp(formatType, 'date')
                            if ischar(value) || isstring(value)
                                if isempty(value)
                                    value = NaN;
                                else
                                    try
                                        dateValue = datenum(value);
                                        if ~isnan(dateValue)
                                            value = dateValue;
                                        end
                                    catch
                                    end
                                end
                            elseif isnumeric(value)
                                value = value;
                            end
                        elseif strcmp(formatType, 'datetime')
                            if ischar(value) || isstring(value)
                                if isempty(value)
                                    value = NaN;
                                else
                                    try
                                        dateValue = datenum(value);
                                        if ~isnan(dateValue)
                                            value = dateValue;
                                        end
                                    catch
                                    end
                                end
                            elseif isnumeric(value)
                                value = value;
                            end
                        end
                    end
                else
                    value = getFieldValue(meta, fieldPath);
                    
                    if ~isempty(value)
                        valueSize = numel(value);
                        if valueSize > fieldInfo{fieldIdx}.maxSize
                            fieldInfo{fieldIdx}.maxSize = valueSize;
                        end
                        
                        if ~fieldInfo{fieldIdx}.typeDetermined
                            debugState('metadataAnalysis', 'Analyzing field %s: isstruct=%d, iscell=%d, dims=%s', fieldPath, isstruct(value), iscell(value), mat2str(size(value)));
                            
                            if isstruct(value)
                                fieldInfo{fieldIdx}.isStruct = true;
                                debugState('metadataAnalysis', 'Field %s: Set isStruct=true', fieldPath);
                            elseif ischar(value) || isstring(value)
                                fieldInfo{fieldIdx}.isText = true;
                                debugState('metadataAnalysis', 'Field %s: Set isText=true', fieldPath);
                            elseif iscell(value)
                                fieldInfo{fieldIdx}.isCellArray = true;
                                valueFlat = value(:);
                                if numel(valueFlat) > 0
                                    textCheck = cellfun(@(x) ischar(x) || isstring(x), valueFlat);
                                    allText = all(textCheck);
                                    debugState('metadataAnalysis', 'Field %s: cell array, allText=%d', fieldPath, allText);
                                    if allText
                                        fieldInfo{fieldIdx}.isText = true;
                                    end
                                end
                            end
                            fieldInfo{fieldIdx}.typeDetermined = true;
                        end
                    end
                end
                
                fileValues{fieldIdx} = value;
            end
            fileData.values{1} = fileValues;
            
            batchTable = createFlatTableWithStructure(fileData, selectedFields, fieldInfo);
            clear meta fileData;
            
            if ~isempty(batchTable)
                allTables{end+1} = batchTable;
                clear batchTable;
                
                if numel(allTables) >= 5
                    debugState('metadataAnalysis', 'Combining %d tables to free memory', numel(allTables));
                    combined = allTables{1};
                    for i = 2:numel(allTables)
                        combined = safeVertcat(combined, allTables{i});
                    end
                    allTables = {combined};
                    clear combined;
                end
            end
        end
        
        if isempty(allTables)
            if exist('wb', 'var') && ishandle(wb)
                close(wb);
            end
            return
        end
        
        waitbar(0.95, wb, 'Finalizing and saving files...');
        debugState('metadataAnalysis', 'Finalizing and saving files...');
        debugState('metadataAnalysis', 'Final combining and saving to MAT file');
        if numel(allTables) == 1
            flatTable = allTables{1};
        else
            flatTable = allTables{1};
            for i = 2:numel(allTables)
                flatTable = safeVertcat(flatTable, allTables{i});
            end
        end
        clear allTables;
        
        waitbar(0.96, wb, 'Saving MAT file...');
        debugState('metadataAnalysis', 'Saving MAT file...');
        save(savePath, 'flatTable', '-v7.3');
        debugState('metadataAnalysis', 'MAT file saved successfully: %s', savePath);
        
        waitbar(0.97, wb, 'Saving Excel file...');
        debugState('metadataAnalysis', 'Saving Excel file...');
        [excelPath, excelName, ~] = fileparts(savePath);
        excelPath = fullfile(excelPath, [excelName, '.xlsx']);
        try
            debugState('metadataAnalysis', 'Saving to Excel file: %s', excelPath);
            writetable(flatTable, excelPath);
            debugState('metadataAnalysis', 'Table successfully saved to Excel: %s', excelPath);
        catch ME
            handleMetadataError(ME, 'Failed to save Excel file', false);
        end
        
        waitbar(1.0, wb, 'Completed!');
        debugState('metadataAnalysis', 'Metadata analysis completed successfully');
        pause(0.1);
        close(wb);
        
        clear flatTable;
        success = true;
    catch ME
        if exist('wb', 'var') && ishandle(wb)
            close(wb);
        end
        handleMetadataError(ME, 'Failed to save MAT file', false);
        errorInfo = ME;
    end
end

function flatTable = createFlatTableWithStructure(collectedData, selectedFields, fieldInfo)
    if isempty(collectedData.fileIds)
        flatTable = [];
        return
    end
    
    numFiles = numel(collectedData.fileIds);
    numFields = numel(selectedFields);
    
    debugState('metadataAnalysis', 'createFlatTableWithStructure: numFiles=%d, numFields=%d', numFiles, numFields);
    
    fileIdColumn = collectedData.fileIds(:);
    
    debugState('metadataAnalysis', 'createFlatTableWithStructure: fileIdColumn size=%d', numel(fileIdColumn));
    
    columnNames = {'File ID'};
    columnData = cell(0, 1);
    
    for fieldIdx = 1:numFields
        fieldName = selectedFields{fieldIdx};
        info = fieldInfo{fieldIdx};
        
        debugState('metadataAnalysis', 'createFlatTableWithStructure: Processing field %d/%d: %s (isText=%d, isStruct=%d)', fieldIdx, numFields, fieldName, info.isText, info.isStruct);
        
        columnNames{end+1} = fieldName;
        
        maxSize = 1;
        if isfield(info, 'maxSize')
            maxSize = info.maxSize;
        end
        
        if info.isText || info.isStruct || info.isCellArray || maxSize > 1
            fieldColumn = cell(numFiles, 1);
        else
            fieldColumn = nan(numFiles, 1);
        end
        
        debugState('metadataAnalysis', 'createFlatTableWithStructure: Created column for field %s, size: fieldColumn=%d, maxSize=%d', fieldName, numel(fieldColumn), maxSize);
        
        for fileIdx = 1:numFiles
            try
                fileValues = collectedData.values{fileIdx};
                value = fileValues{fieldIdx};
                
                debugState('metadataAnalysis', 'createFlatTableWithStructure: File %d/%d, field %s, value empty=%d', fileIdx, numFiles, fieldName, isempty(value));
                
                if isempty(value)
                    debugState('metadataAnalysis', 'createFlatTableWithStructure: Value is empty');
                elseif info.isText || info.isStruct || info.isCellArray || maxSize > 1
                    fieldColumn{fileIdx} = value;
                elseif iscell(fieldColumn)
                    fieldColumn{fileIdx} = value;
                else
                    fieldColumn(fileIdx) = value;
                end
            catch ME
                debugState('metadataAnalysis', 'createFlatTableWithStructure: ERROR at file %d/%d, field %s: %s', fileIdx, numFiles, fieldName, ME.message);
                debugState('metadataAnalysis', 'createFlatTableWithStructure: Stack trace: %s', getReport(ME));
                if ~iscell(fieldColumn) && numel(value) > 1
                    fieldColumn = num2cell(fieldColumn);
                    fieldColumn{fileIdx} = value;
                else
                    rethrow(ME);
                end
            end
        end
        
        columnData{end+1} = fieldColumn;
    end
    
    % Create table ensuring cell columns remain as cell arrays
    % This prevents MATLAB from trying to concatenate structures with different fields
    tableData = [{fileIdColumn}, columnData];
    flatTable = table(tableData{:}, 'VariableNames', columnNames);
    
    % Force cell columns to remain as cell arrays (prevents structure concatenation errors)
    for i = 1:numel(columnData)
        colName = columnNames{i+1};
        if iscell(columnData{i})
            % Ensure the column is treated as cell array
            flatTable.(colName) = columnData{i};
        end
    end
end

function result = safeVertcat(t1, t2)
    % Safely concatenate two tables, ensuring cell columns with structures remain as cell arrays
    % This prevents "Number of fields in structure arrays being concatenated do not match" errors
    
    varNames = t1.Properties.VariableNames;
    
    % Convert both tables to cell arrays row by row, then combine
    t1Data = table2cell(t1);
    t2Data = table2cell(t2);
    combinedData = [t1Data; t2Data];
    
    % Recreate table from cell array, preserving variable names
    result = cell2table(combinedData, 'VariableNames', varNames);
end

function str = struct2str(s)
    if numel(s) == 1
        fieldNames = fieldnames(s);
        parts = cell(numel(fieldNames), 1);
        for i = 1:numel(fieldNames)
            fieldName = fieldNames{i};
            fieldValue = s.(fieldName);
            if ischar(fieldValue) || isstring(fieldValue)
                parts{i} = sprintf('%s: "%s"', fieldName, char(fieldValue));
            elseif isnumeric(fieldValue) && isscalar(fieldValue)
                parts{i} = sprintf('%s: %g', fieldName, fieldValue);
            elseif isnumeric(fieldValue)
                parts{i} = sprintf('%s: [%s]', fieldName, mat2str(size(fieldValue)));
            elseif isstruct(fieldValue)
                parts{i} = sprintf('%s: {struct}', fieldName);
            else
                parts{i} = sprintf('%s: {%s}', fieldName, class(fieldValue));
            end
        end
        str = sprintf('{%s}', strjoin(parts, ', '));
    else
        str = sprintf('{struct array [%s]}', mat2str(size(s)));
    end
end

function handleMetadataError(ME, contextMessage, showMsgbox)
    if nargin < 3
        showMsgbox = false;
    end
    
    debugState('metadataAnalysis', '%s: %s', contextMessage, ME.message);
    fprintf('ERROR in metadataAnalysis: %s\n', contextMessage);
    fprintf('%s\n', getReport(ME, 'extended'));
    
    if showMsgbox
        msgbox(sprintf('%s: %s', contextMessage, ME.message), 'Error', 'error');
    end
end


