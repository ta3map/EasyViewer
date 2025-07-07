function csd = globalCSD(lfp, allowed_ch_inxs)
    % Инициализация результата CSD размером как LFP, заполненного NaN
    csd = zeros(size(lfp));

    % Инициализация waitbar
    h = waitbar(0, 'Calculating CSD...');

    % Общее количество шагов для обновления waitbar
    totalSteps = length(allowed_ch_inxs);

    % Расчет CSD только для разрешенных каналов
    for i = 1:totalSteps
        ch_idx = allowed_ch_inxs(i);
        % Убедимся, что мы не на краю, чтобы избежать выхода за границы
        if any(ch_idx == [1, size(lfp, 2)])
            continue; % Пропускаем крайние каналы
        else
            % Вычисление CSD как второй пространственной производной
            csd(:, ch_idx) = lfp(:, ch_idx-1) - 2 * lfp(:, ch_idx) + lfp(:, ch_idx+1);
        end

        % Обновление waitbar
        waitbar(i / totalSteps, h);
    end

    % Закрытие waitbar по завершении
    close(h);
end
