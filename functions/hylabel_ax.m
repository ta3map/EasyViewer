function hylabel_ax(x, ax, mytext)

% Добавление текста
hT = text(x, ax.YLim(2), mytext, 'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'center', 'interpreter', 'none');
end
