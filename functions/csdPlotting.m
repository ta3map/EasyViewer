function hImg = csdPlotting(csd_image, csd_t_range, csd_ch_range, csd_contrast_coef, hImg)

if nargin < 5
    hImg = [];
end

if ~isempty(hImg) && isgraphics(hImg)
    set(hImg, 'CData', csd_image, 'XData', csd_t_range, 'YData', csd_ch_range);
else
    hImg = imagesc(csd_image, 'XData', csd_t_range, 'YData', csd_ch_range);
end
set(hImg, 'Tag', 'csd_layer');
colormap jet

rawCoef = double(csd_contrast_coef);
rawCoef = rawCoef(:).';
rawCoef = rawCoef(isfinite(rawCoef) & isreal(rawCoef));
rawCoef = [rawCoef, 99.9];
rawCoef = rawCoef(1);
rawCoef = rawCoef .* (1 + 99 * (rawCoef <= 1));
rawCoef = max(rawCoef, 0);

coefForPrctile = min(rawCoef, 100);

if rawCoef > 100
    branch_plus = prctile(csd_image, 100, 'all') * (rawCoef / 100);
else
    branch_plus = prctile(csd_image, coefForPrctile, 'all');
end

caxis([-branch_plus, branch_plus]);

end
