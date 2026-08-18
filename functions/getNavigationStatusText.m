function status_text = getNavigationStatusText(metadata)
    % getNavigationStatusText - форматирование текста статуса из метаданных
    %
    % Входные параметры:
    %   metadata - структура метаданных результата
    %
    % Глобальные переменные:
    %   events_exist, events, stims_exist, stims
    %
    % Выходные параметры:
    %   status_text - строка статуса
    
    global events_exist events stims_exist stims
    
    center = metadata.selectedCenter;
    switch center
        case 'event'
            center = 'events';
        case {'time', 'sweep'}
            center = 'continuous';
    end
    status_text = sprintf('Mode: %s', center);
    
    switch center
        case 'events'
            if exist('events_exist', 'var') && events_exist && ~isempty(events)
                status_text = sprintf('%s (%d/%d)', status_text, metadata.event_inx, length(events));
            end
        case 'stimulus'
            if exist('stims_exist', 'var') && stims_exist && ~isempty(stims)
                status_text = sprintf('%s (%d/%d)', status_text, metadata.stim_inx, length(stims));
            end
    end
    
    % Добавляем информацию о зуме
    if isfield(metadata, 'zoom_active') && metadata.zoom_active
        if isfield(metadata, 'zoom_y_min') && ~isempty(metadata.zoom_y_min) && ...
           isfield(metadata, 'zoom_y_max') && ~isempty(metadata.zoom_y_max)
            status_text = sprintf('%s | Zoom: %.1f%%-%.1f%% | Y: %.2f-%.2f', status_text, ...
                metadata.zoom_start_rel*100, metadata.zoom_end_rel*100, metadata.zoom_y_min, metadata.zoom_y_max);
        else
            status_text = sprintf('%s | Zoom: %.1f%%-%.1f%%', status_text, ...
                metadata.zoom_start_rel*100, metadata.zoom_end_rel*100);
        end
    end
end
