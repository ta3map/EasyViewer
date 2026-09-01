function [calculation_result, plotParams] = calculateMeanEvents(sourceType, opts)
if nargin < 1
    sourceType = 'events';
end
if nargin < 2
    opts = struct();
end

global Fs N time ch_inxs
global shiftCoeff
global lfp_file hd spks
global matFilePath timeUnitFactor
global events newFs time_back time_forward
global std_coef binsize
global visualSettings
global csd_avaliable filter_avaliable filterSettings
global channelTable csd_smooth_coef csd_contrast_coef
global lfpVar mean_group_ch
global art_rem_settings stims
global t_mean_profile wb matFileName evfilename

if strcmp(sourceType, 'stimuli')
    params.timePoints = stims;
    if isempty(evfilename) || strcmp(evfilename, '')
        if ~isempty(matFileName) && ~strcmp(matFileName, '')
            local_evfilename = matFileName;
        else
            local_evfilename = 'stimuli';
        end
    else
        local_evfilename = evfilename;
    end
else
    params.timePoints = events;
    local_evfilename = evfilename;
end

channelSettings = buildChannelSettingsTable();
params.sourceType = sourceType;
params.hd = hd;
params.channelSettings = channelSettings;
params.Fs = Fs;

if isfield(opts, 'meanWindow')
    params.meanWindow = opts.meanWindow;
elseif isfield(opts, 'xLimits') && ~isempty(opts.xLimits)
    xLimitsSeconds = opts.xLimits / timeUnitFactor;
    params.meanWindow = max(abs(xLimitsSeconds(1)), abs(xLimitsSeconds(2))) * 2;
else
    params.meanWindow = 2;
end

if isfield(opts, 'Channel') && ~isempty(opts.Channel)
    ch_sel = round(opts.Channel);
    read_ch = ch_sel;
    read_mean_group = false(1, numel(hd.recChNames));
else
    read_ch = ch_inxs;
    read_mean_group = mean_group_ch;
end
readProgress = struct();
if ~isempty(wb) && isvalid(wb)
    readProgress.wb = wb;
    readProgress.fracLo = 0.05;
    readProgress.fracHi = 0.70;
end
params.lfp_file = lfp_file;
params.N = N;
params.read_ch = read_ch;
params.filter_enabled = filter_avaliable;
params.newFs = newFs;
params.filterSettings = filterSettings;
params.stims = stims;
params.artifact_interp_method = art_rem_settings.interp_method;
params.progress = readProgress;
params.wb = wb;
params.showWaitbar = isempty(wb) || ~isvalid(wb);
params.binsize = binsize;
params.spk_threshold = std_coef;
params.spks = spks;
params.shiftCoeff = shiftCoeff;
params.titlename = local_evfilename;
params.show_spikes = visualSettings.show_spikes;
params.ch_inxs = ch_inxs;
if isfield(opts, 'Channel') && ~isempty(opts.Channel)
    ch_sel = round(opts.Channel);
    params.channelSettings = channelSettings(ch_sel, :);
    params.ch_inxs = 1;
    params.ch_labels = hd.recChNames(ch_sel);
    params.csd_active = csd_avaliable(ch_sel);
    params.mean_group_ch = false(1, numel(hd.recChNames));
    params.channel_index_original = ch_sel;
else
    params.csd_active = csd_avaliable(ch_inxs);
    params.mean_group_ch = mean_group_ch;
end
params.time = time;
params.show_CSD = visualSettings.show_CSD;
params.csd_smooth_coef = csd_smooth_coef;
params.csd_contrast_coef = csd_contrast_coef;
params.timeUnitFactor = timeUnitFactor;
params.lfpVar = lfpVar;
params.t_profile = t_mean_profile;

if isfield(opts, 'removeArtifact')
    params.remove_artifact = strcmp(sourceType, 'stimuli') && logical(opts.removeArtifact);
    if isfield(opts, 'artifactWindow_ms')
        artifact_window_ms = opts.artifactWindow_ms;
    else
        artifact_window_ms = art_rem_settings.artifact_window_ms;
    end
else
    params.remove_artifact = strcmp(sourceType, 'stimuli') && art_rem_settings.artifact_window_ms > 0;
    artifact_window_ms = art_rem_settings.artifact_window_ms;
end
if isfield(opts, 'artifactWindow_ms')
    artifact_window_ms = opts.artifactWindow_ms;
end
params.artifact_window_ms = artifact_window_ms;
params.autoScale = isfield(opts, 'autoScale') && logical(opts.autoScale);
if isfield(opts, 'xLimits')
    params.customXLimits = opts.xLimits;
else
    params.customXLimits = [];
end
params.showOriginalTraces = isfield(opts, 'showOriginalTraces') && logical(opts.showOriginalTraces);
params.removeBaseline = isfield(opts, 'removeBaseline') && logical(opts.removeBaseline);
if isfield(opts, 'SmoothingKernel_s')
    params.SmoothingKernel_s = opts.SmoothingKernel_s;
else
    params.SmoothingKernel_s = 0;
end
params.SubtractMean = isfield(opts, 'SubtractMean') && logical(opts.SubtractMean);
params.showWaitbar = false;

if params.remove_artifact && params.show_spikes
    win_r = round(artifact_window_ms * (Fs/1000));
    stim_inxs = ClosestIndex(stims, time, true);
    params.spks = maskSpikesInStimWindows(params.spks, time, stim_inxs, win_r);
end

timePoints = params.timePoints;
sourceType = params.sourceType;
meanWindow = params.meanWindow;
hd = params.hd;
channelSettings = params.channelSettings;
Fs = params.Fs;
N = params.N;
time = params.time;
binsize = params.binsize;
prg = params.spk_threshold;
spks = params.spks;
ch_inxs = params.ch_inxs;
show_spikes = params.show_spikes;
show_CSD = params.show_CSD;
mean_group_ch = params.mean_group_ch;
t_profile = params.t_profile;
timeUnitFactor = params.timeUnitFactor;
lfpVar = params.lfpVar;
shiftCoeff = params.shiftCoeff;

if isfield(params, 'ch_labels')
    ch_labels = params.ch_labels;
else
    ch_labels = hd.recChNames(:);
end
if isfield(params, 'channel_index_original')
    ch_inxs_for_spks = params.channel_index_original;
else
    ch_inxs_for_spks = ch_inxs;
end
activeChannels = find([channelSettings{:, 2}]);
scalingCoefficients = [channelSettings{:, 3}];
colors_in = channelSettings(:, 4)';
widths_in = [channelSettings{:, 5}];
ch_inxs = ch_inxs(:)';

winLen = round(meanWindow * Fs);
halfWin = round(meanWindow * Fs / 2);
numEvents = length(timePoints);

[meanData, originalEventsData, wasCanceled, nProcessed, processedTimePoints] = accumulateMeanEventWindows(params);

if nProcessed == 0
    if wasCanceled
        fprintf('Mean events stopped by user.\n');
    end
    calculation_result = struct();
    plotParams = params;
    return;
end

params.nProcessedEvents = nProcessed;
params.totalEvents = numEvents;
params.wasCanceled = wasCanceled;
params.processedTimePoints = processedTimePoints;

try
    delete(wb);
catch
end

eventIdx = round(processedTimePoints(:) * Fs);
windowStart = max(eventIdx - halfWin, 1);
windowEnd = min(windowStart + winLen - 1, numel(time));
valid = true(nProcessed, 1);

if params.SmoothingKernel_s > 0
    kernel_samples = max(5, round((params.SmoothingKernel_s / timeUnitFactor) * Fs));
    meanData = movmean(meanData, kernel_samples, 1, 'Endpoints', 'shrink');
    originalEventsData = cellfun(@(x) movmean(x, kernel_samples, 1, 'Endpoints', 'shrink'), ...
        originalEventsData, 'UniformOutput', false);
end

if params.SubtractMean
    meanData = meanData - mean(meanData, 1);
    originalEventsData = cellfun(@(x) x - mean(x, 1), originalEventsData, 'UniformOutput', false);
end

ev_hists = [];
if show_spikes && ~isempty(spks) && ~show_CSD
    spk_times_sec = cell(1, numel(ch_inxs));
    for ch_idx = 1:numel(ch_inxs)
        ch_inx = ch_inxs_for_spks(ch_idx);
        ii = double(spks(ch_inx).ampl) <= (-lfpVar(ch_inx) * prg);
        spk_times_sec{ch_idx} = spks(ch_inx).tStamp(ii) / 1000;
    end

    firstValid = find(valid, 1, 'first');
    if ~isempty(firstValid)
        t0 = time(windowStart(firstValid));
        t1 = time(windowEnd(firstValid));
        nBins = max(numel(t0:binsize:t1) - 1, 0);
        evs = zeros(nProcessed, numel(ch_inxs), nBins);
        nChSpk = numel(ch_inxs);

        for i = 1:nProcessed
            if valid(i) && nBins > 0
                time_start = time(windowStart(i));
                edges = linspace(time_start, time_start + nBins * binsize, nBins + 1);
                time_end = edges(end);
                ch_hists = zeros(nChSpk, nBins);
                for ch_idx = 1:nChSpk
                    spk = spk_times_sec{ch_idx};
                    spk = spk(spk >= time_start & spk < time_end);
                    ch_hists(ch_idx, :) = histcounts(spk, edges);
                end
                evs(i, :, :) = ch_hists;
            end
        end
        ev_hists = squeeze(mean(evs, 1));
    end
end

start_time = -meanWindow / 2;
end_time = meanWindow / 2;
timeAxis = linspace(start_time, end_time, size(meanData, 1)) * timeUnitFactor;
pl_meanData = meanData .* scalingCoefficients(ch_inxs);
numChannels = size(pl_meanData, 2);

calculation_result = struct();
calculation_result.meanData = meanData;
calculation_result.timePoints = timePoints;
calculation_result.nProcessedEvents = nProcessed;
calculation_result.totalEvents = numEvents;
calculation_result.wasCanceled = wasCanceled;
calculation_result.processedTimePoints = processedTimePoints;
calculation_result.sourceType = sourceType;
calculation_result.channelSettings = channelSettings;
calculation_result.activeChannels = activeChannels;
calculation_result.scalingCoefficients = scalingCoefficients;
calculation_result.Fs = Fs;
calculation_result.N = N;
calculation_result.show_spikes = show_spikes;
calculation_result.binsize = binsize;
calculation_result.std_coef = prg;
calculation_result.ch_inxs = ch_inxs;
calculation_result.ev_hists = ev_hists;
calculation_result.timeAxis = timeAxis / timeUnitFactor;
calculation_result.timeAxisScaled = timeAxis;
calculation_result.timeUnitFactor = timeUnitFactor;
calculation_result.ch_labels = ch_labels;
calculation_result.shiftCoeff = shiftCoeff;
calculation_result.widths_in = widths_in;
calculation_result.colors_in = colors_in;
calculation_result.originalEventsData = originalEventsData;

calculation_result.baseline_medians = median(pl_meanData, 1);

if ~isempty(params.customXLimits)
    Xlims = params.customXLimits;
else
    Xlims = [-time_back, time_forward] * timeUnitFactor;
end
calculation_result.xLimits = Xlims;
plotParams = params;
