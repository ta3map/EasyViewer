function applyIosPlayerContrast(ax, baseRange, contrastValue)
    baseRange = double(baseRange(:)).';
    center = (baseRange(1) + baseRange(2)) / 2;
    half = (baseRange(2) - baseRange(1)) / 2;
    half = max(half, eps(abs(center) + 1));
    contrastValue = max(double(contrastValue), eps);
    ax.CLim = center + (half / contrastValue) * [-1 1];
end
