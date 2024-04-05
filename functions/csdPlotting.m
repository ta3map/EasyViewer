function csdPlotting(csd_image, csd_t_range, csd_ch_range, csd_contrast_coef)
   
    imagesc(csd_image, 'XData', csd_t_range, 'YData', csd_ch_range)
    colormap jet
    branch_plus = prctile(csd_image, csd_contrast_coef, 'all');
    caxis([-branch_plus, branch_plus]);
    
end