function spectralDensityGUI()

    % Идентификатор (tag) для GUI фигуры
    figTag = 'spectralDensityGUI';
    
    % Поиск открытой фигуры с заданным идентификатором
    guiFig = findobj('Type', 'figure', 'Tag', figTag);
    
    if ~isempty(guiFig)
        % Делаем существующее окно текущим (активным)
        figure(guiFig);
        return
    end    
        
    global newFs data ch_labels_l
    
    channelNames = ch_labels_l;
    % Проверка наличия channelNames, если нет - создаем временный список
    if isempty(channelNames)
        channelNames = arrayfun(@(x) sprintf('Channel %d', x), 1:size(data, 2), 'UniformOutput', false);
    end

    % Создание и настройка главного окна
    figure('Name', 'Spectral Density', 'Tag', figTag, 'NumberTitle', 'off',...
        'MenuBar', 'none', 'ToolBar', 'none', 'Position', [100, 100, 600, 400], ...
        'Resize', 'off');
    clf
    ax = axes('position', [0.1, 0.12, 0.82, 0.75]);

    % Выпадающий список для выбора канала
    channelList = ['All Channels', channelNames];
    popupChannel = uicontrol('Style', 'popupmenu',...
                      'String', channelList,...
                      'Position', [20 350 160 40],...
                      'Callback', @updateSDPlot);

    % Выпадающий список для выбора типа шкалы оси Y
    yScaleOptions = {'Linear', 'Logarithmic'};
    popupYScale = uicontrol('Style', 'popupmenu',...
                            'String', yScaleOptions,...
                            'Position', [200 350 100 40],...
                            'Callback', @updateSDPlot);

    % Функция для обновления графика в зависимости от выбора канала и шкалы Y
    function updateSDPlot(~, ~)
        channelIdx = popupChannel.Value;
        yScaleIdx = popupYScale.Value;
        
        if channelIdx == 1
            % Если выбраны "All Channels"
            incomingData = sum(data, 2); % Сумма всех каналов
        else
            % Выбор конкретного канала
            incomingData = data(:, channelIdx-1); % channelIdx-1, так как добавили "All Channels" в начало списка
        end

        % Расчет и отображение спектральной плотности мощности
        [Pxx, F] = pwelch(incomingData, [], [], [], newFs);        
        
        axis(ax)
        cla
        plot(F, 10*log10(Pxx));
        title('Signal power spectral density');
        xlabel('Frequency (Hz)');
        ylabel('Power density (dB/Hz)');
        grid on;
        
        % Установка шкалы оси Y в зависимости от выбора пользователя
        if yScaleIdx == 1
            set(ax, 'YScale', 'linear'); % Логарифмическая шкала
        else
            set(ax, 'YScale', 'log'); % Линейная шкала
        end
    end

    % Инициализация графика с выбором "All Channels"
    updateSDPlot(popupChannel, []);
end
