function calculateAndPlotMeanEvents(meanWindow)

% Инициализация переменных
global Fs N time chosen_time_interval cond ch_inxs m_coef 
global data time_in shiftCoeff eventTable
global lfp hd spks multiax lineCoefficients
global channelNames numChannels channelEnabled scalingCoefficients tableData
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
global channelTable

[~, titlename, ~] = fileparts(matFilePath);

params.events = events;
params.figure = figure('Name', 'Mean Event Data'); % Создание нового окна для графика;
params.meanWindow = meanWindow;
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
params.titlename = titlename;
params.show_spikes = show_spikes;
params.ch_inxs = ch_inxs; % Индексы активированных каналов
params.show_CSD = show_CSD;

% Фильтруем если попросили
if sum(filter_avaliable)>0
    ch_to_filter = filter_avaliable;
    params.lfp(:, ch_to_filter) = applyFilter(lfp(:, ch_to_filter), filterSettings, newFs);        
end
    
[f, calculation_result] = plotMeanEvents(params);
end