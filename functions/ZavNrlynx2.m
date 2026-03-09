function [data, ttlIn, hd, spkTS, spkSM] = ZavNrlynx2(pf, hd, rCh, strt, stp, ncsFilePaths)
%[data, hd, ttlIn, spkTS, spkSM] = ZavNrlynx(pf, rCh, strt, stp)
%read neuralynx. NeuralynxMatlabImportExport_v501 require
%
%INPUTS
%pf - pathname or path-and-filename 
%hd - header (full, for all channels)
%rCh - numbers of channels to be read
%strt, stp - start/stop time (seconds), stp='e' for all
%ncsFilePaths - optional cell of full paths to .ncs files (same order as rCh); if given, no folder scan
%
%OUTPUTS
%data - signal samples
%hd - file header (information about record)
%ttlIn - moments of synchro-TTL inputs (samples from sweep beginning)
%spkTS, spkSM - spikes

if (pf(end) ~= '\')%no slash
    pf(end + 1) = '\';
end
if ~exist(pf, 'dir') %&& ~exist(pf, 'file')
    [~, pf] = uigetfile('*.ncs; *.nev; *.nse', 'Select file', pf);%open dialog
end

if isempty(strt), strt = 0; end %start from zeros
if isempty(stp), stp = 'e'; end %read to follow out

if nargin >= 6 && ~isempty(ncsFilePaths)
    ncsFilePaths = ncsFilePaths(:)';
    rCh = rCh(:)';
    ncsFiles = struct('f', ncsFilePaths, 'chNum', num2cell(rCh));
    for k = 1:length(ncsFilePaths)
        info = dir(ncsFilePaths{k});
        ncsFiles(k).bytes = info.bytes;
    end
    [~, largestIdx] = max([ncsFiles.bytes]);
    largestF = largestIdx;
else
    dirCnt = dir(pf);
    ncsFiles = struct('f', {}, 'bytes', {}, 'chNum', {});
    for t = 1:length(dirCnt)
        if ((~dirCnt(t).isdir) && (length(dirCnt(t).name) > 3))
            if isequal(dirCnt(t).name(end - 3:end), '.ncs')
                fileName = dirCnt(t).name(1:end-4);
                numMatch = regexp(fileName, '\d+$', 'match');
                if ~isempty(numMatch)
                    ch = str2double(numMatch{1});
                    if ~isnan(ch)
                        ncsFiles(end + 1).f = [pf, dirCnt(t).name];
                        ncsFiles(end).bytes = dirCnt(t).bytes;
                        ncsFiles(end).chNum = ch;
                    end
                end
            end
        end
    end
    [~, sortIdx] = sort([ncsFiles.chNum]);
    ncsFiles = ncsFiles(sortIdx);
    [~, largestIdx] = max([ncsFiles.bytes]);
    largestF = largestIdx;
end

if (isequal(rCh, []) || isequal(rCh, 'a'))%all channels requested
    if ~isempty(hd)
        rCh = 1:hd.nADCNumChannels;
    else
        rCh = [ncsFiles.chNum];
    end
end
rChNum = length(rCh);%number of wanted channels

%%% stimulus moments (if exist) %%%
fileToRead = [pf, 'Events.nev'];%pathname of file to be read
if exist(fileToRead, 'file')
    evntTStmp = Nlx2MatEV(fileToRead, [1 0 0 0 0], 0, 1, []);
    if (nargout > 1)%synchro events requested
            [ttl, evntStr] = Nlx2MatEV(fileToRead, [0 0 1 0 1], 0, 1, []);%read events timestamps and strings
            
            if isempty(hd)%we have a header
                fileToRead = ncsFiles(largestF).f;%[pf, 'CSC1.ncs'];%pathname of file to be read
                cscHd = Nlx2MatCSC(fileToRead, [0 0 0 0 0], 1, 1, []);%header (lfp)
                si = (1e6 / NlxParametr(cscHd, 'SamplingFrequency'));%sample interval (mks)
            else%no header
                si = hd.si;%sample interval (mks)
            end
            lfpTStmp = Nlx2MatCSC(ncsFiles(largestF).f, [1 0 0 0 0], 0, 1, []);%timestamps of recorded samples (read largest file)
            mStStRec = FindStStStemp(lfpTStmp, si);%find moments of "Starting Recording" and "Stopping Recording"
            
            inEvntOn = zeros(1, length(evntStr));%numbers of events when input ports changed
            for t = 1:length(evntStr) %run over event strings
                inEvntOn(t) = t * double(~isempty(strfind(evntStr{t}, 'Input')));%find input events
            end
            inEvntOff = inEvntOn((ttl <= 0) & (inEvntOn > 0));%number of events when input TTL ports are in state 'OFF'
            inEvntOn = inEvntOn((ttl > 0) & (inEvntOn > 0));%number of events when input TTL ports are in state 'OFF'
            
            ttlPrtOn = unique(evntStr(inEvntOn));%different TTL ports (input ports only) in state 'ON'
            ttlIn(1:length(ttlPrtOn)) = struct('t', zeros(numel(inEvntOn), 2));%initialization
            origTTL(1:length(ttlPrtOn)) = struct('t', []);%initialization
            for ch = 1:length(ttlPrtOn) %run over different TTL ports
                z = 1;%counter of synchroimpulses
                for t = inEvntOn %run over inputs events when TTL set to On'
                    if strcmp(evntStr{t}(1:(end - 15)), ttlPrtOn{ch}(1:(end - 15)))%right number of inputs port
                        ttlIn(ch).t(z, 1) = evntTStmp(t);%"on" (allStims(:, 1)) stimulus (mks from beginnig of day)
                        for n = inEvntOff(inEvntOff > t) %run over input events when TTL set to 'Off'
                            if strcmp(evntStr{n}(1:(end - 15)), ttlPrtOn{ch}(1:(end - 15)))%right number of inputs port
                                ttlIn(ch).t(z, 2) = evntTStmp(n);%"off"(allStims(:, 2)) stimulus (mks from beginnig of day)
                                z = z + 1;%counter of synchroimpulses
                                break;%out of (for n)
                            end
                        end
                    end
                end
                ttlIn(ch).t(z:end, :) = [];%delete excess
                origTTL(ch).t = ttlIn(ch).t;%original timestamps of input TTLs
                
                for z = (numel(mStStRec) - 1):-2:2 %run over start-stop events
                    jj = (ttlIn(ch).t(:, 1) >= lfpTStmp(mStStRec(z)));%number of timestamps satisfying conditions
                    ttlIn(ch).t(jj, :) = ttlIn(ch).t(jj, :) - (lfpTStmp(mStStRec(z)) - lfpTStmp(mStStRec(z - 1))) + (512 * si);%stimulus moments from record begin
                end
                ttlIn(ch).t = ttlIn(ch).t - lfpTStmp(mStStRec(1));%adduction to zeros (first sample)
                ttlIn(ch).t = ttlIn(ch).t / si;%convert stimulus moments to samples from record begin
                origTTL(ch).t = origTTL(ch).t - lfpTStmp(mStStRec(1));%adduction to zeros (first sample)
            end
        end
    end
rStmps(1) = max((strt * 1e6) + evntTStmp(1), evntTStmp(1));%start read from (timestamp of recored began, mks)
if isequal(stp, 'e')
    rStmps(2) = evntTStmp(end);%read all (timestamp, mks)
else
    rStmps(2) = min(evntTStmp(1) + (stp * 1e6), evntTStmp(end));%read until stp (timestamp of record stoped, mks)
end

%%% data: lfp (samples), spikes %%%
data = zeros(0, rChNum);
if (nargout > 3)
    spkTS(1:rChNum, 1) = struct('s', []);%spikes moment (mks)
end
if (nargout > 4)
    spkSM(1:rChNum, 1) = struct('s', []);%spikes samples
end

n = 1;%number of channel in list channels to be read
for ch = rCh %run over all channels
    %%% lfp %%%
    idx = find([ncsFiles.chNum] == ch, 1);
    if isempty(idx)
        n = n + 1;
        continue;
    end
    fileToRead = ncsFiles(idx).f;
    if exist(fileToRead, 'file')%requested file with lfp exist
        if isempty(hd)%we have a header
            cscHd = Nlx2MatCSC(fileToRead, [0 0 0 0 0], 1, 1, []);%header (lfp)
            adBitVolts = NlxParametr(cscHd, 'ADBitVolts');%multiplier to convert from samples to volts (lfp)
            dspDelay_mks = NlxParametr(cscHd, 'DspFilterDelay_µs');%DspFilterDelay_µs (lfp)
            if ~isempty(dspDelay_mks)
                dspDelay_mks = dspDelay_mks * double(isequal(NlxParametr(cscHd, 'DspDelayCompensation'), 'Disabled'));%DspDelayCompensation (lfp)
            end
            z = double(strcmp(NlxParametr(cscHd, 'InputInverted'), 'True'));%input inverted
        else%no header
            adBitVolts = hd.adBitVolts(ch);%multiplier to convert from samples to volts (lfp)
            dspDelay_mks = hd.dspDelay_mks(ch);%DspFilterDelay_µs (lfp)
            z = hd.inverted(ch);%input inverted
        end
        smpl = Nlx2MatCSC(fileToRead, [0 0 0 0 1], 0, 4, rStmps);%
        if size(data, 1) == 0
            data = zeros(numel(smpl), rChNum);
        end
        data(1:numel(smpl), n) = smpl(:) * adBitVolts * 1e6;
        if (z >= 1)%inverted signal
            data(:, n) = -1 * data(:, n);%back inverse
        end
    end
    
    %%% spikes %%%
    if (nargout > 3)
        fileToRead = [pf, 'SE', num2str(ch), '.nse'];%pathname of file to be read
        if exist(fileToRead, 'file')%requested file with spikes exist
            if isempty(hd)%we have a header
                spkHd = Nlx2MatSpike(fileToRead, [0 0 0 0 0], 1, 1, []);%header (spikes)
                adBitVoltsSpk = NlxParametr(spkHd, 'ADBitVolts');%multiplier to convert from samples to volts (spikes)
                dspDelay_mksSpk = NlxParametr(spkHd, 'DspFilterDelay_µs');%DspFilterDelay_µs (spikes)
                dspDelay_mksSpk = dspDelay_mksSpk * double(isequal(NlxParametr(spkHd, 'DspDelayCompensation'), 'Disabled'));%DspDelayCompensation (spikes)
            else%no header
                adBitVoltsSpk = hd.adBitVoltsSpk(idx);%multiplier to convert from samples to volts (spikes)
                dspDelay_mksSpk = hd.dspDelay_mksSpk(idx);%DspFilterDelay_µs (spikes)
                dspDelay_mks = hd.dspDelay_mks(idx);%DspDelayCompensation (scs)
            end
            spkTmStmp = Nlx2MatSpike(fileToRead, [1 0 0 0 0], 0, 1, []);%timestamps of spikes
            spkTmStmp = spkTmStmp((spkTmStmp >= rStmps(1)) & (spkTmStmp <= rStmps(2)));%wanted spikes only
                %or:
                %spkTmStmp = Nlx2MatSpike(fileToRead, [1 0 0 0 0], 0, 4, rStmps);

            spkTS(n).s = spkTmStmp - evntTStmp(1) - round((dspDelay_mksSpk + dspDelay_mks) / 2);%mks from record start
        end
        if (nargout > 4)%spikes time course requested
            try
            spkSM(n).s = squeeze(Nlx2MatSpike(fileToRead, [0 0 0 0 1], 0, 4, rStmps));
            spkSM(n).s = spkSM(n).s * adBitVoltsSpk * 1e6;%samples to microvolts
            catch
                spkSM(n).s = [];
                spkSM(n).s = [];
            end
        end
    end
    n = n + 1;%number of channel in list channels to be read
end

%%% header compile (abf compatible)%%%
if (nargout > 2)%header requested
    hd.fFileSignature = 'Neuralynx';
    hd.nOperationMode = 3;%data were acquired in gap-free mode (continuous record)
    hd.lActualEpisodes = 1;%number of sweeps (for compatibility with abfload)

    hd.nADCNumChannels = length(ncsFiles);
    hd.chNumList = [ncsFiles.chNum];

    hd.adBitVolts = zeros(hd.nADCNumChannels, 1);
    hd.dspDelay_mks = zeros(hd.nADCNumChannels, 1);
    hd.adBitVoltsSpk = zeros(hd.nADCNumChannels, 1);
    hd.dspDelay_mksSpk = zeros(hd.nADCNumChannels, 1);
    hd.alignmentPt = zeros(hd.nADCNumChannels, 1);
    hd.inverted = zeros(hd.nADCNumChannels, 1);
    hd.recChUnits = cell(hd.nADCNumChannels, 1);
    hd.recChNames = cell(hd.nADCNumChannels, 1);
    hd.ch_si = zeros(hd.nADCNumChannels, 1);

    for k = 1:hd.nADCNumChannels
        fileToRead = ncsFiles(k).f;
        if exist(fileToRead, 'file')
            cscHd = Nlx2MatCSC(fileToRead, [0 0 0 0 0], 1, 1, []);
            hd.ch_si(k) = (1e6 / NlxParametr(cscHd, 'SamplingFrequency'));
            hd.adBitVolts(k) = NlxParametr(cscHd, 'ADBitVolts');
            dspDelay_mks = NlxParametr(cscHd, 'DspFilterDelay_µs');
            if isempty(dspDelay_mks)
                dspDelay_mks = Inf;
            end
            hd.dspDelay_mks(k) = dspDelay_mks * double(isequal(NlxParametr(cscHd, 'DspDelayCompensation'), 'Disabled'));
            hd.recChUnits{k} = 'µV';
            z = find(fileToRead == '\', 1, 'last');
            hd.recChNames{k} = fileToRead((z + 1):(end - 4));
            hd.inverted(k) = double(strcmp(NlxParametr(cscHd, 'InputInverted'), 'True'));
        end

        fileToRead = [pf, 'SE', num2str(ncsFiles(k).chNum), '.nse'];
        if exist(fileToRead, 'file')
            spkHd = Nlx2MatSpike(fileToRead, [0 0 0 0 0], 1, 1, []);
            hd.adBitVoltsSpk(k) = NlxParametr(spkHd, 'ADBitVolts');
            hd.dspDelay_mksSpk(k) = NlxParametr(spkHd, 'DspFilterDelay_µs') * double(isequal(NlxParametr(spkHd, 'DspDelayCompensation'), 'Disabled'));
            hd.alignmentPt(k) = NlxParametr(spkHd, 'AlignmentPt');
        end
    end

    hd.dataPtsPerChan = size(data, 1);%samples per channel
    hd.dataPts = hd.dataPtsPerChan * hd.nADCNumChannels;%total number of recorded samples

    hd.si = max(hd.ch_si);%sample interval (mks)
    hd.fADCSampleInterval = hd.si;%sample interval (mks)

    %fill hd.recTime ('ttl' and 'evntStr' automatically exist)
    %if (~exist('ttl', 'var') || ~exist('evntStr', 'var'))
    %   fileToRead = [pf, 'Events.nev'];%pathname of file to be read
    %   [ttl, evntStr] = Nlx2MatEV(fileToRead, [0 0 1 0 1], 0, 1, []);%read event-file
    %end
    hd.inTTL_timestamps = origTTL;%original timestamps of input TTLs
    hd.TTLs = ttl;%ttl events
    hd.EventStrings = evntStr;%text of events
    if exist('cscHd', 'var')
        hd.cscHd = cscHd;%original header of neuralynx-file
    end
    if exist('spkHd', 'var')
        hd.spkHd = spkHd;%original header of neuralynx-file
    end
    
    n = 0; z = 0;
    for t = 1:length(evntStr)
        if isequal(evntStr{t}, 'Starting Recording')
            n = t;%number of event 'Starting Recording'
            break;%out of "for t"
        end
    end
    for t = length(evntStr):-1:1
        if isequal(evntStr{t}, 'Stopping Recording')
            z = t;%number of event 'Stopping Recording'
            break;%out of "for t"
        end
    end
    hd.recTime(1) = evntTStmp(n) * 1e-6;%recording start time in seconds from experiment start
    hd.recTime(2) = evntTStmp(z) * 1e-6;%recording stop time in seconds from experiment start

    %(hd.sweepStartInPts * hd.fADCSampleInterval)   the start times of sweeps in sample points (from beginning of recording)
    %hd.sweepStartInPts = ?allStims(:, 1)?;%the start times of sweeps in sample points (from beginning of recording)
end

if nargout >= 6 && ~useTimingCache && exist('evntTStmp', 'var')
    timingCacheOut = struct('evntTStmp', evntTStmp, 'rStmps', rStmps, 'si', si, 'ttl', ttl, 'evntStr', evntStr, 'origTTL', origTTL);
else
    timingCacheOut = [];
end

function mStStRec = FindStStStemp(evntTS, si)
%find moments of "Starting Recording" and "Stopping Recording"
%
%INPUTS
%%%evntStr - strings with events description
%evntTS - timestampes of events marking start-stop of recordings (mks)
%si - sample interval (mks)
%
%OUTPUTS
%mStStRec - numbers of timestamp of start and stop recordings
%

%methode 1 (find by events timestamp)
% mStStRec = zeros(length(evntTS), 1);%preallocation of memory
% z = 1;
% for t = 1:length(evntTS)
%     if strcmp(evntTS{t}, 'Starting Recording')
%         mStStRec(z) = t;%start timestamp (number)
%         z = z + 1;
%     end
%     if strcmp(evntTS{t}, 'Stopping Recording')
%         mStStRec(z) = t;%stop timestamp (number)
%         z = z + 1;
%     end
% end
% mStStRec(z:end, :) = [];%delete excess

%methode 2 (find by lfp timestamp)
difTS = diff(evntTS);%difference
tmp = find(difTS > ((512 * si) + 10));%number of timestamp with "Stop" events
mStStRec = zeros((2 * numel(tmp)) + 2, 1);%preallocation of memory
mStStRec(2:2:(end - 2)) = tmp;%stop timestamps
mStStRec(3:2:(end - 1)) = tmp + 1;%start timestamps
mStStRec(1) = 1;%first timestamp corresponds to first start
mStStRec(end) = length(evntTS);%last timestamp corresponds to last stop

function nlxPrm = NlxParametr(headCell, fieldNm)
%get value of specified parameter
%
%INPUTS
%cscHd - cell array wiht Neuralynx parameter
%fieldNm - name of requested parameter (single name)
%
%OUTPUTS
%nlxPrm - value of parameter

nlxPrm = [];%initialization
for n = 1:length(headCell) %run over cells with parameters
    if ~isempty(strfind(headCell{n}, fieldNm))%string contains requested name
        t = find(headCell{n} == ' ', 1, 'first');%find delimiter
        strVal = headCell{n}((t + 1):end);%string with value of parameter
        if (any(double(strVal) < 46) || any(double(strVal) > 57))%value is word
            nlxPrm = strVal;
        else%value is numeric
            nlxPrm = str2double(strVal);%numeric value of parameter
        end
        break;%out of (for n)
    end
end