function oep_to_zav_streaming(rec_path, zavFilePath, Fs, newFs, detectMua, mua_std_coef, doResample, channelNames, selectedChIndexes, useStreamingMUA)
% OEP_TO_ZAV_STREAMING Converts Open Ephys data to ZAV format using streaming approach
% Reads data in chunks from binary files and writes directly to MAT file
%
%   Args:
%       rec_path: Path to Open Ephys recording directory
%       zavFilePath: Full path to the output .mat file (will be saved in v7.3 format)
%       Fs: Original sampling frequency (Hz)
%       newFs: Target sampling frequency for LFP resampling (Hz). Ignored if doResample is false
%       detectMua: Boolean flag to enable/disable MUA detection
%       mua_std_coef: Standard deviation coefficient for MUA detection threshold
%       doResample: Boolean flag to enable/disable LFP resampling
%       channelNames: Cell array of all channel names in the original data
%       selectedChIndexes: Numeric array of indices of the channels to process and save
%       useStreamingMUA: Boolean flag to use streaming MUA detection (default: true)
%
%   If useStreamingMUA is true, MUA detection processes data in chunks without
%   loading entire channel into memory. If false, loads entire channel first.

    if nargin < 10
        useStreamingMUA = true; % По умолчанию используем потоковую версию
    end

    fprintf('\n========================================\n');
    fprintf('OEP_TO_ZAV_STREAMING - NEW VERSION CALLED!\n');
    fprintf('========================================\n');
    debugState('oep_to_zav_streaming', 'Starting streaming conversion');
    debugState('oep_to_zav_streaming', 'Input path: %s', rec_path);
    debugState('oep_to_zav_streaming', 'Output file: %s', zavFilePath);
    
    % Chunk size for reading data (number of samples per channel per chunk)
    CHUNK_SIZE = 100000; % ~100k samples per chunk
    
    selectedChannels = channelNames(selectedChIndexes);
    numChannels = numel(selectedChannels);
    
    debugState('oep_to_zav_streaming', 'Processing %d channels using streaming approach', numChannels);
    disp(['Processing ', num2str(numChannels), ' channels using streaming approach.']);

    % Find all continuous streams directly from file system (avoid loading Session/RecordNode)
    debugState('oep_to_zav_streaming', 'Scanning file system for recordings (avoiding Session object)...');
    
    allStreams = {};
    streamPaths = {};
    streamMetadata = {};
    
    % Check if this is a Record Node directory or session directory
    settingsFile = fullfile(rec_path, 'settings.xml');
    recordNodeDirs = {};
    
    if exist(settingsFile, 'file')
        % This is a Record Node directory itself
        recordNodeDirs = {rec_path};
    else
        % Check for Record Node directories
        recordNodeDirs = glob(fullfile(rec_path, 'Record Node *'));
        if isempty(recordNodeDirs)
            recordNodeDirs = {rec_path};
        end
    end
    
    debugState('oep_to_zav_streaming', 'Found %d record node directories', length(recordNodeDirs));
    
    % Process each Record Node directory
    for nodeIdx = 1:length(recordNodeDirs)
        nodeDir = recordNodeDirs{nodeIdx};
        
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
                structureFile = fullfile(recDir, 'structure.oebin');
                
                if ~exist(structureFile, 'file')
                    continue;
                end
                
                debugState('oep_to_zav_streaming', 'Reading structure.oebin from: %s', recDir);
                
                % Read structure.oebin directly (no object creation)
                info = jsondecode(fileread(structureFile));
                
                % Process continuous streams
                if isfield(info, 'continuous') && ~isempty(info.continuous)
                    for k = 1:length(info.continuous)
                        streamDir = fullfile(recDir, 'continuous', info.continuous(k).folder_name);
                        continuousFile = fullfile(streamDir, 'continuous.dat');
                        
                        if exist(continuousFile, 'file')
                            streamMetadata{end+1} = info.continuous(k);
                            streamPaths{end+1} = streamDir;
                            allStreams{end+1} = continuousFile;
                            debugState('oep_to_zav_streaming', 'Found stream: %s', info.continuous(k).folder_name);
                        end
                    end
                end
            end
        end
    end
    
    if isempty(allStreams)
        debugState('oep_to_zav_streaming', 'ERROR: No continuous data files found');
        error('No continuous data files found in %s', rec_path);
    end
    
    debugState('oep_to_zav_streaming', 'Found %d continuous streams', length(allStreams));
    
    % Calculate total length from all streams
    totalSamples = 0;
    for streamIdx = 1:length(streamPaths)
        streamDir = streamPaths{streamIdx};
        timestampsFile = fullfile(streamDir, 'timestamps.npy');
        if exist(timestampsFile, 'file')
            timestamps = readNPY(timestampsFile);
            totalSamples = totalSamples + length(timestamps);
        end
    end
    
    % Calculate final length after resampling
    if doResample
        % Estimate from first chunk
        testChunk = min(CHUNK_SIZE, 10000);
        testData = zeros(testChunk, 1);
        resampledTest = resample(testData, newFs, Fs);
        resampleRatio = length(resampledTest) / testChunk;
        final_lfp_length = round(totalSamples * resampleRatio);
    else
        final_lfp_length = totalSamples;
    end
    
    debugState('oep_to_zav_streaming', 'Total samples: %d, Final LFP length: %d', totalSamples, final_lfp_length);
    disp(['Total samples: ', num2str(totalSamples), ', Final LFP length: ', num2str(final_lfp_length)]);
    
    % Initialize MAT file
    debugState('oep_to_zav_streaming', 'Initializing output MAT file...');
    disp(['Initializing output file: ', zavFilePath]);
    m = matfile(zavFilePath, 'Writable', true);
    
    % Save header
    hd.fFileSignature = 'Openephys';
    hd.recChNames = selectedChannels;
    hd.si = (1/Fs) * 1e6;
    m.hd = hd;
    m.chnlGrp = {};
    
    % Prepare zavp structure
    zavp.file = zavFilePath;
    zavp.siS = 1 / Fs;
    if doResample
        zavp.dwnSmplFrq = newFs;
        zavp.rarStep = zeros(1, numChannels) + (Fs / newFs);
    else
        zavp.dwnSmplFrq = Fs;
        zavp.rarStep = ones(1, numChannels);
    end
    zavp.stimCh = nan;
    zavp.realStim.r = [];
    zavp.realStim.f = [];
    m.zavp = zavp;
    
    % Initialize LFP array in file
    m.lfp(final_lfp_length, numChannels) = 0.0;
    
    % Create unified progress bar
    hWaitBar = waitbar(0, 'Initializing conversion...', 'Name', 'OEP to ZAV Conversion');
    mainPos = get(hWaitBar, 'Position');
    
    % Create separate progress bar for rows written, positioned below main bar
    hRowsBar = waitbar(0, 'Rows written: 0 / 0 (0.0%)', 'Name', 'Rows Progress');
    rowsPos = get(hRowsBar, 'Position');
    rowsPos(1) = mainPos(1); % Same X position
    rowsPos(2) = mainPos(2) - rowsPos(4) - 10; % Below main bar with 10px gap
    set(hRowsBar, 'Position', rowsPos);
    
    % Create separate progress bar for chunks processing
    hChunksBar = waitbar(0, 'Processing chunks: 0 / 0', 'Name', 'Chunks Progress');
    chunksPos = get(hChunksBar, 'Position');
    chunksPos(1) = mainPos(1); % Same X position
    chunksPos(2) = rowsPos(2) - chunksPos(4) - 10; % Below rows bar with 10px gap
    set(hChunksBar, 'Position', chunksPos);
    
    % Create separate progress bar for spike detection
    hSpikesBar = waitbar(0, 'Detecting spikes...', 'Name', 'Spike Detection');
    spikesPos = get(hSpikesBar, 'Position');
    spikesPos(1) = mainPos(1); % Same X position
    spikesPos(2) = chunksPos(2) - spikesPos(4) - 10; % Below chunks bar with 10px gap
    set(hSpikesBar, 'Position', spikesPos);
    
    % Process MUA detection if enabled
    spks = struct('tStamp', cell(1, numChannels), 'ampl', cell(1, numChannels), 'shape', cell(1, numChannels));
    
    if detectMua
        debugState('oep_to_zav_streaming', 'Starting MUA detection with streaming...');
        disp('Starting MUA detection with streaming...');
        
        % Calculate total chunks for MUA (same as for LFP)
        totalMuaChunksPerChannel = 0;
        for streamIdx = 1:length(allStreams)
            metadata = streamMetadata{streamIdx};
            continuousFile = allStreams{streamIdx};
            fileInfo = dir(continuousFile);
            totalBytes = fileInfo.bytes;
            numChannelsInStream = metadata.num_channels;
            totalSamplesInFile = totalBytes / 2 / numChannelsInStream;
            totalMuaChunksPerChannel = totalMuaChunksPerChannel + ceil(totalSamplesInFile / CHUNK_SIZE);
        end
        
        % Calculate total work: MUA (50%) + LFP (50%)
        totalWork = numChannels * 2; % MUA + LFP for each channel
        
        for chIdx = 1:numChannels
            current_channel_global_index = selectedChIndexes(chIdx);
            channelName = strrep(channelNames{current_channel_global_index}, '_', ' ');
            
            if useStreamingMUA
                % Потоковая детекция MUA - обрабатываем данные по частям
                debugState('oep_to_zav_streaming', 'Using streaming MUA detection for channel: %s', channelName);
                
                dataChunks = {};
                muaChunksProcessed = 0;
                
                for streamIdx = 1:length(allStreams)
                    streamDir = streamPaths{streamIdx};
                    metadata = streamMetadata{streamIdx};
                    continuousFile = allStreams{streamIdx};
                    
                    numChannelsInStream = metadata.num_channels;
                    
                    % Check if channel index is valid for this stream
                    if current_channel_global_index > numChannelsInStream
                        continue;
                    end
                    
                    % Read data in chunks using memmapfile
                    fileInfo = dir(continuousFile);
                    totalBytes = fileInfo.bytes;
                    totalSamplesInFile = totalBytes / 2 / numChannelsInStream; % int16 = 2 bytes
                    
                    % Read in chunks to avoid loading all at once
                    numChunks = ceil(totalSamplesInFile / CHUNK_SIZE);
                    
                    for chunkIdx = 1:numChunks
                        startSample = (chunkIdx - 1) * CHUNK_SIZE + 1;
                        endSample = min(chunkIdx * CHUNK_SIZE, totalSamplesInFile);
                        chunkLength = endSample - startSample + 1;
                        
                        offsetBytes = (startSample - 1) * numChannelsInStream * 2;
                        dataMap = memmapfile(continuousFile, 'Format', 'int16', 'Writable', false, ...
                            'Offset', offsetBytes, 'Repeat', chunkLength * numChannelsInStream);
                        
                        dataChunk = reshape(dataMap.Data, [numChannelsInStream, chunkLength]);
                        channelChunk = double(dataChunk(current_channel_global_index, :))';
                        dataChunks{end+1} = channelChunk;
                        
                        muaChunksProcessed = muaChunksProcessed + 1;
                        
                        % Update progress for MUA data collection
                        muaProgress = (chIdx - 1) / numChannels + (muaChunksProcessed / totalMuaChunksPerChannel) / numChannels;
                        progress = muaProgress / 2; % MUA is first half
                        progressMsg = sprintf('MUA (streaming): Channel %d/%d (%s)', chIdx, numChannels, channelName);
                        waitbar(progress, hWaitBar, progressMsg);
                        
                        % Update chunks progress bar
                        chunksProgress = muaChunksProcessed / totalMuaChunksPerChannel;
                        chunksMsg = sprintf('Processing chunks: %d / %d (%.1f%%)', ...
                            muaChunksProcessed, totalMuaChunksPerChannel, chunksProgress * 100);
                        waitbar(chunksProgress, hChunksBar, chunksMsg);
                        
                        clear dataMap dataChunk channelChunk;
                    end
                end
                
                % Detect MUA using streaming version
                progressMsg = sprintf('MUA (streaming): Channel %d/%d (%s)', chIdx, numChannels, channelName);
                waitbar((chIdx - 0.5) / totalWork, hWaitBar, progressMsg);
                
                % Update spikes detection progress bar
                waitbar(0.5, hSpikesBar, sprintf('Detecting spikes: Channel %d/%d (%s)...', chIdx, numChannels, channelName));
                
                disp(['Detecting MUA (streaming) for channel: ', channelName]);
                [tStamp, ampl, shape] = detectMUA_streaming(dataChunks, hd, mua_std_coef, true, Fs);
                
                waitbar(1, hSpikesBar, sprintf('Spikes detected: Channel %d/%d (%s) - Complete', chIdx, numChannels, channelName));
                spks(chIdx).tStamp = double(tStamp);
                spks(chIdx).ampl = double(-ampl);
                spks(chIdx).shape = shape;
                
                clear dataChunks tStamp ampl shape;
            else
                % Классическая детекция MUA - загружаем весь канал
                debugState('oep_to_zav_streaming', 'Using full-channel MUA detection for channel: %s', channelName);
                
                lfp_channel_data_for_mua = [];
                muaChunksProcessed = 0;
                
                for streamIdx = 1:length(allStreams)
                    streamDir = streamPaths{streamIdx};
                    metadata = streamMetadata{streamIdx};
                    continuousFile = allStreams{streamIdx};
                    
                    numChannelsInStream = metadata.num_channels;
                    
                    % Check if channel index is valid for this stream
                    if current_channel_global_index > numChannelsInStream
                        continue;
                    end
                    
                    % Read data in chunks using memmapfile
                    fileInfo = dir(continuousFile);
                    totalBytes = fileInfo.bytes;
                    totalSamplesInFile = totalBytes / 2 / numChannelsInStream; % int16 = 2 bytes
                    
                    % Read in chunks to avoid loading all at once
                    numChunks = ceil(totalSamplesInFile / CHUNK_SIZE);
                    
                    for chunkIdx = 1:numChunks
                        startSample = (chunkIdx - 1) * CHUNK_SIZE + 1;
                        endSample = min(chunkIdx * CHUNK_SIZE, totalSamplesInFile);
                        chunkLength = endSample - startSample + 1;
                        
                        offsetBytes = (startSample - 1) * numChannelsInStream * 2;
                        dataMap = memmapfile(continuousFile, 'Format', 'int16', 'Writable', false, ...
                            'Offset', offsetBytes, 'Repeat', chunkLength * numChannelsInStream);
                        
                        dataChunk = reshape(dataMap.Data, [numChannelsInStream, chunkLength]);
                        channelChunk = double(dataChunk(current_channel_global_index, :))';
                        lfp_channel_data_for_mua = [lfp_channel_data_for_mua; channelChunk];
                        
                        muaChunksProcessed = muaChunksProcessed + 1;
                        
                        % Update progress for MUA data collection
                        muaProgress = (chIdx - 1) / numChannels + (muaChunksProcessed / totalMuaChunksPerChannel) / numChannels;
                        progress = muaProgress / 2; % MUA is first half
                        progressMsg = sprintf('MUA (full): Channel %d/%d (%s)', chIdx, numChannels, channelName);
                        waitbar(progress, hWaitBar, progressMsg);
                        
                        % Update chunks progress bar
                        chunksProgress = muaChunksProcessed / totalMuaChunksPerChannel;
                        chunksMsg = sprintf('Collecting chunks: %d / %d (%.1f%%)', ...
                            muaChunksProcessed, totalMuaChunksPerChannel, chunksProgress * 100);
                        waitbar(chunksProgress, hChunksBar, chunksMsg);
                        
                        clear dataMap dataChunk channelChunk;
                    end
                end
                
                % Detect MUA using classic version
                progressMsg = sprintf('MUA (full): Channel %d/%d (%s)', chIdx, numChannels, channelName);
                waitbar((chIdx - 0.5) / totalWork, hWaitBar, progressMsg);
                
                % Update spikes detection progress bar
                waitbar(0.5, hSpikesBar, sprintf('Detecting spikes: Channel %d/%d (%s)...', chIdx, numChannels, channelName));
                
                disp(['Detecting MUA (full-channel) for channel: ', channelName]);
                [tStamp, ampl, shape] = detectMUA(lfp_channel_data_for_mua, hd, mua_std_coef, true);
                
                waitbar(1, hSpikesBar, sprintf('Spikes detected: Channel %d/%d (%s) - Complete', chIdx, numChannels, channelName));
                spks(chIdx).tStamp = double(tStamp);
                spks(chIdx).ampl = double(-ampl);
                spks(chIdx).shape = shape;
                
                clear lfp_channel_data_for_mua tStamp ampl shape;
            end
            
            progress = chIdx / totalWork;
            progressMsg = sprintf('MUA: Channel %d/%d (%s) - Complete', ...
                chIdx, numChannels, channelName);
            waitbar(progress, hWaitBar, progressMsg);
        end
        
        m.spks = spks;
        clear spks;
    else
        m.spks = spks;
        clear spks;
        % If no MUA, adjust total work
        totalWork = numChannels;
        currentWork = 0;
    end
    
    % Process LFP data channel by channel with streaming
    debugState('oep_to_zav_streaming', 'Starting LFP processing with streaming...');
    disp('Processing LFP data channel by channel with streaming...');
    
    lfpVar_channelwise = zeros(1, numChannels);
    
    % Calculate total chunks per channel for progress estimation
    totalChunksPerChannel = 0;
    for streamIdx = 1:length(allStreams)
        metadata = streamMetadata{streamIdx};
        continuousFile = allStreams{streamIdx};
        fileInfo = dir(continuousFile);
        totalBytes = fileInfo.bytes;
        numChannelsInStream = metadata.num_channels;
        totalSamplesInFile = totalBytes / 2 / numChannelsInStream;
        totalChunksPerChannel = totalChunksPerChannel + ceil(totalSamplesInFile / CHUNK_SIZE);
    end
    
    for chIdx = 1:numChannels
        current_channel_global_index = selectedChIndexes(chIdx);
        channelName = strrep(channelNames{current_channel_global_index}, '_', ' ');
        disp(['Processing LFP for channel: ', channelName]);
        
        currentRow = 1;
        channelDataForVariance = [];
        channelChunksProcessed = 0;
        totalChunksForCurrentChannel = 0;
        
        % Calculate total chunks for current channel
        for streamIdx = 1:length(allStreams)
            metadata = streamMetadata{streamIdx};
            continuousFile = allStreams{streamIdx};
            numChannelsInStream = metadata.num_channels;
            if current_channel_global_index <= numChannelsInStream
                fileInfo = dir(continuousFile);
                totalBytes = fileInfo.bytes;
                totalSamplesInFile = totalBytes / 2 / numChannelsInStream;
                totalChunksForCurrentChannel = totalChunksForCurrentChannel + ceil(totalSamplesInFile / CHUNK_SIZE);
            end
        end
        
        % Process each stream
        for streamIdx = 1:length(allStreams)
            streamDir = streamPaths{streamIdx};
            metadata = streamMetadata{streamIdx};
            continuousFile = allStreams{streamIdx};
            
            numChannelsInStream = metadata.num_channels;
            
            % Check if channel index is valid for this stream
            if current_channel_global_index > numChannelsInStream
                continue;
            end
            
            % Read data in chunks
            fileInfo = dir(continuousFile);
            totalBytes = fileInfo.bytes;
            totalSamplesInFile = totalBytes / 2 / numChannelsInStream;
            
            % Process in chunks to avoid loading all data at once
            numChunks = ceil(totalSamplesInFile / CHUNK_SIZE);
            
            for chunkIdx = 1:numChunks
                startSample = (chunkIdx - 1) * CHUNK_SIZE + 1;
                endSample = min(chunkIdx * CHUNK_SIZE, totalSamplesInFile);
                chunkLength = endSample - startSample + 1;
                
                % Read chunk using memmapfile
                offsetBytes = (startSample - 1) * numChannelsInStream * 2; % int16 = 2 bytes
                dataMap = memmapfile(continuousFile, 'Format', 'int16', 'Writable', false, ...
                    'Offset', offsetBytes, 'Repeat', chunkLength * numChannelsInStream);
                
                dataChunk = reshape(dataMap.Data, [numChannelsInStream, chunkLength]);
                channelChunk = double(dataChunk(current_channel_global_index, :))';
                
                % Resample if needed
                if doResample
                    channelChunk = resample(channelChunk, newFs, Fs);
                end
                
                % Write chunk directly to MAT file
                chunkLengthProcessed = length(channelChunk);
                endRow = currentRow + chunkLengthProcessed - 1;
                
                if endRow <= final_lfp_length
                    m.lfp(currentRow:endRow, chIdx) = channelChunk;
                    channelDataForVariance = [channelDataForVariance; channelChunk];
                else
                    % Truncate if exceeds final length
                    remainingRows = final_lfp_length - currentRow + 1;
                    if remainingRows > 0
                        m.lfp(currentRow:final_lfp_length, chIdx) = channelChunk(1:remainingRows);
                        channelDataForVariance = [channelDataForVariance; channelChunk(1:remainingRows)];
                    end
                    break;
                end
                
                currentRow = endRow + 1;
                channelChunksProcessed = channelChunksProcessed + 1;
                
                % Update progress bar with detailed info
                if detectMua
                    % MUA phase: numChannels, LFP phase: numChannels
                    lfpProgress = (chIdx - 1) / numChannels + (channelChunksProcessed / totalChunksPerChannel) / numChannels;
                    progress = (numChannels + lfpProgress * numChannels) / totalWork;
                else
                    % Only LFP phase
                    progress = (chIdx - 1) / numChannels + (channelChunksProcessed / totalChunksPerChannel) / numChannels;
                end
                
                progressMsg = sprintf('LFP: Channel %d/%d (%s)', chIdx, numChannels, channelName);
                waitbar(progress, hWaitBar, progressMsg);
                
                % Update chunks progress bar
                chunksProgress = channelChunksProcessed / totalChunksPerChannel;
                chunksMsg = sprintf('Processing chunks: %d / %d (%.1f%%)', ...
                    channelChunksProcessed, totalChunksPerChannel, chunksProgress * 100);
                waitbar(chunksProgress, hChunksBar, chunksMsg);
                
                % Update rows progress bar
                rowsProgress = (currentRow - 1) / final_lfp_length;
                rowsMsg = sprintf('Rows written: %d / %d (%.1f%%)', ...
                    currentRow - 1, final_lfp_length, rowsProgress * 100);
                waitbar(rowsProgress, hRowsBar, rowsMsg);
                
                clear dataMap dataChunk channelChunk;
            end
        end
        
        % Update progress after channel completion
        if detectMua
            progress = (numChannels + chIdx) / totalWork;
        else
            progress = chIdx / numChannels;
        end
        
        progressMsg = sprintf('LFP: Channel %d/%d (%s) - Complete', ...
            chIdx, numChannels, channelName);
        waitbar(progress, hWaitBar, progressMsg);
        
        % Update chunks progress bar after channel completion
        waitbar(1, hChunksBar, sprintf('Channel %d/%d complete', chIdx, numChannels));
        
        % Update rows progress bar after channel completion
        rowsProgress = (currentRow - 1) / final_lfp_length;
        rowsMsg = sprintf('Rows written: %d / %d (%.1f%%)', ...
            currentRow - 1, final_lfp_length, rowsProgress * 100);
        waitbar(rowsProgress, hRowsBar, rowsMsg);
        
        % Calculate variance
        if ~isempty(channelDataForVariance)
            lfpVar_channelwise(chIdx) = var(channelDataForVariance);
        end
        
        clear channelDataForVariance;
    end
    
    waitbar(1, hWaitBar, 'Finalizing...');
    
    % Save variance
    debugState('oep_to_zav_streaming', 'Saving LFP variance...');
    m.lfpVar = lfpVar_channelwise;
    
    waitbar(1, hWaitBar, 'Conversion complete!');
    waitbar(1, hChunksBar, 'All chunks processed');
    waitbar(1, hSpikesBar, 'All spikes detected');
    waitbar(1, hRowsBar, sprintf('Rows written: %d / %d (100.0%%)', final_lfp_length, final_lfp_length));
    pause(0.5);
    
    try
        close(hWaitBar);
        close(hChunksBar);
        close(hSpikesBar);
        close(hRowsBar);
    catch
    end
    
    debugState('oep_to_zav_streaming', 'Processing complete. Data saved to: %s', zavFilePath);
    disp('Processing complete. Data saved to:');
    disp(zavFilePath);
end

