function xG = mapTimeToGrid(x, c, Xlims)
xSpan = diff(Xlims);
xG = Xlims(1) + (c - 1) * xSpan + (x - Xlims(1));
end
