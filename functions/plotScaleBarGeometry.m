function g = plotScaleBarGeometry(ax, ampValue, timeSpan, selectedUnit, xlimsOverride, ylimsOverride)
%PLOTSCALEBARGEOMETRY Layout for amp/time scale bars in data axes coords.

if nargin >= 5 && ~isempty(xlimsOverride)
    Xlims = xlimsOverride;
else
    Xlims = xlim(ax);
end
if nargin >= 6 && ~isempty(ylimsOverride)
    Ylims = ylimsOverride;
else
    Ylims = ylim(ax);
end

xSpan = diff(Xlims);
ySpan = diff(Ylims);
pos = get(ax, 'Position');
ampBarLen = min(ampValue, 0.15 * ySpan);
maxBarTime = timeSpan * (ampBarLen / ySpan) * (pos(4) / pos(3));
barTime = niceTimeScale(timeSpan, maxBarTime);
timeBarLen = (barTime / timeSpan) * xSpan;
x0 = Xlims(1) + 0.08 * xSpan;
y0 = Ylims(1) + 0.03 * ySpan;

g = struct();
g.ampLineX = [x0 x0];
g.ampLineY = [y0 y0 + ampBarLen];
g.ampLabelPos = [x0, y0 + ampBarLen + 0.015 * ySpan, 0];
g.ampLabelStr = sprintf('%g', ampValue);
g.timeLineX = [x0 x0 + timeBarLen];
g.timeLineY = [y0 y0];
g.timeLabelPos = [x0 + timeBarLen / 2, y0 + 0.015 * ySpan, 0];
g.timeLabelStr = sprintf('%g %s', barTime, selectedUnit);

end

function v = niceTimeScale(span, maxLen)
maxLen = min(span / 2, maxLen);
target = maxLen / 2;
exp10 = floor(log10(target));
mant = [1 2 5 8];
cands = [mant * 10^(exp10 - 1), mant * 10^exp10, mant * 10^(exp10 + 1)];
cands = cands(cands > 0 & cands <= maxLen);
v = cands(end);
end
