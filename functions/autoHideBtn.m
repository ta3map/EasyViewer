function autoHideBtn(src, event, btn_list)
    for btn = btn_list
        % Получение текущих координат курсора мыши
        currentPoint = get(src, 'CurrentPoint');
        x = currentPoint(1);
        y = currentPoint(2);

        % Получение координат и размеров кнопки из свойства Position
        btnPos = get(btn, 'Position');
        buttonX = btnPos(1);
        buttonY = btnPos(2);
        buttonWidth = btnPos(3);
        buttonHeight = btnPos(4);

        % Проверка, находится ли курсор мыши в пределах кнопки
        if x >= buttonX && x <= (buttonX + buttonWidth) && y >= buttonY && y <= (buttonY + buttonHeight)
            set(btn, 'Visible', 'on'); % Показать кнопку
        else
            set(btn, 'Visible', 'off'); % Скрыть кнопку
        end
    end
end