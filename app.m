function app()

    global EV_path EV_version EV_date EV_author EV_email EV_description

    EV_version = '1.15.00';
    EV_date = '12.01.2026';
    EV_author = 'Azat Gainutdinov';
    EV_email = 'ta3map@gmail.com';
    EV_description = 'Visualization and analysis of electrophysiological data';

    clc
    disp(['Easy Viewer version: ' EV_version])  
        
    disp('working directory:')
    fprintf('%s\n',pwd);
    
    EV_path = fileparts(mfilename('fullpath'));
    disp('app directory:')
    fprintf('%s\n',EV_path);
    

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
              'Position', [100, 100, 400, 484], ...
              'Resize', 'off', ...
              'Tag', 'EasyViewerApp', ...
              'CloseRequestFcn', @closeApp);
    
    disp('Application ready')
    
    % Create panel for buttons
    panel = uipanel('Parent', f, ...
                   'Position', [0.1, 0.1, 0.8, 0.8]);
    
    % Button to launch signalViewerGUI
    uicontrol('Parent', panel, ...
             'Style', 'pushbutton', ...
             'String', 'Signal Viewer', ...
             'Position', [40, 266, 240, 60], ...
             'FontSize', 14, ...
             'Callback', @launchSignalViewer);
    
    % Button to launch signalAnalysisGUI
    uicontrol('Parent', panel, ...
             'Style', 'pushbutton', ...
             'String', 'Signal Analysis', ...
             'Position', [40, 202, 240, 60], ...
             'FontSize', 14, ...
             'Callback', @launchSignalAnalysis);
    
    % Button to launch resultsGalleryGUI
    uicontrol('Parent', panel, ...
             'Style', 'pushbutton', ...
             'String', 'Results Gallery', ...
             'Position', [40, 138, 240, 60], ...
             'FontSize', 14, ...
             'Callback', @launchResultsGallery);
    
    % Button to launch plotFromTableGUI
    uicontrol('Parent', panel, ...
             'Style', 'pushbutton', ...
             'String', 'Plot from Table', ...
             'Position', [40, 74, 240, 60], ...
             'FontSize', 14, ...
             'Callback', @launchPlotFromTable);
    
    % Button to launch fileManagerGUI
    uicontrol('Parent', panel, ...
             'Style', 'pushbutton', ...
             'String', 'File Manager', ...
             'Position', [40, 10, 240, 60], ...
             'FontSize', 14, ...
             'Callback', @launchFileManager);
    
    % Settings button
    uicontrol('Parent', panel, ...
             'Style', 'pushbutton', ...
             'String', 'Settings', ...
             'Position', [40, -54, 240, 60], ...
             'FontSize', 14, ...
             'Callback', @(~,~)showGlobalSettings());
    
    % Callback для запуска Signal Viewer
    function launchSignalViewer(~, ~)
        signalViewerGUI();
        delete(f);
    end
    
    % Callback для запуска Signal Analysis
    function launchSignalAnalysis(~, ~)
        signalAnalysisGUI();
        delete(f);
    end
    
    % Callback для запуска Results Gallery
    function launchResultsGallery(~, ~)
        resultsGalleryGUI();
        delete(f);
    end
    
    % Callback для запуска Plot From Table
    function launchPlotFromTable(~, ~)
        plotFromTableGUI();
        delete(f);
    end
    
    % Callback для запуска File Manager
    function launchFileManager(~, ~)
        fileManagerGUI();
        delete(f);
    end
    
    % Function to handle main window closing
    function closeApp(src, ~)
        delete(src);
    end
end 