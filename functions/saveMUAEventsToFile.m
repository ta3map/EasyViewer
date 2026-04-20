function saveMUAEventsToFile(spks, ~, matFilePath, varargin)
% saveMUAEventsToFile - Сохраняет MUA в .mua

    wb = waitbar(0, 'Preparing MUA save...', 'Name', 'Save MUA');
    p = inputParser;
    p.KeepUnmatched = true;
    addParameter(p, 'dialogTitle', 'Save MUA (.mua)');
    addParameter(p, 'defaultFileNameSuffix', '_mua');
    addParameter(p, 'channel_names', {});
    addParameter(p, 'filepath', '');
    parse(p, varargin{:});
    params = p.Results;

    [basePath, baseName, ~] = fileparts(matFilePath);
    defaultFileName = fullfile(basePath, [baseName params.defaultFileNameSuffix '.mua']);
    filepath = params.filepath;
    waitbar(0.2, wb, 'Selecting output path...');
    if isempty(filepath)
        [file, path] = uiputfile('*.mua', params.dialogTitle, defaultFileName);
        if isequal(file, 0)
            close(wb);
            disp('File save canceled.');
            return;
        end
        filepath = fullfile(path, file);
    else
        [~, file, ext] = fileparts(filepath);
        if isempty(ext)
            filepath = [filepath '.mua'];
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

    save(filepath, 'spks', 'channel_names');
    waitbar(1.0, wb, 'Done');
    close(wb);
    fprintf('Saved MUA spks to %s\n', file);
end

