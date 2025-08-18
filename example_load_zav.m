% ПРИМЕР ИСПОЛЬЗОВАНИЯ load_zav_file.m
% Этот скрипт демонстрирует, как использовать функцию load_zav_file

clear; clc;

% Путь к вашему ZAV файлу (замените на реальный путь)
filepath = 'CC_cur_90V_-70mV_zav.mat';

fprintf('=== ПРИМЕР ЗАГРУЗКИ ZAV ФАЙЛА ===\n\n');

% Пример 1: Базовая загрузка файла
fprintf('1. Базовая загрузка файла:\n');
try
    [lfp, spks, hd, zavp, lfpVar, chnlGrp, time, stims, sweep_info] = load_zav_file(filepath);
    fprintf('✓ Файл успешно загружен!\n\n');
catch ME
    fprintf('✗ Ошибка при загрузке: %s\n\n', ME.message);
    return;
end

% Пример 2: Загрузка с событиями
fprintf('2. Загрузка с событиями:\n');
try
    [lfp, spks, hd, zavp, lfpVar, chnlGrp, time, stims, sweep_info, events, event_comments, event_amplitudes, event_channels, event_widths, event_prominences, event_metadata] = load_zav_file(filepath, 'load_events', true);
    if ~isempty(events)
        fprintf('✓ События загружены: %d штук\n', length(events));
    else
        fprintf('ℹ События не найдены\n');
    end
catch ME
    fprintf('✗ Ошибка при загрузке событий: %s\n', ME.message);
end
fprintf('\n');

% Пример 3: Загрузка с настройками каналов
fprintf('3. Загрузка с настройками каналов:\n');
try
    [lfp, spks, hd, zavp, lfpVar, chnlGrp, time, stims, sweep_info, events, event_comments, event_amplitudes, event_channels, event_widths, event_prominences, event_metadata, channelNames, channelEnabled, scalingCoefficients, colorsIn, lineCoefficients, mean_group_ch, csd_avaliable, filter_avaliable, filterSettings] = load_zav_file(filepath, 'load_events', true, 'load_settings', true);
    fprintf('✓ Настройки каналов загружены\n');
catch ME
    fprintf('✗ Ошибка при загрузке настроек: %s\n', ME.message);
end
fprintf('\n');

% Пример 4: Отключение автоматических настроек
fprintf('4. Загрузка с отключенными автоматическими настройками:\n');
try
    [lfp, spks, hd, zavp, lfpVar, chnlGrp, time, stims, sweep_info] = load_zav_file(filepath, 'auto_set_time_windows', false, 'auto_set_fs', false);
    fprintf('✓ Файл загружен с ручными настройками\n');
catch ME
    fprintf('✗ Ошибка: %s\n', ME.message);
end
fprintf('\n');

% Анализ загруженных данных
fprintf('=== АНАЛИЗ ДАННЫХ ===\n');
fprintf('Размер LFP: %dx%dx%d\n', size(lfp));
fprintf('Размер спайков: %dx%dx%d\n', size(spks));
fprintf('Количество каналов: %d\n', length(hd.recChNames));
fprintf('Длительность записи: %.3f с\n', time(end));
fprintf('Частота дискретизации: %.1f Гц\n', zavp.dwnSmplFrq);

if sweep_info.is_sweep_data
    fprintf('Тип данных: со свипами\n');
    fprintf('Количество свипов: %d\n', sweep_info.sweep_count);
    fprintf('Длительность свипа: %.3f с\n', sweep_info.sweep_duration);
else
    fprintf('Тип данных: непрерывная запись\n');
end

if ~isempty(stims)
    fprintf('Количество стимулов: %d\n', length(stims));
else
    fprintf('Стимулы: отсутствуют\n');
end

if ~isempty(events)
    fprintf('Количество событий: %d\n', length(events));
else
    fprintf('События: отсутствуют\n');
end

fprintf('\n=== ПРИМЕРЫ РАБОТЫ С ДАННЫМИ ===\n');

% Пример построения простого графика
if exist('lfp', 'var') && ~isempty(lfp)
    fprintf('Построение графика первых 3 каналов...\n');
    
    % Выбираем временной интервал для отображения
    if length(time) > 1000
        start_idx = 1;
        end_idx = 1000;
    else
        start_idx = 1;
        end_idx = length(time);
    end
    
    % Создаем график
    figure('Name', 'ZAV Data Preview', 'NumberTitle', 'off');
    
    % Отображаем первые 3 канала
    num_channels_to_plot = min(3, size(lfp, 2));
    for ch = 1:num_channels_to_plot
        subplot(num_channels_to_plot, 1, ch);
        plot(time(start_idx:end_idx), lfp(start_idx:end_idx, ch));
        title(sprintf('Канал %d: %s', ch, hd.recChNames{ch}));
        xlabel('Время (с)');
        ylabel('Амплитуда');
        grid on;
    end
    
    % Добавляем стимулы если они есть
    if ~isempty(stims)
        for ch = 1:num_channels_to_plot
            subplot(num_channels_to_plot, 1, ch);
            hold on;
            for i = 1:min(10, length(stims)) % показываем первые 10 стимулов
                if stims(i) >= time(start_idx) && stims(i) <= time(end_idx)
                    plot([stims(i) stims(i)], ylim, 'r--', 'LineWidth', 2);
                end
            end
            hold off;
        end
    end
    
    fprintf('✓ График построен\n');
else
    fprintf('✗ Данные LFP недоступны для построения графика\n');
end

fprintf('\n=== ЗАВЕРШЕНО ===\n');
fprintf('Функция load_zav_file успешно протестирована!\n');
fprintf('Теперь вы можете использовать её в своих скриптах.\n'); 