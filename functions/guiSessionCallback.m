function varargout = guiSessionCallback(figTag, name)
%GUISESSIONCALLBACK Get or invoke a callback stored in a main GUI figure UserData.

    cb = [];
    figs = findobj('Type', 'figure', 'Tag', figTag);
    if ~isempty(figs)
        ud = get(figs(1), 'UserData');
        if isstruct(ud) && isfield(ud, name)
            candidate = ud.(name);
            if isa(candidate, 'function_handle')
                cb = candidate;
            end
        end
    end

    if nargout > 0
        varargout{1} = cb;
        return;
    end

    if isempty(cb)
        return;
    end

    cb();
end
