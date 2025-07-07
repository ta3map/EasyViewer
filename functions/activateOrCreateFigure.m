function is_return = activateOrCreateFigure(figTag)
    % Поиск открытой фигуры с заданным идентификатором
    guiFig = findobj('Type', 'figure', 'Tag', figTag);
    
    if ~isempty(guiFig)
        % Делаем существующее окно текущим (активным)
        figure(guiFig);
        is_return = true;
    else
        is_return = false;
    end
end
