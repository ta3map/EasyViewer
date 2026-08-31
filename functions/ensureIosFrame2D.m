function data = ensureIosFrame2D(data)
    if ndims(data) == 4
        data = squeeze(data);
    end
end
