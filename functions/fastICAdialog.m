function [Zica, W, T, mu] = fastICAdialog(Z, r, type, TOL, MAX_ITERS, flag)

Z = Z';
% Сделано на основе функции от Brian Moore

% TOL = 1e-6;         % Критерий сходимости
% MAX_ITERS = 1000;    % Максимальное количество итераций

% Проверка входных параметров
if ~exist('flag', 'var') || isempty(flag)
    flag = 1;  % Флаг отображения по умолчанию
end
if ~exist('type', 'var') || isempty(type)
    type = 'kurtosis';  % Тип по умолчанию
end

n = size(Z, 2);

% Определение типа алгоритма
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
        G_func = @(Sk) -exp(-Sk.^2 / 2);
        Gp_func = @(Sk) Sk .* exp(-Sk.^2 / 2);
    otherwise
        error('Unsupported type ''%s''', type);
end

% Центрирование и белизна данных
[Zc, mu] = centerRows(Z);
[Zcw, T] = whitenRows(Zc);

% Normalize rows to unit norm
normRows = @(X) bsxfun(@rdivide,X,sqrt(sum(X.^2,2)));

% Создание диалогового окна
if flag
    hFig = figure('Name', sprintf('Fast ICA (%s)', algoStr), 'NumberTitle', 'off', 'MenuBar', 'none', 'ToolBar', 'none', 'Position', [100, 100, 400, 300]);
    hText = uicontrol('Style', 'text', 'Position', [10, 220, 380, 40], 'String', 'Starting...', 'HorizontalAlignment', 'left');
    hButton = uicontrol('Style', 'pushbutton', 'Position', [150, 20, 100, 30], 'String', 'Stop', 'Callback', 'setappdata(gcbf, ''stop'', 1);');
    hProgressBar = uicontrol('Style', 'text', 'Position', [10, 70, 380, 20], 'String', '', 'BackgroundColor', 'blue');
    hAx = axes('Position', [0.1, 0.4, 0.8, 0.3]);
    plot(hAx, 0, 0, 'r');
    xlabel(hAx, 'Iteration');
    ylabel(hAx, 'Delta');
    setappdata(hFig, 'stop', 0);
end

W = normRows(rand(r, size(Z, 1)));  % Случайные начальные веса
k = 0;
delta = inf;
deltas = [];
while delta > TOL && k < MAX_ITERS
    if getappdata(hFig, 'stop'), break; end  % Проверка на остановку
    k = k + 1;
    
    % Update weights
    Wlast = W; % Save last weights
    Sk = W * Zcw;
    G = G_func(Sk);
    Gp = Gp_func(Sk);
    W = (G * Zcw') / n - bsxfun(@times,mean(Gp,2),W);
    W = normRows(W);
    
    % Decorrelate weights
    [U, S, ~] = svd(W,'econ');
    W = U * diag(1 ./ diag(S)) * U' * W;
    
    % Update convergence criteria
    delta = max(1 - abs(dot(W,Wlast,2)));
    deltas = [deltas; delta];
    
    % Обновление диалогового окна
    if flag
        set(hText, 'String', sprintf('Iter %d: max(1 - |<w%d, w%d>|) = %.4g', k, k, k - 1, delta));
        set(hProgressBar, 'Position', [10, 70, 380 * k / MAX_ITERS, 20]);
        plot(hAx, 1:k, deltas, 'r');
        xlabel(hAx, 'Iteration');
        ylabel(hAx, 'Delta');
        drawnow;  % Обновление интерфейса
    end
end

if flag
    close(hFig);  % Закрытие диалогового окна
end

% Расчет независимых компонентов...
Zica = (W * Zcw)';
end
