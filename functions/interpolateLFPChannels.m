function lfpInterpolated = interpolateLFPChannels(lfp, ch_inxs)
    numChannels = size(lfp, 2); % Количество каналов
    allChannels = 1:numChannels; % Все каналы
    invalidChannels = setdiff(allChannels, ch_inxs); % Недопустимые каналы
    
    lfpInterpolated = lfp; % Создаем копию исходной матрицы для интерполяции
    
    for ch = invalidChannels
        % Найти ближайшие допустимые каналы слева и справа
        validChannelsLeft = ch_inxs(ch_inxs < ch);
        validChannelsRight = ch_inxs(ch_inxs > ch);
        
        if isempty(validChannelsLeft)
            % Если слева нет допустимых каналов, используем ближайший справа
            nearestChannel = min(validChannelsRight);
        elseif isempty(validChannelsRight)
            % Если справа нет допустимых каналов, используем ближайший слева
            nearestChannel = max(validChannelsLeft);
        else
            % Если есть допустимые каналы с обеих сторон, интерполируем
            nearestChannelLeft = max(validChannelsLeft);
            nearestChannelRight = min(validChannelsRight);
            lfpInterpolated(:, ch) = mean([lfp(:, nearestChannelLeft), lfp(:, nearestChannelRight)], 2);
            continue;
        end
        
        % Заполнить недопустимый канал данными из ближайшего допустимого канала
        lfpInterpolated(:, ch) = lfp(:, nearestChannel);
    end
end
