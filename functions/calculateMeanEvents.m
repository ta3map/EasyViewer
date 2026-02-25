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

channelSettings = get(channelTable, 'Data');
params.sourceType = sourceType;
params.hd = hd;
params.channelSettings = channelSettings;
params.Fs = Fs;
params.lfp = lfp_file.lfp;
params.N = N;
params.time = time;
params.binsize = binsize;
params.spk_threshold = std_coef;
params.spks = spks;
params.shiftCoeff = shiftCoeff;
params.titlename = local_evfilename;
params.show_spikes = visualSettings.show_spikes;
params.ch_inxs = ch_inxs;
if isfield(opts, 'Channel') && ~isempty(opts.Channel)
    ch_sel = round(opts.Channel);
    params.ch_inxs = ch_sel;
    params.lfp = params.lfp(:, ch_sel);
    params.channelSettings = channelSettings(ch_sel, :);
    params.ch_inxs = 1;
    params.ch_labels = hd.recChNames(ch_sel);
    params.csd_active = csd_avaliable(ch_sel);
    params.mean_group_ch = 1;
    params.channel_index_original = ch_sel;
else
    params.csd_active = csd_avaliable(ch_inxs);
end
params.show_CSD = visualSettings.show_CSD;
params.csd_smooth_coef = csd_smooth_coef;
params.csd_contrast_coef = csd_contrast_coef;
params.timeUnitFactor = timeUnitFactor;
params.lfpVar = lfpVar;
params.mean_group_ch = mean_group_ch;
params.t_profile = t_mean_profile;

if isfield(opts, 'meanWindow')
    params.meanWindow = opts.meanWindow;
elseif isfield(opts, 'xLimits') && ~isempty(opts.xLimits)
    xLimitsSeconds = opts.xLimits / timeUnitFactor;
    params.meanWindow = max(abs(xLimitsSeconds(1)), abs(xLimitsSeconds(2))) * 2;
else
    params.meanWindow = 2;
end

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

if params.remove_artifact
    win_r = round(artifact_window_ms * (Fs/1000));
    params.lfp = removeStimArtifact(params.lfp, stims, time, win_r, art_rem_settings.interp_method);
    if params.show_spikes
        stim_inxs = ClosestIndex(stims, time);
        for ch = 1:size(spks, 1)
            for i = 1:length(stim_inxs)
                start_inx = max(stim_inxs(i) - win_r, 1);
                end_inx = stim_inxs(i) + win_r;
                cond5 = params.spks(ch).tStamp/1000 >= time(start_inx) & params.spks(ch).tStamp/1000 < time(end_inx);
                params.spks(ch).tStamp = params.spks(ch).tStamp(~cond5);
                params.spks(ch).ampl = params.spks(ch).ampl(~cond5);
            end
        end
    end
end

if isfield(params, 'channel_index_original') && size(params.lfp, 2) == 1
    if filter_avaliable(params.channel_index_original)
        params.lfp = applyFilter(params.lfp, filterSettings, newFs);
    end
elseif sum(filter_avaliable) > 0
    params.lfp(:, filter_avaliable) = applyFilter(params.lfp(:, filter_avaliable), filterSettings, newFs);
end

try
    delete(wb);
catch
end

timePoints = params.timePoints;
sourceType = params.sourceType;
meanWindow = params.meanWindow;
hd = params.hd;
channelSettings = params.channelSettings;
Fs = params.Fs;
lfp = params.lfp;
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

meanData = zeros(round(meanWindow * Fs), size(lfp, 2));
numEvents = length(timePoints);
removeBaseline = params.removeBaseline;

if removeBaseline
    lfp(:, mean_group_ch) = lfp(:, mean_group_ch) - nanmean(lfp(:, mean_group_ch), 2);
end

ch_enabled = false(length(ch_labels), 1);
ch_enabled(activeChannels) = true;
originalEventsData = {};
showWaitbar = ~isfield(params, 'showWaitbar') || logical(params.showWaitbar);
wb_local = [];
if showWaitbar
    wb_local = waitbar(0, 'Processing events...', 'Name', 'Calculating mean events');
end

for i = 1:numEvents
    eventIdx = round(timePoints(i) * Fs);
    windowStart = max(eventIdx - round(meanWindow * Fs / 2), 1);
    windowEnd = min(windowStart + round(meanWindow * Fs) - 1, N);

    if windowEnd < size(lfp, 1)
        eventDataRaw = lfp(windowStart:windowEnd, :);
        if removeBaseline
            eventDataProcessed = eventDataRaw - nanmedian(eventDataRaw);
        else
            eventDataProcessed = eventDataRaw;
        end
        meanData = meanData + eventDataProcessed;
        eventDataScaled = eventDataProcessed(:, ch_enabled) .* scalingCoefficients(ch_enabled);
        originalEventsData{end+1} = eventDataScaled;
    end

    if showWaitbar && ~isempty(wb_local)
        waitbar(i / numEvents, wb_local, sprintf('Processing event %d of %d', i, numEvents));
    end
end

meanData = meanData / numEvents;

if params.SmoothingKernel_s > 0
    kernel_samples = max(5, round((params.SmoothingKernel_s / timeUnitFactor) * Fs));
    for chIdx = 1:size(meanData, 2)
        meanData(:, chIdx) = smooth1(meanData(:, chIdx), kernel_samples, 'moving');
    end
    for eventIdx = 1:length(originalEventsData)
        eventData = originalEventsData{eventIdx};
        for chIdx = 1:size(eventData, 2)
            eventData(:, chIdx) = smooth1(eventData(:, chIdx), kernel_samples, 'moving');
        end
        originalEventsData{eventIdx} = eventData;
    end
end

if params.SubtractMean
    for chIdx = 1:size(meanData, 2)
        meanData(:, chIdx) = meanData(:, chIdx) - mean(meanData(:, chIdx));
    end
    for eventIdx = 1:length(originalEventsData)
        eventData = originalEventsData{eventIdx};
        for chIdx = 1:size(eventData, 2)
            eventData(:, chIdx) = eventData(:, chIdx) - mean(eventData(:, chIdx));
        end
        originalEventsData{eventIdx} = eventData;
    end
end

ev_hists = [];
if show_spikes && ~isempty(spks) && ~show_CSD
    for i = 1:numEvents
        eventIdx = round(timePoints(i) * Fs);
        windowStart = max(eventIdx - round(meanWindow * Fs / 2), 1);
        windowEnd = min(windowStart + round(meanWindow * Fs) - 1, N);

        if windowEnd < size(lfp, 1)
            time_start = time(windowStart);
            time_end = time(windowEnd);
            time_interval = [time_start, time_end];
            edges = time_interval(1):binsize:time_interval(2);
            ch_hists = [];
            for ch_idx = 1:numel(ch_inxs)
                ch_inx = ch_inxs_for_spks(ch_idx);
                ii = double(spks(ch_inx).ampl) <= (-lfpVar(ch_inx) * prg);
                spks_in(ch_inx).tStamp = spks(ch_inx).tStamp(ii);
                spks_in(ch_inx).ampl = spks(ch_inx).ampl(ii);
                spk = spks_in(ch_inx).tStamp/1000;
                hist_data = histcounts(spk, edges);
                ch_hists = [ch_hists; hist_data];
            end
            evs(i, :, :) = ch_hists;
        end
        if showWaitbar && ~isempty(wb_local)
            waitbar(i / numEvents, wb_local, sprintf('Processing spikes: event %d of %d', i, numEvents));
        end
    end
    if exist('evs', 'var')
        ev_hists = squeeze(mean(evs, 1));
    end
end

if showWaitbar && ~isempty(wb_local)
    close(wb_local);
end

start_time = -meanWindow / 2;
end_time = meanWindow / 2;
timeAxis = linspace(start_time, end_time, size(meanData, 1)) * timeUnitFactor;
pl_meanData = meanData .* scalingCoefficients;
pl_meanData = pl_meanData(:, ch_enabled);
numChannels = size(pl_meanData, 2);

calculation_result = struct();
calculation_result.meanData = meanData;
calculation_result.timePoints = timePoints;
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

baseline_medians = zeros(1, numChannels);
for ch = 1:numChannels
    baseline_medians(ch) = median(pl_meanData(:, ch));
end
calculation_result.baseline_medians = baseline_medians;

if ~isempty(params.customXLimits)
    Xlims = params.customXLimits;
else
    Xlims = [-time_back, time_forward] * timeUnitFactor;
end
calculation_result.xLimits = Xlims;
plotParams = params;
