function [offsets, shiftCoeff] = updateMultiplotLines(hLines, time, data, varargin)
%UPDATE existing multiplot line handles (XData/YData/Color/LineWidth).

if isrow(time)
    time = time';
end
if size(data, 2) > size(data, 1)
    data = data';
end

params = inputParser;
addParameter(params, 'LineWidth', 0.5);
addParameter(params, 'Color', {'k'});
addParameter(params, 'shiftCoeff', max(std(data)) * 2);
addParameter(params, 'ChannelLabels', []);
parse(params, varargin{:});

lineWidths = params.Results.LineWidth;
colors = params.Results.Color;
shiftCoeff = params.Results.shiftCoeff;
ch_labels = params.Results.ChannelLabels;

numChannels = size(data, 2);
if isempty(ch_labels)
    ch_labels = arrayfun(@(x) sprintf('Ch%d', x), 1:numChannels, 'UniformOutput', false);
end

offsets = zeros(1, numChannels);
ax = ancestor(hLines(1), 'axes');
maxPoints = plotDecimationLimit(ax);

for chIdx = 1:numChannels
    offsets(chIdx) = -(chIdx - 1) * shiftCoeff;
    [tPlot, yPlot] = decimateForDisplay(time, data(:, chIdx), maxPoints);
    set(hLines(chIdx), ...
        'XData', tPlot, ...
        'YData', yPlot + offsets(chIdx), ...
        'LineWidth', getOptionalParam(lineWidths, chIdx), ...
        'Color', getOptionalParam(colors, chIdx));
end

yticks(ax, flip(offsets));
yticklabels(ax, flip(ch_labels));

end

function param = getOptionalParam(paramArray, index)
if iscell(paramArray)
    param = paramArray{min(index, length(paramArray))};
elseif isvector(paramArray)
    param = paramArray(min(index, length(paramArray)));
else
    param = paramArray;
end
end
