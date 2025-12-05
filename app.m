function app()

    global EV_path EV_version EV_date EV_author EV_email EV_description

    EV_path = pwd;
    EV_version = '1.14.03';
    EV_date = '05.12.2025';
    EV_author = 'Azat Gainutdinov';
    EV_email = 'ta3map@gmail.com';
    EV_description = 'Visualization and analysis of electrophysiological data';

    clc
    disp(['Easy Viewer version: ' EV_version])  
        
    disp('working directory:')
    fprintf('%s\n',EV_path);
    
    app_path = fileparts(mfilename('fullpath'));
    disp('app directory:')
    fprintf('%s\n',app_path);
        
    disp('please wait ...')


    % Check if window is already open
    existingFig = findobj('Tag', 'EasyViewerApp');
    if ~isempty(existingFig)
        figure(existingFig);
        return;
    end
    
    % Create main window
    f = figure('Name', ['EasyViewer App v' EV_version], ...
              'NumberTitle', 'off', ...
              'MenuBar', 'none', ...
              'ToolBar', 'none', ...
              'Position', [100, 100, 400, 300], ...
              'Resize', 'off', ...
              'Tag', 'EasyViewerApp', ...
              'CloseRequestFcn', @closeApp);
    
    % Close all other windows before opening main window
    closeAllButOne(f);
    disp('Application ready')
    
    % Create panel for buttons
    panel = uipanel('Parent', f, ...
                   'Position', [0.1, 0.1, 0.8, 0.8]);
    
    % Button to launch signalViewerGUI
    uicontrol('Parent', panel, ...
             'Style', 'pushbutton', ...
             'String', 'Signal Viewer', ...
             'Position', [40, 120, 240, 60], ...
             'FontSize', 14, ...
             'Callback', @(~,~)signalViewerGUI());
    
    % Button to launch signalAnalysisGUI
    uicontrol('Parent', panel, ...
             'Style', 'pushbutton', ...
             'String', 'Signal Analysis', ...
             'Position', [40, 40, 240, 60], ...
             'FontSize', 14, ...
             'Callback', @(~,~)signalAnalysisGUI());
    
    % Settings button
    uicontrol('Parent', panel, ...
             'Style', 'pushbutton', ...
             'String', '⚙', ...
             'Position', [280, 200, 30, 30], ...
             'FontSize', 12, ...
             'Callback', @(~,~)showGlobalSettings());
    
    % Close all figures except the specified one
    function closeAllButOne(targetFigure)
        % Get array of all current figures
        figures = findobj(allchild(0), 'flat', 'Type', 'figure');
        % Iterate through all figures and close those that don't match target
        for i = 1:length(figures)
            if figures(i) ~= targetFigure
                close(figures(i));
            end
        end
    end
    
    % Function to handle main window closing
    function closeApp(src, ~)
        % Close all child windows
        closeAllButOne(src);
        
        % Close main window
        delete(src);
    end
end 