% Function to process data from the specified recording folder and return a table with accumulated data
function dataTable = readOpenEphysSession(rec_path)

    % Initialize arrays to hold the data for the table
    pathArray = {};
    continuousSamplesArray = {};
    continuousTimestampsArray = {};
    sampleRateArray = {}; % Array to hold sample rates
    channelNamesArray = {}; % Array to hold channel names
    eventsTimestampsArray = {};
    eventsLinesArray = {};
    eventsStatesArray = {};
    spikesTimestampsArray = {};
    spikesWaveformsArray = {};
    metaDataArray = {}; % Array to hold metadata

    % Create a session (loads all data from the recording folder)
    session = Session(rec_path);

    % Get the number of record nodes for this session
    nRecordNodes = length(session.recordNodes);

    % Helper function to clean up field names
    function validName = sanitizeFieldName(name)
        % Replace invalid characters (anything that is not a letter, number, or underscore)
        validName = regexprep(name, '[^a-zA-Z0-9_]', '_');
        % Add a prefix if the name starts with a number
        if isstrprop(validName(1), 'digit')
            validName = ['stream_' validName];
        end
    end

    % Iterate over the record nodes to access data
    for i = 1:nRecordNodes

        node = session.recordNodes{i};
        nodeName = ['Node_', num2str(i)];

        for j = 1:length(node.recordings)

            % Get the recording
            recording = node.recordings{1,j};
            recName = ['Recording_', num2str(j)];

            % Create a base path for this recording
            basePath = ['recordedData_', nodeName, '_', recName];
            
            % Iterate over all data streams in the recording 
            streamNames = recording.continuous.keys();
            for k = 1:length(streamNames)

                streamName = streamNames{k};
                sanitizedStreamName = sanitizeFieldName(streamName);

                % Get the continuous data from the current stream/recording
                data = recording.continuous(streamName);
                
                if ~isfield(data.metadata, 'sampleRate')
                    data.metadata.sampleRate = [];
                end
                if ~isfield(data.metadata, 'names')
                    data.metadata.names = [];
                end
                
                % Append data to the respective arrays
                pathArray{end+1,1} = [basePath, '_', sanitizedStreamName];
                continuousSamplesArray{end+1,1} = data.samples;
                continuousTimestampsArray{end+1,1} = data.timestamps;
                sampleRateArray{end+1,1} = data.metadata.sampleRate; % Accumulate sample rate
                channelNamesArray{end+1,1} = data.metadata.names; % Accumulate channel names
                eventsTimestampsArray{end+1,1} = [];
                eventsLinesArray{end+1,1} = [];
                eventsStatesArray{end+1,1} = [];
                spikesTimestampsArray{end+1,1} = [];
                spikesWaveformsArray{end+1,1} = [];                
                metaDataArray{end+1,1} = data.metadata; % Example metadata: start time

            end

            % Process available event data
            eventProcessors = recording.ttlEvents.keys();
            for p = 1:length(eventProcessors)
                processor = eventProcessors{p};
                sanitizedProcessorName = sanitizeFieldName(processor);
                events = recording.ttlEvents(processor);

                % Append event data to the respective arrays
                pathArray{end+1,1} = [basePath, '_', sanitizedProcessorName];
                continuousSamplesArray{end+1,1} = [];
                continuousTimestampsArray{end+1,1} = [];
                sampleRateArray{end+1,1} = []; % No sample rate for events
                channelNamesArray{end+1,1} = []; % No channel names for events
                if ~isempty(events)
                    eventsTimestampsArray{end+1,1} = events.timestamp;
                    eventsLinesArray{end+1,1} = events.line;
                    eventsStatesArray{end+1,1} = events.state;
                else
                    eventsTimestampsArray{end+1,1} = [];
                    eventsLinesArray{end+1,1} = [];
                    eventsStatesArray{end+1,1} = [];
                end
                spikesTimestampsArray{end+1,1} = [];
                spikesWaveformsArray{end+1,1} = [];
                
                % Add placeholder metadata for events (could be expanded if needed)
                metaDataArray{end+1,1} = [];
            end

            % Process spike data from electrodes
            if recording.spikes.Count > 0
                electrodes = recording.spikes.keys;
                for e = 1:length(electrodes)
                    % Get all spikes for this electrode
                    electrodeName = electrodes{e};
                    sanitizedElectrodeName = sanitizeFieldName(electrodeName);
                    spikes = recording.spikes(electrodes{e});

                    % Append spike data to the respective arrays
                    pathArray{end+1,1} = [basePath, '_', sanitizedElectrodeName];
                    continuousSamplesArray{end+1,1} = [];
                    continuousTimestampsArray{end+1,1} = [];
                    sampleRateArray{end+1,1} = []; % No sample rate for spikes
                    channelNamesArray{end+1,1} = []; % No channel names for spikes
                    eventsTimestampsArray{end+1,1} = [];
                    eventsLinesArray{end+1,1} = [];
                    eventsStatesArray{end+1,1} = [];
                    spikesTimestampsArray{end+1,1} = spikes.timestamps;
                    spikesWaveformsArray{end+1,1} = spikes.waveforms;
                    
                    % Add placeholder metadata for spikes (could be expanded if needed)
                    metaDataArray{end+1,1} = [];
                end
            end
        end
    end

    % Create a table from the accumulated data, including sample rates, channel names, and metadata
    dataTable = table(pathArray, continuousSamplesArray, continuousTimestampsArray, sampleRateArray, channelNamesArray, ...
                      eventsTimestampsArray, eventsLinesArray, eventsStatesArray, ...
                      spikesTimestampsArray, spikesWaveformsArray, metaDataArray, ...
                      'VariableNames', {'Path', 'Continuous_Samples', 'Continuous_Timestamps', 'Sample_Rate', 'Channel_Names', ...
                                        'Events_Timestamps', 'Events_Lines', 'Events_States', ...
                                        'Spikes_Timestamps', 'Spikes_Waveforms', 'Metadata'});
                                    
    % Find rows where Path is filled, but all other columns are empty
    rowsToRemove = ~cellfun(@isempty, dataTable.Path) & all(cellfun(@isempty, dataTable{:, 2:end-1}), 2);

    % Remove those rows
    dataTable(rowsToRemove, :) = [];

end
