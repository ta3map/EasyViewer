function data_out = removeStimArtifact(data_in, stims, time, win_r)
% Убираем артефакт стимула путем линейной интерполяции
% data_in - входные данные (столбец или матрица)
% stims - время стимулов (массив)
% time - временная ось
% win_r - половина окна удаления (в индексах)

    % % fprintf('DEBUG: removeStimArtifact - входные параметры:\n');
    % fprintf('  - Размер data_in: %s\n', mat2str(size(data_in)));
    % fprintf('  - Стимулы: %s\n', mat2str(stims));
    % fprintf('  - Размер time: %s\n', mat2str(size(time)));
    % fprintf('  - win_r: %.3f\n', win_r);

% Проверка входных данных
if ~isnumeric(data_in) | ~isnumeric(stims) | ~isnumeric(time) | ~isnumeric(win_r)
    error('Все входные параметры должны быть числовыми');
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
            % Проходим по каждому столбцу и применяем линейную интерполяцию
            for col = 1:size(data_in, 2)
                % Используем стартовое и конечное значения для интерполяции
                start_val = data_in(start_inx-1, col);
                end_val = data_in(end_inx+1, col);
                
                % Генерируем линейно интерполированные значения
                interpolated_vals = linspace(start_val, end_val, end_inx-start_inx+3)';
                
                % Заменяем данные в текущем столбце
                data_out(start_inx:end_inx, col) = interpolated_vals(2:end-1);
            end
            % % fprintf('DEBUG: Интерполяция выполнена для окна [%d, %d]\n', start_inx, end_inx);
        else
            % % fprintf('DEBUG: Пропуск стимула %d - окно выходит за границы данных\n', i);
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