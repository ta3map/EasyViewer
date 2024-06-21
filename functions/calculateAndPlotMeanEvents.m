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
global app_path evfilename offsets
global calculation_result
global art_rem_window_ms
global stims

local_evfilename = evfilename;

[mat_file_folder, original_filename, ~] = fileparts(matFilePath);

channelSettings = get(channelTable, 'Data');

params.events = events;
params.figure = figure('Name', 'Mean Event Data', 'Tag', 'meanSignalResult'); % Создание нового окна для графика;
params.meanWindow = 2;% s
params.hd = hd;
params.channelSettings = channelSettings;
params.Fs = Fs;
params.lfp = lfp;
params.N = N;
params.time = time;
params.binsize = binsize;
params.spk_threshold = std_coef;
params.spks = spks;
params.shiftCoeff = shiftCoeff;
params.titlename = local_evfilename;
params.show_spikes = show_spikes;
params.ch_inxs = ch_inxs; % Индексы активированных каналов
params.show_CSD = show_CSD;
params.csd_smooth_coef = csd_smooth_coef;
params.csd_contrast_coef = csd_contrast_coef;
params.csd_active = csd_avaliable(ch_inxs);
params.timeUnitFactor = timeUnitFactor;% экспериментальный не проверенный параметр
params.lfpVar = lfpVar;
params.mean_group_ch = mean_group_ch;


% Убираем артефакт стимуляции
if art_rem_window_ms > 0
    win_r = art_rem_window_ms  * (Fs/1000);
    params.lfp = removeStimArtifact(params.lfp, stims, time, win_r);
    
    stim_inxs = ClosestIndex(stims, time); % Индекс стимулов
    for ch = 1:size(spks, 1)        
        for i = 1:length(stim_inxs) 
            start_inx = stim_inxs(i) - win_r;
            end_inx = stim_inxs(i) + win_r;
            cond5 = params.spks(ch).tStamp/1000 >= time(start_inx) & params.spks(ch).tStamp/1000 < time(end_inx);
            params.spks(ch).tStamp = params.spks(ch).tStamp(~cond5);
            params.spks(ch).ampl = params.spks(ch).ampl(~cond5);
        end
    end        
end

% Фильтруем
if sum(filter_avaliable)>0
    ch_to_filter = filter_avaliable;
    params.lfp(:, ch_to_filter) = applyFilter(params.lfp(:, ch_to_filter), filterSettings, newFs);        
end

close(wb);

[mean_f, calculation_result] = plotMeanEvents(params);
xlim([-time_back, time_forward]*timeUnitFactor)

% обозначаем размеры
colors_in = channelSettings(:, 4)';
colors_in = colors_in(ch_inxs);
x_pos = time_forward*timeUnitFactor;
scaling_coefs = [channelSettings{:, 3}];
scaling_coefs = scaling_coefs(ch_inxs);
k = 0;
for y_pos = offsets+shiftCoeff/2
    k = k+1;
    color = colors_in{k};
    if k == 1 || scaling_coefs(k)~=1 || ~strcmp(color, 'black')
        text(x_pos, y_pos, ['  ', num2str(scaling_coefs(k)*shiftCoeff, 3)], 'color', color);
        plot([x_pos, x_pos], [y_pos+shiftCoeff/2, y_pos-shiftCoeff/2], 'color', color, 'linewidth', 2)
    end
end

xline(0, 'r:');

% Кнопка для сохранения файлов
save_btn_coords = [5, 5, 40, 25];
savebutton = uicontrol('Parent', mean_f, 'Style', 'pushbutton', 'String', 'Save Data', 'Visible', 'off', 'Position', save_btn_coords, 'Callback', @SaveBtnClb);
btnIcon(savebutton, [app_path, '\icons\data-storage.png'], false) % ставим иконку для кнопки

save_btn_coords = [5, 32.5, 40, 25];
saveImgbutton = uicontrol('Parent', mean_f, 'Style', 'pushbutton', 'String', 'Save Image', 'Visible', 'off', 'Position', save_btn_coords, 'Callback', @SaveImageClb);
btnIcon(saveImgbutton, [app_path, '\icons\save image.png'], false) % ставим иконку для кнопки
btn_list = [savebutton, saveImgbutton];

set(mean_f, 'WindowButtonMotionFcn', @(src, event)autoHideBtn(src, event, btn_list));

function SaveBtnClb(~,~)
    set(savebutton, 'Visible', 'off')
    [file,path] = uiputfile([mat_file_folder '/' local_evfilename '_data.mean'], 'Save file name');
    if isequal(file,0) || isequal(path,0)
       disp('User pressed cancel')
    else
       filename = fullfile(path, file);      
       save(filename, '-struct', 'calculation_result');
       save(filename, 'original_filename', '-append');
       
       disp(['Data saved to ', filename]);
    end
end

function SaveImageClb(~,~)
    set(saveImgbutton, 'Visible', 'off')
    [file, path, filterindex] = uiputfile(...
        {'*.pdf', 'PDF files (*.pdf)';...
         '*.eps', 'EPS files (*.eps)';...
         '*.png', 'PNG files (*.png)';...
         '*.*', 'All Files (*.*)'},...
         'Save file name', [mat_file_folder '/' local_evfilename '_mean']);
    if isequal(file,0) || isequal(path,0)
       disp('User pressed cancel');
    else
       filename = fullfile(path, file);      
       switch filterindex
           case 1
               print(mean_f, filename, '-dpdf', '-bestfit');
           case 2
               print(mean_f, filename, '-depsc');
           case 3
               saveas(mean_f, filename, 'png');
           otherwise
               saveas(mean_f, filename);
       end
       disp(['Image saved to ', filename]);
    end
    
end


end