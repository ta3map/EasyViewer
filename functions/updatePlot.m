function updatePlot()
    % disp('Plot is updated')
    global chosen_time_interval time_back cond time lfp_file mean_group_ch ch_inxs m_coef Fs newFs timeUnitFactor multiax
    global ch_labels_l shiftCoeff widths_in_l colors_in_l spks std_coef selectedUnit matFilePath stims events timeSlider timeZeroEdit
    global viewerYlimManual viewerYlim yLimMinEdit yLimMaxEdit shiftCoeffEdit
    global data time_in filterSettings filter_avaliable csd_smooth_coef
    global csd_contrast_coef csd_avaliable lfpVar
    global csd_split_by_channel_gaps
    global csd_image csd_t_range csd_ch_range offsets
    global art_rem_settings lines_and_styles
    global visualSettings
    global selectedCenter sweep_info sweep_inx % для работы со свипами
    global event_inx stim_inx
    global baseline_subtract_available % каналы с вычитанием базовой линии
    global plot_updating loading_text_handle % флаг обновления и handle текста
    global previousSliderValue % сохраняем предыдущее значение слайдера
    global event_label_click_callback stim_label_click_callback
    global event_amplitudes
    global event_channels
    global lastPlotTimeResForEvents lastPlotDataResForEvents lastPlotChInxsForEvents
    global event_title_string
    global binsize
    global timeCenterPopup
    global full_channel_trace_state
    global mainPlotGfx
    global channelNames channelEnabled
    global channelLayoutNameGrid

    if ~isempty(full_channel_trace_state) && isstruct(full_channel_trace_state)
        full_channel_trace_state.active = false;
    end

    if isempty(mainPlotGfx) || ~isstruct(mainPlotGfx)
        mainPlotGfx = emptyMainPlotGfx();
    end
    
    show_events = true;
    if isfield(visualSettings, 'events_show')
        show_events = visualSettings.events_show;
    end

    fprintf('[%s] updatePlot: START, chosen_time_interval=[%.3f, %.3f], selectedCenter=%s\n', datestr(now, 'HH:MM:SS.FFF'), chosen_time_interval(1), chosen_time_interval(2), selectedCenter);
    
    plot_updating = true;
    
    axes(multiax);
    keepLoading = gobjects(0);
    if isempty(loading_text_handle) || ~isvalid(loading_text_handle)
        loading_text_handle = text(0.5, 0.5, 'LOADING...', ...
            'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'middle', ...
            'Units', 'normalized', ...
            'FontSize', 12, ...
            'FontWeight', 'normal', ...
            'Color', 'black', ...
            'BackgroundColor', [0.8 0.8 0.8], ...
            'Visible', 'on');
    else
        set(loading_text_handle, 'Visible', 'on');
    end
    keepLoading = loading_text_handle;
    uistack(loading_text_handle, 'top');
    
    if isempty(ch_inxs)
        clearChannelGrid();
        set(multiax, 'Visible', 'on');
        clearMainAxesPlotContent(multiax, keepLoading);
        mainPlotGfx = emptyMainPlotGfx();
        xlabel('Time, s');
        ylabel('Channels');
        text(0.5, 0.5, 'No channels selected', 'HorizontalAlignment', 'center', 'Units', 'normalized');
        plot_updating = false;
        set(loading_text_handle, 'Visible', 'off');
        time_origin_early = chosen_time_interval(1);
        set(timeZeroEdit, 'String', num2str(time_origin_early * timeUnitFactor));
        if isgraphics(multiax)
            yl = get(multiax, 'YLim');
            set(yLimMinEdit, 'String', sprintf('%.6g', yl(1)));
            set(yLimMaxEdit, 'String', sprintf('%.6g', yl(2)));
        end
        return;
    end
    
    csd_active = csd_avaliable(ch_inxs);
    
    plot_time_interval = chosen_time_interval;
    plot_time_interval(1) = plot_time_interval(1) - time_back;
    
    time_origin = chosen_time_interval(1);

    [row_start, row_end] = timeWindowIndices(time, plot_time_interval(1), plot_time_interval(2));
    if isempty(row_start)
        row_start = 1;
        row_end = 0;
    end
    cond = row_start:row_end;
    local_lfp = lfp_file.lfp(cond, :);
    local_lfp(:, mean_group_ch) = local_lfp(:, mean_group_ch) - mean(local_lfp(:, mean_group_ch), 2);
    data = local_lfp(:, ch_inxs).*m_coef;
    time_in = time(cond);
    
    if not(isempty(stims)) && visualSettings.stim_show
        cond3 = stims >= plot_time_interval(1) & stims < plot_time_interval(2); 
        stims_x = (stims(cond3) - time_origin) * timeUnitFactor;
        win_r = round(art_rem_settings.artifact_window_ms * (Fs/1000));
        debugState('updatePlot', 'Stim artifact removal: Fs=%dHz, window=%.3f ms (~%d samples)', Fs, art_rem_settings.artifact_window_ms, win_r);
        data = removeStimArtifact(data, stims(cond3), time_in, win_r, art_rem_settings.interp_method);
    else
        cond3 = [];
        stims_x = [];
    end

    if sum(filter_avaliable)>0
        ch_to_filter = filter_avaliable(ch_inxs);
        data(:, ch_to_filter) = applyFilter(data(:, ch_to_filter), filterSettings, newFs);        
    end
    
    if Fs <= newFs
        data_res = data;
        time_res = time_in;
    else
        raw_Fs = Fs;
        lfp_Fs = round(newFs);
        data_res = resample1(data, lfp_Fs, raw_Fs);
        numPoints = size(data_res, 1);
        time_res = linspace(time_in(1), time_in(end), numPoints);
    end

    numChannels = size(data_res, 2);
    
    baseline_subtract_active = baseline_subtract_available(ch_inxs);
    baseline_medians = zeros(1, numChannels);
    baselineLength = max(1, round(size(data_res, 1) * 0.1));
    med = median(data_res(1:baselineLength, :), 1);
    baseline_medians(baseline_subtract_active) = med(baseline_subtract_active);
    data_res(:, baseline_subtract_active) = data_res(:, baseline_subtract_active) - med(baseline_subtract_active);

    lastPlotTimeResForEvents = time_res;
    lastPlotDataResForEvents = data_res;
    lastPlotChInxsForEvents = ch_inxs;
    
    time_in_transformed = (time_res - time_origin) * timeUnitFactor;

    layoutActive = ~isempty(channelLayoutNameGrid);

    if layoutActive
        indexGrid = matchChannelLayout(channelLayoutNameGrid, channelNames, channelEnabled);

        if visualSettings.auto_shift
            shiftCoeff = max(std(data_res)) * 2;
        end

        Xlims = (plot_time_interval - time_origin) * timeUnitFactor;
        timeSpan = diff(Xlims);

        if show_events && ~isempty(events)
            cond2 = events >= plot_time_interval(1) & events < plot_time_interval(2);
            events_x = (events(cond2) - time_origin) * timeUnitFactor;
            eventIndices = find(cond2);
        else
            cond2 = [];
            events_x = [];
            eventIndices = [];
        end

        if isempty(events_x)
            eventTexts = {};
        else
            event_times_absolute = events(cond2) * timeUnitFactor;
            event_times_relative = (events(cond2) - time_origin) * timeUnitFactor;
            fmtOpts = {'%.3f', '%.0f'};
            timeFmt = fmtOpts{1 + strcmp(selectedUnit, 'ms')};
            eventTexts = arrayfun( ...
                @(i) sprintf(['#%d\n', timeFmt, ' ', selectedUnit, '\nrel ', timeFmt, ' ', selectedUnit], ...
                    eventIndices(i), event_times_absolute(i), event_times_relative(i)), ...
                1:numel(eventIndices), 'UniformOutput', false);
        end

        stimIndices = find(cond3);
        if isempty(stims_x)
            stimTexts = {};
        else
            stimTexts = arrayfun(@(i) sprintf('%d', stimIndices(i)), 1:numel(stimIndices), 'UniformOutput', false);
        end

        [~, name, ~] = fileparts(matFilePath);
        titleLabel = name;
        eventFileLabel = strtrim(event_title_string);
        if ~isempty(eventFileLabel) && ~strcmp(eventFileLabel, 'Events')
            titleLabel = sprintf('%s | %s', name, eventFileLabel);
        end
        centerModes = {'stimulus', 'events', 'continuous'};
        centerLabels = {'Stimuli', 'Events', 'Continuos'};
        centerLabel = centerLabels{find(strcmp(centerModes, selectedCenter), 1)};
        timeFmtOpts = {'%.3f', '%.0f'};
        timeFmt = timeFmtOpts{1 + strcmp(selectedUnit, 'ms')};
        centerLabelParts = { ...
            ['Mode: ', centerLabel], ...
            sprintf([timeFmt, ' %s'], time_origin * timeUnitFactor, selectedUnit) ...
        };
        switch selectedCenter
            case 'events'
                centerLabelParts{end + 1} = sprintf('%d/%d', event_inx, numel(events));
            case 'stimulus'
                centerLabelParts{end + 1} = sprintf('%d/%d', stim_inx, numel(stims));
        end
        centerLabel = strjoin(centerLabelParts, ' | ');

        clearMainAxesPlotContent(multiax, keepLoading);
        mainPlotGfx = emptyMainPlotGfx();

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

        params = struct();
        params.indexGrid = indexGrid;
        params.time = time_in_transformed;
        params.data = data_res;
        params.ch_inxs = ch_inxs;
        params.colors = colors_in_l;
        params.widths = widths_in_l;
        params.labels = ch_labels_l;
        params.shiftCoeff = shiftCoeff;
        params.Ylims = Ylims;
        params.Xlims = Xlims;
        params.timeSpan = timeSpan;
        params.selectedUnit = selectedUnit;
        params.show_events = show_events;
        params.show_stim = logical(visualSettings.stim_show);
        params.events_x = events_x;
        params.stims_x = stims_x;
        params.eventTexts = eventTexts;
        params.stimTexts = stimTexts;
        params.eventIndices = eventIndices;
        params.stimIndices = stimIndices;
        params.titleLabel = titleLabel;
        params.centerLabel = centerLabel;
        plotChannelGrid(params);

        sliderMin = get(timeSlider, 'Min');
        sliderMax = get(timeSlider, 'Max');
        sliderValue = chosen_time_interval(1);
        sliderValue = max(sliderMin, min(sliderMax, sliderValue));
        set(timeSlider, 'Value', sliderValue);
        previousSliderValue = sliderValue;
        set(timeZeroEdit, 'String', num2str(time_origin * timeUnitFactor));
        set(yLimMinEdit, 'String', sprintf('%.6g', Ylims(1)));
        set(yLimMaxEdit, 'String', sprintf('%.6g', Ylims(2)));
        if isgraphics(shiftCoeffEdit)
            set(shiftCoeffEdit, 'String', sprintf('%.6g', shiftCoeff));
        end
        set(loading_text_handle, 'Visible', 'off');
        plot_updating = false;
        return;
    end

    clearChannelGrid();
    set(multiax, 'Visible', 'on');

    use_mua_mask = isfield(visualSettings, 'mua_use_mask') && visualSettings.mua_use_mask;
    [~, gapIdx] = splitConsecutiveChannels(ch_inxs);

    sig = struct();
    sig.ch_inxs = ch_inxs(:)';
    sig.numChannels = numChannels;
    sig.show_CSD = logical(visualSettings.show_CSD);
    sig.show_spikes = logical(visualSettings.show_spikes) && ~isempty(spks);
    sig.mua_use_mask = sig.show_spikes && logical(use_mua_mask);
    sig.gapIdx = gapIdx(:)';

    canReuse = canReuseMainPlotGfx(mainPlotGfx, sig);

    axes(multiax);
    if canReuse
        keep = keepLoading;
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
        clearMainAxesPlotContent(multiax, keep);
    else
        clearMainAxesPlotContent(multiax, keepLoading);
        mainPlotGfx = emptyMainPlotGfx();
    end

    hold(multiax, 'on');
    
    if visualSettings.auto_shift
        shiftCoeff = max(std(data_res)) * 2;
    end
    offsets = -(0:numChannels-1) * shiftCoeff;
    
    if visualSettings.show_CSD
        params.time_in_csd = time_in_transformed;
        params.data_in_csd = data_res;
        params.Fs = Fs;
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
        applyHeatmapContrast(multiax, get(multiax, 'CLim'), csd_contrast_coef);
    else
        mainPlotGfx.csdImage = gobjects(0);
    end
    
    if canReuse && numel(mainPlotGfx.traceLines) == numChannels && all(isgraphics(mainPlotGfx.traceLines))
        if visualSettings.auto_shift
            [offsets, shiftCoeff] = updateMultiplotLines(mainPlotGfx.traceLines, time_in_transformed, data_res, ...
                'ChannelLabels', ch_labels_l, ...
                'LineWidth', widths_in_l, ...
                'Color', colors_in_l);
        else
            [offsets, shiftCoeff] = updateMultiplotLines(mainPlotGfx.traceLines, time_in_transformed, data_res, ...
                'ChannelLabels', ch_labels_l, ...
                'shiftCoeff', shiftCoeff, ...
                'LineWidth', widths_in_l, ...
                'Color', colors_in_l);
        end
    else
        if visualSettings.auto_shift
            [offsets, shiftCoeff, hLines] = multiplot(time_in_transformed, data_res, ...
                'ChannelLabels', ch_labels_l, ...
                'linewidth', widths_in_l, ...
                'color', colors_in_l);
        else
            [offsets, shiftCoeff, hLines] = multiplot(time_in_transformed, data_res, ...
                'ChannelLabels', ch_labels_l, ...
                'shiftCoeff', shiftCoeff, ...
                'linewidth', widths_in_l, ...
                'color', colors_in_l);
        end
        set(hLines, 'Tag', 'trace_layer');
        mainPlotGfx.traceLines = hLines;
    end

    if canReuse && numel(mainPlotGfx.gapLines) == numel(gapIdx) && (isempty(gapIdx) || all(isgraphics(mainPlotGfx.gapLines)))
        x1 = time_in_transformed(1);
        x2 = time_in_transformed(end);
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
            x1 = time_in_transformed(1);
            x2 = time_in_transformed(end);
            mainPlotGfx.gapLines = gobjects(1, numel(gapIdx));
            for k = 1:numel(gapIdx)
                i = gapIdx(k);
                y = (offsets(i) + offsets(i+1)) / 2;
                hGap = plot([x1, x2], [y, y], '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1);
                set(hGap, 'Tag', 'trace_layer');
                mainPlotGfx.gapLines(k) = hGap;
            end
        end
    end
    
    y_pixel_size = 750;
    y_tick_min_pixel_size = 25;

    [chRanges, chRangesOffsets, chRangeIndexes] = calculateChRanges(offsets, shiftCoeff, data_res, numChannels, m_coef, y_pixel_size, y_tick_min_pixel_size);
    
    for ch_inx = 1:numChannels
        if baseline_subtract_active(ch_inx)
            ch_mask = chRangeIndexes == ch_inx;
            chRanges(ch_mask) = chRanges(ch_mask) + baseline_medians(ch_inx) / m_coef(ch_inx);
        end
    end
    
    if visualSettings.show_amplitude_labels
        rangesTimeTicks = time_in_transformed(1)+zeros(size(chRangesOffsets)) + 0.02*(time_in_transformed(end) - time_in_transformed(1));    
        rangesTimeLabels = time_in_transformed(1)+zeros(size(chRangesOffsets)) + 0.005*(time_in_transformed(end) - time_in_transformed(1)); 
        ch_inx = 0;
        for color = np_flatten(colors_in_l)
            ch_inx = ch_inx+1;
            group_index = ch_inx == chRangeIndexes;
            text(rangesTimeTicks(group_index), chRangesOffsets(group_index), num2str(chRanges(group_index)', '%.2f'), 'color', color{:}, 'backgroundcolor', 'w')
            scatter(rangesTimeLabels(group_index), chRangesOffsets(group_index), [], 'Marker', '_', 'MarkerEdgeColor', color{:})
        end
    end

    xlabel('Time, ' + string(selectedUnit) + '');
    ylabel('Channels');

    if visualSettings.show_spikes && not(isempty(spks))
        prg = std_coef;        
        mua_alpha = 0.8;
        if isfield(visualSettings, 'mua_alpha')
            mua_alpha = min(max(double(visualSettings.mua_alpha), 0), 1);
        end
        mua_color_rgb = [1, 0, 0];
        if isfield(visualSettings, 'mua_color')
            mua_color_raw = visualSettings.mua_color;
            if ischar(mua_color_raw) || isstring(mua_color_raw)
                mua_color_str = char(mua_color_raw);
                if startsWith(mua_color_str, '#') && numel(mua_color_str) == 7
                    mua_color_rgb = [ ...
                        hex2dec(mua_color_str(2:3)), ...
                        hex2dec(mua_color_str(4:5)), ...
                        hex2dec(mua_color_str(6:7))] / 255;
                elseif numel(mua_color_str) == 1
                    switch lower(mua_color_str)
                        case 'r'
                            mua_color_rgb = [1, 0, 0];
                        case 'g'
                            mua_color_rgb = [0, 1, 0];
                        case 'b'
                            mua_color_rgb = [0, 0, 1];
                        case 'c'
                            mua_color_rgb = [0, 1, 1];
                        case 'm'
                            mua_color_rgb = [1, 0, 1];
                        case 'y'
                            mua_color_rgb = [1, 1, 0];
                        case 'k'
                            mua_color_rgb = [0, 0, 0];
                        case 'w'
                            mua_color_rgb = [1, 1, 1];
                    end
                end
            elseif isnumeric(mua_color_raw) && numel(mua_color_raw) == 3
                mua_color_rgb = max(0, min(1, double(mua_color_raw(:).')));
            end
        end
        local_binsize = binsize;
        if isempty(local_binsize) || ~isfinite(local_binsize) || local_binsize <= 0
            local_binsize = 0.001;
        end
        n_bins = ceil((plot_time_interval(2) - plot_time_interval(1)) / local_binsize);
        if use_mua_mask
            mua_counts = zeros(numel(ch_inxs), n_bins);
        end
            
        c = 0;
        nEst = 0;
        if ~use_mua_mask
            for ch_pre = ch_inxs
                nEst = nEst + numel(spks(ch_pre).tStamp);
            end
        end
        x_coord = zeros(1, nEst);
        y_coord = zeros(1, nEst);
        nFill = 0;
        for ch_inx = ch_inxs
            c = c+1;
            offset = offsets(c) ;
            
            ii = abs(double(spks(ch_inx).ampl)) >= (lfpVar(ch_inx) * prg);
            spks_in(ch_inx).tStamp = spks(ch_inx).tStamp(ii);
            spks_in(ch_inx).ampl = spks(ch_inx).ampl(ii);
            
            spk = spks_in(ch_inx).tStamp/1000;
            
            if use_mua_mask
                cond4 = spk >= plot_time_interval(1) & spk < plot_time_interval(2);
                spk = spk(cond4);
                if isempty(spk)
                    continue;
                end
                
                if not(isempty(stims)) && visualSettings.stim_show
                    stims_in = stims(cond3);
                    stim_inxs = ClosestIndex(stims_in, time_in, true);
                    win_r = round(art_rem_settings.artifact_window_ms * (Fs/1000));
                    keepSpk = maskTimesOutsideStimWindows(spk, time_in, stim_inxs, win_r);
                    spk = spk(keepSpk);
                end
                
                if isempty(spk)
                    continue;
                end
                
                bin_idx = floor((spk - plot_time_interval(1)) ./ local_binsize) + 1;
                bin_idx = bin_idx(bin_idx >= 1 & bin_idx <= n_bins);
                if isempty(bin_idx)
                    continue;
                end
                mua_counts(c, :) = accumarray(bin_idx(:), 1, [n_bins, 1], @sum, 0).';
            else
                nSpk = numel(spk);
                x_coord(nFill + (1:nSpk)) = spk;
                y_coord(nFill + (1:nSpk)) = offset;
                nFill = nFill + nSpk;
            end
        end
        if ~use_mua_mask
            x_coord = x_coord(1:nFill);
            y_coord = y_coord(1:nFill);
        end
        if use_mua_mask
            max_count = max(mua_counts(:));
            if max_count > 0
                x_start = (plot_time_interval(1) - time_origin) * timeUnitFactor;
                x_end = (plot_time_interval(2) - time_origin) * timeUnitFactor;
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
                    set(mainPlotGfx.muaImage, ...
                        'CData', mua_rgb, ...
                        'XData', [x_start, x_end], ...
                        'YData', [y_start, y_end], ...
                        'AlphaData', mua_alpha_map, ...
                        'AlphaDataMapping', 'none', ...
                        'Visible', 'on');
                else
                    if ~isempty(mainPlotGfx.muaImage) && isgraphics(mainPlotGfx.muaImage)
                        delete(mainPlotGfx.muaImage);
                    end
                    h = image(multiax, [x_start, x_end], [y_start, y_end], mua_rgb);
                    set(h, 'AlphaData', mua_alpha_map, 'AlphaDataMapping', 'none');
                    set(h, 'Tag', 'mua_layer');
                    mainPlotGfx.muaImage = h;
                end
            else
                if ~isempty(mainPlotGfx.muaImage) && isgraphics(mainPlotGfx.muaImage)
                    set(mainPlotGfx.muaImage, 'Visible', 'off');
                end
            end
            mainPlotGfx.muaScatter = gobjects(0);
        else
            cond4 = x_coord >= plot_time_interval(1) & x_coord < plot_time_interval(2);
            x_coord = x_coord(cond4);
            y_coord = y_coord(cond4);
            
            if not(isempty(stims)) && visualSettings.stim_show
                stims_in = stims(cond3);
                stim_inxs = ClosestIndex(stims_in, time_in, true);
                win_r = round(art_rem_settings.artifact_window_ms * (Fs/1000));
                keepSpk = maskTimesOutsideStimWindows(x_coord, time_in, stim_inxs, win_r);
                x_coord = x_coord(keepSpk);
                y_coord = y_coord(keepSpk);
            end
            
            x_plot = (x_coord - time_origin) * timeUnitFactor;
            if canReuse && ~isempty(mainPlotGfx.muaScatter) && isgraphics(mainPlotGfx.muaScatter)
                set(mainPlotGfx.muaScatter, ...
                    'XData', x_plot, ...
                    'YData', y_coord, ...
                    'MarkerEdgeColor', mua_color_rgb, ...
                    'Visible', 'on');
            else
                if ~isempty(mainPlotGfx.muaScatter) && isgraphics(mainPlotGfx.muaScatter)
                    delete(mainPlotGfx.muaScatter);
                end
                hSc = scatter(x_plot, y_coord, 'MarkerEdgeColor', mua_color_rgb, 'Marker', '|');
                set(hSc, 'Tag', 'mua_layer');
                mainPlotGfx.muaScatter = hSc;
            end
            mainPlotGfx.muaImage = gobjects(0);
        end
    else
        mainPlotGfx.muaImage = gobjects(0);
        mainPlotGfx.muaScatter = gobjects(0);
    end

    mainPlotGfx.signature = sig;
    applySignalLayerOrder(multiax);
    
    Xlims = (plot_time_interval - time_origin) * timeUnitFactor;
    xlim(Xlims)
    
    manualYlimValid = viewerYlimManual && numel(viewerYlim) == 2 && all(isfinite(viewerYlim)) && viewerYlim(1) < viewerYlim(2);
    if manualYlimValid
        Ylims = [viewerYlim(1), viewerYlim(2)];
    elseif visualSettings.show_full_signal
        data_with_offsets = data_res + offsets;
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
    ylim(Ylims)

    [~, name, ~] = fileparts(matFilePath);
    titleLabel = name;
    eventFileLabel = strtrim(event_title_string);
    if ~isempty(eventFileLabel) && ~strcmp(eventFileLabel, 'Events')
        titleLabel = sprintf('%s | %s', name, eventFileLabel);
    end
    centerModes = {'stimulus', 'events', 'continuous'};
    centerLabels = {'Stimuli', 'Events', 'Continuos'};
    centerStyleNames = {'stimulus_lines', 'events_lines', 'stimulus_lines', ''};
    centerLabel = centerLabels{find(strcmp(centerModes, selectedCenter), 1)};
    timeFmtOpts = {'%.3f', '%.0f'};
    timeFmt = timeFmtOpts{1 + strcmp(selectedUnit, 'ms')};
    centerLabelParts = { ...
        ['Mode: ', centerLabel], ...
        sprintf([timeFmt, ' %s'], time_origin * timeUnitFactor, selectedUnit) ...
    };
    switch selectedCenter
        case 'events'
            centerLabelParts{end + 1} = sprintf('%d/%d', event_inx, numel(events));
        case 'stimulus'
            centerLabelParts{end + 1} = sprintf('%d/%d', stim_inx, numel(stims));
    end
    centerLabel = strjoin(centerLabelParts, ' | ');
    hylabel_ax(Xlims(1), multiax, titleLabel);
    centerStyleName = centerStyleNames{find(strcmp(centerModes, selectedCenter), 1)};
    modeLabelColor = [0 0.4 0];
    modeLabelBgColor = [1 1 1];
    if ~isempty(centerStyleName) && isfield(lines_and_styles, centerStyleName)
        modeLabelColor = localColorToRgb(lines_and_styles.(centerStyleName).LabelColor, [0 0 0]);
        modeLabelBgColor = localColorToRgb(lines_and_styles.(centerStyleName).LabelBackgroundColor, [1 1 1]);
    end
    modeLabelX = mean(Xlims);
    modeLabelY = multiax.YLim(2) + diff(multiax.YLim) * 0.04;
    text(multiax, modeLabelX, modeLabelY, centerLabel, ...
        'Color', modeLabelColor, ...
        'BackgroundColor', modeLabelBgColor, ...
        'FontSize', 12, ...
        'FontWeight', 'bold', ...
        'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'middle', ...
        'Clipping', 'off', ...
        'HitTest', 'on', ...
        'PickableParts', 'all', ...
        'ButtonDownFcn', @modeLabelClickCallback);
    labelHeightFractions = [0.05, 0.10];

    hold(multiax, 'on');

    if show_events && ~isempty(events)
        cond2 = events >= plot_time_interval(1) & events < plot_time_interval(2);    
        evets_x = (events(cond2) - time_origin) * timeUnitFactor;
    else
        cond2 = [];
        evets_x = [];
    end     

    if show_events
        xlineMod(evets_x, lines_and_styles, 'events_lines')
    end
    xlineMod(stims_x, lines_and_styles, 'stimulus_lines')
    
    text_y = Ylims(2) - diff(Ylims)*labelHeightFractions(2);
    text_y = zeros(numel(evets_x), 1) + text_y;
    text_x = evets_x + diff(Xlims)*0.01;
    if isempty(evets_x)
        text_text = '';
    else
        ev_ix = find(cond2);
        ev_ix = ev_ix(:);
        event_times_absolute = events(cond2) * timeUnitFactor;
        event_times_relative = (events(cond2) - time_origin) * timeUnitFactor;
        fmtOpts = {'%.3f', '%.0f'};
        timeFmt = fmtOpts{1 + strcmp(selectedUnit, 'ms')};
        idx = (1:numel(ev_ix)).';
        baseText = arrayfun( ...
            @(i) sprintf(['#%d\n', timeFmt, ' ', selectedUnit, '\nrel ', timeFmt, ' ', selectedUnit], ...
                ev_ix(i), event_times_absolute(i), event_times_relative(i)), ...
            idx, 'UniformOutput', false);
        
        ev_amps = NaN(size(ev_ix));
        if ~isempty(event_amplitudes) && numel(event_amplitudes) >= max(ev_ix)
            ev_amps = event_amplitudes(ev_ix);
        end
        
        event_y = NaN(size(ev_ix));
        if ~isempty(event_channels)
            ev_chs = event_channels(:);
            if numel(ev_chs) >= max(ev_ix)
                for iEv = 1:numel(ev_ix)
                    ev_ch = ev_chs(ev_ix(iEv));
                    if isnan(ev_ch) || isinf(ev_ch) || isnan(ev_amps(iEv))
                        continue;
                    end
                    ch_plot_idx = find(ch_inxs == ev_ch, 1, 'first');
                    if ~isempty(ch_plot_idx)
                        event_y(iEv) = offsets(ch_plot_idx) + ev_amps(iEv);
                    end
                end
            end
        end
        
        valid_event_mask = ~isnan(event_y);
        if any(valid_event_mask)
            text_y(valid_event_mask) = event_y(valid_event_mask);
        end
        
        ampText = arrayfun(@(a) sprintf('\nAmp %.3f', a), ev_amps, 'UniformOutput', false);
        ampText(isnan(ev_amps)) = {''};
        
        text_text = cellfun(@(b, a) [b a], baseText, ampText, 'UniformOutput', false);
    end
    if show_events
        eventLabelsVisible = true;
        if isfield(lines_and_styles.events_lines, 'LabelVisible')
            eventLabelsVisible = logical(lines_and_styles.events_lines.LabelVisible);
        end
        if ~eventLabelsVisible || isempty(evets_x)
            % nothing to draw
        elseif ~isempty(event_label_click_callback)
            lineStyle = lines_and_styles.events_lines;
            for i = 1:numel(ev_ix)
                drawLabelWithBg(multiax, text_x(i), text_y(i), text_text{i}, lineStyle, @(~,~) event_label_click_callback(ev_ix(i)));
            end
        else
            textMod(text_x, text_y, text_text, lines_and_styles, 'events_lines');
        end
    end

    text_y = Ylims(2) - diff(Ylims)*labelHeightFractions(1);
    text_y = zeros(numel(stims_x), 1) + text_y;
    text_x = stims_x + diff(Xlims)*0.01;
    stim_ix = find(cond3);
    if isempty(stims_x)
        text_text = '';
    else
        text_text = arrayfun(@(i) sprintf('%d', stim_ix(i)), 1:numel(stim_ix), 'UniformOutput', false);
    end
    stimLabelsVisible = true;
    if isfield(lines_and_styles.stimulus_lines, 'LabelVisible')
        stimLabelsVisible = logical(lines_and_styles.stimulus_lines.LabelVisible);
    end
    if ~stimLabelsVisible || isempty(stims_x)
        % nothing to draw
    elseif ~isempty(stim_label_click_callback)
        lineStyle = lines_and_styles.stimulus_lines;
        for i = 1:numel(stim_ix)
            drawLabelWithBg(multiax, text_x(i), text_y(i), text_text{i}, lineStyle, @(~,~) stim_label_click_callback(stim_ix(i)));
        end
    else
        textMod(text_x, text_y, text_text, lines_and_styles, 'stimulus_lines')
    end

    if isfield(visualSettings, 'show_scale_bars') && visualSettings.show_scale_bars
        drawPlotScaleBars(multiax, shiftCoeff, diff(Xlims), selectedUnit);
    end
    
    sliderMin = get(timeSlider, 'Min');
    sliderMax = get(timeSlider, 'Max');
    sliderValue = chosen_time_interval(1);
    sliderValue = max(sliderMin, min(sliderMax, sliderValue));
    set(timeSlider, 'Value', sliderValue);
    previousSliderValue = sliderValue;

    set(timeZeroEdit, 'String', num2str(time_origin * timeUnitFactor));

    set(yLimMinEdit, 'String', sprintf('%.6g', Ylims(1)));
    set(yLimMaxEdit, 'String', sprintf('%.6g', Ylims(2)));
    if isgraphics(shiftCoeffEdit)
        set(shiftCoeffEdit, 'String', sprintf('%.6g', shiftCoeff));
    end

    set(loading_text_handle, 'Visible', 'off');
    plot_updating = false;

    clear local_lfp time_in_transformed data_res
    
    function modeLabelClickCallback(~, ~)
        if isempty(timeCenterPopup) || ~isgraphics(timeCenterPopup)
            return;
        end
        popupItems = get(timeCenterPopup, 'String');
        if isempty(popupItems)
            return;
        end
        if ischar(popupItems)
            popupItems = cellstr(popupItems);
        end
        currentIdx = find(strcmp(popupItems, selectedCenter), 1, 'first');
        if isempty(currentIdx)
            currentIdx = 1;
        end
        nextIdx = mod(currentIdx, numel(popupItems)) + 1;
        set(timeCenterPopup, 'Value', nextIdx);
        popupCallback = get(timeCenterPopup, 'Callback');
        if isa(popupCallback, 'function_handle')
            popupCallback(timeCenterPopup, []);
        end
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
            case 'r'
                rgb = [1 0 0];
            case 'g'
                rgb = [0 1 0];
            case 'b'
                rgb = [0 0 1];
            case 'c'
                rgb = [0 1 1];
            case 'm'
                rgb = [1 0 1];
            case 'y'
                rgb = [1 1 0];
            case 'k'
                rgb = [0 0 0];
            case 'w'
                rgb = [1 1 1];
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

end
