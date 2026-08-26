function clearEventsState()
    global events event_indices event_comments event_amplitudes event_channels
    global event_widths event_prominences event_metadata
    global events_exist event_inx event_title_string

    events = [];
    event_indices = [];
    event_comments = {};
    event_amplitudes = [];
    event_channels = [];
    event_widths = [];
    event_prominences = [];
    event_metadata = [];
    events_exist = false;
    event_inx = 1;
    event_title_string = 'Events';
end
