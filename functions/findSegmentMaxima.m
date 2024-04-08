function segmentMax = findSegmentMaxima(data, numSegments)
    % Рассчитываем размер каждого участка
    segmentLength = floor(length(data) / numSegments);

    % Инициализируем вектор для хранения максимальных значений каждого участка
    segmentMax = zeros(1, numSegments);

    % Находим максимум в каждом участке
    for i = 1:numSegments
        startIdx = (i-1) * segmentLength + 1;
        endIdx = startIdx + segmentLength - 1;
        % Проверяем, не является ли текущий участок последним
        if i == numSegments
            % Если да, то включаем все оставшиеся данные в последний участок
            endIdx = length(data);
        end
        segmentMax(i) = max(data(startIdx:endIdx));
    end
end
