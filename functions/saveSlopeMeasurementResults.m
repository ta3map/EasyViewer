function result_info = saveSlopeMeasurementResults(slope_measurement_results, excel_path, timeUnitFactor, matFilePath, matFileName, params)
    % saveSlopeMeasurementResults - сохранение результатов в Excel и .meta файлы
    % Адаптированная версия saveResults() из signalAnalysisGUI без диалога выбора файла
    %
    % Входные параметры:
    %   slope_measurement_results - массив структур результатов
    %   excel_path                - полный путь для Excel файла (с расширением .xlsx)
    %   timeUnitFactor            - множитель единиц времени
    %   matFilePath               - путь к исходному файлу (опционально)
    %   matFileName               - имя исходного файла (опционально)
    %
    % Выходные параметры:
    %   result_info - структура с путями к сохраненным файлам:
    %     .excel_path - путь к Excel файлу
    %     .meta_path  - путь к .meta файлу
    %     .success    - флаг успешного сохранения
    
    result_info = struct('excel_path', '', 'meta_path', '', 'success', false);
    
    if isempty(slope_measurement_results)
        return;
    end
    
    % Получаем базовое имя файла без расширения
    [pathname, basename, ~] = fileparts(excel_path);
    meta_path = fullfile(pathname, [basename, '.meta']);
    
    % Названия колонок (как в signalAnalysisGUI)
    table_column_names = {'Stimulus', 'Slope', 'Peak Time (rel)', 'Peak Time (abs)', 'Peak Amplitude', 'Peak Value (rel)', 'Onset Time (rel)', 'Onset Time (abs)', 'Peak - Onset', 'Baseline', 'Channel', 'Stim Time', 'Info'};
    
    try
        % Подготавливаем данные для Excel
        excel_data = cell(length(slope_measurement_results) + 1, 13);
        
        % Используем те же названия колонок что и в таблице
        excel_data(1, :) = table_column_names;
        
        % Данные
        for i = 1:length(slope_measurement_results)
            metadata = slope_measurement_results(i).metadata;
            
            % Относительное время пика
            peak_time_rel = slope_measurement_results(i).peak_time * timeUnitFactor;
            
            % Абсолютное время пика
            peak_time_abs = (slope_measurement_results(i).peak_time + metadata.rel_shift) * timeUnitFactor;
            
            % Относительное время онсета
            onset_time_rel = slope_measurement_results(i).onset_time * timeUnitFactor;
            
            % Абсолютное время онсета
            onset_time_abs = (slope_measurement_results(i).onset_time + metadata.rel_shift) * timeUnitFactor;
            
            % Номер стимула
            stimulus_number = metadata.stim_inx;
            
            % Разность времени пика и онсета
            peak_onset_diff = (slope_measurement_results(i).peak_time - slope_measurement_results(i).onset_time) * timeUnitFactor;
            
            excel_data{i+1, 1} = stimulus_number;
            excel_data{i+1, 2} = slope_measurement_results(i).slope_value;
            excel_data{i+1, 3} = peak_time_rel;
            excel_data{i+1, 4} = peak_time_abs;
            excel_data{i+1, 5} = slope_measurement_results(i).peak_value;
            excel_data{i+1, 6} = slope_measurement_results(i).peak_value - slope_measurement_results(i).baseline_value; % Peak Value (rel)
            excel_data{i+1, 7} = onset_time_rel;
            excel_data{i+1, 8} = onset_time_abs;
            excel_data{i+1, 9} = peak_onset_diff;
            excel_data{i+1, 10} = slope_measurement_results(i).baseline_value;
            excel_data{i+1, 11} = metadata.channel;
            excel_data{i+1, 12} = metadata.stim_time; % Stim Time
            excel_data{i+1, 13} = getNavigationStatusText(metadata);
        end
        
        % Добавляем пустую строку после основных данных
        excel_data{end+1, 1} = '';
        
        % Добавляем заголовок для средних значений
        excel_data{end+1, 1} = 'Average Values';
        
        % Добавляем названия колонок для средних значений
        excel_data{end+1, 2} = 'Slope';
        excel_data{end, 3} = 'Peak Time (rel)';
        excel_data{end, 5} = 'Peak Amplitude';
        excel_data{end, 6} = 'Peak Value (rel)';
        excel_data{end, 7} = 'Onset Time (rel)';
        excel_data{end, 8} = 'Onset Time (abs)';
        excel_data{end, 9} = 'Peak - Onset';
        excel_data{end, 10} = 'Baseline';
        
        % Вычисляем средние значения
        slope_values = [slope_measurement_results.slope_value];
        peak_time_rel_values = [slope_measurement_results.peak_time] * timeUnitFactor;
        peak_amplitude_values = [slope_measurement_results.peak_value];
        peak_value_rel_values = peak_amplitude_values - [slope_measurement_results.baseline_value];
        onset_time_rel_values = [slope_measurement_results.onset_time] * timeUnitFactor;
        baseline_values = [slope_measurement_results.baseline_value];
        peak_onset_diff_values = ([slope_measurement_results.peak_time] - [slope_measurement_results.onset_time]) * timeUnitFactor;
        
        % Добавляем средние значения
        excel_data{end+1, 2} = mean(slope_values, 'omitnan');
        excel_data{end, 3} = mean(peak_time_rel_values, 'omitnan');
        excel_data{end, 5} = mean(peak_amplitude_values, 'omitnan');
        excel_data{end, 6} = mean(peak_value_rel_values, 'omitnan');
        excel_data{end, 7} = mean(onset_time_rel_values, 'omitnan');
        excel_data{end, 9} = mean(peak_onset_diff_values, 'omitnan');
        excel_data{end, 10} = mean(baseline_values, 'omitnan');
        
        % Добавляем стандартные отклонения
        excel_data{end+1, 1} = 'Standard Deviation';
        excel_data{end+1, 2} = std(slope_values, 'omitnan');
        excel_data{end, 3} = std(peak_time_rel_values, 'omitnan');
        excel_data{end, 5} = std(peak_amplitude_values, 'omitnan');
        excel_data{end, 6} = std(peak_value_rel_values, 'omitnan');
        excel_data{end, 7} = std(onset_time_rel_values, 'omitnan');
        excel_data{end, 9} = std(peak_onset_diff_values, 'omitnan');
        excel_data{end, 10} = std(baseline_values, 'omitnan');
        
        % Сохраняем Excel файл
        writecell(excel_data, excel_path);
        
        % Создаем структуру с средними значениями для сохранения в .meta файл
        average_values = struct();
        average_values.slope = mean(slope_values, 'omitnan');
        average_values.peak_time_rel = mean(peak_time_rel_values, 'omitnan');
        average_values.peak_amplitude = mean(peak_amplitude_values, 'omitnan');
        average_values.peak_value_rel = mean(peak_value_rel_values, 'omitnan');
        average_values.onset_time_rel = mean(onset_time_rel_values, 'omitnan');
        average_values.baseline = mean(baseline_values, 'omitnan');
        
        % Добавляем стандартные отклонения
        average_values.std_slope = std(slope_values, 'omitnan');
        average_values.std_peak_time_rel = std(peak_time_rel_values, 'omitnan');
        average_values.std_peak_amplitude = std(peak_amplitude_values, 'omitnan');
        average_values.std_peak_value_rel = std(peak_value_rel_values, 'omitnan');
        average_values.std_onset_time_rel = std(onset_time_rel_values, 'omitnan');
        average_values.std_baseline = std(baseline_values, 'omitnan');
        
        % Сохраняем информацию об оригинальном файле
        original_file_info = struct();
        if nargin >= 4 && ~isempty(matFilePath)
            original_file_info.matFilePath = matFilePath;
        else
            original_file_info.matFilePath = '';
        end
        if nargin >= 5 && ~isempty(matFileName)
            original_file_info.matFileName = matFileName;
        else
            original_file_info.matFileName = '';
        end
        original_file_info.timestamp = datestr(now);
        
        % Сохраняем метаданные в .meta файл (фактически .mat формат)
        if nargin >= 6 && ~isempty(params)
            save(meta_path, 'slope_measurement_results', 'average_values', 'original_file_info', 'params', '-v7.3');
        else
            save(meta_path, 'slope_measurement_results', 'average_values', 'original_file_info', '-v7.3');
        end
        
        result_info.excel_path = excel_path;
        result_info.meta_path = meta_path;
        result_info.success = true;
        
    catch ME
        result_info.success = false;
        result_info.error = ME.message;
        rethrow(ME);
    end
end

