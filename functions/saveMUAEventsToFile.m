function saveMUAEventsToFile(spks, ~, matFilePath, varargin)
% saveMUAEventsToFile - Сохраняет MUA в .mua

    p = inputParser;
    p.KeepUnmatched = true;
    addParameter(p, 'dialogTitle', 'Save MUA (.mua)');
    addParameter(p, 'defaultFileNameSuffix', '_mua');
    addParameter(p, 'channel_names', {});
    parse(p, varargin{:});
    params = p.Results;

    [basePath, baseName, ~] = fileparts(matFilePath);
    defaultFileName = fullfile(basePath, [baseName params.defaultFileNameSuffix '.mua']);
    [file, path] = uiputfile('*.mua', params.dialogTitle, defaultFileName);
    if isequal(file, 0)
        disp('File save canceled.');
        return;
    end
    filepath = fullfile(path, file);

    channel_names = params.channel_names;

    save(filepath, 'spks', 'channel_names');
    fprintf('Saved MUA spks to %s\n', file);
end

