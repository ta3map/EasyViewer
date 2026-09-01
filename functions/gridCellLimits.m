function [cellXlims, cellYlims] = gridCellLimits(r, c, nRows, nCols, Xlims, Ylims)
xSpan = diff(Xlims);
ySpan = diff(Ylims);
cellXlims = [Xlims(1) + (c - 1) * xSpan, Xlims(1) + c * xSpan];
cellYlims = [(nRows - r) * ySpan, (nRows - r + 1) * ySpan];
end
