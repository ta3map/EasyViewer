function oep_to_zav(recordedData, zavFilePath, Fs, newFs, detectMua, mua_std_coef, doResample, channelNames, selectedChIndexes)

    selectedChannels = channelNames(selectedChIndexes);

    % Инициализация переменных
    recsNumber = size(recordedData, 1);
    lfp = [];

    % Считывание данных по каналам
    for recinx = 1:recsNumber       
        numChannels = numel(selectedChannels); % Количество каналов
        lfp = [lfp; recordedData.Continuous_Samples{recinx}(selectedChIndexes, :)'];
    end

    chnlGrp = {};
    hd.fFileSignature = 'Openephys';
    hd.recChNames = selectedChannels;
    hd.si = (1/Fs) * 1e6;

    % Обнаружение MUA, если требуется
    sweepIdx = 1;
    spks = [];

    if detectMua
        hWaitBar = waitbar(0, 'MUA detection.', 'Name', 'MUA detection.');
        waitbar(0, hWaitBar, 'Starting MUA detection...');
        for chIdx = 1:numChannels
            % Обнаружение MUA
            [tStamp, ampl, shape] = detectMUA(lfp(:, chIdx), hd, mua_std_coef, true);
            spks(chIdx, sweepIdx).tStamp = double(tStamp);
            spks(chIdx, sweepIdx).ampl = double(-ampl);
            spks(chIdx, sweepIdx).shape = shape;

            channelName = strrep(channelNames{chIdx}, '_', ' ');
            percent = [chIdx/numChannels];
            current_message = ['Channel:', channelName, ', ' num2str(percent*100, 3), '%'];
            disp(current_message); % Выводим имя канала
            waitbar(percent, hWaitBar, current_message);
        end
        waitbar(1, hWaitBar, 'Detection completed!');
        close(hWaitBar);
    end

    % Выполнение ресемплинга, если требуется
    if doResample
        lfp = resample(double(lfp), newFs, Fs);
    end

    % Расчет вариации LFP
    lfpVar = var(reshape(lfp, [], numChannels));

    % Подготовка структуры zavp
    skip_points = Fs / newFs;
    zavp.file = zavFilePath;
    zavp.siS = 1 / Fs; % Интервал выборки
    zavp.dwnSmplFrq = newFs;
    zavp.stimCh = nan;
    zavp.realStim.r = [];
    zavp.realStim.f = [];
    zavp.rarStep = zeros(1, numChannels) + skip_points;

    % Сохранение данных
    save(zavFilePath, 'chnlGrp', 'hd', 'lfp', 'lfpVar', 'spks', 'zavp', '-v7.3');
end
