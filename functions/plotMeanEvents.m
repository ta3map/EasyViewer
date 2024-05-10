function [f, calculation_result] = plotMeanEvents(params)

    % Распаковка переменных из params
    events = params.events;
    meanWindow = params.meanWindow;
    hd = params.hd;
    channelSettings = params.channelSettings;
    Fs = params.Fs;
    lfp = params.lfp;
    N = params.N;
    time = params.time;
    binsize = params.binsize;
    prg = params.spk_threshold;
    spks = params.spks;
    shiftCoeff = params.shiftCoeff;
    titlename = params.titlename;
    show_spikes = params.show_spikes;
    ch_inxs = params.ch_inxs; % Индексы активированных каналов
    show_CSD = params.show_CSD;
    csd_smooth_coef = params.csd_smooth_coef;
    csd_contrast_coef = params.csd_contrast_coef;
    csd_active = params.csd_active;
    lfpVar = params.lfpVar;
    mean_group_ch = params.mean_group_ch;
    
    if isfield(params, 'timeUnitFactor')
        timeUnitFactor = params.timeUnitFactor;
    else
        timeUnitFactor = 1;
    end
    
    % Получение данных событий и настроек каналов
    ch_labels = hd.recChNames(:);

    activeChannels = find([channelSettings{:, 2}]); % Индексы активных каналов
    scalingCoefficients = [channelSettings{:, 3}]; % Масштабирующие коэффициенты

    colors_in = channelSettings(:, 4)';
    widths_in = [channelSettings{:, 5}];

    % Подготовка данных для среднего
    meanData = zeros(round(meanWindow * Fs), size(lfp, 2));
    numEvents = length(events);
    
    lfp(:, mean_group_ch) = lfp(:, mean_group_ch) - nanmean(lfp(:, mean_group_ch), 2); % вычитание выбранных средних каналов
    
    for i = 1:numEvents
        % Вычисление индексов окна вокруг события
        eventIdx = round(events(i) * Fs);
        windowStart = max(eventIdx - round(meanWindow * Fs / 2), 1);
        windowEnd = min(windowStart + round(meanWindow * Fs) - 1, N);

        if windowEnd < size(lfp, 1)                  
            % Добавление данных в среднее
            meanData = meanData + lfp(windowStart:windowEnd, :) - nanmedian(lfp(windowStart:windowEnd, :));
        end
    end

    % Нормализация среднего
    meanData = meanData / numEvents;

    % Считаем средние спайки

    % show spikes
    ev_hists = [];
    if show_spikes && not(isempty(spks))
        clear evs
        for i = 1:numEvents
            % Вычисление индексов окна вокруг события
            eventIdx = round(events(i) * Fs);
            windowStart = max(eventIdx - round(meanWindow * Fs / 2), 1);
            windowEnd = min(windowStart + round(meanWindow * Fs) - 1, N);

            if windowEnd < size(lfp, 1)                      
                % Окно события
                time_start = time(windowStart);
                time_end = time(windowEnd);
                c = 0;

                time_interval = [time_start, time_end];% s
                edges = time_interval(1):binsize:time_interval(2);

                % Смотрим что на каждом канале для этого эвента
                ch_hists = [];
                for ch_inx = ch_inxs
                    c = c+1;
                    
                    % Порог ZAV метод
                    ii = double(spks(ch_inx).ampl) <= (-lfpVar(ch_inx) * prg);
                    spks_in(ch_inx).tStamp = spks(ch_inx).tStamp(ii);
                    spks_in(ch_inx).ampl = spks(ch_inx).ampl(ii);

                    spk = spks_in(ch_inx).tStamp/1000;
                    
                    hist_data = histcounts(spk, edges);
                    ch_hists = [ch_hists; hist_data];
                end
                evs(i, :, :) = ch_hists;
            end
            disp(['event #' num2str(i) ' of ' num2str(numEvents)])
        end
        if exist('evs')
            ev_hists = squeeze(mean(evs,1));
        else
            ev_hists = [];
        end
    end


    % Отображение среднего
    f = params.figure; % Создание нового окна для графика
    clf
    hold on

    start_time = -meanWindow / 2;
    end_time = meanWindow / 2;
    
    ch_enabled = repmat(false, length(ch_labels), 1);    
    ch_enabled(activeChannels) = true;

    timeAxis = linspace(start_time, end_time, size(meanData, 1))*timeUnitFactor;
    pl_meanData =  meanData.* scalingCoefficients;

    pl_meanData = pl_meanData(:, ch_enabled);
    pl_ch_labels = ch_labels(ch_enabled);
    pl_shiftCoeff = shiftCoeff;
    pl_widths_in = widths_in(ch_enabled);
    pl_colors_in = colors_in(ch_enabled);     
    

    
    if show_CSD
        numChannels = size(pl_meanData, 2);
        % Initialize offsets array
        offsets = zeros(1, numChannels);
        % Plot each column with specified parameters
        for p = 1:numChannels
            % Determine the offset
            offsets(p) = -(p-1) * shiftCoeff;
        end    
        
        params.time_in_csd = timeAxis;
        params.data_in_csd = pl_meanData;
        params.Fs = Fs;
        params.offsets = offsets;
        params.csd_smooth_coef = csd_smooth_coef;
        params.csd_active = csd_active;
        
        [csd_image, csd_trange, csd_ch_range] = csdCalc(params);
        csdPlotting(csd_image, csd_trange, csd_ch_range, csd_contrast_coef);
    end
    
    offsets = multiplot(timeAxis, pl_meanData, ...
    'ChannelLabels', pl_ch_labels, ...
    'shiftCoeff',pl_shiftCoeff, ...
    'linewidth', pl_widths_in, ...
    'color', pl_colors_in);

    if not(isempty(ev_hists))
        mua_x = linspace(start_time*timeUnitFactor, end_time*timeUnitFactor, size(ev_hists, 2));
        im = imagesc(mua_x, offsets, ev_hists);
        uistack(im, 'bottom'); % Перемещение изображения на задний план
    end        

    xlabel('Time');
    ylabel('Mean Value');    
    title([titlename, ', ', num2str(numEvents), ' events'], 'interpreter', 'none')        

    ylim([offsets(end)-shiftCoeff, offsets(1)+shiftCoeff])
    xlim([start_time, end_time]*timeUnitFactor)
    
    calculation_result = struct();

    calculation_result.meanData = meanData;
    calculation_result.events = events;
    calculation_result.channelSettings = channelSettings;
    calculation_result.activeChannels = activeChannels;
    calculation_result.scalingCoefficients = scalingCoefficients;
    calculation_result.Fs = Fs;
    calculation_result.N = N;
%     calculation_result.time = time;
    calculation_result.show_spikes = show_spikes;
    calculation_result.binsize = binsize;
    calculation_result.std_coef = prg;
    calculation_result.ch_inxs = ch_inxs;
    calculation_result.ev_hists = ev_hists;
    calculation_result.timeAxis = timeAxis/timeUnitFactor;
    calculation_result.ch_labels = ch_labels;
    calculation_result.shiftCoeff = shiftCoeff;
    calculation_result.widths_in = widths_in;
    calculation_result.colors_in = colors_in;

end