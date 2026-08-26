function out = normalizeEventMetadata(src, n, defaultSource)
    out = createDefaultEventMetadata(defaultSource, n);
    if n == 0 || isempty(src)
        return;
    end
    k = min(n, numel(src));
    for i = 1:k
        item = src(i);
        if iscell(src)
            item = src{i};
        end
        if ~isstruct(item)
            continue;
        end
        if isfield(item, 'source'), out(i).source = item.source; end
        if isfield(item, 'method'), out(i).method = item.method; end
        if isfield(item, 'data_type'), out(i).data_type = item.data_type; end
        if isfield(item, 'polarity'), out(i).polarity = item.polarity; end
        if isfield(item, 'prominence'), out(i).prominence = item.prominence; end
        if isfield(item, 'detection_params'), out(i).detection_params = item.detection_params; end
    end
end
