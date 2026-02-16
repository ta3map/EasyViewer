function [baselineData, postStimData, fullTrialData, timeAxis] = extractTrialData(lfp, time, Fs, N, stims, xLimits, timeUnitFactor, removeBaseline, removeArtifact, artifactWindow_ms, startTrial, endTrial, removeEdgeTrials, artifactInterpMethod)
    % Извлекает данные по триалам вокруг стимулов с разделением на baseline и post-stimulus
    % 
    % Входные параметры:
    %   lfp - матрица данных (samples × channels)
    %   time - временная ось (в секундах)
    %   Fs - частота дискретизации
    %   N - количество отсчетов
    %   stims - массив временных точек стимулов (в секундах)
    %   xLimits - диапазон нарезки [start, end] в масштабированных единицах
    %   timeUnitFactor - коэффициент масштабирования времени
    %   removeBaseline - флаг удаления базовой линии
    %   removeArtifact - флаг удаления артефакта стимула
    %   artifactWindow_ms - окно удаления артефакта в миллисекундах
    %   startTrial - опционально: начальный индекс триала (по умолчанию 1)
    %   endTrial - опционально: конечный индекс триала (по умолчанию numStims)
    %   removeEdgeTrials - опционально: флаг удаления краевых триалов вместо ротации (по умолчанию false)
    %
    % Выходные данные:
    %   baselineData - массив триалов baseline (trials × timepoints × channels)
    %   postStimData - массив триалов post-stimulus (trials × timepoints × channels)
    %   fullTrialData - массив полных триалов для всего окна (trials × timepoints × channels)
    %   timeAxis - временная ось для одного триала (относительно стимула, в секундах)
    
    if isempty(stims)
        error('stims is empty');
    end
    
    % Вычисляем окно из xLimits
    xLimitsSeconds = xLimits / timeUnitFactor;
    windowStart_relative = xLimitsSeconds(1); % начало окна относительно стимула (отрицательное)
    windowEnd_relative = xLimitsSeconds(2);   % конец окна относительно стимула (положительное)
    meanWindow = windowEnd_relative - windowStart_relative; % полная ширина окна
    
    if nargin < 14
        artifactInterpMethod = 'linear';
    elseif isempty(artifactInterpMethod)
        artifactInterpMethod = 'linear';
    end
    % Удаление артефакта стимула до нарезки
    if removeArtifact && artifactWindow_ms > 0
        win_r = round(artifactWindow_ms * (Fs/1000));
        lfp = removeStimArtifact(lfp, stims, time, win_r, artifactInterpMethod);
    end
    
    numStims = length(stims);
    numChannels = size(lfp, 2);
    
    % Определяем диапазон триалов для анализа
    if nargin < 11 || isempty(startTrial)
        startTrial = 1;
    end
    if nargin < 12 || isempty(endTrial)
        endTrial = numStims;
    end
    if nargin < 13 || isempty(removeEdgeTrials)
        removeEdgeTrials = false;
    end
    
    % Валидация индексов
    startTrial = max(1, min(startTrial, numStims));
    endTrial = max(startTrial, min(endTrial, numStims));
    
    % Предварительное выделение памяти (оценка размера)
    windowSize = round(meanWindow * Fs);
    baselineTrials = {};
    postStimTrials = {};
    fullTrials = {};
    
    % Вычисляем требуемое количество точек для окна
    requiredSamples = round(meanWindow * Fs);
    timeAxis = linspace(windowStart_relative, windowEnd_relative, requiredSamples)';
    
    % Извлечение данных по триалам
    for i = startTrial:endTrial
        eventIdx = round(stims(i) * Fs);
        
        % Вычисляем индексы окна
        windowStart_abs = eventIdx + round(windowStart_relative * Fs);
        windowEnd_abs = eventIdx + round(windowEnd_relative * Fs);
        
        % Выбор режима обработки краевых триалов
        switch removeEdgeTrials
            case true
                [eventDataRaw, shouldSkip] = extractTrialSkip(...
                    lfp, windowStart_abs, windowEnd_abs, requiredSamples, numChannels, N);
                if shouldSkip
                    continue;
                end
                
            case false
                eventDataRaw = extractTrialWrap(...
                    lfp, windowStart_abs, requiredSamples, numChannels, N);
        end
        
        % Удаление базовой линии (медиана)
        if removeBaseline
            eventDataProcessed = eventDataRaw - nanmedian(eventDataRaw, 1);
        else
            eventDataProcessed = eventDataRaw;
        end
        
        % Разделение на baseline и post-stimulus по знаку времени
        baselineIdx = timeAxis <= 0;
        postStimIdx = timeAxis > 0;
        
        baselineTrial = eventDataProcessed(baselineIdx, :);
        postStimTrial = eventDataProcessed(postStimIdx, :);
        
        baselineTrials{end+1} = baselineTrial;
        postStimTrials{end+1} = postStimTrial;
        fullTrials{end+1} = eventDataProcessed; % Полный триал для всего окна
    end
    
    if isempty(baselineTrials)
        error('No valid trials extracted');
    end
    
    % Определяем максимальные размеры для выравнивания
    maxBaselineSize = 0;
    maxPostStimSize = 0;
    maxFullSize = 0;
    for i = 1:length(baselineTrials)
        maxBaselineSize = max(maxBaselineSize, size(baselineTrials{i}, 1));
        maxPostStimSize = max(maxPostStimSize, size(postStimTrials{i}, 1));
        maxFullSize = max(maxFullSize, size(fullTrials{i}, 1));
    end
    
    % Временная ось уже создана выше на основе xLimits
    % timeAxis создан как linspace(windowStart_relative, windowEnd_relative, requiredSamples)'
    
    % Создаем массивы данных (trials × timepoints × channels)
    numTrials = length(baselineTrials);
    baselineData = nan(numTrials, maxBaselineSize, numChannels);
    postStimData = nan(numTrials, maxPostStimSize, numChannels);
    fullTrialData = nan(numTrials, maxFullSize, numChannels);
    
    for i = 1:numTrials
        baselineTrial = baselineTrials{i};
        postStimTrial = postStimTrials{i};
        fullTrial = fullTrials{i};
        
        baselineData(i, 1:size(baselineTrial, 1), :) = baselineTrial;
        postStimData(i, 1:size(postStimTrial, 1), :) = postStimTrial;
        fullTrialData(i, 1:size(fullTrial, 1), :) = fullTrial;
    end
end

function [eventDataRaw, shouldSkip] = extractTrialSkip(lfp, windowStart_abs, windowEnd_abs, requiredSamples, numChannels, N)
    % Извлекает данные триала без циклического закольцовывания
    % Если триал выходит за границы данных, возвращает shouldSkip = true
    
    shouldSkip = false;
    
    % Проверяем, выходит ли триал за границы данных
    if windowStart_abs < 1 || windowEnd_abs > N
        shouldSkip = true;
        eventDataRaw = nan(requiredSamples, numChannels);
        return;
    end
    
    % Инициализируем массив для триала
    eventDataRaw = nan(requiredSamples, numChannels);
    
    % Простое извлечение без ротации (триалы уже проверены на границы)
    for sample = 1:requiredSamples
        absIdx = windowStart_abs + sample - 1;
        if absIdx >= 1 && absIdx <= N
            eventDataRaw(sample, :) = lfp(absIdx, :);
        end
    end
end

function eventDataRaw = extractTrialWrap(lfp, windowStart_abs, requiredSamples, numChannels, N)
    % Извлекает данные триала с циклическим закольцовыванием
    
    % Инициализируем массив для триала
    eventDataRaw = nan(requiredSamples, numChannels);
    
    % Заполняем данные с циклическим закольцовыванием
    for sample = 1:requiredSamples
        absIdx = windowStart_abs + sample - 1;
        
        if absIdx < 1
            % Выход за начало: берем с конца данных (циклическое закольцовывание)
            wrappedIdx = N + absIdx;
            if wrappedIdx < 1
                wrappedIdx = 1; % fallback
            end
            eventDataRaw(sample, :) = lfp(wrappedIdx, :);
        elseif absIdx > N
            % Выход за конец: берем с начала данных (циклическое закольцовывание)
            wrappedIdx = absIdx - N;
            if wrappedIdx > N
                wrappedIdx = N; % fallback
            end
            eventDataRaw(sample, :) = lfp(wrappedIdx, :);
        else
            % Нормальный случай: данные в пределах
            eventDataRaw(sample, :) = lfp(absIdx, :);
        end
    end
end
