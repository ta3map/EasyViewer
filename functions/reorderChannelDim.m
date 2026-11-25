function values = reorderChannelDim(values, perm)
    n = numel(perm);
    dim = find(size(values) == n, 1);
    if isempty(values) || isempty(dim)
        return
    end
    idx = repmat({':'}, 1, max(ndims(values), dim));
    idx{dim} = perm;
    values = values(idx{:});
end
