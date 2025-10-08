function ResizeElements(figHandle, coordsFile, basePosition)
    % ResizeElements - Функция для масштабирования элементов GUI при изменении размера окна
    % 
    % Входные параметры:
    %   figHandle - handle к фигуре
    %   coordsFile - путь к JSON файлу с координатами элементов
    %   basePosition - базовое положение фигуры [x, y, width, height] (опционально)
    % 
    % Автор: Azat Gainutdinov
    % Дата: 05.09.2025
    
    try
        % Загружаем координаты из JSON файла
        if exist(coordsFile, 'file')
            coordsData = jsondecode(fileread(coordsFile));
        else
            error('Файл координат не найден: %s', coordsFile);
        end
        
        % Если basePosition не передан, используем из JSON файла
        if nargin < 3 || isempty(basePosition)
            if isfield(coordsData, 'base_figure_position')
                basePosition = coordsData.base_figure_position;
            else
                error('Базовое положение фигуры не найдено в JSON файле');
            end
        end
        
        % Получаем текущее положение фигуры
        currentPosition = get(figHandle, 'Position');
        
        % Вычисляем коэффициенты масштабирования
        scaleX = currentPosition(3) / basePosition(3);
        scaleY = currentPosition(4) / basePosition(4);
        scaling_matrix = [scaleX, scaleY, scaleX, scaleY];
        
        % Отладочная информация (можно убрать после отладки)
        % fprintf('Текущая позиция: %s\n', mat2str(currentPosition));
        % fprintf('Базовая позиция: %s\n', mat2str(basePosition));
        % fprintf('Коэффициенты масштабирования: X=%.3f, Y=%.3f\n', scaleX, scaleY);
        
        % Получаем все элементы управления в фигуре
        allControls = findall(figHandle, 'Type', 'uicontrol');
        allTables = findall(figHandle, 'Type', 'uitable');
        allAxes = findall(figHandle, 'Type', 'axes');
        
        allElements = [allControls; allTables; allAxes];
        
        % Перебираем все элементы и масштабируем их
        for i = 1:length(allElements)
            element = allElements(i);
            tag = get(element, 'Tag');
            elementType = get(element, 'Type');
            
            % Пропускаем элементы без тегов
            if isempty(tag)
                continue;
            end
            
            % Если у элемента есть тег, ищем его координаты в JSON
            if isfield(coordsData.elements, tag)
                coords = coordsData.elements.(tag);
                
                % Принудительно преобразуем в числа, если это возможно
                if iscell(coords)
                    coords = cell2mat(coords);
                end
                coords = double(coords);
                
                % Преобразуем в строку, если это столбец
                if size(coords, 1) > 1 && size(coords, 2) == 1
                    coords = coords';
                end
                
                % Отладочная информация для элемента (можно убрать после отладки)
                % fprintf('Элемент %s: координаты %s (тип: %s)\n', tag, mat2str(coords), class(coords));
                
                % Проверяем, что координаты имеют правильный формат (4 элемента)
                if length(coords) == 4 && isnumeric(coords) && all(isfinite(coords))
                    try
                        if strcmp(elementType, 'axes')
                            % Для осей используем координаты из JSON как есть (относительные координаты)
                            set(element, 'Position', coords);
                        else
                            % Для всех остальных элементов (uicontrol, uitable, uipanel) применяем масштабирование
                            newPosition = coords .* scaling_matrix;
                            
                            % Убеждаемся, что newPosition - это вектор-строка из 4 элементов
                            if size(newPosition, 1) > 1
                                newPosition = newPosition(:)';  % Преобразуем в строку
                            end
                            
                            % Проверяем, что newPosition является валидным вектором из 4 элементов
                            if length(newPosition) == 4 && isnumeric(newPosition) && all(isfinite(newPosition))
                                set(element, 'Position', newPosition);
                            else
                                warning('Некорректная позиция после масштабирования для элемента %s: %s', tag, mat2str(newPosition));
                            end
                        end
                    catch ME
                        warning('Ошибка при установке позиции для элемента %s (%s): %s', tag, elementType, ME.message);
                        % fprintf('Координаты: %s, newPosition: %s\n', mat2str(coords), mat2str(newPosition));
                    end
                else
                    warning('Неправильный формат координат для элемента %s: %s', tag, mat2str(coords));
                end
            else
                % Элемент с тегом не найден в JSON - это нормально для некоторых элементов
                % fprintf('Элемент с тегом %s не найден в JSON файле\n', tag);
            end
        end
        
    catch ME
        warning('Ошибка при масштабировании элементов: %s', ME.message);
    end
end
