function [data, ttlIn, hd, spkTS, spkSM] = ZavNrlynx2(pf, hd, rCh, strt, stp)
%[data, hd, ttlIn, spkTS, spkSM] = ZavNrlynx(pf, rCh, strt, stp)
%read neuralynx. NeuralynxMatlabImportExport_v501 require
%
%INPUTS
%pf - pathname or path-and-filename 
%hd - header (full, for all channels)
%rCh - numbers of channels to be read
%strt - start time to read spontaneous record (seconds from beginning of record)
%stp - stop time of read spontaneous record (seconds from beginning of record)
%
%OUTPUTS
%data - signal samples
%hd - file header (information about record)
%ttlIn - moments of synchro-TTL inputs (samples from sweep beginning)
%spkTS - spikes appearence moments (mks)
%spkSM - spikes samples

if (pf(end) ~= '\')%no slash
    pf(end + 1) = '\';
end
if ~exist(pf, 'dir') %&& ~exist(pf, 'file')
    [~, pf] = uigetfile('*.ncs; *.nev; *.nse', 'Select file', pf);%open dialog
end

if isempty(strt), strt = 0; end %start from zeros
if isempty(stp), stp = 'e'; end %read to follow out
    
rChNum = 0;%counter of channels
dirCnt = dir(pf);%directory content
ncsFiles(1:length(dirCnt)) = struct('f', '', 'bytes', []);
largestF = 1;%number of file (in ncsFiles structure) with largest size
for t = 1:length(dirCnt)
    if ((~dirCnt(t).isdir) && (length(dirCnt(t).name) > 3))%not directory and name good
        if isequal(dirCnt(t).name(end - 3:end), '.ncs')
            ch = str2double(dirCnt(t).name(4:(end - 4)));%number of channel (3-letteral name + number of channel)
            ncsFiles(ch).f = [pf, dirCnt(t).name];%full name of channel-file
            ncsFiles(ch).bytes = dirCnt(t).bytes;%size of file (bytes)
            if (ncsFiles(ch).bytes > ncsFiles(largestF).bytes)
                largestF = ch;%number of file (in ncsFiles structure) with largest size
            end
            rChNum = rChNum + 1;%increase counter of channels
        end
    end
end
ncsFiles((rChNum + 1):end) = [];%delet empty
        
if (isequal(rCh, []) || isequal(rCh, 'a'))%all channels requested
    if ~isempty(hd)%no header
        rChNum = hd.nADCNumChannels;
    end
    rCh = 1:rChNum;%read all channels
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
data = zeros(0, rChNum);%lfp samples
if (nargout > 3)
    spkTS(1:rChNum, 1) = struct('s', []);%spikes moment (mks)
end
if (nargout > 4)
    spkSM(1:rChNum, 1) = struct('s', []);%spikes samples
end

n = 1;%number of channel in list channels to be read
for ch = rCh %run over all channels
    %%% lfp %%%
    fileToRead = ncsFiles(ch).f;%[pf, 'CSC', num2str(ch), '.ncs'];%pathname of file to be read
    if exist(fileToRead, 'file')%requested file with lfp exist
        if isempty(hd)%we have a header
            cscHd = Nlx2MatCSC(fileToRead, [0 0 0 0 0], 1, 1, []);%header (lfp)
            adBitVolts = NlxParametr(cscHd, 'ADBitVolts');%multiplier to convert from samples to volts (lfp)
            dspDelay_mks = NlxParametr(cscHd, 'DspFilterDelay_탎');%DspFilterDelay_탎 (lfp)
            if ~isempty(dspDelay_mks)
                dspDelay_mks = dspDelay_mks * double(isequal(NlxParametr(cscHd, 'DspDelayCompensation'), 'Disabled'));%DspDelayCompensation (lfp)
            end
            z = double(strcmp(NlxParametr(cscHd, 'InputInverted'), 'True'));%input inverted
        else%no header
            adBitVolts = hd.adBitVolts(ch);%multiplier to convert from samples to volts (lfp)
            dspDelay_mks = hd.dspDelay_mks(ch);%DspFilterDelay_탎 (lfp)
            z = hd.inverted(ch);%input inverted
        end
        smpl = Nlx2MatCSC(fileToRead, [0 0 0 0 1], 0, 4, rStmps);%
        data(1:numel(smpl), n) = smpl(:) * adBitVolts * 1e6;%lfp
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
                dspDelay_mksSpk = NlxParametr(spkHd, 'DspFilterDelay_탎');%DspFilterDelay_탎 (spikes)
                dspDelay_mksSpk = dspDelay_mksSpk * double(isequal(NlxParametr(spkHd, 'DspDelayCompensation'), 'Disabled'));%DspDelayCompensation (spikes)
            else%no header
                adBitVoltsSpk = hd.adBitVoltsSpk(ch);%multiplier to convert from samples to volts (spikes)
                dspDelay_mksSpk = hd.dspDelay_mksSpk(ch);%DspFilterDelay_탎 (spikes)
                dspDelay_mks = hd.dspDelay_mks(ch);%DspDelayCompensation (scs)
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

    hd.nADCNumChannels = 0;%number of channels
    dirCnt = dir(pf);%content of directory
    for t = 1:length(dirCnt)
        if ((~dirCnt(t).isdir) && (length(dirCnt(t).name) > 3))
            if isequal(dirCnt(t).name(end - 3:end), '.ncs')
                hd.nADCNumChannels = hd.nADCNumChannels + 1;%counter of channels
            end
        end
    end
    
    hd.adBitVolts = zeros(hd.nADCNumChannels, 1);%multiplier to convert from samples to volts (lfp)
    hd.dspDelay_mks = zeros(hd.nADCNumChannels, 1);%DspFilterDelay_탎 (lfp)
    hd.adBitVoltsSpk = zeros(hd.nADCNumChannels, 1);%multiplier to convert from samples to volts (spikes)
    hd.dspDelay_mksSpk = zeros(hd.nADCNumChannels, 1);%DspFilterDelay_탎 (spikes)
    hd.alignmentPt = zeros(hd.nADCNumChannels, 1);%spike samples back (from peak, including peak point)
    hd.inverted = zeros(hd.nADCNumChannels, 1);%input inverted
    hd.recChUnits = cell(hd.nADCNumChannels, 1);%mesurement units
    hd.recChNames = cell(hd.nADCNumChannels, 1);%name of channels
    hd.ch_si = zeros(hd.nADCNumChannels, 1);%sample interval (mks)

    %read headers
    for ch = 1:hd.nADCNumChannels
        %%% CSC(ncs)-files (lfp) %%%
        fileToRead = ncsFiles(ch).f;%[pf, 'CSC', num2str(ch), '.ncs'];%pathname of file to be read
        if exist(fileToRead, 'file')%requested file with lfp exist
            cscHd = Nlx2MatCSC(fileToRead, [0 0 0 0 0], 1, 1, []);%header (lfp)
            hd.ch_si(ch) = (1e6 / NlxParametr(cscHd, 'SamplingFrequency'));%sample interval (mks)
            hd.adBitVolts(ch) = NlxParametr(cscHd, 'ADBitVolts');%multiplier to convert from samples to volts (lfp)
            dspDelay_mks = NlxParametr(cscHd, 'DspFilterDelay_탎');%DspFilterDelay_탎 (lfp)
            if isempty(dspDelay_mks)
                dspDelay_mks = Inf;
            end
            hd.dspDelay_mks(ch) = dspDelay_mks;%DspFilterDelay_탎 (lfp)
            hd.dspDelay_mks(ch) = hd.dspDelay_mks(ch) * double(isequal(NlxParametr(cscHd, 'DspDelayCompensation'), 'Disabled'));%DspDelayCompensation (lfp)
            hd.recChUnits{ch} = '킮';%mesurement units
            z = find(fileToRead == '\', 1, 'last');%last slash
            hd.recChNames{ch} = fileToRead((z + 1):(end - 4));%cscHd{20}(2:end);%name of channels
            hd.inverted(ch) = double(strcmp(NlxParametr(cscHd, 'InputInverted'), 'True'));%input inverted
        end

        %%% SE(nse)-files (spikes) %%%
        fileToRead = [pf, 'SE', num2str(ch), '.nse'];%pathname of file to be read
        if exist(fileToRead, 'file')%requested file with spikes exist
            spkHd = Nlx2MatSpike(fileToRead, [0 0 0 0 0], 1, 1, []);%header (spikes)
            hd.adBitVoltsSpk(ch) = NlxParametr(spkHd, 'ADBitVolts');%multiplier to convert from samples to volts (spikes)
            hd.dspDelay_mksSpk(ch) = NlxParametr(spkHd, 'DspFilterDelay_탎');%DspFilterDelay_탎 (spikes)
            hd.dspDelay_mksSpk(ch) = hd.dspDelay_mksSpk(ch) * double(isequal(NlxParametr(spkHd, 'DspDelayCompensation'), 'Disabled'));%DspDelayCompensation (spikes)
            hd.alignmentPt(ch) = NlxParametr(spkHd, 'AlignmentPt');%spike samples back (from peak, including peak point)
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