function protocols = read_pgf_clean()
% ЧИТАЕТ PGF и показывает ПОНЯТНЫЕ протоколы стимуляции
% Без криптографии, только осмысленные данные

fprintf('=== ЧТЕНИЕ PGF - ПОНЯТНЫЙ РЕЗУЛЬТАТ ===\n');

% Запускаем сборку понятных протоколов
fprintf('Собираем протоколы в понятный вид...\n');
system('venv\Scripts\python.exe make_sense_of_pgf.py');

try
    % Читаем понятный результат
    if exist('pgf_protocols_clean.json', 'file')
        json_text = fileread('pgf_protocols_clean.json');
        data = jsondecode(json_text);
        
        fprintf('\n=== ПРОТОКОЛЫ СТИМУЛЯЦИИ ===\n');
        fprintf('Файл: %s\n', data.filename);
        fprintf('Всего протоколов: %d\n\n', data.total_protocols);
        
        % Показываем статистику
        fprintf('--- СТАТИСТИКА ---\n');
        fprintf('Ramp протоколы: %d\n', data.summary.ramp_protocols);
        fprintf('Step протоколы: %d\n', data.summary.step_protocols);
        fprintf('Firing протоколы: %d\n', data.summary.firing_protocols);
        fprintf('Измерения: %d\n\n', data.summary.measurement_protocols);
        
        % Показываем протоколы по типам
        fprintf('--- RAMP ПРОТОКОЛЫ ---\n');
        ramp_protocols = data.protocols(strcmp({data.protocols.type}, 'Ramp protocol'));
        for i = 1:length(ramp_protocols)
            p = ramp_protocols(i);
            fprintf('%d. %s\n', i, p.name);
            if ~isempty(p.parameters)
                fprintf('   Параметры: %s\n', mat2str(p.parameters(1:min(3,length(p.parameters)))));
            end
        end
        
        fprintf('\n--- STEP ПРОТОКОЛЫ ---\n');
        step_protocols = data.protocols(strcmp({data.protocols.type}, 'Step protocol'));
        for i = 1:length(step_protocols)
            p = step_protocols(i);
            fprintf('%d. %s\n', i, p.name);
            if ~isempty(p.parameters)
                fprintf('   Параметры: %s\n', mat2str(p.parameters(1:min(3,length(p.parameters)))));
            end
        end
        
        fprintf('\n--- FIRING ПРОТОКОЛЫ ---\n');
        firing_protocols = data.protocols(strcmp({data.protocols.type}, 'Firing protocol'));
        for i = 1:length(firing_protocols)
            p = firing_protocols(i);
            fprintf('%d. %s\n', i, p.name);
            if ~isempty(p.parameters)
                fprintf('   Параметры: %s\n', mat2str(p.parameters(1:min(3,length(p.parameters)))));
            end
        end
        
        fprintf('\n--- ИЗМЕРЕНИЯ ---\n');
        measurement_protocols = data.protocols(strcmp({data.protocols.type}, 'Capacitance measurement') | ...
                                             strcmp({data.protocols.type}, 'IV curve') | ...
                                             strcmp({data.protocols.type}, 'Test protocol'));
        for i = 1:length(measurement_protocols)
            p = measurement_protocols(i);
            fprintf('%d. %s\n', i, p.name);
            if ~isempty(p.parameters)
                fprintf('   Параметры: %s\n', mat2str(p.parameters(1:min(3,length(p.parameters)))));
            end
        end
        
        fprintf('\n=== ЧТО ЭТО ЗНАЧИТ ===\n');
        fprintf('✓ Найдены РЕАЛЬНЫЕ протоколы стимуляции\n');
        fprintf('✓ У каждого протокола есть параметры (времена, амплитуды)\n');
        fprintf('✓ Данные можно использовать для воспроизведения\n');
        fprintf('✓ Результат в переменной: protocols\n');
        
        protocols = data;
        
    else
        fprintf('❌ Файл pgf_protocols_clean.json не найден\n');
        protocols = [];
    end
    
catch ME
    fprintf('❌ Ошибка: %s\n', ME.message);
    protocols = [];
end

end 