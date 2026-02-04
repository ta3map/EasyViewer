function addResultsTable(fig, events, calcResult)
    % Добавляет таблицу с результатами детекции в фигуру
    % fig - handle фигуры
    % events - структура с событиями
    % calcResult - результат расчета средних данных
    
    figure(fig);
    
    % Находим tiledlayout в фигуре
    t = findobj(fig, 'Type', 'tiledlayout');
    if isempty(t)
        return;
    end
    
    % Используем nexttile для добавления тайла для таблицы
    tableAx = nexttile(t);
    axis(tableAx, 'off'); % Скрываем ось для таблицы
    
    % Получаем позицию тайла в нормализованных единицах фигуры
    tableAxPos = get(tableAx, 'Position'); % [left, bottom, width, height] в нормализованных единицах
    
    % Определяем уникальные каналы и их названия из calcResult
    uniqueChannels = [];
    channelNames = {};
    if isfield(events, 'channels') && ~isempty(events.channels) && isfield(calcResult, 'ch_labels') && ~isempty(calcResult.ch_labels)
        allUniqueChannels = unique(events.channels);
        for i = 1:length(allUniqueChannels)
            chIdx = allUniqueChannels(i);
            if chIdx > 0 && chIdx <= length(calcResult.ch_labels)
                uniqueChannels(end+1) = chIdx;
                channelNames{end+1} = calcResult.ch_labels{chIdx};
            end
        end
    end
    
    numChannels = length(uniqueChannels);
    
    % Подготовка данных для таблицы с колонками для каждого канала
    columnNames = {'Parameter'};
    for i = 1:numChannels
        columnNames{end+1} = channelNames{i};
    end
    
    % Инициализация данных таблицы
    summaryData = cell(0, numChannels + 1);
    
    % Строка: Total / Before Zero / After Zero по каналам
    totalRow = {'Total / Before Zero / After Zero'};
    if events.numEvents > 0 && numChannels > 0
        for i = 1:numChannels
            chIdx = uniqueChannels(i);
            chMask = events.channels == chIdx;
            chTotal = sum(chMask);
            chBeforeZero = sum(chMask & events.peak_times < 0);
            chAfterZero = sum(chMask & events.peak_times > 0);
            totalRow{end+1} = sprintf('%d / %d / %d', chTotal, chBeforeZero, chAfterZero);
        end
    else
        for i = 1:numChannels
            totalRow{end+1} = '0 / 0 / 0';
        end
    end
    summaryData(end+1, :) = totalRow;
    
    % Строка: dt между стимулами (min - max), одна переменная в текстовом виде
    stimDtRow = {'Stim dt (min - max)'};
    stimDtStr = 'N/A';
    if isfield(calcResult, 'stim_dt_min_max')
        stimDtStr = calcResult.stim_dt_min_max;
    end
    for i = 1:numChannels
        stimDtRow{end+1} = stimDtStr;
    end
    summaryData(end+1, :) = stimDtRow;
    
    % Строка: Paired t-test (p-value / More after zero) по каналам
    ttestRow = {'Paired t-test (p-value / More after zero)'};
    if isfield(events, 'paired_ttest_pvalue_by_channel') && isfield(events, 'has_response_mean') && numChannels > 0
        for i = 1:numChannels
            chIdx = uniqueChannels(i);
            activeChIdx = find(calcResult.activeChannels == chIdx, 1);
            if ~isempty(activeChIdx) && activeChIdx <= length(events.paired_ttest_pvalue_by_channel)
                pval = events.paired_ttest_pvalue_by_channel(activeChIdx);
                moreAfter = events.has_response_mean(activeChIdx);
                if ~isnan(pval)
                    moreAfterStr = 'Yes';
                    if ~moreAfter
                        moreAfterStr = 'No';
                    end
                    ttestRow{end+1} = sprintf('%.4f / %s', pval, moreAfterStr);
                else
                    ttestRow{end+1} = 'N/A';
                end
            else
                ttestRow{end+1} = 'N/A';
            end
        end
    else
        for i = 1:numChannels
            ttestRow{end+1} = 'N/A';
        end
    end
    summaryData(end+1, :) = ttestRow;
    
    % Строка: джиттер первого онсета и амплитуды ответа (глобальные)
    jitterRow = {'First onset jitter (std)'};
    onsetJitter = NaN;
    if isfield(events, 'first_onset_jitter')
        onsetJitter = events.first_onset_jitter;
    end
    onsetJitterStr = 'N/A';
    if ~isnan(onsetJitter)
        onsetJitterStr = sprintf('%.4f', onsetJitter);
    end
    for i = 1:numChannels
        jitterRow{end+1} = onsetJitterStr;
    end
    summaryData(end+1, :) = jitterRow;
    ampJitterRow = {'Amplitude jitter (std)'};
    ampJitter = NaN;
    if isfield(events, 'amplitude_jitter')
        ampJitter = events.amplitude_jitter;
    end
    ampJitterStr = 'N/A';
    if ~isnan(ampJitter)
        ampJitterStr = sprintf('%.4f', ampJitter);
    end
    for i = 1:numChannels
        ampJitterRow{end+1} = ampJitterStr;
    end
    summaryData(end+1, :) = ampJitterRow;
    
    if events.numEvents > 0 && numChannels > 0
        % Статистика по каналам для событий до нуля
        beforeZeroMask = events.peak_times < 0;
        if sum(beforeZeroMask) > 0
            beforeZeroTimes = events.peak_times(beforeZeroMask);
            beforeZeroProminences = events.prominences(beforeZeroMask);
            beforeZeroChannels = events.channels(beforeZeroMask);
            
            % Median, Q1-Q3 before zero по каналам
            timeBeforeRow = {'Median, Q1-Q3 before zero'};
            for i = 1:numChannels
                chMask = beforeZeroChannels == uniqueChannels(i);
                if sum(chMask) > 0
                    chTimes = beforeZeroTimes(chMask);
                    medianTime = median(chTimes);
                    q1Time = quantile(chTimes, 0.25);
                    q3Time = quantile(chTimes, 0.75);
                    iqrTime = q3Time - q1Time;
                    timeBeforeRow{end+1} = sprintf('%.3f, %.3f-%.3f (%.3f)', medianTime, q1Time, q3Time, iqrTime);
                else
                    timeBeforeRow{end+1} = 'N/A';
                end
            end
            summaryData(end+1, :) = timeBeforeRow;
            
            % Median Prominence before zero по каналам
            promBeforeRow = {'Median Prominence before zero'};
            for i = 1:numChannels
                chMask = beforeZeroChannels == uniqueChannels(i);
                if sum(chMask) > 0
                    chProms = beforeZeroProminences(chMask);
                    medianProm = median(chProms);
                    q1Prom = quantile(chProms, 0.25);
                    q3Prom = quantile(chProms, 0.75);
                    iqrProm = q3Prom - q1Prom;
                    promBeforeRow{end+1} = sprintf('%.3f, %.3f-%.3f (%.3f)', medianProm, q1Prom, q3Prom, iqrProm);
                else
                    promBeforeRow{end+1} = 'N/A';
                end
            end
            summaryData(end+1, :) = promBeforeRow;
        else
            timeBeforeRow = {'Median, Q1-Q3 before zero'};
            promBeforeRow = {'Median Prominence before zero'};
            for i = 1:numChannels
                timeBeforeRow{end+1} = 'N/A';
                promBeforeRow{end+1} = 'N/A';
            end
            summaryData(end+1, :) = timeBeforeRow;
            summaryData(end+1, :) = promBeforeRow;
        end
        
        % Статистика по каналам для событий после нуля
        afterZeroMask = events.peak_times > 0;
        if sum(afterZeroMask) > 0
            afterZeroTimes = events.peak_times(afterZeroMask);
            afterZeroProminences = events.prominences(afterZeroMask);
            afterZeroChannels = events.channels(afterZeroMask);
            
            % Median, Q1-Q3 after zero по каналам
            timeAfterRow = {'Median, Q1-Q3 after zero'};
            for i = 1:numChannels
                chMask = afterZeroChannels == uniqueChannels(i);
                if sum(chMask) > 0
                    chTimes = afterZeroTimes(chMask);
                    medianTime = median(chTimes);
                    q1Time = quantile(chTimes, 0.25);
                    q3Time = quantile(chTimes, 0.75);
                    iqrTime = q3Time - q1Time;
                    timeAfterRow{end+1} = sprintf('%.3f, %.3f-%.3f (%.3f)', medianTime, q1Time, q3Time, iqrTime);
                else
                    timeAfterRow{end+1} = 'N/A';
                end
            end
            summaryData(end+1, :) = timeAfterRow;
            
            % Median Prominence after zero по каналам
            promAfterRow = {'Median Prominence after zero'};
            for i = 1:numChannels
                chMask = afterZeroChannels == uniqueChannels(i);
                if sum(chMask) > 0
                    chProms = afterZeroProminences(chMask);
                    medianProm = median(chProms);
                    q1Prom = quantile(chProms, 0.25);
                    q3Prom = quantile(chProms, 0.75);
                    iqrProm = q3Prom - q1Prom;
                    promAfterRow{end+1} = sprintf('%.3f, %.3f-%.3f (%.3f)', medianProm, q1Prom, q3Prom, iqrProm);
                else
                    promAfterRow{end+1} = 'N/A';
                end
            end
            summaryData(end+1, :) = promAfterRow;
        else
            timeAfterRow = {'Median, Q1-Q3 after zero'};
            promAfterRow = {'Median Prominence after zero'};
            for i = 1:numChannels
                timeAfterRow{end+1} = 'N/A';
                promAfterRow{end+1} = 'N/A';
            end
            summaryData(end+1, :) = timeAfterRow;
            summaryData(end+1, :) = promAfterRow;
        end
    else
        timeBeforeRow = {'Median, Q1-Q3 before zero'};
        promBeforeRow = {'Median Prominence before zero'};
        timeAfterRow = {'Median, Q1-Q3 after zero'};
        promAfterRow = {'Median Prominence after zero'};
        for i = 1:numChannels
            timeBeforeRow{end+1} = 'N/A';
            promBeforeRow{end+1} = 'N/A';
            timeAfterRow{end+1} = 'N/A';
            promAfterRow{end+1} = 'N/A';
        end
        summaryData(end+1, :) = timeBeforeRow;
        summaryData(end+1, :) = promBeforeRow;
        summaryData(end+1, :) = timeAfterRow;
        summaryData(end+1, :) = promAfterRow;
    end
    
    % Вычисляем оптимальную ширину колонок
    maxParamWidth = 0;
    maxValueWidths = zeros(1, numChannels + 1);
    for i = 1:size(summaryData, 1)
        if ischar(summaryData{i, 1})
            maxParamWidth = max(maxParamWidth, length(summaryData{i, 1}));
        end
        for j = 2:size(summaryData, 2)
            if isnumeric(summaryData{i, j})
                valueStr = num2str(summaryData{i, j});
                maxValueWidths(j) = max(maxValueWidths(j), length(valueStr));
            elseif ischar(summaryData{i, j})
                maxValueWidths(j) = max(maxValueWidths(j), length(summaryData{i, j}));
            end
        end
    end
    
    % Ширина символа примерно 8 пикселей, добавляем отступы
    paramColWidth = max(150, maxParamWidth * 8 + 20);
    columnWidths = {paramColWidth};
    for j = 1:numChannels
        colWidth = max(100, maxValueWidths(j+1) * 8 + 20);
        columnWidths{end+1} = colWidth;
    end
    
    % Создание таблицы в тайле с позицией относительно тайла
    hTable = uitable(fig, ...
        'Units', 'normalized', ...
        'Position', tableAxPos, ...
        'Data', summaryData, ...
        'ColumnName', columnNames, ...
        'ColumnWidth', columnWidths, ...
        'ColumnEditable', [false, repmat(false, 1, numChannels)], ...
        'RowName', []);
    
    % Убеждаемся, что таблица не перекрывает другие элементы
    % Перемещаем таблицу на задний план (но это не всегда работает для uitable)
    uistack(hTable, 'bottom');
end

