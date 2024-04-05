function pleasantValues = findPleasantValues(minRange, maxRange)
    % Определение порядка величины диапазона
    magnitude = floor(log10(maxRange - minRange));
    
    % Определение множителя для "приятного" значения
    pleasantMultiplier = 10^magnitude;
    
    % Корректировка множителя для случаев, когда диапазон меньше 1
    if pleasantMultiplier < 1
        pleasantMultiplier = 1;
    end
    
    % Определение минимального "приятного" значения, кратного pleasantMultiplier, большего minRange
    startValue = ceil(minRange / pleasantMultiplier) * pleasantMultiplier;
    
    % Определение максимального "приятного" значения, кратного pleasantMultiplier, меньшего maxRange
    endValue = floor(maxRange / pleasantMultiplier) * pleasantMultiplier;
    
    % Расчет количества участков между startValue и endValue
    numSections = 9; % для 10 участков
    
    % Расчет шага между "приятными" значениями
    step = (endValue - startValue) / numSections;
    
    % Генерация 10 "приятных" значений на равном расстоянии
    pleasantValues = startValue:step:endValue;
    
    % Округление значений для обеспечения "приятности"
    if magnitude < 0
        % Для диапазонов меньше 1, округление до соответствующего количества знаков после запятой
        pleasantValues = round(pleasantValues, abs(magnitude));
    else
        % Для диапазонов больше или равных 1, округление до ближайшего "приятного" значения
        pleasantValues = round(pleasantValues / pleasantMultiplier) * pleasantMultiplier;
    end
end
