function closest_indexes = ClosestIndex(x, X)
    % Проверка на необходимость транспонирования X для удобства обработки
    if size(X, 2) > 1
        X = X';
    end
    % Инициализация массива индексов
    closest_indexes = zeros(size(x));
    % Обработка случая, когда x - это массив
    for idx = 1:length(x)
        if isnan(x(idx))
            closest_indexes(idx) = nan; % Возвращение NaN для NaN элементов
        else
            [~, closest_indexes(idx)] = min(abs(X - x(idx)));
        end
    end
end
