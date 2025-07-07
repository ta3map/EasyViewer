function [Zica, W, T, mu] = fastICAdialog(Z, r, type, method, TOL, MAX_ITERS, flag, seed)
% FASTICADIALOG - Реализация алгоритма FastICA с поддержкой методов 'parallel' и 'deflation'
% Теперь поддерживает опциональный параметр 'seed' для воспроизводимости.

Z = Z';

% Проверка и установка параметров по умолчанию
if ~exist('flag', 'var') || isempty(flag)
    flag = 1;
end
if ~exist('type', 'var') || isempty(type)
    type = 'tanh';
end
if ~exist('method', 'var') || isempty(method)
    method = 'parallel';
end
if ~exist('TOL', 'var') || isempty(TOL)
    TOL = 1e-6;
end
if ~exist('MAX_ITERS', 'var') || isempty(MAX_ITERS)
    MAX_ITERS = 1000;
end

% **Новый код: установка начального значения генератора случайных чисел**
if exist('seed', 'var') && ~isempty(seed)
    rngState = rng;        % Сохранение текущего состояния генератора
    rng(seed);             % Установка нового состояния генератора
    restoreRNG = true;     % Флаг для восстановления генератора позже
else
    restoreRNG = false;    % Генератор случайных чисел не менялся
end

n = size(Z, 2);

% Определение нелинейных функций
switch lower(type)
    case 'kurtosis'
        algoStr = 'kurtosis';
        G_func = @(Sk) 4 * Sk.^3;
        Gp_func = @(Sk) 12 * Sk.^2;
    case 'negentropy'
        algoStr = 'negentropy';
        G_func = @(Sk) Sk .* exp(-0.5 * Sk.^2);
        Gp_func = @(Sk) (1 - Sk.^2) .* exp(-0.5 * Sk.^2);
    case 'tanh'
        algoStr = 'tanh';
        a = 1;
        G_func = @(Sk) tanh(a * Sk);
        Gp_func = @(Sk) a * (1 - tanh(a * Sk).^2);
    case 'exp'
        algoStr = 'exp';
        G_func = @(Sk) Sk .* exp(-Sk.^2 / 2);
        Gp_func = @(Sk) (1 - Sk.^2) .* exp(-Sk.^2 / 2);
    otherwise
        error('Unsupported type ''%s''', type);
end

% Центрирование и белизна данных
[Zc, mu] = centerRows(Z);
[Zcw, T] = whitenRows(Zc);

% Нормализация строк до единичной нормы
normRows = @(X) bsxfun(@rdivide, X, sqrt(sum(X.^2, 2)));

% Инициализация весов
if strcmpi(method, 'parallel')
    W = normRows(randn(r, size(Zcw, 1)));  % Случайные начальные веса
else
    W = zeros(r, size(Zcw, 1));  % Для метода deflation
end

% Создание диалогового окна
if flag
    hFig = figure('Name', sprintf('Fast ICA (%s, %s)', algoStr, method), 'NumberTitle', 'off', 'MenuBar', 'none', 'ToolBar', 'none', 'Position', [100, 100, 400, 300]);
    hText = uicontrol('Style', 'text', 'Position', [10, 220, 380, 40], 'String', 'Starting...', 'HorizontalAlignment', 'left');
    hButton = uicontrol('Style', 'pushbutton', 'Position', [150, 20, 100, 30], 'String', 'Stop', 'Callback', 'setappdata(gcbf, ''stop'', 1);');
    hProgressBar = uicontrol('Style', 'text', 'Position', [10, 70, 380, 20], 'String', '', 'BackgroundColor', 'blue');
    hAx = axes('Position', [0.1, 0.4, 0.8, 0.3]);
    plot(hAx, 0, 0, 'r');
    xlabel(hAx, 'Iteration');
    ylabel(hAx, 'Delta');
    setappdata(hFig, 'stop', 0);
end

delta = inf;
k = 0;
deltas = [];

if strcmpi(method, 'parallel')
    % Параллельный метод FastICA
    W = normRows(randn(r, size(Zcw, 1)));  % Случайные начальные веса
    while delta > TOL && k < MAX_ITERS
        if flag && getappdata(hFig, 'stop'), break; end  % Проверка на остановку
        k = k + 1;
        Wlast = W;  % Сохранение предыдущего W

        % Вычисление сигналов
        Sk = W * Zcw;

        % Вычисление G(Sk) и G'(Sk)
        G = G_func(Sk);
        Gp = Gp_func(Sk);

        % Обновление весов
        W = (G * Zcw') / n - bsxfun(@times, mean(Gp, 2), W);

        % Симметричная декорреляция
        [E, D] = eig(W * W');
        W = (E * diag(1 ./ sqrt(diag(D))) * E') * W;

        % Критерий сходимости
        delta = max(abs(abs(dot(W, Wlast, 2)) - 1));
        deltas = [deltas; delta];

        % Обновление диалогового окна
        if flag
            set(hText, 'String', sprintf('Iter %d: delta = %.4g', k, delta));
            set(hProgressBar, 'Position', [10, 70, 380 * k / MAX_ITERS, 20]);
            plot(hAx, 1:k, deltas, 'r');
            xlabel(hAx, 'Iteration');
            ylabel(hAx, 'Delta');
            drawnow;
        end
    end
elseif strcmpi(method, 'deflation')
    % Метод дефляции FastICA
    for i = 1:r
        w = randn(size(Zcw, 1), 1);  % Случайный начальный вес
        w = w / norm(w);
        delta = inf;
        k = 0;
        while delta > TOL && k < MAX_ITERS
            if flag && getappdata(hFig, 'stop'), break; end  % Проверка на остановку
            k = k + 1;
            wlast = w;

            % Вычисление сигнала
            Sk = w' * Zcw;

            % Вычисление G(Sk) и G'(Sk)
            G = G_func(Sk);
            Gp = Gp_func(Sk);

            % Обновление веса
            w = (Zcw * G') / n - mean(Gp) * w;

            % Декорреляция с предыдущими компонентами
            if i > 1
                w = w - W(1:i-1, :)' * (W(1:i-1, :) * w);
            end

            % Нормализация веса
            w = w / norm(w);

            % Критерий сходимости
            delta = abs(abs(w' * wlast) - 1);

            % Обновление диалогового окна
            if flag
                set(hText, 'String', sprintf('Component %d, Iter %d: delta = %.4g', i, k, delta));
                set(hProgressBar, 'Position', [10, 70, 380 * k / MAX_ITERS, 20]);
                drawnow;
            end
        end
        W(i, :) = w';  % Сохранение веса

        % Обновление deltas
        deltas = [deltas; delta];
    end
else
    error('Unsupported method ''%s''', method);
end

if flag
    close(hFig);
end

% Восстановление состояния генератора случайных чисел, если это необходимо
if restoreRNG
    rng(rngState);
end

% Расчет независимых компонентов
Zica = (W * Zcw)';

end
