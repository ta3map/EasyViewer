function pd = appendViewerOverlayMeta(pd)
%APPENDVIEWEROVERLAYMETA Events/stims texts and title/center labels.

global events stims timeUnitFactor selectedUnit selectedCenter
global event_inx stim_inx matFilePath event_title_string
global event_amplitudes event_channels ch_inxs visualSettings

if pd.show_events && ~isempty(events)
    pd.cond2 = events >= pd.plot_time_interval(1) & events < pd.plot_time_interval(2);
    pd.events_x = (events(pd.cond2) - pd.time_origin) * timeUnitFactor;
    pd.eventIndices = find(pd.cond2);
else
    pd.cond2 = [];
    pd.events_x = [];
    pd.eventIndices = [];
end

if isempty(pd.events_x)
    pd.eventTexts = {};
    pd.eventAmps = [];
    pd.eventChannels = [];
else
    event_times_absolute = events(pd.cond2) * timeUnitFactor;
    event_times_relative = (events(pd.cond2) - pd.time_origin) * timeUnitFactor;
    fmtOpts = {'%.3f', '%.0f'};
    timeFmt = fmtOpts{1 + strcmp(selectedUnit, 'ms')};
    pd.eventTexts = arrayfun( ...
        @(i) sprintf(['#%d\n', timeFmt, ' ', selectedUnit, '\nrel ', timeFmt, ' ', selectedUnit], ...
            pd.eventIndices(i), event_times_absolute(i), event_times_relative(i)), ...
        1:numel(pd.eventIndices), 'UniformOutput', false);
    ev_amps = NaN(size(pd.eventIndices(:)));
    if ~isempty(event_amplitudes) && numel(event_amplitudes) >= max(pd.eventIndices)
        ev_amps = event_amplitudes(pd.eventIndices);
        ev_amps = ev_amps(:);
    end
    ampText = arrayfun(@(a) sprintf('\nAmp %.3f', a), ev_amps, 'UniformOutput', false);
    ampText(isnan(ev_amps)) = {''};
    pd.eventTexts = cellfun(@(b, a) [b a], pd.eventTexts(:), ampText, 'UniformOutput', false);
    pd.eventAmps = ev_amps;
    pd.eventChannels = [];
    if ~isempty(event_channels)
        ev_chs = event_channels(:);
        if numel(ev_chs) >= max(pd.eventIndices)
            pd.eventChannels = ev_chs(pd.eventIndices);
        end
    end
end

pd.stimIndices = find(pd.cond3);
if isempty(pd.stims_x)
    pd.stimTexts = {};
else
    pd.stimTexts = arrayfun(@(i) sprintf('%d', pd.stimIndices(i)), 1:numel(pd.stimIndices), 'UniformOutput', false);
end

[~, name, ~] = fileparts(matFilePath);
pd.titleLabel = name;
eventFileLabel = strtrim(event_title_string);
if ~isempty(eventFileLabel) && ~strcmp(eventFileLabel, 'Events')
    pd.titleLabel = sprintf('%s | %s', name, eventFileLabel);
end
centerModes = {'stimulus', 'events', 'continuous'};
centerLabels = {'Stimuli', 'Events', 'Continuos'};
pd.centerLabel = centerLabels{find(strcmp(centerModes, selectedCenter), 1)};
timeFmtOpts = {'%.3f', '%.0f'};
timeFmt = timeFmtOpts{1 + strcmp(selectedUnit, 'ms')};
centerLabelParts = { ...
    ['Mode: ', pd.centerLabel], ...
    sprintf([timeFmt, ' %s'], pd.time_origin * timeUnitFactor, selectedUnit) ...
};
switch selectedCenter
    case 'events'
        centerLabelParts{end + 1} = sprintf('%d/%d', event_inx, numel(events));
    case 'stimulus'
        centerLabelParts{end + 1} = sprintf('%d/%d', stim_inx, numel(stims));
end
pd.centerLabel = strjoin(centerLabelParts, ' | ');
pd.ch_inxs = ch_inxs;
pd.show_stim = logical(visualSettings.stim_show);
end
