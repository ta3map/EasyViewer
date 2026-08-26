function pos = getGUIElementPosition(coordsData, tag, relativeTags)
    if ~isfield(coordsData.elements, tag)
        error('Coordinates for element %s not found in JSON file', tag);
    end
    pos = coordsData.elements.(tag);
    if ismember(tag, relativeTags)
        return;
    end
    base_pos = coordsData.base_figure_position;
    pos = [
        pos(1) * base_pos(3), ...
        pos(2) * base_pos(4), ...
        pos(3) * base_pos(3), ...
        pos(4) * base_pos(4)
    ];
end
