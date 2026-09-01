function y = resample1Mex(x, p, q)
%RESAMPLE1MEX Native MEX resample (enabled only after bench_evProcessSignal).

orig_Fs = q;
new_Fs = p;

if isvector(x)
    wasRow = isrow(x);
    x = x(:);
else
    wasRow = false;
end

nCols = size(x, 2);
columnMask = true(1, nCols);
b = zeros(0, 1);
a = zeros(0, 1);

y = evProcessSignal( ...
    double(x), b, a, columnMask, ...
    0, 'moving', false, ...
    new_Fs, orig_Fs, []);

if wasRow
    y = y.';
end

end
