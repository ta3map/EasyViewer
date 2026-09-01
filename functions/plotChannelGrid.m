function plotChannelGrid(params, actions)
%PLOTCHANNELGRID Draw channel grid on one axes; reuse lines when size unchanged.

global channelGridGfx multiax lines_and_styles visualSettings axes_background_color
global event_label_click_callback stim_label_click_callback

if nargin < 2 || isempty(actions)
    actions = viewerPlotActions('visual');
end

if isempty(channelGridGfx) || ~isstruct(channelGridGfx)
    channelGridGfx = emptyChannelGridGfx();
end

indexGrid = params.indexGrid;
[nRows, nCols] = size(indexGrid);
bgColor = hex2rgb(axes_background_color);

Xlims = params.Xlims;
Ylims = params.Ylims;
xSpan = diff(Xlims);
ySpan = diff(Ylims);
gridXlims = [Xlims(1), Xlims(1) + nCols * xSpan];
gridYlims = [0, nRows * ySpan];

needRebuild = actions.invalidate ...
    || isempty(channelGridGfx.axes) || ~isgraphics(channelGridGfx.axes) || channelGridGfx.axes ~= multiax ...
    || ~isequal(channelGridGfx.size, [nRows nCols]) ...
    || ~isfield(channelGridGfx, 'traceLines') ...
    || isempty(channelGridGfx.traceLines) ...
    || ~isequal(size(channelGridGfx.traceLines), [nRows nCols]);

if needRebuild
    clearChannelGrid();
    clearMainAxesPlotContent(multiax, gobjects(0));
    channelGridGfx = emptyChannelGridGfx();
    channelGridGfx.size = [nRows nCols];
    channelGridGfx.traceLines = gobjects(nRows, nCols);
    channelGridGfx.nameLabels = gobjects(nRows, nCols);
    channelGridGfx.eventLines = cell(nRows, nCols);
    channelGridGfx.stimLines = cell(nRows, nCols);
    channelGridGfx.muaImages = gobjects(nRows, nCols);
    channelGridGfx.muaScatters = gobjects(nRows, nCols);

    ax = multiax;
    channelGridGfx.axes = ax;
    set(ax, 'Visible', 'on', 'Box', 'off', 'Color', bgColor);
    hold(ax, 'on');

    for r = 1:nRows
        for c = 1:nCols
            channelGridGfx.traceLines(r, c) = plot(ax, nan, nan, 'Visible', 'off');
            channelGridGfx.nameLabels(r, c) = text(ax, 0, 0, '', ...
                'Color', [0.2 0.2 0.2], 'FontSize', 9, 'FontWeight', 'bold', ...
                'Interpreter', 'none', 'HorizontalAlignment', 'left', ...
                'VerticalAlignment', 'top', 'Clipping', 'on', 'Visible', 'off');
            channelGridGfx.eventLines{r, c} = gobjects(0);
            channelGridGfx.stimLines{r, c} = gobjects(0);
        end
    end
else
    set(multiax, 'Visible', 'on');
    if ~isfield(channelGridGfx, 'muaImages') || ~isequal(size(channelGridGfx.muaImages), [nRows nCols])
        channelGridGfx.muaImages = gobjects(nRows, nCols);
        channelGridGfx.muaScatters = gobjects(nRows, nCols);
    end
end

ax = channelGridGfx.axes;
maxPointsPerCell = plotDecimationLimit(ax, nCols);
set(ax, ...
    'Color', bgColor, ...
    'XLim', gridXlims, ...
    'YLim', gridYlims, ...
    'XTick', [], 'YTick', [], ...
    'XColor', 'none', 'YColor', 'none', ...
    'Box', 'off');

channelGridGfx.indexGrid = indexGrid;
channelGridGfx.Xlims = Xlims;
channelGridGfx.nCols = nCols;
channelGridGfx.nRows = nRows;
timeVec = params.time;
data = params.data;
ch_inxs = params.ch_inxs;
colors = params.colors;
widths = params.widths;
labels = params.labels;

firstOccupied = [];
for r = 1:nRows
    for c = 1:nCols
        [cellXlims, cellYlims] = gridCellLimits(r, c, nRows, nCols, Xlims, Ylims);

        chIdx = indexGrid(r, c);
        hLine = channelGridGfx.traceLines(r, c);
        hName = channelGridGfx.nameLabels(r, c);

        col = [];
        if chIdx >= 1
            col = find(ch_inxs == chIdx, 1, 'first');
        end

        if isempty(col)
            set(hLine, 'Visible', 'off');
            set(hName, 'Visible', 'off');
            channelGridGfx.eventLines{r, c} = updateXMarkersPool(ax, channelGridGfx.eventLines{r, c}, [], cellYlims, lines_and_styles, 'events_lines');
            channelGridGfx.stimLines{r, c} = updateXMarkersPool(ax, channelGridGfx.stimLines{r, c}, [], cellYlims, lines_and_styles, 'stimulus_lines');
            continue;
        end

        if isempty(firstOccupied)
            firstOccupied = [r c];
        end

        nameX = cellXlims(1) + xSpan * 0.02;
        nameY = cellYlims(2) - ySpan * 0.08;

        if actions.traces || needRebuild
            [tPlot, yPlot] = decimateForDisplay(timeVec, data(:, col), maxPointsPerCell);
            xPlot = mapTimeToGrid(tPlot, c, Xlims);
            yPlot = mapAmpToGrid(yPlot, r, Ylims, nRows);
            set(hLine, ...
                'XData', xPlot, ...
                'YData', yPlot, ...
                'Color', colors{col}, ...
                'LineWidth', widths(col), ...
                'Visible', 'on');
            set(hName, ...
                'Position', [nameX, nameY, 0], ...
                'String', labels{col}, ...
                'Visible', 'on');
        else
            set(hLine, 'Visible', 'on');
            set(hName, 'Position', [nameX, nameY, 0], 'Visible', 'on');
        end

        if actions.overlays || needRebuild
            evX = [];
            stX = [];
            if params.show_events && ~isempty(params.events_x)
                evX = mapTimeToGrid(params.events_x, c, Xlims);
            end
            if params.show_stim && ~isempty(params.stims_x)
                stX = mapTimeToGrid(params.stims_x, c, Xlims);
            end
            channelGridGfx.eventLines{r, c} = updateXMarkersPool(ax, channelGridGfx.eventLines{r, c}, evX, cellYlims, lines_and_styles, 'events_lines');
            channelGridGfx.stimLines{r, c} = updateXMarkersPool(ax, channelGridGfx.stimLines{r, c}, stX, cellYlims, lines_and_styles, 'stimulus_lines');
        end
    end
end

if isempty(firstOccupied)
    return;
end

if actions.overlays || actions.chrome || needRebuild
    refreshGridChrome(ax, params, indexGrid, nRows, nCols, Xlims, Ylims, firstOccupied);
end

if actions.chrome || needRebuild
    showBars = isfield(visualSettings, 'show_scale_bars') && visualSettings.show_scale_bars;
    if ~showBars
        if ~isempty(channelGridGfx.scaleBars) && any(isgraphics(channelGridGfx.scaleBars))
            set(channelGridGfx.scaleBars(isgraphics(channelGridGfx.scaleBars)), 'Visible', 'off');
        end
    else
        channelGridGfx.scaleBars = updatePlotScaleBars(ax, channelGridGfx.scaleBars, ...
            params.shiftCoeff, params.timeSpan, params.selectedUnit, gridXlims, gridYlims);
    end
end
end

function refreshGridChrome(axLab, params, indexGrid, nRows, nCols, Xlims, Ylims, firstOccupied)
global channelGridGfx lines_and_styles
global event_label_click_callback stim_label_click_callback

if ~isfield(channelGridGfx, 'eventLabels')
    channelGridGfx.eventLabels = gobjects(0);
    channelGridGfx.eventLabelRects = gobjects(0);
    channelGridGfx.stimLabels = gobjects(0);
    channelGridGfx.stimLabelRects = gobjects(0);
    channelGridGfx.centerLabel = gobjects(0);
end

xSpan = diff(Xlims);
ySpan = diff(Ylims);
fallbackR = firstOccupied(1);
fallbackC = firstOccupied(2);
[fbXlims, fbYlims] = gridCellLimits(fallbackR, fallbackC, nRows, nCols, Xlims, Ylims);

evXs = [];
evYs = [];
evStr = {};
evCbs = {};
if params.show_events && ~isempty(params.events_x) && ~isempty(params.eventTexts)
    eventLabelsVisible = true;
    if isfield(lines_and_styles.events_lines, 'LabelVisible')
        eventLabelsVisible = logical(lines_and_styles.events_lines.LabelVisible);
    end
    if eventLabelsVisible
        nEv = numel(params.events_x);
        evXs = zeros(1, nEv);
        evYs = zeros(1, nEv);
        evStr = params.eventTexts;
        for iEv = 1:nEv
            rEv = fallbackR;
            cEv = fallbackC;
            if isfield(params, 'eventChannels') && ~isempty(params.eventChannels) && numel(params.eventChannels) >= iEv
                evCh = params.eventChannels(iEv);
                if ~isnan(evCh) && ~isinf(evCh)
                    [rFound, cFound] = findGridCellForChannel(indexGrid, evCh);
                    if ~isempty(rFound)
                        rEv = rFound;
                        cEv = cFound;
                    end
                end
            end
            [~, cellYlimsEv] = gridCellLimits(rEv, cEv, nRows, nCols, Xlims, Ylims);
            evXs(iEv) = mapTimeToGrid(params.events_x(iEv), cEv, Xlims) + xSpan * 0.01;
            evYs(iEv) = cellYlimsEv(2) - ySpan * 0.10;
            if isfield(params, 'eventAmps') && ~isempty(params.eventAmps) && numel(params.eventAmps) >= iEv ...
                    && ~isnan(params.eventAmps(iEv))
                evYs(iEv) = mapAmpToGrid(params.eventAmps(iEv), rEv, Ylims, nRows);
            end
            evCbs{iEv} = []; %#ok<AGROW>
            if ~isempty(event_label_click_callback) && numel(params.eventIndices) >= iEv
                evIx = params.eventIndices(iEv);
                evCbs{iEv} = @(~,~) event_label_click_callback(evIx);
            end
        end
    end
end
[channelGridGfx.eventLabels, channelGridGfx.eventLabelRects] = updateLabelPool( ...
    axLab, channelGridGfx.eventLabels, channelGridGfx.eventLabelRects, ...
    evXs, evYs, evStr, lines_and_styles.events_lines, evCbs);

stXs = [];
stYs = [];
stStr = {};
stCbs = {};
if params.show_stim && ~isempty(params.stims_x) && ~isempty(params.stimTexts)
    stimLabelsVisible = true;
    if isfield(lines_and_styles.stimulus_lines, 'LabelVisible')
        stimLabelsVisible = logical(lines_and_styles.stimulus_lines.LabelVisible);
    end
    if stimLabelsVisible
        stXs = mapTimeToGrid(params.stims_x, fallbackC, Xlims) + xSpan * 0.01;
        stYs = fbYlims(2) - ySpan * 0.05 + zeros(size(stXs));
        stStr = params.stimTexts;
        for i = 1:numel(stXs)
            stCbs{i} = []; %#ok<AGROW>
            if ~isempty(stim_label_click_callback) && numel(params.stimIndices) >= i
                stIx = params.stimIndices(i);
                stCbs{i} = @(~,~) stim_label_click_callback(stIx);
            end
        end
    end
end
[channelGridGfx.stimLabels, channelGridGfx.stimLabelRects] = updateLabelPool( ...
    axLab, channelGridGfx.stimLabels, channelGridGfx.stimLabelRects, ...
    stXs, stYs, stStr, lines_and_styles.stimulus_lines, stCbs);
end
