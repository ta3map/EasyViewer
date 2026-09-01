function updatePlot(reason)
%UPDATEPLOT Refresh Signal Viewer plot by action reason (default: visual).

    if nargin < 1 || isempty(reason)
        reason = 'visual';
    end

    global chosen_time_interval timeUnitFactor multiax
    global ch_labels_l shiftCoeff widths_in_l colors_in_l spks std_coef selectedUnit matFilePath stims events timeSlider timeZeroEdit
    global viewerYlimManual viewerYlim yLimMinEdit yLimMaxEdit shiftCoeffEdit
    global time_in csd_smooth_coef
    global csd_contrast_coef csd_avaliable lfpVar
    global csd_split_by_channel_gaps
    global csd_image csd_t_range csd_ch_range offsets
    global art_rem_settings lines_and_styles
    global visualSettings
    global selectedCenter
    global event_inx stim_inx
    global plot_updating loading_text_handle
    global previousSliderValue
    global event_label_click_callback stim_label_click_callback
    global binsize
    global timeCenterPopup
    global full_channel_trace_state
    global mainPlotGfx
    global channelNames channelEnabled
    global channelLayoutNameGrid
    global ch_inxs m_coef Fs
    global viewerPlotDataCache

    actions = viewerPlotActions(reason);

    if ~isempty(full_channel_trace_state) && isstruct(full_channel_trace_state)
        full_channel_trace_state.active = false;
    end

    if actions.invalidate
        viewerPlotDataCache = [];
    end

    if isempty(mainPlotGfx) || ~isstruct(mainPlotGfx)
        mainPlotGfx = emptyMainPlotGfx();
    else
        mainPlotGfx = ensureMainPlotGfxFields(mainPlotGfx);
    end

    plot_updating = true;
    keepLoading = ensureLoadingVisible(actions.showLoading);

    if isempty(ch_inxs)
        clearChannelGrid();
        set(multiax, 'Visible', 'on');
        clearMainAxesPlotContent(multiax, keepLoading);
        mainPlotGfx = emptyMainPlotGfx();
        viewerPlotDataCache = [];
        updateViewerPlotTitle('');
        xlabel(multiax, 'Time, s');
        ylabel(multiax, 'Channels');
        text(multiax, 0.5, 0.5, 'No channels selected', 'HorizontalAlignment', 'center', 'Units', 'normalized');
        finishPlotUpdate(chosen_time_interval(1));
        return;
    end

    if strcmp(reason, 'ylim_manual') && ~isViewerGridDisplayActive()
        manualYlimValid = viewerYlimManual && numel(viewerYlim) == 2 ...
            && all(isfinite(viewerYlim)) && viewerYlim(1) < viewerYlim(2);
        if manualYlimValid && isgraphics(multiax)
            ylim(multiax, [viewerYlim(1), viewerYlim(2)]);
        end
        finishPlotUpdate(chosen_time_interval(1));
        return;
    end

    if actions.needData
        pd = prepareViewerPlotData();
    else
        pd = rebuildViewerPlotMetaFromCache();
        if (isfield(pd, 'needFreshData') && pd.needFreshData) || isempty(pd.data_res)
            pd = prepareViewerPlotData();
        end
    end

    layoutActive = isViewerGridDisplayActive();

    if layoutActive
        if actions.invalidate || actions.layoutSwitch
            clearMainAxesPlotContent(multiax, keepLoading);
            mainPlotGfx = emptyMainPlotGfx();
        end
        pd = refreshGridBranch(pd, actions);
        finishPlotUpdate(pd.time_origin, pd);
        return;
    end

    clearChannelGrid();
    set(multiax, 'Visible', 'on');
    pd = refreshLinearBranch(pd, actions, keepLoading);
    finishPlotUpdate(pd.time_origin, pd);
end

function keepLoading = ensureLoadingVisible(showLoading)
    global loading_text_handle multiax
    keepLoading = gobjects(0);
    plotPanel = get(multiax, 'Parent');
    loading_text_handle = loadingOverlay(plotPanel, showLoading);
end

function finishPlotUpdate(time_origin, pd)
    global plot_updating loading_text_handle timeSlider previousSliderValue
    global timeZeroEdit yLimMinEdit yLimMaxEdit shiftCoeffEdit
    global chosen_time_interval timeUnitFactor shiftCoeff multiax
    global viewerYlimManual

    sliderMin = get(timeSlider, 'Min');
    sliderMax = get(timeSlider, 'Max');
    sliderValue = chosen_time_interval(1);
    sliderValue = max(sliderMin, min(sliderMax, sliderValue));
    set(timeSlider, 'Value', sliderValue);
    previousSliderValue = sliderValue;
    set(timeZeroEdit, 'String', num2str(time_origin * timeUnitFactor));

    if nargin >= 2 && isfield(pd, 'Ylims')
        set(yLimMinEdit, 'String', sprintf('%.6g', pd.Ylims(1)));
        set(yLimMaxEdit, 'String', sprintf('%.6g', pd.Ylims(2)));
    elseif isgraphics(multiax)
        yl = get(multiax, 'YLim');
        set(yLimMinEdit, 'String', sprintf('%.6g', yl(1)));
        set(yLimMaxEdit, 'String', sprintf('%.6g', yl(2)));
    end
    if isgraphics(shiftCoeffEdit)
        set(shiftCoeffEdit, 'String', sprintf('%.6g', shiftCoeff));
    end
    loadingOverlay(get(multiax, 'Parent'), false);
    plot_updating = false;
end

function pd = refreshGridBranch(pd, actions)
    global visualSettings shiftCoeff viewerYlimManual viewerYlim
    global ch_inxs colors_in_l widths_in_l ch_labels_l selectedUnit
    global channelLayoutNameGrid channelNames channelEnabled

    indexGrid = matchChannelLayout(channelLayoutNameGrid, channelNames, channelEnabled);

    if visualSettings.auto_shift
        shiftCoeff = max(std(pd.data_res)) * 2;
    end

    manualYlimValid = viewerYlimManual && numel(viewerYlim) == 2 ...
        && all(isfinite(viewerYlim)) && viewerYlim(1) < viewerYlim(2);
    if manualYlimValid
        Ylims = [viewerYlim(1), viewerYlim(2)];
    else
        Ylims = [-shiftCoeff / 2, shiftCoeff / 2];
    end
    if viewerYlimManual && ~manualYlimValid
        viewerYlimManual = false;
    end
    pd.Ylims = Ylims;

    params = struct();
    params.indexGrid = indexGrid;
    params.time = pd.time_in_transformed;
    params.data = pd.data_res;
    params.ch_inxs = ch_inxs;
    params.colors = colors_in_l;
    params.widths = widths_in_l;
    params.labels = ch_labels_l;
    params.shiftCoeff = shiftCoeff;
    params.Ylims = Ylims;
    params.Xlims = pd.Xlims;
    params.timeSpan = pd.timeSpan;
    params.selectedUnit = selectedUnit;
    params.show_events = pd.show_events;
    params.show_stim = pd.show_stim;
    params.events_x = pd.events_x;
    params.stims_x = pd.stims_x;
    params.eventTexts = pd.eventTexts;
    params.stimTexts = pd.stimTexts;
    params.eventIndices = pd.eventIndices;
    params.stimIndices = pd.stimIndices;
    params.eventChannels = pd.eventChannels;
    params.eventAmps = pd.eventAmps;
    params.plot_time_interval = pd.plot_time_interval;
    params.time_origin = pd.time_origin;
    params.cond3 = pd.cond3;
    layerOnlyGrid = ~actions.traces && ~actions.overlays && ~actions.chrome;
    if ~layerOnlyGrid
        plotChannelGrid(params, actions);
    end
    if actions.mua
        refreshGridMuaLayer(pd, params, actions);
    end
    refreshSharedPlotHeader(pd);
end

function pd = refreshLinearBranch(pd, actions, keepLoading)
    global mainPlotGfx multiax visualSettings shiftCoeff offsets
    global ch_inxs spks
    global m_coef
    global viewerYlimManual viewerYlim selectedUnit

    numChannels = pd.numChannels;
    use_mua_mask = isfield(visualSettings, 'mua_use_mask') && visualSettings.mua_use_mask;
    [~, gapIdx] = splitConsecutiveChannels(ch_inxs);

    sig = struct();
    sig.ch_inxs = ch_inxs(:)';
    sig.numChannels = numChannels;
    sig.gapIdx = gapIdx(:)';

    canReuse = ~actions.invalidate && canReuseMainPlotGfx(mainPlotGfx, sig);
    layerOnlyRefresh = canReuse && ~actions.traces && ~actions.overlays && ~actions.chrome;
    axes(multiax);
    hold(multiax, 'on');

    if ~canReuse
        clearMainAxesPlotContent(multiax, keepLoading);
        mainPlotGfx = emptyMainPlotGfx();
    elseif ~layerOnlyRefresh
        clearEphemeralLinearOverlays(keepLoading);
    end

    if visualSettings.auto_shift
        shiftCoeff = max(std(pd.data_res)) * 2;
    end
    offsets = -(0:numChannels-1) * shiftCoeff;

    if actions.csd || ~canReuse
        refreshCsdLayer(pd, canReuse);
    end

    if actions.traces || ~canReuse
        refreshTraceLayer(pd, canReuse, gapIdx);
    end

    y_pixel_size = 750;
    y_tick_min_pixel_size = 25;
    [chRanges, chRangesOffsets, chRangeIndexes] = calculateChRanges(offsets, shiftCoeff, pd.data_res, numChannels, m_coef, y_pixel_size, y_tick_min_pixel_size);
    for ch_inx = 1:numChannels
        if pd.baseline_subtract_active(ch_inx)
            ch_mask = chRangeIndexes == ch_inx;
            chRanges(ch_mask) = chRanges(ch_mask) + pd.baseline_medians(ch_inx) / m_coef(ch_inx);
        end
    end

    if actions.mua || ~canReuse
        refreshMuaLayer(pd, canReuse, use_mua_mask);
    end

    mainPlotGfx.signature = sig;
    applySignalLayerOrder(multiax);

    xlim(multiax, pd.Xlims);
    manualYlimValid = viewerYlimManual && numel(viewerYlim) == 2 && all(isfinite(viewerYlim)) && viewerYlim(1) < viewerYlim(2);
    if manualYlimValid
        Ylims = [viewerYlim(1), viewerYlim(2)];
    elseif visualSettings.show_full_signal
        data_with_offsets = pd.data_res + offsets;
        yMin = min(data_with_offsets(:));
        yMax = max(data_with_offsets(:));
        margin = (yMax - yMin) * 0.05;
        Ylims = [yMin - margin, yMax + margin];
    else
        Ylims = [min(chRangesOffsets)-shiftCoeff*0.2, max(chRangesOffsets)+shiftCoeff*0.2];
    end
    if viewerYlimManual && ~manualYlimValid
        viewerYlimManual = false;
    end
    ylim(multiax, Ylims);
    pd.Ylims = Ylims;

    xlabel(multiax, 'Time, ' + string(selectedUnit) + '');
    ylabel(multiax, 'Channels');

    if actions.chrome || ~canReuse
        refreshAmpLabels(pd, chRanges, chRangesOffsets, chRangeIndexes);
        refreshModeAndTitle(pd);
        refreshScaleBars(pd);
    end

    if actions.overlays || ~canReuse
        refreshLinearOverlays(pd);
    end
end

function clearEphemeralLinearOverlays(keepLoading)
    global mainPlotGfx multiax
    keep = keepLoading(:);
    keep = [keep; mainPlotGfx.traceLines(:)];
    keep = [keep; mainPlotGfx.gapLines(:)];
    if ~isempty(mainPlotGfx.csdImage) && isgraphics(mainPlotGfx.csdImage)
        keep = [keep; mainPlotGfx.csdImage];
    end
    if ~isempty(mainPlotGfx.muaImage) && isgraphics(mainPlotGfx.muaImage)
        keep = [keep; mainPlotGfx.muaImage];
    end
    if ~isempty(mainPlotGfx.muaScatter) && isgraphics(mainPlotGfx.muaScatter)
        keep = [keep; mainPlotGfx.muaScatter];
    end
    poolFields = {'eventLines', 'stimLines', 'eventLabels', 'eventLabelRects', ...
        'stimLabels', 'stimLabelRects', 'modeLabel', 'titleHandle', ...
        'ampTexts', 'ampScatters', 'scaleBars'};
    for f = 1:numel(poolFields)
        name = poolFields{f};
        if isfield(mainPlotGfx, name) && ~isempty(mainPlotGfx.(name))
            keep = [keep; mainPlotGfx.(name)(:)]; %#ok<AGROW>
        end
    end
    clearMainAxesPlotContent(multiax, keep);
end

function refreshCsdLayer(pd, canReuse)
    global mainPlotGfx multiax visualSettings shiftCoeff offsets
    global ch_inxs csd_avaliable Fs newFs csd_smooth_coef csd_split_by_channel_gaps
    global csd_image csd_t_range csd_ch_range csd_contrast_coef

    if ~visualSettings.show_CSD
        if ~isempty(mainPlotGfx.csdImage) && isgraphics(mainPlotGfx.csdImage)
            set(mainPlotGfx.csdImage, 'Visible', 'off');
        end
        return;
    end

    csd_active = csd_avaliable(ch_inxs);
    params.time_in_csd = pd.time_in_transformed;
    params.data_in_csd = pd.data_res;
    params.Fs = newFs;
    params.offsets = offsets;
    params.csd_smooth_coef = csd_smooth_coef;
    params.csd_active = csd_active;
    params.ch_inxs_original = ch_inxs;
    params.csd_split_by_channel_gaps = csd_split_by_channel_gaps;
    [csd_image, csd_t_range, csd_ch_range] = csdCalc(params);
    hCsd = [];
    if canReuse && ~isempty(mainPlotGfx.csdImage) && isgraphics(mainPlotGfx.csdImage)
        hCsd = mainPlotGfx.csdImage;
    end
    mainPlotGfx.csdImage = csdPlotting(csd_image, csd_t_range, csd_ch_range, hCsd);
    set(mainPlotGfx.csdImage, 'Visible', 'on');
    applyHeatmapContrast(multiax, get(multiax, 'CLim'), csd_contrast_coef);
end

function refreshTraceLayer(pd, canReuse, gapIdx)
    global mainPlotGfx visualSettings shiftCoeff offsets
    global ch_labels_l widths_in_l colors_in_l multiax

    numChannels = pd.numChannels;
    if canReuse && numel(mainPlotGfx.traceLines) == numChannels && all(isgraphics(mainPlotGfx.traceLines))
        if visualSettings.auto_shift
            [offsets, shiftCoeff] = updateMultiplotLines(mainPlotGfx.traceLines, pd.time_in_transformed, pd.data_res, ...
                'ChannelLabels', ch_labels_l, 'LineWidth', widths_in_l, 'Color', colors_in_l);
        else
            [offsets, shiftCoeff] = updateMultiplotLines(mainPlotGfx.traceLines, pd.time_in_transformed, pd.data_res, ...
                'ChannelLabels', ch_labels_l, 'shiftCoeff', shiftCoeff, ...
                'LineWidth', widths_in_l, 'Color', colors_in_l);
        end
    else
        if visualSettings.auto_shift
            [offsets, shiftCoeff, hLines] = multiplot(pd.time_in_transformed, pd.data_res, ...
                'ChannelLabels', ch_labels_l, 'linewidth', widths_in_l, 'color', colors_in_l);
        else
            [offsets, shiftCoeff, hLines] = multiplot(pd.time_in_transformed, pd.data_res, ...
                'ChannelLabels', ch_labels_l, 'shiftCoeff', shiftCoeff, ...
                'linewidth', widths_in_l, 'color', colors_in_l);
        end
        set(hLines, 'Tag', 'trace_layer');
        mainPlotGfx.traceLines = hLines;
    end

    if canReuse && numel(mainPlotGfx.gapLines) == numel(gapIdx) && (isempty(gapIdx) || all(isgraphics(mainPlotGfx.gapLines)))
        x1 = pd.time_in_transformed(1);
        x2 = pd.time_in_transformed(end);
        for k = 1:numel(gapIdx)
            i = gapIdx(k);
            y = (offsets(i) + offsets(i+1)) / 2;
            set(mainPlotGfx.gapLines(k), 'XData', [x1, x2], 'YData', [y, y]);
        end
    else
        if ~isempty(mainPlotGfx.gapLines)
            delete(mainPlotGfx.gapLines(isgraphics(mainPlotGfx.gapLines)));
        end
        mainPlotGfx.gapLines = gobjects(0);
        if ~isempty(gapIdx)
            x1 = pd.time_in_transformed(1);
            x2 = pd.time_in_transformed(end);
            mainPlotGfx.gapLines = gobjects(1, numel(gapIdx));
            for k = 1:numel(gapIdx)
                i = gapIdx(k);
                y = (offsets(i) + offsets(i+1)) / 2;
                hGap = plot(multiax, [x1, x2], [y, y], '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1);
                set(hGap, 'Tag', 'trace_layer');
                mainPlotGfx.gapLines(k) = hGap;
            end
        end
    end
end

function refreshMuaLayer(pd, canReuse, use_mua_mask)
    global mainPlotGfx multiax visualSettings shiftCoeff offsets
    global ch_inxs spks lfpVar std_coef binsize stims art_rem_settings Fs time_in timeUnitFactor

    if ~(visualSettings.show_spikes && ~isempty(spks))
        if ~isempty(mainPlotGfx.muaImage) && isgraphics(mainPlotGfx.muaImage)
            set(mainPlotGfx.muaImage, 'Visible', 'off');
        end
        if ~isempty(mainPlotGfx.muaScatter) && isgraphics(mainPlotGfx.muaScatter)
            set(mainPlotGfx.muaScatter, 'Visible', 'off');
        end
        return;
    end

    prg = std_coef;
    mua_alpha = 0.8;
    if isfield(visualSettings, 'mua_alpha')
        mua_alpha = min(max(double(visualSettings.mua_alpha), 0), 1);
    end
    mua_color_rgb = resolveMuaColor();
    local_binsize = binsize;
    if isempty(local_binsize) || ~isfinite(local_binsize) || local_binsize <= 0
        local_binsize = 0.001;
    end
    n_bins = ceil((pd.plot_time_interval(2) - pd.plot_time_interval(1)) / local_binsize);
    if use_mua_mask
        mua_counts = zeros(numel(ch_inxs), n_bins);
    end

    c = 0;
    x_coord = [];
    y_coord = [];
    for ch_inx = ch_inxs
        c = c + 1;
        offset = offsets(c);
        spk = spikesInTimeWindow(ch_inx, pd.plot_time_interval(1), pd.plot_time_interval(2), prg, lfpVar(ch_inx));
        if isempty(spk)
            continue;
        end
        if ~isempty(stims) && visualSettings.stim_show
            stims_in = stims(pd.cond3);
            stim_inxs = ClosestIndex(stims_in, time_in, true);
            win_r = round(art_rem_settings.artifact_window_ms * (Fs / 1000));
            keepSpk = maskTimesOutsideStimWindows(spk, time_in, stim_inxs, win_r);
            spk = spk(keepSpk);
        end
        if isempty(spk)
            continue;
        end
        if use_mua_mask
            bin_idx = floor((spk - pd.plot_time_interval(1)) ./ local_binsize) + 1;
            bin_idx = bin_idx(bin_idx >= 1 & bin_idx <= n_bins);
            if isempty(bin_idx)
                continue;
            end
            mua_counts(c, :) = accumarray(bin_idx(:), 1, [n_bins, 1], @sum, 0).';
        else
            x_coord = [x_coord, spk(:)']; %#ok<AGROW>
            y_coord = [y_coord, repmat(offset, 1, numel(spk))]; %#ok<AGROW>
        end
    end

    if use_mua_mask
        max_count = max(mua_counts(:));
        if max_count > 0
            x_start = (pd.plot_time_interval(1) - pd.time_origin) * timeUnitFactor;
            x_end = (pd.plot_time_interval(2) - pd.time_origin) * timeUnitFactor;
            y_half = max(shiftCoeff * 0.18, eps);
            tone_denom = max(1 - 0.5 * mua_alpha, eps);
            mua_tone = min(1, (mua_counts / max_count) / tone_denom);
            mua_alpha_map = mua_alpha * mua_tone;
            mua_rgb = zeros(numel(ch_inxs), n_bins, 3);
            mua_rgb(:, :, 1) = mua_tone * mua_color_rgb(1);
            mua_rgb(:, :, 2) = mua_tone * mua_color_rgb(2);
            mua_rgb(:, :, 3) = mua_tone * mua_color_rgb(3);
            y_start = offsets(1) + y_half;
            y_end = offsets(end) - y_half;
            if canReuse && ~isempty(mainPlotGfx.muaImage) && isgraphics(mainPlotGfx.muaImage)
                set(mainPlotGfx.muaImage, 'CData', mua_rgb, 'XData', [x_start, x_end], ...
                    'YData', [y_start, y_end], 'AlphaData', mua_alpha_map, ...
                    'AlphaDataMapping', 'none', 'Visible', 'on');
            else
                if ~isempty(mainPlotGfx.muaImage) && isgraphics(mainPlotGfx.muaImage)
                    delete(mainPlotGfx.muaImage);
                end
                h = image(multiax, [x_start, x_end], [y_start, y_end], mua_rgb);
                set(h, 'AlphaData', mua_alpha_map, 'AlphaDataMapping', 'none', 'Tag', 'mua_layer');
                mainPlotGfx.muaImage = h;
            end
        else
            if ~isempty(mainPlotGfx.muaImage) && isgraphics(mainPlotGfx.muaImage)
                set(mainPlotGfx.muaImage, 'Visible', 'off');
            end
        end
        if ~isempty(mainPlotGfx.muaScatter) && isgraphics(mainPlotGfx.muaScatter)
            delete(mainPlotGfx.muaScatter);
        end
        mainPlotGfx.muaScatter = gobjects(0);
        return;
    end

    x_plot = (x_coord - pd.time_origin) * timeUnitFactor;
    if canReuse && ~isempty(mainPlotGfx.muaScatter) && isgraphics(mainPlotGfx.muaScatter)
        set(mainPlotGfx.muaScatter, 'XData', x_plot, 'YData', y_coord, ...
            'MarkerEdgeColor', mua_color_rgb, 'Visible', 'on');
    else
        if ~isempty(mainPlotGfx.muaScatter) && isgraphics(mainPlotGfx.muaScatter)
            delete(mainPlotGfx.muaScatter);
        end
        hSc = scatter(multiax, x_plot, y_coord, 'MarkerEdgeColor', mua_color_rgb, 'Marker', '|');
        set(hSc, 'Tag', 'mua_layer');
        mainPlotGfx.muaScatter = hSc;
    end
    if ~isempty(mainPlotGfx.muaImage) && isgraphics(mainPlotGfx.muaImage)
        delete(mainPlotGfx.muaImage);
    end
    mainPlotGfx.muaImage = gobjects(0);
end

function refreshGridMuaLayer(pd, params, actions)
    global channelGridGfx visualSettings
    global spks lfpVar std_coef binsize stims art_rem_settings Fs time_in timeUnitFactor

    if isempty(channelGridGfx) || ~isstruct(channelGridGfx) ...
            || ~isfield(channelGridGfx, 'axes') || ~isgraphics(channelGridGfx.axes)
        return;
    end

    indexGrid = params.indexGrid;
    [nRows, nCols] = size(indexGrid);
    Xlims = params.Xlims;
    Ylims = params.Ylims;
    ax = channelGridGfx.axes;
    use_mua_mask = isfield(visualSettings, 'mua_use_mask') && visualSettings.mua_use_mask;

    if ~(visualSettings.show_spikes && ~isempty(spks))
        hideGridMuaLayer(nRows, nCols);
        return;
    end

    prg = std_coef;
    mua_alpha = 0.8;
    if isfield(visualSettings, 'mua_alpha')
        mua_alpha = min(max(double(visualSettings.mua_alpha), 0), 1);
    end
    mua_color_rgb = resolveMuaColor();
    local_binsize = binsize;
    if isempty(local_binsize) || ~isfinite(local_binsize) || local_binsize <= 0
        local_binsize = 0.001;
    end
    n_bins = ceil((pd.plot_time_interval(2) - pd.plot_time_interval(1)) / local_binsize);
    canReuse = ~actions.invalidate && isfield(channelGridGfx, 'muaImages') ...
        && isequal(size(channelGridGfx.muaImages), [nRows nCols]);

    if ~isfield(channelGridGfx, 'muaImages') || ~isequal(size(channelGridGfx.muaImages), [nRows nCols])
        channelGridGfx.muaImages = gobjects(nRows, nCols);
        channelGridGfx.muaScatters = gobjects(nRows, nCols);
        canReuse = false;
    end

    for r = 1:nRows
        for c = 1:nCols
            chIdx = indexGrid(r, c);
            hImg = channelGridGfx.muaImages(r, c);
            hSc = channelGridGfx.muaScatters(r, c);
            if chIdx < 1
                hideGridMuaCell(hImg, hSc);
                channelGridGfx.muaImages(r, c) = gobjects(1);
                channelGridGfx.muaScatters(r, c) = gobjects(1);
                continue;
            end
            [cellXlims, cellYlims] = gridCellLimits(r, c, nRows, nCols, Xlims, Ylims);
            spk = gridChannelSpikes(chIdx, pd, prg, use_mua_mask, local_binsize, n_bins);
            if use_mua_mask
                [hImg, hSc] = drawGridMuaMask(ax, hImg, hSc, spk, cellXlims, cellYlims, Xlims, c, pd, ...
                    mua_color_rgb, mua_alpha, canReuse);
                channelGridGfx.muaImages(r, c) = hImg;
                channelGridGfx.muaScatters(r, c) = gobjects(1);
            else
                [hSc, hImg] = drawGridMuaScatter(ax, hSc, hImg, spk, r, c, Xlims, Ylims, nRows, pd, ...
                    mua_color_rgb, canReuse);
                channelGridGfx.muaScatters(r, c) = hSc;
                channelGridGfx.muaImages(r, c) = gobjects(1);
            end
        end
    end

    muaLayer = findobj(ax, '-depth', 1, 'Tag', 'mua_layer');
    if ~isempty(muaLayer)
        uistack(muaLayer, 'bottom');
    end
end

function spk = gridChannelSpikes(chIdx, pd, prg, use_mua_mask, local_binsize, n_bins)
    global lfpVar stims visualSettings art_rem_settings Fs time_in

    spk = spikesInTimeWindow(chIdx, pd.plot_time_interval(1), pd.plot_time_interval(2), prg, lfpVar(chIdx));
    if isempty(spk)
        return;
    end
    if ~isempty(stims) && visualSettings.stim_show
        stims_in = stims(pd.cond3);
        stim_inxs = ClosestIndex(stims_in, time_in, true);
        win_r = round(art_rem_settings.artifact_window_ms * (Fs / 1000));
        keepSpk = maskTimesOutsideStimWindows(spk, time_in, stim_inxs, win_r);
        spk = spk(keepSpk);
    end
    if use_mua_mask && ~isempty(spk)
        bin_idx = floor((spk - pd.plot_time_interval(1)) ./ local_binsize) + 1;
        bin_idx = bin_idx(bin_idx >= 1 & bin_idx <= n_bins);
        counts = accumarray(bin_idx(:), 1, [n_bins, 1], @sum, 0).';
        spk = counts;
    end
end

function [hImg, hSc] = drawGridMuaMask(ax, hImg, hSc, mua_counts, cellXlims, cellYlims, Xlims, c, pd, ...
        mua_color_rgb, mua_alpha, canReuse)
    global timeUnitFactor
    hSc = gobjects(1);
    if isempty(hImg) || ~isgraphics(hImg)
        hImg = gobjects(1);
    end
    if isempty(mua_counts)
        hideGridMuaCell(hImg, hSc);
        hImg = gobjects(1);
        return;
    end
    max_count = max(mua_counts);
    if max_count <= 0
        hideGridMuaCell(hImg, hSc);
        hImg = gobjects(1);
        return;
    end
    x_start = mapTimeToGrid((pd.plot_time_interval(1) - pd.time_origin) * timeUnitFactor, c, Xlims);
    x_end = mapTimeToGrid((pd.plot_time_interval(2) - pd.time_origin) * timeUnitFactor, c, Xlims);
    tone_denom = max(1 - 0.5 * mua_alpha, eps);
    mua_tone = min(1, (mua_counts / max_count) / tone_denom);
    mua_alpha_map = mua_alpha * mua_tone;
    mua_rgb = zeros(1, numel(mua_counts), 3);
    mua_rgb(1, :, 1) = mua_tone * mua_color_rgb(1);
    mua_rgb(1, :, 2) = mua_tone * mua_color_rgb(2);
    mua_rgb(1, :, 3) = mua_tone * mua_color_rgb(3);
    if canReuse && isgraphics(hImg)
        set(hImg, 'CData', mua_rgb, 'XData', [x_start, x_end], ...
            'YData', cellYlims, 'AlphaData', mua_alpha_map, ...
            'AlphaDataMapping', 'none', 'Visible', 'on');
        return;
    end
    if isgraphics(hImg)
        delete(hImg);
    end
    hImg = image(ax, [x_start, x_end], cellYlims, mua_rgb);
    set(hImg, 'AlphaData', mua_alpha_map, 'AlphaDataMapping', 'none', 'Tag', 'mua_layer');
end

function [hSc, hImg] = drawGridMuaScatter(ax, hSc, hImg, spk, r, c, Xlims, Ylims, nRows, pd, ...
        mua_color_rgb, canReuse)
    global timeUnitFactor
    hImg = gobjects(1);
    if isgraphics(hImg)
        delete(hImg);
    end
    if isempty(spk)
        hideGridMuaCell(gobjects(1), hSc);
        hSc = gobjects(1);
        return;
    end
    x_plot = mapTimeToGrid((spk - pd.time_origin) * timeUnitFactor, c, Xlims);
    y_plot = mapAmpToGrid(zeros(size(spk)), r, Ylims, nRows);
    if canReuse && isgraphics(hSc)
        set(hSc, 'XData', x_plot, 'YData', y_plot, 'MarkerEdgeColor', mua_color_rgb, 'Visible', 'on');
        return;
    end
    if isgraphics(hSc)
        delete(hSc);
    end
    hSc = scatter(ax, x_plot, y_plot, 'MarkerEdgeColor', mua_color_rgb, 'Marker', '|');
    set(hSc, 'Tag', 'mua_layer');
end

function hideGridMuaLayer(nRows, nCols)
    global channelGridGfx
    if ~isfield(channelGridGfx, 'muaImages') || isempty(channelGridGfx.muaImages)
        return;
    end
    for r = 1:nRows
        for c = 1:nCols
            hideGridMuaCell(channelGridGfx.muaImages(r, c), channelGridGfx.muaScatters(r, c));
            channelGridGfx.muaImages(r, c) = gobjects(1);
            channelGridGfx.muaScatters(r, c) = gobjects(1);
        end
    end
end

function hideGridMuaCell(hImg, hSc)
    if isgraphics(hImg)
        set(hImg, 'Visible', 'off');
    end
    if isgraphics(hSc)
        set(hSc, 'Visible', 'off');
    end
end

function rgb = resolveMuaColor()
    global visualSettings
    rgb = [1, 0, 0];
    if ~isfield(visualSettings, 'mua_color')
        return;
    end
    mua_color_raw = visualSettings.mua_color;
    if ischar(mua_color_raw) || isstring(mua_color_raw)
        mua_color_str = char(mua_color_raw);
        if startsWith(mua_color_str, '#') && numel(mua_color_str) == 7
            rgb = [hex2dec(mua_color_str(2:3)), hex2dec(mua_color_str(4:5)), hex2dec(mua_color_str(6:7))] / 255;
            return;
        end
        switch lower(mua_color_str)
            case 'r', rgb = [1 0 0];
            case 'g', rgb = [0 1 0];
            case 'b', rgb = [0 0 1];
            case 'c', rgb = [0 1 1];
            case 'm', rgb = [1 0 1];
            case 'y', rgb = [1 1 0];
            case 'k', rgb = [0 0 0];
            case 'w', rgb = [1 1 1];
        end
        return;
    end
    if isnumeric(mua_color_raw) && numel(mua_color_raw) == 3
        rgb = max(0, min(1, double(mua_color_raw(:).')));
    end
end

function refreshAmpLabels(pd, chRanges, chRangesOffsets, chRangeIndexes)
    global mainPlotGfx multiax visualSettings colors_in_l

    if ~visualSettings.show_amplitude_labels
        [mainPlotGfx.ampTexts, mainPlotGfx.ampScatters] = updateAmpLabelPool( ...
            multiax, mainPlotGfx.ampTexts, mainPlotGfx.ampScatters, ...
            [], [], [], [], {}, {});
        return;
    end

    xSpan = pd.time_in_transformed(end) - pd.time_in_transformed(1);
    rangesTimeTicks = pd.time_in_transformed(1) + zeros(size(chRangesOffsets)) + 0.02 * xSpan;
    rangesTimeLabels = pd.time_in_transformed(1) + zeros(size(chRangesOffsets)) + 0.005 * xSpan;

    tickX = [];
    tickY = [];
    markX = [];
    markY = [];
    strings = {};
    colors = {};
    ch_inx = 0;
    for color = np_flatten(colors_in_l)
        ch_inx = ch_inx + 1;
        group_index = ch_inx == chRangeIndexes;
        if ~any(group_index)
            continue;
        end
        vals = chRanges(group_index);
        n = numel(vals);
        tickX = [tickX; rangesTimeTicks(group_index(:))]; %#ok<AGROW>
        tickY = [tickY; chRangesOffsets(group_index(:))]; %#ok<AGROW>
        markX = [markX; rangesTimeLabels(group_index(:))]; %#ok<AGROW>
        markY = [markY; chRangesOffsets(group_index(:))]; %#ok<AGROW>
        lbl = arrayfun(@(v) sprintf('%.2f', v), vals, 'UniformOutput', false);
        strings = [strings, lbl]; %#ok<AGROW>
        colors = [colors, repmat({color{:}}, 1, n)]; %#ok<AGROW>
    end

    [mainPlotGfx.ampTexts, mainPlotGfx.ampScatters] = updateAmpLabelPool( ...
        multiax, mainPlotGfx.ampTexts, mainPlotGfx.ampScatters, ...
        tickX, tickY, markX, markY, strings, colors);
end

function refreshModeAndTitle(pd)
    refreshSharedPlotHeader(pd);
end

function refreshSharedPlotHeader(pd)
    global lines_and_styles selectedCenter

    centerModes = {'stimulus', 'events', 'continuous'};
    centerStyleNames = {'stimulus_lines', 'events_lines', 'stimulus_lines'};
    centerStyleName = centerStyleNames{find(strcmp(centerModes, selectedCenter), 1)};
    modeLabelColor = [0 0.4 0];
    modeLabelBgColor = [1 1 1];
    if ~isempty(centerStyleName) && isfield(lines_and_styles, centerStyleName)
        modeLabelColor = localColorToRgb(lines_and_styles.(centerStyleName).LabelColor, [0 0 0]);
        modeLabelBgColor = localColorToRgb(lines_and_styles.(centerStyleName).LabelBackgroundColor, [1 1 1]);
    end
    updateViewerPlotTitle(pd.titleLabel, pd.centerLabel, modeLabelColor, modeLabelBgColor);
end

function refreshScaleBars(pd)
    global mainPlotGfx multiax visualSettings shiftCoeff selectedUnit

    showBars = isfield(visualSettings, 'show_scale_bars') && visualSettings.show_scale_bars;
    if ~showBars
        if ~isempty(mainPlotGfx.scaleBars) && any(isgraphics(mainPlotGfx.scaleBars))
            set(mainPlotGfx.scaleBars(isgraphics(mainPlotGfx.scaleBars)), 'Visible', 'off');
        end
        return;
    end

    mainPlotGfx.scaleBars = updatePlotScaleBars(multiax, mainPlotGfx.scaleBars, ...
        shiftCoeff, pd.timeSpan, selectedUnit, [], []);
end

function refreshLinearOverlays(pd)
    global mainPlotGfx multiax lines_and_styles
    global event_label_click_callback stim_label_click_callback
    global offsets ch_inxs

    Ylims = pd.Ylims;
    Xlims = pd.Xlims;

    evX = [];
    if pd.show_events
        evX = pd.events_x;
    end
    stX = [];
    if pd.show_stim
        stX = pd.stims_x;
    end
    mainPlotGfx.eventLines = updateXMarkersPool(multiax, mainPlotGfx.eventLines, evX, Ylims, lines_and_styles, 'events_lines');
    mainPlotGfx.stimLines = updateXMarkersPool(multiax, mainPlotGfx.stimLines, stX, Ylims, lines_and_styles, 'stimulus_lines');

    evXs = [];
    evYs = [];
    evStr = {};
    evCbs = {};
    eventLabelsVisible = true;
    if isfield(lines_and_styles.events_lines, 'LabelVisible')
        eventLabelsVisible = logical(lines_and_styles.events_lines.LabelVisible);
    end
    if pd.show_events && eventLabelsVisible && ~isempty(pd.events_x)
        evXs = pd.events_x + diff(Xlims) * 0.01;
        evYs = Ylims(2) - diff(Ylims) * 0.10 + zeros(size(evXs));
        if ~isempty(pd.eventChannels) && ~isempty(pd.eventAmps)
            for iEv = 1:numel(pd.eventIndices)
                ev_ch = pd.eventChannels(iEv);
                if isnan(ev_ch) || isinf(ev_ch) || isnan(pd.eventAmps(iEv))
                    continue;
                end
                ch_plot_idx = find(ch_inxs == ev_ch, 1, 'first');
                if ~isempty(ch_plot_idx)
                    evYs(iEv) = offsets(ch_plot_idx) + pd.eventAmps(iEv);
                end
            end
        end
        evStr = pd.eventTexts;
        for i = 1:numel(evXs)
            evCbs{i} = []; %#ok<AGROW>
            if ~isempty(event_label_click_callback)
                evIx = pd.eventIndices(i);
                evCbs{i} = @(~,~) event_label_click_callback(evIx);
            end
        end
    end
    [mainPlotGfx.eventLabels, mainPlotGfx.eventLabelRects] = updateLabelPool( ...
        multiax, mainPlotGfx.eventLabels, mainPlotGfx.eventLabelRects, ...
        evXs, evYs, evStr, lines_and_styles.events_lines, evCbs);

    stXs = [];
    stYs = [];
    stStr = {};
    stCbs = {};
    stimLabelsVisible = true;
    if isfield(lines_and_styles.stimulus_lines, 'LabelVisible')
        stimLabelsVisible = logical(lines_and_styles.stimulus_lines.LabelVisible);
    end
    if pd.show_stim && stimLabelsVisible && ~isempty(pd.stims_x)
        stXs = pd.stims_x + diff(Xlims) * 0.01;
        stYs = Ylims(2) - diff(Ylims) * 0.05 + zeros(size(stXs));
        stStr = pd.stimTexts;
        for i = 1:numel(stXs)
            stCbs{i} = []; %#ok<AGROW>
            if ~isempty(stim_label_click_callback)
                stIx = pd.stimIndices(i);
                stCbs{i} = @(~,~) stim_label_click_callback(stIx);
            end
        end
    end
    [mainPlotGfx.stimLabels, mainPlotGfx.stimLabelRects] = updateLabelPool( ...
        multiax, mainPlotGfx.stimLabels, mainPlotGfx.stimLabelRects, ...
        stXs, stYs, stStr, lines_and_styles.stimulus_lines, stCbs);
end

function rgb = localColorToRgb(colorSpec, defaultRgb)
    if nargin < 2
        defaultRgb = [0 0 0];
    end
    rgb = defaultRgb;
    if isnumeric(colorSpec) && numel(colorSpec) == 3
        rgb = max(0, min(1, double(colorSpec(:).')));
        return;
    end
    if ~(ischar(colorSpec) || isstring(colorSpec))
        return;
    end
    colorSpec = char(colorSpec);
    switch lower(colorSpec)
        case 'r', rgb = [1 0 0];
        case 'g', rgb = [0 1 0];
        case 'b', rgb = [0 0 1];
        case 'c', rgb = [0 1 1];
        case 'm', rgb = [1 0 1];
        case 'y', rgb = [1 1 0];
        case 'k', rgb = [0 0 0];
        case 'w', rgb = [1 1 1];
        otherwise
            if startsWith(colorSpec, '#') && numel(colorSpec) == 7
                rgb = hex2rgb(colorSpec);
            end
    end
end

function applySignalLayerOrder(axHandle)
    muaLayer = findobj(axHandle, '-depth', 1, 'Tag', 'mua_layer');
    csdLayer = findobj(axHandle, '-depth', 1, 'Tag', 'csd_layer');
    traceLayer = findobj(axHandle, '-depth', 1, 'Tag', 'trace_layer');
    if ~isempty(muaLayer)
        uistack(muaLayer, 'bottom');
    end
    if ~isempty(csdLayer)
        uistack(csdLayer, 'bottom');
    end
    if ~isempty(traceLayer)
        uistack(traceLayer, 'top');
    end
end

function gfx = ensureMainPlotGfxFields(gfx)
    template = emptyMainPlotGfx();
    names = fieldnames(template);
    for i = 1:numel(names)
        if ~isfield(gfx, names{i})
            gfx.(names{i}) = template.(names{i});
        end
    end
end
