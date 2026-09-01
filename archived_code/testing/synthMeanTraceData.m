function data = synthMeanTraceData(opts)

if nargin < 1
    opts = struct();
end
if ~isfield(opts, 'Fs')
    opts.Fs = 1000;
end
if ~isfield(opts, 'duration')
    opts.duration = 30;
end
if ~isfield(opts, 'numCh')
    opts.numCh = 8;
end
if ~isfield(opts, 'depthStep_um')
    opts.depthStep_um = 150;
end

Fs = opts.Fs;
duration = opts.duration;
numCh = opts.numCh;
N = Fs * duration;
time = (0:N-1)' / Fs;
ch_labels = arrayfun(@(c) sprintf('Ch%d', c), 1:numCh, 'UniformOutput', false);
depth_um = (0:numCh - 1) * opts.depthStep_um;
eventTimes = 5:5:(duration - 5);

lfp = synthLfpVolume(time, depth_um);
lfp = addLaminarErps(lfp, eventTimes, Fs, depth_um);

channelSettings = cell(numCh, 5);
for ch = 1:numCh
    channelSettings{ch, 1} = ch_labels{ch};
    channelSettings{ch, 2} = true;
    channelSettings{ch, 3} = 1;
    channelSettings{ch, 4} = 'black';
    channelSettings{ch, 5} = 0.5;
end

lfpVar = std(lfp, 0, 1);
spks = synthLaminarSpikes(eventTimes, numCh, depth_um, lfpVar, duration);

params = struct();
params.timePoints = eventTimes;
params.meanWindow = 2;
params.Fs = Fs;
params.lfp_file = struct('lfp', lfp);
params.N = N;
params.time = time;
params.hd = struct('recChNames', ch_labels);
params.read_ch = 1:numCh;
params.ch_inxs = 1:numCh;
params.ch_labels = ch_labels;
params.channelSettings = channelSettings;
params.mean_group_ch = false(1, numCh);
params.mean_group_ch(1) = true;
params.shiftCoeff = 100;
params.binsize = 0.005;
params.spk_threshold = 5;
params.spks = spks;
params.lfpVar = lfpVar;
params.show_CSD = true;
params.show_spikes = true;
params.csd_smooth_coef = 5;
params.csd_contrast_coef = 99;
params.csd_active = true(1, numCh);
params.csd_hp_cutoff_hz = 100;
params.t_profile = 0.05;
params.show_profile = true;
params.titlename = 'synthetic_test';
params.showWaitbar = false;
params.timeUnitFactor = 1;
params.filter_enabled = false(1, numCh);
params.newFs = Fs;
params.filterSettings = [];
params.remove_artifact = false;

data = struct();
data.params = params;
data.lfp = lfp;
data.spks = spks;
data.eventTimes = eventTimes;
data.lfpVar = lfpVar;
data.channelSettings = channelSettings;
data.ch_labels = ch_labels;

end

function lfp = synthLfpVolume(time, depth_um)
n = numel(time);
numCh = numel(depth_um);
lfp = zeros(n, numCh);
for ch = 1:numCh
    rng(ch);
    noise = randn(n, 1);
    pink = cumsum(noise);
    pink = (pink - mean(pink)) / max(std(pink), eps);
    theta = sin(2 * pi * 6 * time + 2 * pi * rand);
    gamma = sin(2 * pi * 40 * time + 2 * pi * rand);
    depthScale = 1 - 0.12 * (depth_um(ch) / depth_um(end));
    lfp(:, ch) = depthScale * (35e-6 * pink + 12e-6 * theta + 4e-6 * gamma);
end
end

function lfp = addLaminarErps(lfp, eventTimes, Fs, depth_um)
z_mm = depth_um / 1000;
spatialProfile = (-exp(-((z_mm - 0.55) / 0.12).^2) + 0.75 * exp(-((z_mm - 0.95) / 0.18).^2)) * 180e-6;
t = (0:round(0.18 * Fs))' / Fs;
temporalKernel = -exp(-(t / 0.012).^2) + 0.55 * exp(-((t - 0.045) / 0.03).^2);
n = size(lfp, 1);
for ev = eventTimes
    onset = round(ev * Fs);
    idx = onset:(onset + numel(temporalKernel) - 1);
    idx = idx(idx >= 1 & idx <= n);
    kernel = temporalKernel(1:numel(idx));
    for ch = 1:numel(depth_um)
        lfp(idx, ch) = lfp(idx, ch) + spatialProfile(ch) * kernel;
    end
end
end

function spks = synthLaminarSpikes(eventTimes, numCh, depth_um, lfpVar, duration)
spks = repmat(struct('tStamp', single([]), 'ampl', single([])), 1, numCh);
baselineHz = 2.5 + 1.5 * (depth_um / depth_um(end));
peakHz = [6, 18, 35, 55, 40, 22, 12, 6];

for ch = 1:numCh
    ts = poissonSpikeTimes(0, duration, baselineHz(ch));
    ampl = lfpVar(ch) * (6 + 3 * rand(1, numel(ts)));
    for ev = eventTimes
        burstStart = ev + 0.008 + 0.001 * (ch - 1);
        burstEnd = burstStart + 0.18;
        burstTs = poissonSpikeTimes(burstStart, burstEnd, peakHz(ch));
        ts = [ts, burstTs]; %#ok<AGROW>
        ampl = [ampl, lfpVar(ch) * (6 + 3 * rand(1, numel(burstTs)))]; %#ok<AGROW>
    end
    [ts, ord] = sort(ts);
    spks(ch).tStamp = single(ts * 1000);
    spks(ch).ampl = single(ampl(ord));
end
end

function ts = poissonSpikeTimes(tStart, tEnd, rateHz)
t = tStart - log(rand) / rateHz;
ts = [];
while t < tEnd
    ts = [ts, t]; %#ok<AGROW>
    t = t - log(rand) / rateHz;
end
end
