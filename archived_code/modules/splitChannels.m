function result = splitChannels(filePath, fileId, params)
    global zav_calling
    
    metadata = zav_calling(filePath);
    if isempty(metadata)
        result = [];
        return
    end

    global lfp_file spks hd zavp chnlGrp lfpVar stims stims_exist
    
    lfp_orig = lfp_file.lfp;
    spks_orig = spks;
    hd_orig = hd;
    zavp_orig = zavp;
    chnlGrp_orig = chnlGrp;
    lfpVar_orig = lfpVar;
    
    numChannels = hd.nADCNumChannels;
    
    [folder, baseName, ~] = fileparts(filePath);
    
    convertedFolder = fullfile(folder, 'converted');
    if ~isfolder(convertedFolder)
        mkdir(convertedFolder);
    end
    
    for chIdx = 1:numChannels
        lfp_ch = lfp_orig(:, chIdx);
        
        if ~isempty(spks_orig) && numel(spks_orig) >= chIdx
            spks_ch = spks_orig(chIdx);
        else
            spks_ch = struct('tStamp', [], 'ampl', [], 'shape', []);
        end
        
        hd_ch = hd_orig;
        hd_ch.nADCNumChannels = 1;
        if iscell(hd_orig.recChNames) && numel(hd_orig.recChNames) >= chIdx
            hd_ch.recChNames = {hd_orig.recChNames{chIdx}};
        else
            hd_ch.recChNames = {sprintf('Channel_%d', chIdx)};
        end
        
        if isfield(hd_orig, 'recChUnits') && iscell(hd_orig.recChUnits) && numel(hd_orig.recChUnits) >= chIdx
            hd_ch.recChUnits = {hd_orig.recChUnits{chIdx}};
        end
        
        if isfield(hd_orig, 'ch_si') && isnumeric(hd_orig.ch_si) && numel(hd_orig.ch_si) >= chIdx
            if isscalar(hd_orig.ch_si)
                hd_ch.ch_si = hd_orig.ch_si;
            else
                hd_ch.ch_si = hd_orig.ch_si(chIdx);
            end
        end
        
        if isfield(hd_orig, 'dataPtsPerChan')
            hd_ch.dataPtsPerChan = size(lfp_ch, 1);
        end
        
        if isfield(hd_orig, 'dataPts')
            hd_ch.dataPts = size(lfp_ch, 1);
        end
        
        if ~isempty(lfpVar_orig) && numel(lfpVar_orig) >= chIdx
            lfpVar_ch = lfpVar_orig(chIdx);
        else
            lfpVar_ch = [];
        end
        
        zavp_ch = zavp_orig;
        if isfield(zavp_orig, 'stimCh') && isnumeric(zavp_orig.stimCh) && zavp_orig.stimCh == chIdx
            zavp_ch.stimCh = 1;
        else
            zavp_ch.stimCh = [];
        end
        
        if exist('stims', 'var') && ~isempty(stims) && stims_exist
            zavp_ch.realStim = struct('r', stims(:) / zavp_ch.siS);
        else
            zavp_ch.realStim = struct('r', []);
        end
        
        chnlGrp_ch = [];
        
        channelFolder = fullfile(convertedFolder, sprintf('ch%d', chIdx));
        if ~isfolder(channelFolder)
            mkdir(channelFolder);
        end
        
        outputPath = fullfile(channelFolder, [baseName, '_ch', num2str(chIdx), '.mat']);
        
        lfp_file = struct('lfp', lfp_ch);
        spks = spks_ch;
        hd = hd_ch;
        zavp = zavp_ch;
        chnlGrp = chnlGrp_ch;
        lfpVar = lfpVar_ch;
        
        saveZavFile(outputPath);
    end
    
    lfp_file = struct('lfp', lfp_orig);
    spks = spks_orig;
    hd = hd_orig;
    zavp = zavp_orig;
    chnlGrp = chnlGrp_orig;
    lfpVar = lfpVar_orig;
    
    result = struct();
end
