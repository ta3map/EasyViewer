function filteredData = applyFilterMex(data, filterSettings, Fs)
%APPLYFILTERMEX Native MEX path (enabled only after bench_evProcessSignal).

[b, a] = getFilterCoeffs(filterSettings, Fs);
[smoothSpan, smoothMethod, smoothEnabled] = getSmoothParams(filterSettings, size(data, 1));
columnMask = true(1, size(data, 2));

if isempty(b)
    b = zeros(0, 1);
    a = zeros(0, 1);
end

filteredData = evProcessSignal( ...
    double(data), b, a, columnMask, ...
    smoothSpan, smoothMethod, smoothEnabled, ...
    Fs, Fs, []);

end

function [b, a] = getFilterCoeffs(filterSettings, Fs)
b = [];
a = [];
freqFilterOn = ~isfield(filterSettings, 'filterEnabled') || filterSettings.filterEnabled;
if ~freqFilterOn
    return;
end
order = filterSettings.order;
switch filterSettings.filterType
    case 'lowpass'
        [b, a] = butter(order, filterSettings.freqHigh / (Fs / 2), 'low');
    case 'highpass'
        [b, a] = butter(order, filterSettings.freqLow / (Fs / 2), 'high');
    case 'bandpass'
        [b, a] = butter(order, [filterSettings.freqLow filterSettings.freqHigh] / (Fs / 2), 'bandpass');
    otherwise
        error('Unknown filter type: %s', filterSettings.filterType);
end
end

function [span, method, enabled] = getSmoothParams(filterSettings, nRows)
span = 0;
if isfield(filterSettings, 'smoothSpan')
    span = filterSettings.smoothSpan;
end
enabled = (~isfield(filterSettings, 'smoothEnabled') || filterSettings.smoothEnabled) && span >= 5;
method = 'moving';
if isfield(filterSettings, 'smoothMethod')
    method = filterSettings.smoothMethod;
end
if enabled
    span = round(span(1));
    span = min(max(span, 5), nRows);
end
end
