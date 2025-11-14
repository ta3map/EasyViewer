function offsets = multiplot(varargin)

% Multiple lines on a single graph
%
% Usage:
%   offsets = multiplot(time, data, ... );
%
% This function plots multiple lines on a single graph. Each line represents
% a set of data. The function takes in time and data as inputs and
% allows various optional parameters to customize the appearance of each line.
%
% Input Arguments:
%
%   time: Array of time points corresponding to data values.
%   data: Matrix where each column represents a different data set to be plotted.
%
% Optional Parameters:
%
%   LineWidth: Specifies the width of the lines. Default is 0.5.
%   Color: Defines the color of each line. Accepts RGB values or color names.
%   shiftCoeff: Coefficient to shift the lines vertically for clarity.
%   DisplayName: Name for each line, used in legends.
%   LineStyle: Style of the line (e.g., '-', '--', ':', '-.').
%
%   Marker: Type of marker to use on each point (e.g., '+', 'o', '*', 'x').
%   MarkerSize: Size of the markers.
%   MarkerEdgeColor: Color of the marker edge. Accepts RGB values or color names.
%   MarkerFaceColor: Color of the marker face. Accepts RGB values or color names.
%   
%   AmplitudeMarkerColor: Color of a marker wich shows the size of the
%   offset between channels.
%   
%   ChannelLabels: Labels for each data channel, displayed along the y-axis or in a legend.
%
% Output:
%
%   offsets: Returns the vertical offsets used for each line, in case of shifted plots.
%
% Examples:
%
%   Example 1: Basic use case
%   multiplot(data);
%
%   Example 2: Use case with time vector
%   multiplot(time, data);
%
%   Example 3: Custom line style and color
%   multiplot(time, data, 'LineStyle', '--', 'Color', 'red');
%
%   Example 4: Adding markers and channel labels
%   multiplot(time, data, 'Marker', 'o', 'ChannelLabels', {'Ch1', 'Ch2', 'Ch3'});
%
%   Example 5: Multiple markers and styles
%   multiplot(time, data, 'color', {'k', 'none', '#565DEB'});
%   multiplot(time, data, 'Marker', {'o', 'x'});
%   multiplot(time, data, 'LineWidth', [1, 0.1]);
%
%   Example 6: Custom shift coefficient
%   multiplot(time, data, 'shiftCoeff', 100);
%   by default shiftCoeff is max(std(data)) * 2)
%
%   See also PLOT

    % Check if the first argument is a time vector or data
    if isvector(varargin{1})
        time = varargin{1};
        data = varargin{2};
        paramIndex = 3;
    else
        data = varargin{1};
        time = 1:size(data, 1); % Default time vector if not provided
        paramIndex = 2;
    end

    % Transpose time vector if it is horizontal
    if isrow(time)
        time = time';
    end
    % Transpose data vector if needed
    if size(data, 2) > size(data, 1)
        data = data';
    end

    % Default plot settings
    params = inputParser;
    addParameter(params, 'LineWidth', 0.5);
    addParameter(params, 'Color', {'k'}); % Make sure default is a cell array to accommodate multiple lines
    addParameter(params, 'shiftCoeff', max(std(data)) * 2);
    addParameter(params, 'DisplayName', {''});
    addParameter(params, 'LineStyle', {'-'});
    addParameter(params, 'Marker', {''});
    addParameter(params, 'MarkerSize', {6});
    addParameter(params, 'MarkerEdgeColor', {'auto'});
    addParameter(params, 'MarkerFaceColor', {'auto'});
    addParameter(params, 'AmplitudeMarkerColor', 'r');
    addParameter(params, 'ChannelLabels', []); % Add ch_labels as an optional parameter
    parse(params, varargin{paramIndex:end});

    % Get the parameters
    lineWidths = params.Results.LineWidth;
    colors = params.Results.Color;
    shiftCoeff = params.Results.shiftCoeff;
    displayNames = params.Results.DisplayName;
    lineStyles = params.Results.LineStyle;
    markers = params.Results.Marker;
    markerSizes = params.Results.MarkerSize;
    markerEdgeColors = params.Results.MarkerEdgeColor;
    markerFaceColors = params.Results.MarkerFaceColor;
    AmplitudeMarkerColor = params.Results.AmplitudeMarkerColor;
    ch_labels = params.Results.ChannelLabels;

    % Generate default ch_labels if not provided
    if isempty(ch_labels)
        ch_labels = arrayfun(@(x) sprintf('Ch%d', x), 1:size(data, 2), 'UniformOutput', false);
    end

    % Initialize offsets array
    offsets = zeros(1, size(data, 2));
    numChannels = size(data, 2);
    % Plot each column with specified parameters
    for chIdx = 1:numChannels
        % Determine the offset
        offsets(chIdx) = -(chIdx-1) * shiftCoeff;

        % Plotting the line with an offset
        plotArgs = {'LineWidth', getOptionalParam(lineWidths, chIdx),...
                    'Color', getOptionalParam(colors, chIdx),...
                    'DisplayName', getOptionalParam(displayNames, chIdx),...
                    'LineStyle', getOptionalParam(lineStyles, chIdx)};
                
        % Add marker-related properties if a marker is specified
        marker = getOptionalParam(markers, chIdx);
        if ~isempty(marker)
            plotArgs = [plotArgs, {'Marker', marker,...
                                    'MarkerSize', getOptionalParam(markerSizes, chIdx),...
                                    'MarkerEdgeColor', getOptionalParam(markerEdgeColors, chIdx), ...
                                    'MarkerFaceColor', getOptionalParam(markerFaceColors, chIdx)}];
        end
        plot(time, data(:, chIdx) + offsets(chIdx), plotArgs{:});
    end
    
    if size(data, 2)>1
        mid_y = round(size(data, 2) / 2);
        coord_y_line = offsets([mid_y, mid_y+1]);
        text_in = [num2str(round(-offsets(2)))];
    else
        coord_y_line = [0, shiftCoeff];
        text_in = [num2str(shiftCoeff)];
    end
    
    coordx = time(1) + (time(end)-time(1))*0.95;
    coord_x_line = [coordx, coordx];
    
    text_x = time(1) + (time(end)-time(1))*0.96;
    text_y = coord_y_line(1) + diff(coord_y_line)/2;
    
    
    %plot(coord_x_line, coord_y_line, AmplitudeMarkerColor, 'LineWidth',2)
    %text(text_x,text_y, text_in, 'Color', AmplitudeMarkerColor)

    yticks(flip(offsets));
    yticklabels(flip(ch_labels)); % Use ch_labels for y-axis labels
end

function param = getOptionalParam(paramArray, index)
    % Helper function to get the parameter value based on index
    if iscell(paramArray)
        param = paramArray{min(index, length(paramArray))};
    elseif isvector(paramArray)
        param = paramArray(min(index, length(paramArray)));
    else
        param = paramArray; % Use default if index exceeds the length of paramArray
    end
end
