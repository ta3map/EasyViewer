function sz = lfp_size(lfp_file)
    if isa(lfp_file, 'matlab.io.MatFile')
        info = whos(lfp_file, 'lfp');
        sz = info.size;
    else
        sz = size(lfp_file.lfp);
    end
end
