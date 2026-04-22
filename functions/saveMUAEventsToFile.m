function saveMUAEventsToFile(spks, ~, matFilePath, varargin)
% saveMUAEventsToFile - Сохраняет MUA в .mua (плоский spks или spks_events + event_times_sec)

    wb = waitbar(0, 'Preparing MUA save...', 'Name', 'Save MUA');
    p = inputParser;
    p.KeepUnmatched = true;
    addParameter(p, 'dialogTitle', 'Save MUA (.mua)');
    addParameter(p, 'defaultFileNameSuffix', '_mua');
    addParameter(p, 'channel_names', {});
    addParameter(p, 'filepath', '');
    addParameter(p, 'spks_events', {});
    addParameter(p, 'event_times_sec', []);
    addParameter(p, 'events', []);
    addParameter(p, 'events_index', []);
    addParameter(p, 'events_filepath', '');
    addParameter(p, 'original_filepath', '');
    addParameter(p, 'fileExtension', '.mua');
    parse(p, varargin{:});
    params = p.Results;
    fileExtension = params.fileExtension;
    if isempty(fileExtension)
        fileExtension = '.mua';
    end
    if fileExtension(1) ~= '.'
        fileExtension = ['.' fileExtension];
    end

    [basePath, baseName, ~] = fileparts(matFilePath);
    defaultFileName = fullfile(basePath, [baseName params.defaultFileNameSuffix fileExtension]);
    filepath = params.filepath;
    waitbar(0.2, wb, 'Selecting output path...');
    if isempty(filepath)
        [file, path] = uiputfile(['*' fileExtension], params.dialogTitle, defaultFileName);
        if isequal(file, 0)
            close(wb);
            disp('File save canceled.');
            return;
        end
        filepath = fullfile(path, file);
    else
        [~, file, ext] = fileparts(filepath);
        if isempty(ext)
            filepath = [filepath fileExtension];
            [~, file, ~] = fileparts(filepath);
        end
    end

    if exist(filepath, 'file')
        overwriteChoice = questdlg( ...
            sprintf('File already exists:\n%s\n\nOverwrite?', filepath), ...
            'Confirm overwrite', ...
            'Overwrite', 'Cancel', 'Cancel');
        if ~strcmp(overwriteChoice, 'Overwrite')
            close(wb);
            disp('MUA save canceled (overwrite declined).');
            return;
        end
    end

    waitbar(0.6, wb, 'Saving file...');
    channel_names = params.channel_names;
    spks_events = params.spks_events;
    event_times_sec = params.event_times_sec(:);
    events = params.events(:);
    events_index = params.events_index(:);
    events_filepath = params.events_filepath;
    original_filepath = params.original_filepath;

    if ~isempty(spks_events)
        if isempty(events)
            events = event_times_sec;
        end
        save(filepath, 'spks_events', 'event_times_sec', 'channel_names', 'events', ...
            'events_index', 'events_filepath', 'original_filepath');
        waitbar(1.0, wb, 'Done');
        close(wb);
        fprintf('Saved MUA spks_events (%d trials) to %s\n', numel(spks_events), file);
        return;
    end

    save(filepath, 'spks', 'channel_names', 'events', 'events_index', 'events_filepath', 'original_filepath');
    waitbar(1.0, wb, 'Done');
    close(wb);
    fprintf('Saved MUA spks to %s\n', file);
end
