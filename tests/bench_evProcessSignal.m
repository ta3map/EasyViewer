function bench_evProcessSignal(varargin)
%BENCH_EVPROCESSSIGNAL Correctness + speed gate for native evProcessSignal MEX.
%
%   bench_evProcessSignal
%   bench_evProcessSignal('minSpeedup', 1.05)
%
% On pass: creates functions/evProcessSignal.enabled
% On fail: deletes that file and errors.

    p = inputParser;
    addParameter(p, 'nIter', 30, @(x) isnumeric(x) && isscalar(x) && x >= 1);
    addParameter(p, 'tolerance', 1e-9, @(x) isnumeric(x) && isscalar(x) && x > 0);
    addParameter(p, 'minSpeedup', 1.0, @(x) isnumeric(x) && isscalar(x) && x > 0);
    parse(p, varargin{:});

    cfg = initBenchConfig();
    cfg.nIter = p.Results.nIter;
    cfg.tolerance = p.Results.tolerance;
    cfg.minSpeedup = p.Results.minSpeedup;
    logCloser = onCleanup(@() fclose(cfg.logFid)); %#ok<NASGU>

    disableEvProcessSignal();
    buildEvMex();

    assert(exist('evProcessSignal', 'file') == 3, 'evProcessSignal MEX build failed.');

    logMsg(cfg, 'bench_evProcessSignal start %s', datestr(now, 31));
    logMsg(cfg, 'fixture: %s', cfg.matPath);
    logMsg(cfg, 'nIter=%d tolerance=%.1e minSpeedup=%.2f', cfg.nIter, cfg.tolerance, cfg.minSpeedup);

    cfg = loadBenchFixture(cfg);
    cases = benchCaseList();
    minSpeedup = inf;
    gateSpeedup = inf;

    for i = 1:numel(cases)
        s = runBenchCase(cfg, cases(i));
        minSpeedup = min(minSpeedup, s);
        if cases(i).gate
            gateSpeedup = min(gateSpeedup, s);
        end
    end

    if gateSpeedup < cfg.minSpeedup
        disableEvProcessSignal();
        error('bench_evProcessSignal: gate speedup %.2fx < required %.2fx', gateSpeedup, cfg.minSpeedup);
    end

    enableEvProcessSignal();
    logMsg(cfg, 'PASS: gate speedup=%.2fx (all min=%.2fx), enabled %s', gateSpeedup, minSpeedup, evProcessSignalFlagPath());
    logMsg(cfg, 'bench_evProcessSignal end %s', datestr(now, 31));
end

function cfg = initBenchConfig()
    cfg.testsDir = fileparts(mfilename('fullpath'));
    cfg.root = fileparts(cfg.testsDir);
    cfg.fixturesDir = fullfile(cfg.testsDir, 'fixtures');
    cfg.matPath = fullfile(cfg.root, 'data_examples', 'CC_cur_90V_-70mV_zav.mat');
    cfg.logPath = fullfile(cfg.testsDir, 'bench_evProcessSignal.log');

    addpath(cfg.root);
    addpath(genpath(fullfile(cfg.root, 'functions')));
    addpath(cfg.fixturesDir);

    cfg.logFid = fopen(cfg.logPath, 'w');
    assert(cfg.logFid >= 0, 'Cannot open log: %s', cfg.logPath);
    logMsg(cfg, 'log: %s', cfg.logPath);
end

function cfg = loadBenchFixture(cfg)
    assert(exist(cfg.matPath, 'file') == 2, 'Fixture not found: %s', cfg.matPath);
    loadGlobalSettings();
    loadZavSession(cfg.matPath);

    global filterSettings filter_avaliable ch_inxs Fs newFs
    filterSettings.filterType = 'highpass';
    filterSettings.freqLow = 10;
    filterSettings.freqHigh = 50;
    filterSettings.order = 4;
    filterSettings.filterEnabled = true;
    filterSettings.smoothSpan = 7;
    filterSettings.smoothMethod = 'moving';
    filterSettings.smoothEnabled = true;
    filter_avaliable = false(1, numel(filter_avaliable));
    filter_avaliable(ch_inxs) = true;
    newFs = min(Fs, 1000);
    cfg.Fs = Fs;
    cfg.newFs = newFs;
end

function cases = benchCaseList()
    cases = struct( ...
        'name', {'filter_movmean', 'filter_median', 'resample_down', 'viewer_pipeline'}, ...
        'fn', {@caseFilterMovmean, @caseFilterMedian, @caseResampleDown, @caseViewerPipeline}, ...
        'gate', {false, false, false, true});
end

function speedup = runBenchCase(cfg, c)
    [yRef, yMex, meta, payload] = c.fn(cfg);
    errMax = max(abs(yRef(:) - yMex(:)));
    assert(errMax <= cfg.tolerance, '%s: max err %.3e > tol %.1e', c.name, errMax, cfg.tolerance);

    tRef = medianTime(@() c.fn(cfg, payload, 'ref_only'), cfg.nIter);
    tMex = medianTime(@() c.fn(cfg, payload, 'mex_only'), cfg.nIter);
    speedup = tRef / tMex;

    logMsg(cfg, '  %s: size=%s err=%.3e t_ref=%.3f ms t_mex=%.3f ms speedup=%.2fx (%s)', ...
        c.name, sizeStr(meta.size), errMax, 1e3 * tRef, 1e3 * tMex, speedup, meta.note);
end

function [yRef, yMex, meta, payload] = caseFilterMovmean(cfg, payload, mode)
    if nargin < 2
        data = loadViewerSlice(cfg);
        s = benchFilterSettings('moving', 7);
        payload = struct('data', data, 's', s);
        yRef = applyFilter_reference(data, s, cfg.newFs);
        yMex = applyFilterMex(data, s, cfg.newFs);
        meta.size = size(data);
        meta.note = 'highpass+movmean';
        return;
    end
    data = payload.data;
    s = payload.s;
    meta.size = size(data);
    meta.note = 'highpass+movmean';
    if strcmp(mode, 'ref_only')
        yRef = applyFilter_reference(data, s, cfg.newFs);
    else
        yRef = applyFilterMex(data, s, cfg.newFs);
    end
    yMex = yRef;
end

function [yRef, yMex, meta, payload] = caseFilterMedian(cfg, payload, mode)
    if nargin < 2
        data = loadViewerSlice(cfg);
        s = benchFilterSettings('median', 9);
        payload = struct('data', data, 's', s);
        yRef = applyFilter_reference(data, s, cfg.newFs);
        yMex = applyFilterMex(data, s, cfg.newFs);
        meta.size = size(data);
        meta.note = 'highpass+medfilt1';
        return;
    end
    data = payload.data;
    s = payload.s;
    meta.size = size(data);
    meta.note = 'highpass+medfilt1';
    if strcmp(mode, 'ref_only')
        yRef = applyFilter_reference(data, s, cfg.newFs);
    else
        yRef = applyFilterMex(data, s, cfg.newFs);
    end
    yMex = yRef;
end

function [yRef, yMex, meta, payload] = caseResampleDown(cfg, payload, mode)
    if nargin < 2
        data = loadViewerSlice(cfg);
        payload = struct('data', data);
        yRef = resample1_reference(data, round(cfg.newFs), cfg.Fs);
        yMex = resample1Mex(data, round(cfg.newFs), cfg.Fs);
        meta.size = size(data);
        meta.note = sprintf('resample %d->%d Hz', cfg.Fs, cfg.newFs);
        return;
    end
    data = payload.data;
    meta.size = size(data);
    meta.note = sprintf('resample %d->%d Hz', cfg.Fs, cfg.newFs);
    if strcmp(mode, 'ref_only')
        yRef = resample1_reference(data, round(cfg.newFs), cfg.Fs);
    else
        yRef = resample1Mex(data, round(cfg.newFs), cfg.Fs);
    end
    yMex = yRef;
end

function [yRef, yMex, meta, payload] = caseViewerPipeline(cfg, payload, mode)
    if nargin < 2
        [data, chMask] = loadViewerSliceWithMask(cfg);
        s = benchFilterSettings('moving', 7);
        payload = struct('data', data, 's', s, 'chMask', chMask);
        yRef = runViewerPipelineReference(data, s, chMask, cfg);
        yMex = runViewerPipelineMex(data, s, chMask, cfg);
        meta.size = size(data);
        meta.note = 'filter subset + resample all';
        return;
    end
    data = payload.data;
    s = payload.s;
    chMask = payload.chMask;
    meta.size = size(data);
    meta.note = 'filter subset + resample all';
    if strcmp(mode, 'ref_only')
        yRef = runViewerPipelineReference(data, s, chMask, cfg);
    else
        yRef = runViewerPipelineMex(data, s, chMask, cfg);
    end
    yMex = yRef;
end

function y = runViewerPipelineReference(data, filterSettings, chMask, cfg)
    y = data;
    cols = find(chMask);
    y(:, cols) = applyFilter_reference(y(:, cols), filterSettings, cfg.newFs);
    if cfg.Fs > cfg.newFs
        y = resample1_reference(y, round(cfg.newFs), cfg.Fs);
    end
end

function y = runViewerPipelineMex(data, filterSettings, chMask, cfg)
    y = data;
    cols = find(chMask);
    y(:, cols) = applyFilterMex(y(:, cols), filterSettings, cfg.newFs);
    if cfg.Fs > cfg.newFs
        y = resample1Mex(y, round(cfg.newFs), cfg.Fs);
    end
end

function data = loadViewerSlice(cfg)
    [data, ~] = loadViewerSliceWithMask(cfg);
end

function [data, chMask] = loadViewerSliceWithMask(cfg)
    global lfp_file time chosen_time_interval time_back ch_inxs mean_group_ch filter_avaliable Fs scalingCoefficients
    cfg.Fs = Fs;
    plot_time_interval = chosen_time_interval;
    plot_time_interval(1) = plot_time_interval(1) - time_back;
    [row_start, row_end] = timeWindowIndices(time, plot_time_interval(1), plot_time_interval(2));
    lfpDims = lfp_size(lfp_file);
    nCh = lfpDims(2);
    mg = false(1, nCh);
    if ~isempty(mean_group_ch) && any(mean_group_ch(:))
        rawMg = mean_group_ch(:);
        if islogical(rawMg)
            n = min(numel(rawMg), nCh);
            mg(1:n) = rawMg(1:n);
        else
            idx = rawMg(isfinite(rawMg) & rawMg >= 1 & rawMg <= nCh);
            mg(idx) = true;
        end
    end
    chNeed = unique(ch_inxs(:)', 'stable');
    chNeed = chNeed(chNeed >= 1 & chNeed <= nCh);
    cols = unique([chNeed, find(mg)], 'stable');
    local_lfp = lfp_file.lfp(row_start:row_end, cols);
    if any(mg)
        meanLocal = ismember(cols, find(mg));
        local_lfp(:, meanLocal) = local_lfp(:, meanLocal) - mean(local_lfp(:, meanLocal), 2);
    end
    [~, chLocal] = ismember(ch_inxs(:), cols);
    m_coef = np_flatten(scalingCoefficients(ch_inxs));
    data = local_lfp(:, chLocal) .* m_coef(:)';
    chMask = filter_avaliable(ch_inxs);
end

function s = benchFilterSettings(method, span)
    s.filterType = 'highpass';
    s.freqLow = 10;
    s.freqHigh = 50;
    s.order = 4;
    s.filterEnabled = true;
    s.smoothSpan = span;
    s.smoothMethod = method;
    s.smoothEnabled = true;
end

function t = medianTime(fn, nIter)
    times = zeros(nIter, 1);
    fn();
    for k = 1:nIter
        tic;
        fn();
        times(k) = toc;
    end
    t = median(times);
end

function s = sizeStr(sz)
    s = sprintf('%dx%d', sz(1), sz(2));
end

function logMsg(cfg, fmt, varargin)
    line = sprintf(fmt, varargin{:});
    fprintf('%s\n', line);
    fprintf(cfg.logFid, '%s\n', line);
end

function enableEvProcessSignal()
    fid = fopen(evProcessSignalFlagPath(), 'w');
    assert(fid >= 0, 'Cannot write %s', evProcessSignalFlagPath());
    fprintf(fid, 'enabled %s\n', datestr(now, 31));
    fclose(fid);
end

function disableEvProcessSignal()
    p = evProcessSignalFlagPath();
    if isfile(p)
        delete(p);
    end
end

function p = evProcessSignalFlagPath()
    p = fullfile(fileparts(which('applyFilter')), 'evProcessSignal.enabled');
end
