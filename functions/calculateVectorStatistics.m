function stats = calculateVectorStatistics(data)
% calculateVectorStatistics - Расчет статистики для любого числового вектора
%
% Входные параметры:
%   data - числовой вектор (может содержать NaN и Inf)
%
% Выходные параметры:
%   stats - структура со статистикой:
%     count - общее количество элементов
%     nanCount - количество NaN/Inf значений
%     mean - среднее значение
%     std - стандартное отклонение
%     median - медиана
%     q25 - первый квартиль (25-й процентиль)
%     q75 - третий квартиль (75-й процентиль)
%     min - минимальное значение
%     max - максимальное значение

    stats = struct();
    
    if isempty(data)
        stats.count = 0;
        stats.nanCount = 0;
        stats.mean = NaN;
        stats.std = NaN;
        stats.median = NaN;
        stats.q25 = NaN;
        stats.q75 = NaN;
        stats.min = NaN;
        stats.max = NaN;
        return;
    end
    
    if ~isnumeric(data)
        data = [];
        stats.count = 0;
        stats.nanCount = 0;
        stats.mean = NaN;
        stats.std = NaN;
        stats.median = NaN;
        stats.q25 = NaN;
        stats.q75 = NaN;
        stats.min = NaN;
        stats.max = NaN;
        return;
    end
    
    data = double(data(:));
    stats.count = length(data);
    stats.nanCount = sum(isnan(data) | isinf(data));
    validData = data(~isnan(data) & ~isinf(data));
    
    if ~isempty(validData)
        stats.mean = mean(validData);
        stats.std = std(validData);
        stats.median = median(validData);
        stats.q25 = prctile(validData, 25);
        stats.q75 = prctile(validData, 75);
        stats.min = min(validData);
        stats.max = max(validData);
    else
        stats.mean = NaN;
        stats.std = NaN;
        stats.median = NaN;
        stats.q25 = NaN;
        stats.q75 = NaN;
        stats.min = NaN;
        stats.max = NaN;
    end
end
