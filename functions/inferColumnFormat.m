function formatStr = inferColumnFormat(column)
n = size(column, 1);
if n == 0
    formatStr = 'Text';
    return
end
idx = round(linspace(1, n, min(5, n)));
if iscell(column)
    sample = column(idx);
else
    sample = num2cell(column(idx));
end
logicalSet = {'true', 'false', '1', '0', 'yes', 'no', 'on', 'off'};
nonEmpty = {};
for k = 1:numel(sample)
    v = sample{k};
    if isempty(v) || (isnumeric(v) && numel(v) == 1 && isnan(v))
        continue
    end
    nonEmpty{end+1} = v;
end
if isempty(nonEmpty)
    formatStr = 'Text';
    return
end
allLogical = true;
for k = 1:numel(nonEmpty)
    v = nonEmpty{k};
    if islogical(v)
        continue
    end
    if ischar(v) || isstring(v)
        s = lower(strtrim(char(v)));
        if ismember(s, logicalSet)
            continue
        end
    end
    allLogical = false;
    break
end
if allLogical
    formatStr = 'Logical';
    return
end
allNumeric = true;
for k = 1:numel(nonEmpty)
    v = nonEmpty{k};
    if isnumeric(v)
        continue
    end
    if ischar(v) || isstring(v)
        if isempty(v)
            continue
        end
        if ~isnan(str2double(v))
            continue
        end
    end
    allNumeric = false;
    break
end
if allNumeric
    formatStr = 'Number';
    return
end
formatStr = 'Text';
