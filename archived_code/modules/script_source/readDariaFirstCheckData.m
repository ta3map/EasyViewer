function data = readDariaFirstCheckData(params)
    % readDariaFirstCheckData - Чтение кусков данных из файлов
    %
    % Входные параметры (структура params):
    %   params.lfpPath - путь к .mat файлу с LFP данными
    %   params.iosPath - путь к IOS файлу с видео данными
    %   params.settingsPath - путь к файлу с координатами электродов ECoG
    %   params.loadCadr - параметр для readIOS
    %   params.dataStart - начало диапазона данных (в секундах)
    %   params.dataEnd - конец диапазона данных (в секундах)
    %
    % Возвращает структуру с полями:
    %   lfp - вырезанный кусок LFP данных
    %   hd - заголовок данных
    %   videoData - вырезанные кадры IOS
    %   videoTime - временные метки видео
    %   ecogCh - координаты электродов ECoG
    
    load(params.lfpPath);
    
    Fs = zavp.dwnSmplFrq;
    lfpStartIdx = round(params.dataStart * Fs) + 1;
    lfpEndIdx = round(params.dataEnd * Fs);
    
    lfpStartIdx = max(1, min(lfpStartIdx, size(lfp, 1)));
    lfpEndIdx = max(lfpStartIdx, min(lfpEndIdx, size(lfp, 1)));
    
    lfp = lfp(lfpStartIdx:lfpEndIdx, :);
    time = (lfpStartIdx - 1:lfpEndIdx - 1) / Fs;
    
    [~, sampleTime] = readIOS2(params.iosPath, 'startframe', 1, 'endframe', 10, 'eachframe', 1, 'Format', 'Lin');
    startTime = sampleTime(1);
    dt = mean(diff(sampleTime));
    
    startFrame = round((params.dataStart - startTime) / dt) + 1;
    endFrame = round((params.dataEnd - startTime) / dt) + 1;
    
    [videoData, videoTime] = readIOS2(params.iosPath, 'startframe', startFrame, 'endframe', endFrame, 'eachframe', params.loadCadr, 'Format', 'Lin');
    videoData(:,:,3)=[];
    
    videoTime = videoTime - params.dataStart;
    
    load(params.settingsPath);
    
    data.lfp = lfp;
    data.hd = hd;
    data.time = time;
    data.Fs = Fs;
    data.videoData = videoData;
    data.videoTime = videoTime;
    data.ecogCh = ecogCh;
    data.dataStart = params.dataStart;
end
