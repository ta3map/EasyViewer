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
global t_mean_profile

local_evfilename = evfilename;

[mat_file_folder, original_filename, ~] = fileparts(matFilePath);

channelSettings = get(channelTable, 'Data');

params.events = events;
params.figure = figure('Name', 'Mean Event Data', 'Tag', 'meanSignalResult'); % Создание нового окна для графика;
params.figure.Position = [32, 64, 1024, 768];
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
params.timeUnitFactor = timeUnitFactor;
params.lfpVar = lfpVar;
params.mean_group_ch = mean_group_ch;
params.t_profile = t_mean_profile;

% Убираем артефакт стимуляции
if params.show_spikes
    if art_rem_window_ms > 0
        win_r = art_rem_window_ms  * (Fs/1000);
        params.lfp = removeStimArtifact(params.lfp, stims, time, win_r);

        stim_inxs = ClosestIndex(stims, time); % Индекс стимулов
        for ch = 1:size(spks, 1)        
            for i = 1:length(stim_inxs) 
                start_inx = stim_inxs(i) - win_r;
                start_inx(start_inx<1) = 1;
                end_inx = stim_inxs(i) + win_r;
                cond5 = params.spks(ch).tStamp/1000 >= time(start_inx) & params.spks(ch).tStamp/1000 < time(end_inx);
                params.spks(ch).tStamp = params.spks(ch).tStamp(~cond5);
                params.spks(ch).ampl = params.spks(ch).ampl(~cond5);
            end
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
Xlims = [-time_back, time_forward]*timeUnitFactor;
xlim(Xlims)

numChannels = numel(ch_inxs);
y_pixel_size = 768;             % Размер по Y в пикселях
y_tick_min_pixel_size = 32;     % Минимальный размер тиков по Y в пикселях
[chRanges, chRangesOffsets, chRangeIndexes] = calculateChRanges(offsets, shiftCoeff, calculation_result.meanData, ...
    numChannels, calculation_result.scalingCoefficients(ch_inxs), y_pixel_size, y_tick_min_pixel_size);
rangesTimeTicks = Xlims(1)+zeros(size(chRangesOffsets)) + 0.02*(Xlims(end) - Xlims(1));    
rangesTimeLabels = Xlims(1)+zeros(size(chRangesOffsets)) + 0.005*(Xlims(end) - Xlims(1)); 
colors_in = channelSettings(:, 4)';
colors_in_selected = colors_in(ch_inxs);
ch_inx = 0;
for color = colors_in_selected
    ch_inx = ch_inx+1;
    group_index = ch_inx == chRangeIndexes;
    text(rangesTimeTicks(group_index), chRangesOffsets(group_index), num2str(chRanges(group_index)', '%.2f'), 'color', color{:}, 'backgroundcolor', 'w')
    scatter(rangesTimeLabels(group_index), chRangesOffsets(group_index), '_', color{:})
end

Ylims = [min(chRangesOffsets)-shiftCoeff*0.5, max(chRangesOffsets)+shiftCoeff*0.5];
ylim(Ylims)

% % обозначаем размеры
% colors_in = channelSettings(:, 4)';
% colors_in = colors_in(ch_inxs);
% x_pos = time_forward*timeUnitFactor;
% scaling_coefs = [channelSettings{:, 3}];
% scaling_coefs = scaling_coefs(ch_inxs);
% k = 0;
% for y_pos = offsets+shiftCoeff/2
%     k = k+1;
%     color = colors_in{k};
%     if k == 1 || scaling_coefs(k)~=1 || ~strcmp(color, 'black')
%         text(x_pos, y_pos, ['  ', num2str(scaling_coefs(k)*shiftCoeff, 3)], 'color', color);
%         plot([x_pos, x_pos], [y_pos+shiftCoeff/2, y_pos-shiftCoeff/2], 'color', color, 'linewidth', 2)
%     end
% end

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