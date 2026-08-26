function [timeAxis, zscore_all] = computeEventSpikeZScore(params)
%COMPUTEEVENTSPIKEZSCORE PSTH across events/channels then Z-score of mean PSTH.

    events = params.events;
    meanWindow = params.meanWindow;
    Fs = params.Fs;
    lfp = params.lfp;
    N = params.N;
    time = params.time;
    binsize = params.binsize;
    spks = params.spks;
    ch_inxs = params.ch_inxs;
    lfpVar = params.lfpVar;
    prg = params.spk_threshold;

    if isfield(params, 'timeUnitFactor')
        timeUnitFactor = params.timeUnitFactor;
    else
        timeUnitFactor = 1;
    end

    numEvents = numel(events);
    all_hists = [];
    if ~isempty(spks)
        for i = 1:numEvents
            eventIdx = round(events(i) * Fs);
            windowStart = max(eventIdx - round(meanWindow * Fs / 2), 1);
            windowEnd = min(windowStart + round(meanWindow * Fs) - 1, N);
            if windowEnd < size(lfp, 1)
                edges = time(windowStart):binsize:time(windowEnd);
                for ch_inx = ch_inxs
                    ii = double(spks(ch_inx).ampl) <= (-lfpVar(ch_inx) * prg);
                    spk = spks(ch_inx).tStamp(ii) / 1000;
                    hist_data = histcounts(spk, edges);
                    all_hists = [all_hists; hist_data]; %#ok<AGROW>
                end
            end
        end
    end

    if ~isempty(all_hists)
        mean_hists = mean(all_hists, 1);
        zscore_all = (mean_hists - mean(mean_hists)) / std(mean_hists);
    else
        zscore_all = [];
    end

    start_time = -meanWindow / 2;
    end_time = meanWindow / 2;
    timeAxis = linspace(start_time * timeUnitFactor, end_time * timeUnitFactor, numel(zscore_all));
end
