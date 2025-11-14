function colors = getColors(numChannels)
    % GETCOLORS Генерирует современную палитру цветов в HEX формате
    % 
    % Входные параметры:
    %   numChannels - количество каналов
    %
    % Выходные параметры:
    %   colors - cell array строк с HEX кодами цветов
    
    % Современная палитра цветов (Material Design и другие современные схемы)
    modernPalette = {
        '#1E88E5',  % Blue
        '#43A047',  % Green
        '#FB8C00',  % Orange
        '#E53935',  % Red
        '#8E24AA',  % Purple
        '#00ACC1',  % Cyan
        '#FDD835',  % Yellow
        '#D81B60',  % Pink
        '#00897B',  % Teal
        '#5E35B1',  % Deep Purple
        '#C62828',  % Dark Red
        '#2E7D32',  % Dark Green
        '#F57C00',  % Dark Orange
        '#1565C0',  % Dark Blue
        '#6A1B9A',  % Dark Purple
        '#00695C',  % Dark Teal
        '#AD1457',  % Dark Pink
        '#4527A0',  % Indigo
        '#C2185B',  % Pink 700
        '#00796B',  % Teal 700
        '#1976D2',  % Blue 700
        '#388E3C',  % Green 700
        '#F9A825',  % Amber 800
        '#D32F2F',  % Red 700
        '#7B1FA2',  % Purple 700
        '#0288D1',  % Light Blue 700
        '#689F38',  % Light Green 700
        '#FBC02D',  % Yellow 700
        '#E64A19',  % Deep Orange 700
        '#5D4037'   % Brown 700
    };
    
    % Повторяем палитру, если каналов больше
    colors = cell(numChannels, 1);
    for i = 1:numChannels
        colorIdx = mod(i - 1, length(modernPalette)) + 1;
        colors{i} = modernPalette{colorIdx};
    end
end

