function sec = iosPlayerTimeStr2sec(s)
    parts = sscanf(s, '%d:%f');
    if numel(parts) < 2
        sec = str2double(s);
        if isnan(sec)
            sec = 0;
        end
        return
    end
    sec = parts(1) * 60 + parts(2);
end
