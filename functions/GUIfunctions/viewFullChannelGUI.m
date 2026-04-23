function viewFullChannelGUI(applyCallback)
    global lfp_file time channelNames zavp

    if nargin < 1
        return;
    end

    if isempty(lfp_file) || isempty(time)
        errordlg('Load a file first.', 'Full channel trace');
        return;
    end

    figTag = 'viewFullChannelGUI';
    guiFig = findobj('Type', 'figure', 'Tag', figTag);
    if ~isempty(guiFig)
        figure(guiFig);
        return;
    end

    dlgWidth = 320;
    dlgHeight = 140;
    screenSize = get(0, 'ScreenSize');
    dlgPos = [(screenSize(3) - dlgWidth) / 2, (screenSize(4) - dlgHeight) / 2, dlgWidth, dlgHeight];

    dlg = figure('Name', 'Full channel trace', 'Tag', figTag, 'NumberTitle', 'off', ...
        'MenuBar', 'none', 'ToolBar', 'none', ...
        'WindowStyle', 'modal', 'Resize', 'off', ...
        'Position', dlgPos);

    uicontrol('Parent', dlg, 'Style', 'text', 'String', 'Channel:', ...
        'Position', [10, dlgHeight - 35, 80, 20], 'HorizontalAlignment', 'left');
    channelPopup = uicontrol('Parent', dlg, 'Style', 'popupmenu', 'String', channelNames, ...
        'Position', [100, dlgHeight - 38, 200, 22], 'Value', 1);

    uicontrol('Parent', dlg, 'Style', 'text', 'String', 'Resampling, Hz:', ...
        'Position', [10, dlgHeight - 70, 80, 20], 'HorizontalAlignment', 'left');
    resampleEdit = uicontrol('Parent', dlg, 'Style', 'edit', 'String', '100', ...
        'Position', [100, dlgHeight - 73, 80, 22], 'BackgroundColor', 'white');

    uicontrol('Parent', dlg, 'Style', 'pushbutton', 'String', 'Apply', ...
        'Position', [dlgWidth - 90, 15, 80, 25], 'Callback', @onApply);

    function onApply(~, ~)
        chIdx = get(channelPopup, 'Value');
        targetFsStr = get(resampleEdit, 'String');
        targetFs = str2double(targetFsStr);
        if isnan(targetFs) || targetFs <= 0
            errordlg('Enter a positive number for resampling Hz.', 'Full channel trace');
            return;
        end

        progressBar = waitbar(0, 'Preparing full channel trace...', ...
            'Name', 'Full channel trace', ...
            'WindowStyle', 'modal');
        progressCleanup = onCleanup(@() closeProgressBar(progressBar)); %#ok<NASGU>

        try
            waitbar(0.2, progressBar, 'Reading channel data...');
            Fs = zavp.dwnSmplFrq;
            sig = lfp_file.lfp(:, chIdx);

            if targetFs >= Fs
                waitbar(0.5, progressBar, 'Resampling skipped (target >= source Fs)...');
                t_res = time;
                sig_res = double(sig);
            else
                waitbar(0.5, progressBar, 'Resampling signal...');
                sig_res = resample1(double(sig), targetFs, Fs);
                t_res = linspace(time(1), time(end), length(sig_res));
            end

            waitbar(0.8, progressBar, 'Preparing data for plot...');
            traceData = struct( ...
                'channel_index', chIdx, ...
                'channel_name', channelNames{chIdx}, ...
                'target_fs', targetFs, ...
                'time', t_res, ...
                'signal', sig_res);

            waitbar(0.95, progressBar, 'Rendering in main axes...');
            applyCallback(traceData);
            waitbar(1, progressBar, 'Done');
            close(dlg);
        catch ME
            errordlg(ME.message, 'Full channel trace');
        end
    end

    function closeProgressBar(progressBarHandle)
        if isgraphics(progressBarHandle)
            close(progressBarHandle);
        end
    end
end
