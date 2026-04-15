function oep_to_zav_streaming(rec_path, zavFilePath, Fs, newFs, detectMua, mua_std_coef, doResample, channelNames, selectedChIndexes, hWaitBar)
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
%       hWaitBar: Optional waitbar handle to reuse existing progress bar
%
    
    % Create waitbar if not provided
    if nargin < 10 || isempty(hWaitBar)
        hWaitBar = waitbar(0, 'Initializing conversion...', 'Name', 'OEP to ZAV Conversion');
        closeWaitBar = true; % Flag to close waitbar at the end
    else
        closeWaitBar = false; % Don't close if provided from outside
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
        % Estimate from first chunk (используем resample1 для избежания краевых эффектов)
        testChunk = min(CHUNK_SIZE, 10000);
        testData = zeros(testChunk, 1);
        resampledTest = resample1(testData, newFs, Fs);
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
    % Создаем v7.3 файл, сохраняя только целевые поля (без workspace-мусора)
    hd = struct();
    zavp = struct();
    chnlGrp = {};
    spks = struct([]);
    lfpVar = [];
    save(zavFilePath, 'hd', 'zavp', 'chnlGrp', 'spks', 'lfpVar', '-v7.3');
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
    
    % Преаллокация массива lfp убрана - массив будет создаваться автоматически
    % при первой записи данных канала. Это позволяет избежать ошибки "out of memory"
    % при работе с большими массивами. Данные записываются напрямую на диск через HDF5.
    
    % Initialize progress bar if not already initialized
    waitbar(0, hWaitBar, 'Initializing conversion...');
    conversion_tic = tic;
    formatEta = @(sec) sprintf('~%d min %d s left', floor(sec / 60), round(rem(sec, 60)));
    
    % Calculate total number of steps
    % Each channel has: MUA processing (if enabled) + LFP processing
    if detectMua
        totalSteps = numChannels * 2; % MUA + LFP for each channel (combined in one pass)
    else
        totalSteps = numChannels; % Only LFP for each channel
    end
    currentStep = 0;
    
    % Process MUA detection and LFP in one pass
    spks = struct('tStamp', cell(1, numChannels), 'ampl', cell(1, numChannels), 'shape', cell(1, numChannels));
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
    
    debugState('oep_to_zav_streaming', 'Starting combined MUA+LFP processing in one pass...');
    disp('Processing MUA and LFP in one pass...');
    
    for chIdx = 1:numChannels
        current_channel_global_index = selectedChIndexes(chIdx);
        channelName = strrep(channelNames{current_channel_global_index}, '_', ' ');
        disp(['Processing channel: ', channelName]);
        
        % Инициализация для канала
        if detectMua
            lfp_channel_data_for_mua = [];
        end
        
        % Инициализируем массив lfp при обработке первого канала
        % Это создаст массив нужного размера в HDF5 файле без загрузки в RAM
        if chIdx == 1
            m.lfp(final_lfp_length, numChannels) = 0.0;
        end
        
        currentRow = 1;
        channelDataForVariance = [];
        chunksProcessed = 0;
        
        % ОДИН проход по всем streams и chunks
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
            
            numChunks = ceil(totalSamplesInFile / CHUNK_SIZE);
            
            for chunkIdx = 1:numChunks
                startSample = (chunkIdx - 1) * CHUNK_SIZE + 1;
                endSample = min(chunkIdx * CHUNK_SIZE, totalSamplesInFile);
                chunkLength = endSample - startSample + 1;
                
                % 1. Читаем chunk (один раз!)
                offsetBytes = (startSample - 1) * numChannelsInStream * 2;
                dataMap = memmapfile(continuousFile, 'Format', 'int16', 'Writable', false, ...
                    'Offset', offsetBytes, 'Repeat', chunkLength * numChannelsInStream);
                
                dataChunk = reshape(dataMap.Data, [numChannelsInStream, chunkLength]);
                channelChunk = double(dataChunk(current_channel_global_index, :))';
                
                % 2. Если нужна MUA - обрабатываем оригинальный chunk
                if detectMua
                    lfp_channel_data_for_mua = [lfp_channel_data_for_mua; channelChunk];
                end
                
                % 3. Если нужен resample - делаем ресемплинг для LFP (используем resample1 для избежания краевых эффектов)
                if doResample
                    channelChunkForLFP = resample1(channelChunk, newFs, Fs);
                else
                    channelChunkForLFP = channelChunk;
                end
                
                % 4. Сохраняем в LFP
                chunkLengthProcessed = length(channelChunkForLFP);
                endRow = currentRow + chunkLengthProcessed - 1;
                
                if endRow <= final_lfp_length
                    m.lfp(currentRow:endRow, chIdx) = channelChunkForLFP;
                    channelDataForVariance = [channelDataForVariance; channelChunkForLFP];
                else
                    % Truncate if exceeds final length
                    remainingRows = final_lfp_length - currentRow + 1;
                    if remainingRows > 0
                        m.lfp(currentRow:final_lfp_length, chIdx) = channelChunkForLFP(1:remainingRows);
                        channelDataForVariance = [channelDataForVariance; channelChunkForLFP(1:remainingRows)];
                    end
                    break;
                end
                
                currentRow = endRow + 1;
                chunksProcessed = chunksProcessed + 1;
                
                % Update progress
                chunksProgress = chunksProcessed / totalChunksPerChannel;
                rowsProgress = (currentRow - 1) / final_lfp_length;
                if detectMua
                    currentStep = (chIdx - 1) * 2 + 1; % Combined MUA+LFP step
                else
                    currentStep = chIdx; % LFP only step
                end
                overallProgress = (currentStep - 1 + chunksProgress) / totalSteps;
                elapsed = toc(conversion_tic);
                etaSec = elapsed * (1 - overallProgress) / max(overallProgress, eps);
                progressMsg = sprintf('%d/%d: %s (%.0f%%) %s', currentStep, totalSteps, channelName, overallProgress * 100, formatEta(etaSec));
                waitbar(overallProgress, hWaitBar, progressMsg);
                
                clear dataMap dataChunk channelChunk channelChunkForLFP;
            end
        end
        
        % Финализация MUA если нужно
        if detectMua
            currentStep = (chIdx - 1) * 2 + 1; % MUA detection step
            overallProgress = (currentStep - 1 + 0.5) / totalSteps;
            elapsed = toc(conversion_tic);
            etaSec = elapsed * (1 - overallProgress) / max(overallProgress, eps);
            progressMsg = sprintf('%d/%d: MUA - %s (%.0f%%) %s', currentStep, totalSteps, channelName, overallProgress * 100, formatEta(etaSec));
            waitbar(overallProgress, hWaitBar, progressMsg);
            
            disp(['Detecting MUA (full-channel) for channel: ', channelName]);
            [tStamp, ampl, shape] = detectMUAzav(lfp_channel_data_for_mua, hd, mua_std_coef, true);
            
            spks(chIdx).tStamp = double(tStamp);
            spks(chIdx).ampl = double(-ampl);
            spks(chIdx).shape = shape;
            
            clear lfp_channel_data_for_mua tStamp ampl shape;
        end
        
        % Calculate lfpVar in the same scale as Neuralynx converter
        if ~isempty(channelDataForVariance)
            lfpVar_channelwise(chIdx) = std(channelDataForVariance) / 10;
        end
        
        % Update progress after channel completion
        rowsProgress = (currentRow - 1) / final_lfp_length;
        if detectMua
            currentStep = (chIdx - 1) * 2 + 2; % Channel complete step
        else
            currentStep = chIdx; % Channel complete step
        end
        overallProgress = currentStep / totalSteps;
        elapsed = toc(conversion_tic);
        etaSec = elapsed * (1 - overallProgress) / max(overallProgress, eps);
        progressMsg = sprintf('%d/%d: %s - Complete %s', currentStep, totalSteps, channelName, formatEta(etaSec));
        waitbar(currentStep / totalSteps, hWaitBar, progressMsg);
        
        clear channelDataForVariance;
    end
    
    % Save MUA results
    m.spks = spks;
    clear spks;
    
    waitbar(1, hWaitBar, sprintf('%d/%d: Finalizing...', totalSteps, totalSteps));
    
    % Save variance
    debugState('oep_to_zav_streaming', 'Saving LFP variance...');
    m.lfpVar = lfpVar_channelwise;
    
    waitbar(1, hWaitBar, sprintf('%d/%d: Conversion complete', totalSteps, totalSteps));
    pause(0.5);
    
    % Close waitbar only if we created it
    if closeWaitBar
        try
            close(hWaitBar);
        catch
        end
    end
    
    debugState('oep_to_zav_streaming', 'Processing complete. Data saved to: %s', zavFilePath);
    disp('Processing complete. Data saved to:');
    disp(zavFilePath);
end

