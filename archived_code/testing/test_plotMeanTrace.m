function test_plotMeanTrace()

testDir = fileparts(mfilename('fullpath'));
addpath(fullfile(testDir, '..', 'functions'));

% --- данные ---
% synthMeanTraceData: синтетический LFP + spks + params для computeMeanTrace
% data.params — готовый struct, глобальные переменные не нужны
data = synthMeanTraceData();
params = data.params;

% --- расчёт ---
% computeMeanTrace(params) -> calc: meanData, ev_hists, timeAxis, ...
calc = computeMeanTrace(params);

% --- отрисовка: режим в params (show_CSD/show_spikes), боковой профиль: show_profile ---
% params.show_profile = false;
params_csd = params;
params_csd.show_CSD = true;
params_csd.show_spikes = false;
params_csd.figure = figure('Name', 'Synthetic Mean [CSD]');
plotMeanTrace(calc, params_csd);

% --- отрисовка MUA ---
params_mua = params;
params_mua.show_CSD = false;
params_mua.show_spikes = true;
params_mua.figure = figure('Name', 'Synthetic Mean [MUA]');
plotMeanTrace(calc, params_mua);

% --- альтернатива: расчёт + отрисовка одним вызовом ---
% params.figure = figure('Name', 'Mean');
% plotMeanEvents(params);

fprintf('test_plotMeanTrace: done\n');

end
