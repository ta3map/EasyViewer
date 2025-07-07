function event_x = addExtraEvent()
    global add_event_settings lfp time timeUnitFactor filter_avaliable filterSettings newFs ch_inxs
    global csd_image csd_t_range csd_ch_range offsets show_CSD
    
    disp('adding new event ...')
    
    % Получаем первичную временную координату события
    [event_x, ~] = ginput(1); 
    event_x = event_x/timeUnitFactor;
    
    % Определяем индекс канала
    ch_inx = add_event_settings.channel;

    if strcmp(add_event_settings.mode, 'locked')
        % Определение временного интервала (мл-сек в настройках)
        
        range_half = (add_event_settings.timeWindow/1000)/2;
        time_interval = [event_x - range_half, event_x + range_half];% глобальный формат времени в секундах

        % Выборка данных в заданном временном интервале
        cond = time >= time_interval(1) & time < time_interval(2);
        data = lfp(cond, ch_inx);
        time_in = time(cond);
        
        % Фильтруем если попросили
        if sum(filter_avaliable)>0
            ch_to_filter = filter_avaliable(ch_inx);
            data(:, ch_to_filter) = applyFilter(data(:, ch_to_filter), filterSettings, newFs);        
        end
        
        % Определяем по CSD если надо
        if isfield(add_event_settings, 'signal_type')
            if strcmp(add_event_settings.signal_type, 'CSD') && show_CSD
                disp('using CSD for detection')
                
                dataLength = size(csd_image, 1); % Количество элементов в наборе данных
                target_ch_offset = offsets(ch_inx == ch_inxs);% глубина целевого канала
                
                % Создаем вектор, соответствующий индексам данных
                dataIndexes = linspace(csd_ch_range(1), csd_ch_range(2), dataLength);

                % Находим индекс ближайшего значения в dataIndexes к заданному смещению
                [~, idx] = min(abs(dataIndexes - target_ch_offset));
                
                % Преобразуем время в секундный стандарт
                csd_sec_time = csd_t_range/timeUnitFactor;
                
                % Выборка CSD в заданном временном интервале
                cond = csd_sec_time >= time_interval(1) & csd_sec_time < time_interval(2);
                
                data = csd_image(idx, cond);% данные CSD на выбранной высоте
                time_in = csd_sec_time(cond);% глобальный формат времени в секундах
            else
                disp('using LFP for detection')                
            end
        end
        
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
