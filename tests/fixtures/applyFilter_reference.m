function filteredData = applyFilter_reference(data, filterSettings, Fs)
%APPLYFILTER_REFERENCE MATLAB-only reference (pre-MEX applyFilter.m).

filteredData = zeros(size(data));
freqFilterOn = ~isfield(filterSettings, 'filterEnabled') || filterSettings.filterEnabled;

if freqFilterOn
    order = filterSettings.order;
    switch filterSettings.filterType
        case 'lowpass'
            [b, a] = butter(order, filterSettings.freqHigh / (Fs / 2), 'low');
        case 'highpass'
            [b, a] = butter(order, filterSettings.freqLow / (Fs / 2), 'high');
        case 'bandpass'
            [b, a] = butter(order, [filterSettings.freqLow filterSettings.freqHigh] / (Fs / 2), 'bandpass');
    end
    reflectionLength = round(size(data, 1) * 0.10);
    reflected = [flipud(data(1:reflectionLength, :)); data; flipud(data(end-reflectionLength+1:end, :))];
    filteredReflected = filtfilt(b, a, double(reflected));
    filteredData = filteredReflected(reflectionLength + 1:end-reflectionLength, :);
else
    filteredData = data;
end

span = 0;
if isfield(filterSettings, 'smoothSpan')
    span = filterSettings.smoothSpan;
end
smoothOn = (~isfield(filterSettings, 'smoothEnabled') || filterSettings.smoothEnabled) && span >= 5;
if smoothOn
    method = 'moving';
    if isfield(filterSettings, 'smoothMethod')
        method = filterSettings.smoothMethod;
    end
    span = round(span(1));
    span = min(max(span, 5), size(filteredData, 1));
    switch lower(method)
        case 'moving'
            filteredData = movmean(filteredData, span, 1, 'Endpoints', 'shrink');
        case 'median'
            if mod(span, 2) == 0
                span = span + 1;
            end
            filteredData = medfilt1(filteredData, span);
        otherwise
            error('Unknown smooth method: %s', method);
    end
end

end
