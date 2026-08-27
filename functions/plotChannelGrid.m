function plotChannelGrid(params, actions)
%PLOTCHANNELGRID Draw channel tiles; reuse axes/lines when size unchanged.

global channelGridGfx multiax lines_and_styles visualSettings axes_background_color
global event_label_click_callback stim_label_click_callback

if nargin < 2 || isempty(actions)
    actions = viewerPlotActions('visual');
end

if isempty(channelGridGfx) || ~isstruct(channelGridGfx)
    channelGridGfx = emptyChannelGridGfx();
end

plotPanel = get(multiax, 'Parent');
indexGrid = params.indexGrid;
[nRows, nCols] = size(indexGrid);
bgColor = hex2rgb(axes_background_color);
tileSpacing = 'compact';

set(multiax, 'Visible', 'off');

needRebuild = actions.invalidate || isempty(channelGridGfx.host) || ~isgraphics(channelGridGfx.host) ...
    || ~isequal(channelGridGfx.size, [nRows nCols]) ...
    || ~isfield(channelGridGfx, 'spacing') ...
    || ~strcmp(channelGridGfx.spacing, tileSpacing) ...
    || ~isfield(channelGridGfx, 'traceLines') ...
    || isempty(channelGridGfx.traceLines) ...
    || ~isequal(size(channelGridGfx.traceLines), [nRows nCols]);

if needRebuild
    clearChannelGrid();
    channelGridGfx = emptyChannelGridGfx();
    channelGridGfx.size = [nRows nCols];
    channelGridGfx.spacing = tileSpacing;
    channelGridGfx.axes = gobjects(nRows, nCols);
    channelGridGfx.traceLines = gobjects(nRows, nCols);
    channelGridGfx.nameLabels = gobjects(nRows, nCols);
    channelGridGfx.eventLines = cell(nRows, nCols);
    channelGridGfx.stimLines = cell(nRows, nCols);

        channelGridGfx.host = uipanel( ...
            'Parent', plotPanel, ...
            'Units', 'normalized', ...
            'Position', [0.08 0.02 0.92 0.87], ...
            'BorderType', 'none', ...
            'BackgroundColor', bgColor, ...
            'Tag', 'channelGridHost');

    channelGridGfx.layout = tiledlayout(channelGridGfx.host, nRows, nCols, ...
        'TileSpacing', tileSpacing, ...
        'Padding', 'none');

    for r = 1:nRows
        for c = 1:nCols
            ax = nexttile(channelGridGfx.layout);
            channelGridGfx.axes(r, c) = ax;
            set(ax, 'Tag', 'channelGridAx', 'Box', 'off', ...
                'XTick', [], 'YTick', [], ...
                'XColor', 'none', 'YColor', 'none', ...
                'Color', bgColor);
            hold(ax, 'on');
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
    set(channelGridGfx.host, 'Visible', 'on', ...
        'BackgroundColor', bgColor, ...
        'Position', [0.08 0.02 0.92 0.87]);
end

channelGridGfx.indexGrid = indexGrid;
Xlims = params.Xlims;
Ylims = params.Ylims;
timeVec = params.time;
data = params.data;
ch_inxs = params.ch_inxs;
colors = params.colors;
widths = params.widths;
labels = params.labels;

firstOccupied = [];
for r = 1:nRows
    for c = 1:nCols
        ax = channelGridGfx.axes(r, c);
        set(ax, ...
            'Color', bgColor, ...
            'XLim', Xlims, ...
            'YLim', Ylims, ...
            'XTick', [], 'YTick', [], ...
            'XColor', 'none', 'YColor', 'none', ...
            'Box', 'off');

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
            channelGridGfx.eventLines{r, c} = updateXMarkersPool(ax, channelGridGfx.eventLines{r, c}, [], Ylims, lines_and_styles, 'events_lines');
            channelGridGfx.stimLines{r, c} = updateXMarkersPool(ax, channelGridGfx.stimLines{r, c}, [], Ylims, lines_and_styles, 'stimulus_lines');
            continue;
        end

        if isempty(firstOccupied)
            firstOccupied = [r c];
        end

        if actions.traces || needRebuild
            set(hLine, ...
                'XData', timeVec, ...
                'YData', data(:, col), ...
                'Color', colors{col}, ...
                'LineWidth', widths(col), ...
                'Visible', 'on');
            set(hName, ...
                'Position', [Xlims(1) + diff(Xlims) * 0.02, Ylims(2) - diff(Ylims) * 0.08, 0], ...
                'String', labels{col}, ...
                'Visible', 'on');
        else
            set(hLine, 'Visible', 'on');
            set(hName, 'Position', [Xlims(1) + diff(Xlims) * 0.02, Ylims(2) - diff(Ylims) * 0.08, 0], 'Visible', 'on');
        end

        if actions.overlays || needRebuild
            evX = [];
            stX = [];
            if params.show_events && ~isempty(params.events_x)
                evX = params.events_x;
            end
            if params.show_stim && ~isempty(params.stims_x)
                stX = params.stims_x;
            end
            channelGridGfx.eventLines{r, c} = updateXMarkersPool(ax, channelGridGfx.eventLines{r, c}, evX, Ylims, lines_and_styles, 'events_lines');
            channelGridGfx.stimLines{r, c} = updateXMarkersPool(ax, channelGridGfx.stimLines{r, c}, stX, Ylims, lines_and_styles, 'stimulus_lines');
        end
    end
end

if isempty(firstOccupied)
    return;
end

axLab = channelGridGfx.axes(firstOccupied(1), firstOccupied(2));
if actions.overlays || actions.chrome || needRebuild
    refreshGridChrome(axLab, params, Xlims, Ylims);
end
end

function refreshGridChrome(axLab, params, Xlims, Ylims)
global channelGridGfx lines_and_styles visualSettings
global event_label_click_callback stim_label_click_callback

if ~isfield(channelGridGfx, 'eventLabels')
    channelGridGfx.eventLabels = gobjects(0);
    channelGridGfx.eventLabelRects = gobjects(0);
    channelGridGfx.stimLabels = gobjects(0);
    channelGridGfx.stimLabelRects = gobjects(0);
    channelGridGfx.centerLabel = gobjects(0);
    channelGridGfx.scaleBars = gobjects(0);
end

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
        evXs = params.events_x + diff(Xlims) * 0.01;
        evYs = Ylims(2) - diff(Ylims) * 0.10 + zeros(size(evXs));
        evStr = params.eventTexts;
        for i = 1:numel(evXs)
            evCbs{i} = []; %#ok<AGROW>
            if ~isempty(event_label_click_callback) && numel(params.eventIndices) >= i
                evIx = params.eventIndices(i);
                evCbs{i} = @(~,~) event_label_click_callback(evIx);
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
        stXs = params.stims_x + diff(Xlims) * 0.01;
        stYs = Ylims(2) - diff(Ylims) * 0.05 + zeros(size(stXs));
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

deleteGraphicsWithListeners(channelGridGfx.scaleBars(isgraphics(channelGridGfx.scaleBars)));
channelGridGfx.scaleBars = gobjects(0);
if isfield(visualSettings, 'show_scale_bars') && visualSettings.show_scale_bars
    drawPlotScaleBars(axLab, params.shiftCoeff, params.timeSpan, params.selectedUnit);
    channelGridGfx.scaleBars = findobj(axLab, '-depth', 1, 'Tag', 'plotScaleBar');
end
end
