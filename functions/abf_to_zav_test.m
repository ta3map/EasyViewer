% Разрабатываем конвертер из abf в zav

abfFilePath = "C:\Users\ta3ma\Dropbox\results guzel\CA1 feedforward inhibition\eSPW and AMPA-GABA\data\2023-11-30_P4\23n30002.abf"

% reading header
[~, ~, hd]=abfload(abfFilePath, 'stop',1);

for ch_n = 1:numel(hd.recChNames)
    chName = hd.recChNames(ch_n);
    disp(chName)
    % load file
    [data, ~, hd]=abfload(abfFilePath, 'channels', chName);
end

raw_frq = round(1e6/hd.si);% оригинальная частота дискретизации


% Преобразование содержимого hd в JSON
hd_json_data = jsonencode(hd);
% Сохранение в JSON файл
json_filepath = "C:\Users\ta3ma\Documents\MATLAB\AzatG functions\EasyViewer\EasyViewer\abf_hd.json";
fid = fopen(json_filepath, 'w');
fwrite(fid, hd_json_data, 'char');
fclose(fid);
%%
% Загрузка содержимого mat файла
zav_mat = "C:\Users\ta3ma\Dropbox\results guzel\CA1 feedforward inhibition\eSPW and AMPA-GABA\data\2023-11-30_P4\2023-11-30_17-12-49.mat";
d = load(zav_mat);
d.lfp = size(d.lfp)   
d.spks = size(d.spks)
% Преобразование содержимого в JSON
zav_json_data = jsonencode(d);

% Сохранение в JSON файл
zav_json_filepath = "C:\Users\ta3ma\Documents\MATLAB\AzatG functions\EasyViewer\EasyViewer\zav_data.json";
fid = fopen(zav_json_filepath, 'w');
fwrite(fid, zav_json_data, 'char');
fclose(fid);
%%
abfFilePath = "C:\Users\ta3ma\Dropbox\results guzel\CA1 feedforward inhibition\eSPW and AMPA-GABA\data\2023-11-30_P4\23n30002.abf";
zavFilePath = 'D:\abf_to_zav_test.mat';
lfp_Fs = 1000; % желаемая частота дискретизации LFP
detectMua = false; % или false, если не нужно обнаруживать МСА
doResample = false; % ресемплинг
collectSweeps = false; % установить в true, если нужно сохранить данные по свипам

abf_to_zav(abfFilePath, zavFilePath, lfp_Fs, detectMua, doResample, collectSweeps);

%% сравниваем результаты

norm_zav = load("C:\Users\ta3ma\Dropbox\GDP CSD paper\GDP_CSD  2024\070624_P4\070624_P4_slc2_0001.mat")
my_zav = load("C:\Users\ta3ma\Dropbox\GDP CSD paper\GDP_CSD  2024\070624_P4\070624_P4_slc2_0001_converted.mat")

norm_zav = load("D:\normspks.mat")
my_zav = load("D:\myspks.mat")


