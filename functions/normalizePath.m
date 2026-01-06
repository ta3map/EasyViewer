function pathStr = normalizePath(value)
    if isempty(value)
        pathStr = '';
    elseif isstring(value)
        pathStr = char(value);
    elseif iscell(value)
        pathStr = normalizePath(value{1});
    else
        pathStr = char(value);
    end
end

