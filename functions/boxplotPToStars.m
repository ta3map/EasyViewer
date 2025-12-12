function stars = boxplotPToStars(p)
    % boxplotPToStars - Конвертация p-value в звездочки для обозначения значимости
    % 
    % Входные параметры:
    %   p - p-value (число)
    %
    % Выходные параметры:
    %   stars - строка со звездочками: '***' (p<0.001), '**' (p<0.01), '*' (p<0.05), 'ns' (p>=0.05)
    
    if ~isfinite(p)
        stars = '';
    elseif p < 0.001
        stars = '***';
    elseif p < 0.01
        stars = '**';
    elseif p < 0.05
        stars = '*';
    else
        stars = 'ns';
    end
end

