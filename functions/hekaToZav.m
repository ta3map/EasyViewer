function [lfp, spks, hd, zavp, lfpVar, chnlGrp] = hekaToZav(filepath)
    % Converts Heka .mat file to ZAV format
    %
    % Parameters:
    %   filepath - path to Heka .mat file
    %
    % Returns:
    %   lfp, spks, hd, zavp, lfpVar, chnlGrp - variables in ZAV format
    
    disp('Converting Heka file to ZAV format...');
    
    try
        % Load Heka .mat file
        load(filepath);
        
        % Get list of variables
        aa = who;
        
        % Find Trace variables
        ThirdValue = [];
        FourthValue = [];
        cn = 0;
        FilesOfInterest = [];
        for m = 1:size(aa, 1)
            bz = aa{m};
            if numel(bz) >= 5 && isequal(bz(1:5), 'Trace')
                cn = cn + 1;
                h1 = strfind(bz, '_');
                ValueT = str2num(bz(h1(3)+1:h1(4)-1));
                ThirdValue(cn) = ValueT;
                ValueY = str2num(bz(h1(4)+1:end));
                FourthValue(cn) = ValueY;
                FilesOfInterest(cn) = m;
            end
        end
        
        % Determine dimensions and preallocate lfp
        n_sweeps = max(ThirdValue);
        n_channels = max(FourthValue);
        firstTrace = aa{FilesOfInterest(1)};
        trace_lengths = zeros(1, numel(FilesOfInterest));
        for listOfTraces = 1:numel(FilesOfInterest)
            traceName = aa{FilesOfInterest(listOfTraces)};
            trace_lengths(listOfTraces) = size(eval([traceName, '(:,2)']), 1);
        end
        n_points = min(trace_lengths);
        lfp = zeros(n_points, n_channels, n_sweeps, 'single');
        
        % Calculate sampling frequency from first trace
        Freq = round(1/median(diff(eval([firstTrace, '(:,1)']))));
        
        % Read Trace variables directly into lfp with scaling
        for listOfTraces = 1:numel(FilesOfInterest)
            bz = aa{FilesOfInterest(listOfTraces)};
            h1 = strfind(bz, '_');
            SweepNumber = str2num(bz(h1(3)+1:h1(4)-1));
            ChannelNumber = str2num(bz(h1(4)+1:end));
            d = eval([bz, '(:,2)']);
            d = d(1:n_points);
            
            med = abs(median(d));
            if med > 1e-3 && med < 1e-1
                d = 1e3 * d;
            elseif med < 1e-7
                d = 1e12 * d;
            end
            lfp(:, ChannelNumber, SweepNumber) = single(d);
        end
        
        disp(['Found ' num2str(n_channels) ' channels, ' num2str(n_sweeps) ' sweeps, ' num2str(n_points) ' points per sweep']);
        
        % Create events for each sweep in format compatible with sweepProcessData.
        % For single-sweep recordings we keep data continuous and do not add synthetic stimuli.
        if n_sweeps > 1
            zavp.realStim = struct('r', cell(1, n_sweeps));
            for sweep = 1:n_sweeps
                zavp.realStim(sweep).r = 1; % Start of each sweep
            end
        end
        
        % Create spike structure for each channel and sweep
        spks = repmat(struct('tStamp', [], 'ampl', Inf, 'shape', []), n_channels, n_sweeps);
        
        % Calculate variation for each channel across sweeps
        lfpVar = zeros(n_channels, n_sweeps);
        for ch = 1:n_channels
            for sweep = 1:n_sweeps
                lfpVar(ch, sweep) = std(lfp(:, ch, sweep));
            end
        end
        
        % Create header
        [~, filename, ~] = fileparts(filepath);
        zavp.file = filename;
        zavp.rarStep = Freq/Freq;
        zavp.dwnSmplFrq = Freq;
        zavp.siS = 1e-3;
        zavp.prm = [];
        zavp.stimCh = 4;
        
        hd.fFileSignature = 'HEKA';
        hd.lActualEpisodes = n_sweeps;
        hd.si = 1e6/Freq;
        hd.nADCNumChannels = n_channels;
        hd.nOperationMode = 3;
        hd.recTime = [1 n_points];
        hd.sweepLengthInPts = n_points;
        
        % Create channel names
        recChNames = cell(1, n_channels);
        for i = 1:n_channels
            recChNames{i} = ['Ch', num2str(i)];
        end
        hd.recChNames = recChNames;
        
        % Channel groups
        chnlGrp = 1:n_channels;
        
        disp(['Successfully converted Heka file: ' filename]);
        disp(['Data size: [' num2str(size(lfp)) ']']);
        
    catch ME
        error(['Error converting Heka file: ' ME.message]);
    end
end 