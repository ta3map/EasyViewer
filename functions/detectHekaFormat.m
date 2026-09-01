function isHeka = detectHekaFormat(filepath, fileInfo)
    % Определяет, является ли .mat файл файлом Heka по наличию переменных Trace_*_*
    %
    % Параметры:
    %   filepath - путь к .mat файлу
    %   fileInfo - (опционально) результат whos('-file', filepath)
    %
    % Возвращает:
    %   isHeka - логическое значение, true если файл в формате Heka

    try
        if nargin < 2
            fileInfo = whos('-file', filepath);
        end
        variableNames = {fileInfo.name};

        traceCount = 0;
        for i = 1:length(variableNames)
            varName = variableNames{i};
            if length(varName) >= 5 && strcmp(varName(1:5), 'Trace')
                underscores = strfind(varName, '_');
                if length(underscores) >= 3
                    traceCount = traceCount + 1;
                end
            end
        end

        isHeka = traceCount > 0;

        if isHeka
            disp(['Detected Heka format file with ' num2str(traceCount) ' trace variables']);
        end

    catch ME
        isHeka = false;
        disp(['Error detecting file format: ' ME.message]);
    end
end
