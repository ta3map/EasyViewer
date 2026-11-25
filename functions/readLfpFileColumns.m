function block = readLfpFileColumns(lfp_file, rowStart, rowEnd, fileCols)
    rows = rowStart:rowEnd;
    fileCols = fileCols(:)';
    if ~isa(lfp_file, 'matlab.io.MatFile')
        block = lfp_file.lfp(rows, fileCols);
        return
    end
    if isscalar(fileCols)
        block = lfp_file.lfp(rows, fileCols);
        return
    end
    d = diff(fileCols);
    if all(d == d(1))
        block = lfp_file.lfp(rows, fileCols(1):d(1):fileCols(end));
        return
    end
    colRange = min(fileCols):max(fileCols);
    wide = lfp_file.lfp(rows, colRange);
    [~, pick] = ismember(fileCols, colRange);
    block = wide(:, pick);
end
