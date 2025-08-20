function renderVisualizationObject(obj, axes_handle, timeUnitFactor)
    % renderVisualizationObject - универсальная функция для отрисовки объектов визуализации
    % 
    % Входные параметры:
    %   obj - объект визуализации из метаданных
    %   axes_handle - handle к осям для отрисовки
    %   timeUnitFactor - коэффициент для единиц времени
    
    % fprintf('DEBUG: renderVisualizationObject вызвана\n');
    % fprintf('DEBUG: Тип объекта: %s\n', obj.type);
    % fprintf('DEBUG: Поля объекта: %s\n', strjoin(fieldnames(obj), ', '));
    % fprintf('DEBUG: timeUnitFactor=%.3f\n', timeUnitFactor);
    % fprintf('DEBUG: Координаты объекта: %s\n', strjoin(fieldnames(obj.coordinates), ', '));
    
    if ~isfield(obj, 'type') || ~isfield(obj, 'coordinates') || ~isfield(obj, 'style')
        % fprintf('DEBUG: Неполный объект, пропускаем\n');
        return; % Неполный объект, пропускаем
    end
    
    % Устанавливаем текущие оси
    axes(axes_handle);
    
    switch obj.type
        case 'point'
            % fprintf('DEBUG: Обрабатываем тип point\n');
            % Отрисовка одиночной точки
            if isfield(obj.coordinates, 'x') && isfield(obj.coordinates, 'y') && ~isnan(obj.coordinates.x)
                % Координаты уже в относительном времени, применяем только timeUnitFactor
                x_display = obj.coordinates.x * timeUnitFactor;
                
                % Отрисовываем точку
                plot(x_display, obj.coordinates.y, ...
                    'Color', obj.style.color, 'Marker', obj.style.marker, ...
                    'MarkerSize', obj.style.markersize, 'MarkerFaceColor', obj.style.markerfacecolor);
            end
            
        case 'line'
            % fprintf('DEBUG: Обрабатываем тип line\n');
            % fprintf('DEBUG: Координаты: x1=%.3f, y1=%.3f, x2=%.3f, y2=%.3f\n', ...
            %    obj.coordinates.x1, obj.coordinates.y1, obj.coordinates.x2, obj.coordinates.y2);
            % fprintf('DEBUG: Проверка isfield: x1=%d, x2=%d, y1=%d, y2=%d\n', ...
            %    isfield(obj.coordinates, 'x1'), isfield(obj.coordinates, 'x2'), ...
            %    isfield(obj.coordinates, 'y1'), isfield(obj.coordinates, 'y2'));
            % fprintf('DEBUG: Проверка isnan: x1=%d, x2=%d\n', ...
            %    isnan(obj.coordinates.x1), isnan(obj.coordinates.x2));
            % Отрисовка линии между двумя точками
            if isfield(obj.coordinates, 'x1') && isfield(obj.coordinates, 'x2') && ...
               isfield(obj.coordinates, 'y1') && isfield(obj.coordinates, 'y2') && ...
               ~isnan(obj.coordinates.x1) && ~isnan(obj.coordinates.x2)
                
                                % Нормализуем времена для отображения
            % Координаты уже в относительном времени к текущему интервалу
            x1_display = obj.coordinates.x1 * timeUnitFactor;
            x2_display = obj.coordinates.x2 * timeUnitFactor;
                
                % Отрисовываем линию
                line([x1_display, x2_display], [obj.coordinates.y1, obj.coordinates.y2], ...
                    'Color', obj.style.color, 'LineWidth', obj.style.linewidth, ...
                    'LineStyle', obj.style.linestyle);
            end
            
        case 'points'
            % fprintf('DEBUG: Обрабатываем тип points\n');
            % Отрисовка массива точек
            if isfield(obj.coordinates, 'x') && isfield(obj.coordinates, 'y') && ...
               ~isempty(obj.coordinates.x) && ~isempty(obj.coordinates.y)
                
                % Координаты уже в относительном времени, применяем только timeUnitFactor
                x_display = obj.coordinates.x * timeUnitFactor;
                
                % Отрисовываем точки
                plot(x_display, obj.coordinates.y, ...
                    'Color', obj.style.color, 'Marker', obj.style.marker, ...
                    'MarkerSize', obj.style.markersize, 'MarkerFaceColor', obj.style.markerfacecolor);
            end
            
        case 'text'
            % Отрисовка текста
            if isfield(obj.coordinates, 'x') && isfield(obj.coordinates, 'y') && ...
               isfield(obj, 'text') && ~isnan(obj.coordinates.x)
                
                % Координаты уже в относительном времени, применяем только timeUnitFactor
                x_display = obj.coordinates.x * timeUnitFactor;
                
                % Отрисовываем текст
                text(x_display, obj.coordinates.y, obj.text, ...
                    'HorizontalAlignment', obj.style.horizontalalignment, ...
                    'Color', obj.style.color, 'FontWeight', obj.style.fontweight, ...
                    'FontSize', obj.style.fontsize);
            end
            
        case 'area'
            % Отрисовка закрашенной области
            if isfield(obj.coordinates, 'x') && isfield(obj.coordinates, 'y') && ...
               ~isempty(obj.coordinates.x) && ~isempty(obj.coordinates.y)
                
                % Координаты уже в относительном времени, применяем только timeUnitFactor
                x_display = obj.coordinates.x * timeUnitFactor;
                
                % Отрисовываем закрашенную область
                fill(x_display, obj.coordinates.y, obj.style.color, ...
                    'FaceAlpha', obj.style.facealpha, 'EdgeColor', obj.style.edgecolor);
            end
            
        otherwise
            % Неизвестный тип объекта
            warning('Unknown visualization object type: %s', obj.type);
    end
    
    % fprintf('DEBUG: renderVisualizationObject завершена для типа %s\n', obj.type);
end 