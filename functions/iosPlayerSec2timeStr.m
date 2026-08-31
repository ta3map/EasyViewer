function s = iosPlayerSec2timeStr(sec)
    m = floor(sec / 60);
    sVal = sec - m * 60;
    s = sprintf('%d:%04.1f', m, sVal);
end
