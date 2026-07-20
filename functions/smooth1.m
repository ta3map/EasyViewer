function y = smooth1(x, span, method)
%SMOOTH1 Сглаживание данных
%   Y = SMOOTH1(X) — скользящее среднее, окно 5 точек.
%   Y = SMOOTH1(X, SPAN) — окно SPAN точек.
%   Y = SMOOTH1(X, SPAN, METHOD):
%       'moving' — movmean (по умолчанию)
%       'median' — medfilt1

if nargin < 1
    error('Недостаточно входных аргументов');
end

if nargin < 2
    span = 5;
end

if nargin < 3
    method = 'moving';
end

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

wasRow = isrow(x);
x = x(:);
span = min(span, length(x));

method = lower(method);
switch method
    case 'moving'
        y = movmean(x, span, 'Endpoints', 'shrink');
    case 'median'
        if mod(span, 2) == 0
            span = span + 1;
        end
        y = medfilt1(x, span);
    otherwise
        error('Неизвестный метод сглаживания: %s', method);
end

if wasRow
    y = y.';
end

end
