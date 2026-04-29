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
global meanControlsState

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
totalTimePoints = numel(params.timePoints);
if isfield(opts, 'startIndex') || isfield(opts, 'endIndex')
    startIndex = 1;
    endIndex = totalTimePoints;
    if isfield(opts, 'startIndex')
        startIndex = round(double(opts.startIndex));
    end
    if isfield(opts, 'endIndex')
        endIndex = round(double(opts.endIndex));
    end
    validRange = totalTimePoints >= 1 && startIndex >= 1 && endIndex <= totalTimePoints && startIndex <= endIndex;
    if ~validRange
        error('Invalid mean index range [%d, %d]. Available range: [1, %d].', startIndex, endIndex, totalTimePoints);
    end
    params.timePoints = params.timePoints(startIndex:endIndex);
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
if isfield(opts, 'shiftCoeff')
    params.shiftCoeff = double(opts.shiftCoeff);
else
    params.shiftCoeff = shiftCoeff;
end
params.titlename = local_evfilename;
if isfield(opts, 'show_spikes')
    params.show_spikes = logical(opts.show_spikes);
else
    params.show_spikes = visualSettings.show_spikes;
end
params.ch_inxs = ch_inxs; % Индексы активированных каналов
if isfield(opts, 'show_CSD')
    params.show_CSD = logical(opts.show_CSD);
else
    params.show_CSD = visualSettings.show_CSD;
end
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
if isfield(opts, 'csd_hp_cutoff_hz')
    params.csd_hp_cutoff_hz = max(0, double(opts.csd_hp_cutoff_hz));
else
    params.csd_hp_cutoff_hz = 100;
end
if isfield(opts, 'csd_baseline_boundary')
    params.csd_baseline_boundary = double(opts.csd_baseline_boundary);
else
    if ~isempty(params.customXLimits) && numel(params.customXLimits) == 2
        params.csd_baseline_boundary = params.customXLimits(1) / 2;
    else
        params.csd_baseline_boundary = (-time_back * timeUnitFactor) / 2;
    end
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
    params_csd = createRenderParams(params_csd, [0, 0]);
    [mean_f_csd, calculation_result_csd] = plotMeanEvents(params_csd);
    [mean_f_csd, calculation_result_csd] = finalizeMeanFigure(mean_f_csd, calculation_result_csd, ' [CSD]', false);

    params_mua = params;
    params_mua.show_CSD = false;
    params_mua.show_spikes = true;
    params_mua = createRenderParams(params_mua, [36, -36]);
    [mean_f_mua, calculation_result_mua] = plotMeanEvents(params_mua);
    [mean_f_mua, calculation_result_mua] = finalizeMeanFigure(mean_f_mua, calculation_result_mua, ' [MUA]', false);

    mean_f = [mean_f_csd, mean_f_mua];
    calculation_result = struct('csd', calculation_result_csd, 'mua', calculation_result_mua);
else
    params = createRenderParams(params, [0, 0]);
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

function paramsOut = createRenderParams(paramsIn, positionShift)
paramsOut = paramsIn;
if buildFigure
    paramsOut.figure = figure('Name', figureName, 'Tag', 'meanSignalResult', ...
        'MenuBar', 'none', 'ToolBar', 'figure');
else
    paramsOut.figure = figure('Name', figureName, 'Tag', 'meanSignalResult', 'Visible', 'off', ...
        'MenuBar', 'none', 'ToolBar', 'figure');
end
basePosition = [32, 64, 1024, 820];
paramsOut.figure.Position = basePosition + [positionShift(1), positionShift(2), 0, 0];
set(paramsOut.figure, 'WindowButtonMotionFcn', []);

hToolbar = findall(paramsOut.figure, 'Type', 'uitoolbar');
if ~isempty(hToolbar)
    set(hToolbar, 'Visible', 'off');
end
plotContainerBottom = 0.06;
paramsOut.plotContainer = uipanel('Parent', paramsOut.figure, ...
    'Tag', 'mean_plot_container', ...
    'Units', 'normalized', ...
    'Position', [0, plotContainerBottom, 1, 1 - plotContainerBottom], ...
    'BorderType', 'none');
setappdata(paramsOut.figure, 'meanPlotContainer', paramsOut.plotContainer);
paramsOut.axesContainer = uipanel('Parent', paramsOut.plotContainer, ...
    'Tag', 'mean_axes_container', ...
    'Units', 'normalized', ...
    'Position', [0.02, 0.08, 0.96, 0.90], ...
    'BorderType', 'none');
setappdata(paramsOut.figure, 'meanAxesContainer', paramsOut.axesContainer);
paramsOut.tiledlayout = tiledlayout(paramsOut.plotContainer, tiledRows, tiledCols, 'TileSpacing', 'compact', 'Padding', 'compact');
set(paramsOut.tiledlayout, 'Visible', 'off');
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
plotOffsets = zeros(1, numChannels);
for p = 1:numChannels
    plotOffsets(p) = -(p-1) * params.shiftCoeff;
end
y_pixel_size = 768;
y_tick_min_pixel_size = 32;
[chRanges, chRangesOffsets, chRangeIndexes] = calculateChRanges(plotOffsets, params.shiftCoeff, calculationResultOut.meanData, ...
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
        data_with_offsets = pl_meanData + plotOffsets;
        yMin = min(data_with_offsets(:));
        yMax = max(data_with_offsets(:));
        margin = (yMax - yMin) * 0.05;
        Ylims = [yMin - margin, yMax + margin];
    elseif isfield(calculationResultOut, 'baseline_medians')
        baseline_medians = calculationResultOut.baseline_medians;
        minOffset = min(plotOffsets);
        maxOffset = max(plotOffsets);
        minBaseline = min(baseline_medians);
        maxBaseline = max(baseline_medians);
        Ylims = [min([chRangesOffsets(:); minOffset + minBaseline]) - params.shiftCoeff*0.2, ...
                 max([chRangesOffsets(:); maxOffset + maxBaseline]) + params.shiftCoeff*0.2];
    else
        Ylims = [min(chRangesOffsets)-params.shiftCoeff*0.5, max(chRangesOffsets)+params.shiftCoeff*0.5];
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
reset_btn_coords = [5, 33, 40, 25];
savebutton = uicontrol('Parent', figureHandleOut, 'Style', 'pushbutton', 'String', 'Save', ...
    'Visible', 'on', 'Position', save_btn_coords, 'Callback', @SaveClb);
resetbutton = uicontrol('Parent', figureHandleOut, 'Style', 'pushbutton', 'String', 'Reset', ...
    'Visible', 'on', 'Position', reset_btn_coords, 'Callback', @ResetClb);
btnIcon(savebutton, fullfile(getAssetsPath(), 'data-storage.png'), false)
contrast_text_coords = [55, 7, 70, 20];
contrast_edit_coords = [120, 7, 40, 20];
contrast_slider_coords = [162, 9, 70, 18];
hp_text_coords = [280, 7, 38, 20];
hp_edit_coords = [318, 7, 45, 20];
hp_slider_coords = [365, 9, 70, 18];
hp_active_checkbox_coords = [262, 9, 16, 18];
baseline_text_coords = [450, 7, 55, 20];
baseline_edit_coords = [490, 7, 50, 20];
baseline_slider_coords = [543, 9, 70, 18];
smooth_text_coords = [618, 7, 41, 20];
smooth_edit_coords = [657, 7, 41, 20];
smooth_slider_coords = [705, 9, 70, 18];
xmin_text_coords = [787, 7, 32, 20];
xmin_edit_coords = [817, 7, 38, 20];
xmax_text_coords = [857, 7, 32, 20];
xmax_edit_coords = [893, 7, 38, 20];
mua_trace_checkbox_coords = [940, 7, 95, 20];
colormap_text_coords = [55, 33, 62, 20];
colormap_popup_coords = [117, 33, 118, 22];
lfp_spacing_text_coords = [250, 33, 78, 20];
lfp_spacing_edit_coords = [326, 33, 44, 20];
lfp_spacing_slider_coords = [372, 35, 86, 18];
secondary_axes_checkbox_coords = [468, 33, 120, 20];
contrastCoefMin = 10;
contrastCoefMax = 250;
contrastSliderMax = 100;
hpSliderMax = 100;
minHpCutoff = 0.01;
baselineSliderMax = 100;
smoothSigmaMin = 0;
smoothSigmaMax = 5;
smoothSliderMax = 100;
shiftSliderMax = 100;
minShiftSpacing = 1;
maxShiftSpacing = max(1000, params.shiftCoeff * 4);
contrastLabel = [];
contrastEdit = [];
contrastSlider = [];
hpLabel = [];
hpEdit = [];
hpSlider = [];
hpActiveCheckbox = [];
hpFilterEnabled = true;
baselineLabel = [];
baselineEdit = [];
baselineSlider = [];
smoothLabel = [];
smoothEdit = [];
smoothSlider = [];
colormapLabel = [];
colormapPopup = [];
lfpSpacingLabel = [];
lfpSpacingEdit = [];
lfpSpacingSlider = [];
secondaryAxesCheckbox = [];
colormapNames = {'parula', 'turbo', 'jet', 'gray'};
currentColormapName = colormapNames{1};
xMinLabel = [];
xMinEdit = [];
xMaxLabel = [];
xMaxEdit = [];
muaTraceWhiteCheckbox = [];
useWhiteTracesInMua = true;
refreshDebounceTimer = [];
refreshDebounceDelay = 0.18;
defaultXlims = Xlims;
currentXlims = Xlims;
currentShiftSpacing = params.shiftCoeff;
showSecondaryAxes = true;
currentHpCutoff = 100;
currentBaselineBoundary = currentXlims(1) / 2;
currentContrastPercent = defaultContrastPercent();
currentHeatmapSmoothSigma = defaultHeatmapSmoothSigma();
if isfield(calculationResultOut, 'csd_hp_cutoff_hz')
    currentHpCutoff = calculationResultOut.csd_hp_cutoff_hz;
end
if isfield(calculationResultOut, 'csd_baseline_boundary')
    currentBaselineBoundary = calculationResultOut.csd_baseline_boundary;
end
maxHpCutoff = 500;
restoreMeanControlsState();
[contrastCenter, contrastHalfSpan] = resolveContrastBaseline();
createContrastControls();
createPreCsdControls();

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
            exportPlotContainerOnly(filename, '.pdf');
            disp(['Image saved to ', filename]);
        case '.eps'
            exportPlotContainerOnly(filename, '.eps');
            disp(['Image saved to ', filename]);
        case '.png'
            exportPlotContainerOnly(filename, '.png');
            disp(['Image saved to ', filename]);
        otherwise
            saveas(figureHandleOut, filename);
            disp(['Saved to ', filename]);
    end
end

function exportPlotContainerOnly(filename, ext)
plotContainerHandle = getappdata(figureHandleOut, 'meanPlotContainer');
if isempty(plotContainerHandle) || ~isgraphics(plotContainerHandle, 'uipanel')
    saveas(figureHandleOut, filename);
    return
end
tempFig = figure('Visible', 'off', 'Color', [1 1 1], 'MenuBar', 'none', 'ToolBar', 'none');
cleanupTempFigure = onCleanup(@() deleteIfGraphic(tempFig));
set(tempFig, 'Units', get(figureHandleOut, 'Units'), 'Position', get(figureHandleOut, 'Position'));
plotContainerCopy = copyobj(plotContainerHandle, tempFig);
set(plotContainerCopy, 'Units', 'normalized', 'Position', [0 0 1 1], 'BorderType', 'none');
switch lower(ext)
    case '.pdf'
        print(tempFig, filename, '-dpdf', '-bestfit');
    case '.eps'
        print(tempFig, filename, '-depsc');
    case '.png'
        saveas(tempFig, filename, 'png');
    otherwise
        saveas(tempFig, filename);
end
end

function deleteIfGraphic(h)
if ~isempty(h) && isgraphics(h)
    delete(h);
end
end

function ResetClb(~, ~)
    userChoice = questdlg('Reset Mean controls to defaults?', 'Reset controls', 'Yes', 'No', 'No');
    if ~strcmp(userChoice, 'Yes')
        return
    end
    currentXlims = defaultXlims;
    currentContrastPercent = defaultContrastPercent();
    currentHpCutoff = 100;
    currentBaselineBoundary = defaultXlims(1) / 2;
    hpFilterEnabled = true;
    useWhiteTracesInMua = true;
    currentHeatmapSmoothSigma = defaultHeatmapSmoothSigma();
    currentColormapName = colormapNames{1};
    currentShiftSpacing = params.shiftCoeff;
    syncPreCsdControls();
    applyCurrentColormap();
    applyXlimToAxes();
    saveMeanControlsState();
    requestDebouncedRefresh();
end

function deleteSaveButton_meanEvents()
if ~isempty(resetbutton) && isgraphics(resetbutton, 'uicontrol')
    delete(resetbutton);
end
if ~isempty(savebutton) && isgraphics(savebutton, 'uicontrol')
    delete(savebutton);
end
deleteContrastControls();
deletePreCsdControls();
end

function createSaveButton_meanEvents()
if ~isgraphics(figureHandleOut, 'figure')
    return
end
savebutton = uicontrol('Parent', figureHandleOut, 'Style', 'pushbutton', 'String', 'Save', ...
    'Visible', 'on', 'Position', save_btn_coords, 'Callback', @SaveClb);
resetbutton = uicontrol('Parent', figureHandleOut, 'Style', 'pushbutton', 'String', 'Reset', ...
    'Visible', 'on', 'Position', reset_btn_coords, 'Callback', @ResetClb);
btnIcon(savebutton, fullfile(getAssetsPath(), 'data-storage.png'), false)
createContrastControls();
createPreCsdControls();
end

function createContrastControls()
if contrastHalfSpan <= 0
    return
end
initialCoef = currentContrastPercent;
initialSliderValue = sliderFromCoef(initialCoef);
contrastLabel = uicontrol('Parent', figureHandleOut, 'Style', 'text', 'String', 'Contrast, %', ...
    'Position', contrast_text_coords, 'HorizontalAlignment', 'left');
contrastEdit = uicontrol('Parent', figureHandleOut, 'Style', 'edit', 'String', num2str(initialCoef, '%.3g'), ...
    'BackgroundColor', 'white', 'Position', contrast_edit_coords, 'Callback', @ContrastEditClb);
contrastSlider = uicontrol('Parent', figureHandleOut, 'Style', 'slider', 'Min', 0, 'Max', contrastSliderMax, ...
    'Value', initialSliderValue, 'Position', contrast_slider_coords, 'Callback', @ContrastSliderClb);
applyContrast(initialCoef);
end

function deleteContrastControls()
if ~isempty(contrastLabel) && isgraphics(contrastLabel, 'uicontrol')
    delete(contrastLabel);
end
if ~isempty(contrastEdit) && isgraphics(contrastEdit, 'uicontrol')
    delete(contrastEdit);
end
if ~isempty(contrastSlider) && isgraphics(contrastSlider, 'uicontrol')
    delete(contrastSlider);
end
contrastLabel = [];
contrastEdit = [];
contrastSlider = [];
end

function createPreCsdControls()
currentHpCutoff = clampHp(currentHpCutoff);
currentShiftSpacing = clampShiftSpacing(currentShiftSpacing);
hpLabel = uicontrol('Parent', figureHandleOut, 'Style', 'text', 'String', 'HP, Hz', ...
    'Position', hp_text_coords, 'HorizontalAlignment', 'left');
hpEdit = uicontrol('Parent', figureHandleOut, 'Style', 'edit', ...
    'String', sprintf('%.2f', currentHpCutoff), 'BackgroundColor', 'white', ...
    'Position', hp_edit_coords, 'Callback', @HpEditClb);
hpSlider = uicontrol('Parent', figureHandleOut, 'Style', 'slider', ...
    'Min', 0, 'Max', hpSliderMax, 'Value', hpSliderFromValue(currentHpCutoff), ...
    'Position', hp_slider_coords, 'Callback', @HpSliderClb);
hpActiveCheckbox = uicontrol('Parent', figureHandleOut, 'Style', 'checkbox', ...
    'String', '', 'Value', double(hpFilterEnabled), ...
    'Position', hp_active_checkbox_coords, 'Callback', @HpActiveCheckboxClb);

baselineLabel = uicontrol('Parent', figureHandleOut, 'Style', 'text', 'String', 'Base to', ...
    'Position', baseline_text_coords, 'HorizontalAlignment', 'left');
baselineEdit = uicontrol('Parent', figureHandleOut, 'Style', 'edit', ...
    'String', num2str(currentBaselineBoundary, '%.3g'), 'BackgroundColor', 'white', ...
    'Position', baseline_edit_coords, 'Callback', @BaselineEditClb);
baselineSlider = uicontrol('Parent', figureHandleOut, 'Style', 'slider', ...
    'Min', 0, 'Max', baselineSliderMax, 'Value', baselineSliderFromValue(currentBaselineBoundary), ...
    'Position', baseline_slider_coords, 'Callback', @BaselineSliderClb);
smoothLabel = uicontrol('Parent', figureHandleOut, 'Style', 'text', 'String', 'Smooth', ...
    'Position', smooth_text_coords, 'HorizontalAlignment', 'left');
smoothEdit = uicontrol('Parent', figureHandleOut, 'Style', 'edit', ...
    'String', num2str(currentHeatmapSmoothSigma, '%.3g'), 'BackgroundColor', 'white', ...
    'Position', smooth_edit_coords, 'Callback', @SmoothEditClb);
smoothSlider = uicontrol('Parent', figureHandleOut, 'Style', 'slider', ...
    'Min', 0, 'Max', smoothSliderMax, 'Value', smoothSliderFromValue(currentHeatmapSmoothSigma), ...
    'Position', smooth_slider_coords, 'Callback', @SmoothSliderClb);

xMinLabel = uicontrol('Parent', figureHandleOut, 'Style', 'text', 'String', 'X min', ...
    'Position', xmin_text_coords, 'HorizontalAlignment', 'left');
xMinEdit = uicontrol('Parent', figureHandleOut, 'Style', 'edit', ...
    'String', num2str(currentXlims(1), '%.6g'), 'BackgroundColor', 'white', ...
    'Position', xmin_edit_coords, 'Callback', @XlimEditClb);
xMaxLabel = uicontrol('Parent', figureHandleOut, 'Style', 'text', 'String', 'X max', ...
    'Position', xmax_text_coords, 'HorizontalAlignment', 'left');
xMaxEdit = uicontrol('Parent', figureHandleOut, 'Style', 'edit', ...
    'String', num2str(currentXlims(2), '%.6g'), 'BackgroundColor', 'white', ...
    'Position', xmax_edit_coords, 'Callback', @XlimEditClb);
muaTraceWhiteCheckbox = uicontrol('Parent', figureHandleOut, 'Style', 'checkbox', ...
    'String', 'white traces', 'Value', double(useWhiteTracesInMua), ...
    'Position', mua_trace_checkbox_coords, 'Callback', @MuaTraceWhiteCheckboxClb);
colormapLabel = uicontrol('Parent', figureHandleOut, 'Style', 'text', 'String', 'Colormap', ...
    'Position', colormap_text_coords, 'HorizontalAlignment', 'left');
colormapPopup = uicontrol('Parent', figureHandleOut, 'Style', 'popupmenu', ...
    'String', colormapNames, 'BackgroundColor', 'white', ...
    'Position', colormap_popup_coords, 'Callback', @ColormapPopupClb);
lfpSpacingLabel = uicontrol('Parent', figureHandleOut, 'Style', 'text', 'String', 'LFP gap', ...
    'Position', lfp_spacing_text_coords, 'HorizontalAlignment', 'left');
lfpSpacingEdit = uicontrol('Parent', figureHandleOut, 'Style', 'edit', ...
    'String', num2str(currentShiftSpacing, '%.6g'), 'BackgroundColor', 'white', ...
    'Position', lfp_spacing_edit_coords, 'Callback', @LfpSpacingEditClb);
lfpSpacingSlider = uicontrol('Parent', figureHandleOut, 'Style', 'slider', ...
    'Min', 0, 'Max', shiftSliderMax, 'Value', shiftSliderFromValue(currentShiftSpacing), ...
    'Position', lfp_spacing_slider_coords, 'Callback', @LfpSpacingSliderClb);
secondaryAxesCheckbox = uicontrol('Parent', figureHandleOut, 'Style', 'checkbox', ...
    'String', 'Profile', 'Value', double(showSecondaryAxes), ...
    'Position', secondary_axes_checkbox_coords, 'Callback', @SecondaryAxesCheckboxClb);
set(muaTraceWhiteCheckbox, 'Visible', ternaryVisibility(isfield(calculationResultOut, 'show_spikes') && calculationResultOut.show_spikes && ...
    (~isfield(calculationResultOut, 'show_CSD') || ~calculationResultOut.show_CSD)));

syncPreCsdControls();
applyCurrentColormap();
applyXlimToAxes();
refreshCsdWithPreprocessing();
end

function deletePreCsdControls()
cancelDebouncedRefresh();
handles = {hpLabel, hpEdit, hpSlider, baselineLabel, baselineEdit, baselineSlider, smoothLabel, smoothEdit, smoothSlider, xMinLabel, xMinEdit, xMaxLabel, xMaxEdit, muaTraceWhiteCheckbox, colormapLabel, colormapPopup, lfpSpacingLabel, lfpSpacingEdit, lfpSpacingSlider, secondaryAxesCheckbox};
for idx = 1:numel(handles)
    h = handles{idx};
    if ~isempty(h) && isgraphics(h, 'uicontrol')
        delete(h);
    end
end
hpLabel = [];
hpEdit = [];
hpSlider = [];
hpActiveCheckbox = [];
baselineLabel = [];
baselineEdit = [];
baselineSlider = [];
smoothLabel = [];
smoothEdit = [];
smoothSlider = [];
colormapLabel = [];
colormapPopup = [];
xMinLabel = [];
xMinEdit = [];
xMaxLabel = [];
xMaxEdit = [];
muaTraceWhiteCheckbox = [];
lfpSpacingLabel = [];
lfpSpacingEdit = [];
lfpSpacingSlider = [];
secondaryAxesCheckbox = [];
end

function HpSliderClb(~, ~)
currentHpCutoff = hpValueFromSlider(get(hpSlider, 'Value'));
syncPreCsdControls();
saveMeanControlsState();
requestDebouncedRefresh();
end

function HpActiveCheckboxClb(src, ~)
hpFilterEnabled = logical(get(src, 'Value'));
syncPreCsdControls();
saveMeanControlsState();
requestDebouncedRefresh();
end

function HpEditClb(~, ~)
inputValue = str2double(strrep(get(hpEdit, 'String'), ',', '.'));
if isnan(inputValue) || ~isfinite(inputValue)
    inputValue = currentHpCutoff;
end
currentHpCutoff = clampHp(inputValue);
syncPreCsdControls();
saveMeanControlsState();
requestDebouncedRefresh();
end

function BaselineSliderClb(~, ~)
currentBaselineBoundary = baselineValueFromSlider(get(baselineSlider, 'Value'));
syncPreCsdControls();
saveMeanControlsState();
requestDebouncedRefresh();
end

function BaselineEditClb(~, ~)
inputValue = str2double(strrep(get(baselineEdit, 'String'), ',', '.'));
if isnan(inputValue) || ~isfinite(inputValue)
    inputValue = currentBaselineBoundary;
end
currentBaselineBoundary = inputValue;
syncPreCsdControls();
saveMeanControlsState();
requestDebouncedRefresh();
end

function XlimEditClb(~, ~)
xMinValue = str2double(strrep(get(xMinEdit, 'String'), ',', '.'));
xMaxValue = str2double(strrep(get(xMaxEdit, 'String'), ',', '.'));
if isnan(xMinValue) || ~isfinite(xMinValue)
    xMinValue = currentXlims(1);
end
if isnan(xMaxValue) || ~isfinite(xMaxValue)
    xMaxValue = currentXlims(2);
end
if xMinValue >= xMaxValue
    xMaxValue = xMinValue + max(1e-6, abs(xMinValue) * 1e-6);
end
currentXlims = [xMinValue, xMaxValue];
syncPreCsdControls();
applyXlimToAxes();
saveMeanControlsState();
requestDebouncedRefresh();
end

function MuaTraceWhiteCheckboxClb(src, ~)
useWhiteTracesInMua = logical(get(src, 'Value'));
saveMeanControlsState();
requestDebouncedRefresh();
end

function SmoothSliderClb(~, ~)
currentHeatmapSmoothSigma = smoothValueFromSlider(get(smoothSlider, 'Value'));
syncPreCsdControls();
saveMeanControlsState();
requestDebouncedRefresh();
end

function SmoothEditClb(~, ~)
inputValue = str2double(strrep(get(smoothEdit, 'String'), ',', '.'));
if isnan(inputValue) || ~isfinite(inputValue)
    inputValue = currentHeatmapSmoothSigma;
end
currentHeatmapSmoothSigma = clampSmoothSigma(inputValue);
syncPreCsdControls();
saveMeanControlsState();
requestDebouncedRefresh();
end

function LfpSpacingSliderClb(~, ~)
currentShiftSpacing = shiftValueFromSlider(get(lfpSpacingSlider, 'Value'));
syncPreCsdControls();
saveMeanControlsState();
refreshShiftLayout();
end

function LfpSpacingEditClb(~, ~)
inputValue = str2double(strrep(get(lfpSpacingEdit, 'String'), ',', '.'));
if isnan(inputValue) || ~isfinite(inputValue)
    inputValue = currentShiftSpacing;
end
currentShiftSpacing = clampShiftSpacing(inputValue);
syncPreCsdControls();
saveMeanControlsState();
refreshShiftLayout();
end

function SecondaryAxesCheckboxClb(src, ~)
showSecondaryAxes = logical(get(src, 'Value'));
applySecondaryAxesVisibility();
saveMeanControlsState();
end

function requestDebouncedRefresh()
try
    if isempty(refreshDebounceTimer) || ~isvalid(refreshDebounceTimer)
        refreshDebounceTimer = timer('ExecutionMode', 'singleShot', ...
            'StartDelay', refreshDebounceDelay, ...
            'TimerFcn', @DebouncedRefreshTimerFcn);
    else
        stop(refreshDebounceTimer);
    end
    start(refreshDebounceTimer);
catch
    refreshCsdWithPreprocessing();
end
end

function DebouncedRefreshTimerFcn(~, ~)
refreshCsdWithPreprocessing();
end

function refreshShiftLayout()
mainAxes = findobj(figureHandleOut, 'Type', 'axes', 'Tag', 'mean_main_axis');
if isempty(mainAxes) || ~isgraphics(mainAxes(1))
    return
end
mainAxLocal = mainAxes(1);
timeAxis = calculationResultOut.timeAxisScaled;
plMeanData = prepareLfpForCsd(timeAxis);
numChannelsLocal = numel(calculationResultOut.ch_inxs);
offsetsLocal = zeros(1, numChannelsLocal);
for p = 1:numChannelsLocal
    offsetsLocal(p) = -(p-1) * currentShiftSpacing;
end
climValue = get(mainAxLocal, 'CLim');
heatmapData = [];
heatmapX = [];
heatmapY = [];
if isfield(calculationResultOut, 'heatmap_handle') && ~isempty(calculationResultOut.heatmap_handle) && isgraphics(calculationResultOut.heatmap_handle)
    heatmapData = get(calculationResultOut.heatmap_handle, 'CData');
    heatmapX = get(calculationResultOut.heatmap_handle, 'XData');
    heatmapY = get(calculationResultOut.heatmap_handle, 'YData');
end
axes(mainAxLocal);
cla(mainAxLocal);
hold(mainAxLocal, 'on');
set(mainAxLocal, 'Color', 'none');
if ~isempty(heatmapData)
    yMin = min(offsetsLocal);
    yMax = max(offsetsLocal);
    heatmapYScaled = heatmapY;
    if numel(heatmapYScaled) >= 2
        srcMin = min(heatmapYScaled(:));
        srcMax = max(heatmapYScaled(:));
        if srcMax > srcMin
            heatmapYScaled = yMin + (heatmapYScaled - srcMin) * (yMax - yMin) / (srcMax - srcMin);
        else
            heatmapYScaled = heatmapYScaled * 0 + yMin;
        end
    end
    calculationResultOut.heatmap_handle = imagesc(mainAxLocal, heatmapX, heatmapYScaled, heatmapData);
    uistack(calculationResultOut.heatmap_handle, 'bottom');
    set(mainAxLocal, 'CLim', climValue);
else
    calculationResultOut.heatmap_handle = [];
end
calculationResultOut.shiftCoeff = currentShiftSpacing;
drawMeanTrace(mainAxLocal, timeAxis, plMeanData, offsetsLocal);
if visualSettings.show_full_signal
    dataWithOffsets = plMeanData + offsetsLocal;
    yMin = min(dataWithOffsets(:));
    yMax = max(dataWithOffsets(:));
    margin = (yMax - yMin) * 0.05;
    Ylims = [yMin - margin, yMax + margin];
elseif isfield(calculationResultOut, 'baseline_medians')
    baselineMedians = calculationResultOut.baseline_medians;
    minOffset = min(offsetsLocal);
    maxOffset = max(offsetsLocal);
    minBaseline = min(baselineMedians);
    maxBaseline = max(baselineMedians);
    Ylims = [minOffset + minBaseline - currentShiftSpacing*0.2, maxOffset + maxBaseline + currentShiftSpacing*0.2];
else
    Ylims = [min(offsetsLocal)-currentShiftSpacing*0.5, max(offsetsLocal)+currentShiftSpacing*0.5];
end
ylim(mainAxLocal, Ylims);
secondaryAxes = findobj(figureHandleOut, 'Type', 'axes', '-not', 'Tag', 'legend');
for iAx = 1:numel(secondaryAxes)
    if secondaryAxes(iAx) ~= mainAxLocal
        ylim(secondaryAxes(iAx), Ylims);
    end
end
applyCurrentColormap();
hold(mainAxLocal, 'off');
applyXlimToAxes();
applySecondaryAxesVisibility();
end

function applySecondaryAxesVisibility()
mainAxes = findobj(figureHandleOut, 'Type', 'axes', 'Tag', 'mean_main_axis');
if isempty(mainAxes) || ~isgraphics(mainAxes(1))
    return
end
mainAxLocal = mainAxes(1);
secondaryAxes = findobj(figureHandleOut, 'Type', 'axes', 'Tag', 'mean_secondary_axis');
if isempty(secondaryAxes)
    updateAxesLayout(mainAxLocal, []);
    return
end
secondaryAxLocal = secondaryAxes(1);
visibleState = ternaryVisibility(showSecondaryAxes);
set(secondaryAxLocal, 'Visible', visibleState);
updateAxesLayout(mainAxLocal, secondaryAxLocal);
end

function updateAxesLayout(mainAxLocal, secondaryAxLocal)
if nargin < 1 || isempty(mainAxLocal) || ~isgraphics(mainAxLocal, 'axes')
    return
end
axesContainer = getappdata(figureHandleOut, 'meanAxesContainer');
if isempty(axesContainer) || ~isgraphics(axesContainer, 'uipanel')
    return
end
set(mainAxLocal, 'Parent', axesContainer, 'Units', 'normalized');
if nargin >= 2 && ~isempty(secondaryAxLocal) && isgraphics(secondaryAxLocal, 'axes')
    set(secondaryAxLocal, 'Parent', axesContainer, 'Units', 'normalized');
end
outerPad = 0.02;
topBottomPad = 0.06;
gap = 0.02;
fullHeight = 1 - 2 * topBottomPad;
if nargin < 2 || isempty(secondaryAxLocal) || ~isgraphics(secondaryAxLocal, 'axes') || ~showSecondaryAxes
    set(mainAxLocal, 'Position', [outerPad, topBottomPad, 1 - 2*outerPad, fullHeight]);
    return
end
availableWidth = 1 - 2*outerPad - gap;
mainWidth = availableWidth * 4 / 5;
secondaryWidth = availableWidth - mainWidth;
set(mainAxLocal, 'Position', [outerPad, topBottomPad, mainWidth, fullHeight]);
set(secondaryAxLocal, 'Position', [outerPad + mainWidth + gap, topBottomPad, secondaryWidth, fullHeight]);
end

function cancelDebouncedRefresh()
if ~isempty(refreshDebounceTimer) && isvalid(refreshDebounceTimer)
    stop(refreshDebounceTimer);
    delete(refreshDebounceTimer);
end
refreshDebounceTimer = [];
end

function syncPreCsdControls()
if ~isempty(hpActiveCheckbox) && isgraphics(hpActiveCheckbox, 'uicontrol')
    set(hpActiveCheckbox, 'Value', double(hpFilterEnabled));
end
enabledState = ternaryEnable(hpFilterEnabled);
labelColor = [0 0 0];
if ~hpFilterEnabled
    labelColor = [0.5 0.5 0.5];
end
if ~isempty(hpLabel) && isgraphics(hpLabel, 'uicontrol')
    set(hpLabel, 'ForegroundColor', labelColor);
end
if ~isempty(baselineLabel) && isgraphics(baselineLabel, 'uicontrol')
    set(baselineLabel, 'ForegroundColor', labelColor);
end
if ~isempty(hpEdit) && isgraphics(hpEdit, 'uicontrol')
    set(hpEdit, 'Enable', enabledState);
    set(hpEdit, 'String', sprintf('%.2f', currentHpCutoff));
end
if ~isempty(hpSlider) && isgraphics(hpSlider, 'uicontrol')
    set(hpSlider, 'Enable', enabledState);
    set(hpSlider, 'Value', hpSliderFromValue(currentHpCutoff));
end
if ~isempty(baselineEdit) && isgraphics(baselineEdit, 'uicontrol')
    set(baselineEdit, 'Enable', enabledState);
    set(baselineEdit, 'String', num2str(currentBaselineBoundary, '%.3g'));
end
if ~isempty(baselineSlider) && isgraphics(baselineSlider, 'uicontrol')
    set(baselineSlider, 'Enable', enabledState);
    set(baselineSlider, 'Value', baselineSliderFromValue(currentBaselineBoundary));
end
if ~isempty(xMinEdit) && isgraphics(xMinEdit, 'uicontrol')
    set(xMinEdit, 'String', num2str(currentXlims(1), '%.6g'));
end
if ~isempty(xMaxEdit) && isgraphics(xMaxEdit, 'uicontrol')
    set(xMaxEdit, 'String', num2str(currentXlims(2), '%.6g'));
end
if ~isempty(smoothEdit) && isgraphics(smoothEdit, 'uicontrol')
    set(smoothEdit, 'String', num2str(currentHeatmapSmoothSigma, '%.3g'));
end
if ~isempty(smoothSlider) && isgraphics(smoothSlider, 'uicontrol')
    set(smoothSlider, 'Value', smoothSliderFromValue(currentHeatmapSmoothSigma));
end
if ~isempty(colormapPopup) && isgraphics(colormapPopup, 'uicontrol')
    activeColormapIndex = find(strcmp(colormapNames, currentColormapName), 1);
    if isempty(activeColormapIndex)
        activeColormapIndex = 1;
        currentColormapName = colormapNames{activeColormapIndex};
    end
    set(colormapPopup, 'Value', activeColormapIndex);
end
if ~isempty(lfpSpacingEdit) && isgraphics(lfpSpacingEdit, 'uicontrol')
    set(lfpSpacingEdit, 'String', num2str(currentShiftSpacing, '%.6g'));
end
if ~isempty(lfpSpacingSlider) && isgraphics(lfpSpacingSlider, 'uicontrol')
    set(lfpSpacingSlider, 'Value', shiftSliderFromValue(currentShiftSpacing));
end
if ~isempty(secondaryAxesCheckbox) && isgraphics(secondaryAxesCheckbox, 'uicontrol')
    set(secondaryAxesCheckbox, 'Value', double(showSecondaryAxes));
end
hasHeatmap = (isfield(calculationResultOut, 'show_CSD') && calculationResultOut.show_CSD) || ...
    (isfield(calculationResultOut, 'show_spikes') && calculationResultOut.show_spikes);
if ~isempty(colormapLabel) && isgraphics(colormapLabel, 'uicontrol')
    set(colormapLabel, 'Visible', ternaryVisibility(hasHeatmap));
end
if ~isempty(colormapPopup) && isgraphics(colormapPopup, 'uicontrol')
    set(colormapPopup, 'Visible', ternaryVisibility(hasHeatmap));
end
end

function value = clampHp(valueIn)
value = min(max(valueIn, minHpCutoff), maxHpCutoff);
end

function value = clampBaselineBoundary(valueIn)
baselineUpper = currentXlims(2);
baselineLower = currentXlims(1);
value = min(max(valueIn, baselineLower), baselineUpper);
end

function value = clampSmoothSigma(valueIn)
value = min(max(valueIn, smoothSigmaMin), smoothSigmaMax);
end

function value = clampShiftSpacing(valueIn)
value = min(max(valueIn, minShiftSpacing), maxShiftSpacing);
end

function sliderValue = hpSliderFromValue(hpValue)
sliderValue = hpSliderMax * (hpValue - minHpCutoff) / (maxHpCutoff - minHpCutoff);
end

function hpValue = hpValueFromSlider(sliderValue)
hpValue = minHpCutoff + (maxHpCutoff - minHpCutoff) * sliderValue / hpSliderMax;
end

function sliderValue = baselineSliderFromValue(boundaryValue)
span = currentXlims(2) - currentXlims(1);
if span <= 0
    sliderValue = 0;
    return
end
sliderValue = baselineSliderMax * (boundaryValue - currentXlims(1)) / span;
sliderValue = min(max(sliderValue, 0), baselineSliderMax);
end

function boundaryValue = baselineValueFromSlider(sliderValue)
span = currentXlims(2) - currentXlims(1);
if span <= 0
    boundaryValue = currentXlims(1);
    return
end
boundaryValue = currentXlims(1) + span * sliderValue / baselineSliderMax;
boundaryValue = clampBaselineBoundary(boundaryValue);
end

function sliderValue = smoothSliderFromValue(sigmaValue)
sliderValue = smoothSliderMax * (sigmaValue - smoothSigmaMin) / (smoothSigmaMax - smoothSigmaMin);
end

function sigmaValue = smoothValueFromSlider(sliderValue)
sigmaValue = smoothSigmaMin + (smoothSigmaMax - smoothSigmaMin) * sliderValue / smoothSliderMax;
end

function sliderValue = shiftSliderFromValue(shiftValue)
sliderValue = shiftSliderMax * (shiftValue - minShiftSpacing) / (maxShiftSpacing - minShiftSpacing);
end

function shiftValue = shiftValueFromSlider(sliderValue)
shiftValue = minShiftSpacing + (maxShiftSpacing - minShiftSpacing) * sliderValue / shiftSliderMax;
end

function applyXlimToAxes()
mainAxes = findobj(figureHandleOut, 'Type', 'axes', 'Tag', 'mean_main_axis');
if isempty(mainAxes) || ~isgraphics(mainAxes(1))
    return
end
xlim(mainAxes(1), currentXlims);
calculationResultOut.xLimits = currentXlims;
end

function refreshCsdWithPreprocessing()
currentHpCutoff = clampHp(currentHpCutoff);
mainAxes = findobj(figureHandleOut, 'Type', 'axes', 'Tag', 'mean_main_axis');
if isempty(mainAxes) || ~isgraphics(mainAxes(1))
    return
end
mainAxLocal = mainAxes(1);
timeAxis = calculationResultOut.timeAxisScaled;
plMeanData = prepareLfpForCsd(timeAxis);

numChannelsLocal = numel(calculationResultOut.ch_inxs);
offsetsLocal = zeros(1, numChannelsLocal);
for p = 1:numChannelsLocal
    offsetsLocal(p) = -(p-1) * calculationResultOut.shiftCoeff;
end

axes(mainAxLocal);
currentYlim = ylim(mainAxLocal);
cla(mainAxLocal);
hold(mainAxLocal, 'on');
set(mainAxLocal, 'Color', 'none');

if isfield(calculationResultOut, 'show_CSD') && calculationResultOut.show_CSD
    csdParams.time_in_csd = timeAxis;
    csdParams.data_in_csd = plMeanData;
    csdParams.Fs = calculationResultOut.Fs;
    csdParams.offsets = offsetsLocal;
    csdParams.csd_smooth_coef = calculationResultOut.csd_smooth_coef;
    csdParams.csd_active = calculationResultOut.csd_active;
    csdParams.ch_inxs_original = calculationResultOut.ch_inxs;
    csdParams.csd_split_by_channel_gaps = true;
    [csdImage, csdTime, csdCh] = csdCalc(csdParams);
    [csdImage, csdTime, csdCh] = applyHeatmapResampling(csdImage, csdTime, csdCh, currentHeatmapSmoothSigma);
    csdPlotting(csdImage, csdTime, csdCh, calculationResultOut.csd_contrast_coef);
    imageHandles = findobj(mainAxLocal, 'Type', 'image', '-depth', 1);
    if ~isempty(imageHandles)
        calculationResultOut.heatmap_handle = imageHandles(1);
        uistack(calculationResultOut.heatmap_handle, 'bottom');
    end
    calculationResultOut.heatmap_base_clim = get(mainAxLocal, 'CLim');
    currentContrast = str2double(get(contrastEdit, 'String'));
    if isnan(currentContrast) || ~isfinite(currentContrast)
        currentContrast = defaultContrastPercent();
    end
    applyContrast(currentContrast);
elseif isfield(calculationResultOut, 'show_spikes') && calculationResultOut.show_spikes && ...
        isfield(calculationResultOut, 'ev_hists') && ~isempty(calculationResultOut.ev_hists)
    evHists = calculationResultOut.ev_hists;
    evHists = evHists - median(evHists, 2);
    muaX = linspace(timeAxis(1), timeAxis(end), size(evHists, 2));
    [evHists, muaX, muaY] = applyHeatmapResampling(evHists, muaX, offsetsLocal, currentHeatmapSmoothSigma);
    muaImage = imagesc(mainAxLocal, muaX, muaY, evHists);
    calculationResultOut.heatmap_handle = muaImage;
    uistack(calculationResultOut.heatmap_handle, 'bottom');
    calculationResultOut.heatmap_base_clim = get(mainAxLocal, 'CLim');
    currentContrast = str2double(get(contrastEdit, 'String'));
    if isnan(currentContrast) || ~isfinite(currentContrast)
        currentContrast = defaultContrastPercent();
    end
    applyContrast(currentContrast);
else
    calculationResultOut.heatmap_handle = [];
end
applyCurrentColormap();

drawMeanTrace(mainAxLocal, timeAxis, plMeanData, offsetsLocal);
ylim(mainAxLocal, currentYlim);
hold(mainAxLocal, 'off');
calculationResultOut.csd_hp_cutoff_hz = currentHpCutoff;
calculationResultOut.csd_baseline_boundary = currentBaselineBoundary;
applyXlimToAxes();
applySecondaryAxesVisibility();
end

function plMeanData = prepareLfpForCsd(timeAxis)
plMeanData = calculationResultOut.meanData(:, calculationResultOut.ch_inxs) .* ...
    calculationResultOut.scalingCoefficients(calculationResultOut.ch_inxs);
plMeanData = double(plMeanData);
if hpFilterEnabled && currentHpCutoff > 0
    nyquistFreq = calculationResultOut.Fs / 2;
    hpCutoff = min(currentHpCutoff, nyquistFreq * 0.99);
    processingMask = timeAxis >= currentXlims(1) & timeAxis <= currentBaselineBoundary;
    processIdx = find(processingMask);
    if numel(processIdx) >= 9
        dataBeforeFilter = plMeanData;
        [bHp, aHp] = butter(2, hpCutoff / nyquistFreq, 'high');
        plMeanData(processIdx, :) = filtfilt(bHp, aHp, plMeanData(processIdx, :));
        joinIdx = processIdx(end);
        if joinIdx < size(plMeanData, 1)
            rightIdx = (joinIdx + 1):size(plMeanData, 1);
            joinShift = plMeanData(joinIdx, :) - dataBeforeFilter(joinIdx, :);
            plMeanData(rightIdx, :) = plMeanData(rightIdx, :) + joinShift;
        end
    end
end
if hpFilterEnabled
    baselineBoundaryInRange = currentBaselineBoundary >= currentXlims(1) && currentBaselineBoundary <= currentXlims(2);
    if baselineBoundaryInRange
        baselineMask = timeAxis >= currentXlims(1) & timeAxis <= currentBaselineBoundary;
        if any(baselineMask)
            baselineMedian = median(plMeanData(baselineMask, :), 1);
            plMeanData = plMeanData - baselineMedian;
        end
    end
end
end

function drawMeanTrace(mainAxLocal, timeAxis, plMeanData, offsetsLocal)
channelLabels = calculationResultOut.ch_labels(calculationResultOut.ch_inxs);
channelWidths = calculationResultOut.widths_in(calculationResultOut.ch_inxs);
channelColors = calculationResultOut.colors_in(calculationResultOut.ch_inxs);
isMuaMode = isfield(calculationResultOut, 'show_spikes') && calculationResultOut.show_spikes && ...
    (~isfield(calculationResultOut, 'show_CSD') || ~calculationResultOut.show_CSD);
if isMuaMode && useWhiteTracesInMua
    channelColors = repmat({[1 1 1]}, 1, numel(channelColors));
end
multiplot(timeAxis, plMeanData, ...
    'ChannelLabels', channelLabels, ...
    'shiftCoeff', calculationResultOut.shiftCoeff, ...
    'linewidth', channelWidths, ...
    'color', channelColors);
[~, gapIdx] = splitConsecutiveChannels(calculationResultOut.ch_inxs);
if ~isempty(gapIdx)
    x1 = timeAxis(1);
    x2 = timeAxis(end);
    for k = 1:numel(gapIdx)
        i = gapIdx(k);
        y = (offsetsLocal(i) + offsetsLocal(i+1)) / 2;
        plot(mainAxLocal, [x1, x2], [y, y], '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1);
    end
end
xline(mainAxLocal, currentBaselineBoundary, '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 1);
xline(mainAxLocal, 0, 'r:');
end

function visibleValue = ternaryVisibility(isVisible)
visibleValue = 'off';
if isVisible
    visibleValue = 'on';
end
end

function enableValue = ternaryEnable(isEnabled)
enableValue = 'off';
if isEnabled
    enableValue = 'on';
end
end

function ContrastSliderClb(~, ~)
coef = coefFromSlider(get(contrastSlider, 'Value'));
set(contrastEdit, 'String', num2str(coef, '%.3g'));
currentContrastPercent = coef;
saveMeanControlsState();
applyContrast(coef);
end

function ContrastEditClb(~, ~)
coef = str2double(get(contrastEdit, 'String'));
if isnan(coef) || ~isfinite(coef)
    coef = defaultContrastPercent();
end
coef = min(max(coef, contrastCoefMin), contrastCoefMax);
set(contrastEdit, 'String', num2str(coef, '%.3g'));
set(contrastSlider, 'Value', sliderFromCoef(coef));
currentContrastPercent = coef;
saveMeanControlsState();
applyContrast(coef);
end

function sliderValue = sliderFromCoef(coef)
sliderValue = contrastSliderMax * (coef - contrastCoefMin) / (contrastCoefMax - contrastCoefMin);
end

function coef = coefFromSlider(sliderValue)
coef = contrastCoefMin + (contrastCoefMax - contrastCoefMin) * sliderValue / contrastSliderMax;
end

function applyContrast(coef)
heatmapHandle = [];
if isfield(calculationResultOut, 'heatmap_handle')
    heatmapHandle = calculationResultOut.heatmap_handle;
end
if isempty(heatmapHandle) || ~isgraphics(heatmapHandle)
    return
end
contrastScale = max(coef / 100, eps);
halfSpan = contrastHalfSpan / contrastScale;
newClim = contrastCenter + [-halfSpan, halfSpan];
set(get(heatmapHandle, 'Parent'), 'CLim', newClim);
end

function ColormapPopupClb(src, ~)
selectedIndex = get(src, 'Value');
if selectedIndex < 1 || selectedIndex > numel(colormapNames)
    return
end
currentColormapName = colormapNames{selectedIndex};
applyCurrentColormap();
saveMeanControlsState();
end

function applyCurrentColormap()
mainAxes = findobj(figureHandleOut, 'Type', 'axes', 'Tag', 'mean_main_axis');
if isempty(mainAxes) || ~isgraphics(mainAxes(1))
    return
end
colormap(mainAxes(1), currentColormapName);
end

function coef = defaultContrastPercent()
coef = 100 - 40 * double(isfield(calculationResultOut, 'show_CSD') && calculationResultOut.show_CSD);
end

function sigma = defaultHeatmapSmoothSigma()
sigma = 0.1 + 1.9 * double(isfield(calculationResultOut, 'show_CSD') && calculationResultOut.show_CSD);
end

function restoreMeanControlsState()
if ~isstruct(meanControlsState)
    return
end
modeKey = currentMeanModeKey();
stateForMode = struct();
if isfield(meanControlsState, modeKey) && isstruct(meanControlsState.(modeKey))
    stateForMode = meanControlsState.(modeKey);
elseif isfield(meanControlsState, 'contrastPercent') || isfield(meanControlsState, 'hpCutoffHz')
    stateForMode = meanControlsState; % обратная совместимость со старым форматом
end
if isfield(stateForMode, 'contrastPercent')
    currentContrastPercent = stateForMode.contrastPercent;
end
if isfield(stateForMode, 'hpCutoffHz')
    currentHpCutoff = stateForMode.hpCutoffHz;
end
if isfield(stateForMode, 'baselineBoundary')
    currentBaselineBoundary = stateForMode.baselineBoundary;
end
if isfield(stateForMode, 'xLim') && isnumeric(stateForMode.xLim) && numel(stateForMode.xLim) == 2
    currentXlims = stateForMode.xLim(:).';
end
if isfield(stateForMode, 'hpFilterEnabled')
    hpFilterEnabled = logical(stateForMode.hpFilterEnabled);
end
if isfield(stateForMode, 'muaWhiteTraces')
    useWhiteTracesInMua = logical(stateForMode.muaWhiteTraces);
end
if isfield(stateForMode, 'heatmapSmoothSigma')
    currentHeatmapSmoothSigma = stateForMode.heatmapSmoothSigma;
end
if isfield(stateForMode, 'colormapName') && ischar(stateForMode.colormapName)
    currentColormapName = stateForMode.colormapName;
end
if isfield(stateForMode, 'lfpSpacing')
    currentShiftSpacing = double(stateForMode.lfpSpacing);
end
if isfield(stateForMode, 'showSecondaryAxes')
    showSecondaryAxes = logical(stateForMode.showSecondaryAxes);
end
if isfield(opts, 'xLimits') && isnumeric(opts.xLimits) && numel(opts.xLimits) == 2
    currentXlims = reshape(double(opts.xLimits), 1, 2);
end
if isfield(opts, 'csd_hp_cutoff_hz')
    currentHpCutoff = double(opts.csd_hp_cutoff_hz);
end
if isfield(opts, 'csd_baseline_boundary')
    currentBaselineBoundary = double(opts.csd_baseline_boundary);
end
if isfield(opts, 'hpFilterEnabled')
    hpFilterEnabled = logical(opts.hpFilterEnabled);
end
if isfield(opts, 'muaWhiteTraces')
    useWhiteTracesInMua = logical(opts.muaWhiteTraces);
end
if isfield(opts, 'heatmapSmoothSigma')
    currentHeatmapSmoothSigma = double(opts.heatmapSmoothSigma);
end
if isfield(opts, 'contrastPercent')
    currentContrastPercent = double(opts.contrastPercent);
end
if isfield(opts, 'colormapName')
    currentColormapName = char(opts.colormapName);
end
if isfield(opts, 'shiftCoeff')
    currentShiftSpacing = double(opts.shiftCoeff);
end
if isfield(opts, 'showSecondaryAxes')
    showSecondaryAxes = logical(opts.showSecondaryAxes);
end
if isempty(find(strcmp(colormapNames, currentColormapName), 1))
    currentColormapName = colormapNames{1};
end
if currentXlims(1) >= currentXlims(2)
    currentXlims = Xlims;
end
currentContrastPercent = min(max(currentContrastPercent, contrastCoefMin), contrastCoefMax);
currentHpCutoff = clampHp(currentHpCutoff);
currentHeatmapSmoothSigma = clampSmoothSigma(currentHeatmapSmoothSigma);
currentShiftSpacing = clampShiftSpacing(currentShiftSpacing);
calculationResultOut.shiftCoeff = currentShiftSpacing;
saveMeanControlsState();
end

function saveMeanControlsState()
modeKey = currentMeanModeKey();
stateForMode = struct( ...
    'contrastPercent', currentContrastPercent, ...
    'hpCutoffHz', currentHpCutoff, ...
    'baselineBoundary', currentBaselineBoundary, ...
    'xLim', currentXlims, ...
    'hpFilterEnabled', logical(hpFilterEnabled), ...
    'muaWhiteTraces', logical(useWhiteTracesInMua), ...
    'heatmapSmoothSigma', currentHeatmapSmoothSigma, ...
    'colormapName', currentColormapName, ...
    'lfpSpacing', currentShiftSpacing, ...
    'showSecondaryAxes', logical(showSecondaryAxes));
if ~isstruct(meanControlsState)
    meanControlsState = struct();
end
meanControlsState.(modeKey) = stateForMode;
saveChannelSettings('meanControlsState');
end

function modeKey = currentMeanModeKey()
modeKeys = {'mua', 'csd'};
modeKey = modeKeys{1 + double(isfield(calculationResultOut, 'show_CSD') && calculationResultOut.show_CSD)};
end

function [imageOut, xOut, yOut] = applyHeatmapResampling(imageIn, xIn, yIn, sigma)
imageOut = imageIn;
xOut = xIn;
yOut = yIn;
sigma = clampSmoothSigma(sigma);
if sigma <= 0
    return
end
scaleFactor = 1 + sigma;
numRows = size(imageIn, 1);
numCols = size(imageIn, 2);
newRows = max(numRows, round(numRows * scaleFactor));
newCols = max(numCols, round(numCols * scaleFactor));
[xGrid, yGrid] = meshgrid(1:numCols, 1:numRows);
[xQuery, yQuery] = meshgrid(linspace(1, numCols, newCols), linspace(1, numRows, newRows));
imageOut = interp2(xGrid, yGrid, double(imageIn), xQuery, yQuery, 'linear');
xOut = linspace(xIn(1), xIn(end), newCols);
yOut = linspace(yIn(1), yIn(end), newRows);
end

function [climCenterOut, halfSpanOut] = resolveContrastBaseline()
climCenterOut = 0;
halfSpanOut = 0;
baseClim = [];
if isfield(calculationResultOut, 'heatmap_base_clim')
    baseClim = calculationResultOut.heatmap_base_clim;
end
if isempty(baseClim) || numel(baseClim) ~= 2 || any(~isfinite(baseClim))
    return
end
climCenterOut = mean(baseClim);
halfSpanOut = (baseClim(2) - baseClim(1)) / 2;
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