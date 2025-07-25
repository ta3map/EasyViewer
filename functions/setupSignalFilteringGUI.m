function setupSignalFilteringGUI()
    % Глобальные переменные
    global newFs data time chosen_time_interval time_back lfp m_coef
    global ch_inxs channelNames filter_avaliable numChannels matFilePath local_settings
    global filterSettings
    global high_line_enable low_line_enable

    % Идентификатор (tag) для GUI фигуры
    figTag = 'SignalFiltering';
    if activateOrCreateFigure(figTag)
        return
    end
    
    if isempty(filter_avaliable)
        filter_avaliable = false(numChannels, 1);% Ни один канал не участвует в усреднении
    end
    
    % Создание и настройка главного окна
    fig = figure('Name', 'Signal Filtering', 'Tag', figTag, ...
        'NumberTitle', 'off', ...
        'MenuBar', 'none', 'ToolBar', 'none', 'Position', [100, 100, 450, 600], ...
        'Resize', 'off',  'WindowStyle', 'modal');
    
    % Таблица для выбора каналов
    tableData = [channelNames(ch_inxs); num2cell(filter_avaliable(ch_inxs))]';
    SubMeanSettings_coords = [10, 300, 300, 300];
    hTable = uitable('Parent', fig, 'Data', tableData, ...
        'ColumnName', {'Channel', 'Enabled'}, ...
        'ColumnFormat', {'char', 'logical'}, ...
        'ColumnEditable', [false true], ...
        'Position', SubMeanSettings_coords, 'CellEditCallback', @checkbtns);
    
    % Выбор типа фильтра
    % Сопоставление типов фильтров с их позициями в списке
    filterTypes = {'highpass', 'bandpass', 'lowpass'};
    filterIndex = find(strcmp(filterSettings.filterType, filterTypes));

    % Проверка, что filterSettings.filterType содержит допустимое значение
    if isempty(filterIndex)
        filterIndex = 1; % Выберите значение по умолчанию, если текущее значение недопустимо
    end
    
    % Создание выпадающего списка с выбранным значением
    hFilterType = uicontrol('Style', 'popup', 'String', filterTypes, ...
        'Position', [320, 550, 100, 25], 'Callback', @filterTypeCallback, ...
        'Value', filterIndex);

    % Поля для ввода частот обрезки с подписями 'Hz'
    uicontrol('Style', 'text', 'Position', [320, 535, 30, 15], 'String', 'Hz', 'HorizontalAlignment', 'left');
    hFreqLow = uicontrol('Style', 'edit', 'Position', [320, 510, 50, 25], 'Enable', 'on', 'String', num2str(filterSettings.freqLow));

    uicontrol('Style', 'text', 'Position', [380, 535, 30, 15], 'String', 'Hz', 'HorizontalAlignment', 'left');
    hFreqHigh = uicontrol('Style', 'edit', 'Position', [380, 510, 50, 25], 'Enable', 'on', 'String', num2str(filterSettings.freqHigh));

    % Поле для ввода порядка фильтра
    uicontrol('Style', 'text', 'Position', [320, 480, 110, 15], 'String', 'Filter Order:', 'HorizontalAlignment', 'left');
    hOrder = uicontrol('Style', 'edit', 'Position', [320, 455, 50, 25], 'String', filterSettings.order);  % Значение по умолчанию 4

    
    % Ось для отображения графика
    ax = axes('Parent', fig, 'Position', [.1 .1 .8 .35]);
    xlabel('Frequency (Hz)');
    ylabel('Power/Frequency (dB/Hz)');
    title('Frequency Response');
    grid on;
    set(ax, 'Visible', 'off');    
    
    
    % Кнопка для нажатия всех каналов
    uicontrol('Style', 'pushbutton', 'String', 'Select ALL', 'Position', [320, 400, 110, 25], 'Callback', @selectAll);
    % Кнопка для отжатия всех каналов
    uicontrol('Style', 'pushbutton', 'String', 'Deselect ALL', 'Position', [320, 370, 110, 25], 'Callback', @deselectAll);
    
    % Кнопка для проверки фильтрации
    checkfiltbtn = uicontrol('Style', 'pushbutton', 'String', 'Check Filtration', 'Position', [320, 320, 110, 25], 'Enable', 'on', 'Callback', {@checkFiltration, ax});
    % Кнопка применения настроек
    uicontrol('Style', 'pushbutton', 'String', 'Apply', 'Position', [320, 290, 70, 25], 'Enable', 'on', 'Callback', @applySettings);
    % Кнопка отмены
    uicontrol('Style', 'pushbutton', 'String', 'Cancel', 'Position', [320, 260, 70, 25], 'Enable', 'on', 'Callback', @cancelSettings);
    
    % вызов callback для адекватности отображения окон
    filterTypeCallback(hFilterType)
    
    uiwait(fig);
    
    % Функции обратного вызова
    function selectAll(~, ~)
        hTable.Data(:,2) = num2cell(true(size(hTable.Data(:,2))));
        set(checkfiltbtn, 'Enable', 'on');
    end
    
    function deselectAll(~, ~)
        hTable.Data(:,2) = num2cell(false(size(hTable.Data(:,2))));
        axes(ax); cla(ax);
        set(ax, 'Visible', 'off');
%         set(applybtn, 'Enable', 'on');
        set(checkfiltbtn, 'Enable', 'off');
    end
    
    function checkbtns(~, ~)
        if sum(cell2mat(hTable.Data(:, 2)))>0
            set(checkfiltbtn, 'Enable', 'on');
        else
            set(checkfiltbtn, 'Enable', 'off');
        end
    end

    function filterTypeCallback(src, ~)
        switch src.Value
            case 1 % highpass
                set(hFreqLow, 'Enable', 'on');
                low_line_enable = true;   
                set(hFreqHigh, 'Enable', 'off');
                high_line_enable = false;
            case 2 % bandpass
                set(hFreqLow, 'Enable', 'on');
                low_line_enable = true;   
                set(hFreqHigh, 'Enable', 'on');
                high_line_enable = true;
            case 3 % lowpass
                set(hFreqLow, 'Enable', 'off');
                low_line_enable = false;                
                set(hFreqHigh, 'Enable', 'on');                
                high_line_enable = true;
        end
    end

    function checkFiltration(~, ~, ax)
        % Получение выбранных каналов и параметров фильтрации
        selectedChannels = find(cell2mat(hTable.Data(:,2)));
        
        if not(isempty(selectedChannels))
            set(ax, 'Visible', 'on');
            
            freqLow = str2double(hFreqLow.String);
            freqHigh = str2double(hFreqHigh.String);



            local_settings.filterType = hFilterType.String{hFilterType.Value};
            local_settings.freqLow = str2double(hFreqLow.String);
            local_settings.freqHigh = str2double(hFreqHigh.String);
            local_settings.order = str2double(hOrder.String);
            local_settings.channelsToFilter = find(cell2mat(hTable.Data(:, 2)));
            
            % Выборка данных в заданном временном интервале
            plot_time_interval = chosen_time_interval;
            plot_time_interval(1) = plot_time_interval(1) - time_back;

            cond = time >= plot_time_interval(1) & time < plot_time_interval(2);
            local_lfp = lfp(cond, :);% все каналы данного участка времени
            data = local_lfp(:, ch_inxs).*m_coef;

            filtered_data = applyFilter(data(:, selectedChannels), local_settings, newFs);        

            % Расчет частотной характеристики
            incomingData = sum(data(:, selectedChannels), 2); % Сумма выбранных каналов
            [Pxx, F] = pwelch(incomingData, [], [], [], newFs); % Спектральная плотность мощности

            outcomingData = sum(filtered_data, 2); % Сумма выбранных каналов
            [PxxOut, F_out] = pwelch(outcomingData, [], [], [], newFs); % Спектральная плотность мощности

            % Отображение частотной характеристики
            axes(ax); cla(ax);
            hold on
            plot(F, 10*log10(Pxx));
            plot(F_out, 10*log10(PxxOut));
            

            % Отображение выбранных частот обрезки
            hold on;
            if low_line_enable
                xline(freqLow, ':b', 'LineWidth', 1.5);
            end
            if high_line_enable
                xline(freqHigh, ':r', 'LineWidth', 1.5);
            end
            hold off;
        else
            axes(ax); cla(ax);
            set(ax, 'Visible', 'off');
            text(0.5, 0.5, 'Channels are not selected', 'color', 'r', 'horizontalalignment', 'center')
        end
        
        
%         set(applybtn, 'Enable', 'on');
    end

    function applySettings(~, ~)
        local_settings.filterType = hFilterType.String{hFilterType.Value};
        local_settings.freqLow = str2double(hFreqLow.String);
        local_settings.freqHigh = str2double(hFreqHigh.String);
        local_settings.order = str2double(hOrder.String);
        local_settings.channelsToFilter = find(cell2mat(hTable.Data(:, 2)));
        % обновляем глобальную переменную для фильтрации
        
        filterSettings = local_settings;
        filter_avaliable = false(numChannels, 1);
        filter_avaliable(ch_inxs(cell2mat(hTable.Data(:, 2)))) = true;
        filter_avaliable = np_flatten(filter_avaliable);
        [path, name, ~] = fileparts(matFilePath);
        channelSettingsFilePath = fullfile(path, [name '_channelSettings.stn']);
        save(channelSettingsFilePath, 'filter_avaliable', 'filterSettings', '-append');
        
        updatePlot(); % функция для обновления графика
        uiresume(fig);
        close(fig); % закрытие GUI
    end
    
    function cancelSettings(~, ~)
        uiresume(fig);
        close(fig); % закрытие GUI
    end
end

