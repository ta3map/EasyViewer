function values = reorderChannelVector(values, perm)
    if numel(values) == numel(perm)
        values = values(perm);
    end
end
