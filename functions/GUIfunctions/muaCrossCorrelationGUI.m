function muaCrossCorrelationGUI()
    global spks events events_exist channelNames timeUnitFactor selectedUnit matFilePath SettingsFilepath

    correlation_result = struct();

    if isempty(SettingsFilepath)
        SettingsFilepath = fullfile(tempdir, 'ev_settings.mat');
    end
    savedMuaCcg = struct();
    if exist(SettingsFilepath, 'file')
        d = load(SettingsFilepath);
        if isfield(d, 'mua_ccg_settings')
            savedMuaCcg = d.mua_ccg_settings;
        end
    end

    figTag = 'muaCrossCorrelationGUI';
    guiFig = findobj('Type', 'figure', 'Tag', figTag);
    if ~isempty(guiFig)
        figure(guiFig);
        guiFig.WindowState = 'maximized';
        return;
    end

    if isempty(spks)
        errordlg('No MUA data (spks). Load a .mua or .mat file with spikes.', 'MUA Cross-Correlation');
        return;
    end

    nSpk = numel(spks);
    hasAny = false(nSpk, 1);
    for c = 1:nSpk
        hasAny(c) = ~isempty(spks(c).tStamp);
    end
    if ~any(hasAny)
        errordlg('No spikes in spks.', 'MUA Cross-Correlation');
        return;
    end

    chLabels = cell(nSpk, 1);
    for c = 1:nSpk
        chLabels{c} = channelLabelForIndex(c, channelNames);
    end

    [tDef0, tDef1] = defaultIntervalSecFromSpks(spks);

    hFig = figure('Name', 'MUA Cross-Correlation', 'NumberTitle', 'off', ...
        'Position', [120, 120, 1040, 540], 'Resize', 'on', ...
        'MenuBar', 'none', 'ToolBar', 'figure', ...
        'Tag', figTag);
    hFig.WindowState = 'maximized';
    hFig.CloseRequestFcn = @onCloseMuaCcgGui;

    px = 0.37;
    lx = 0.13;
    ex = 0.51;
    ew = 0.12;
    axL = 0.65;
    axW = 0.33;
    plotPanel = uipanel('Parent', hFig, 'Units', 'normalized', 'Position', [axL, 0.10, axW, 0.82], ...
        'BorderType', 'none', 'BackgroundColor', get(hFig, 'Color'), 'Tag', 'muaXc_plotPanel');
    ax = axes('Parent', plotPanel, 'Units', 'normalized', 'Position', [0.08, 0.11, 0.86, 0.82]);

    uicontrol(hFig, 'Style', 'text', 'Units', 'normalized', 'Position', [0.03, 0.92, 0.32, 0.04], ...
        'String', 'Channels A', 'HorizontalAlignment', 'left');
    idxHas = find(hasAny);
    vPickA = idxHas(1);
    vPickB = idxHas(min(2, numel(idxHas)));

    listA = uicontrol(hFig, 'Style', 'listbox', 'Units', 'normalized', 'Position', [0.03, 0.58, 0.32, 0.33], ...
        'String', chLabels, 'Min', 0, 'Max', nSpk, 'Value', vPickA);

    uicontrol(hFig, 'Style', 'text', 'Units', 'normalized', 'Position', [0.03, 0.52, 0.32, 0.04], ...
        'String', 'Channels B', 'HorizontalAlignment', 'left');
    listB = uicontrol(hFig, 'Style', 'listbox', 'Units', 'normalized', 'Position', [0.03, 0.18, 0.32, 0.33], ...
        'String', chLabels, 'Min', 0, 'Max', nSpk, 'Value', vPickB);

    y0 = 0.11;
    dy = 0.052;
    uicontrol(hFig, 'Style', 'text', 'Units', 'normalized', 'Position', [px, y0 + 4 * dy, lx, 0.038], ...
        'String', ['Bin (' selectedUnit ')'], 'HorizontalAlignment', 'left');
    binEdit = uicontrol(hFig, 'Style', 'edit', 'Units', 'normalized', 'Position', [ex, y0 + 4 * dy, ew, 0.038], ...
        'String', num2str(0.01 * timeUnitFactor), 'HorizontalAlignment', 'left');

    uicontrol(hFig, 'Style', 'text', 'Units', 'normalized', 'Position', [px, y0 + 3 * dy, lx, 0.038], ...
        'String', ['Max lag (' selectedUnit ')'], 'HorizontalAlignment', 'left');
    maxLagEdit = uicontrol(hFig, 'Style', 'edit', 'Units', 'normalized', 'Position', [ex, y0 + 3 * dy, ew, 0.038], ...
        'String', num2str(1 * timeUnitFactor), 'HorizontalAlignment', 'left');

    uicontrol(hFig, 'Style', 'text', 'Units', 'normalized', 'Position', [px, y0 + 2 * dy, lx, 0.038], ...
        'String', ['t0 (' selectedUnit ')'], 'HorizontalAlignment', 'left');
    t0Edit = uicontrol(hFig, 'Style', 'edit', 'Units', 'normalized', 'Position', [ex, y0 + 2 * dy, ew, 0.038], ...
        'String', num2str(tDef0 * timeUnitFactor), 'HorizontalAlignment', 'left');

    uicontrol(hFig, 'Style', 'text', 'Units', 'normalized', 'Position', [px, y0 + 1 * dy, lx, 0.038], ...
        'String', ['t1 (' selectedUnit ')'], 'HorizontalAlignment', 'left');
    t1Edit = uicontrol(hFig, 'Style', 'edit', 'Units', 'normalized', 'Position', [ex, y0 + 1 * dy, ew, 0.038], ...
        'String', num2str(tDef1 * timeUnitFactor), 'HorizontalAlignment', 'left');

    useEvCb = uicontrol(hFig, 'Style', 'checkbox', 'Units', 'normalized', 'Position', [px, y0 + 0.5 * dy, 0.36, 0.038], ...
        'String', 'Event windows (±Max lag, median)', 'Value', double(events_exist), 'Visible', eventVisibility(events_exist));

    normCb = uicontrol(hFig, 'Style', 'checkbox', 'Units', 'normalized', 'Position', [px, y0 - 0.5 * dy, 0.36, 0.038], ...
        'String', 'Percent of pairs (bins sum to 100%)', 'Value', 1);

    uicontrol(hFig, 'Style', 'pushbutton', 'Units', 'normalized', 'Position', [ex, 0.02, ew, 0.06], ...
        'String', 'Analyze', 'Callback', @runAnalyze);

    set(useEvCb, 'Callback', @toggleEvUi);
    applySavedMuaCcgSettings(savedMuaCcg);
    toggleEvUi();

    function toggleEvUi(~, ~)
        on = get(useEvCb, 'Value') == 1;
        set([t0Edit, t1Edit], 'Enable', eventOnOff(~on));
    end

    function runAnalyze(~, ~)
        selA = listA.Value;
        selB = listB.Value;
        if isempty(selA) || isempty(selB)
            errordlg('Select channels in groups A and B.', 'MUA Cross-Correlation');
            return;
        end

        binDisp = str2double(get(binEdit, 'String'));
        maxLagDisp = str2double(get(maxLagEdit, 'String'));
        if ~(isfinite(binDisp) && binDisp > 0 && isfinite(maxLagDisp) && maxLagDisp > 0)
            errordlg('Bin and Max lag must be positive numbers.', 'MUA Cross-Correlation');
            return;
        end
        binSec = binDisp / timeUnitFactor;
        maxLagSec = maxLagDisp / timeUnitFactor;

        tA = mergeSpikeTimesSec(spks, selA);
        tB = mergeSpikeTimesSec(spks, selB);
        if isempty(tA) || isempty(tB)
            errordlg('No spikes in the selected A or B group.', 'MUA Cross-Correlation');
            return;
        end
        normalize = get(normCb, 'Value') == 1;
        useEv = get(useEvCb, 'Value') == 1;
        t0sec = NaN;
        t1sec = NaN;

        axes(ax);
        cla(ax);
        hold(ax, 'on');

        if useEv
            if isempty(events)
                errordlg('No events array.', 'MUA Cross-Correlation');
                return;
            end
            modeParam = struct('centers_sec', events(:), 'halfWindow_sec', maxLagSec);
            [lags_sec, cc] = muaCrossCorrelationFromBins(tA, tB, binSec, maxLagSec, normalize, 'events', modeParam);
            ccY = yAxisForCcg(cc, normalize);
            lagX = lags_sec * timeUnitFactor;
            bar(ax, lagX, ccY, 1, 'FaceColor', [0 0 0.8], 'EdgeColor', [0 0 0.6]);
            title(ax, sprintf('MUA CCG — median over %d events', numel(events)));
        else
            t0Disp = str2double(get(t0Edit, 'String'));
            t1Disp = str2double(get(t1Edit, 'String'));
            if ~(isfinite(t0Disp) && isfinite(t1Disp) && t1Disp > t0Disp)
                errordlg('Require t0 < t1 in axis units.', 'MUA Cross-Correlation');
                return;
            end
            t0sec = t0Disp / timeUnitFactor;
            t1sec = t1Disp / timeUnitFactor;
            [lags_sec, cc] = muaCrossCorrelationFromBins(tA, tB, binSec, maxLagSec, normalize, 'interval', [t0sec, t1sec]);
            ccY = yAxisForCcg(cc, normalize);
            lagX = lags_sec * timeUnitFactor;
            bar(ax, lagX, ccY, 1, 'FaceColor', [0 0 0.8], 'EdgeColor', [0 0 0.6]);
            title(ax, 'MUA CCG — pair lag histogram');
        end

        xline(ax, 0, 'r:');
        grid(ax, 'on');
        xlabel(ax, ['Lag (' selectedUnit ')']);
        ylab = 'Pairs (after edge correction)';
        if normalize
            ylab = '% of all pairs (bins sum to 100%)';
        end
        ylabel(ax, ylab);
        hold(ax, 'off');

        correlation_result.lags_sec = lags_sec(:);
        correlation_result.cc = ccY(:);
        correlation_result.lags_axis = lags_sec(:) * timeUnitFactor;
        correlation_result.normalize = normalize;
        correlation_result.cc_y_unit = yAxisUnitLabel(normalize);
        correlation_result.bin_sec = binSec;
        correlation_result.max_lag_sec = maxLagSec;
        correlation_result.channelsA = selA(:)';
        correlation_result.channelsB = selB(:)';
        correlation_result.selectedUnit = selectedUnit;
        correlation_result.timeUnitFactor = timeUnitFactor;
        correlation_result.use_event_windows = useEv;
        correlation_result.method = 'pair_lag_histogram';
        correlation_result.border_correction = 'T_minus_abs_tau';
        correlation_result.t0_sec = NaN;
        correlation_result.t1_sec = NaN;
        correlation_result.n_events = 0;
        if useEv
            correlation_result.analysis_mode = 'events_median';
            correlation_result.n_events = numel(events);
        else
            correlation_result.analysis_mode = 'interval';
            correlation_result.t0_sec = t0sec;
            correlation_result.t1_sec = t1sec;
        end
        createSaveButtons();
        saveMuaCcgSettingsToDisk();
    end

    function applySavedMuaCcgSettings(s)
        if isempty(fieldnames(s))
            return;
        end
        if isfield(s, 'BinSize_sec') && isnumeric(s.BinSize_sec) && isscalar(s.BinSize_sec) && isfinite(s.BinSize_sec) && s.BinSize_sec > 0
            set(binEdit, 'String', num2str(s.BinSize_sec * timeUnitFactor));
        end
        if isfield(s, 'MaxLag_sec') && isnumeric(s.MaxLag_sec) && isscalar(s.MaxLag_sec) && isfinite(s.MaxLag_sec) && s.MaxLag_sec > 0
            set(maxLagEdit, 'String', num2str(s.MaxLag_sec * timeUnitFactor));
        end
        if isfield(s, 't0_sec') && isnumeric(s.t0_sec) && isscalar(s.t0_sec) && isfinite(s.t0_sec)
            set(t0Edit, 'String', num2str(s.t0_sec * timeUnitFactor));
        end
        if isfield(s, 't1_sec') && isnumeric(s.t1_sec) && isscalar(s.t1_sec) && isfinite(s.t1_sec)
            set(t1Edit, 'String', num2str(s.t1_sec * timeUnitFactor));
        end
        if isfield(s, 'PercentOfPairs')
            set(normCb, 'Value', double(logical(s.PercentOfPairs)));
        end
        if isfield(s, 'UseEventWindows') && strcmp(get(useEvCb, 'Visible'), 'on')
            set(useEvCb, 'Value', double(logical(s.UseEventWindows)));
        end
        if isfield(s, 'channelsA') && isnumeric(s.channelsA)
            ch = unique(s.channelsA(:)');
            ch = ch(ch >= 1 & ch <= nSpk);
            if ~isempty(ch)
                set(listA, 'Value', ch);
            end
        end
        if isfield(s, 'channelsB') && isnumeric(s.channelsB)
            ch = unique(s.channelsB(:)');
            ch = ch(ch >= 1 & ch <= nSpk);
            if ~isempty(ch)
                set(listB, 'Value', ch);
            end
        end
    end

    function s = packMuaCcgSettingsStruct()
        s = struct();
        s.BinSize_sec = str2double(get(binEdit, 'String')) / timeUnitFactor;
        s.MaxLag_sec = str2double(get(maxLagEdit, 'String')) / timeUnitFactor;
        s.t0_sec = str2double(get(t0Edit, 'String')) / timeUnitFactor;
        s.t1_sec = str2double(get(t1Edit, 'String')) / timeUnitFactor;
        s.PercentOfPairs = logical(get(normCb, 'Value'));
        s.UseEventWindows = logical(get(useEvCb, 'Value'));
        s.channelsA = listA.Value(:)';
        s.channelsB = listB.Value(:)';
    end

    function saveMuaCcgSettingsToDisk()
        mua_ccg_settings = packMuaCcgSettingsStruct();
        save(SettingsFilepath, 'mua_ccg_settings', '-append');
    end

    function onCloseMuaCcgGui(~, ~)
        saveMuaCcgSettingsToDisk();
        delete(hFig);
    end

    function createSaveButtons()
        [mat_file_folder, original_filename, ~] = fileparts(matFilePath);
        if isempty(mat_file_folder)
            mat_file_folder = pwd;
        end
        baseName = strtrim(original_filename);
        if isempty(baseName)
            local_filename = 'mua_xcorr';
        else
            local_filename = [baseName '_mua_xcorr'];
        end

        old_buttons = findobj(hFig, 'Type', 'uicontrol', 'Style', 'pushbutton', 'Tag', 'muaXc_save_btn');
        if ~isempty(old_buttons)
            delete(old_buttons);
        end
        old_open_checkbox = findobj(hFig, 'Type', 'uicontrol', 'Style', 'checkbox', 'Tag', 'muaXc_open_after_export_cb');
        if ~isempty(old_open_checkbox)
            delete(old_open_checkbox);
        end

        % btnIcon считает высоту кнопки в пикселях (imresize); normalized даёт ~0.06 и иконка пропадает.
        uicontrol('Parent', hFig, 'Style', 'checkbox', ...
            'Tag', 'muaXc_open_after_export_cb', ...
            'String', 'Open after export', ...
            'Units', 'pixels', 'Position', [10, 48, 220, 20], ...
            'Value', 0);

        savebutton = uicontrol('Parent', hFig, 'Style', 'pushbutton', ...
            'String', 'Save Result', 'Tag', 'muaXc_save_btn', ...
            'Units', 'pixels', 'Position', [10, 10, 280, 30], ...
            'Callback', @SaveResultClb);
        btnIcon(savebutton, fullfile(getAssetsPath(), 'data-storage.png'), false);

        function SaveResultClb(~, ~)
            defaultPath = fullfile(mat_file_folder, [local_filename '_correlation']);
            [file, path, filterindex] = uiputfile( ...
                {'*.pdf', 'PDF files (*.pdf)'; ...
                 '*.eps', 'EPS files (*.eps)'; ...
                 '*.png', 'PNG files (*.png)'; ...
                 '*.*', 'All Files (*.*)'}, ...
                'Save file name', defaultPath);
            if isequal(file, 0) || isequal(path, 0)
                disp('User pressed cancel');
                return;
            end

            filename_fig = fullfile(path, file);
            switch filterindex
                case 1
                    exportgraphics(plotPanel, filename_fig, 'ContentType', 'vector');
                case 2
                    exportgraphics(plotPanel, filename_fig, 'ContentType', 'vector');
                case 3
                    exportgraphics(plotPanel, filename_fig, 'Resolution', 300);
                otherwise
                    exportgraphics(plotPanel, filename_fig);
            end
            disp(['Image saved to ', filename_fig]);

            openAfterExportCheckbox = findobj(hFig, 'Type', 'uicontrol', 'Tag', 'muaXc_open_after_export_cb');
            if ~isempty(openAfterExportCheckbox) && get(openAfterExportCheckbox, 'Value') == 1
                system(sprintf('cmd /c start "" "%s"', filename_fig));
            end

            [~, name_fig, ~] = fileparts(filename_fig);
            filename_meta = fullfile(path, [name_fig, '.meta']);
            save(filename_meta, '-struct', 'correlation_result');
            save(filename_meta, 'original_filename', '-append');
            disp(['Data saved to ', filename_meta]);
        end
    end
end

function y = yAxisForCcg(cc, doPercent)
    y = cc;
    if doPercent
        y = cc * 100;
    end
end

function s = yAxisUnitLabel(doPercent)
    s = 'pair_counts_edge_corrected';
    if doPercent
        s = 'percent_of_pairs_sum100';
    end
end

function vis = eventVisibility(events_exist)
    vis = 'off';
    if events_exist
        vis = 'on';
    end
end

function s = eventOnOff(tf)
    if tf
        s = 'on';
        return;
    end
    s = 'off';
end

function lab = channelLabelForIndex(c, channelNames)
    lab = sprintf('Ch %d', c);
    if iscell(channelNames) && c >= 1 && c <= numel(channelNames)
        entry = channelNames{c};
        if ischar(entry) || isstring(entry)
            lab = char(entry);
        end
    end
end

function tsec = mergeSpikeTimesSec(spks, chIdx)
    tsec = [];
    for k = chIdx(:)'
        ts = spks(k).tStamp;
        if isempty(ts)
            continue;
        end
        tsec = [tsec; double(ts(:)) / 1000]; %#ok<AGROW>
    end
    tsec = sort(tsec);
end

function [t0, t1] = defaultIntervalSecFromSpks(spks)
    allMs = [];
    for k = 1:numel(spks)
        ts = spks(k).tStamp;
        if isempty(ts)
            continue;
        end
        allMs = [allMs; double(ts(:))]; %#ok<AGROW>
    end
    t0 = min(allMs) / 1000;
    t1 = max(allMs) / 1000;
end
