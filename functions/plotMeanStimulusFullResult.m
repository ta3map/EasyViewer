function figPath = plotMeanStimulusFullResult(calcResult, plotParams, events, metadata, params)
global ch_inxs shiftCoeff matFilePath

[folder, baseName, ~] = fileparts(metadata.filePath);
baseName = updateBaseName(baseName, params);
[mat_file_folder, original_filename, ~] = fileparts(matFilePath);
local_evfilename = original_filename;
if isempty(local_evfilename)
    local_evfilename = 'stimuli';
end

meanFig = figure('Name', 'Mean Stimulus Data', 'Tag', 'meanSignalResult');
meanFig.Position = [32, 64, 1024, 768];
t = tiledlayout(meanFig, 4, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
plotParams.figure = meanFig;
plotParams.tiledlayout = t;

[~, calculation_result] = plotMeanEvents(plotParams);
calculation_result.xLimits = calcResult.xLimits;

channelSettings = buildChannelSettingsTable();
Xlims = calculation_result.xLimits;
numChannels = numel(ch_inxs);
offsets = zeros(1, numChannels);
for p = 1:numChannels
    offsets(p) = -(p-1) * shiftCoeff;
end
y_pixel_size = 768;
y_tick_min_pixel_size = 32;
[chRanges, chRangesOffsets, chRangeIndexes] = calculateChRanges(offsets, shiftCoeff, calculation_result.meanData, ...
    numChannels, calculation_result.scalingCoefficients(ch_inxs), y_pixel_size, y_tick_min_pixel_size);

if isfield(calculation_result, 'baseline_medians')
    baseline_medians = calculation_result.baseline_medians;
    for ch_inx = 1:numChannels
        ch_mask = chRangeIndexes == ch_inx;
        chRanges(ch_mask) = chRanges(ch_mask) + baseline_medians(ch_inx) / calculation_result.scalingCoefficients(ch_inxs(ch_inx));
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

ax = findobj(meanFig, 'Type', 'axes', '-not', 'Tag', 'legend');
if ~isempty(ax)
    ax = ax(1);
    if isfield(calculation_result, 'baseline_medians')
        baseline_medians = calculation_result.baseline_medians;
        minOffset = min(offsets);
        maxOffset = max(offsets);
        minBaseline = min(baseline_medians);
        maxBaseline = max(baseline_medians);
        Ylims = [min([chRangesOffsets(:); minOffset + minBaseline]) - shiftCoeff*0.2, ...
                 max([chRangesOffsets(:); maxOffset + maxBaseline]) + shiftCoeff*0.2];
    else
        Ylims = [min(chRangesOffsets)-shiftCoeff*0.5, max(chRangesOffsets)+shiftCoeff*0.5];
    end
    ylim(ax, Ylims);
end

xline(0, 'r:');

save_btn_coords = [5, 5, 40, 25];
savebutton = uicontrol('Parent', meanFig, 'Style', 'pushbutton', 'String', 'Save Data', 'Visible', 'off', 'Position', save_btn_coords, 'Callback', @SaveBtnClb);
btnIcon(savebutton, fullfile(getAssetsPath(), 'data-storage.png'), false)

save_btn_coords = [5, 32.5, 40, 25];
saveImgbutton = uicontrol('Parent', meanFig, 'Style', 'pushbutton', 'String', 'Save Image', 'Visible', 'off', 'Position', save_btn_coords, 'Callback', @SaveImageClb);
btnIcon(saveImgbutton, fullfile(getAssetsPath(), 'save_image.png'), false)
btn_list = [savebutton, saveImgbutton];

set(meanFig, 'WindowButtonMotionFcn', @(src, event)autoHideBtn(src, event, btn_list));

    function SaveBtnClb(~,~)
        set(savebutton, 'Visible', 'off')
        [file,path] = uiputfile([mat_file_folder '/' local_evfilename '_data.mean'], 'Save file name');
        if isequal(file,0) || isequal(path,0)
        else
           filename = fullfile(path, file);
           save(filename, '-struct', 'calculation_result');
           save(filename, 'original_filename', '-append');
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
        else
           filename = fullfile(path, file);
           switch filterindex
               case 1
                   print(meanFig, filename, '-dpdf', '-bestfit');
               case 2
                   print(meanFig, filename, '-depsc');
               case 3
                   saveas(meanFig, filename, 'png');
               otherwise
                   saveas(meanFig, filename);
           end
        end
    end

meanFig = plotEvents(meanFig, events, calcResult);
addResultsTable(meanFig, events, calcResult);
plotEventsScatter(meanFig, events, calcResult);

figureFormat = params.figureFormat;
if strcmpi(figureFormat, 'png')
    figPath = fullfile(folder, [baseName, '_auto_mean.png']);
    saveas(meanFig, figPath, 'png');
else
    figPath = fullfile(folder, [baseName, '_auto_mean.fig']);
    savefig(meanFig, figPath);
end
end
