function y = smooth1(x, span, method)
%SMOOTH Сглаживание данных
%   Y = SMOOTH(X) сглаживает данные в векторе X используя метод 'moving'
%   с окном по умолчанию 5 точек.
%
%   Y = SMOOTH(X, SPAN) сглаживает данные с окном SPAN точек.
%
%   Y = SMOOTH(X, SPAN, METHOD) сглаживает данные используя указанный метод:
%       'moving' - скользящее среднее (по умолчанию)
%       'median' - медианный фильтр (medfilt1)
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

if ~isnumeric(span) || isempty(span)
    span = 5;
end
span = span(1);
if ~isfinite(span) || isnan(span)
    span = 5;
end
span = round(span);
if span < 5
    span = 5;
end

% Преобразование в столбец
x = x(:);
n = length(x);

% Ограничение span размером данных
span = min(span, n);

method = lower(method);
switch method
    case 'moving'
        y = movingAverage(x, span);
    case 'median'
        if mod(span, 2) == 0
            span = span + 1;
        end
        y = medfilt1(x, span);
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

