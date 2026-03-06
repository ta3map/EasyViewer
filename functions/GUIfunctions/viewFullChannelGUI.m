function viewFullChannelGUI()
    global lfp_file time channelNames zavp

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
    resampleEdit = uicontrol('Parent', dlg, 'Style', 'edit', 'String', '10', ...
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

        Fs = zavp.dwnSmplFrq;
        sig = lfp_file.lfp(:, chIdx);

        if targetFs >= Fs
            t_res = time;
            sig_res = double(sig);
        else
            sig_res = resample1(double(sig), targetFs, Fs);
            t_res = linspace(time(1), time(end), length(sig_res));
        end

        close(dlg);
        fig = figure('Name', ['Full trace: ', channelNames{chIdx}], 'NumberTitle', 'off');
        plot(t_res, sig_res);
        xlabel('Time, s');
        ylabel('Signal');
        title(channelNames{chIdx});
    end
end
