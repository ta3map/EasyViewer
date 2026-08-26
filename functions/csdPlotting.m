function hImg = csdPlotting(csd_image, csd_t_range, csd_ch_range, hImg)

if nargin < 4
    hImg = [];
end

if ~isempty(hImg) && isgraphics(hImg)
    set(hImg, 'CData', csd_image, 'XData', csd_t_range, 'YData', csd_ch_range);
else
    hImg = imagesc(csd_image, 'XData', csd_t_range, 'YData', csd_ch_range);
end
set(hImg, 'Tag', 'csd_layer');
colormap jet

branch_plus = abs(prctile(csd_image, 99, 'all'));
if ~(isfinite(branch_plus) && branch_plus > 0)
    branch_plus = max(abs(csd_image(:)));
    branch_plus = max(branch_plus, 1);
end
caxis([-branch_plus, branch_plus]);

end
