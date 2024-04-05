function ICAazGUI()
global channelTable 
global lfp ch_inxs ica_params shiftCoeff selectedCenter timeCenterPopup
global csd_avaliable filter_avaliable channelNames mean_group_ch channelSettings m_coef

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
    'NumberTitle', 'Off', 'Position', [100, 100, 400, 550]);

% Input for r (number of components)
position = [215,500,150,20];
uicontrol('Style', 'text', 'Position',position, 'String', 'Number of components (r):');
position = [215,470,150,20];
editR = uicontrol('Style', 'edit', 'Position', position, 'BackgroundColor', 'white','String', num2str(max_r));

% Dropdown for type
position = [215,450,100,20];
uicontrol('Style', 'text', 'Position', position, 'String', 'Type:');
position = [215,420,150,20];
popupType = uicontrol('Style', 'popupmenu', 'Position', position, 'BackgroundColor', 'white', 'String', {'kurtosis', 'negentropy'});

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
                
    function runFastICA(~, ~)
        % Get user inputs
        r = str2double(get(editR, 'String'));
        typeIdx = get(popupType, 'Value');
        types = get(popupType, 'String');
        type = types{typeIdx};
        
        % Validate inputs
        if isnan(r) || r <= 0
            errordlg('Please enter a valid number for components (r).', 'Input Error');
            return;
        end
        
        try
            settings = get(ICAchanneltable, 'Data');
            chosen_inx = cellfun(@(x) isequal(x, 1), settings(:, 2));
            
            % Call fastICA function
            [~, W, T, mu] = fastICAdialog(lfp(:, chosen_inx), r, type, 1);
            
            ica_params.W = W;
            ica_params.T = T;
            ica_params.mu = mu;
            
            lfp = [lfp, transformICA(lfp(:, chosen_inx), W, T, mu)];
            %%
            % Добавление элементов к channelNames
            for i = 1:r
                channelNames{end+1, 1} = ['ICA ', num2str(i)];
            end

            % Добавление элементов к csd_avaliable, filter_avaliable, mean_group_ch
            csd_avaliable = [csd_avaliable; false(r, 1)];
            filter_avaliable = [filter_avaliable; false(r, 1)];
            mean_group_ch = [mean_group_ch; false(r, 1)];
            
            % Добавление строк к channelSettings
            for i = 1:r
                channelSettings{end+1, 1} = ['ICA ', num2str(i)];
                channelSettings{end, 2} = true;
                channelSettings{end, 3} = shiftCoeff;
                channelSettings{end, 4} = '#922B16';
                channelSettings{end, 5} = 0.5;
            end
            
            ch_inxs = find([channelSettings{:, 2}]);
            m_coef = [channelSettings{:, 3}]; % Обновленные коэффициенты масштабирования
            m_coef = m_coef(ch_inxs);
            %%
            set(channelTable, 'Data', channelSettings);
            
            
            updatePlot()
        catch e
            % Display error message if fastICA fails
            errordlg(['Error during fastICA: ' e.message], 'fastICA Error');
        end
    end
end
