function [event_x, amplitude, channel, width, prominence, metadata] = addExtraEvent()
    global add_event_settings lfp time timeUnitFactor filter_avaliable filterSettings newFs ch_inxs
    global csd_image csd_t_range csd_ch_range offsets show_CSD
    
    disp('adding new event ...')
    
    % Получаем первичную временную координату события
    [event_x, ~] = ginput(1); 
    event_x = event_x/timeUnitFactor;
    
    % Определяем индекс канала с проверкой границ
    ch_inx = add_event_settings.channel;
    
    % Проверка границ массива каналов
    [~, numChannels] = size(lfp);
    if ch_inx > numChannels || ch_inx < 1
        warning('Channel index %d exceeds available channels (1-%d). Using channel 1 instead.', ch_inx, numChannels);
        ch_inx = 1;
        add_event_settings.channel = 1;  % Обновляем настройки
    end

    if strcmp(add_event_settings.mode, 'locked') || strcmp(add_event_settings.mode, 'peak_detection')
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
        
        % Определение индекса экстремума или пика
        if strcmp(add_event_settings.mode, 'peak_detection')
            % Новый режим: используем findpeaks для точного поиска пиков
            
            % Подготавливаем данные для анализа пиков
            processed_data = data;
            if strcmp(add_event_settings.polarity, 'negative')
                processed_data = -processed_data;  % Инвертируем для поиска отрицательных пиков
            end
            
            % Параметры для findpeaks
            minPeakHeight = add_event_settings.minPeakHeight;
            maxPeakWidthSec = add_event_settings.maxPeakWidth / 1000;  % Конвертируем мс в секунды
            
            % Поиск пиков с помощью findpeaks
            [peaks, peak_times, widths, prominences] = findpeaks(processed_data, time_in, ...
                'MinPeakHeight', minPeakHeight, ...
                'MaxPeakWidth', maxPeakWidthSec, ...
                'WidthReference', 'halfheight');
            
            if ~isempty(peaks)
                % Выбираем пик ближайший к точке клика
                [~, closest_idx] = min(abs(peak_times - event_x));
                
                amplitude = peaks(closest_idx);
                if strcmp(add_event_settings.polarity, 'negative')
                    amplitude = -amplitude;  % Возвращаем исходный знак
                end
                width = widths(closest_idx) * 1000;  % Конвертируем в миллисекунды
                prominence = prominences(closest_idx);
                event_x = peak_times(closest_idx);   % Уточняем время пика
                
                disp(['Peak detection: found peak at ', num2str(event_x), 's, amplitude=', num2str(amplitude), ', width=', num2str(width), 'ms']);
                
            else
                % Fallback к простому поиску экстремума если пики не найдены
                warning('Peak detection: no peaks found, falling back to extremum search');
                if strcmp(add_event_settings.polarity, 'positive')
                    [amplitude, extr_inx] = max(data);
                else
                    [amplitude, extr_inx] = min(data);
                end
                event_x = time_in(extr_inx);
                width = NaN;
                prominence = NaN;
            end
            
        else
            % Оригинальный режим 'locked': простой поиск экстремума
            if strcmp(add_event_settings.polarity, 'positive')
                [amplitude, extr_inx] = max(data);
            else
                [amplitude, extr_inx] = min(data);
            end
            event_x = time_in(extr_inx);
            width = NaN;
            prominence = NaN;
        end
    else
        % Для manual режима амплитуда недоступна
        amplitude = NaN;
        width = NaN;
        prominence = NaN;
    end

    % Извлекаем канал
    channel = add_event_settings.channel;
    
    % Создаем метаданные
    metadata = struct(...
        'source', 'manual', ...
        'method', add_event_settings.mode, ...
        'data_type', '', ...  % Будет заполнено ниже
        'polarity', add_event_settings.polarity, ...
        'prominence', prominence, ...
        'detection_params', struct() ...
    );
    
    % Добавляем параметры peak_detection в метаданные если используется этот режим
    if strcmp(add_event_settings.mode, 'peak_detection')
        metadata.detection_params.minPeakHeight = add_event_settings.minPeakHeight;
        metadata.detection_params.maxPeakWidth = add_event_settings.maxPeakWidth;
        metadata.detection_params.timeWindow = add_event_settings.timeWindow;
    end
    
    % Определяем тип данных
    if isfield(add_event_settings, 'signal_type')
        metadata.data_type = add_event_settings.signal_type;
    else
        metadata.data_type = 'LFP';  % default
    end

    % Возврат всех значений
    return
end
