function data_out = removeStimArtifact(data_in, stims, time, win_r)

data_out = data_in;
% Убираем артефакт стимула
if ~isempty(stims) && win_r ~= 0
    stim_inxs = ClosestIndex(stims, time); % Индекс стимулов
    % win_r  Размер окна в индекс формате

    for i = 1:length(stim_inxs)
        start_inx = stim_inxs(i) - win_r;
        end_inx = stim_inxs(i) + win_r;

        % Убедитесь, что индексы не выходят за пределы данных
        if start_inx > 1 && end_inx < size(data_in, 1)
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
        end
    end
end