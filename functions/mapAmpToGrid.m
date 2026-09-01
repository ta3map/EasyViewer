function yG = mapAmpToGrid(y, r, Ylims, nRows)
ySpan = diff(Ylims);
yG = (nRows - r) * ySpan + (y - Ylims(1));
end
