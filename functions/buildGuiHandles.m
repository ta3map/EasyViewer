function h = buildGuiHandles(fig, nameToTag)
    names = fieldnames(nameToTag);
    h = struct();
    for i = 1:numel(names)
        fieldName = names{i};
        tag = nameToTag.(fieldName);
        obj = findobj(fig, 'Tag', tag);
        if isempty(obj)
            error('buildGuiHandles: tag not found: %s (%s)', tag, fieldName);
        end
        if numel(obj) > 1
            obj = obj(1);
        end
        h.(fieldName) = obj;
    end
end
