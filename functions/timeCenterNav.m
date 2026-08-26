function varargout = timeCenterNav(action, varargin)
    % Shared time-center navigation used by signalViewerGUI and signalAnalysisGUI.
    % Modes: continuous, stimulus, events.

    global selectedCenter events event_inx events_exist stims stim_inx stims_exist
    global time chosen_time_interval

    switch action
        case 'modes'
            varargout{1} = navModes();
        case 'shift'
            ensureCenter();
            shiftImpl(varargin{1}, varargin{2});
        case 'applyInterval'
            ensureCenter();
            applyIntervalImpl(varargin{1});
        case 'resetIndex'
            ensureCenter();
            resetIndexImpl();
        case 'popupIndex'
            ensureCenter();
            varargout{1} = find(strcmp(navModes(), selectedCenter), 1);
        case 'status'
            ensureCenter();
            varargout{1} = statusImpl();
    end
end

function names = navModes()
    names = {'continuous', 'stimulus', 'events'};
end

function ensureCenter()
    global selectedCenter
    if isempty(selectedCenter)
        selectedCenter = 'continuous';
        return;
    end
    switch selectedCenter
        case 'event'
            selectedCenter = 'events';
        case {'time', 'sweep'}
            selectedCenter = 'continuous';
        case {'events', 'stimulus', 'continuous'}
            return;
        otherwise
            selectedCenter = 'continuous';
    end
end

function resetIndexImpl()
    global selectedCenter event_inx stim_inx
    switch selectedCenter
        case 'stimulus'
            stim_inx = 1;
        case 'events'
            event_inx = 1;
    end
end

function shiftImpl(direction, windowSize)
    global selectedCenter events event_inx events_exist stims stim_inx stims_exist chosen_time_interval

    switch selectedCenter
        case 'events'
            if events_exist
                event_inx = min(max(event_inx + direction, 1), numel(events));
                chosen_time_interval(1) = events(event_inx);
                chosen_time_interval(2) = events(event_inx) + windowSize;
            end
        case 'stimulus'
            if stims_exist
                stim_inx = min(max(stim_inx + direction, 1), numel(stims));
                chosen_time_interval(1) = stims(stim_inx);
                chosen_time_interval(2) = stims(stim_inx) + windowSize;
            end
        case 'continuous'
            shiftContinuous(direction, windowSize);
    end
end

function shiftContinuous(direction, windowSize)
    global time chosen_time_interval
    if direction == 1
        next_step_1 = chosen_time_interval(2);
        next_step_2 = chosen_time_interval(2) + windowSize;
    else
        next_step_1 = chosen_time_interval(1) - windowSize;
        next_step_2 = next_step_1 + windowSize;
    end
    if ~(next_step_1 < 0 || next_step_2 > time(end) + windowSize)
        chosen_time_interval(1) = next_step_1;
        chosen_time_interval(2) = next_step_2;
    end
end

function applyIntervalImpl(windowSize)
    global selectedCenter events event_inx events_exist stims stim_inx stims_exist
    global time chosen_time_interval

    switch selectedCenter
        case 'events'
            if events_exist
                chosen_time_interval(1) = events(event_inx);
                chosen_time_interval(2) = events(event_inx) + windowSize;
            end
        case 'stimulus'
            if stims_exist
                chosen_time_interval(1) = stims(stim_inx);
                chosen_time_interval(2) = stims(stim_inx) + windowSize;
            end
        case 'continuous'
            chosen_time_interval(2) = chosen_time_interval(1) + windowSize;
            if chosen_time_interval(2) > time(end)
                chosen_time_interval(2) = time(end);
                chosen_time_interval(1) = max(time(end) - windowSize, 0);
            end
    end
end

function status_text = statusImpl()
    global selectedCenter events event_inx events_exist stims stim_inx stims_exist
    status_text = sprintf('Mode: %s', selectedCenter);
    switch selectedCenter
        case 'events'
            if events_exist && ~isempty(events)
                status_text = sprintf('%s (%d/%d)', status_text, event_inx, length(events));
            end
        case 'stimulus'
            if stims_exist && ~isempty(stims)
                status_text = sprintf('%s (%d/%d)', status_text, stim_inx, length(stims));
            end
    end
end
