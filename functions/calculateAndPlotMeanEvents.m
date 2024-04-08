function calculateAndPlotMeanEvents()
wb = msgbox('Please wait...', 'Status');
% Инициализация переменных
global Fs N time ch_inxs  
global shiftCoeff
global lfp hd spks
global matFilePath
global timeUnitFactor 
global events 
global newFs
global time_back time_forward
global std_coef show_spikes binsize show_CSD % спайки/CSD
global csd_avaliable filter_avaliable filterSettings
global channelTable csd_smooth_coef csd_contrast_coef
global lfpVar 
global mean_group_ch

[mat_file_folder, original_filename, ~] = fileparts(matFilePath);

params.events = events;
params.figure = figure('Name', 'Mean Event Data'); % Создание нового окна для графика;
params.meanWindow = 2;% s
params.hd = hd;
params.channelSettings = get(channelTable, 'Data');
params.Fs = Fs;
params.lfp = lfp;
params.N = N;
params.time = time;
params.binsize = binsize;
params.spk_threshold = std_coef;
params.spks = spks;
params.shiftCoeff = shiftCoeff;
params.titlename = original_filename;
params.show_spikes = show_spikes;
params.ch_inxs = ch_inxs; % Индексы активированных каналов
params.show_CSD = show_CSD;
params.csd_smooth_coef = csd_smooth_coef;
params.csd_contrast_coef = csd_contrast_coef;
params.csd_active = csd_avaliable(ch_inxs);
params.timeUnitFactor = timeUnitFactor;% экспериментальный не проверенный параметр
params.lfpVar = lfpVar;
params.mean_group_ch = mean_group_ch;

% Фильтруем если попросили
if sum(filter_avaliable)>0
    ch_to_filter = filter_avaliable;
    params.lfp(:, ch_to_filter) = applyFilter(lfp(:, ch_to_filter), filterSettings, newFs);        
end

close(wb);

[mean_f, calculation_result] = plotMeanEvents(params);
xlim([-time_back, time_forward]*timeUnitFactor)
xline(0, 'r:');

% Кнопка для сохранения файлов
save_btn_coords = [5, 5, 50, 30];
savebutton = uicontrol('Parent', mean_f, 'Style', 'pushbutton', 'String', 'Save Data', 'Position', save_btn_coords, 'Callback', @SaveBtnClb);

function SaveBtnClb(~,~)
    [file,path] = uiputfile([mat_file_folder '/' original_filename '_data.mean'], 'Save file name');
    if isequal(file,0) || isequal(path,0)
       disp('User pressed cancel')
    else
       filename = fullfile(path, file);      
       save(filename, '-struct', 'calculation_result');
       save(filename, 'original_filename', '-append');
       
       disp(['Data saved to ', filename]);
    end
end


end