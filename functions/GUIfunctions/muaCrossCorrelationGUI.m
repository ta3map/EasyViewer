function muaCrossCorrelationGUI()
    global spks events events_exist channelNames timeUnitFactor selectedUnit matFilePath SettingsFilepath lfpVar std_coef

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

    muaCoefInit = std_coef;
    if ~(isscalar(muaCoefInit) && isfinite(muaCoefInit) && muaCoefInit >= 0)
        muaCoefInit = 3;
    end

    hFig = figure('Name', 'MUA Cross-Correlation', 'NumberTitle', 'off', ...
        'Position', [120, 120, 1040, 540], 'Resize', 'on', ...
        'MenuBar', 'none', 'ToolBar', 'figure', ...
        'Tag', figTag);
    hFig.CloseRequestFcn = @onCloseMuaCcgGui;

    lm = 0.02;
    lw = 0.30;
    lblW = 0.12;
    edL = 0.15;
    edW = 0.16;
    rowH = 0.032;

    rightWrap = uipanel('Parent', hFig, 'Units', 'normalized', 'Position', [0.33, 0.03, 0.64, 0.94], ...
        'BorderType', 'none', 'BackgroundColor', get(hFig, 'Color'), 'Tag', 'muaXc_rightWrap');
    plotPanel = uipanel('Parent', rightWrap, 'Units', 'normalized', 'Position', [0.04, 0.03, 0.92, 0.72], ...
        'BorderType', 'none', 'BackgroundColor', get(hFig, 'Color'), 'Tag', 'muaXc_plotPanel');
    ax = axes('Parent', plotPanel, 'Units', 'normalized', 'Position', [0.08, 0.11, 0.86, 0.82]);

    ccfExplainText = uicontrol('Parent', rightWrap, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.04, 0.84, 0.92, 0.14], 'HorizontalAlignment', 'left', 'FontSize', 9, ...
        'String', ['Cross-correlogram (CCG): binned pairwise lag histogram between spikes in groups A and B. ' ...
        'Counts are edge-corrected (divided by T-|tau|). ' ...
        'With Percent of pairs checked, Y is % of pairs (histogram sums to 100%). ' ...
        'Optional surrogate: mean CCG after random circular time shifts of group B within the analysis window(s).']);

    peakSummaryLine = 'Peak: -';
    peakResultText = uicontrol('Parent', rightWrap, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.04, 0.76, 0.92, 0.06], 'HorizontalAlignment', 'left', 'FontSize', 10, ...
        'FontWeight', 'bold', 'String', 'Peak: -');

    uicontrol(hFig, 'Style', 'text', 'Units', 'normalized', 'Position', [lm, 0.948, lw, 0.024], ...
        'String', 'Channels A', 'HorizontalAlignment', 'left');
    idxHas = find(hasAny);
    vPickA = idxHas(1);
    vPickB = idxHas(min(2, numel(idxHas)));

    listA = uicontrol(hFig, 'Style', 'listbox', 'Units', 'normalized', 'Position', [lm, 0.778, lw, 0.165], ...
        'String', chLabels, 'Min', 0, 'Max', nSpk, 'Value', vPickA);

    uicontrol(hFig, 'Style', 'text', 'Units', 'normalized', 'Position', [lm, 0.748, lw, 0.024], ...
        'String', 'Channels B', 'HorizontalAlignment', 'left');
    listB = uicontrol(hFig, 'Style', 'listbox', 'Units', 'normalized', 'Position', [lm, 0.573, lw, 0.145], ...
        'String', chLabels, 'Min', 0, 'Max', nSpk, 'Value', vPickB);

    yStep = rowH + 0.01;
    yMua = 0.508;
    yBin = yMua - yStep;
    yMaxLag = yBin - yStep;
    yt0 = yMaxLag - yStep;
    yt1 = yt0 - yStep;

    uicontrol(hFig, 'Style', 'text', 'Units', 'normalized', 'Position', [lm, yMua, lblW, rowH], ...
        'String', 'MUA Threshold (n*STD)', 'HorizontalAlignment', 'left');
    muaCoefEdit = uicontrol(hFig, 'Style', 'edit', 'Units', 'normalized', 'Position', [edL, yMua, edW, rowH], ...
        'String', num2str(muaCoefInit), 'HorizontalAlignment', 'left');

    uicontrol(hFig, 'Style', 'text', 'Units', 'normalized', 'Position', [lm, yBin, lblW, rowH], ...
        'String', ['Bin (' selectedUnit ')'], 'HorizontalAlignment', 'left');
    binEdit = uicontrol(hFig, 'Style', 'edit', 'Units', 'normalized', 'Position', [edL, yBin, edW, rowH], ...
        'String', num2str(0.01 * timeUnitFactor), 'HorizontalAlignment', 'left');

    uicontrol(hFig, 'Style', 'text', 'Units', 'normalized', 'Position', [lm, yMaxLag, lblW, rowH], ...
        'String', ['Max lag (' selectedUnit ')'], 'HorizontalAlignment', 'left');
    maxLagEdit = uicontrol(hFig, 'Style', 'edit', 'Units', 'normalized', 'Position', [edL, yMaxLag, edW, rowH], ...
        'String', num2str(1 * timeUnitFactor), 'HorizontalAlignment', 'left');

    uicontrol(hFig, 'Style', 'text', 'Units', 'normalized', 'Position', [lm, yt0, lblW, rowH], ...
        'String', ['t start (' selectedUnit ')'], 'HorizontalAlignment', 'left');
    t0Edit = uicontrol(hFig, 'Style', 'edit', 'Units', 'normalized', 'Position', [edL, yt0, edW, rowH], ...
        'String', num2str(tDef0 * timeUnitFactor), 'HorizontalAlignment', 'left');

    uicontrol(hFig, 'Style', 'text', 'Units', 'normalized', 'Position', [lm, yt1, lblW, rowH], ...
        'String', ['t end (' selectedUnit ')'], 'HorizontalAlignment', 'left');
    t1Edit = uicontrol(hFig, 'Style', 'edit', 'Units', 'normalized', 'Position', [edL, yt1, edW, rowH], ...
        'String', num2str(tDef1 * timeUnitFactor), 'HorizontalAlignment', 'left');

    useEvCb = uicontrol(hFig, 'Style', 'checkbox', 'Units', 'normalized', 'Position', [lm, 0.298, 0.30, 0.032], ...
        'String', 'Event windows (±Max lag, median)', 'Value', double(events_exist), 'Visible', eventVisibility(events_exist));

    normCb = uicontrol(hFig, 'Style', 'checkbox', 'Units', 'normalized', 'Position', [lm, 0.258, 0.30, 0.032], ...
        'String', 'Percent of pairs (bins sum to 100%)', 'Value', 1);

    surrogateBaselineCb = uicontrol(hFig, 'Style', 'checkbox', 'Units', 'normalized', 'Position', [lm, 0.218, 0.30, 0.034], ...
        'String', 'Surrogate baseline (mean, circular shift B)', 'Value', 0);

    showPeakCb = uicontrol(hFig, 'Style', 'checkbox', 'Units', 'normalized', 'Position', [lm, 0.182, 0.30, 0.030], ...
        'String', 'Show peak', 'Value', 1, 'Callback', @onShowPeakChanged);

    uicontrol(hFig, 'Style', 'pushbutton', 'Units', 'normalized', 'Position', [lm, 0.132, lw, 0.044], ...
        'String', 'Analyze', 'Callback', @runAnalyze);

    uicontrol(hFig, 'Style', 'text', 'Units', 'normalized', 'Position', [lm, 0.108, lw, 0.016], ...
        'String', '-----', 'HorizontalAlignment', 'center', 'Tag', 'muaXc_sep', 'Visible', 'off');

    set(useEvCb, 'Callback', @toggleEvUi);
    applySavedMuaCcgSettings(savedMuaCcg);
    toggleEvUi();

    function toggleEvUi(~, ~)
        on = get(useEvCb, 'Value') == 1;
        set([t0Edit, t1Edit], 'Enable', eventOnOff(~on));
    end

    function onShowPeakChanged(~, ~)
        showPeak = get(showPeakCb, 'Value') == 1;
        delete(findobj(ax, 'Type', 'line', 'Tag', 'muaXc_peak'));
        if ~showPeak
            set(peakResultText, 'String', 'Peak: -');
            return;
        end
        if isfield(correlation_result, 'peak_cc') && isnumeric(correlation_result.peak_cc) && isscalar(correlation_result.peak_cc) && isfinite(correlation_result.peak_cc)
            hold(ax, 'on');
            plot(ax, correlation_result.peak_lag_axis, correlation_result.peak_cc, 'r.', 'MarkerSize', 12, 'LineWidth', 1, 'Tag', 'muaXc_peak');
            hold(ax, 'off');
        end
        set(peakResultText, 'String', peakSummaryLine);
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

        muaCoef = str2double(get(muaCoefEdit, 'String'));
        if ~(isscalar(muaCoef) && isfinite(muaCoef) && muaCoef >= 0)
            errordlg('MUA Threshold (n*STD) must be a finite number ≥ 0.', 'MUA Cross-Correlation');
            return;
        end

        tA = mergeSpikeTimesSec(spks, selA, muaCoef, lfpVar);
        tB = mergeSpikeTimesSec(spks, selB, muaCoef, lfpVar);
        if isempty(tA) || isempty(tB)
            errordlg('No spikes in the selected A or B group.', 'MUA Cross-Correlation');
            return;
        end
        normalize = get(normCb, 'Value') == 1;
        useEv = get(useEvCb, 'Value') == 1;
        t0sec = NaN;
        t1sec = NaN;

        hWaitFig = waitbar(0, 'MUA CCG: starting...', 'Name', 'MUA Cross-Correlation');
        figure(hWaitFig);
        waitbar(0.08, hWaitFig, 'MUA CCG: main histogram...');

        if useEv
            if isempty(events)
                closeMuaWaitbarIfValid(hWaitFig);
                errordlg('No events array.', 'MUA Cross-Correlation');
                return;
            end
            modeParam = struct('centers_sec', events(:), 'halfWindow_sec', maxLagSec);
            modeStr = 'events';
            [lags_sec, cc] = muaCrossCorrelationFromBins(tA, tB, binSec, maxLagSec, normalize, modeStr, modeParam);
            plotTitle = sprintf('MUA CCG - median over %d events', numel(events));
            waitbar(0.22, hWaitFig, 'MUA CCG: main histogram done');
        else
            t0Disp = str2double(get(t0Edit, 'String'));
            t1Disp = str2double(get(t1Edit, 'String'));
            if ~(isfinite(t0Disp) && isfinite(t1Disp) && t1Disp > t0Disp)
                closeMuaWaitbarIfValid(hWaitFig);
                errordlg('Require t start < t end in axis units.', 'MUA Cross-Correlation');
                return;
            end
            t0sec = t0Disp / timeUnitFactor;
            t1sec = t1Disp / timeUnitFactor;
            modeParam = [t0sec, t1sec];
            modeStr = 'interval';
            [lags_sec, cc] = muaCrossCorrelationFromBins(tA, tB, binSec, maxLagSec, normalize, modeStr, modeParam);
            plotTitle = 'MUA CCG - pair lag histogram';
            waitbar(0.22, hWaitFig, 'MUA CCG: main histogram done');
        end
        ccY = yAxisForCcg(cc, normalize);
        lagX = lags_sec * timeUnitFactor;
        showSur = get(surrogateBaselineCb, 'Value') == 1;
        surrogateMeanY = [];
        nSurrogateRep = 50;
        if showSur
            surSum = zeros(size(cc));
            for r = 1:nSurrogateRep
                if useEv
                    tBs = surrogateCircularShiftBUnionEvents(tB, events(:), maxLagSec);
                else
                    tBs = surrogateCircularShiftBInInterval(tB, t0sec, t1sec);
                end
                [~, ccR] = muaCrossCorrelationFromBins(tA, tBs, binSec, maxLagSec, normalize, modeStr, modeParam);
                surSum = surSum + yAxisForCcg(ccR, normalize);
                waitbar(0.22 + 0.74 * r / nSurrogateRep, hWaitFig, sprintf('Surrogate baseline %d / %d', r, nSurrogateRep));
            end
            surrogateMeanY = surSum(:) / nSurrogateRep;
        end
        waitbar(0.97, hWaitFig, 'MUA CCG: drawing...');
        closeMuaWaitbarIfValid(hWaitFig);
        figure(hFig);
        axes(ax);
        cla(ax);
        hold(ax, 'on');
        hBar = bar(ax, lagX(:), ccY(:), 1, 'FaceColor', [0 0 0.8], 'EdgeColor', [0 0 0.6]);
        hBar.FaceAlpha = 0.92;
        if showSur
            hSurBar = bar(ax, lagX(:), surrogateMeanY, 1, 'FaceColor', [0.72 0.72 0.72], 'EdgeColor', [0.5 0.5 0.5]);
            hSurBar.FaceAlpha = 0.78;
        end
        title(ax, plotTitle);

        xline(ax, 0, 'r:');
        grid(ax, 'on');
        xlabel(ax, ['Lag (' selectedUnit ')']);
        ylab = 'Pairs (after edge correction)';
        if normalize
            ylab = '% of all pairs (bins sum to 100%)';
        end
        ylabel(ax, ylab);

        yStack = [double(ccY(:)); double(surrogateMeanY(:))];
        yLo = min(yStack);
        yHi = max(yStack);
        padY = 0.06 * max(yHi - yLo, max(abs(yHi), abs(yLo)) * 0.02 + sqrt(eps));
        ylim(ax, [yLo - padY, yHi + padY]);

        [peakVal, ixPeak] = max(ccY(:));
        peakLagSec = lags_sec(ixPeak);
        peakLagDisp = peakLagSec * timeUnitFactor;
        showPeak = get(showPeakCb, 'Value') == 1;
        if normalize
            peakSummaryLine = sprintf('Peak: %.5g %% of pairs at lag %.5g %s', peakVal, peakLagDisp, selectedUnit);
        else
            peakSummaryLine = sprintf('Peak: %.5g (edge-corrected counts) at lag %.5g %s', peakVal, peakLagDisp, selectedUnit);
        end
        if showPeak
            plot(ax, peakLagDisp, peakVal, 'r.', 'MarkerSize', 12, 'LineWidth', 1, 'Tag', 'muaXc_peak');
            set(peakResultText, 'String', peakSummaryLine);
        else
            set(peakResultText, 'String', 'Peak: -');
        end
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
        correlation_result.peak_cc = peakVal;
        correlation_result.peak_lag_sec = peakLagSec;
        correlation_result.peak_lag_axis = peakLagDisp;
        correlation_result.surrogate_baseline = showSur;
        correlation_result.surrogate_n = nSurrogateRep * double(showSur);
        correlation_result.surrogate_mean_cc = surrogateMeanY;
        correlation_result.surrogate_method = 'circular_shift_B';
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
        if isfield(s, 'ShowSurrogateBaseline')
            set(surrogateBaselineCb, 'Value', double(logical(s.ShowSurrogateBaseline)));
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
        s.ShowSurrogateBaseline = logical(get(surrogateBaselineCb, 'Value'));
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
        sepObj = findobj(hFig, 'Type', 'uicontrol', 'Tag', 'muaXc_sep');
        if ~isempty(sepObj)
            set(sepObj, 'Visible', 'on');
        end

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

        uicontrol('Parent', hFig, 'Style', 'checkbox', ...
            'Tag', 'muaXc_open_after_export_cb', ...
            'String', 'Open after export', ...
            'Units', 'normalized', 'Position', [lm, 0.072, lw, 0.028], ...
            'Value', 0);

        savebutton = uicontrol('Parent', hFig, 'Style', 'pushbutton', ...
            'String', 'Save Result', 'Tag', 'muaXc_save_btn', ...
            'Units', 'normalized', 'Position', [lm, 0.018, lw, 0.050], ...
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

function closeMuaWaitbarIfValid(h)
    if nargin < 1 || isempty(h)
        return;
    end
    if isgraphics(h) && isvalid(h)
        close(h);
    end
end

function tBs = surrogateCircularShiftBInInterval(tB_sec, t0, t1)
    tBs = tB_sec(:);
    span = t1 - t0;
    mask = tBs >= t0 & tBs <= t1;
    tv = tBs(mask);
    if numel(tv) < 2
        return;
    end
    off = rand * span;
    tv2 = mod(tv - t0 + off, span) + t0;
    tBs(mask) = sort(tv2);
end

function tBs = surrogateCircularShiftBUnionEvents(tB_sec, centers_sec, halfWindow_sec)
    tBs = tB_sec(:);
    u0 = min(centers_sec) - halfWindow_sec;
    u1 = max(centers_sec) + halfWindow_sec;
    mask = tBs >= u0 & tBs <= u1;
    tv = tBs(mask);
    if numel(tv) < 2
        return;
    end
    span = u1 - u0;
    off = rand * span;
    tv2 = mod(tv - u0 + off, span) + u0;
    tBs(mask) = sort(tv2);
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
    base = sprintf('Ch %d', c);
    if iscell(channelNames) && c >= 1 && c <= numel(channelNames)
        entry = channelNames{c};
        if ischar(entry) || isstring(entry)
            base = char(entry);
        end
    end
    lab = sprintf('%d: %s', c, base);
end

function tsec = mergeSpikeTimesSec(spks, chIdx, muaCoef, lfpVarVec)
    tsec = [];
    for k = chIdx(:)'
        ts = spks(k).tStamp;
        if isempty(ts)
            continue;
        end
        ts = double(ts(:));
        if isvector(lfpVarVec) && numel(lfpVarVec) >= k && isfield(spks(k), 'ampl') && ~isempty(spks(k).ampl)
            lv = double(lfpVarVec(k));
            if isfinite(muaCoef) && muaCoef >= 0 && isfinite(lv) && lv > 0
                a = double(spks(k).ampl(:));
                n = min(numel(ts), numel(a));
                ts = ts(1:n);
                a = a(1:n);
                ts = ts(abs(a) >= lv * muaCoef);
            end
        end
        if isempty(ts)
            continue;
        end
        tsec = [tsec; ts / 1000]; %#ok<AGROW>
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
