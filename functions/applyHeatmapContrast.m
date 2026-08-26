function applyHeatmapContrast(ax, baseClim, contrastPercent)
%APPLYHEATMAPCONTRAST Scale axes CLim relative to base clim by contrast %.
% formula: halfSpan = baseHalf / (coef/100)

contrastCoefMin = 10;
contrastCoefMax = 250;
coef = double(contrastPercent);
coef = coef(isfinite(coef) & isreal(coef));
coef = [coef, 100];
coef = coef(1);
coef = min(max(coef, contrastCoefMin), contrastCoefMax);

baseClim = double(baseClim(:)).';
center = mean(baseClim(1:2));
baseHalfSpan = (baseClim(2) - baseClim(1)) / 2;
baseHalfSpan = max(baseHalfSpan, eps);

contrastScale = max(coef / 100, eps);
halfSpan = baseHalfSpan / contrastScale;
set(ax, 'CLim', center + [-halfSpan, halfSpan]);

end
