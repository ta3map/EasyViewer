% conversion to zav format

record_path = 'D:\Neurolab\eSPW\Data files\2020_07_08nlx\2020-07-08_19-39-27';

detect_mua = false;

channels_n = countChannels(record_path);  % number of channels
channels_list = 1:channels_n;

lfp_Fs = 1000; % новая частота
lfp = []; % инициализация переменной для lfp

% Создание окна прогресса
hWaitBar = waitbar(0,'Wait...');
set(hWaitBar, 'Name', 'Conversion to NlX to ZAV');

% Считываем данные первого канала для определения размера матрицы lfp
[data, ~, hd, ~, ~] = ZavNrlynx2(record_path, [], 1, [], []);
orig_Fs = 1e6/hd.si; % оригинальная частота дискретизации
lfp_length = floor(length(data) * lfp_Fs / orig_Fs); % новая длина сигнала после ресемплинга
lfp = zeros(lfp_length, channels_n); % предварительное выделение памяти для lfp

clear spks

for ch = channels_list
    [data, ttlIn, hd, spkTS, spkSM] = ZavNrlynx2(record_path, [], ch, [], []);
    
    ampl = min(spkSM.s(:, :));
    
    if detect_mua
        [tStamp, ampl, shape] = detectMUA(data, hd);
        spks(ch).tStamp = single(tStamp); % сохраняем спайки канала в миллисекундном формате
        spks(ch).ampl = single(ampl);
        spks(ch).shape = shape;
    else
        % по ZAV формату
        spks(ch).tStamp = single(spkTS.s'); % сохраняем спайки канала в миллисекундном формате
        spks(ch).ampl = single(ampl');
        spks(ch).shape = [];
    end
    
    % Ресамплинг данных канала
    data_resampled = resample(data, lfp_Fs, orig_Fs);
    lfp(:, ch) = data_resampled; % добавляем ресемплированные данные в матрицу lfp
    
    % Обновление индикатора прогресса
    waitbar(ch / numel(channels_list), hWaitBar, sprintf('Channel %d from %d...', ch, numel(channels_list)));
end

close(hWaitBar); % Закрытие окна прогресса
disp('over')

%% save data in ZAV format
save_data = true;
if save_data
    skip_points = orig_Fs/lfp_Fs;
    clear chnlGrp lfpVar zavp
    chnlGrp = {};
    lfpVar = np_flatten(std(lfp)/10)'; % не знаю что это
    zavp.file = record_path;
    zavp.siS = (hd.si/1000)/lfp_Fs;
    zavp.dwnSmplFrq = lfp_Fs;
    zavp.stimCh = nan;

    if size(hd.inTTL_timestamps, 2)>0 % если были ttl стимуляции
        r_i = (hd.inTTL_timestamps.t(:,1)*skip_points)/zavp.dwnSmplFrq;
        f_i = (hd.inTTL_timestamps.t(:,2)*skip_points)/zavp.dwnSmplFrq;
    else
        r_i = [];
        f_i = [];
    end
    zavp.realStim.r = r_i;
    zavp.realStim.f = f_i;
    zavp.rarStep = hd.ch_si'*0+skip_points;

    new_lfp_filepath = [fileparts(record_path), '.zav'];
    save(new_lfp_filepath, 'chnlGrp', 'hd', 'lfp', 'lfpVar' , 'spks', 'zavp');
    disp('file saved')
end