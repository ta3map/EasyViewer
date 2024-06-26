function importLFP()
    % Global variables
    global lastOpenedFiles lfp time N time_forward time_back chosen_time_interval
    global shiftCoeff newFs selectedCenter stim_inx show_spikes show_CSD channelNames
    global numChannels lfpVar matFileName matFilePath Fs
    global call_updateTable
    global call_setStandardChannelSettings
    global call_resetMainWindowButtons
    global spks stims zavp hd
    global new_channelNames new_spks 
    
    % Tag for GUI figure
    figTag = 'importLFP';

    % Search for an open figure with the given tag
    guiFig = findobj('Type', 'figure', 'Tag', figTag);

    if ~isempty(guiFig)
        % Make the existing window the current figure
        figure(guiFig);
        return
    end
    
    % Initialize GUI
    fig = figure('Name', 'Import data from ZAV(.mat) file', 'NumberTitle', 'off', ...
                  'Position', [100, 100, 400, 700], 'Resize', 'off', ...
                  'NumberTitle', 'off', 'MenuBar', 'none', 'ToolBar', 'none', ...
                  'Tag', figTag, 'WindowStyle', 'normal');


    % File selection button
    uicontrol('Style', 'pushbutton', 'Position', [20, 650, 100, 40], 'String', 'Browse', ...
              'Callback', @selectFile);

    uicontrol('Style', 'text', 'Position', [20, 610, 150, 20], 'String', 'Select Channels:');
    channelList = uicontrol('Style', 'listbox', 'Position', [20, 350, 150, 250], ...
                            'String', {}, 'Max', 100, 'Min', 1);

    uicontrol('Style', 'text', 'Position', [200, 610, 150, 20], 'String', 'Select Time Interval:');
    uicontrol('Style', 'text', 'Position', [200, 580, 50, 20], 'String', 'Start:');
    startTimeBox = uicontrol('Style', 'edit', 'Position', [250, 580, 100, 20], 'String', '0');
    uicontrol('Style', 'text', 'Position', [200, 550, 50, 20], 'String', 'End:');
    endTimeBox = uicontrol('Style', 'edit', 'Position', [250, 550, 100, 20], 'String', '');

    uicontrol('Style', 'text', 'Position', [200, 520, 150, 20], 'String', 'Import Mode:');
    importMode = uicontrol('Style', 'popupmenu', 'Position', [200, 490, 150, 20], ...
                           'String', {'Replace all', 'Append Data'});
    set(importMode, 'Value', 2);

    uicontrol('Style', 'pushbutton', 'Position', [200, 400, 100, 40], 'String', 'Import', ...
              'Callback', @importData);

    append_start_time = 0;

    % File selection callback function
    function selectFile(~, ~)
        initialDir = pwd;
        if ~isempty(lastOpenedFiles)
            initialDir = fileparts(lastOpenedFiles{end});
        end

        [file, path] = uigetfile('*.mat', 'Load .mat File', initialDir);
        if isequal(file, 0)
            disp('File selection canceled.');
            return;
        end
        filepath = fullfile(path, file);
        set(channelList, 'UserData', filepath);

        % Load metadata
        info = matfile(filepath);
        lfp_info = whos(info, 'lfp');
        if size(lfp_info.size, 2) == 2
            N = lfp_info.size(1);
        else            
            N = lfp_info.size(1)*lfp_info.size(3);
        end
        

        data = load(filepath, 'zavp', 'hd', 'spks');
        Fs = data.zavp.dwnSmplFrq;
        new_channelNames = data.hd.recChNames;
        new_spks = data.spks;% ms
        
        set(channelList, 'String', new_channelNames);
        set(endTimeBox, 'String', num2str((N-1)/Fs));
    end

    % Import data callback function
    function importData(~, ~)
        filepath = get(channelList, 'UserData');
        if isempty(filepath)
            disp('No file selected.');
            return;
        end

        selectedChannels = get(channelList, 'Value');
        time_start = str2double(get(startTimeBox, 'String'));
        time_end = str2double(get(endTimeBox, 'String'));

        start_index = max(1, round(time_start * Fs) + 1);% s
        end_index = min(N, round(time_end * Fs) + 1);% s

        % Load selected data
        d = load(filepath, 'lfp', 'lfpVar', 'zavp');
        new_lfp = d.lfp;
        
        [m, n, p] = size(new_lfp);  % получение размеров исходной матрицы
        if p > 1 % случай со свипами 
            disp('sweep case')
            [new_lfp, new_spks, ~, new_lfpVar] = sweepProcessData(p, new_spks, n, m, new_lfp, Fs, d.zavp, d.lfpVar);
            
        else            
            new_lfpVar = d.lfpVar(selectedChannels);
        end
        new_lfp = new_lfp(start_index:end_index, selectedChannels);
        
        clear d
        
        mode = get(importMode, 'Value');
        if mode == 1 % Clean Import
            lfp = new_lfp;
            lfpVar = new_lfpVar;
            channelNames = new_channelNames(selectedChannels)';
            spks = new_spks;
        else % Append Data
            append_start_time = str2double(inputdlg('Enter the start (in seconds) time for appending data:', 'Append Data', 1, {'0'}));
            append_start_index = round(append_start_time * Fs) + 1;
            if append_start_index < 1
                % Shift existing data to the right
                shift_amount = abs(append_start_index) + 1;
                lfp = [nan(shift_amount, size(lfp, 2)); lfp];
                append_start_index = 1;
            end
            if size(new_lfp, 1) + append_start_index - 1 > size(lfp, 1)
                lfp(size(new_lfp, 1) + append_start_index - 1, end) = nan; % Expand lfp to new data length
            end
            lfp(append_start_index:append_start_index + size(new_lfp, 1) - 1, end + 1:end + length(selectedChannels)) = new_lfp;
            lfpVar = [lfpVar; new_lfpVar];
            channelNames = [channelNames, new_channelNames(selectedChannels)'];
            lfp(lfp == 0) = nan;
            
            if append_start_time <0
                for ch_inx = selectedChannels
                    time_cond = new_spks(ch_inx).tStamp/1000 >= time_start & new_spks(ch_inx).tStamp/1000 <= time_end;
                    new_spks(ch_inx).tStamp = new_spks(ch_inx).tStamp(time_cond);% ms
                    new_spks(ch_inx).ampl = new_spks(ch_inx).ampl(time_cond);
                end

                for ch_inx = 1:numel(spks)
                    spks(ch_inx).tStamp = spks(ch_inx).tStamp - append_start_time*1000;
                end
                
                stims = stims - append_start_time;
                % Обратное помещение измененных значений в структуру zavp
                for i = 1:length(zavp.realStim)
                    zavp.realStim(i).r(:) = stims((i-1)*length(zavp.realStim(i).r)+1:i*length(zavp.realStim(i).r)) / zavp.siS;
                end
            else
                for ch_inx = selectedChannels
                    time_cond = new_spks(ch_inx).tStamp/1000 >= time_start & new_spks(ch_inx).tStamp/1000 <= time_end;
                    new_spks(ch_inx).tStamp = new_spks(ch_inx).tStamp(time_cond) + append_start_time*1000;% ms
                    new_spks(ch_inx).ampl = new_spks(ch_inx).ampl(time_cond);
                end
            end
            
            spks = [spks; new_spks(selectedChannels)];
        end
        
        hd.recChNames = channelNames';
        
        numChannels = length(channelNames);

        % Update time and other settings
        N = size(lfp, 1);
        time = (0:N-1) / Fs;

        time_forward = 0.6;
        time_back = 0.6;
        chosen_time_interval = [0, time_forward];
        shiftCoeff = 200;
        newFs = 1000;
        selectedCenter = 'time';
        stim_inx = 1;
        show_spikes = false;
        show_CSD = false;

        % Update file path with selected channels
        [folder, matFileName, ext] = fileparts(filepath);
        matFilePath = [folder, '\', matFileName ' ' [new_channelNames{selectedChannels}], ext];
        [~, matFileName, ~] = fileparts(matFilePath);

        % Call external functions
        call_setStandardChannelSettings();
        call_updateTable();
        updatePlot();
        call_resetMainWindowButtons();

        close(fig);
    end
end
