function y = smooth1(x, span, method)
%SMOOTH Сглаживание данных
%   Y = SMOOTH(X) сглаживает данные в векторе X используя метод 'moving'
%   с окном по умолчанию 5 точек.
%
%   Y = SMOOTH(X, SPAN) сглаживает данные с окном SPAN точек.
%
%   Y = SMOOTH(X, SPAN, METHOD) сглаживает данные используя указанный метод:
%       'moving'   - скользящее среднее (по умолчанию)
%       'lowess'   - локально взвешенная регрессия
%       'loess'    - локально взвешенная регрессия (степень 2)
%       'sgolay'   - фильтр Савицкого-Голея
%       'rlowess'  - устойчивая локально взвешенная регрессия
%       'rloess'   - устойчивая локально взвешенная регрессия (степень 2)
%
%   Примеры:
%       y = smooth(randn(100,1));
%       y = smooth(randn(100,1), 10);
%       y = smooth(randn(100,1), 10, 'lowess');

% Обработка входных аргументов
if nargin < 1
    error('Недостаточно входных аргументов');
end

if nargin < 2
    span = 5;
end

if nargin < 3
    method = 'moving';
end

% Проверка входных данных
if ~isvector(x) || length(x) < 3
    error('X должен быть вектором с минимум 3 элементами');
end

if span < 3
    error('SPAN должен быть не менее 3');
end

% Преобразование в столбец
x = x(:);
n = length(x);

% Ограничение span размером данных
span = min(span, n);

% Выбор метода сглаживания
switch lower(method)
    case 'moving'
        y = movingAverage(x, span);
    case 'lowess'
        y = lowess(x, span);
    case 'loess'
        y = loess(x, span);
    case 'sgolay'
        y = sgolay(x, span);
    case 'rlowess'
        y = rlowess(x, span);
    case 'rloess'
        y = rloess(x, span);
    otherwise
        error('Неизвестный метод сглаживания: %s', method);
end

end

function y = movingAverage(x, span)
% Скользящее среднее
n = length(x);
y = zeros(n, 1);

halfSpan = floor(span / 2);

for i = 1:n
    startIdx = max(1, i - halfSpan);
    endIdx = min(n, i + halfSpan);
    y(i) = mean(x(startIdx:endIdx));
end
end

function y = lowess(x, span)
% Локально взвешенная регрессия (степень 1)
y = localRegression(x, span, 1);
end

function y = loess(x, span)
% Локально взвешенная регрессия (степень 2)
y = localRegression(x, span, 2);
end

function y = localRegression(x, span, degree)
% Локально взвешенная регрессия
n = length(x);
y = zeros(n, 1);

halfSpan = floor(span / 2);

for i = 1:n
    startIdx = max(1, i - halfSpan);
    endIdx = min(n, i + halfSpan);
    
    % Индексы для локальной области
    localIdx = startIdx:endIdx;
    localX = localIdx';
    localY = x(localIdx);
    
    % Трикубические веса
    distances = abs(localX - i);
    maxDist = max(distances);
    if maxDist > 0
        weights = (1 - (distances / maxDist).^3).^3;
    else
        weights = ones(size(localX));
    end
    
    % Полиномиальная регрессия с весами
    if degree == 1
        % Линейная регрессия
        X = [ones(length(localX), 1), localX];
    else
        % Квадратичная регрессия
        X = [ones(length(localX), 1), localX, localX.^2];
    end
    
    % Взвешенные нормальные уравнения
    W = diag(weights);
    coeffs = (X' * W * X) \ (X' * W * localY);
    
    % Предсказание для точки i
    if degree == 1
        y(i) = coeffs(1) + coeffs(2) * i;
    else
        y(i) = coeffs(1) + coeffs(2) * i + coeffs(3) * i^2;
    end
end
end

function y = sgolay(x, span)
% Фильтр Савицкого-Голея
n = length(x);
y = zeros(n, 1);

halfSpan = floor(span / 2);
degree = min(3, span - 1); % Степень полинома

for i = 1:n
    startIdx = max(1, i - halfSpan);
    endIdx = min(n, i + halfSpan);
    
    localIdx = startIdx:endIdx;
    localY = x(localIdx);
    
    % Центрирование индексов
    centerIdx = i - startIdx + 1;
    centeredIdx = (1:length(localIdx))' - centerIdx;
    
    % Полиномиальная регрессия
    X = ones(length(centeredIdx), degree + 1);
    for d = 1:degree
        X(:, d + 1) = centeredIdx.^d;
    end
    
    coeffs = X \ localY;
    y(i) = coeffs(1); % Константный член
end
end

function y = rlowess(x, span)
% Устойчивая локально взвешенная регрессия (степень 1)
y = robustLocalRegression(x, span, 1);
end

function y = rloess(x, span)
% Устойчивая локально взвешенная регрессия (степень 2)
y = robustLocalRegression(x, span, 2);
end

function y = robustLocalRegression(x, span, degree)
% Устойчивая локально взвешенная регрессия
n = length(x);
y = zeros(n, 1);

halfSpan = floor(span / 2);

for i = 1:n
    startIdx = max(1, i - halfSpan);
    endIdx = min(n, i + halfSpan);
    
    localIdx = startIdx:endIdx;
    localX = localIdx';
    localY = x(localIdx);
    
    % Итеративная процедура с весами
    maxIter = 5;
    weights = ones(size(localY));
    
    for iter = 1:maxIter
        % Трикубические веса по расстоянию
        distances = abs(localX - i);
        maxDist = max(distances);
        if maxDist > 0
            distWeights = (1 - (distances / maxDist).^3).^3;
        else
            distWeights = ones(size(localX));
        end
        
        % Объединенные веса
        totalWeights = weights .* distWeights;
        
        % Полиномиальная регрессия
        if degree == 1
            X = [ones(length(localX), 1), localX];
        else
            X = [ones(length(localX), 1), localX, localX.^2];
        end
        
        W = diag(totalWeights);
        coeffs = (X' * W * X) \ (X' * W * localY);
        
        % Предсказание
        if degree == 1
            pred = coeffs(1) + coeffs(2) * localX;
        else
            pred = coeffs(1) + coeffs(2) * localX + coeffs(3) * localX.^2;
        end
        
        % Остатки
        residuals = abs(localY - pred);
        medianResidual = median(residuals);
        
        if medianResidual > 0
            % Биквадратные веса для остатков
            weights = (1 - min(residuals / (6 * medianResidual), 1).^2).^2;
        else
            break;
        end
    end
    
    % Финальное предсказание для точки i
    if degree == 1
        y(i) = coeffs(1) + coeffs(2) * i;
    else
        y(i) = coeffs(1) + coeffs(2) * i + coeffs(3) * i^2;
    end
end
end
