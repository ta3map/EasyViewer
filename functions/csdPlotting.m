function hImg = csdPlotting(csd_image, csd_t_range, csd_ch_range, hImg, parentAx)

if nargin < 4
    hImg = [];
end
if nargin < 5 || isempty(parentAx)
    parentAx = gca;
end

if ~isempty(hImg) && isgraphics(hImg)
    set(hImg, 'CData', csd_image, 'XData', csd_t_range, 'YData', csd_ch_range);
else
    hImg = imagesc(parentAx, csd_t_range, csd_ch_range, csd_image);
end
set(hImg, 'Tag', 'csd_layer');
colormap(parentAx, jet);

branch_plus = abs(prctile(csd_image, 99, 'all'));
if ~(isfinite(branch_plus) && branch_plus > 0)
    branch_plus = max(abs(csd_image(:)));
    branch_plus = max(branch_plus, 1);
end
caxis(parentAx, [-branch_plus, branch_plus]);

end
