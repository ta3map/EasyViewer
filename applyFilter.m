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
        for ch = 1:size(data, 2)
            % Используйте filtfilt для фильтрации без фазового сдвига
            filteredData(:, ch) = filtfilt(b, a, double(data(:, ch)));
        end

        % Возвращение отфильтрованных данных
    end