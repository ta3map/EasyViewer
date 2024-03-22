function calculateAndPlotMeanEvents(meanWindow)

% Инициализация переменных
global Fs N time chosen_time_interval cond ch_inxs  
global data time_in shiftCoeff eventTable
global lfp hd spks multiax lineCoefficients
global channelNames numChannels channelEnabled  
global matFilePath channelSettingsFilePath
global timeUnitFactor selectedUnit
global saved_time_interval
global meanData timeAxis initialDir
global events event_inx events_exist event_comments
global stims stim_inx stims_exist
global lastOpenedFiles
global updatedData
global zavp newFs selectedCenter
global time_back time_forward
global figure_position timeForwardEdit
global meanSaveButton saveDataButton
global std_coef show_spikes binsize show_CSD % спайки/CSD
global events_detected
global ev_hists ch_hists 
global ch_labels_l colors_in_l  widths_in_l
global add_event_settings
global mean_group_ch timeSlider menu_visible csd_avaliable filter_avaliable filterSettings
global channelTable csd_smooth_coef csd_contrast_coef

[mat_file_folder, original_filename, ~] = fileparts(matFilePath);

params.events = events;
params.figure = figure('Name', 'Mean Event Data'); % Создание нового окна для графика;
params.meanWindow = time_forward*2;
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

% Фильтруем если попросили
if sum(filter_avaliable)>0
    ch_to_filter = filter_avaliable;
    params.lfp(:, ch_to_filter) = applyFilter(lfp(:, ch_to_filter), filterSettings, newFs);        
end
    
[mean_f, calculation_result] = plotMeanEvents(params);
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