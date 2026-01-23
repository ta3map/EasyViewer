function stats = executeModuleTasks(tasks, varargin)
    % Выполняет список задач модулей с обработкой результатов
    % 
    % Входные параметры:
    %   tasks - массив структур задач со следующими полями:
    %       fileId - ID файла
    %       filePath - путь к файлу
    %       fileName - имя файла
    %       moduleName - имя модуля
    %       params - параметры модуля (структура)
    %       updateHistory - логическое значение, обновлять ли историю анализа (по умолчанию true)
    %
    %   Опциональные параметры (пары ключ-значение):
    %       'ProgressBarTitle' - заголовок прогресс-бара (по умолчанию 'Processing Modules')
    %       'ExtractMetadataCallback' - функция для извлечения и сохранения метаданных
    %           function result = callback(result, fileId)
    %       'SaveMetaFileCallback' - функция для сохранения .meta файла
    %           function result = callback(result, filePath)
    %       'UpdateTableCallback' - функция для обновления таблицы анализа
    %           function callback(fileId)
    %
    % Выходные параметры:
    %   stats - структура со статистикой:
    %       total - общее количество задач
    %       success - количество успешно выполненных задач
    %       failed - количество неудачных задач
    
    p = inputParser;
    addParameter(p, 'ProgressBarTitle', 'Processing Modules', @ischar);
    addParameter(p, 'ExtractMetadataCallback', [], @(x) isempty(x) || isa(x, 'function_handle'));
    addParameter(p, 'SaveMetaFileCallback', [], @(x) isempty(x) || isa(x, 'function_handle'));
    addParameter(p, 'UpdateTableCallback', [], @(x) isempty(x) || isa(x, 'function_handle'));
    parse(p, varargin{:});
    
    progressBarTitle = p.Results.ProgressBarTitle;
    extractMetadataCallback = p.Results.ExtractMetadataCallback;
    saveMetaFileCallback = p.Results.SaveMetaFileCallback;
    updateTableCallback = p.Results.UpdateTableCallback;
    
    stats = struct('total', 0, 'success', 0, 'failed', 0);
    
    if isempty(tasks)
        return
    end
    
    stats.total = numel(tasks);
    stats.success = 0;
    stats.failed = 0;
    
    progressBar = waitbar(0, 'Initializing...', 'Name', progressBarTitle);
    startTime = tic;
    
    try
        for i = 1:numel(tasks)
            task = tasks(i);
            
            if ~isfield(task, 'updateHistory') || isempty(task.updateHistory)
                task.updateHistory = true;
            end
            
            if ishandle(progressBar)
                progress = (i - 1) / stats.total;
                elapsedTime = toc(startTime);
                
                message = sprintf('Processing task %d/%d: %s', i, stats.total, task.moduleName);
                
                if i > 1 && elapsedTime > 0
                    avgTimePerTask = elapsedTime / (i - 1);
                    remainingTasks = stats.total - i + 1;
                    estimatedRemaining = avgTimePerTask * remainingTasks;
                    
                    elapsedStr = formatTime(elapsedTime);
                    remainingStr = formatTime(estimatedRemaining);
                    message = sprintf('%s\nElapsed: %s | Remaining: ~%s', message, elapsedStr, remainingStr);
                end
                
                waitbar(progress, progressBar, message);
            end
            
            try
                debugState('executeModuleTasks', 'Task %d/%d: module=%s, file=%s', ...
                    i, stats.total, task.moduleName, task.filePath);
                
                if task.updateHistory
                    updateAnalysisHistory(task.fileId, task.moduleName);
                end
                
                result = callModule(task.moduleName, task.filePath, task.fileId, task.params);
                
                if ~isempty(result) && isstruct(result) && numel(result) == 1 && ~isempty(fieldnames(result))
                    result.file_id = task.fileId;
                    result.file_name = task.fileName;
                    result.module_name = task.moduleName;
                    
                    if ~isempty(extractMetadataCallback)
                        result = extractMetadataCallback(result, task.fileId);
                    end
                    
                    if ~isempty(saveMetaFileCallback)
                        result = saveMetaFileCallback(result, task.filePath);
                    end
                    
                    logAnalysisResult(task.fileId, result);
                    
                    if ~isempty(updateTableCallback)
                        updateTableCallback(task.fileId);
                    end
                    
                    stats.success = stats.success + 1;
                else
                    warning('executeModuleTasks: module %s returned empty result for file_id=%d', ...
                        task.moduleName, task.fileId);
                    stats.failed = stats.failed + 1;
                end
            catch ME
                warning('executeModuleTasks: error processing task %d/%d: %s', ...
                    i, stats.total, ME.message);
                stats.failed = stats.failed + 1;
            end
        end
        
        if ishandle(progressBar)
            totalTime = toc(startTime);
            totalTimeStr = formatTime(totalTime);
            waitbar(1.0, progressBar, sprintf('Completed! (Total time: %s)', totalTimeStr));
            pause(0.5);
            close(progressBar);
        end
    catch ME
        if ishandle(progressBar)
            close(progressBar);
        end
        rethrow(ME);
    end
end

function result = callModule(moduleName, filePath, fileId, params)
    result = [];
    
    if isempty(params)
        global timeUnitFactor
        if isempty(timeUnitFactor)
            timeUnitFactor = 1;
        end
        params = loadModuleParams(moduleName, timeUnitFactor);
    end
    
    try
        macroFunc = str2func(moduleName);
        result = macroFunc(filePath, fileId, params);
    catch ME
        debugState('executeModuleTasks', 'Module call failed: %s (%s)', moduleName, ME.message);
    end
end

function formattedTime = formatTime(seconds)
    if seconds < 60
        formattedTime = sprintf('%.0f sec', seconds);
    elseif seconds < 3600
        minutes = floor(seconds / 60);
        secs = floor(mod(seconds, 60));
        formattedTime = sprintf('%.0f min %.0f sec', minutes, secs);
    else
        hours = floor(seconds / 3600);
        minutes = floor(mod(seconds, 3600) / 60);
        secs = floor(mod(seconds, 60));
        formattedTime = sprintf('%.0f h %.0f min %.0f sec', hours, minutes, secs);
    end
end
