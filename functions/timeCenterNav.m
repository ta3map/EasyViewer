function varargout = timeCenterNav(action, varargin)
    % Shared time-center navigation used by signalViewerGUI and signalAnalysisGUI.
    % Modes: continuous, stimulus, events (popup lists only modes with data in memory).

    global selectedCenter events event_inx events_exist stims stim_inx stims_exist
    global time chosen_time_interval

    switch action
        case 'modes'
            varargout{1} = navModesAvailable();
        case 'syncPopup'
            popup = varargin{1};
            windowSize = [];
            if numel(varargin) >= 2
                windowSize = varargin{2};
            end
            ensureAvailableCenter(windowSize);
            modes = navModesAvailable();
            set(popup, 'String', modes);
            idx = find(strcmp(modes, selectedCenter), 1);
            if isempty(idx)
                idx = 1;
                selectedCenter = modes{1};
            end
            set(popup, 'Value', idx);
        case 'shift'
            ensureCenter();
            shiftImpl(varargin{1}, varargin{2});
        case 'setAnchor'
            ensureCenter();
            varargout{1} = setAnchorImpl(varargin{1}, varargin{2});
        case 'applyInterval'
            ensureCenter();
            applyIntervalImpl(varargin{1});
        case 'resetIndex'
            ensureCenter();
            resetIndexImpl();
        case 'popupIndex'
            ensureAvailableCenter();
            idx = find(strcmp(navModesAvailable(), selectedCenter), 1);
            if isempty(idx)
                idx = 1;
            end
            varargout{1} = idx;
        case 'status'
            ensureCenter();
            varargout{1} = statusImpl();
    end
end

function names = navModesAvailable()
    global events_exist stims_exist events stims
    names = {'continuous'};
    if isscalar(stims_exist) && stims_exist && ~isempty(stims)
        names{end + 1} = 'stimulus';
    end
    if isscalar(events_exist) && events_exist && ~isempty(events)
        names{end + 1} = 'events';
    end
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

function ensureAvailableCenter(windowSize)
    global selectedCenter time
    ensureCenter();
    modes = navModesAvailable();
    if ~any(strcmp(modes, selectedCenter))
        selectedCenter = 'continuous';
        resetIndexImpl();
        if nargin >= 1 && ~isempty(windowSize) && ~isempty(time)
            applyIntervalImpl(windowSize);
        end
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

function navState = setAnchorImpl(anchorTime, windowSize)
    global selectedCenter events event_inx events_exist stims stim_inx stims_exist
    global time chosen_time_interval

    navState = struct('anchorTime', anchorTime, 'event_inx', [], 'stim_inx', []);

    switch selectedCenter
        case 'stimulus'
            if stims_exist
                stim_inx = ClosestIndex(anchorTime, stims);
                stim_inx = min(max(stim_inx, 1), numel(stims));
                chosen_time_interval(1) = stims(stim_inx);
                chosen_time_interval(2) = stims(stim_inx) + windowSize;
                navState.stim_inx = stim_inx;
                navState.anchorTime = stims(stim_inx);
                return;
            end
        case 'events'
            if events_exist
                event_inx = ClosestIndex(anchorTime, events);
                event_inx = min(max(event_inx, 1), numel(events));
                chosen_time_interval(1) = events(event_inx);
                chosen_time_interval(2) = events(event_inx) + windowSize;
                navState.event_inx = event_inx;
                navState.anchorTime = events(event_inx);
                return;
            end
    end

    anchorTime = clampContinuousStart(anchorTime, windowSize);
    chosen_time_interval = [anchorTime, anchorTime + windowSize];
    navState.anchorTime = anchorTime;
    if events_exist && ~isempty(events)
        event_inx = ClosestIndex(anchorTime, events);
        event_inx = min(max(event_inx, 1), numel(events));
        navState.event_inx = event_inx;
    end
end

function startTime = clampContinuousStart(startTime, windowSize)
    global time
    if isempty(time)
        return;
    end
    if startTime + windowSize > time(end)
        startTime = time(end) - windowSize;
    end
    if startTime < time(1)
        startTime = time(1);
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
