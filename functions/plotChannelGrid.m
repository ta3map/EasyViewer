function plotChannelGrid(params)
%PLOTCHANNELGRID Draw channel tiles in a host panel beside multiax.

    global channelGridGfx multiax lines_and_styles visualSettings axes_background_color

    if isempty(channelGridGfx) || ~isstruct(channelGridGfx)
        channelGridGfx = emptyChannelGridGfx();
    end

    plotPanel = get(multiax, 'Parent');
    indexGrid = params.indexGrid;
    [nRows, nCols] = size(indexGrid);
    bgColor = hex2rgb(axes_background_color);
    tileSpacing = 'compact';

    set(multiax, 'Visible', 'off');

    needRebuild = isempty(channelGridGfx.host) || ~isgraphics(channelGridGfx.host) ...
        || ~isequal(channelGridGfx.size, [nRows nCols]) ...
        || ~isfield(channelGridGfx, 'spacing') ...
        || ~strcmp(channelGridGfx.spacing, tileSpacing);

    if needRebuild
        clearChannelGrid();
        channelGridGfx = emptyChannelGridGfx();
        channelGridGfx.size = [nRows nCols];
        channelGridGfx.spacing = tileSpacing;
        channelGridGfx.axes = gobjects(nRows, nCols);

        channelGridGfx.host = uipanel( ...
            'Parent', plotPanel, ...
            'Units', 'normalized', ...
            'Position', [0.08 0.02 0.92 0.96], ...
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
            end
        end
    else
        set(channelGridGfx.host, 'Visible', 'on', ...
            'BackgroundColor', bgColor, ...
            'Position', [0.08 0.02 0.92 0.96]);
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
            cla(ax);
            hold(ax, 'on');
            set(ax, ...
                'Color', bgColor, ...
                'XLim', Xlims, ...
                'YLim', Ylims, ...
                'XTick', [], 'YTick', [], ...
                'XColor', 'none', 'YColor', 'none', ...
                'Box', 'off');

            chIdx = indexGrid(r, c);
            if chIdx < 1
                continue;
            end

            col = find(ch_inxs == chIdx, 1, 'first');
            if isempty(col)
                continue;
            end

            if isempty(firstOccupied)
                firstOccupied = [r c];
            end

            plot(ax, timeVec, data(:, col), ...
                'Color', colors{col}, ...
                'LineWidth', widths(col));

            text(ax, Xlims(1) + diff(Xlims) * 0.02, Ylims(2) - diff(Ylims) * 0.08, ...
                labels{col}, ...
                'Color', [0.2 0.2 0.2], ...
                'FontSize', 9, ...
                'FontWeight', 'bold', ...
                'Interpreter', 'none', ...
                'HorizontalAlignment', 'left', ...
                'VerticalAlignment', 'top', ...
                'Clipping', 'on');

            if params.show_events && ~isempty(params.events_x)
                drawXMarkers(ax, params.events_x, lines_and_styles, 'events_lines', Ylims);
            end
            if params.show_stim && ~isempty(params.stims_x)
                drawXMarkers(ax, params.stims_x, lines_and_styles, 'stimulus_lines', Ylims);
            end
        end
    end

    if isempty(firstOccupied)
        return;
    end

    axLab = channelGridGfx.axes(firstOccupied(1), firstOccupied(2));
    drawEventStimLabels(axLab, params, Xlims, Ylims);

    if isfield(visualSettings, 'show_scale_bars') && visualSettings.show_scale_bars
        drawPlotScaleBars(axLab, params.shiftCoeff, params.timeSpan, params.selectedUnit);
    end
    if ~isempty(params.centerLabel)
        text(axLab, mean(Xlims), Ylims(2), params.centerLabel, ...
            'FontSize', 9, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
            'Interpreter', 'none', 'HitTest', 'off', 'Clipping', 'off');
    end
end

function drawXMarkers(ax, xVals, lines_and_styles, lineName, Ylims)
    lineStyle = lines_and_styles.(lineName);
    lineAlpha = 1;
    if isfield(lineStyle, 'LineAlpha')
        lineAlpha = lineStyle.LineAlpha;
    end
    lineColor = toRgbColorLocal(lineStyle.LineColor);

    if lineAlpha >= 1
        for i = 1:numel(xVals)
            plot(ax, [xVals(i) xVals(i)], Ylims, ...
                'Color', lineColor, ...
                'LineStyle', lineStyle.LineStyle, ...
                'LineWidth', lineStyle.LineWidth, ...
                'HitTest', 'off');
        end
        return;
    end

    xSpan = max(eps, ax.XLim(2) - ax.XLim(1));
    stripeWidth = max(eps, xSpan * 0.0008 * lineStyle.LineWidth);
    for i = 1:numel(xVals)
        x1 = xVals(i) - stripeWidth / 2;
        x2 = xVals(i) + stripeWidth / 2;
        patch(ax, [x1 x2 x2 x1], [Ylims(1) Ylims(1) Ylims(2) Ylims(2)], lineColor, ...
            'FaceAlpha', lineAlpha, 'EdgeColor', 'none', 'HitTest', 'off');
    end
end

function drawEventStimLabels(ax, params, Xlims, Ylims)
    global lines_and_styles event_label_click_callback stim_label_click_callback

    if params.show_events && ~isempty(params.events_x) && ~isempty(params.eventTexts)
        eventLabelsVisible = true;
        if isfield(lines_and_styles.events_lines, 'LabelVisible')
            eventLabelsVisible = logical(lines_and_styles.events_lines.LabelVisible);
        end
        if eventLabelsVisible
            text_y = Ylims(2) - diff(Ylims) * 0.10;
            text_x = params.events_x + diff(Xlims) * 0.01;
            lineStyle = lines_and_styles.events_lines;
            for i = 1:numel(params.events_x)
                cb = [];
                if ~isempty(event_label_click_callback) && numel(params.eventIndices) >= i
                    evIx = params.eventIndices(i);
                    cb = @(~,~) event_label_click_callback(evIx);
                end
                drawLabelWithBg(ax, text_x(i), text_y, params.eventTexts{i}, lineStyle, cb);
            end
        end
    end

    if params.show_stim && ~isempty(params.stims_x) && ~isempty(params.stimTexts)
        stimLabelsVisible = true;
        if isfield(lines_and_styles.stimulus_lines, 'LabelVisible')
            stimLabelsVisible = logical(lines_and_styles.stimulus_lines.LabelVisible);
        end
        if stimLabelsVisible
            text_y = Ylims(2) - diff(Ylims) * 0.05;
            text_x = params.stims_x + diff(Xlims) * 0.01;
            lineStyle = lines_and_styles.stimulus_lines;
            for i = 1:numel(params.stims_x)
                cb = [];
                if ~isempty(stim_label_click_callback) && numel(params.stimIndices) >= i
                    stIx = params.stimIndices(i);
                    cb = @(~,~) stim_label_click_callback(stIx);
                end
                drawLabelWithBg(ax, text_x(i), text_y, params.stimTexts{i}, lineStyle, cb);
            end
        end
    end
end

function rgb = toRgbColorLocal(colorValue)
    if isnumeric(colorValue) && numel(colorValue) == 3
        rgb = colorValue(:)';
        return;
    end
    switch colorValue
        case 'r', rgb = [1 0 0];
        case 'g', rgb = [0 1 0];
        case 'b', rgb = [0 0 1];
        case 'k', rgb = [0 0 0];
        case 'y', rgb = [1 1 0];
        case 'm', rgb = [1 0 1];
        case 'c', rgb = [0 1 1];
        case 'w', rgb = [1 1 1];
        otherwise, rgb = [0 0 0];
    end
end

function gfx = emptyChannelGridGfx()
    gfx = struct( ...
        'host', gobjects(0), ...
        'layout', [], ...
        'axes', gobjects(0), ...
        'size', [0 0], ...
        'spacing', '', ...
        'indexGrid', []);
end
