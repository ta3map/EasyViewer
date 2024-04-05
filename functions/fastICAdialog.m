function [Zica, W, T, mu] = fastICAdialog(Z, r, type, flag)

Z = Z';
% Сделано на основе функции от Brian Moore

TOL = 1e-6;         % Критерий сходимости
MAX_ITERS = 100;    % Максимальное количество итераций

% Проверка входных параметров
if ~exist('flag', 'var') || isempty(flag)
    flag = 1;  % Флаг отображения по умолчанию
end
if ~exist('type', 'var') || isempty(type)
    type = 'kurtosis';  % Тип по умолчанию
end

n = size(Z, 2);

% Определение типа алгоритма
if strncmpi(type, 'kurtosis', 1)
    USE_KURTOSIS = true;
    algoStr = 'kurtosis';
elseif strncmpi(type, 'negentropy', 1)
    USE_KURTOSIS = false;
    algoStr = 'negentropy';
else
    error('Unsupported type ''%s''', type);
end

% Центрирование и белизна данных
[Zc, mu] = centerRows(Z);
[Zcw, T] = whitenRows(Zc);

% Normalize rows to unit norm
normRows = @(X) bsxfun(@rdivide,X,sqrt(sum(X.^2,2)));

% Создание диалогового окна
if flag
    hFig = figure('Name', sprintf('Fast ICA (%s)', algoStr), 'NumberTitle', 'off', 'MenuBar', 'none', 'ToolBar', 'none', 'Position', [100, 100, 350, 150]);
    hText = uicontrol('Style', 'text', 'Position', [10, 80, 330, 40], 'String', 'Starting...', 'HorizontalAlignment', 'left');
    hButton = uicontrol('Style', 'pushbutton', 'Position', [125, 20, 100, 30], 'String', 'Stop', 'Callback', 'setappdata(gcbf, ''stop'', 1);');
    setappdata(hFig, 'stop', 0);
end

W = normRows(rand(r, size(Z, 1)));  % Случайные начальные веса
k = 0;
delta = inf;
while delta > TOL && k < MAX_ITERS
    if getappdata(hFig, 'stop'), break; end  % Проверка на остановку
    k = k + 1;
    
    % Update weights
    Wlast = W; % Save last weights
    Sk = W * Zcw;
    if USE_KURTOSIS
        % Kurtosis
        G = 4 * Sk.^3;
        Gp = 12 * Sk.^2;
    else
        % Negentropy
        G = Sk .* exp(-0.5 * Sk.^2);
        Gp = (1 - Sk.^2) .* exp(-0.5 * Sk.^2);
    end
    W = (G * Zcw') / n - bsxfun(@times,mean(Gp,2),W);
    W = normRows(W);
    
    % Decorrelate weights
    [U, S, ~] = svd(W,'econ');
    W = U * diag(1 ./ diag(S)) * U' * W;
    
    % Update convergence criteria
    delta = max(1 - abs(dot(W,Wlast,2)));
    
    % Обновление диалогового окна
    if flag
        set(hText, 'String', sprintf('Iter %d: max(1 - |<w%d, w%d>|) = %.4g', k, k, k - 1, delta));
        drawnow;  % Обновление интерфейса
    end
end

if flag
    close(hFig);  % Закрытие диалогового окна
end

% Расчет независимых компонентов...
Zica = (W * Zcw)';
end
