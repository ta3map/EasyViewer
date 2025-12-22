function [channel_data, time_vector] = getSignalDataForInterval(lfp, time, channel_idx, time_interval, params)
    % getSignalDataForInterval - получение данных канала для заданного временного интервала
    % Адаптированная версия getCurrentData() из signalAnalysisGUI без зависимостей от UI
    %
    % Входные параметры:
    %   lfp            - матрица данных сигнала [samples x channels]
    %   time           - вектор времени [samples x 1]
    %   channel_idx    - индекс канала (начиная с 1)
    %   time_interval  - [start, end] временной интервал в секундах
    %   params         - структура с параметрами обработки:
    %     .smoothing_enabled    - включить сглаживание (true/false)
    %     .smoothing_span       - размер ядра сглаживания
    %     .smoothing_method     - метод сглаживания ('moving' или 'median')
    %     .remove_artifact      - удалять артефакты стимуляции (true/false)
    %     .artifact_window_ms   - окно удаления артефакта в мс
    %     .stims                - массив времен стимулов
    %     .Fs                   - частота дискретизации
    %     .mean_group_ch        - массив индексов каналов для вычитания среднего (опционально)
    %
    % Выходные параметры:
    %   channel_data   - вектор данных канала [samples x 1]
    %   time_vector    - вектор времени для данных [samples x 1]
    
    % Проверка входных параметров
    if nargin < 5
        params = struct();
    end
    
    % Значения по умолчанию
    if ~isfield(params, 'smoothing_enabled')
        params.smoothing_enabled = false;
    end
    if ~isfield(params, 'smoothing_span')
        params.smoothing_span = 5;
    end
    if ~isfield(params, 'smoothing_method')
        params.smoothing_method = 'moving';
    end
    if ~isfield(params, 'remove_artifact')
        params.remove_artifact = false;
    end
    if ~isfield(params, 'artifact_window_ms')
        params.artifact_window_ms = 0;
    end
    if ~isfield(params, 'stims')
        params.stims = [];
    end
    if ~isfield(params, 'Fs')
        params.Fs = [];
    end
    if ~isfield(params, 'mean_group_ch')
        params.mean_group_ch = [];
    end
    
    % Выборка данных по временному интервалу
    cond = time >= time_interval(1) & time < time_interval(2);
    if ~any(cond)
        channel_data = [];
        time_vector = [];
        return;
    end
    
    local_lfp = lfp(cond, :);
    
    % Вычитание средних каналов если нужно
    if ~isempty(params.mean_group_ch) && any(params.mean_group_ch)
        local_lfp(:, params.mean_group_ch) = local_lfp(:, params.mean_group_ch) - mean(local_lfp(:, params.mean_group_ch), 2);
    end
    
    % Выбор канала
    if channel_idx > size(local_lfp, 2)
        channel_idx = 1;
    end
    channel_data = local_lfp(:, channel_idx);
    time_vector = time(cond);
    
    % Удаление артефакта стимуляции если нужно
    if params.remove_artifact && ~isempty(params.stims) && ~isempty(params.Fs)
        Fs_fascor = params.Fs / 1000;
        channel_data = removeStimArtifact(channel_data, params.stims, time_vector, params.artifact_window_ms * Fs_fascor * 0.5);
    end
    
    % Сглаживание если включено
    if params.smoothing_enabled && params.smoothing_span >= 5
        channel_data = smooth1(channel_data(:), params.smoothing_span, params.smoothing_method);
    end
end




