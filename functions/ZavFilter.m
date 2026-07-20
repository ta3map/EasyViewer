function filteredS = ZavFilter(s, discrFrq, filtType, fStop, metod)
%filteredS = ZavFilter(s, dF, filter, fStop, metod)
%synthesis of filter and filtration. Signals must be sweeped through the first dimention
%
%INPUTS
%s - original signal
%dF - discretization frequency
%filter - type of filtration ('high', 'low', 'stop', 'bandpass', bandstop', and so on)
%fStop - stopband-edge frequency
%metod - used method
%
%OUTPUTS
%filteredS - filtered signal

if (~exist('metod', 'var'))
    metod = 1;
end

if (metod == 1)%single-step filtering
    [b1, a1] = cheby2(4, 20, fStop / (0.5 * discrFrq), filtType);%Chebyshev filter
elseif (metod == 2) %two-cascade filtering (Chebyshev)
    [b1, a1] = cheby2(4, 8, fStop / (0.5 * discrFrq), filtType);%first step Chebyshev filter
    [b2, a2] = cheby2(5, 8, fStop / (0.5 * discrFrq), filtType);%second step Chebyshev filter
elseif (metod == 3) %tree-cascade filtering (Chebyshev)
    [b1, a1] = cheby2(4, 8, fStop / (0.5 * discrFrq), filtType);%first step Chebyshev filter
    [b2, a2] = cheby2(5, 8, fStop / (0.5 * discrFrq), filtType);%second step Chebyshev filter
    [b3, a3] = cheby2(5, 8, fStop / (0.5 * discrFrq), filtType);%third step Chebyshev filter
elseif (metod == 4) %Butterworth filter
    [b1, a1] = butter(4, fStop / (0.5 * discrFrq), filtType);%Butterworth filter
    metod = 1;
else
    disp('no other methods')
end

% !use FILTER instead of FILTFILT if analogous-like filtering is required!

sz = size(s);
n = sz(1);
nCh = sz(2);
if numel(sz) < 3
    nSw = 1;
else
    nSw = sz(3);
end
s2 = reshape(s, n, nCh * nSw);

if ((metod == 1) || (metod == 4)) %single-step filtering
    f2 = filtfilt(b1, a1, s2);
elseif (metod == 2) %two-cascade filtering (Chebyshev)
    f2 = filtfilt(b1, a1, s2);
    f2 = filtfilt(b2, a2, f2);
elseif (metod == 3) %three-cascade filtering (Chebyshev)
    f2 = filtfilt(b1, a1, s2);
    f2 = filtfilt(b2, a2, f2);
    f2 = filtfilt(b3, a3, f2);
else
    disp('unexpected method number');%no other methods
    f2 = zeros(size(s2));
end

filteredS = reshape(f2, n, nCh, nSw);
if numel(sz) < 3
    filteredS = filteredS(:,:,1);
end
