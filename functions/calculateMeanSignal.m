function [mean_data, mean_time] = calculateMeanSignal()
    % Вычисляет средний сигнал из всех добавленных результатов
    
    % Глобальные переменные для доступа к данным
    global lfp time time_back hd
    global newFs Fs timeUnitFactor selectedUnit
    global filterSettings filter_avaliable mean_group_ch
    global selectedCenter events stims sweep_info event_inx stim_inx sweep_inx events_exist stims_exist
    global slope_measurement_results
    
    if isempty(slope_measurement_results)
        mean_data = [];
        mean_time = [];
        return;
    end
    
    fprintf('DEBUG: Начинаем вычисление среднего сигнала из %d результатов\n', length(slope_measurement_results));

    
    % Первый проход - находим точку t=0 для каждого сигнала
    zero_indices = zeros(1, length(slope_measurement_results));
    before_zero_signals = {};
    after_zero_signals = {};
    
    valid_results = 0;
    for i = 1:length(slope_measurement_results)
        metadata = slope_measurement_results(i).metadata;
        [signal_data, time_data] = getSignalDataForResult(metadata);
        
        if ~isempty(signal_data) && ~isempty(time_data)

            % Находим ближайшую точку к t=0
            zero_idx_array = ClosestIndex(0, time_data);
            zero_idx = zero_idx_array(1); % Берем первый (и единственный) элемент
            valid_results = valid_results + 1;
            zero_indices(valid_results) = zero_idx;
            
            % Разделяем сигнал на части до и после t=0
            before_zero_signals{valid_results} = signal_data(1:zero_idx);
            after_zero_signals{valid_results} = signal_data(zero_idx+1:end);
            
            fprintf('DEBUG: Результат #%d - t=0 индекс: %d, до: %d, после: %d\n', ...
                i, zero_idx, length(before_zero_signals{valid_results}), length(after_zero_signals{valid_results}));
        else
            fprintf('DEBUG: Результат #%d пропущен (пустые данные)\n', i);
        end
    end
    
    % Обрезаем массивы до реального количества валидных результатов
    zero_indices = zero_indices(1:valid_results);

    
    % Находим минимальные длины для обеих частей
    min_before_length = min(cellfun(@length, before_zero_signals));
    min_after_length = min(cellfun(@length, after_zero_signals));
    
    fprintf('DEBUG: Минимальные длины - до t=0: %d, после t=0: %d\n', min_before_length, min_after_length);
    
    % Обрезаем все сигналы до одинаковой длины
    normalized_before_signals = {};
    normalized_after_signals = {};
    
    for i = 1:length(before_zero_signals)
        % Обрезаем часть до t=0 - убираем из начала
        signal = before_zero_signals{i};
        current_length = length(signal);
        
        if current_length > min_before_length
            % Убираем лишние точки из начала
            start_idx = current_length - min_before_length + 1;
            normalized_before_signals{i} = signal(start_idx:end);
        else
            normalized_before_signals{i} = signal;
        end
        
        % Обрезаем часть после t=0 - убираем из конца
        signal = after_zero_signals{i};
        current_length = length(signal);
        
        if current_length > min_after_length
            % Убираем лишние точки из конца
            normalized_after_signals{i} = signal(1:min_after_length);
        else
            normalized_after_signals{i} = signal;
        end
        
        fprintf('DEBUG: Результат #%d - нормализовано до: %d, после: %d\n', ...
            i, length(normalized_before_signals{i}), length(normalized_after_signals{i}));
    end
    
    % Собираем полные сигналы
    all_normalized_signals = {};
    for i = 1:length(normalized_before_signals)
        % Объединяем часть до t=0 и после t=0
        full_signal = [normalized_before_signals{i}, normalized_after_signals{i}];
        all_normalized_signals{i} = full_signal;
    end
    
    % Преобразуем в матрицу для усреднения
    signal_matrix = cell2mat(all_normalized_signals');
    
    % Вычисляем среднее
    mean_data = mean(signal_matrix, 1)'; % Транспонируем в столбец
    
    % Создаем нормализованное время
    total_length = min_before_length + min_after_length;
    
    % Получаем шаг времени из первого результата
    metadata = slope_measurement_results(1).metadata;
    [~, time_data] = getSignalDataForResult(metadata);
    time_step = time_data(2) - time_data(1);
    
    % Время от -min_before_length до +min_after_length
    mean_time = (-min_before_length+1:min_after_length) * time_step;
    
    fprintf('DEBUG: Финальный размер mean_data: %s, mean_time: %s\n', ...
        mat2str(size(mean_data)), mat2str(size(mean_time)));
    
    % Выводим значения в начале и конце векторов
    if ~isempty(mean_data) && ~isempty(mean_time)
        fprintf('DEBUG: Начало mean_time: [%.3f, %.3f, %.3f, %.3f, %.3f]\n', ...
            mean_time(1:min(5, length(mean_time))));
        fprintf('DEBUG: Конец mean_time: [%.3f, %.3f, %.3f, %.3f, %.3f]\n', ...
            mean_time(max(1, end-4):end));
        fprintf('DEBUG: Начало mean_data: [%.6f, %.6f, %.6f, %.6f, %.6f]\n', ...
            mean_data(1:min(5, length(mean_data))));
        fprintf('DEBUG: Конец mean_data: [%.6f, %.6f, %.6f, %.6f, %.6f]\n', ...
            mean_data(max(1, end-4):end));
    end
    
    
    fprintf('✓ Средний сигнал вычислен из %d результатов\n', size(signal_matrix, 1))
end 