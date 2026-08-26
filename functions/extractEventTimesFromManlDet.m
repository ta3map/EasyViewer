function [eventTimesSec, amplitudes] = extractEventTimesFromManlDet(loadedData, time)
%EXTRACTEVENTTIMESFROMMANLDET Event times (sec) and amplitudes from .ev manlDet.

    eventTimesSec = [];
    amplitudes = [];
    if ~isfield(loadedData, 'manlDet') || isempty(loadedData.manlDet)
        return
    end
    if isempty(time)
        return
    end

    indices = round([loadedData.manlDet.t]);
    indices = max(1, min(indices, numel(time)));
    eventTimesSec = time(indices)';

    if isfield(loadedData.manlDet, 'amplitude')
        amplitudes = [loadedData.manlDet.amplitude]';
    else
        amplitudes = NaN(size(indices(:)));
    end
    amplitudes = amplitudes(:);
    if numel(amplitudes) ~= numel(eventTimesSec)
        amplitudes = NaN(size(eventTimesSec));
    end
end
