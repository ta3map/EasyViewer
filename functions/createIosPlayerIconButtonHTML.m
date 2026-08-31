function htmlStr = createIosPlayerIconButtonHTML(imgPath, textStr, iconSize)
    if nargin < 3
        iconSize = 30;
    end
    if nargin < 2
        textStr = '';
    end
    imgPathEscaped = strrep(imgPath, '\', '/');
    if isempty(textStr)
        htmlStr = sprintf('<html><img src="file:///%s" width="%d" height="%d"></html>', imgPathEscaped, iconSize, iconSize);
    else
        htmlStr = sprintf('<html><img src="file:///%s" width="%d" height="%d">&nbsp;%s</html>', imgPathEscaped, iconSize, iconSize, textStr);
    end
end
