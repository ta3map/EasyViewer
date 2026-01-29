function rgb = hex2rgb(hexColor)
    % HEX2RGB Конвертирует HEX цвет в RGB формат
    % 
    % Входные параметры:
    %   hexColor - строка с HEX кодом цвета (например, '#1E88E5' или '1E88E5')
    %
    % Выходные параметры:
    %   rgb - массив [r, g, b] в диапазоне [0-1]
    
    hexColor = strrep(hexColor, '#', '');
    r = hex2dec(hexColor(1:2)) / 255;
    g = hex2dec(hexColor(3:4)) / 255;
    b = hex2dec(hexColor(5:6)) / 255;
    rgb = [r, g, b];
end
