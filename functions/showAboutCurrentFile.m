function showAboutCurrentFile()
    % SHOWABOUTCURRENTFILE Отображает окно с информацией о текущем открытом файле
    
    global matFilePath matFileName Fs N lfp hd zavp data_loaded
    
    existingFig = findobj('Tag', 'AboutCurrentFile');
    if ~isempty(existingFig)
        figure(existingFig);
        return;
    end
    
    screenSize = get(0, 'ScreenSize');
    windowWidth = 600;
    windowHeight = 500;
    xPos = (screenSize(3) - windowWidth) / 2;
    yPos = (screenSize(4) - windowHeight) / 2;
    
    fig = figure('Name', 'About Current File', ...
                 'NumberTitle', 'off', ...
                 'MenuBar', 'none', ...
                 'ToolBar', 'none', ...
                 'Position', [xPos, yPos, windowWidth, windowHeight], ...
                 'Resize', 'off', ...
                 'Tag', 'AboutCurrentFile', ...
                 'CloseRequestFcn', @closeWindow);
    
    uicontrol('Parent', fig, 'Style', 'text', ...
              'String', 'CURRENT FILE INFORMATION', ...
              'Position', [25, 460, 550, 25], ...
              'HorizontalAlignment', 'left', ...
              'FontWeight', 'bold', ...
              'FontSize', 12, ...
              'ForegroundColor', [0, 0.4, 0.8]);
    
    if ~data_loaded || isempty(matFilePath)
        infoTextStr = 'No file is currently loaded.';
    else
        infoText = {};
        
        infoText{end+1} = sprintf('File name: %s', matFileName);
        infoText{end+1} = sprintf('Full path: %s', matFilePath);
        
        if ~isempty(Fs)
            infoText{end+1} = sprintf('Sampling frequency: %.2f Hz', Fs);
        end
        
        if ~isempty(N)
            infoText{end+1} = sprintf('Number of channels: %d', N);
        elseif ~isempty(lfp)
            infoText{end+1} = sprintf('Number of channels: %d', size(lfp, 1));
        end
        
        if ~isempty(lfp)
            lfpSize = size(lfp);
            if length(lfpSize) == 2
                infoText{end+1} = sprintf('Data dimensions: %d x %d (channels x time points)', lfpSize(1), lfpSize(2));
            elseif length(lfpSize) == 3
                infoText{end+1} = sprintf('Data dimensions: %d x %d x %d (channels x time points x sweeps)', lfpSize(1), lfpSize(2), lfpSize(3));
            end
        end
        
        if ~isempty(zavp) && isfield(zavp, 'dwnSmplFrq')
            infoText{end+1} = sprintf('Downsampled frequency: %.2f Hz', zavp.dwnSmplFrq);
        end
        
        if ~isempty(hd)
            if isfield(hd, 'recChNames') && ~isempty(hd.recChNames)
                chNames = hd.recChNames;
                if iscell(chNames) && length(chNames) <= 10
                    infoText{end+1} = sprintf('Channel names: %s', strjoin(chNames, ', '));
                elseif iscell(chNames)
                    infoText{end+1} = sprintf('Channel names: %s ... (%d total)', strjoin(chNames(1:10), ', '), length(chNames));
                end
            end
        end
        
        infoTextStr = strjoin(infoText, sprintf('\n'));
    end
    
    uicontrol('Parent', fig, 'Style', 'edit', ...
              'String', infoTextStr, ...
              'Position', [25, 80, 550, 370], ...
              'HorizontalAlignment', 'left', ...
              'FontSize', 10, ...
              'Max', 2, ...
              'Enable', 'inactive', ...
              'BackgroundColor', [1, 1, 1]);
    
    uicontrol('Parent', fig, 'Style', 'pushbutton', ...
              'String', 'Close', ...
              'Position', [250, 30, 100, 35], ...
              'Callback', @closeWindow, ...
              'FontSize', 11);
    
    function closeWindow(~, ~)
        delete(fig);
    end
end

