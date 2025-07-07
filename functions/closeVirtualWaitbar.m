function closeVirtualWaitbar(wb, tm)
    % Эта функция останавливает timer и закрывает виртуальный waitbar

    % Найти timer по тегу и остановить его, если он работает
%     t = timerfind('Tag', 'VirtualWaitbarTimer');
    if ~isempty(tm)
        stop(tm); % Остановить таймер
        delete(tm); % Удалить объект таймера
    end
    
    % Закрыть waitbar
%     f = findobj('Tag', 'VirtualWaitbar');
    if ~isempty(wb)
        close(wb);
    end
end
