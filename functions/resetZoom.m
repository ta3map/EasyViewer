function resetZoom()
    % Сброс состояния зума в signalViewerGUI
    % Используется для автоматического сброса зума при обновлении графика
    
    global zoomState zoomButton multiax
    
    try
        if isempty(zoomState) || ~isstruct(zoomState)
            return;
        end
        
        if ~(zoomState.has_zoom || zoomState.await_points)
            return;
        end
        
        % Сброс флагов зума
        zoomState.await_points = false;
        zoomState.has_zoom = false;
        zoomState.is_panning = false;
        zoomState.points = zeros(0, 2);
        
        % Удаление временных линий зума
        if isfield(zoomState, 'lines') && ~isempty(zoomState.lines)
            valid_lines = ishandle(zoomState.lines);
            delete(zoomState.lines(valid_lines));
            zoomState.lines = gobjects(0);
        end
        
        % Обновление кнопки зума
        if ~isempty(zoomButton) && ishandle(zoomButton)
            set(zoomButton, 'String', 'Zoom');
        end
        
        % Сброс указателя мыши
        if ~isempty(multiax) && ishandle(multiax)
            f = get(multiax, 'Parent');
            while ~strcmp(get(f, 'Type'), 'figure')
                f = get(f, 'Parent');
            end
            if ishandle(f)
                set(f, 'Pointer', 'arrow');
            end
        end
    catch
        % Игнорируем ошибки при сбросе зума
    end
end


