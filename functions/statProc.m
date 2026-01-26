function stats = statProc(data)
% statProc - Расчет статистики для любого числового вектора
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
%     iqr - межквартильный размах (q75 - q25)
%     mad - медианное абсолютное отклонение
%     min - минимальное значение
%     max - максимальное значение
%     string - форматированная строка: "median (q25 − q75)"
%     s_par - форматированная строка: "mean (+- std)"
%     data - валидные данные (без NaN и Inf)

    stats = struct();
    
    if isempty(data)
        stats.count = 0;
        stats.nanCount = 0;
        stats.mean = NaN;
        stats.std = NaN;
        stats.median = NaN;
        stats.q25 = NaN;
        stats.q75 = NaN;
        stats.iqr = NaN;
        stats.mad = NaN;
        stats.min = NaN;
        stats.max = NaN;
        stats.string = {''};
        stats.s_par = {''};
        stats.data = [];
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
        stats.iqr = NaN;
        stats.mad = NaN;
        stats.min = NaN;
        stats.max = NaN;
        stats.string = {''};
        stats.s_par = {''};
        stats.data = [];
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
        stats.iqr = stats.q75 - stats.q25;
        stats.mad = mad(validData, 1);
        stats.min = min(validData);
        stats.max = max(validData);
        stats.string = {[num2str(stats.median, 4) ' (' num2str(stats.q25, 4) ' − ' num2str(stats.q75, 4) ')']};
        stats.s_par = {[num2str(stats.mean, 4) ' (+-' num2str(stats.std, 4) ')']};
        stats.data = validData;
    else
        stats.mean = NaN;
        stats.std = NaN;
        stats.median = NaN;
        stats.q25 = NaN;
        stats.q75 = NaN;
        stats.iqr = NaN;
        stats.mad = NaN;
        stats.min = NaN;
        stats.max = NaN;
        stats.string = {''};
        stats.s_par = {''};
        stats.data = [];
    end
end
