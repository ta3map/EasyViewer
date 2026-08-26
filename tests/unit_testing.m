function unit_testing(varargin)
%UNIT_TESTING  Проверка целостности EasyViewer без GUI.
%
% Запуск:
%   unit_testing
%   unit_testing('mean_csd_figure', false)
%
% Результат:
%   tests/unit_testing.log
%   tests/out/<имя_кейса>_<n>.png

    cfg = initConfig(varargin{:});
    logCloser = onCleanup(@() fclose(cfg.logFid)); %#ok<NASGU>

    try
        %% 1. Загрузка сессии и эталонного .ev
        loadFixture(cfg);

        %% 2. Проверка загрузки
        checkLoad(cfg);

        %% 3. Детекция → запись .ev
        nDetected = runDetectEvents(cfg);

        %% 4. Чтение того же .ev
        runLoadDetectedEvents(cfg);

        %% 5. Auto measure (slope) по событиям
        nMeasured = runAnalysisAutoMeasure(cfg);

        %% 6. Mean по событиям из прочитанного .ev
        nImages = runMeanCases(cfg);

        %% 7. Итог
        global events stims ch_inxs
        logMsg(cfg, 'unit_testing: OK (detected=%d, measured=%d, mean cases=%d, images=%d, events=%d, stims=%d, channels=%d)', ...
            nDetected, nMeasured, countEnabledMeanFlags(cfg.flags), nImages, numel(events), numel(stims), numel(ch_inxs));
        logMsg(cfg, 'unit_testing end %s', datestr(now, 31));

    catch ME
        logMsg(cfg, 'FAIL: %s', ME.message);
        logMsg(cfg, 'unit_testing end %s', datestr(now, 31));
        rethrow(ME);
    end
end

% -------------------------------------------------------------------------
% Конфиг и пути
% -------------------------------------------------------------------------

function cfg = initConfig(varargin)
    p = inputParser;
    addParameter(p, 'load', true, @islogical);
    addParameter(p, 'detect_events', true, @islogical);
    addParameter(p, 'load_detected_events', true, @islogical);
    addParameter(p, 'analysis_auto_measure', true, @islogical);
    addParameter(p, 'mean_events_default', true, @islogical);
    addParameter(p, 'mean_events_xLimits', true, @islogical);
    addParameter(p, 'mean_events_baseline', true, @islogical);
    addParameter(p, 'mean_csd_figure', true, @islogical);
    addParameter(p, 'mean_stimuli_default', true, @islogical);
    addParameter(p, 'mean_stimuli_artifact', true, @islogical);
    parse(p, varargin{:});

    cfg.flags = p.Results;
    cfg.testsDir = fileparts(mfilename('fullpath'));
    cfg.root = fileparts(cfg.testsDir);
    cfg.matPath = fullfile(cfg.root, 'data_examples', 'CC_cur_90V_-70mV_zav.mat');
    cfg.evPath = fullfile(cfg.root, 'data_examples', 'CC_cur_90V_-70mV_events.ev');
    cfg.outDir = fullfile(cfg.testsDir, 'out');
    cfg.logPath = fullfile(cfg.testsDir, 'unit_testing.log');
    cfg.detectedEvPath = fullfile(cfg.outDir, 'detected_events.ev');

    addpath(cfg.root);
    addpath(genpath(fullfile(cfg.root, 'functions')));

    if exist(cfg.outDir, 'dir') ~= 7
        mkdir(cfg.outDir);
    end

    cfg.logFid = fopen(cfg.logPath, 'w');
    assert(cfg.logFid >= 0, 'Cannot open log: %s', cfg.logPath);

    logMsg(cfg, 'unit_testing start %s', datestr(now, 31));
    logMsg(cfg, 'log: %s', cfg.logPath);
    logMsg(cfg, 'out: %s', cfg.outDir);
    logMsg(cfg, 'flags: %s', flagsToString(cfg.flags));
end

% -------------------------------------------------------------------------
% Шаг 1–2: загрузка
% -------------------------------------------------------------------------

function loadFixture(cfg)
    assert(exist(cfg.matPath, 'file') == 2, 'Fixture not found: %s', cfg.matPath);
    assert(exist(cfg.evPath, 'file') == 2, 'Fixture not found: %s', cfg.evPath);

    loadGlobalSettings();
    loadZavSession(cfg.matPath);
    loadEventsFromFile(cfg.evPath, struct( ...
        'skip_callbacks', true, ...
        'skip_mode_change', true));
end

function checkLoad(cfg)
    if ~cfg.flags.load
        return
    end

    global time Fs N channelNames matFilePath hd
    global events events_exist event_indices

    assert(~isempty(time), 'time is empty');
    assert(~isempty(Fs) && Fs > 0, 'Fs invalid');
    assert(N == numel(time), 'N ~= numel(time)');
    assert(numel(channelNames) >= 1, 'no channels');
    assert(strcmp(matFilePath, cfg.matPath), 'matFilePath mismatch');
    assert(~isempty(hd), 'hd is empty');
    assert(events_exist, 'events_exist is false');
    assert(~isempty(events), 'events is empty');
    assert(numel(events) == numel(event_indices), 'events/indices size mismatch');
    assert(all(events >= time(1) & events <= time(end)), 'event times out of range');

    logMsg(cfg, '  load: OK');
end

% -------------------------------------------------------------------------
% Шаг 3: автодетекция событий
% -------------------------------------------------------------------------

function nDetected = runDetectEvents(cfg)
    nDetected = 0;
    if ~cfg.flags.detect_events
        return
    end

    global time

    params = struct( ...
        'DetectionType', 'one channel positive', ...
        'MinPeakProminence', 50, ...
        'ChPos', 1, ...
        'ChNeg', 1, ...
        'MinPeakDistance', 0.5, ...
        'SourceType', 'LFP', ...
        'detect', true, ...
        'max_peak_width', 0.05, ...
        'SearchAroundStimuli', false, ...
        'SearchWindow', 0.5, ...
        'SearchAroundDirection', 2, ...
        'UseTimeRange', false, ...
        'StartTime', time(1), ...
        'EndTime', time(end));

    [ev, Trace_out, time_res, amplitudes, widths, channels, metadata, prominences, indices, wasCanceled] = ...
        autoEventDetection(params);

    assert(~wasCanceled, 'detect_events: canceled');
    assert(~isempty(Trace_out) && ~isempty(time_res), 'detect_events: empty trace');
    assert(numel(ev) == 10, 'detect_events: expected 10 events, got %d', numel(ev));
    assert(numel(ev) == numel(amplitudes), 'detect_events: amplitudes size');
    assert(numel(ev) == numel(widths), 'detect_events: widths size');
    assert(numel(ev) == numel(prominences), 'detect_events: prominences size');
    assert(numel(ev) == numel(indices), 'detect_events: indices size');
    assert(numel(metadata) == numel(ev), 'detect_events: metadata size');
    assert(size(channels, 1) == numel(ev), 'detect_events: channels size');
    assert(all(ev >= time(1) & ev <= time(end)), 'detect_events: times out of range');
    assert(all(isfinite(amplitudes)), 'detect_events: non-finite amplitudes');
    assert(all(indices >= 1 & indices <= numel(time)), 'detect_events: bad indices');

    closeDetectWaitbars();

    global matFilePath
    [evSorted, order] = sort(ev(:));
    saveEventsToFile(evSorted, time, matFilePath, ...
        'filepath', cfg.detectedEvPath, ...
        'event_indices', indices(order), ...
        'event_amplitudes', amplitudes(order), ...
        'event_widths', widths(order), ...
        'event_prominences', prominences(order), ...
        'event_channels', channels(order, :), ...
        'event_metadata', metadata(order), ...
        'event_comments', repmat({'...'}, numel(evSorted), 1));

    info = dir(cfg.detectedEvPath);
    assert(~isempty(info) && info.bytes > 0, 'detect_events: empty ev %s', cfg.detectedEvPath);

    nDetected = numel(evSorted);
    logMsg(cfg, '  detect_events: OK (n=%d, saved %s)', nDetected, cfg.detectedEvPath);
end

function closeDetectWaitbars()
    delete(findall(0, 'Type', 'figure', 'Name', 'Event Detection'));
    delete(findall(0, 'Type', 'figure', 'Name', 'Saving Events'));
end

% -------------------------------------------------------------------------
% Шаг 4: чтение .ev после детекции
% -------------------------------------------------------------------------

function runLoadDetectedEvents(cfg)
    if ~cfg.flags.load_detected_events
        return
    end

    assert(exist(cfg.detectedEvPath, 'file') == 2, ...
        'load_detected_events: file missing %s (run detect_events first)', cfg.detectedEvPath);

    global time events events_exist event_indices lastEventsFilePath
    global event_amplitudes event_channels event_widths event_prominences event_metadata

    loadEventsFromFile(cfg.detectedEvPath, struct( ...
        'skip_callbacks', true, ...
        'skip_mode_change', true));

    assert(events_exist, 'load_detected_events: events_exist is false');
    assert(numel(events) == 10, 'load_detected_events: expected 10, got %d', numel(events));
    assert(numel(events) == numel(event_indices), 'load_detected_events: indices size');
    assert(all(events >= time(1) & events <= time(end)), 'load_detected_events: times out of range');
    assert(strcmp(lastEventsFilePath, cfg.detectedEvPath), 'load_detected_events: lastEventsFilePath');
    assert(numel(event_amplitudes) == numel(events), 'load_detected_events: amplitudes');
    assert(size(event_channels, 1) == numel(events), 'load_detected_events: channels');
    assert(numel(event_widths) == numel(events), 'load_detected_events: widths');
    assert(numel(event_prominences) == numel(events), 'load_detected_events: prominences');
    assert(numel(event_metadata) == numel(events), 'load_detected_events: metadata');

    logMsg(cfg, '  load_detected_events: OK (n=%d, %s)', numel(events), cfg.detectedEvPath);
end

% -------------------------------------------------------------------------
% Шаг 5: auto measure (slope)
% -------------------------------------------------------------------------

function nMeasured = runAnalysisAutoMeasure(cfg)
    nMeasured = 0;
    if ~cfg.flags.analysis_auto_measure
        return
    end

    global events stims time time_back time_forward Fs art_rem_settings mean_group_ch

    if isempty(art_rem_settings) || ~isstruct(art_rem_settings)
        art_rem_settings = struct('artifact_window_ms', 0, 'interp_method', 'linear');
    end
    if isempty(mean_group_ch)
        mean_group_ch = [];
    end

    centers = events(events >= time(1) & events <= time(end));
    assert(~isempty(centers), 'analysis_auto_measure: no in-range events');

    opts = struct();
    opts.centers = centers(:);
    opts.windowSize = 0.6;
    opts.baseline_rel = struct('start', -0.05, 'end', -0.005);
    opts.peak_rel = struct('start', -0.005, 'end', 0.05);
    opts.selectedCenter = 'events';
    opts.channel = 1;
    opts.slope_percent = 20;
    opts.peak_polarity = 'positive';
    opts.onset_method = 'calculated_by_slope';
    opts.onset_threshold = 3;
    opts.show_baseline = true;
    opts.show_onset = true;
    opts.show_slope = true;
    opts.show_peak = true;
    opts.time_back = 0.6;
    opts.time_forward = 0.6;
    opts.analysis_smooth_enabled = false;
    opts.analysis_smooth_span = 5;
    opts.analysis_smooth_method = 'moving';
    opts.analysis_show_raw_signal = true;
    opts.remove_artifact = false;
    opts.artifact_window_ms = art_rem_settings.artifact_window_ms;
    opts.artifact_interp_method = art_rem_settings.interp_method;

    results = autoMeasureSlopeRanges(opts);
    assert(numel(results) == numel(centers), ...
        'analysis_auto_measure: expected %d results, got %d', numel(centers), numel(results));
    assert(all(isfinite([results.slope_value])), 'analysis_auto_measure: non-finite slope');
    assert(all(isfinite([results.peak_value])), 'analysis_auto_measure: non-finite peak');
    assert(all(isfinite([results.baseline_value])), 'analysis_auto_measure: non-finite baseline');

    nMeasured = numel(results);
    logMsg(cfg, '  analysis_auto_measure: OK (n=%d, slope[1]=%.4g)', nMeasured, results(1).slope_value);
end

% -------------------------------------------------------------------------
% Шаг 6: mean-кейсы
% -------------------------------------------------------------------------

function nImages = runMeanCases(cfg)
    cases = meanCaseList(cfg);
    nImages = 0;

    for i = 1:numel(cases)
        nImages = nImages + runOneMeanCase(cfg, cases(i));
    end
end

function cases = meanCaseList(cfg)
% Каталог проверок mean. Каждый кейс: имя, источник, опции plot.
    global timeUnitFactor

    catalog = {
        'mean_events_default',   'events',  struct('buildFigure', true)
        'mean_events_xLimits',   'events',  struct('buildFigure', true, ...
            'xLimits', [-0.05, 0.2] * timeUnitFactor)
        'mean_events_baseline',  'events',  struct('buildFigure', true, ...
            'removeBaseline', true, 'showOriginalTraces', true)
        'mean_csd_figure',       'events',  struct('buildFigure', true, 'show_CSD', true)
        'mean_stimuli_default',  'stimuli', struct('buildFigure', true)
        'mean_stimuli_artifact', 'stimuli', struct('buildFigure', true, ...
            'removeArtifact', true, 'artifactWindow_ms', 2)
        };

    cases = struct('name', {}, 'source', {}, 'opts', {});
    for i = 1:size(catalog, 1)
        name = catalog{i, 1};
        if ~cfg.flags.(name)
            continue
        end
        cases(end+1) = struct( ...
            'name', name, ...
            'source', catalog{i, 2}, ...
            'opts', catalog{i, 3}); %#ok<AGROW>
    end
end

function nImages = runOneMeanCase(cfg, c)
    [fig, result] = calculateAndPlotMeanEvents(c.source, c.opts);
    assertMeanResult(c.name, c.source, result);

    nImages = 0;
    for k = 1:numel(fig)
        imgPath = fullfile(cfg.outDir, sprintf('%s_%d.png', c.name, k));
        saveMeanFigureImage(fig(k), imgPath);

        info = dir(imgPath);
        assert(~isempty(info) && info.bytes > 0, '%s: empty image %s', c.name, imgPath);

        nImages = nImages + 1;
        logMsg(cfg, '  %s image: %s (%d bytes)', c.name, imgPath, info.bytes);
        close(fig(k));
    end

    closeMeanWaitbars();
    logMsg(cfg, '  %s: OK', c.name);
end

function assertMeanResult(caseName, source, result)
    assert(isstruct(result) && ~isempty(result), '%s: empty result', caseName);
    assert(isfield(result, 'meanData') && ~isempty(result.meanData), '%s: no meanData', caseName);
    assert(all(isfinite(result.meanData(:))), '%s: non-finite meanData', caseName);
    assert(isfield(result, 'timeAxis') && numel(result.timeAxis) == size(result.meanData, 1), ...
        '%s: timeAxis mismatch', caseName);
    assert(strcmp(result.sourceType, source), '%s: sourceType mismatch', caseName);
    assert(size(result.meanData, 2) >= 1, '%s: no channels in meanData', caseName);
end

function closeMeanWaitbars()
    delete(findall(0, 'Type', 'figure', 'Name', 'Mean Events'));
end

% -------------------------------------------------------------------------
% Лог
% -------------------------------------------------------------------------

function logMsg(cfg, fmt, varargin)
    line = sprintf(fmt, varargin{:});
    fprintf('%s\n', line);
    fprintf(cfg.logFid, '%s\n', line);
end

function s = flagsToString(flags)
    names = fieldnames(flags);
    parts = cell(numel(names), 1);
    for i = 1:numel(names)
        parts{i} = sprintf('%s=%d', names{i}, flags.(names{i}));
    end
    s = strjoin(parts, ', ');
end

function n = countEnabledMeanFlags(flags)
    names = {
        'mean_events_default'
        'mean_events_xLimits'
        'mean_events_baseline'
        'mean_csd_figure'
        'mean_stimuli_default'
        'mean_stimuli_artifact'
        };
    n = 0;
    for i = 1:numel(names)
        n = n + double(flags.(names{i}));
    end
end
