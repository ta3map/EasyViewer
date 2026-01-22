function data_out = removeStimArtifact(data_in, stims, time, win_r, method)
% Убираем артефакт стимула путем сглаженной интерполяции
% data_in - входные данные (столбец или матрица)
% stims - время стимулов (массив)
% time - временная ось
% win_r - половина окна удаления (в индексах)
% method - метод интерполяции: 'spline' (по умолчанию), 'median', 'pchip', 'linear', 'smooth'

    % % fprintf('DEBUG: removeStimArtifact - входные параметры:\n');
    % fprintf('  - Размер data_in: %s\n', mat2str(size(data_in)));
    % fprintf('  - Стимулы: %s\n', mat2str(stims));
    % fprintf('  - Размер time: %s\n', mat2str(size(time)));
    % fprintf('  - win_r: %.3f\n', win_r);

% Проверка входных данных
if ~isnumeric(data_in) | ~isnumeric(stims) | ~isnumeric(time) | ~isnumeric(win_r)
    error('Все входные параметры должны быть числовыми');
end

% Метод интерполяции по умолчанию
if nargin < 5 || isempty(method)
    method = 'spline';
end

% Убеждаемся, что stims - массив
if isscalar(stims)
    stims = [stims];
end

% Убеждаемся, что data_in - столбец или матрица
if size(data_in, 2) > size(data_in, 1)
    data_in = data_in';
    % % fprintf('DEBUG: data_in транспонирован в столбец\n');
end

% Убеждаемся, что time - вектор
if size(time, 2) > size(time, 1)
    time = time';
    % % fprintf('DEBUG: time транспонирован в столбец\n');
end

data_out = data_in;

% Убираем артефакт стимула
if ~isempty(stims) & win_r ~= 0
    stim_inxs = ClosestIndex(stims, time); % Индекс стимулов
    % % fprintf('DEBUG: Найдены индексы стимулов: %s\n', mat2str(stim_inxs));
    
    % Округляем win_r до целого числа
    win_r = round(win_r);
    
    for i = 1:length(stim_inxs)
        start_inx = stim_inxs(i) - win_r;
        end_inx = stim_inxs(i) + win_r;
        
        % % fprintf('DEBUG: Обработка стимула %d - окно [%d, %d]\n', i, start_inx, end_inx);
        
        % Убедитесь, что индексы не выходят за пределы данных
        if start_inx > 1 & end_inx < size(data_in, 1)
            % Расширяем окно для более плавного перехода (минимум 3 точки с каждой стороны)
            extend_win = max(3, round(win_r * 0.5));
            left_extend = max(1, start_inx - extend_win);
            right_extend = min(size(data_in, 1), end_inx + extend_win);
            
            % Проходим по каждому столбцу и применяем сглаженную интерполяцию
            for col = 1:size(data_in, 2)
                % Точки для интерполяции (до и после окна артефакта)
                x_before = time(left_extend:start_inx-1);
                x_after = time(end_inx+1:right_extend);
                y_before = data_in(left_extend:start_inx-1, col);
                y_after = data_in(end_inx+1:right_extend, col);
                
                % Временные точки для интерполяции
                x_interp = time(start_inx:end_inx);
                
                % Выбираем метод интерполяции
                switch lower(method)
                    case 'pchip'
                        % Кубическая интерполяция Эрмита - гладкая, без осцилляций
                        x_all = [x_before; x_after];
                        y_all = [y_before; y_after];
                        interpolated_vals = pchip(x_all, y_all, x_interp);
                        
                    case 'spline'
                        % Кубический сплайн - очень гладкая, но может осциллировать
                        x_all = [x_before; x_after];
                        y_all = [y_before; y_after];
                        interpolated_vals = spline(x_all, y_all, x_interp);
                        
                    case 'smooth'
                        % Линейная интерполяция + сглаживание краев
                        start_val = data_in(start_inx-1, col);
                        end_val = data_in(end_inx+1, col);
                        linear_vals = linspace(start_val, end_val, length(x_interp))';
                        
                        % Создаем плавный переход на краях
                        n_points = length(x_interp);
                        edge_points = max(3, round(n_points * 0.2));
                        window = ones(n_points, 1);
                        
                        % Плавное затухание на краях
                        for j = 1:edge_points
                            alpha = (j - 1) / edge_points;
                            window(j) = alpha;
                            window(n_points - j + 1) = alpha;
                        end
                        
                        % Смешиваем линейную интерполяцию с исходными данными на краях
                        original_vals = data_in(start_inx:end_inx, col);
                        interpolated_vals = linear_vals .* window + original_vals .* (1 - window);
                        
                        % Легкое сглаживание
                        n_smooth = max(5, min(round(n_points/3), n_points));
                        interpolated_vals = smooth1(interpolated_vals, n_smooth, 'moving');
                        
                    case 'median'
                        % Замена медианой из небольших окон слева и справа от артефакта
                        % Размер окна для медианы (небольшое окно, не весь сигнал)
                        median_win = max(5, round(win_r * 0.5));
                        
                        % Фиксированные окна слева и справа от всего артефакта
                        left_win_start = max(1, start_inx - win_r - median_win);
                        left_win_end = start_inx - 1;
                        right_win_start = end_inx + 1;
                        right_win_end = min(size(data_in, 1), end_inx + win_r + median_win);
                        
                        % Берем данные из окон слева и справа
                        left_data = data_in(left_win_start:left_win_end, col);
                        right_data = data_in(right_win_start:right_win_end, col);
                        
                        % Объединяем данные из обоих окон
                        reference_data = [left_data; right_data];
                        
                        % Вычисляем одно медианное значение для всего артефакта
                        median_val = median(reference_data);
                        
                        % Заменяем все точки артефакта на это медианное значение
                        n_points = length(x_interp);
                        interpolated_vals = repmat(median_val, n_points, 1);
                        
                    otherwise
                        % Линейная интерполяция (старый метод)
                        start_val = data_in(start_inx-1, col);
                        end_val = data_in(end_inx+1, col);
                        interpolated_vals = linspace(start_val, end_val, length(x_interp))';
                end
                
                % Заменяем данные в текущем столбце
                data_out(start_inx:end_inx, col) = interpolated_vals;
            end
        end
    end
end

% Возвращаем в исходную ориентацию если нужно
if size(data_in, 2) > size(data_in, 1)
    data_out = data_out';
    % % fprintf('DEBUG: data_out транспонирован обратно в строку\n');
end

% % fprintf('DEBUG: removeStimArtifact завершен\n');
end