function nameGrid = parseChannelLayout(filepath)
%PARSECHANNELLAYOUT Excel -> name grid cropped to occupied cells.

    raw = readcell(filepath);
    nameGrid = cellfun(@cellToChannelToken, raw, 'UniformOutput', false);
    occupied = ~cellfun(@isempty, nameGrid);
    rows = find(any(occupied, 2));
    cols = find(any(occupied, 1));
    nameGrid = nameGrid(rows(1):rows(end), cols(1):cols(end));
end

function token = cellToChannelToken(value)
    token = '';
    if isempty(value)
        return;
    end
    if isnumeric(value)
        token = num2str(value);
        return;
    end
    if isstring(value)
        if ismissing(value)
            return;
        end
        token = strtrim(char(value));
        return;
    end
    if ischar(value)
        token = strtrim(value);
    end
end
