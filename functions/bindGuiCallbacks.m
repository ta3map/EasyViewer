function bindGuiCallbacks(fig, bindings)
    for i = 1:size(bindings, 1)
        tag = bindings{i, 1};
        callback = bindings{i, 2};
        propertyName = 'Callback';
        if size(bindings, 2) >= 3
            propertyName = bindings{i, 3};
        end
        obj = findobj(fig, 'Tag', tag);
        if isempty(obj)
            error('bindGuiCallbacks: tag not found: %s', tag);
        end
        if numel(obj) > 1
            obj = obj(1);
        end
        obj.(propertyName) = callback;
    end
end
