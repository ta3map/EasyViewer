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
global lfp_file hd spks
global matFilePath
global timeUnitFactor 
global events 
global newFs
global time_back time_forward
global std_coef binsize % спайки/CSD
global visualSettings
global csd_avaliable filter_avaliable filterSettings
global channelTable csd_smooth_coef csd_contrast_coef
global csd_split_by_channel_gaps
global lfpVar 
global mean_group_ch
global app_path evfilename offsets
global calculation_result
global art_rem_settings
global stims
global t_mean_profile
global wb
global matFileName
global axes_background_color

wbCreatedHere = isempty(wb) || ~isvalid(wb);
if wbCreatedHere
    wb = waitbar(0.10, 'Preparing mean trace...', 'Name', 'Mean Events');
else
    waitbar(0.10, wb, 'Preparing mean trace...');
end
drawnow;

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
params.csd_split_by_channel_gaps = true;
buildFigure = ~isfield(opts, 'buildFigure') || logical(opts.buildFigure);
if isfield(opts, 'tiledlayoutSize') && ~isempty(opts.tiledlayoutSize)
    tiledRows = opts.tiledlayoutSize(1);
    tiledCols = opts.tiledlayoutSize(2);
else
    tiledRows = 1;
    tiledCols = 1;
end
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
params.lfp = lfp_file.lfp;
params.N = N;
params.time = time;
params.binsize = binsize;
params.spk_threshold = std_coef;
params.spks = spks;
params.shiftCoeff = shiftCoeff;
params.titlename = local_evfilename;
params.show_spikes = visualSettings.show_spikes;
params.ch_inxs = ch_inxs; % Индексы активированных каналов
params.show_CSD = visualSettings.show_CSD;
params.csd_smooth_coef = csd_smooth_coef;
params.csd_contrast_coef = csd_contrast_coef;
params.csd_active = csd_avaliable(ch_inxs);
params.timeUnitFactor = timeUnitFactor;
params.lfpVar = lfpVar;
params.mean_group_ch = mean_group_ch;
params.t_profile = t_mean_profile;

if ~isempty(wb) && isvalid(wb)
    waitbar(0.15, wb, 'Preparing input data...');
    drawnow;
end
% Определение параметров удаления артефакта: приоритет у параметров из opts
if isfield(opts, 'removeArtifact')
    params.remove_artifact = strcmp(sourceType, 'stimuli') && logical(opts.removeArtifact);
    if isfield(opts, 'artifactWindow_ms')
        artifact_window_ms = opts.artifactWindow_ms;
    else
        artifact_window_ms = art_rem_settings.artifact_window_ms;
    end
else
    params.remove_artifact = strcmp(sourceType, 'stimuli') && art_rem_settings.artifact_window_ms > 0;
    artifact_window_ms = art_rem_settings.artifact_window_ms;
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
    if ~isempty(wb) && isvalid(wb)
        waitbar(0.3, wb, 'Removing stimulus artifacts...');
        drawnow;
    end
    params.lfp = removeStimArtifact(params.lfp, stims, time, win_r, art_rem_settings.interp_method);
    
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
    if ~isempty(wb) && isvalid(wb)
        waitbar(0.5, wb, sprintf('Applying filters (channels: %d)...', sum(ch_to_filter)));
        drawnow;
    end
    params.lfp(:, ch_to_filter) = applyFilter(params.lfp(:, ch_to_filter), filterSettings, newFs);        
end

if ~isempty(wb) && isvalid(wb)
    waitbar(0.85, wb, 'Rendering mean trace...');
    drawnow;
end

renderBothModes = params.show_CSD && params.show_spikes;
numEvents = numel(params.timePoints);
if renderBothModes
    params_csd = params;
    params_csd.show_CSD = true;
    params_csd.show_spikes = false;
    params_csd = createRenderParams(params_csd);
    [mean_f_csd, calculation_result_csd] = plotMeanEvents(params_csd);
    [mean_f_csd, calculation_result_csd] = finalizeMeanFigure(mean_f_csd, calculation_result_csd, ' [CSD]', false);

    params_mua = params;
    params_mua.show_CSD = false;
    params_mua.show_spikes = true;
    params_mua = createRenderParams(params_mua);
    [mean_f_mua, calculation_result_mua] = plotMeanEvents(params_mua);
    [mean_f_mua, calculation_result_mua] = finalizeMeanFigure(mean_f_mua, calculation_result_mua, ' [MUA]', false);

    mean_f = [mean_f_csd, mean_f_mua];
    calculation_result = struct('csd', calculation_result_csd, 'mua', calculation_result_mua);
else
    params = createRenderParams(params);
    [mean_f, calculation_result] = plotMeanEvents(params);
    [mean_f, calculation_result] = finalizeMeanFigure(mean_f, calculation_result, '', true);
end

if ~buildFigure
    fprintf('Mean events calculated.\n');
    if ~isempty(wb) && isvalid(wb)
        waitbar(1.0, wb, 'Complete');
        drawnow;
    end
    if wbCreatedHere && ~isempty(wb) && isvalid(wb)
        delete(wb);
    end
    return
end

function paramsOut = createRenderParams(paramsIn)
paramsOut = paramsIn;
if buildFigure
    paramsOut.figure = figure('Name', figureName, 'Tag', 'meanSignalResult', ...
        'MenuBar', 'none', 'ToolBar', 'figure');
else
    paramsOut.figure = figure('Name', figureName, 'Tag', 'meanSignalResult', 'Visible', 'off', ...
        'MenuBar', 'none', 'ToolBar', 'figure');
end
paramsOut.figure.Position = [32, 64, 1024, 768];
set(paramsOut.figure, 'WindowButtonMotionFcn', []);

hToolbar = findall(paramsOut.figure, 'Type', 'uitoolbar');
if ~isempty(hToolbar)
    set(hToolbar, 'Visible', 'off');
end
paramsOut.tiledlayout = tiledlayout(paramsOut.figure, tiledRows, tiledCols, 'TileSpacing', 'compact', 'Padding', 'compact');
end

function [figureHandleOut, calculationResultOut] = finalizeMeanFigure(meanFigureIn, calculationResultIn, nameSuffix, drawRangeLabels)
figureHandleOut = meanFigureIn;
calculationResultOut = calculationResultIn;

if strcmp(sourceType, 'stimuli')
    figureHandleOut.Name = [figureName, ': ', local_evfilename, ' (', num2str(numEvents), ' stimuli)', nameSuffix];
else
    figureHandleOut.Name = [figureName, ': ', local_evfilename, ' (', num2str(numEvents), ' events)', nameSuffix];
end

bgHex = axes_background_color;
if isempty(bgHex)
    bgHex = '#FFFFFF';
end
bgRgb = hex2rgb_meanEvents(bgHex);
axesHandles = findobj(figureHandleOut, 'Type', 'axes');
for iAx = 1:numel(axesHandles)
    axh = axesHandles(iAx);
    if isprop(axh, 'Color')
        set(axh, 'Color', bgRgb);
    end
end

if ~isempty(params.customXLimits)
    Xlims = params.customXLimits;
else
    Xlims = [-time_back, time_forward]*timeUnitFactor;
end
xlim(Xlims)
calculationResultOut.xLimits = Xlims;

if ~buildFigure
    close(figureHandleOut);
    figureHandleOut = [];
    return
end

numChannels = numel(ch_inxs);
y_pixel_size = 768;
y_tick_min_pixel_size = 32;
[chRanges, chRangesOffsets, chRangeIndexes] = calculateChRanges(offsets, shiftCoeff, calculationResultOut.meanData, ...
    numChannels, calculationResultOut.scalingCoefficients(ch_inxs), y_pixel_size, y_tick_min_pixel_size);

if isfield(calculationResultOut, 'baseline_medians')
    baseline_medians = calculationResultOut.baseline_medians;
    for ch_inx = 1:numChannels
        ch_mask = chRangeIndexes == ch_inx;
        chRanges(ch_mask) = chRanges(ch_mask) + baseline_medians(ch_inx) / calculationResultOut.scalingCoefficients(ch_inxs(ch_inx));
        chRangesOffsets(ch_mask) = chRangesOffsets(ch_mask) + baseline_medians(ch_inx);
    end
end

if drawRangeLabels
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
end

ax = findobj(figureHandleOut, 'Type', 'axes', '-not', 'Tag', 'legend');
if ~isempty(ax)
    mainAx = [];
    for iAx = 1:numel(ax)
        xLbl = get(get(ax(iAx), 'XLabel'), 'String');
        if ischar(xLbl) && strcmp(xLbl, 'Time')
            mainAx = ax(iAx);
            break
        end
    end
    if isempty(mainAx)
        mainAx = ax(1);
    end
    if visualSettings.show_full_signal
        pl_meanData = calculationResultOut.meanData(:, ch_inxs) .* calculationResultOut.scalingCoefficients(ch_inxs);
        data_with_offsets = pl_meanData + offsets;
        yMin = min(data_with_offsets(:));
        yMax = max(data_with_offsets(:));
        margin = (yMax - yMin) * 0.05;
        Ylims = [yMin - margin, yMax + margin];
    elseif isfield(calculationResultOut, 'baseline_medians')
        baseline_medians = calculationResultOut.baseline_medians;
        minOffset = min(offsets);
        maxOffset = max(offsets);
        minBaseline = min(baseline_medians);
        maxBaseline = max(baseline_medians);
        Ylims = [min([chRangesOffsets(:); minOffset + minBaseline]) - shiftCoeff*0.2, ...
                 max([chRangesOffsets(:); maxOffset + maxBaseline]) + shiftCoeff*0.2];
    else
        Ylims = [min(chRangesOffsets)-shiftCoeff*0.5, max(chRangesOffsets)+shiftCoeff*0.5];
    end
    ylim(mainAx, Ylims);
    for iAx = 1:numel(ax)
        if ax(iAx) ~= mainAx
            ylim(ax(iAx), Ylims);
        end
    end
end

xline(0, 'r:');
save_btn_coords = [5, 5, 40, 25];
savebutton = uicontrol('Parent', figureHandleOut, 'Style', 'pushbutton', 'String', 'Save', ...
    'Visible', 'on', 'Position', save_btn_coords, 'Callback', @SaveClb);
btnIcon(savebutton, fullfile(getAssetsPath(), 'data-storage.png'), false)

function SaveClb(~,~)
    [file, path] = uiputfile(...
        {'*.png',  'PNG image (*.png)'; ...
         '*.fig',  'MATLAB figure (*.fig)'; ...
         '*.pdf',  'PDF file (*.pdf)'; ...
         '*.eps',  'EPS file (*.eps)'; ...
         '*.*',    'All Files (*.*)'; ...
         '*.mean', 'Mean data (*.mean)'}, ...
        'Save file name', fullfile(mat_file_folder, [local_evfilename '_mean']));
    if isequal(file, 0) || isequal(path, 0)
        disp('User pressed cancel');
        return
    end

    filename = fullfile(path, file);
    [~, ~, ext] = fileparts(filename);

    switch lower(ext)
        case '.mean'
            data_to_save = calculationResultOut;
            save(filename, '-struct', 'data_to_save');
            save(filename, 'original_filename', '-append');
            disp(['Data saved to ', filename]);
        case '.fig'
            fclose('all');
            drawnow;
            deleteSaveButton_meanEvents();
            restoreSaveBtn = onCleanup(@() createSaveButton_meanEvents());
            savefig(figureHandleOut, filename, 'compact');
            disp(['Figure saved to ', filename]);
        case '.pdf'
            print(figureHandleOut, filename, '-dpdf', '-bestfit');
            disp(['Image saved to ', filename]);
        case '.eps'
            print(figureHandleOut, filename, '-depsc');
            disp(['Image saved to ', filename]);
        case '.png'
            saveas(figureHandleOut, filename, 'png');
            disp(['Image saved to ', filename]);
        otherwise
            saveas(figureHandleOut, filename);
            disp(['Saved to ', filename]);
    end
end

function deleteSaveButton_meanEvents()
if ~isempty(savebutton) && isgraphics(savebutton, 'uicontrol')
    delete(savebutton);
end
end

function createSaveButton_meanEvents()
if ~isgraphics(figureHandleOut, 'figure')
    return
end
savebutton = uicontrol('Parent', figureHandleOut, 'Style', 'pushbutton', 'String', 'Save', ...
    'Visible', 'on', 'Position', save_btn_coords, 'Callback', @SaveClb);
btnIcon(savebutton, fullfile(getAssetsPath(), 'data-storage.png'), false)
end
end

fprintf('Mean events calculated.\n');
if ~isempty(wb) && isvalid(wb)
    waitbar(1.0, wb, 'Complete');
    drawnow;
end
if wbCreatedHere && ~isempty(wb) && isvalid(wb)
    delete(wb);
end
end

function rgb = hex2rgb_meanEvents(hexColor)
hexColor = strrep(hexColor, '#', '');
r = hex2dec(hexColor(1:2)) / 255;
g = hex2dec(hexColor(3:4)) / 255;
b = hex2dec(hexColor(5:6)) / 255;
rgb = [r, g, b];
end