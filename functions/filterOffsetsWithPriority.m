function good_diff = filterOffsetsWithPriority(chRangesOffsets, y_tick_min_offset_size, priorityOffsets)
    % Сортируем массив и сохраняем исходные индексы
    [chRangesOffsets_sorted, sort_idx] = sort(chRangesOffsets);
    N = length(chRangesOffsets_sorted);
    
    % Определяем, какие из отсортированных оффсетов являются приоритетными
    isPriority_sorted = ismember(chRangesOffsets_sorted, priorityOffsets);
    
    % Инициализируем логический массив
    good_diff_sorted = false(N,1);
    
    % Инициализируем массивы выбранных оффсетов и их приоритетности как столбцы
    selected_offsets = zeros(0,1);  % Столбец
    selected_is_priority = false(0,1);  % Столбец
    
    for i = 1:N
        current_offset = chRangesOffsets_sorted(i);
        current_is_priority = isPriority_sorted(i);
        
        % Вычисляем расстояния до ранее выбранных оффсетов
        distances = abs(current_offset - selected_offsets);
        conflicts = distances < y_tick_min_offset_size;
        
        if ~any(conflicts)
            % Нет конфликтов, добавляем текущий оффсет
            good_diff_sorted(i) = true;
            selected_offsets = [selected_offsets; current_offset];
            selected_is_priority = [selected_is_priority; current_is_priority];
        else
            % Есть конфликты
            if current_is_priority
                % Текущий оффсет приоритетный
                % Добавляем текущий оффсет
                good_diff_sorted(i) = true;
                selected_offsets = [selected_offsets; current_offset];
                selected_is_priority = [selected_is_priority; current_is_priority];
                
                % Удаляем конфликтующие неприоритетные оффсеты
                non_priority_conflicts = conflicts & ~selected_is_priority;
                if any(non_priority_conflicts)
                    % Удаляем из выбранных оффсетов и обновляем good_diff_sorted
                    offsets_to_remove = selected_offsets(non_priority_conflicts);
                    selected_offsets(non_priority_conflicts) = [];
                    selected_is_priority(non_priority_conflicts) = [];
                    
                    % Находим индексы в chRangesOffsets_sorted для обновления good_diff_sorted
                    [~, idxs_to_remove] = ismember(offsets_to_remove, chRangesOffsets_sorted(1:i-1));
                    good_diff_sorted(idxs_to_remove) = false;
                end
            else
                % Текущий оффсет не приоритетный
                % Проверяем, конфликтует ли он с приоритетными оффсетами
                priority_conflicts = conflicts & selected_is_priority;
                if any(priority_conflicts)
                    % Конфликт с приоритетным оффсетом, пропускаем текущий
                    continue;
                else
                    % Конфликт только с неприоритетными оффсетами
                    % Поскольку мы идем с начала, сохраняем первый (уже выбранный), пропускаем текущий
                    continue;
                end
            end
        end
    end
    
    % Приводим логический массив к исходному порядку
    good_diff = false(size(chRangesOffsets));
    good_diff(sort_idx) = good_diff_sorted;
end
