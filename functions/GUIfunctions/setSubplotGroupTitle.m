function setSubplotGroupTitle(ax, groupName, nPlotGroups)
    % setSubplotGroupTitle - Установка title сабплота, если групп несколько
    % 
    % Входные параметры:
    %   ax - handle оси (axes)
    %   groupName - имя группы (строка)
    %   nPlotGroups - количество групп (число)
    
    if nPlotGroups > 1
        titleText = groupName;
        if isempty(titleText)
            titleText = '(no name)';
        end
        title(ax, titleText, 'Interpreter', 'none');
    end
end
