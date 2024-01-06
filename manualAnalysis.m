% global lfp data time_in Fs newFs timeUnitFactor

% ampa
mat_path = "C:\Users\ta3ma\Dropbox\results guzel\eSPW and AMPA-GABA\data\2023-12-18_P3\2023-12-18_17-43-07.mat"
channelSettingsFilePath = "C:\Users\ta3ma\Dropbox\results guzel\eSPW and AMPA-GABA\data\2023-12-18_P3\2023-12-18_17-43-07_channelSettings.stn"
ev_path = "C:\Users\ta3ma\Dropbox\results guzel\eSPW and AMPA-GABA\data\2023-12-18_P3\2023-12-18_17-43-07_events rk.ev"

event_inx = 6;
color = 'red';
mc_coef = -1;
li_color = '#F4DBDA';
ampa_paths = {mat_path, ev_path, channelSettingsFilePath, event_inx, color, mc_coef, li_color};

% gaba
mat_path = "C:\Users\ta3ma\Dropbox\results guzel\eSPW and AMPA-GABA\data\2023-12-18_P3\2023-12-18_18-01-19.mat"
channelSettingsFilePath = "C:\Users\ta3ma\Dropbox\results guzel\eSPW and AMPA-GABA\data\2023-12-18_P3\2023-12-18_18-01-19_channelSettings.stn"
ev_path = "C:\Users\ta3ma\Dropbox\results guzel\eSPW and AMPA-GABA\data\2023-12-18_P3\2023-12-18_18-01-19_events gaba rk.ev"
event_inx = 7;
color = 'blue';
mc_coef = 0.1;
li_color = '#DADCF4';
gaba_paths = {mat_path, ev_path, channelSettingsFilePath, event_inx, color, mc_coef, li_color};

collection = {ampa_paths; gaba_paths};

f1 = figure(5);
f1.Position = [56.2000 82.6000 597.6000 586.4000];
clf
hold on

% current type index (AMPA-or-GABA)
for c_inx = 1:2
    mat_path = collection{c_inx, 1}{1};
    ev_path = collection{c_inx, 1}{2};
    channelSettingsFilePath = collection{c_inx, 1}{3};
    event_inx = collection{c_inx, 1}{4};
    color = collection{c_inx, 1}{5};
    mc_coef = collection{c_inx, 1}{6};
    li_color =  collection{c_inx, 1}{7};
    
    d = load(mat_path); % Загружаем данные в структуру
    lfp = d.lfp;
    hd = d.hd;

    Fs = d.zavp.dwnSmplFrq;
    N = size(lfp, 1);
    time = (0:N-1) / Fs;% s
    newFs = 1000;
    timeUnitFactor = 1;
    windowSize = 1; %s
    time_back = 1; %s
    min_time = -0.2;
    
    % load events
    loadedData = load(ev_path, '-mat'); % Загружаем данные в структуру
    events = time([loadedData.manlDet.t])';

    % choose event
    areas = [];
    data_cums = [];
    for event_inx = 1:numel(events);
        chosen_time_interval(1) = events(event_inx);
        chosen_time_interval(2) = events(event_inx)+windowSize;
        plot_time_interval = chosen_time_interval;
        plot_time_interval(1) = plot_time_interval(1) - time_back;

        cond = time >= plot_time_interval(1) & time < plot_time_interval(2);

        % load channel settings
        loadedSettings = load(channelSettingsFilePath, '-mat');
        channelSettingsTable = loadedSettings.channelSettings;
        ch_inxs = find([channelSettingsTable{:, 2}]); % Индексы активированных каналов
        m_coef = [channelSettingsTable{:, 3}]; % Коэффициенты масштабирования
        m_coef = m_coef(ch_inxs);

        data = lfp(cond, ch_inxs);
        time_in = time(cond);

        % resample based on time interval
        raw_frq = Fs;
        lfp_frq = round(newFs);
        numRawPoints = size(data, 1); % количество точек в исходных данных

        numPoints = ceil(numRawPoints * lfp_frq / raw_frq); % вычисляем количество точек после ресемплинга

        data_res = zeros(numPoints, size(data, 2)); % предварительное выделение памяти

        for ch = 1:size(data, 2)
            data_res(:, ch) = resample(double(data(:, ch)), lfp_frq , raw_frq);
        end        
        time_res = linspace(time_in(1),time_in(end),size(data_res, 1));        
        time_res = time_res - time_res(1) - 1;
        % Отображение времени на графике с учетом выбранной единицы времени
        time_in_transformed = time_res * timeUnitFactor;

        target_ch = size(data_res, 2);
        diff_data = [0; diff(data_res(:, target_ch))];
        baseline = median(data_res(:, target_ch));
        data_cum = (data_res(:, target_ch) - baseline)*mc_coef;
%         data_cum(data_cum<0) = 0;
        data_cum(time_res<min_time) = 0;
        area = cumtrapz(time_res, data_cum);
        area = 100*(area/max(area));
        data_sum = cumsum(data_res(:, target_ch));
        % data_sum = 100*(data_sum/max(data_sum));
        diff_area = [0; diff(area)];
        
        areas = [areas, area];
        data_cums = [data_cums, data_cum];
        subplot(212)
        hold on
        plot(time_res, area, 'color', li_color, 'linestyle', '-')
        subplot(211)
        hold on
        plot(time_res, data_cum, 'color', li_color, 'linestyle', '-')
    end
    area_mean = mean(areas, 2);
    data_cum_mean = mean(data_cums, 2);
        subplot(212)
        hold on
        plot(time_res, area_mean, 'color', color, 'linestyle', '-')
        subplot(211)
        hold on
        plot(time_res, data_cum_mean, 'color', color, 'linestyle', '-')
        
    collection{c_inx, 1}{8} = area_mean;
    collection{c_inx, 1}{9} = data_cum_mean;
end

subplot(211)
d_inx = 9;
plot(time_res, collection{1, 1}{d_inx} - collection{2, 1}{d_inx}, 'color', 'k', 'linestyle', '-')
ylabel('Currents, a.u.')
subplot(212)
d_inx = 8;
plot(time_res, collection{1, 1}{d_inx} - collection{2, 1}{d_inx}, 'color', 'k', 'linestyle', '-')
xlabel('Time, s')
title('Cumulative sum (normalized), black -- AMPAsum-GABAsum')
