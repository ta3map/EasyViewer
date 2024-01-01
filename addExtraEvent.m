function event_x = addExtraEvent()
    global add_event_settings lfp time timeUnitFactor

    % Получаем первичную временную координату события
    [event_x, ~] = ginput(1); 
    event_x = event_x/timeUnitFactor;
    
    % Определяем индекс канала
    ch_inx = add_event_settings.channel;

    if strcmp(add_event_settings.mode, 'locked')
        % Определение временного интервала (мл-сек в настройках)
        
        range_half = (add_event_settings.timeWindow/1000)/2
        time_interval = [event_x - range_half, event_x + range_half];

        % Выборка данных в заданном временном интервале
        cond = time >= time_interval(1) & time < time_interval(2);
        data = lfp(cond, ch_inx);
        time_in = time(cond);

        % Определение индекса экстремума
        if strcmp(add_event_settings.polarity, 'positive')
            [~, extr_inx] = max(data);
        else
            [~, extr_inx] = min(data);
        end

        % Обновление времени события
        event_x = time_in(extr_inx);
    end

    % Возврат координаты события
    return
end
