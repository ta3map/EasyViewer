% Function to read only metadata from Open Ephys session without loading data
% Returns a table with metadata (sample rates, channel names) for GUI display
function metadataTable = readOpenEphysMetadata(rec_path)

    sampleRateArray = {};
    channelNamesArray = {};
    pathArray = {};

    % Helper function to clean up field names
    function validName = sanitizeFieldName(name)
        validName = regexprep(name, '[^a-zA-Z0-9_]', '_');
        if ~isempty(validName) && isstrprop(validName(1), 'digit')
            validName = ['stream_' validName];
        end
    end

    % Check for settings.xml (indicates Record Node directory)
    settingsFile = fullfile(rec_path, 'settings.xml');
    
    % Check for Record Node directories
    recordNodeDirs = {};
    if exist(settingsFile, 'file') == 2
        % This is a Record Node directory itself
        recordNodeDirs = {rec_path};
    else
        recordNodeDirs = glob(fullfile(rec_path, 'Record Node *'));
        if isempty(recordNodeDirs)
            % Fallback: treat selected folder as a potential Record Node root.
            % This supports direct selection of "Record Node NNN" even without
            % settings.xml/structure.oebin on that exact level.
            recordNodeDirs = {rec_path};
        end
    end

    % Process each Record Node
    for nodeIdx = 1:length(recordNodeDirs)
        nodeDir = recordNodeDirs{nodeIdx};
        nodeName = ['Node_', num2str(nodeIdx)];

        % Check for experiment directories
        experimentDirs = glob(fullfile(nodeDir, 'experiment*'));
        
        if isempty(experimentDirs)
            % Check if structure.oebin is directly in nodeDir
            structureFile = fullfile(nodeDir, 'structure.oebin');
            if exist(structureFile, 'file')
                experimentDirs = {nodeDir};
            end
        end

        for expIdx = 1:length(experimentDirs)
            expDir = experimentDirs{expIdx};
            
            % Check for recording directories
            recordingDirs = glob(fullfile(expDir, 'recording*'));
            
            if isempty(recordingDirs)
                % Check if structure.oebin is directly in expDir
                structureFile = fullfile(expDir, 'structure.oebin');
                if exist(structureFile, 'file')
                    recordingDirs = {expDir};
                end
            end

            for recIdx = 1:length(recordingDirs)
                recDir = recordingDirs{recIdx};
                recName = ['Recording_', num2str(recIdx)];
                basePath = ['recordedData_', nodeName, '_', recName];

                structureFile = fullfile(recDir, 'structure.oebin');
                
                if ~exist(structureFile, 'file')
                    continue;
                end

                % Read structure.oebin JSON file
                try
                    info = jsondecode(fileread(structureFile));
                catch
                    continue;
                end

                % Process continuous streams
                if isfield(info, 'continuous') && ~isempty(info.continuous)
                    for i = 1:length(info.continuous)
                        streamName = info.continuous(i).folder_name(1:end-1);
                        sanitizedStreamName = sanitizeFieldName(streamName);

                        % Extract metadata
                        sampleRate = info.continuous(i).sample_rate;
                        channelNames = {};
                        if isfield(info.continuous(i), 'channels') && ~isempty(info.continuous(i).channels)
                            for j = 1:length(info.continuous(i).channels)
                                if isfield(info.continuous(i).channels(j), 'channel_name')
                                    channelNames{j} = info.continuous(i).channels(j).channel_name;
                                end
                            end
                        end

                        pathArray{end+1,1} = [basePath, '_', sanitizedStreamName];
                        sampleRateArray{end+1,1} = sampleRate;
                        channelNamesArray{end+1,1} = channelNames;
                    end
                end
            end
        end
    end

    if isempty(pathArray)
        error('No Open Ephys metadata found in %s. Select a Session or Record Node folder containing experiment*/recording* data.', rec_path);
    end

    % Create table with metadata only
    metadataTable = table(pathArray, sampleRateArray, channelNamesArray, ...
        'VariableNames', {'Path', 'Sample_Rate', 'Channel_Names'});

end

