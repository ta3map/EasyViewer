    function filteredData = applyFilter(data, filterSettings, Fs)
        % Входные данные:
        % data - мультиканальные данные для фильтрации
        % filterSettings - структура с настройками фильтра:
        %    filterSettings.filterType - тип фильтра ('lowpass', 'highpass', 'bandpass')
        %    filterSettings.freqLow - нижняя граница частоты (для 'bandpass' и 'highpass')
        %    filterSettings.freqHigh - верхняя граница частоты (для 'bandpass' и 'lowpass')
        % Fs - частота дискретизации сигнала

        % Инициализация выходных данных
        filteredData = zeros(size(data));

        % Параметры фильтра
        order = filterSettings.order; % Порядок фильтра

        % Создание фильтра в зависимости от типа
        switch filterSettings.filterType
            case 'lowpass'
                [b, a] = butter(order, filterSettings.freqHigh/(Fs/2), 'low');
            case 'highpass'
                [b, a] = butter(order, filterSettings.freqLow/(Fs/2), 'high');
            case 'bandpass'
                [b, a] = butter(order, [filterSettings.freqLow filterSettings.freqHigh]/(Fs/2), 'bandpass');
        end
        
        % Применение фильтра ко всем выбранным каналам
        % убираем краевые эффекты через отражение сигнала
        reflectionLength = round(size(data,1)*0.10);
        for ch = 1:size(data, 2)
            % Отражение сигнала
            reflectedSignal = [flipud(data(1:reflectionLength, ch)); data(:, ch); flipud(data(end-reflectionLength+1:end, ch))];

            % Фильтрация отраженного сигнала
            filteredReflectedSignal = filtfilt(b, a, double(reflectedSignal));

            % Удаление отраженных частей, возвращая сигнал к исходной длине
            filteredData(:, ch) = filteredReflectedSignal(reflectionLength+1:end-reflectionLength);
        end
    
        % старый метод без отражения
%         for ch = 1:size(data, 2)
%             % Используйте filtfilt для фильтрации без фазового сдвига
%             filteredData(:, ch) = filtfilt(b, a, double(data(:, ch)));
%         end

        % Возвращение отфильтрованных данных
    end