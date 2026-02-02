function [mean_f, calculation_result] = calculateAndPlotMeanEvents(sourceType, opts)
if nargin < 1
    sourceType = 'events'; % обратная совместимость
end
if nargin < 2
    opts = struct();
end
fprintf('Please wait...\n');
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
global wb
global matFileName

if strcmp(sourceType, 'stimuli')
    params.timePoints = stims;
    if isempty(evfilename) || strcmp(evfilename, '')
        if ~isempty(matFileName) && ~strcmp(matFileName, '')
            local_evfilename = matFileName;
        else
            local_evfilename = 'stimuli';
        end
    else
        local_evfilename = evfilename;
    end
    figureName = 'Mean Stimulus Data';
else
    params.timePoints = events;
    local_evfilename = evfilename;
    figureName = 'Mean Event Data';
end

[mat_file_folder, original_filename, ~] = fileparts(matFilePath);

channelSettings = get(channelTable, 'Data');

params.sourceType = sourceType;
buildFigure = ~isfield(opts, 'buildFigure') || logical(opts.buildFigure);
if buildFigure
    params.figure = figure('Name', figureName, 'Tag', 'meanSignalResult');
else
    params.figure = figure('Name', figureName, 'Tag', 'meanSignalResult', 'Visible', 'off');
end
params.figure.Position = [32, 64, 1024, 768];

% Создаем tiledlayout с опциональным размером через opts
% По умолчанию 1x1, но можно задать больше для таблиц и scatter-графиков
if isfield(opts, 'tiledlayoutSize') && ~isempty(opts.tiledlayoutSize)
    tiledRows = opts.tiledlayoutSize(1);
    tiledCols = opts.tiledlayoutSize(2);
else
    tiledRows = 1;
    tiledCols = 1;
end
t = tiledlayout(params.figure, tiledRows, tiledCols, 'TileSpacing', 'compact', 'Padding', 'compact');
params.tiledlayout = t;
% Определяем временное окно для усреднения на основе xLimits
if isfield(opts, 'meanWindow')
    params.meanWindow = opts.meanWindow;
elseif isfield(opts, 'xLimits') && ~isempty(opts.xLimits)
    % Если заданы xLimits, вычисляем окно из них (xLimits в масштабированных единицах)
    % Переводим в секунды и берем максимальное расстояние от нуля
    xLimitsSeconds = opts.xLimits / timeUnitFactor;
    params.meanWindow = max(abs(xLimitsSeconds(1)), abs(xLimitsSeconds(2))) * 2;
else
    params.meanWindow = 2; % значение по умолчанию
end
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
% Определение параметров удаления артефакта: приоритет у параметров из opts
if isfield(opts, 'removeArtifact')
    params.remove_artifact = strcmp(sourceType, 'stimuli') && logical(opts.removeArtifact);
    if isfield(opts, 'artifactWindow_ms')
        artifact_window_ms = opts.artifactWindow_ms;
    else
        artifact_window_ms = art_rem_window_ms;
    end
else
    params.remove_artifact = strcmp(sourceType, 'stimuli') && art_rem_window_ms > 0;
    artifact_window_ms = art_rem_window_ms;
end
if isfield(opts, 'autoScale')
    params.autoScale = logical(opts.autoScale);
else
    params.autoScale = false;
end
if isfield(opts, 'xLimits')
    params.customXLimits = opts.xLimits;
else
    params.customXLimits = [];
end
if isfield(opts, 'showOriginalTraces')
    params.showOriginalTraces = logical(opts.showOriginalTraces);
else
    params.showOriginalTraces = false;
end
if isfield(opts, 'removeBaseline')
    params.removeBaseline = logical(opts.removeBaseline);
else
    params.removeBaseline = false;
end
if isfield(opts, 'SmoothingKernel_s')
    params.SmoothingKernel_s = opts.SmoothingKernel_s;
end
if isfield(opts, 'SubtractMean')
    params.SubtractMean = logical(opts.SubtractMean);
else
    params.SubtractMean = false;
end

% Убираем артефакт стимуляции в окне усреднения
if params.remove_artifact
    win_r = round(artifact_window_ms * (Fs/1000));
    debugState('calculateAndPlotMeanEvents', 'Stim artifact removal: Fs=%dHz, window=%.3f ms (~%d samples)', Fs, artifact_window_ms, win_r);
    params.lfp = removeStimArtifact(params.lfp, stims, time, win_r);
    
    if params.show_spikes
        stim_inxs = ClosestIndex(stims, time); % Индекс стимулов
        for ch = 1:size(spks, 1)
            for i = 1:length(stim_inxs)
                start_inx = stim_inxs(i) - win_r;
                start_inx(start_inx < 1) = 1;
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

try
    delete(wb);
catch
end

[mean_f, calculation_result] = plotMeanEvents(params);
if ~isempty(params.customXLimits)
    Xlims = params.customXLimits;
else
    Xlims = [-time_back, time_forward]*timeUnitFactor;
end
xlim(Xlims)
% Сохраняем пределы X в calcResult для использования в других функциях
calculation_result.xLimits = Xlims;

if ~buildFigure
    close(mean_f);
    mean_f = [];
    fprintf('Mean events calculated.\n');
    return
end

numChannels = numel(ch_inxs);
y_pixel_size = 768;             % Размер по Y в пикселях
y_tick_min_pixel_size = 32;     % Минимальный размер тиков по Y в пикселях
[chRanges, chRangesOffsets, chRangeIndexes] = calculateChRanges(offsets, shiftCoeff, calculation_result.meanData, ...
    numChannels, calculation_result.scalingCoefficients(ch_inxs), y_pixel_size, y_tick_min_pixel_size);

% Корректируем значения chRanges и смещаем обозначения к базовой линии (медиане) каждого канала
if isfield(calculation_result, 'baseline_medians')
    baseline_medians = calculation_result.baseline_medians;
    for ch_inx = 1:numChannels
        ch_mask = chRangeIndexes == ch_inx;
        % baseline_medians уже в масштабе данных, нужно добавить обратно с учетом m_coef
        chRanges(ch_mask) = chRanges(ch_mask) + baseline_medians(ch_inx) / calculation_result.scalingCoefficients(ch_inxs(ch_inx));
        % Смещаем обозначения по Y к медиане канала
        chRangesOffsets(ch_mask) = chRangesOffsets(ch_mask) + baseline_medians(ch_inx);
    end
end

rangesTimeTicks = Xlims(1)+zeros(size(chRangesOffsets)) + 0.02*(Xlims(end) - Xlims(1));    
rangesTimeLabels = Xlims(1)+zeros(size(chRangesOffsets)) + 0.005*(Xlims(end) - Xlims(1)); 
colors_in = channelSettings(:, 4)';
colors_in_selected = colors_in(ch_inxs);
    ch_inx = 0;
    for color = colors_in_selected
        ch_inx = ch_inx+1;
        group_index = ch_inx == chRangeIndexes;
        text(rangesTimeTicks(group_index), chRangesOffsets(group_index), num2str(chRanges(group_index)', '%.2f'), 'color', color{:}, 'BackgroundColor', 'none')
        scatter(rangesTimeLabels(group_index), chRangesOffsets(group_index), [], 'Marker', '_', 'MarkerEdgeColor', color{:})
    end

% Вычисляем и применяем пределы Y с учетом смещения к медиане
ax = findobj(mean_f, 'Type', 'axes', '-not', 'Tag', 'legend');
if ~isempty(ax)
    ax = ax(1);
    if isfield(calculation_result, 'baseline_medians')
        % Учитываем смещение данных и обозначений
        baseline_medians = calculation_result.baseline_medians;
        minOffset = min(offsets);
        maxOffset = max(offsets);
        minBaseline = min(baseline_medians);
        maxBaseline = max(baseline_medians);
        % Учитываем смещенные обозначения и позиции медиан каналов
        Ylims = [min([chRangesOffsets(:); minOffset + minBaseline]) - shiftCoeff*0.2, ...
                 max([chRangesOffsets(:); maxOffset + maxBaseline]) + shiftCoeff*0.2];
    else
        Ylims = [min(chRangesOffsets)-shiftCoeff*0.5, max(chRangesOffsets)+shiftCoeff*0.5];
    end
    ylim(ax, Ylims);
end



xline(0, 'r:');

% Кнопка для сохранения файлов
save_btn_coords = [5, 5, 40, 25];
savebutton = uicontrol('Parent', mean_f, 'Style', 'pushbutton', 'String', 'Save Data', 'Visible', 'off', 'Position', save_btn_coords, 'Callback', @SaveBtnClb);
btnIcon(savebutton, fullfile(getAssetsPath(), 'data-storage.png'), false) % ставим иконку для кнопки

save_btn_coords = [5, 32.5, 40, 25];
saveImgbutton = uicontrol('Parent', mean_f, 'Style', 'pushbutton', 'String', 'Save Image', 'Visible', 'off', 'Position', save_btn_coords, 'Callback', @SaveImageClb);
btnIcon(saveImgbutton, fullfile(getAssetsPath(), 'save_image.png'), false) % ставим иконку для кнопки
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

fprintf('Mean events calculated.\n');
end