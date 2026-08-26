function drawPlotScaleBars(ax, ampValue, timeSpan, selectedUnit)
%DRAWPLOTSCALEBARS Thick Y/X scale bars in axes coords; labels from ampValue/timeSpan.

    Xlims = xlim(ax);
    Ylims = ylim(ax);
    xSpan = diff(Xlims);
    ySpan = diff(Ylims);
    pos = get(ax, 'Position');
    ampBarLen = min(ampValue, 0.15 * ySpan);
    maxBarTime = timeSpan * (ampBarLen / ySpan) * (pos(4) / pos(3));
    barTime = niceTimeScale(timeSpan, maxBarTime);
    timeBarLen = (barTime / timeSpan) * xSpan;
    x0 = Xlims(1) + 0.08 * xSpan;
    y0 = Ylims(1) + 0.03 * ySpan;

    hold(ax, 'on');
    plot(ax, [x0 x0], [y0 y0 + ampBarLen], 'k-', 'LineWidth', 3, ...
        'Tag', 'plotScaleBar', 'HitTest', 'off', 'Clipping', 'on');
    text(ax, x0, y0 + ampBarLen + 0.015 * ySpan, sprintf('%g', ampValue), ...
        'FontSize', 10, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
        'Tag', 'plotScaleBar', 'HitTest', 'off', 'Clipping', 'on');

    plot(ax, [x0 x0 + timeBarLen], [y0 y0], 'k-', 'LineWidth', 3, ...
        'Tag', 'plotScaleBar', 'HitTest', 'off', 'Clipping', 'on');
    text(ax, x0 + timeBarLen / 2, y0 + 0.015 * ySpan, sprintf('%g %s', barTime, selectedUnit), ...
        'FontSize', 10, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
        'Tag', 'plotScaleBar', 'HitTest', 'off', 'Clipping', 'on');
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
