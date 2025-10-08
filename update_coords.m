function update_coords(coordsFile, mainFig)
    % Скрипт для обновления координат элементов из JSON файла
    % Создает новый JSON файл с актуальными координатами
    
    % Если имя файла не передано, используем по умолчанию
    if nargin < 1
        coordsFile = 'signalViewerGUI_coords.json';
    end
    
    % Если фигура не передана, ищем по тегам
    if nargin < 2
        f = findobj('Tag', 'EasyViwerFigure');
        if isempty(f)
            f = findobj('Tag', 'SlopeMeasurement');
            if isempty(f)
                error('Главная фигура не найдена. Запустите signalViewerGUI() или signalAnalysisGUI() сначала');
            end
        end
    else
        f = mainFig;
    end
    
    % Загружаем исходный JSON с координатами
    if exist(coordsFile, 'file')
        coordsData = jsondecode(fileread(coordsFile));
    else
        error('Файл координат не найден: %s', coordsFile);
    end
    
    % Создаем новую структуру для обновленных координат
    newCoordsData = struct();
    newCoordsData.base_figure_position = get(f, 'Position');
    newCoordsData.elements = struct();
    
    % Проходим по всем тегам из исходного JSON
    elementNames = fieldnames(coordsData.elements);
    
    for i = 1:length(elementNames)
        tag = elementNames{i};
        
        % Ищем элемент по тегу
        element = findobj(f, 'Tag', tag);
        
        if ~isempty(element)
            % Получаем текущие координаты
            pos = get(element, 'Position');
            newCoordsData.elements.(tag) = pos;
            fprintf('Обновлено: %s -> [%.1f, %.1f, %.1f, %.1f]\n', tag, pos(1), pos(2), pos(3), pos(4));
        else
            % Если элемент не найден, используем старые координаты
            newCoordsData.elements.(tag) = coordsData.elements.(tag);
            fprintf('Не найден: %s (используются старые координаты)\n', tag);
        end
    end
    
    % Перезаписываем исходный JSON файл
    jsonStr = jsonencode(newCoordsData, 'PrettyPrint', true);
    fid = fopen(coordsFile, 'w');
    fprintf(fid, '%s', jsonStr);
    fclose(fid);
    
    fprintf('\nКоординаты обновлены в: %s\n', coordsFile);
end
