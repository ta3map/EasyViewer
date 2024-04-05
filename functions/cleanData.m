function data_clean = cleanData(data, avaliable)
    % Инициализация результата теми же данными
    data_clean = data;

    % Находим индексы столбцов, где данные доступны и где они недоступны
    validCols = find(avaliable);
    missingCols = find(~avaliable);

    % Для каждого недоступного столбца выполняем интерполяцию
    for i = missingCols
        if ~isempty(validCols)
            % Если есть хотя бы один доступный столбец, используем его для интерполяции
            data_clean(:, i) = interp1(validCols, data(:, validCols)', i, 'linear', 'extrap')';
        else
            % Если нет ни одного доступного столбца, оставляем столбец без изменений или заполняем по умолчанию
            % Этот кейс не обрабатывается, так как предполагается, что минимум один столбец доступен
        end
    end
end
