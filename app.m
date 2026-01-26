function app()

    global EV_path EV_version EV_date EV_author EV_email EV_description

    EV_version = '1.15.02';
    EV_date = '26.01.2026';
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
    
    loadGlobalSettings();
    initDbPath();
    
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
    
    % Path to assets folder
    assetsPath = fullfile(EV_path, 'assets');
    
    % Helper function to create HTML string with image and text
    function htmlStr = createButtonHTML(imgPath, textStr)
        imgPathEscaped = strrep(imgPath, '\', '/');
        htmlStr = sprintf('<html><body style="font-size:14px;"><table cellpadding="0" cellspacing="0" style="width:100%%; height:100%%;"><tr><td style="width:50px; vertical-align:middle; text-align:center;"><img src="file:///%s" width="32" height="32"></td><td style="vertical-align:middle; padding-left:15px;">%s</td></tr></table></body></html>', ...
            imgPathEscaped, textStr);
    end
    
    % Create panel for buttons
    panel = uipanel('Parent', f, ...
                   'Position', [0.1, 0.1, 0.8, 0.8]);
    
    % Button to launch signalViewerGUI
    uicontrol('Parent', panel, ...
             'Style', 'pushbutton', ...
             'String', createButtonHTML(fullfile(assetsPath, 'signal_viewer_btn.png'), 'Signal Viewer'), ...
             'Position', [40, 320, 240, 50], ...
             'FontSize', 11, ...
             'Callback', @launchSignalViewer);
    
    % Button to launch signalAnalysisGUI
    uicontrol('Parent', panel, ...
             'Style', 'pushbutton', ...
             'String', createButtonHTML(fullfile(assetsPath, 'signal_analysis_btn.png'), 'Signal Analysis'), ...
             'Position', [40, 265, 240, 50], ...
             'FontSize', 11, ...
             'Callback', @launchSignalAnalysis);
    
    % Button to launch resultsGalleryGUI
    uicontrol('Parent', panel, ...
             'Style', 'pushbutton', ...
             'String', createButtonHTML(fullfile(assetsPath, 'results_gallery_btn.png'), 'Results Gallery'), ...
             'Position', [40, 210, 240, 50], ...
             'FontSize', 11, ...
             'Callback', @launchResultsGallery);
    
    % Button to launch plotFromTableGUI
    uicontrol('Parent', panel, ...
             'Style', 'pushbutton', ...
             'String', createButtonHTML(fullfile(assetsPath, 'plot_from_table_btn.png'), 'Plot from Table'), ...
             'Position', [40, 155, 240, 50], ...
             'FontSize', 11, ...
             'Callback', @launchPlotFromTable);
    
    % Button to launch fileManagerGUI
    uicontrol('Parent', panel, ...
             'Style', 'pushbutton', ...
             'String', createButtonHTML(fullfile(assetsPath, 'fm_button.png'), 'File Manager'), ...
             'Position', [40, 100, 240, 50], ...
             'FontSize', 11, ...
             'Callback', @launchFileManager);
    
    % Settings button
    uicontrol('Parent', panel, ...
             'Style', 'pushbutton', ...
             'String', createButtonHTML(fullfile(assetsPath, 'settings_btn.png'), 'Settings'), ...
             'Position', [40, 45, 240, 50], ...
             'FontSize', 11, ...
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