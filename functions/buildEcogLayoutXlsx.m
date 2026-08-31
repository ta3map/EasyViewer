function buildEcogLayoutXlsx(ecogCh, outPath)
%BUILDECOGLAYOUTXLSX Excel grid from ecogCh [chIdx, row, col, ...].

    ok = ~isnan(ecogCh(:, 2)) & ~isnan(ecogCh(:, 3));
    ec = ecogCh(ok, :);
    nRows = max(ec(:, 2));
    nCols = max(ec(:, 3));
    grid = cell(nRows, nCols);
    for i = 1:size(ec, 1)
        grid{ec(i, 2), ec(i, 3)} = ec(i, 1);
    end
    emptyMask = cellfun(@isempty, grid);
    grid(emptyMask) = {''};
    writecell(grid, outPath);
end
