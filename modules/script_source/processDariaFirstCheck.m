function results = processDariaFirstCheck(params)
    % processDariaFirstCheck - Визуализация IOS кадра с трейсами LFP
    %
    % Входные параметры (структура params):
    %   params.data - структура с данными (результат readDariaFirstCheckData)
    %   params.showTime - время показа (в секундах, абсолютное время)
    %   params.traceWindow - размер окна для трейсов (в секундах, например 5 для ±5 сек)
    %
    % Возвращает структуру результатов (пустая, визуализация выполняется)
    
    data = params.data;
    showTime = params.showTime;
    traceWindow = params.traceWindow;
    
    lfp = data.lfp;
    time = data.time;
    videoData = data.videoData;
    videoTime = data.videoTime;
    ecogCh = data.ecogCh;
    dataStart = data.dataStart;
    
    showTimeRelative = showTime - dataStart;
    [~, frameIdx] = min(abs(videoTime - showTimeRelative));
    iosFrame = videoData(:, :, frameIdx);
    
    clf
    imagesc(iosFrame)
    hold on
    colormap(gray)
    
    traceStartTime = showTimeRelative - traceWindow;
    traceEndTime = showTimeRelative + traceWindow;
    
    [~, traceStartIdx] = min(abs(time - traceStartTime));
    [~, traceEndIdx] = min(abs(time - traceEndTime));
    
    if traceStartIdx < 1
        traceStartIdx = 1;
    end
    if traceEndIdx > size(lfp, 1)
        traceEndIdx = size(lfp, 1);
    end
    
    traceScale = 20;
    
    for p = 1:size(ecogCh, 1)
        if ~isnan(ecogCh(p, 4)) && ~isnan(ecogCh(p, 5))
            channelNum = ecogCh(p, 1);
            xCoord = ecogCh(p, 4);
            yCoord = ecogCh(p, 5);
            
            trace = lfp(traceStartIdx:traceEndIdx, channelNum);
            trace = trace - mean(trace);
            trace = trace / max(abs(trace)) * traceScale;
            
            timeAxis = linspace(-traceWindow, traceWindow, length(trace));
            xTrace = xCoord + timeAxis;
            yTrace = yCoord + trace;
            
            plot(xTrace, yTrace, 'b', 'LineWidth', 1)
        end
    end
    
    axis equal
    axis tight
    
    results = struct();
end
