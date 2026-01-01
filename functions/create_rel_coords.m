function create_rel_coords()
    % create_rel_coords - Скрипт для создания JSON файлов с относительными координатами
    % Конвертирует абсолютные координаты в относительные для всех элементов
    % кроме plot_container и main_axes, которые уже относительные
    
    % Список файлов для обработки
    coord_files = {
        'signalViewerGUI_coords.json', 'signalViewerGUI_rel_coords.json';
        'signalAnalysisGUI_coords.json', 'signalAnalysisGUI_rel_coords.json'
    };
    
    for i = 1:size(coord_files, 1)
        input_file = coord_files{i, 1};
        output_file = coord_files{i, 2};
        
        fprintf('Обрабатываю файл: %s\n', input_file);
        
        % Проверяем существование входного файла
        if ~exist(input_file, 'file')
            warning('Файл не найден: %s', input_file);
            continue;
        end
        
        try
            % Читаем исходный JSON файл
            fid = fopen(input_file, 'r', 'n', 'UTF-8');
            if fid == -1
                error('Не удалось открыть файл: %s', input_file);
            end
            
            json_str = fread(fid, '*char')';
            fclose(fid);
            
            % Парсим JSON
            coords_data = jsondecode(json_str);
            
            % Получаем размеры окна
            base_pos = coords_data.base_figure_position;
            window_width = base_pos(3);
            window_height = base_pos(4);
            
            fprintf('Размеры окна: %d x %d\n', window_width, window_height);
            
            % Создаем новую структуру данных
            new_coords_data = struct();
            new_coords_data.base_figure_position = base_pos;
            new_coords_data.elements = struct();
            
            % Получаем список всех элементов
            element_names = fieldnames(coords_data.elements);
            
            for j = 1:length(element_names)
                element_name = element_names{j};
                coords = coords_data.elements.(element_name);
                
                % Проверяем, является ли элемент уже относительным
                if strcmp(element_name, 'plot_container') || strcmp(element_name, 'main_axes')
                    % Оставляем относительные координаты как есть
                    new_coords_data.elements.(element_name) = coords;
                    fprintf('  %s: оставлены относительные координаты\n', element_name);
                else
                    % Конвертируем абсолютные координаты в относительные
                    if length(coords) == 4 && isnumeric(coords)
                        rel_coords = [
                            coords(1) / window_width,   % x
                            coords(2) / window_height,  % y
                            coords(3) / window_width,   % width
                            coords(4) / window_height   % height
                        ];
                        new_coords_data.elements.(element_name) = rel_coords;
                        fprintf('  %s: [%.6f, %.6f, %.6f, %.6f]\n', element_name, rel_coords(1), rel_coords(2), rel_coords(3), rel_coords(4));
                    else
                        % Если формат координат неожиданный, копируем как есть
                        new_coords_data.elements.(element_name) = coords;
                        fprintf('  %s: скопированы как есть (неожиданный формат)\n', element_name);
                    end
                end
            end
            
            % Сохраняем новый JSON файл
            json_str_new = jsonencode(new_coords_data, 'PrettyPrint', true);
            
            fid = fopen(output_file, 'w', 'n', 'UTF-8');
            if fid == -1
                error('Не удалось создать файл: %s', output_file);
            end
            
            fprintf(fid, '%s', json_str_new);
            fclose(fid);
            
            fprintf('Создан файл: %s\n\n', output_file);
            
        catch ME
            fprintf('Ошибка при обработке файла %s: %s\n', input_file, ME.message);
        end
    end
    
    fprintf('Обработка завершена!\n');
end
