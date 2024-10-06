function good_diff = filterOffsetsFromStart(chRangesOffsets, y_tick_min_offset_size)
    % Сортируем массив и сохраняем исходные индексы
    [chRangesOffsets_sorted, sort_idx] = sort(chRangesOffsets);
    N = length(chRangesOffsets_sorted);
    % Инициализируем логический массив
    good_diff_sorted = false(N,1);
    % Инициализируем массив выбранных оффсетов
    selected_offsets = [];
    for i = 1:N
        current_offset = chRangesOffsets_sorted(i);
        % Проверяем расстояние до всех ранее выбранных точек
        if isempty(selected_offsets) || all(abs(current_offset - selected_offsets) >= y_tick_min_offset_size)
            good_diff_sorted(i) = true;
            selected_offsets(end+1) = current_offset;
        end
    end
    % Приводим логический массив к исходному порядку
    good_diff = false(size(chRangesOffsets));
    good_diff(sort_idx) = good_diff_sorted;
end
