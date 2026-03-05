function snapshotAllFrames(f, updatePlotFunc, shiftTimeFunc, timeForwardEdit)
    global matFilePath matFileName timeUnitFactor time chosen_time_interval
    global event_inx events eventDeleteEdit stims stim_inx stims_exist events_exist sweep_info sweep_inx selectedCenter data_loaded timeCenterPopup initialDir
    if ~data_loaded || isempty(matFilePath)
        msgbox('Load a file first.', 'Snapshot all frames');
        return;
    end
    popupStr = get(timeCenterPopup, 'String');
    selectedCenter = popupStr{get(timeCenterPopup, 'Value')};
    switch selectedCenter
        case 'event'
            if ~events_exist
                msgbox('No events loaded.', 'Snapshot all frames');
                return;
            end
        case 'stimulus'
            if ~stims_exist
                msgbox('No stimuli.', 'Snapshot all frames');
                return;
            end
        case 'sweep'
            if ~sweep_info.is_sweep_data
                msgbox('No sweep data.', 'Snapshot all frames');
                return;
            end
    end
    defaultDir = fileparts(matFilePath);
    if isempty(defaultDir)
        defaultDir = initialDir;
    end
    parentDir = uigetdir(defaultDir, 'Select folder for snapshots');
    if isequal(parentDir, 0)
        return;
    end
    snapshotsFolderName = [matFileName, '_snapshots'];
    snapshotsDir = fullfile(parentDir, snapshotsFolderName);
    mkdir(snapshotsDir);
    windowSize = str2double(get(timeForwardEdit, 'String')) / timeUnitFactor;
    switch selectedCenter
        case 'time'
            chosen_time_interval(1) = time(1);
            chosen_time_interval(2) = time(1) + windowSize;
        case 'stimulus'
            stim_inx = 1;
            chosen_time_interval(1) = stims(1);
            chosen_time_interval(2) = stims(1) + windowSize;
        case 'event'
            event_inx = 1;
            chosen_time_interval(1) = events(1);
            chosen_time_interval(2) = events(1) + windowSize;
            set(eventDeleteEdit, 'String', '1');
        case 'sweep'
            sweep_inx = 1;
            chosen_time_interval(1) = sweep_info.sweep_times(1);
            chosen_time_interval(2) = chosen_time_interval(1) + windowSize;
    end
    updatePlotFunc();
    drawnow;
    snapshotNum = 1;
    while true
        filename = sprintf('%s_%03d_%s.png', matFileName, snapshotNum, selectedCenter);
        saveas(f, fullfile(snapshotsDir, filename), 'png');
        prev_event_inx = event_inx;
        prev_stim_inx = stim_inx;
        prev_sweep_inx = sweep_inx;
        prev_interval = chosen_time_interval;
        shiftTimeFunc([], [], 1, timeForwardEdit);
        switch selectedCenter
            case 'event'
                if event_inx == prev_event_inx && event_inx >= numel(events)
                    break;
                end
            case 'stimulus'
                if stim_inx == prev_stim_inx && stim_inx >= numel(stims)
                    break;
                end
            case 'sweep'
                if sweep_inx == prev_sweep_inx && sweep_inx >= sweep_info.sweep_count
                    break;
                end
            case 'time'
                if chosen_time_interval(1) == prev_interval(1) && chosen_time_interval(2) == prev_interval(2)
                    break;
                end
        end
        snapshotNum = snapshotNum + 1;
    end
    winopen(snapshotsDir);
end
