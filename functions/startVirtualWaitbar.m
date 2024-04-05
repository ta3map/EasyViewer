function [wb, tm] = startVirtualWaitbar()
    % Создает и запускает виртуальный waitbar, который обновляется по кругу

    % Создание waitbar и задание тега для последующего поиска
    wb = waitbar(0, 'Please wait...', 'Tag', 'VirtualWaitbar');
    % Инициализация UserData для хранения прогресса
    userData = struct('progress', 0);
    set(wb, 'UserData', userData);

    % Создание и настройка timer объекта
    tm = timer('Tag', 'VirtualWaitbarTimer');
    tm.TimerFcn = @(myTimerObj, thisEvent)updateCircularWaitbar(wb);
    tm.Period = 0.1; % Время обновления в секундах
    tm.ExecutionMode = 'fixedRate';
    tm.TasksToExecute = inf; % Бесконечное количество обновлений

    % Запуск timer
    start(tm);
end

function updateCircularWaitbar(wb)
    % Функция для обновления waitbar с циклическим прогрессом

    % Получение текущего состояния прогресса из UserData
    userData = get(wb, 'UserData');
    progress = userData.progress + 0.01; % Увеличение прогресса

    % Перезапуск прогресса, если достигнут максимум
    if progress >= 1
        progress = 0;
    end

    % Обновление waitbar и сохранение нового состояния прогресса
    waitbar(progress, wb);
    set(wb, 'UserData', struct('progress', progress));
end
