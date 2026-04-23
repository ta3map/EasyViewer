function wasApplied = setupSignalFilteringGUI()
    % Глобальные переменные
    global newFs data time chosen_time_interval time_back lfp_file m_coef
    global ch_inxs channelNames filter_avaliable numChannels matFilePath local_settings
    global filterSettings
    global high_line_enable low_line_enable

    % Идентификатор (tag) для GUI фигуры
    figTag = 'SignalFiltering';
    wasApplied = false;
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
    
    filterEnabledVal = true;
    if isfield(filterSettings, 'filterEnabled')
        filterEnabledVal = filterSettings.filterEnabled;
    end
    smoothEnabledVal = true;
    if isfield(filterSettings, 'smoothEnabled')
        smoothEnabledVal = filterSettings.smoothEnabled;
    end

    % Чекбокс: фильтрация по частотам (вкл/выкл)
    hFilterEnabled = uicontrol('Style', 'checkbox', 'String', 'Frequency filtering', ...
        'Position', [320, 572, 200, 22], 'Value', filterEnabledVal, 'Callback', @filterEnabledCallback);

    % Выбор типа фильтра
    filterTypes = {'highpass', 'bandpass', 'lowpass'};
    filterIndex = find(strcmp(filterSettings.filterType, filterTypes));
    if isempty(filterIndex)
        filterIndex = 1;
    end
    hFilterType = uicontrol('Style', 'popup', 'String', filterTypes, ...
        'Position', [320, 545, 100, 25], 'Callback', @filterTypeCallback, 'Value', filterIndex);

    uicontrol('Style', 'text', 'Position', [320, 527, 30, 15], 'String', 'Hz', 'HorizontalAlignment', 'left');
    hFreqLow = uicontrol('Style', 'edit', 'Position', [320, 502, 50, 25], 'String', num2str(filterSettings.freqLow));
    uicontrol('Style', 'text', 'Position', [380, 527, 30, 15], 'String', 'Hz', 'HorizontalAlignment', 'left');
    hFreqHigh = uicontrol('Style', 'edit', 'Position', [380, 502, 50, 25], 'String', num2str(filterSettings.freqHigh));

    uicontrol('Style', 'text', 'Position', [320, 472, 110, 15], 'String', 'Filter Order:', 'HorizontalAlignment', 'left');
    hOrder = uicontrol('Style', 'edit', 'Position', [320, 447, 50, 25], 'String', filterSettings.order);

    smoothSpanVal = 0;
    if isfield(filterSettings, 'smoothSpan')
        smoothSpanVal = filterSettings.smoothSpan;
    end
    smoothMethodVal = 'moving';
    if isfield(filterSettings, 'smoothMethod')
        smoothMethodVal = filterSettings.smoothMethod;
    end
    % Чекбокс: сглаживание
    hSmoothEnabled = uicontrol('Style', 'checkbox', 'String', 'Smoothing', ...
        'Position', [320, 422, 120, 22], 'Value', smoothEnabledVal, 'Callback', @smoothEnabledCallback);
    uicontrol('Style', 'text', 'Position', [320, 397, 140, 15], 'String', 'Smooth (samples):', 'HorizontalAlignment', 'left');
    hSmoothSpan = uicontrol('Style', 'edit', 'Position', [320, 372, 50, 25], 'String', num2str(smoothSpanVal));
    smoothMethods = {'moving', 'median'};
    smoothMethodIdx = find(strcmp(smoothMethodVal, smoothMethods), 1);
    if isempty(smoothMethodIdx)
        smoothMethodIdx = 1;
    end
    uicontrol('Style', 'text', 'Position', [320, 347, 80, 15], 'String', 'Method:', 'HorizontalAlignment', 'left');
    hSmoothMethod = uicontrol('Style', 'popup', 'String', smoothMethods, 'Position', [320, 322, 80, 25], 'Value', smoothMethodIdx);

    % Ось для отображения графика
    ax = axes('Parent', fig, 'Position', [.1 .1 .8 .35]);
    xlabel('Frequency (Hz)');
    ylabel('Power/Frequency (dB/Hz)');
    title('Frequency Response');
    grid on;
    set(ax, 'Visible', 'off');    
    
    
    uicontrol('Style', 'pushbutton', 'String', 'Select ALL', 'Position', [320, 292, 110, 25], 'Callback', @selectAll);
    uicontrol('Style', 'pushbutton', 'String', 'Deselect ALL', 'Position', [320, 262, 110, 25], 'Callback', @deselectAll);
    checkfiltbtn = uicontrol('Style', 'pushbutton', 'String', 'Check Filtration', 'Position', [320, 212, 110, 25], 'Enable', 'on', 'Callback', {@checkFiltration, ax});
    uicontrol('Style', 'pushbutton', 'String', 'Apply', 'Position', [320, 182, 70, 25], 'Enable', 'on', 'Callback', @applySettings);
    uicontrol('Style', 'pushbutton', 'String', 'Cancel', 'Position', [320, 152, 70, 25], 'Enable', 'on', 'Callback', @cancelSettings);

    updateControlsBySelectedChannels();
    filterTypeCallback(hFilterType);
    filterEnabledCallback(hFilterEnabled, []);
    smoothEnabledCallback(hSmoothEnabled, []);
    
    uiwait(fig);
    
    % Функции обратного вызова
    function selectAll(~, ~)
        hTable.Data(:,2) = num2cell(true(size(hTable.Data(:,2))));
        updateControlsBySelectedChannels();
        set(checkfiltbtn, 'Enable', 'on');
    end
    
    function deselectAll(~, ~)
        hTable.Data(:,2) = num2cell(false(size(hTable.Data(:,2))));
        updateControlsBySelectedChannels();
        axes(ax); cla(ax);
        set(ax, 'Visible', 'off');
%         set(applybtn, 'Enable', 'on');
        set(checkfiltbtn, 'Enable', 'off');
    end
    
    function checkbtns(~, ~)
        updateControlsBySelectedChannels();
        if sum(cell2mat(hTable.Data(:, 2)))>0
            set(checkfiltbtn, 'Enable', 'on');
        else
            set(checkfiltbtn, 'Enable', 'off');
        end
    end

    function updateControlsBySelectedChannels()
        hasSelectedChannels = sum(cell2mat(hTable.Data(:, 2))) > 0;
        enableStates = {'off', 'on'};
        enableValue = enableStates{hasSelectedChannels + 1};
        set(hFilterEnabled, 'Enable', enableValue);
        set(hSmoothEnabled, 'Enable', enableValue);
        if ~hasSelectedChannels
            set(hFilterEnabled, 'Value', 0);
            set(hSmoothEnabled, 'Value', 0);
        end
    end

    function filterEnabledCallback(~, ~)
        on = get(hFilterEnabled, 'Value');
        enableStates = {'off', 'on'};
        enableValue = enableStates{on + 1};
        set(hFilterType, 'Enable', enableValue);
        set(hFreqLow, 'Enable', enableValue);
        set(hFreqHigh, 'Enable', enableValue);
        set(hOrder, 'Enable', enableValue);
        if on
            filterTypeCallback(hFilterType);
        else
            low_line_enable = false;
            high_line_enable = false;
        end
    end

    function smoothEnabledCallback(~, ~)
        on = get(hSmoothEnabled, 'Value');
        enableStates = {'off', 'on'};
        enableValue = enableStates{on + 1};
        set(hSmoothSpan, 'Enable', enableValue);
        set(hSmoothMethod, 'Enable', enableValue);
    end

    function filterTypeCallback(src, ~)
        if ~get(hFilterEnabled, 'Value')
            low_line_enable = false;
            high_line_enable = false;
            return
        end
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



            local_settings.filterEnabled = get(hFilterEnabled, 'Value');
            local_settings.smoothEnabled = get(hSmoothEnabled, 'Value');
            local_settings.filterType = hFilterType.String{hFilterType.Value};
            local_settings.freqLow = str2double(hFreqLow.String);
            local_settings.freqHigh = str2double(hFreqHigh.String);
            local_settings.order = str2double(hOrder.String);
            local_settings.smoothSpan = round(str2double(hSmoothSpan.String));
            local_settings.smoothMethod = hSmoothMethod.String{hSmoothMethod.Value};
            local_settings.channelsToFilter = find(cell2mat(hTable.Data(:, 2)));
            
            % Выборка данных в заданном временном интервале
            plot_time_interval = chosen_time_interval;
            plot_time_interval(1) = plot_time_interval(1) - time_back;

            row_start = find(time >= plot_time_interval(1), 1, 'first');
            row_end = find(time < plot_time_interval(2), 1, 'last');
            cond = row_start:row_end;
            local_lfp = lfp_file.lfp(cond, :);% все каналы данного участка времени
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
        local_settings.filterEnabled = get(hFilterEnabled, 'Value');
        local_settings.smoothEnabled = get(hSmoothEnabled, 'Value');
        local_settings.filterType = hFilterType.String{hFilterType.Value};
        local_settings.freqLow = str2double(hFreqLow.String);
        local_settings.freqHigh = str2double(hFreqHigh.String);
        local_settings.order = str2double(hOrder.String);
        local_settings.smoothSpan = round(str2double(hSmoothSpan.String));
        local_settings.smoothMethod = hSmoothMethod.String{hSmoothMethod.Value};
        % обновляем глобальную переменную для фильтрации
        filterSettings = local_settings;
        filter_avaliable = false(numChannels, 1);
        filter_avaliable(ch_inxs(cell2mat(hTable.Data(:, 2)))) = true;
        filter_avaliable = np_flatten(filter_avaliable);
        filterSettings.channelsToFilter = filter_avaliable;
        [path, name, ~] = fileparts(matFilePath);
        channelSettingsFilePath = fullfile(path, [name '_channelSettings.stn']);
        save(channelSettingsFilePath, 'filter_avaliable', 'filterSettings', '-append');
        
        wasApplied = true;
        uiresume(fig);
        close(fig); % закрытие GUI
    end
    
    function cancelSettings(~, ~)
        uiresume(fig);
        close(fig); % закрытие GUI
    end
end

