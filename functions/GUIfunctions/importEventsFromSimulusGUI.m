function importEventsFromSimulusGUI()
    % Global variables
    global events stims time lfp channelNames ch_inxs
    global event_amplitudes event_channels event_widths event_prominences event_metadata

    % Идентификатор (tag) для GUI фигуры
    figTag = 'importEventsFromSimulusGUI';
    
    % Поиск открытой фигуры с заданным идентификатором
    guiFig = findobj('Type', 'figure', 'Tag', figTag);
    
    if ~isempty(guiFig)
        % Делаем существующее окно текущим (активным)
        figure(guiFig);
        return
    end
    
    % Initialize GUI
    hFig = figure('Name', 'Import Events from Stimulus', 'NumberTitle', 'off', ...
                  'Position', [100, 100, 260, 400], 'Resize', 'off', ...
                  'NumberTitle', 'off', 'MenuBar', 'none', 'ToolBar', 'none', ...
                  'Tag', figTag,  'WindowStyle', 'modal');

    % Create UI elements
    uicontrol('Style', 'text', 'Position', [20, 370, 100, 20], ...
              'String', 'Select Channels:');
    channelList = uicontrol('Style', 'listbox', 'Position', [20, 70, 100, 300], ...
                            'String', channelNames(ch_inxs), ...
                            'Max', length(ch_inxs), 'Min', 1);
    uicontrol('Style', 'text', 'Position', [140, 370, 100, 25], ...
              'String', 'Minimum Distance (ms):');
    minDistEdit = uicontrol('Style', 'edit', 'Position', [140, 350, 100, 20], 'String', '100');

    uicontrol('Style', 'text', 'Position', [140, 320, 100, 20], ...
              'String', 'Amplitude Criterion:');
    ampCriteriaPopup = uicontrol('Style', 'popupmenu', 'Position', [140, 300, 100, 20], ...
                                 'String', {'Maximum', 'Minimum'});

    analyzeButton = uicontrol('Style', 'pushbutton', 'Position', [140, 260, 100, 20], ...
                              'String', 'Import Selected', 'Callback', @analyzeData);

    importAllButton = uicontrol('Style', 'pushbutton', 'Position', [140, 220, 100, 20], ...
                                'String', 'Import All', 'Callback', @importAllData);

    uiwait(hFig);

    function analyzeData(~, ~)
        selectedChannels = channelList.Value;
        minDist = str2double(minDistEdit.String) / 1000; % Convert ms to seconds
        ampCriterion = ampCriteriaPopup.Value;

        analyzedStims = [];
        analyzedAmplitudes = [];
        analyzedChannels = [];
        analyzedMetadata = [];
        
        i = 1;
        while i <= length(stims)
            stimCluster = stims(i);
            j = i + 1;
            while j <= length(stims) && (stims(j) - stims(i)) < minDist
                stimCluster = [stimCluster; stims(j)];
                j = j + 1;
            end

            stimClusterInxs = ClosestIndex(stimCluster, time);
            clusterData = mean(lfp(stimClusterInxs, selectedChannels), 2);
            
            if ampCriterion == 1
                % Select maximum amplitude
                [amplitude, maxIdx] = max(clusterData);
                analyzedStims = [analyzedStims; stimCluster(maxIdx)];
                analyzedAmplitudes = [analyzedAmplitudes; amplitude];
                criterion_str = 'Maximum';
            else
                % Select minimum amplitude
                [amplitude, minIdx] = min(clusterData);
                analyzedStims = [analyzedStims; stimCluster(minIdx)];
                analyzedAmplitudes = [analyzedAmplitudes; amplitude];
                criterion_str = 'Minimum';
            end
            
            % Сохраняем каналы
            analyzedChannels = [analyzedChannels; selectedChannels(:)'];
            
            % Создаем метаданные
            metadata = struct(...
                'source', 'stimulus', ...
                'method', criterion_str, ...
                'data_type', 'LFP', ...
                'polarity', criterion_str, ...
                'prominence', NaN, ...
                'detection_params', struct(...
                    'selectedChannels', selectedChannels, ...
                    'minDistance', minDist, ...
                    'ampCriterion', criterion_str ...
                ) ...
            );
            analyzedMetadata = [analyzedMetadata; metadata];

            i = j; % Move to the next cluster
        end

        events = analyzedStims;
        event_amplitudes = analyzedAmplitudes;
        event_channels = analyzedChannels;
        event_widths = NaN(size(analyzedStims));
        event_prominences = NaN(size(analyzedStims));
        event_metadata = analyzedMetadata;
        uiresume(hFig);
        close(hFig)
    end

    function importAllData(~, ~)
        events = stims;
        
        % Создаем простые метаданные для всех стимулов
        event_amplitudes = NaN(size(stims));  % Амплитуда неизвестна для простого импорта
        event_channels = ones(length(stims), 1);  % Default канал
        event_widths = NaN(size(stims));
        event_prominences = NaN(size(stims));
        
        % Создаем метаданные для всех событий
        metadata_template = struct(...
            'source', 'stimulus', ...
            'method', 'import_all', ...
            'data_type', 'LFP', ...
            'polarity', 'unknown', ...
            'prominence', NaN, ...
            'detection_params', struct() ...
        );
        event_metadata = repmat(metadata_template, length(stims), 1);
        
        uiresume(hFig);
        close(hFig)
    end
end
