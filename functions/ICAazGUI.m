function ICAazGUI()
global channelTable ch_labels_l colors_in_l widths_in_l matFileName matFilePath
global lfp ch_inxs ica_params spks filterSettings
global csd_avaliable filter_avaliable channelNames mean_group_ch channelSettings m_coef
global ica_flag hd zav_saving chnlGrp lfpVar numChannels channelEnabled scalingCoefficients colorsIn lineCoefficients

% GUI for fastICA function
%
% Inputs:
%   lfp - input data for fastICA

% Идентификатор (tag) для GUI фигуры
figTag = 'ICA';

% Поиск открытой фигуры с заданным идентификатором
guiFig = findobj('Type', 'figure', 'Tag', figTag);

if ~isempty(guiFig)
    % Делаем существующее окно текущим (активным)
    figure(guiFig);
    return
end

max_r = numel(ch_inxs);

% Create figure
fig = figure('Name', 'Fast ICA','Tag', figTag,...
    'MenuBar', 'none', 'ToolBar', 'none', ...
    'Resize', 'off', ...
    'NumberTitle', 'Off', 'Position', [100, 100, 400, 600]);

% Input for r (number of components)
position = [215,550,150,20];
uicontrol('Style', 'text', 'Position',position, 'String', 'Number of components (r):');
position = [215,520,150,20];
editR = uicontrol('Style', 'edit', 'Position', position, 'BackgroundColor', 'white','String', num2str(max_r));

% Input for maximum iterations
position = [215,490,150,20];
uicontrol('Style', 'text', 'Position',position, 'String', 'Max Iterations:');
position = [215,460,150,20];
editMaxIter = uicontrol('Style', 'edit', 'Position', position, 'BackgroundColor', 'white','String', '1000');

% Input for convergence tolerance
position = [215,430,150,20];
uicontrol('Style', 'text', 'Position',position, 'String', 'Convergence Tolerance:');
position = [215,400,150,20];
editTol = uicontrol('Style', 'edit', 'Position', position, 'BackgroundColor', 'white','String', '1e-6');

% Dropdown for type
position = [215,370,100,20];
uicontrol('Style', 'text', 'Position', position, 'String', 'Type:');
position = [215,340,150,20];
popupType = uicontrol('Style', 'popupmenu', 'Position', position, 'BackgroundColor', 'white', 'String', {'kurtosis', 'negentropy', 'tanh', 'exp'});
set(popupType, 'Value', 2);

% Button to run fastICA
position = [215,308,150,20];
uicontrol('Style', 'pushbutton', 'Position', position, 'String', 'Run fastICA', 'Callback', @runFastICA);

channelSettings = get(channelTable, 'Data');

tableData = [channelSettings(:, 1), channelSettings(:, 2)];

position = [16,14,170,520];
ICAchanneltable = uitable('Data', tableData, ...
        'ColumnName', {'Channel', 'Enabled'}, ...
        'ColumnFormat', {'char', 'logical'}, ...
        'ColumnEditable', [true true], ...
        'Position', position);
    
% Check if ICA analysis was already performed
if ica_flag
    choice = questdlg('ICA analysis has already been performed. Do you want to proceed and overwrite the current results?', ...
        'Warning', ...
        'Yes', 'No', 'No');
    if strcmp(choice, 'No')
        close(fig)
        return;
    end
end
        
    function runFastICA(~, ~)

        
        % Get user inputs
        r = str2double(get(editR, 'String'));% число источников
        maxIter = str2double(get(editMaxIter, 'String')); % Max iterations
        tol = str2double(get(editTol, 'String')); % Convergence tolerance
        typeIdx = get(popupType, 'Value');
        types = get(popupType, 'String');
        type = types{typeIdx};
        
        % Validate inputs
        if isnan(r) || r <= 0
            errordlg('Please enter a valid number for components (r).', 'Input Error');
            return;
        end
        if isnan(maxIter) || maxIter <= 0
            errordlg('Please enter a valid number for max iterations.', 'Input Error');
            return;
        end
        if isnan(tol) || tol <= 0
            errordlg('Please enter a valid number for convergence tolerance.', 'Input Error');
            return;
        end
        
        try
            settings = get(ICAchanneltable, 'Data');
            chosen_inx = cellfun(@(x) isequal(x, 1), settings(:, 2));
            
            % Call fastICA function
            [~, W, T, mu] = fastICAdialog(lfp(:, chosen_inx), r, type, tol, maxIter, 1);

            ica_params.W = W;
            ica_params.T = T;
            ica_params.mu = mu;
            %% Замена данных
            
            % Меняем название файла
            [~, matFileName, matFileExt] = fileparts(matFilePath);

            % Добавляем приписку "_ICA"
            matFileName = [matFileName '_ICA' matFileExt];

            % Собираем полный путь к новому файлу
            matFilePath = fullfile(fileparts(matFilePath), matFileName);

            % Заменяем lfp на источники
            lfp = transformICA(lfp(:, chosen_inx), W, T, mu);
            
            % устанавливаем новые имена каналов channelNames
            channelNames = cell(r, 1); % Preallocate cell array for efficiency
            for i = 1:r
                channelNames{i} = ['ICA ', num2str(i)];
            end
            
            % удаляем данные по MUA
            spks = [];
            
            % формируем новый заголовок
            hd.recChNames = channelNames;            
            
            chnlGrp = {};
            lfpVar = std(lfp);
        
            % Формируем таблицу свойств              
            numChannels = r;% число каналов равно числу источников
            
            channelNames = np_flatten(channelNames);
            channelEnabled = true(1, numChannels); % Все каналы активированы по умолчанию
            scalingCoefficients = ones(1, numChannels); % Коэффициенты масштабирования по умолчанию
            colorsIn = np_flatten(repmat({'black'}, numChannels, 1)); % Инициализация цветов
            lineCoefficients = ones(1, numChannels)*0.5; % Инициализация толщины линий
            mean_group_ch = false(1, numChannels);% Ни один канал не участвует в усреднении
            csd_avaliable = true(1, numChannels);% Все каналы участвуют в CSD
            filter_avaliable = false(1, numChannels);% Ни один канал не участвует в фильтрации
            
            filterSettings.filterType = 'highpass';
            filterSettings.freqLow = 10;
            filterSettings.freqHigh = 50;
            filterSettings.order = 4;
            filterSettings.channelsToFilter = false(numChannels, 1);% Ни один канал не участвует в фильтрации
            
            
            tableData = [np_flatten(channelNames); ...
            np_flatten(num2cell(channelEnabled));...
            np_flatten(num2cell(scalingCoefficients)); ...
            np_flatten(colorsIn); ...
            np_flatten(num2cell(lineCoefficients)); ...
            np_flatten(num2cell(mean_group_ch)); ...
            np_flatten(num2cell(csd_avaliable));...
            np_flatten(num2cell(filter_avaliable))]';

            set(channelTable, 'Data', tableData, ... % Обновляем данные в таблице
                       'ColumnName', {'Channel', 'Enabled', 'Scale', 'Color', 'Line Width', 'Averaging', 'CSD', 'Filter'}, ...
                       'ColumnFormat', {'char', 'logical', 'numeric', 'char', 'numeric', 'logical', 'logical', 'logical'}, ...
                       'ColumnEditable', [false true true true true true true true]);
               
            ch_inxs = find(channelEnabled); % Индексы активированных каналов
            m_coef = np_flatten(scalingCoefficients(ch_inxs));% Обновленные коэффициенты масштабирования
            ch_labels_l = channelNames(ch_inxs);
            colors_in_l = colorsIn(ch_inxs);
            widths_in_l = lineCoefficients(ch_inxs);
            
            % обозначаем что мы уже делали ICA
            ica_flag = true;
            
            % обновляем график
            updatePlot()
            
            % тут будет предложение cохранить файл с результатами
            saveChoice = questdlg('Do you want to save the results?', ...
                'Save Results', ...
                'Yes', 'No', 'Yes');
            if strcmp(saveChoice, 'Yes')
                zav_saving(matFilePath);
            end
            close(fig)
        catch e
            % Display error message if fastICA fails
            errordlg(['Error during fastICA: ' e.message], 'fastICA Error');
        end
    end
end