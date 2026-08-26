function deleteEventsByIndex(idxs)
    global events event_indices event_comments event_amplitudes event_channels
    global event_widths event_prominences event_metadata
    global events_exist event_inx

    idxs = idxs(:);
    idxs = idxs(~isnan(idxs) & idxs >= 1 & idxs <= numel(events));
    idxs = unique(round(idxs));
    if isempty(idxs)
        return;
    end

    events(idxs) = [];
    if numel(event_indices) >= max(idxs)
        event_indices(idxs) = [];
    end
    if numel(event_comments) >= max(idxs)
        event_comments(idxs) = [];
    end
    if numel(event_amplitudes) >= max(idxs)
        event_amplitudes(idxs) = [];
    end
    if size(event_channels, 1) >= max(idxs)
        event_channels(idxs, :) = [];
    end
    if numel(event_widths) >= max(idxs)
        event_widths(idxs) = [];
    end
    if numel(event_prominences) >= max(idxs)
        event_prominences(idxs) = [];
    end
    if numel(event_metadata) >= max(idxs)
        event_metadata(idxs) = [];
    end

    if isempty(events)
        clearEventsState();
        syncEventTable();
        return;
    end

    events_exist = true;
    event_inx = min(max(event_inx, 1), numel(events));
    syncEventTable();
end
