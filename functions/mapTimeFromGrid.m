function xLocal = mapTimeFromGrid(xGrid, Xlims, nCols)
xSpan = diff(Xlims);
c = floor((xGrid - Xlims(1)) / xSpan) + 1;
c = min(max(c, 1), nCols);
xLocal = xGrid - (c - 1) * xSpan;
end
