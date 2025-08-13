function [signal_data, time_data] = getSignalDataForResult(metadata)
    % Получает данные сигнала для конкретного результата
    
    % Глобальные переменные для доступа к данным
    global lfp time time_back hd
    global newFs Fs timeUnitFactor selectedUnit
    global filterSettings filter_avaliable mean_group_ch
    global selectedCenter events stims sweep_info event_inx stim_inx sweep_inx events_exist stims_exist
    
    try
        fprintf('DEBUG: getSignalDataForResult - начало обработки\n');
        
        % Используем ЛОКАЛЬНУЮ копию, НЕ изменяем глобальную переменную
        local_chosen_time_interval = metadata.chosen_time_interval;
        
        fprintf('DEBUG: Временной интервал: [%.3f, %.3f]\n', local_chosen_time_interval(1), local_chosen_time_interval(2));
        
        % Получаем данные для этого временного интервала
        plot_time_interval = local_chosen_time_interval;
        plot_time_interval(1) = plot_time_interval(1) - time_back;
        
        fprintf('DEBUG: Расширенный интервал: [%.3f, %.3f]\n', plot_time_interval(1), plot_time_interval(2));
        
        cond = time >= plot_time_interval(1) & time < plot_time_interval(2);
        local_lfp = lfp(cond, :);
        
        fprintf('DEBUG: Размер local_lfp: %s\n', mat2str(size(local_lfp)));
        
        % Вычитание средних каналов если нужно
        if ~isempty(mean_group_ch) && any(mean_group_ch)
            local_lfp(:, mean_group_ch) = local_lfp(:, mean_group_ch) - mean(local_lfp(:, mean_group_ch), 2);
        end
        
        selected_channel = metadata.channel;
        signal_data = local_lfp(:, selected_channel)';
        time_data = time(cond);
        
        fprintf('DEBUG: Исходный размер signal_data: %s, time_data: %s\n', ...
            mat2str(size(signal_data)), mat2str(size(time_data)));
        
        % Нормализуем время относительно rel_shift
        if strcmp(metadata.selectedCenter, 'stimulus') && stims_exist && ~isempty(stims)
            local_rel_shift = stims(metadata.stim_inx);
        else
            local_rel_shift = local_chosen_time_interval(1);
        end
        
        fprintf('DEBUG: rel_shift для нормализации = %.3f\n', local_rel_shift);
        fprintf('DEBUG: Время до нормализации: [%.3f, %.3f, %.3f, %.3f, %.3f]\n', ...
            time_data(1:min(5, length(time_data))));
        
        time_data = time_data - local_rel_shift;
        
        fprintf('DEBUG: Время после нормализации: [%.3f, %.3f, %.3f, %.3f, %.3f]\n', ...
            time_data(1:min(5, length(time_data))));
        
        % Фильтрация если включена
        if sum(filter_avaliable) > 0 && filter_avaliable(selected_channel)
            signal_data = applyFilter(signal_data, filterSettings, newFs);
            fprintf('DEBUG: После фильтрации - размер signal_data: %s\n', mat2str(size(signal_data)));
        end
        
        % Ресэмплинг убран - используем исходные данные
        fprintf('DEBUG: Ресэмплинг пропущен - используем исходные данные\n');
        
        fprintf('DEBUG: getSignalDataForResult - финальный размер signal_data: %s, time_data: %s\n', ...
            mat2str(size(signal_data)), mat2str(size(time_data)));
        
    catch ME
        fprintf('❌ Ошибка при получении данных для результата: %s\n', ME.message);
        signal_data = [];
        time_data = [];
    end
end 