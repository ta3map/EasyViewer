function transliterated = transliterateColumnName(name)
    % transliterateColumnName - транскрибирует кириллические буквы в латиницу
    % и делает имя валидным для MATLAB переменных
    %
    % Input:
    %   name - строка с названием (может содержать кириллицу)
    %
    % Output:
    %   transliterated - строка с транскрибированным названием
    
    if isempty(name)
        transliterated = '';
        return
    end
    
    if ~ischar(name) && ~isstring(name)
        transliterated = '';
        return
    end
    
    if isstring(name)
        name = char(name);
    end
    
    % Таблица транскрипции кириллицы в латиницу
    cyrillicToLatin = containers.Map();
    
    % Заглавные буквы
    cyrillicToLatin('А') = 'A';
    cyrillicToLatin('Б') = 'B';
    cyrillicToLatin('В') = 'V';
    cyrillicToLatin('Г') = 'G';
    cyrillicToLatin('Д') = 'D';
    cyrillicToLatin('Е') = 'E';
    cyrillicToLatin('Ё') = 'Yo';
    cyrillicToLatin('Ж') = 'Zh';
    cyrillicToLatin('З') = 'Z';
    cyrillicToLatin('И') = 'I';
    cyrillicToLatin('Й') = 'Y';
    cyrillicToLatin('К') = 'K';
    cyrillicToLatin('Л') = 'L';
    cyrillicToLatin('М') = 'M';
    cyrillicToLatin('Н') = 'N';
    cyrillicToLatin('О') = 'O';
    cyrillicToLatin('П') = 'P';
    cyrillicToLatin('Р') = 'R';
    cyrillicToLatin('С') = 'S';
    cyrillicToLatin('Т') = 'T';
    cyrillicToLatin('У') = 'U';
    cyrillicToLatin('Ф') = 'F';
    cyrillicToLatin('Х') = 'Kh';
    cyrillicToLatin('Ц') = 'Ts';
    cyrillicToLatin('Ч') = 'Ch';
    cyrillicToLatin('Ш') = 'Sh';
    cyrillicToLatin('Щ') = 'Shch';
    cyrillicToLatin('Ъ') = '';
    cyrillicToLatin('Ы') = 'Y';
    cyrillicToLatin('Ь') = '';
    cyrillicToLatin('Э') = 'E';
    cyrillicToLatin('Ю') = 'Yu';
    cyrillicToLatin('Я') = 'Ya';
    
    % Строчные буквы
    cyrillicToLatin('а') = 'a';
    cyrillicToLatin('б') = 'b';
    cyrillicToLatin('в') = 'v';
    cyrillicToLatin('г') = 'g';
    cyrillicToLatin('д') = 'd';
    cyrillicToLatin('е') = 'e';
    cyrillicToLatin('ё') = 'yo';
    cyrillicToLatin('ж') = 'zh';
    cyrillicToLatin('з') = 'z';
    cyrillicToLatin('и') = 'i';
    cyrillicToLatin('й') = 'y';
    cyrillicToLatin('к') = 'k';
    cyrillicToLatin('л') = 'l';
    cyrillicToLatin('м') = 'm';
    cyrillicToLatin('н') = 'n';
    cyrillicToLatin('о') = 'o';
    cyrillicToLatin('п') = 'p';
    cyrillicToLatin('р') = 'r';
    cyrillicToLatin('с') = 's';
    cyrillicToLatin('т') = 't';
    cyrillicToLatin('у') = 'u';
    cyrillicToLatin('ф') = 'f';
    cyrillicToLatin('х') = 'kh';
    cyrillicToLatin('ц') = 'ts';
    cyrillicToLatin('ч') = 'ch';
    cyrillicToLatin('ш') = 'sh';
    cyrillicToLatin('щ') = 'shch';
    cyrillicToLatin('ъ') = '';
    cyrillicToLatin('ы') = 'y';
    cyrillicToLatin('ь') = '';
    cyrillicToLatin('э') = 'e';
    cyrillicToLatin('ю') = 'yu';
    cyrillicToLatin('я') = 'ya';
    
    % Транскрибируем посимвольно
    result = '';
    for i = 1:length(name)
        ch = name(i);
        if isKey(cyrillicToLatin, ch)
            result = [result, cyrillicToLatin(ch)];
        else
            result = [result, ch];
        end
    end
    
    % Делаем имя валидным для MATLAB (заменяем недопустимые символы на подчеркивания)
    transliterated = matlab.lang.makeValidName(result);
end

