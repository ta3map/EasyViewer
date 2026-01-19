function profile_fileManagerGUI_init()
    fprintf('Профилирование инициализации fileManagerGUI...\n');
    
    profile clear;
    profile on;
    
    tic;
    fileManagerGUI();
    elapsedTime = toc;
    
    profile off;
    
    fprintf('Инициализация заняла %.3f секунд\n\n', elapsedTime);
    
    results = profile('info');
    
    if ~isempty(results.FunctionTable)
        fprintf('=== Топ-20 самых медленных функций ===\n');
        [~, idx] = sort([results.FunctionTable.TotalTime], 'descend');
        topN = min(20, numel(idx));
        for i = 1:topN
            funcIdx = idx(i);
            func = results.FunctionTable(funcIdx);
            fprintf('%2d. %-50s: %8.3f сек (%6d вызовов, %8.3f мс/вызов)\n', ...
                i, func.FunctionName, func.TotalTime, func.NumCalls, ...
                func.TotalTime / max(1, func.NumCalls) * 1000);
        end
    end
end
