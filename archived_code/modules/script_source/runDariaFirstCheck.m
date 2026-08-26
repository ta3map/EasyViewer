% runDariaFirstCheck - Скрипт для чтения данных и запуска визуализации
%
% Этот скрипт читает данные из файлов и визуализирует IOS кадр с трейсами LFP
clear all
clc
readParams.lfpPath = "\\10.167.11.29\data2\photothrombosis\2025-07-22\2025-07-22_15-10-23.mat";
readParams.iosPath = "\\10.167.11.69\ios\2025-07-22\2025-07-22_14-45-36.ios";
readParams.settingsPath = "C:\Users\AzaRGajnutdinov\Documents\EasyViewer\modules\script_source\ecogCh.mat";
readParams.loadCadr = 1;
readParams.dataStart = 0;
readParams.dataEnd = 100;

data = readDariaFirstCheckData(readParams);
%%
params.data = data;
params.showTime = 6;
params.traceWindow = 20;

results = processDariaFirstCheck(params);
