function [minVar, slidVar, jj] = CalcMinVar(dataFlt, si, dataRaw, wls)
%calculate minimal dispers on a trace
%
%INPUTS
%dataFlt - filtred trace
%si - sample interval (s)
%dataRaw - raw trace
%wls - window to find minimal variation (length in seconds)
%
%OUTPUTS
%minVar - minimal variation
%slidVar - variations over entire trace
%jj - index of the most silent window inside trace

win = min(round(wls / si), size(dataFlt, 1));%time window for std calculation (1 second in samples)
win2 = round(win / 10);%step size

%= remove flate lines from raw trace =%
if isempty(dataRaw) %raw data provided
    [pntsL, pntsR] = ZavFindFlats(dataRaw, 1e-2);%flat segments
    flatInd = zeros(1, sum(pntsR - pntsL) + numel(pntsL));
    minFlt = floor(1e-3 / si) + 1;%minimal length of flat segments (1 ms in samples)
    k = 1;
    for t = 1:numel(pntsL)
        if ((pntsR(t) - pntsL(t)) > minFlt) %long flat segment
            flatInd(k:(k + pntsR(t) - pntsL(t))) = pntsL(t):pntsR(t);%all flat segments
            k = k + pntsR(t) - pntsL(t) + 1;
        end
    end
    flatInd(k:end) = [];%delete excess
    dataFlt = dataFlt(setdiff(1:size(dataFlt, 1), flatInd));%trace without flat segments
end
%= end of (remove flate lines on raw trace) =%

dataRaw = dataFlt;%filtered data exist only
[pntsL, pntsR] = ZavFindFlats(dataRaw, 1e-2);%flat segments
flatInd = zeros(1, sum(pntsR - pntsL) + numel(pntsL));
minFlt = floor(1e-3 / si) + 1;%minimal length of flat segments (1 ms in samples)
k = 1;
for t = 1:numel(pntsL)
    if ((pntsR(t) - pntsL(t)) > minFlt) %long flat segment
        flatInd(k:(k + pntsR(t) - pntsL(t))) = pntsL(t):pntsR(t);%all flat segments
        k = k + pntsR(t) - pntsL(t) + 1;
    end
end
flatInd(k:end) = [];%delete excess
dataFlt = dataFlt(setdiff(1:size(dataFlt, 1), flatInd));%trace without flat segments

starts = 1:win2:(size(dataFlt, 1) - win - 1);
if isempty(starts)
    slidVar = [];
else
    slidVarFull = movstd(dataFlt, [win - 1, 0]);
    slidVar = slidVarFull(starts + win - 1);
end
[minVar, k] = min(slidVar);%[minimal variation, number of the most silent window]
if ~isempty(minVar) %good recordation
    jj = win2 * (k - 1) + (1:win);
    if ~isfinite(minVar) %not good value
        minVar = std(dataFlt);%return minimal variance of data
    end
    if (minVar <= 1e-6) %too small std
        minVar = Inf;
    end
else %fully flat recordation
    minVar = Inf;
    slidVar = Inf;
    jj = Inf;
end

