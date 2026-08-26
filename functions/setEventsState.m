function setEventsState(times, varargin)
    global events event_indices event_comments event_amplitudes event_channels
    global event_widths event_prominences event_metadata
    global events_exist event_inx event_title_string time

    p = inputParser;
    addParameter(p, 'indices', [], @isnumeric);
    addParameter(p, 'comments', {}, @(x) iscell(x) || isstring(x) || ischar(x));
    addParameter(p, 'amplitudes', [], @isnumeric);
    addParameter(p, 'channels', [], @isnumeric);
    addParameter(p, 'widths', [], @isnumeric);
    addParameter(p, 'prominences', [], @isnumeric);
    addParameter(p, 'metadata', [], @(x) isstruct(x) || iscell(x) || isempty(x));
    addParameter(p, 'source', 'unknown', @(x) ischar(x) || isstring(x));
    addParameter(p, 'title', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'event_inx', 1, @isnumeric);
    addParameter(p, 'sync', true, @islogical);
    parse(p, varargin{:});
    opts = p.Results;

    times = times(:);
    n = numel(times);
    events = times;

    if n == 0
        clearEventsState();
        if ~isempty(opts.title)
            event_title_string = char(opts.title);
        end
        if opts.sync
            syncEventTable();
        end
        return;
    end

    [events, order] = sort(events);
    event_indices = buildEventIndices(opts.indices, order, n, events);
    event_comments = buildEventComments(opts.comments, order, n);
    event_amplitudes = buildEventColumn(opts.amplitudes, order, n, NaN);
    event_channels = normalizeEventChannels(reorderRows(opts.channels, order, n), n);
    event_widths = buildEventColumn(opts.widths, order, n, NaN);
    event_prominences = buildEventColumn(opts.prominences, order, n, NaN);
    event_metadata = normalizeEventMetadata(reorderMeta(opts.metadata, order, n), n, char(opts.source));

    events_exist = true;
    event_inx = min(max(round(opts.event_inx), 1), n);
    if ~isempty(opts.title)
        event_title_string = char(opts.title);
    end
    if opts.sync
        syncEventTable();
    end
end

function indices = buildEventIndices(src, order, n, times)
    global time
    indices = zeros(n, 1);
    src = src(:);
    if numel(src) == n
        indices = src(order);
        return;
    end
    if isempty(time)
        return;
    end
    for i = 1:n
        [~, indices(i)] = min(abs(time(:) - times(i)));
    end
end

function comments = buildEventComments(src, order, n)
    comments = repmat({'...'}, n, 1);
    if ischar(src)
        src = {src};
    end
    if isstring(src)
        src = cellstr(src);
    end
    src = src(:);
    if numel(src) == n
        comments = src(order);
    elseif ~isempty(src)
        m = min(n, numel(src));
        comments(1:m) = src(1:m);
    end
end

function col = buildEventColumn(src, order, n, fill)
    col = repmat(fill, n, 1);
    src = src(:);
    if numel(src) == n
        col = src(order);
    elseif ~isempty(src)
        m = min(n, numel(src));
        col(1:m) = src(1:m);
    end
end

function rows = reorderRows(src, order, n)
    if isempty(src)
        rows = [];
        return;
    end
    if size(src, 1) == n
        rows = src(order, :);
        return;
    end
    rows = src;
end

function meta = reorderMeta(src, order, n)
    if isempty(src)
        meta = [];
        return;
    end
    if iscell(src)
        src = src(:);
        if numel(src) == n
            meta = src(order);
            return;
        end
        meta = src;
        return;
    end
    if numel(src) == n
        meta = src(order);
        return;
    end
    meta = src;
end
