function showHelp(section)
    % SHOWHELP Справка раздела: вкладки English / Русский
    %   showHelp('signal_viewer') или showHelp('signal_analysis')

    docsPath = fullfile(getAppRoot(), 'docs', 'user_docs', section);

    if ~exist(docsPath, 'dir')
        errordlg(['Help folder not found: ' docsPath], 'Error');
        return;
    end

    htmlFiles = dir(fullfile(docsPath, '*.html'));
    if isempty(htmlFiles)
        msgbox('No HTML help files found.', 'Help');
        return;
    end

    rusPaths = {};
    rusNames = {};
    engPaths = {};
    engNames = {};

    for i = 1:numel(htmlFiles)
        name = htmlFiles(i).name;
        path = fullfile(docsPath, name);
        title = extractHtmlTitle(path);
        if endsWith(name, '_rus.html')
            rusPaths{end+1} = path; %#ok<AGROW>
            rusNames{end+1} = title; %#ok<AGROW>
        elseif endsWith(name, '_eng.html')
            engPaths{end+1} = path; %#ok<AGROW>
            engNames{end+1} = title; %#ok<AGROW>
        end
    end

    fig = figure( ...
        'Name', 'Help', ...
        'NumberTitle', 'off', ...
        'MenuBar', 'none', ...
        'ToolBar', 'none', ...
        'Resize', 'on', ...
        'Units', 'pixels', ...
        'Position', [200 200 480 360], ...
        'Color', get(0, 'DefaultUicontrolBackgroundColor'));

    tg = uitabgroup(fig, 'Units', 'normalized', 'Position', [0.04 0.14 0.92 0.82]);

    tabEn = uitab(tg, 'Title', 'English');
    lbEn = uicontrol(tabEn, ...
        'Style', 'listbox', ...
        'Units', 'normalized', ...
        'Position', [0.03 0.03 0.94 0.94], ...
        'String', engNames, ...
        'FontSize', 11, ...
        'Callback', @onListActivate);

    tabRu = uitab(tg, 'Title', 'Russian');
    lbRu = uicontrol(tabRu, ...
        'Style', 'listbox', ...
        'Units', 'normalized', ...
        'Position', [0.03 0.03 0.94 0.94], ...
        'String', rusNames, ...
        'FontSize', 11, ...
        'Callback', @onListActivate);

    uicontrol(fig, ...
        'Style', 'pushbutton', ...
        'Units', 'normalized', ...
        'Position', [0.55 0.03 0.2 0.08], ...
        'String', 'Open', ...
        'FontSize', 11, ...
        'Callback', @onOpen);

    uicontrol(fig, ...
        'Style', 'pushbutton', ...
        'Units', 'normalized', ...
        'Position', [0.76 0.03 0.2 0.08], ...
        'String', 'Close', ...
        'FontSize', 11, ...
        'Callback', @(~, ~) delete(fig));

    function onListActivate(~, ~)
        if ~strcmp(get(fig, 'SelectionType'), 'open')
            return;
        end
        onOpen();
    end

    function onOpen(~, ~)
        selectedTab = tg.SelectedTab;
        paths = rusPaths;
        lb = lbRu;
        if selectedTab == tabEn
            paths = engPaths;
            lb = lbEn;
        end
        idx = lb.Value;
        if isempty(paths) || isempty(idx)
            return;
        end
        web(paths{idx}, '-browser');
    end
end

function title = extractHtmlTitle(htmlFile)
    title = '';
    try
        content = fileread(htmlFile);
        h1 = regexp(content, '<h1[^>]*>(.*?)</h1>', 'tokens', 'once', 'dotexceptnewline');
        if ~isempty(h1)
            title = strtrim(regexprep(h1{1}, '<[^>]+>', ''));
        else
            t = regexp(content, '<title[^>]*>(.*?)</title>', 'tokens', 'once', 'dotexceptnewline');
            if ~isempty(t)
                title = strtrim(t{1});
            end
        end
    catch
    end

    if isempty(title)
        [~, fileName, ~] = fileparts(htmlFile);
        title = fileName;
    end
end
