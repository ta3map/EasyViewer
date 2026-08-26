function syncEventTable()
    global events event_comments event_amplitudes event_channels event_metadata
    global event_title_string timeUnitFactor eventTable

    n = numel(events);
    titleStr = 'Events';
    if ~isempty(event_title_string)
        titleStr = event_title_string;
    end

    if n == 0
        data = cell(0, 5);
    else
        comments = repmat({'...'}, n, 1);
        if numel(event_comments) == n
            comments = event_comments(:);
        end

        amps = NaN(n, 1);
        if numel(event_amplitudes) == n
            amps = event_amplitudes(:);
        end

        chs = ones(n, 1);
        if size(event_channels, 1) == n && size(event_channels, 2) >= 1
            chs = event_channels(:, 1);
        end

        sources = repmat({'unknown'}, n, 1);
        if isstruct(event_metadata) && numel(event_metadata) == n
            for i = 1:n
                if isfield(event_metadata(i), 'source') && ~isempty(event_metadata(i).source)
                    sources{i} = event_metadata(i).source;
                end
            end
        end

        factor = 1;
        if ~isempty(timeUnitFactor)
            factor = timeUnitFactor;
        end
        data = [num2cell(events(:) * factor), comments, num2cell(amps), num2cell(chs), sources];
    end

    tbl = eventTable;
    if isempty(tbl) || ~ishandle(tbl)
        tbl = findobj(0, 'Tag', 'event_table');
        if ~isempty(tbl)
            tbl = tbl(1);
        end
    end
    if ~isempty(tbl) && ishandle(tbl)
        set(tbl, 'Data', data);
    end

    titleHandles = findobj(0, 'Tag', 'events_table_title');
    if ~isempty(titleHandles)
        set(titleHandles, 'String', [titleStr, ': ', num2str(n)]);
    end
end
