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

filteredS = zeros(size(s));%preallocation of memory for filtered signal


% !use FILTER instead of FILTFILT if analogous-like filtering is required!

if ((metod == 1) || (metod == 4)) %single-step filtering
    for ch = 1:size(s, 2) %run over channels
        for sw = 1:size(s, 3) %run over segments
            filteredS(:, ch, sw) = filtfilt(b1, a1, s(:, ch, sw));%filtering
        end
    end
elseif (metod == 2) %two-cascade filtering (Chebyshev)
    for ch = 1:size(s, 2) %run over channels
        for sw = 1:size(s, 3) %run over segments
            filteredS(:, ch, sw) = filtfilt(b1, a1, s(:, ch, sw));%first step filtering
            filteredS(:, ch, sw) = filtfilt(b2, a2, filteredS(:, ch, sw));%second step filtering
        end
    end
elseif (metod == 3) %three-cascade filtering (Chebyshev)
    for ch = 1:size(s, 2) %run over channels
        for sw = 1:size(s, 3) %run over segments
            filteredS(:, ch, sw) = filtfilt(b1, a1, s(:, ch, sw));%first step filtering
            filteredS(:, ch, sw) = filtfilt(b2, a2, filteredS(:, ch, sw));%second step filtering
            filteredS(:, ch, sw) = filtfilt(b3, a3, filteredS(:, ch, sw));%third step filtering
        end
    end
else
    disp('unexpected method number');%no other methods
end
