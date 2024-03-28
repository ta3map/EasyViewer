function setUIControlsEnable(parentHandles, mode)
    % Проверка, передан ли список родителей как массив
    if ~iscell(parentHandles)
        parentHandles = {parentHandles}; % Преобразование в ячейковый массив, если передан один элемент
    end
    
    % Перебор всех родительских элементов
    for p = 1:length(parentHandles)
        parentHandle = parentHandles{p};
        % Получение списка дочерних элементов
        children = get(parentHandle, 'Children');
        
        % Перебор всех дочерних элементов
        for i = 1:length(children)
            % Проверка, можно ли установить свойство 'Enable'
            if isprop(children(i), 'Enable')
                set(children(i), 'Enable', mode); % Установка соответствующего режима
            end
        end
    end
end
