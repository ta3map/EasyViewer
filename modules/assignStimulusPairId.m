function fileTable = assignStimulusPairId(fileTable)
    debugState('assignStimulusPairId', '=== Starting module ===');
    
    % Проверка базовых колонок (как в assignFolderIds)
    if isempty(fileTable) || width(fileTable) < 3
        debugState('assignStimulusPairId', 'Table is empty or has less than 3 columns, exiting');
        return
    end
    
    debugState('assignStimulusPairId', 'Table size: %d rows, %d columns', height(fileTable), width(fileTable));
    
    varNames = fileTable.Properties.VariableNames;
    debugState('assignStimulusPairId', 'Available columns: %s', strjoin(varNames, ', '));
    
    outputFields = {'folder_id', 'current_type', 'pair_id'};
    for i = 1:numel(outputFields)
        if any(strcmp(varNames, outputFields{i}))
            fileTable = removevars(fileTable, outputFields{i});
            debugState('assignStimulusPairId', 'Removed existing output field: %s', outputFields{i});
        end
    end
    
    varNames = fileTable.Properties.VariableNames;
    debugState('assignStimulusPairId', 'Updated columns: %s', strjoin(varNames, ', '));
    
    paths = fileTable.Path;
    folders = cellfun(@(p) fileparts(p), paths, 'UniformOutput', false);
    [~, ~, folderIdx] = unique(folders);
    fileTable.folder_id = folderIdx;
    debugState('assignStimulusPairId', 'Created folder_id: %d unique folders', numel(unique(folderIdx)));
    
    % Обновляем список колонок после возможного добавления folder_id
    varNames = fileTable.Properties.VariableNames;
    debugState('assignStimulusPairId', 'Updated columns: %s', strjoin(varNames, ', '));
    
    % Проверка наличия необходимых колонок
    requiredCols = {'hold_potential', 'stim'};
    missingCols = setdiff(requiredCols, varNames);
    if ~isempty(missingCols)
        debugState('assignStimulusPairId', 'Missing required columns: %s, exiting', strjoin(missingCols, ', '));
        debugState('assignStimulusPairId', 'Available columns after folder_id: %s', strjoin(varNames, ', '));
        return
    end
    
    debugState('assignStimulusPairId', 'All required columns found');
    
    % Инициализация колонок
    numRows = height(fileTable);
    currentType = cell(numRows, 1);
    pairId = cell(numRows, 1);
    
    % Конвертация hold_potential в числовой формат
    holdPotentialRaw = fileTable.hold_potential;
    holdPotential = nan(numRows, 1);
    
    debugState('assignStimulusPairId', 'Converting hold_potential, type: %s', class(holdPotentialRaw));
    
    if iscell(holdPotentialRaw)
        debugState('assignStimulusPairId', 'hold_potential is cell array, converting...');
        convertedCount = 0;
        emptyCount = 0;
        for i = 1:numRows
            val = holdPotentialRaw{i};
            if isempty(val)
                holdPotential(i) = NaN;
                emptyCount = emptyCount + 1;
            elseif ischar(val) || isstring(val)
                numVal = str2double(val);
                if ~isnan(numVal)
                    holdPotential(i) = numVal;
                    convertedCount = convertedCount + 1;
                else
                    emptyCount = emptyCount + 1;
                end
            elseif isnumeric(val)
                holdPotential(i) = val;
                convertedCount = convertedCount + 1;
            end
        end
        debugState('assignStimulusPairId', 'Converted: %d values, empty/NaN: %d', convertedCount, emptyCount);
    elseif isnumeric(holdPotentialRaw)
        holdPotential = holdPotentialRaw;
        debugState('assignStimulusPairId', 'hold_potential is already numeric');
    end
    
    validHoldPotentialCount = sum(~isnan(holdPotential));
    debugState('assignStimulusPairId', 'Valid hold_potential values: %d / %d', validHoldPotentialCount, numRows);
    if validHoldPotentialCount > 0
        debugState('assignStimulusPairId', 'hold_potential range: [%.3f, %.3f]', min(holdPotential(~isnan(holdPotential))), max(holdPotential(~isnan(holdPotential))));
    end
    
    % Получение данных
    folderIds = fileTable.folder_id;
    stims = fileTable.stim;
    
    debugState('assignStimulusPairId', 'Data types - folder_id: %s, stim: %s', class(folderIds), class(stims));
    
    % Конвертация folderIds в числовой массив, если нужно
    if iscell(folderIds)
        debugState('assignStimulusPairId', 'Converting folder_id from cell to numeric array');
        folderIdsNumeric = zeros(numRows, 1);
        convertedCount = 0;
        numericCount = 0;
        stringCount = 0;
        emptyCount = 0;
        for i = 1:numRows
            val = folderIds{i};
            if isnumeric(val)
                folderIdsNumeric(i) = val;
                numericCount = numericCount + 1;
            elseif ischar(val) || isstring(val)
                numVal = str2double(val);
                if ~isnan(numVal)
                    folderIdsNumeric(i) = numVal;
                    convertedCount = convertedCount + 1;
                else
                    folderIdsNumeric(i) = NaN;
                    emptyCount = emptyCount + 1;
                end
                stringCount = stringCount + 1;
            else
                folderIdsNumeric(i) = NaN;
                emptyCount = emptyCount + 1;
            end
        end
        debugState('assignStimulusPairId', 'folder_id conversion: numeric=%d, string->numeric=%d, empty/NaN=%d', ...
            numericCount, convertedCount, emptyCount);
    else
        debugState('assignStimulusPairId', 'folder_id is already numeric, no conversion needed');
        folderIdsNumeric = folderIds;
    end
    
    % Обработка по folder_id
    uniqueFolders = unique(folderIdsNumeric(~isnan(folderIdsNumeric)));
    nextPairId = 1;
    
    debugState('assignStimulusPairId', 'Processing %d unique folders', numel(uniqueFolders));
    
    for folderIdx = 1:numel(uniqueFolders)
        folderId = uniqueFolders(folderIdx);
        folderMask = folderIdsNumeric == folderId;
        folderRows = sum(folderMask);
        
        debugState('assignStimulusPairId', 'Folder %d/%d: folder_id=%d, rows=%d', folderIdx, numel(uniqueFolders), folderId, folderRows);
        
        % Фильтрация: пропуск пустых hold_potential (NaN или пустые)
        validMask = folderMask & ~isnan(holdPotential);
        validRows = sum(validMask);
        if ~any(validMask)
            debugState('assignStimulusPairId', '  No valid hold_potential in this folder, skipping');
            continue
        end
        
        debugState('assignStimulusPairId', '  Valid rows with hold_potential: %d', validRows);
        
        % Разделение на типы
        gabaMask = validMask & holdPotential >= 0;
        ampaMask = validMask & holdPotential < 0;
        gabaCount = sum(gabaMask);
        ampaCount = sum(ampaMask);
        
        debugState('assignStimulusPairId', '  GABA (>=0): %d, AMPA (<0): %d', gabaCount, ampaCount);
        
        % Заполнение current_type
        currentType(gabaMask) = {'GABA'};
        currentType(ampaMask) = {'AMPA'};
        
        % Поиск пар по stim
        folderStims = stims(validMask);
        debugState('assignStimulusPairId', '  Processing stims, type: %s, count: %d', class(folderStims), numel(folderStims));
        
        if iscell(folderStims)
            debugState('assignStimulusPairId', '  stim is cell array, using cell comparison');
            uniqueStims = unique(folderStims);
            debugState('assignStimulusPairId', '  Found %d unique stims (cell array)', numel(uniqueStims));
            for stimIdx = 1:numel(uniqueStims)
                stim = uniqueStims{stimIdx};
                stimMask = validMask & cellfun(@(x) isequal(x, stim), stims);
                stimRows = sum(stimMask);
                
                % Проверка наличия обоих типов
                hasGABA = any(gabaMask & stimMask);
                hasAMPA = any(ampaMask & stimMask);
                
                debugState('assignStimulusPairId', '    Stim %d/%d: "%s", rows=%d, hasGABA=%d, hasAMPA=%d', ...
                    stimIdx, numel(uniqueStims), mat2str(stim), stimRows, hasGABA, hasAMPA);
                
                if hasGABA && hasAMPA
                    % Назначаем pair_id всем записям с этим stim
                    pairId(stimMask) = {nextPairId};
                    debugState('assignStimulusPairId', '      ✓ Pair found! Assigned pair_id=%d to %d rows', nextPairId, stimRows);
                    nextPairId = nextPairId + 1;
                else
                    debugState('assignStimulusPairId', '      ✗ No pair (missing one type), skipping');
                end
            end
        else
            debugState('assignStimulusPairId', '  stim is numeric array, using numeric comparison');
            uniqueStims = unique(folderStims);
            debugState('assignStimulusPairId', '  Found %d unique stims (numeric array)', numel(uniqueStims));
            for stimIdx = 1:numel(uniqueStims)
                stim = uniqueStims(stimIdx);
                stimMask = validMask & stims == stim;
                stimRows = sum(stimMask);
                
                % Проверка наличия обоих типов
                hasGABA = any(gabaMask & stimMask);
                hasAMPA = any(ampaMask & stimMask);
                
                debugState('assignStimulusPairId', '    Stim %d/%d: %.3f, rows=%d, hasGABA=%d, hasAMPA=%d', ...
                    stimIdx, numel(uniqueStims), stim, stimRows, hasGABA, hasAMPA);
                
                if hasGABA && hasAMPA
                    % Назначаем pair_id всем записям с этим stim
                    pairId(stimMask) = {nextPairId};
                    debugState('assignStimulusPairId', '      ✓ Pair found! Assigned pair_id=%d to %d rows', nextPairId, stimRows);
                    nextPairId = nextPairId + 1;
                else
                    debugState('assignStimulusPairId', '      ✗ No pair (missing one type), skipping');
                end
            end
        end
    end
    
    % Добавление колонок в таблицу
    pairsAssigned = sum(~cellfun(@isempty, pairId));
    currentTypeAssigned = sum(~cellfun(@isempty, currentType));
    
    debugState('assignStimulusPairId', '=== Results ===');
    debugState('assignStimulusPairId', 'current_type assigned: %d rows', currentTypeAssigned);
    debugState('assignStimulusPairId', 'pair_id assigned: %d rows', pairsAssigned);
    debugState('assignStimulusPairId', 'Total pairs found: %d', nextPairId - 1);
    
    fileTable.current_type = currentType;
    fileTable.pair_id = pairId;
    
    debugState('assignStimulusPairId', '=== Module completed ===');
end
