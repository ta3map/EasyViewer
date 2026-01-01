function text = escapeSql(text)
    if isempty(text)
        return
    end
    text = strrep(text, '''', '''''');
end

