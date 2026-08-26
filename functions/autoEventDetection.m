function [events_detected, Trace_out, time_res, amplitudes_detected, widths_detected, channels_detected, metadata_detected, prominences_detected, indices_detected, wasCanceled] = autoEventDetection(params)
    global Fs time newFs lfp_file wb ch_inxs csd_avaliable filterSettings filter_avaliable mean_group_ch 
    global stims_exist stims time art_rem_settings
    
    wasCanceled = false;
    fprintf('Please wait...\n');
    
    if isempty(wb) || ~isvalid(wb)
        wb = createCancelableWaitbar(0, 'Initializing...', 'Event Detection');
    else
        setappdata(wb, 'canceling', 0);
    end
    drawnow;
    waitbar(0.06, wb, 'Preparing data...');
    drawnow;
    if isWaitbarCanceled(wb)
        [events_detected, Trace_out, time_res, amplitudes_detected, widths_detected, channels_detected, metadata_detected, prominences_detected, indices_detected, wasCanceled] = stopCanceledAutoEventDetection(wb);
        return;
    end
    
    % Распаковка параметров из структуры
    DetectionType = params.DetectionType;
    MinPeakProminence = params.MinPeakProminence;
    ChPos = params.ChPos;
    ChNeg = params.ChNeg;
    MinPeakDistance = params.MinPeakDistance;
    SourceType = params.SourceType;
    
    detect = params.detect;
    
    if ~detect
        [Trace_out, time_res, wasCanceled] = previewDetectionTrace(params);
        events_detected = [];
        amplitudes_detected = [];
        widths_detected = [];
        channels_detected = [];
        metadata_detected = [];
        prominences_detected = [];
        indices_detected = [];
        if wasCanceled
            [events_detected, Trace_out, time_res, amplitudes_detected, widths_detected, channels_detected, metadata_detected, prominences_detected, indices_detected, wasCanceled] = stopCanceledAutoEventDetection(wb);
            return;
        end
        waitbar(1.0, wb, 'Complete');
        if ~isempty(wb) && isvalid(wb)
            delete(wb);
        end
        return;
    end
    
    data_in = lfp_file.lfp;
    max_peak_width = params.max_peak_width;
    
    raw_frq = Fs;
    lfp_frq = round(newFs);
    
    % Фильтруем если попросили
    waitbar(0.08, wb, 'Preparing filters...');
    drawnow;
    waitbar(0.1, wb, 'Applying filters...');
    drawnow;
    if isWaitbarCanceled(wb)
        [events_detected, Trace_out, time_res, amplitudes_detected, widths_detected, channels_detected, metadata_detected, prominences_detected, indices_detected, wasCanceled] = stopCanceledAutoEventDetection(wb);
        return;
    end
    try
        if sum(filter_avaliable)>0
            ch_to_filter = find(filter_avaliable);
            waitbar(0.12, wb, sprintf('Applying filters (channels: %d)...', numel(ch_to_filter)));
            drawnow;
            data_in(:, ch_to_filter) = applyFilter(data_in(:, ch_to_filter), filterSettings, newFs);        
        end
    catch ME
        fprintf('An error occurred: %s\n', ME.message);
    end
    if isWaitbarCanceled(wb)
        [events_detected, Trace_out, time_res, amplitudes_detected, widths_detected, channels_detected, metadata_detected, prominences_detected, indices_detected, wasCanceled] = stopCanceledAutoEventDetection(wb);
        return;
    end

    % Убираем артефакт стимула если включено
    waitbar(0.2, wb, 'Removing stimulus artifacts...');
    drawnow;
    if isWaitbarCanceled(wb)
        [events_detected, Trace_out, time_res, amplitudes_detected, widths_detected, channels_detected, metadata_detected, prominences_detected, indices_detected, wasCanceled] = stopCanceledAutoEventDetection(wb);
        return;
    end
    if stims_exist && ~isempty(stims) && art_rem_settings.artifact_window_ms > 0
        win_r = round(art_rem_settings.artifact_window_ms * (Fs/1000));
        data_in = removeStimArtifact(data_in, stims, time, win_r, art_rem_settings.interp_method);
    end
    
    % Вычитаем среднее из запрошенных
    waitbar(0.3, wb, 'Subtracting mean...');
    drawnow;
    if isWaitbarCanceled(wb)
        [events_detected, Trace_out, time_res, amplitudes_detected, widths_detected, channels_detected, metadata_detected, prominences_detected, indices_detected, wasCanceled] = stopCanceledAutoEventDetection(wb);
        return;
    end
    data_in(:, mean_group_ch) = data_in(:, mean_group_ch) - mean(data_in(:, mean_group_ch), 2); % вычитание выбранных средних каналов
    
    % Если источником выбран CSD
    waitbar(0.4, wb, 'Computing CSD...');
    drawnow;
    if isWaitbarCanceled(wb)
        [events_detected, Trace_out, time_res, amplitudes_detected, widths_detected, channels_detected, metadata_detected, prominences_detected, indices_detected, wasCanceled] = stopCanceledAutoEventDetection(wb);
        return;
    end
    switch SourceType
        case 'CSD'
        % Выборка только разрешенных каналов, которым доступен CSD
        allowed_ch_inxs = ch_inxs(csd_avaliable(ch_inxs) == 1);
        waitbar(0.45, wb, sprintf('Computing CSD (channels: %d)...', numel(allowed_ch_inxs)));
        drawnow;
        data_in = -globalCSD(data_in, allowed_ch_inxs);
    end
    if isWaitbarCanceled(wb)
        [events_detected, Trace_out, time_res, amplitudes_detected, widths_detected, channels_detected, metadata_detected, prominences_detected, indices_detected, wasCanceled] = stopCanceledAutoEventDetection(wb);
        return;
    end

    % Создание Trace_out
    waitbar(0.5, wb, 'Creating detection trace...');
    drawnow;
    if isWaitbarCanceled(wb)
        [events_detected, Trace_out, time_res, amplitudes_detected, widths_detected, channels_detected, metadata_detected, prominences_detected, indices_detected, wasCanceled] = stopCanceledAutoEventDetection(wb);
        return;
    end
    switch DetectionType
        case 'two channels difference'

            waitbar(0.55, wb, 'Resampling channels...');
            drawnow;
            NegTrace = resample1(double(data_in(:, ChNeg)), lfp_frq , raw_frq)';
            PosTrace = resample1(double(data_in(:, ChPos)), lfp_frq , raw_frq)';
            Trace_out = PosTrace - NegTrace;
        case 'two channels multiplied'
            waitbar(0.55, wb, 'Resampling channels...');
            drawnow;
            NegTrace = resample1(double(data_in(:, ChNeg)), lfp_frq , raw_frq)';
            PosTrace = resample1(double(data_in(:, ChPos)), lfp_frq , raw_frq)';              
            Trace_out = -(NegTrace.*PosTrace);        
        case 'one channel negative'
            waitbar(0.55, wb, 'Resampling channel...');
            drawnow;
            NegTrace = resample1(double(data_in(:, ChNeg)), lfp_frq , raw_frq)';
            Trace_out = -NegTrace;
        case 'one channel positive'
            waitbar(0.55, wb, 'Resampling channel...');
            drawnow;
            PosTrace = resample1(double(data_in(:, ChPos)), lfp_frq , raw_frq)';
            Trace_out = PosTrace;
    end
    Trace_out(isnan(Trace_out)) = nanmean(Trace_out);
    Trace_out = Trace_out - mean(Trace_out);
    Trace_out = np_flatten(Trace_out);
    
    time_res = linspace(time(1),time(end),numel(Trace_out));
    
    % Параметры временного диапазона (используются только для фильтрации событий)
    UseTimeRange = false;
    StartTime = time(1);
    EndTime = time(end);
    if isfield(params, 'UseTimeRange')
        UseTimeRange = params.UseTimeRange;
    end
    if isfield(params, 'StartTime')
        StartTime = params.StartTime;
    end
    if isfield(params, 'EndTime')
        EndTime = params.EndTime;
    end
    
    % Проверка на пустой Trace_out
    if isempty(Trace_out) || numel(Trace_out) == 0
        if ~isempty(wb) && isvalid(wb)
            delete(wb);
        end
        
        errorMsg = sprintf(['Error: No data available for event detection.\n\n' ...
            'Possible causes:\n' ...
            '1. Time range (Use time range) contains no data\n' ...
            '2. Selected channels contain no data\n' ...
            '3. Data filtering resulted in empty result\n\n' ...
            'Recommendations:\n' ...
            '- Check time range settings\n' ...
            '- Ensure selected channels exist\n' ...
            '- Disable filters or time range and try again']);
        
        uiwait(msgbox(errorMsg, 'Event Detection Error', 'error', 'modal'));
        error('Trace_out is empty - no data available for detection');
    end
    
    waitbar(0.6, wb, 'Preparing detection...');
    drawnow;
    if isWaitbarCanceled(wb)
        [events_detected, Trace_out, time_res, amplitudes_detected, widths_detected, channels_detected, metadata_detected, prominences_detected, indices_detected, wasCanceled] = stopCanceledAutoEventDetection(wb);
        return;
    end
    
    if detect
        fprintf('=== DEBUG: Detection parameters ===\n');
        fprintf('MinPeakProminence: %.3f\n', MinPeakProminence);
        fprintf('MinPeakDistance: %.6f sec (%.6f samples at %d Hz)\n', MinPeakDistance, MinPeakDistance*lfp_frq, lfp_frq);
        fprintf('MaxPeakWidth: %.6f sec (%.6f samples at %d Hz)\n', max_peak_width, max_peak_width*lfp_frq, lfp_frq);
        fprintf('DetectionType: %s\n', DetectionType);
        fprintf('SourceType: %s\n', SourceType);
        fprintf('ChPos: %d, ChNeg: %d\n', ChPos, ChNeg);
        fprintf('\n=== DEBUG: Trace_out statistics ===\n');
        fprintf('Trace_out length: %d samples\n', numel(Trace_out));
        fprintf('Trace_out min: %.3f\n', min(Trace_out));
        fprintf('Trace_out max: %.3f\n', max(Trace_out));
        fprintf('Trace_out mean: %.3f\n', mean(Trace_out));
        fprintf('Trace_out std: %.3f\n', std(Trace_out));
        fprintf('Trace_out median: %.3f\n', median(Trace_out));
        fprintf('Trace_out 99.9%% quantile: %.3f\n', quantile(Trace_out, 0.999));
        fprintf('\n');
        
            % Проверяем, нужно ли искать вокруг стимулов
            SearchAroundStimuli = false;
            SearchWindow = 0;
            SearchAroundDirection = 2; % 1 - two-sided, 2 - after-only
            if isfield(params, 'SearchAroundStimuli')
                SearchAroundStimuli = params.SearchAroundStimuli;
            end
            if isfield(params, 'SearchWindow')
                SearchWindow = params.SearchWindow;
            end
            if isfield(params, 'SearchAroundDirection')
                SearchAroundDirection = params.SearchAroundDirection;
            end
            isTwoSided = (SearchAroundDirection == 1);
        
        % Поиск вокруг стимулов возможен только если не включен временной диапазон
        if SearchAroundStimuli && stims_exist && ~isempty(stims) && ~UseTimeRange
            fprintf('=== DEBUG: Searching around stimuli ===\n');
            fprintf('Number of stimuli: %d\n', length(stims));
            fprintf('Search window: [%.6f..%.6f] sec\n', -SearchWindow*isTwoSided, SearchWindow);
            fprintf('\n');
            
            waitbar(0.65, wb, sprintf('Detecting events around %d stimuli...', length(stims)));
            drawnow;
            if isWaitbarCanceled(wb)
                [events_detected, Trace_out, time_res, amplitudes_detected, widths_detected, channels_detected, metadata_detected, prominences_detected, indices_detected, wasCanceled] = stopCanceledAutoEventDetection(wb);
                return;
            end
            
            % Инициализация массивов для объединения результатов
            all_peak_times = [];
            all_peaks = [];
            all_widths = [];
            all_prominences = [];
            mpdWarningShown = false;
            
            % Детекция в окнах вокруг каждого стимула
            num_stims = length(stims);
            for stim_idx = 1:num_stims
                waitbar(0.65 + 0.25 * (stim_idx / num_stims), wb, ...
                    sprintf('Processing stimulus %d of %d...', stim_idx, num_stims));
                drawnow;
                if isWaitbarCanceled(wb)
                    [events_detected, Trace_out, time_res, amplitudes_detected, widths_detected, channels_detected, metadata_detected, prominences_detected, indices_detected, wasCanceled] = stopCanceledAutoEventDetection(wb);
                    return;
                end
                stim = stims(stim_idx);
                window_start = stim - SearchWindow*isTwoSided;
                window_end = stim + SearchWindow;
                
                % Находим индексы, попадающие в окно
                window_mask = (time_res >= window_start) & (time_res <= window_end);
                
                if sum(window_mask) == 0
                    continue;
                end
                
                % Выделяем участок сигнала
                Trace_out_window = Trace_out(window_mask);
                time_res_window = time_res(window_mask);
                
                % Пропускаем окно, если данных нет
                if isempty(Trace_out_window) || numel(Trace_out_window) == 0
                    continue;
                end
                
                % findpeaks requires MinPeakDistance < (x(end) - x(1)).
                % Here x is time_res_window; if MinPeakDistance is larger than the
                % available time span in the current window, MATLAB throws an error.
                time_span_window = time_res_window(end) - time_res_window(1);
                if MinPeakDistance >= time_span_window
                    if ~mpdWarningShown
                        suggested = max(0, time_span_window - eps(time_span_window));
                        msg = sprintf(['MinPeakDistance is too large for the current search window.\n\n' ...
                            'MATLAB requires: MinPeakDistance < (max(time) - min(time))\n' ...
                            'Current MinPeakDistance: %.6f s\n' ...
                            'Available window time span: %.6f s\n' ...
                            'Suggested maximum value: %.6f s\n\n' ...
                            'Please decrease "Minimal Time Between Peaks" in the GUI and press Detect again.'], ...
                            MinPeakDistance, time_span_window, suggested);
                        uiwait(msgbox(msg, 'MinPeakDistance too large', 'warn', 'modal'));
                        mpdWarningShown = true;
                    end
                    
                    % Abort full detection to avoid repeated findpeaks errors.
                    all_peak_times = [];
                    all_peaks = [];
                    all_widths = [];
                    all_prominences = [];
                    break;
                end
                
                % Детекция в окне
                findpeaks_params = {'MinPeakDistance', MinPeakDistance, 'WidthReference', 'halfheight', 'MinPeakHeight', MinPeakProminence};
                [peaks_window, peak_times_window, widths_window, prominences_window] = ...
                    findpeaks(Trace_out_window, time_res_window, findpeaks_params{:});
                
                % Фильтрация по ширине
                if ~isempty(widths_window)
                    wide_mask = widths_window <= max_peak_width;
                    peaks_window = peaks_window(wide_mask);
                    peak_times_window = peak_times_window(wide_mask);
                    widths_window = widths_window(wide_mask);
                    prominences_window = prominences_window(wide_mask);
                end
                
                % Добавляем результаты в общие массивы
                if ~isempty(peak_times_window)
                    all_peak_times = [all_peak_times; peak_times_window(:)];
                    all_peaks = [all_peaks; peaks_window(:)];
                    all_widths = [all_widths; widths_window(:)];
                    all_prominences = [all_prominences; prominences_window(:)];
                end
            end
            
            fprintf('=== DEBUG: After window detection ===\n');
            fprintf('Total peaks found in all windows: %d\n', length(all_peak_times));
            fprintf('\n');
            
            waitbar(0.9, wb, 'Removing duplicates...');
            drawnow;
            if isWaitbarCanceled(wb)
                [events_detected, Trace_out, time_res, amplitudes_detected, widths_detected, channels_detected, metadata_detected, prominences_detected, indices_detected, wasCanceled] = stopCanceledAutoEventDetection(wb);
                return;
            end
            
            % Удаление дубликатов (если окна перекрываются)
            if ~isempty(all_peak_times)
                [sorted_times, sort_idx] = sort(all_peak_times);
                sorted_peaks = all_peaks(sort_idx);
                sorted_widths = all_widths(sort_idx);
                sorted_prominences = all_prominences(sort_idx);
                
                % Удаляем события, которые слишком близко друг к другу
                unique_mask = true(size(sorted_times));
                for i = 2:length(sorted_times)
                    if (sorted_times(i) - sorted_times(i-1)) < MinPeakDistance
                        unique_mask(i) = false;
                    end
                end
                
                all_peak_times = sorted_times(unique_mask);
                all_peaks = sorted_peaks(unique_mask);
                all_widths = sorted_widths(unique_mask);
                all_prominences = sorted_prominences(unique_mask);
                
                fprintf('=== DEBUG: After duplicate removal ===\n');
                fprintf('Remaining peaks: %d\n', length(all_peak_times));
                fprintf('\n');
            end
            
            if ~isempty(all_peak_times)
                events_detected = all_peak_times(:);
                amplitudes_detected = all_peaks(:);
                widths_detected = all_widths(:);
                prominences = all_prominences(:);
            else
                events_detected = [];
                amplitudes_detected = [];
                widths_detected = [];
                prominences = [];
            end
            
        else
            % Детекция по всему сигналу (как раньше)
            waitbar(0.7, wb, 'Detecting peaks in full signal...');
            drawnow;
            if isWaitbarCanceled(wb)
                [events_detected, Trace_out, time_res, amplitudes_detected, widths_detected, channels_detected, metadata_detected, prominences_detected, indices_detected, wasCanceled] = stopCanceledAutoEventDetection(wb);
                return;
            end
            
            % Проверка на пустой Trace_out перед вызовом findpeaks
            if isempty(Trace_out) || numel(Trace_out) == 0
                if ~isempty(wb) && isvalid(wb)
                    delete(wb);
                end
                
                errorMsg = sprintf(['Ошибка: Нет данных для детекции событий.\n\n' ...
                    'Возможные причины:\n' ...
                    '1. Временной диапазон (Use time range) не содержит данных\n' ...
                    '2. Выбранные каналы не содержат данных\n' ...
                    '3. Фильтрация данных привела к пустому результату\n\n' ...
                    'Рекомендации:\n' ...
                    '- Проверьте настройки временного диапазона\n' ...
                    '- Убедитесь, что выбранные каналы существуют\n' ...
                    '- Отключите фильтры или временной диапазон и попробуйте снова']);
                
                uiwait(msgbox(errorMsg, 'Ошибка детекции событий', 'error', 'modal'));
                error('Trace_out is empty - no data available for detection');
            end
            
            findpeaks_params = {'MinPeakDistance', MinPeakDistance, 'WidthReference', 'halfheight', 'MinPeakHeight', MinPeakProminence};
            [peaks,peak_times,widths,prominences] = findpeaks(Trace_out, time_res, findpeaks_params{:});
            
            fprintf('=== DEBUG: After findpeaks ===\n');
            fprintf('Found %d peaks\n', length(peaks));
            if ~isempty(peaks)
                fprintf('Peak amplitudes range: [%.3f, %.3f]\n', min(peaks), max(peaks));
                fprintf('Peak widths range: [%.6f, %.6f] sec\n', min(widths), max(widths));
                fprintf('Peak prominences range: [%.3f, %.3f]\n', min(prominences), max(prominences));
            end
            fprintf('\n');
            
            waitbar(0.85, wb, 'Filtering peaks by width...');
            drawnow;
            if isWaitbarCanceled(wb)
                [events_detected, Trace_out, time_res, amplitudes_detected, widths_detected, channels_detected, metadata_detected, prominences_detected, indices_detected, wasCanceled] = stopCanceledAutoEventDetection(wb);
                return;
            end
            
            % убираем слишком широкие пики
            wide_peaks_mask = widths > max_peak_width;
            num_wide_peaks = sum(wide_peaks_mask);
            peak_times(wide_peaks_mask) = [];
            peaks(wide_peaks_mask) = [];
            widths(wide_peaks_mask) = [];
            prominences(wide_peaks_mask) = [];
            
            fprintf('=== DEBUG: After width filtering ===\n');
            fprintf('Removed %d peaks (too wide, > %.6f sec)\n', num_wide_peaks, max_peak_width);
            fprintf('Remaining peaks: %d\n', length(peaks));
            fprintf('\n');
            
            events_detected = peak_times(:);
            amplitudes_detected = peaks(:);
            widths_detected = widths(:);
            prominences = prominences(:);
        end

        if UseTimeRange
            time_mask = events_detected >= StartTime & events_detected <= EndTime;
            events_detected = events_detected(time_mask);
            amplitudes_detected = amplitudes_detected(time_mask);
            widths_detected = widths_detected(time_mask);
            prominences = prominences(time_mask);
        end
        
        waitbar(0.95, wb, 'Finalizing results...');
        drawnow;
        if isWaitbarCanceled(wb)
            [events_detected, Trace_out, time_res, amplitudes_detected, widths_detected, channels_detected, metadata_detected, prominences_detected, indices_detected, wasCanceled] = stopCanceledAutoEventDetection(wb);
            return;
        end
        
        % Формируем каналы и метаданные (всегда N x K, K >= 1)
        nEv = length(events_detected);
        if strcmp(DetectionType, 'two channels difference') || strcmp(DetectionType, 'two channels multiplied')
            channels_detected = repmat([ChPos, ChNeg], nEv, 1);
        elseif strcmp(DetectionType, 'one channel positive')
            channels_detected = repmat(ChPos, nEv, 1);
        elseif strcmp(DetectionType, 'one channel negative')
            channels_detected = repmat(ChNeg, nEv, 1);
        else
            channels_detected = ones(nEv, 1);
        end
        
        % Создаем метаданные для каждого события
        metadata_detected = repmat(struct(...
            'source', 'auto', ...
            'method', 'peaks', ...
            'data_type', SourceType, ...
            'polarity', DetectionType, ...
            'prominence', NaN, ...
            'detection_params', struct(...
                'MinPeakProminence', MinPeakProminence, ...
                'MinPeakDistance', MinPeakDistance, ...
                'MaxPeakWidth', max_peak_width ...
            ) ...
        ), length(events_detected), 1);
        
        % Добавляем prominence для каждого события
        prominences_detected = prominences(:);
        for i = 1:length(events_detected)
            metadata_detected(i).prominence = prominences(i);
        end
        
        % Индексы в исходной шкале time (создаются при детекции, без поиска при сохранении)
        indices_detected = ClosestIndex(events_detected, time, true);
        
        fprintf('=== DEBUG: Final results ===\n');
        fprintf('Total events detected: %d\n', length(events_detected));
        fprintf('===================================\n\n');
        
    end
    
    waitbar(1.0, wb, 'Complete');
    fprintf('Events detected.\n');
    if ~isempty(wb) && isvalid(wb)
        delete(wb);
    end
end

function [Trace_out, time_res, wasCanceled] = previewDetectionTrace(params)
    global Fs time newFs lfp_file wb filterSettings filter_avaliable
    global stims_exist stims art_rem_settings

    wasCanceled = false;
    DetectionType = params.DetectionType;
    ChPos = params.ChPos;
    ChNeg = params.ChNeg;
    SourceType = params.SourceType;
    nSamples = size(lfp_file.lfp, 1);
    nChannels = size(lfp_file.lfp, 2);

    switch DetectionType
        case {'two channels difference', 'two channels multiplied'}
            chs = [ChPos, ChNeg];
        case 'one channel negative'
            chs = ChNeg;
        case 'one channel positive'
            chs = ChPos;
    end
    if strcmp(SourceType, 'CSD')
        chs = [chs, chs - 1, chs + 1];
    end
    chs = unique(chs);
    chs = chs(chs >= 1 & chs <= nChannels);

    step = max(1, round(Fs / newFs));
    idx = 1:step:nSamples;
    if params.UseTimeRange
        idx = idx(time(idx) >= params.StartTime & time(idx) <= params.EndTime);
    end

    waitbar(0.3, wb, 'Preview: reading channel...');
    drawnow;
    if isWaitbarCanceled(wb)
        wasCanceled = true;
        Trace_out = [];
        time_res = [];
        return;
    end
    traces = double(lfp_file.lfp(idx, chs));

    waitbar(0.55, wb, 'Preview: filtering...');
    drawnow;
    if isWaitbarCanceled(wb)
        wasCanceled = true;
        Trace_out = [];
        time_res = [];
        return;
    end
    filtMask = logical(filter_avaliable(chs));
    if any(filtMask)
        traces(:, filtMask) = applyFilter(traces(:, filtMask), filterSettings, newFs);
    end

    if stims_exist && ~isempty(stims) && art_rem_settings.artifact_window_ms > 0
        win_r = max(1, round(art_rem_settings.artifact_window_ms * (Fs / 1000) / step));
        traces = removeStimArtifact(traces, stims, time(idx), win_r, art_rem_settings.interp_method);
    end

    waitbar(0.75, wb, 'Preview: building trace...');
    drawnow;
    pos = previewSourceColumn(traces, chs, ChPos, SourceType, nChannels);
    neg = previewSourceColumn(traces, chs, ChNeg, SourceType, nChannels);
    switch DetectionType
        case 'two channels difference'
            Trace_out = pos - neg;
        case 'two channels multiplied'
            Trace_out = -(neg .* pos);
        case 'one channel negative'
            Trace_out = -neg;
        case 'one channel positive'
            Trace_out = pos;
    end

    Trace_out(isnan(Trace_out)) = nanmean(Trace_out);
    Trace_out = Trace_out - mean(Trace_out);
    Trace_out = np_flatten(Trace_out);
    time_res = time(idx);
end

function col = previewSourceColumn(traces, chs, ch, SourceType, nChannels)
    col = previewChannelColumn(traces, chs, ch);
    if strcmp(SourceType, 'CSD')
        col = zeros(size(traces, 1), 1);
        if ch > 1 && ch < nChannels
            col = -(previewChannelColumn(traces, chs, ch - 1) - 2 * previewChannelColumn(traces, chs, ch) + previewChannelColumn(traces, chs, ch + 1));
        end
    end
end

function col = previewChannelColumn(traces, chs, ch)
    col = zeros(size(traces, 1), 1);
    mask = (chs == ch);
    if any(mask)
        col = traces(:, mask);
    end
end

function [events_detected, Trace_out, time_res, amplitudes_detected, widths_detected, channels_detected, metadata_detected, prominences_detected, indices_detected, wasCanceled] = stopCanceledAutoEventDetection(wb)
    wasCanceled = true;
    events_detected = [];
    Trace_out = [];
    time_res = [];
    amplitudes_detected = [];
    widths_detected = [];
    channels_detected = [];
    metadata_detected = [];
    prominences_detected = [];
    indices_detected = [];
    fprintf('Event detection stopped by user.\n');
    if ~isempty(wb) && isvalid(wb)
        delete(wb);
    end
end
