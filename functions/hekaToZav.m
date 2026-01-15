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
        
        % Load data from Trace variables
        data = [];
        for listOfTraces = 1:numel(FilesOfInterest)
            bz = aa{FilesOfInterest(listOfTraces)};
            h1 = strfind(bz, '_');
            SweepNumber = str2num(bz(h1(3)+1:h1(4)-1));
            ChannelNumber = str2num(bz(h1(4)+1:end));
            data(:, ChannelNumber, SweepNumber) = eval([bz, '(:,2)']);
        end
        
        % Calculate sampling frequency
        Freq = round(1/median(diff(eval([bz, '(:,1)']))));
        
        % Get data dimensions
        n_channels = size(data, 2);
        n_sweeps = size(data, 3);
        n_points = size(data, 1);
        
        disp(['Found ' num2str(n_channels) ' channels, ' num2str(n_sweeps) ' sweeps, ' num2str(n_points) ' points per sweep']);
        
        % Store sweeps separately in format [time_points, channels, sweeps]
        lfp = zeros(n_points, n_channels, n_sweeps);
        
        % Data processing with scaling
        for CH = 1:n_channels
            for sweep = 1:n_sweeps
                d = data(:, CH, sweep);
                
                % Data scaling (as in PreprocessingEC)
                if abs(median(d)) > 1e-3 && abs(median(d)) < 1e-1
                    lfp(:, CH, sweep) = 1e3 * d;
                elseif abs(median(d)) < 1e-7
                    lfp(:, CH, sweep) = 1e12 * d;
                else
                    lfp(:, CH, sweep) = d;
                end
            end
        end
        
        % Create events for each sweep in format compatible with sweepProcessData
        zavp.realStim = struct('r', cell(1, n_sweeps));
        for sweep = 1:n_sweeps
            zavp.realStim(sweep).r = 1; % Start of each sweep
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