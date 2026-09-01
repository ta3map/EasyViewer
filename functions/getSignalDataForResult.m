function [signal_data, time_data] = getSignalDataForResult(metadata)
    global lfp_file time time_back
    global newFs Fs
    global filterSettings filter_avaliable mean_group_ch
    global stims stims_exist
    global visualSettings art_rem_settings

    signal_data = [];
    time_data = [];

    local_chosen_time_interval = metadata.chosen_time_interval;
    plot_time_interval = local_chosen_time_interval;
    plot_time_interval(1) = plot_time_interval(1) - time_back;

    selected_channel = metadata.channel;
    [local_lfp, time_data, cols] = readLfpChannelsForInterval( ...
        lfp_file, time, plot_time_interval, selected_channel, mean_group_ch);
    if isempty(local_lfp)
        return;
    end

    ch_local = find(cols == selected_channel, 1, 'first');
    signal_data = local_lfp(:, ch_local)';
    time_data = time_data(:)';

    if strcmp(metadata.selectedCenter, 'stimulus') && stims_exist && ~isempty(stims)
        local_rel_shift = stims(metadata.stim_inx);
    else
        local_rel_shift = local_chosen_time_interval(1);
    end

    stims_in = [];
    if ~isempty(stims) && visualSettings.stim_show
        Fs_fascor = Fs / 1000;
        local_stim = stims(metadata.stim_inx);
        local_stim_rel = local_stim - time_data(1);
        time_data_rel = time_data - time_data(1);
        signal_col = signal_data(:);
        signal_col = removeStimArtifact(signal_col, local_stim_rel, time_data_rel(:), ...
            art_rem_settings.artifact_window_ms * Fs_fascor * 0.5, art_rem_settings.interp_method);
        signal_data = signal_col';
    end

    time_data = time_data - local_rel_shift;

    if sum(filter_avaliable) > 0 && filter_avaliable(selected_channel)
        signal_data = applyFilter(signal_data, filterSettings, newFs);
    end
end
