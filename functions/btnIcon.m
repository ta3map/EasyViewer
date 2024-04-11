function btnIcon(btn, icon_filepath)
    try
        [im_orig, ~, alpha] = imread(icon_filepath);  % Загружаем изображение и альфа-канал
        im_sized = imresize(im_orig, [30, 30]); % Изменяем размер изображения под размер кнопки
        alpha_sized = imresize(alpha, [30, 30]); % Изменяем размер альфа-канала аналогично

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
    catch
        
    end
end
