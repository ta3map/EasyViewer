function maxPoints = plotDecimationLimit(hGraphic, nCells)
%PLOTDECIMATIONLIMIT Max polyline points (~2 per screen pixel).

if nargin < 2 || isempty(nCells)
    nCells = 1;
end
nCells = max(1, round(nCells));

defaultLimit = 3000;
if nargin < 1 || isempty(hGraphic) || ~isgraphics(hGraphic)
    maxPoints = defaultLimit;
    return
end

ax = ancestor(hGraphic, 'axes');
if isempty(ax) || ~isgraphics(ax)
    maxPoints = defaultLimit;
    return
end

pos = getpixelposition(ax, true);
maxPoints = max(500, 2 * round(pos(3) / nCells));

end
