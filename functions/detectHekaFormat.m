function isHeka = detectHekaFormat(filepath)
    % Определяет, является ли .mat файл файлом Heka по наличию переменных Trace_*_*
    %
    % Параметры:
    %   filepath - путь к .mat файлу
    %
    % Возвращает:
    %   isHeka - логическое значение, true если файл в формате Heka
    
    try
        % Получаем список переменных в файле без загрузки данных
        info = whos('-file', filepath);
        variableNames = {info.name};
        
        % Проверяем наличие переменных с паттерном Trace_*_*
        traceCount = 0;
        for i = 1:length(variableNames)
            varName = variableNames{i};
            if length(varName) >= 5 && strcmp(varName(1:5), 'Trace')
                % Проверяем структуру имени: Trace_X_Y_Z где X, Y, Z - числа
                underscores = strfind(varName, '_');
                if length(underscores) >= 3
                    traceCount = traceCount + 1;
                end
            end
        end
        
        % Если найдено достаточно переменных Trace, считаем файл Heka
        isHeka = traceCount > 0;
        
        if isHeka
            disp(['Detected Heka format file with ' num2str(traceCount) ' trace variables']);
        end
        
    catch ME
        % В случае ошибки считаем, что это не Heka файл
        isHeka = false;
        disp(['Error detecting file format: ' ME.message]);
    end
end 