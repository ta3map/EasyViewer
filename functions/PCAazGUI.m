function PCAazGUI()
global channelTable ch_labels_l colors_in_l widths_in_l matFileName matFilePath
global lfp ch_inxs pca_params spks filterSettings
global csd_avaliable filter_avaliable channelNames mean_group_ch channelSettings m_coef
global pca_flag hd zav_saving chnlGrp lfpVar numChannels channelEnabled scalingCoefficients colorsIn lineCoefficients

% GUI for PCA function
%
% Inputs:
%   lfp - input data for PCA

% Identifier (tag) for GUI figure
figTag = 'PCA';

% Search for an open figure with the given identifier
guiFig = findobj('Type', 'figure', 'Tag', figTag);

if ~isempty(guiFig)
    % Make the existing window current (active)
    figure(guiFig);
    return
end

max_r = numel(ch_inxs);

% Create figure
fig = figure('Name', 'PCA','Tag', figTag,...
    'MenuBar', 'none', 'ToolBar', 'none', ...
    'Resize', 'off', ...
    'NumberTitle', 'Off', 'Position', [100, 100, 400, 600]);

% Input for r (number of components)
position = [215,550,150,20];
uicontrol('Style', 'text', 'Position',position, 'String', 'Number of components (r):');
position = [215,520,150,20];
editR = uicontrol('Style', 'edit', 'Position', position, 'BackgroundColor', 'white','String', num2str(max_r));

% Button to run PCA
position = [215,308,150,20];
uicontrol('Style', 'pushbutton', 'Position', position, 'String', 'Run PCA', 'Callback', @runPCA);

channelSettings = get(channelTable, 'Data');

tableData = [channelSettings(:, 1), channelSettings(:, 2)];

position = [16,14,170,520];
PCAchanneltable = uitable('Data', tableData, ...
        'ColumnName', {'Channel', 'Enabled'}, ...
        'ColumnFormat', {'char', 'logical'}, ...
        'ColumnEditable', [true true], ...
        'Position', position);
    
% Check if PCA analysis was already performed
if pca_flag
    choice = questdlg('PCA analysis has already been performed. Do you want to proceed and overwrite the current results?', ...
        'Warning', ...
        'Yes', 'No', 'No');
    if strcmp(choice, 'No')
        close(fig)
        return;
    end
end
        
    function runPCA(~, ~)

        % Get user inputs
        r = str2double(get(editR, 'String')); % Number of components
        
        % Validate inputs
        if isnan(r) || r <= 0
            errordlg('Please enter a valid number for components (r).', 'Input Error');
            return;
        end
        
        try
            settings = get(PCAchanneltable, 'Data');
            chosen_inx = cellfun(@(x) isequal(x, 1), settings(:, 2));
            
            % Call PCA function
            [coeff, score, ~, ~, explained] = pca(lfp(:, chosen_inx));

            % Select the required number of components
            pca_params.coeff = coeff(:, 1:r);
            pca_params.score = score(:, 1:r);
            pca_params.explained = explained(1:r);

            % Replace data
            % Change file name
            [~, matFileName, matFileExt] = fileparts(matFilePath);

            % Add suffix "_PCA"
            matFileName = [matFileName '_PCA' matFileExt];

            % Full path to new file
            matFilePath = fullfile(fileparts(matFilePath), matFileName);

            % Replace lfp with sources
            lfp = pca_params.score;
            
            % Set new channel names
            channelNames = cell(r, 1); % Preallocate cell array for efficiency
            for i = 1:r
                channelNames{i} = ['PCA ', num2str(i)];
            end
            
            % Clear MUA data
            spks = [];
            
            % Form new header
            hd.recChNames = channelNames;            
            
            chnlGrp = {};
            lfpVar = std(lfp);
        
            % Form properties table              
            numChannels = r; % Number of channels equals number of sources
            
            channelNames = channelNames;
            channelEnabled = true(1, numChannels); % All channels enabled by default
            scalingCoefficients = ones(1, numChannels); % Default scaling coefficients
            colorsIn = repmat({'black'}, numChannels, 1); % Initialize colors
            lineCoefficients = ones(1, numChannels) * 0.5; % Initialize line widths
            mean_group_ch = false(1, numChannels); % No channel involved in averaging
            csd_avaliable = true(1, numChannels); % All channels involved in CSD
            filter_avaliable = false(1, numChannels); % No channel involved in filtering
            
            filterSettings.filterType = 'highpass';
            filterSettings.freqLow = 10;
            filterSettings.freqHigh = 50;
            filterSettings.order = 4;
            filterSettings.channelsToFilter = false(numChannels, 1); % No channel involved in filtering
            
            tableData = [channelNames, num2cell(channelEnabled)', num2cell(scalingCoefficients)', colorsIn, num2cell(lineCoefficients)', num2cell(mean_group_ch)', num2cell(csd_avaliable)', num2cell(filter_avaliable)'];
            
            set(channelTable, 'Data', tableData, ... % Update table data
                       'ColumnName', {'Channel', 'Enabled', 'Scale', 'Color', 'Line Width', 'Averaging', 'CSD', 'Filter'}, ...
                       'ColumnFormat', {'char', 'logical', 'numeric', 'char', 'numeric', 'logical', 'logical', 'logical'}, ...
                       'ColumnEditable', [false true true true true true true true]);
               
            ch_inxs = find(channelEnabled); % Indices of enabled channels
            m_coef = scalingCoefficients(ch_inxs); % Updated scaling coefficients
            ch_labels_l = channelNames(ch_inxs);
            colors_in_l = colorsIn(ch_inxs);
            widths_in_l = lineCoefficients(ch_inxs);
            
            % Mark that PCA was performed
            pca_flag = true;
            
            % Update plot
            updatePlot()
            
            % Prompt to save the file with results
            saveChoice = questdlg('Do you want to save the results?', ...
                'Save Results', ...
                'Yes', 'No', 'Yes');
            if strcmp(saveChoice, 'Yes')
                zav_saving(matFilePath);
            end
            close(fig)
        catch e
            % Display error message if PCA fails
            errordlg(['Error during PCA: ' e.message], 'PCA Error');
        end
    end
end
