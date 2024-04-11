function btnIcon(btn, icon_filepath, keep_text)
    try
        [im_orig, ~, alpha] = imread(icon_filepath);  % Загружаем изображение и альфа-канал
        btnPos = get(btn, 'Position'); % Получаем позицию и размеры кнопки
        iconHeight = btnPos(4)*0.8; % Высота иконки равна высоте кнопки
        
        im_sized = imresize(im_orig, [iconHeight, NaN]); % Изменяем размер изображения, сохраняя пропорции
        alpha_sized = imresize(alpha, [iconHeight, NaN]); % Аналогично для альфа-канала

        
        % Преобразование изображения в double для последующей обработки
        im_double = double(im_sized) / 255;

        % Преобразуем альфа-канал в маску, где альфа < 255 становится NaN
        alpha_mask = double(alpha_sized) / 255; % Нормализуем альфа-канал
        alpha_mask(alpha_mask < 1) = NaN; % Устанавливаем NaN для пикселей с альфа < 1 (255 в оригинале)

        % Применяем маску альфа-канала к каждому цветовому каналу изображения
        for k = 1:3 % Применяем маску к каждому из RGB каналов
            im_double(:,:,k) = im_double(:,:,k) .* alpha_mask;
        end

        % Устанавливаем обработанное изображение как CData для кнопки
        set(btn, 'CData', im_double);
        
        TooltipString = get(btn,'String');
        set(btn, 'TooltipString', TooltipString);
        
        if ~keep_text
            % Убираем текст за ненадобностью
            set(btn,'String', '');
        end
    catch
        
    end
end
