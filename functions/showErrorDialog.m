function showErrorDialog(errorMessage)
    % Уникальный тег для окна сообщения об ошибке
    errorDialogTag = 'myErrorDialog';
    
    % Поиск существующего окна ошибки с заданным тегом
    existingErrorDialogs = findall(0, 'Type', 'figure', 'Tag', errorDialogTag);
    
    if isempty(existingErrorDialogs)
        % Если окно не найдено, создаем новое и устанавливаем тег
        errDlgHandle = errordlg(errorMessage, 'Error');
        set(errDlgHandle, 'Tag', errorDialogTag);
    else
        % Если окно найдено, переносим на него фокус
        figure(existingErrorDialogs(1));
    end
end
