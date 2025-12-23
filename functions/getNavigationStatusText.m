function status_text = getNavigationStatusText(metadata)
    % getNavigationStatusText - форматирование текста статуса из метаданных
    % Точная копия из signalAnalysisGUI
    %
    % Входные параметры:
    %   metadata - структура метаданных результата
    %
    % Глобальные переменные:
    %   events_exist, events, stims_exist, stims, sweep_info
    %
    % Выходные параметры:
    %   status_text - строка статуса
    
    global events_exist events stims_exist stims sweep_info
    
    status_text = sprintf('Mode: %s', metadata.selectedCenter);
    
    % Добавляем информацию о текущей позиции
    switch metadata.selectedCenter
        case 'event'
            if exist('events_exist', 'var') && events_exist && ~isempty(events)
                status_text = sprintf('%s (%d/%d)', status_text, metadata.event_inx, length(events));
            end
        case 'stimulus'
            if exist('stims_exist', 'var') && stims_exist && ~isempty(stims)
                status_text = sprintf('%s (%d/%d)', status_text, metadata.stim_inx, length(stims));
            end
        case 'sweep'
            if exist('sweep_info', 'var') && isstruct(sweep_info) && sweep_info.is_sweep_data
                status_text = sprintf('%s (%d/%d)', status_text, metadata.sweep_inx, sweep_info.sweep_count);
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





