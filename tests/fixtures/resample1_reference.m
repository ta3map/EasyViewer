function y = resample1_reference(x, p, q)
%RESAMPLE1_REFERENCE MATLAB-only reference (pre-MEX resample1.m).

orig_Fs = q;
new_Fs = p;

if isvector(x)
    wasRow = isrow(x);
    x = x(:);
else
    wasRow = false;
end

N = size(x, 1);
numPoints = round((N - 1) * new_Fs / orig_Fs) + 1;
t_original = (0:N-1)' / orig_Fs;
t_resampled = (0:numPoints-1)' / new_Fs;

y = interp1(t_original, double(x), t_resampled, 'linear', 'extrap');

if wasRow
    y = y.';
end

end
