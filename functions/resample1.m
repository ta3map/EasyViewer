function y = resample1(x, p, q)
%RESAMPLE1 Resample signal using linear interpolation (without edge effects)
%   Y = RESAMPLE1(X, P, Q) resamples the signal in vector X at P/Q times
%   the original sample rate using linear interpolation. This function
%   avoids edge effects that occur with the standard resample function.
%
%   INPUTS:
%   X - input signal (vector)
%   P - new sampling rate (or numerator)
%   Q - original sampling rate (or denominator)
%
%   OUTPUTS:
%   Y - resampled signal
%
%   Example:
%   y = resample1(x, 1000, 10000); % downsample from 10kHz to 1kHz

% Ensure x is a column vector
x = x(:);

% Calculate original and new sampling rates
orig_Fs = q;
new_Fs = p;

% Create time vectors
% Более точный расчет количества точек на основе соотношения частот
% Длительность = (N-1) / Fs_old, для новой частоты: (M-1) / Fs_new = (N-1) / Fs_old
% Отсюда: M = round((N-1) * Fs_new / Fs_old) + 1
N = length(x);
numPoints = round((N - 1) * new_Fs / orig_Fs) + 1;
t_original = (0:N-1) / orig_Fs;
t_resampled = (0:numPoints-1) / new_Fs;

% Perform linear interpolation
y = interp1(t_original, double(x), t_resampled, 'linear', 'extrap')';

% Ensure output has same orientation as input
if size(x, 1) == 1
    y = y';
end
