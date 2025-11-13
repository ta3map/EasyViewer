% Простой тест функции Nlx2MatCSC (без нагрузки на систему)
% Тестирует только заголовок и первые 10 записей

% Добавляем путь к папке functions
addpath(fullfile(pwd, 'functions'));

filename = '\\10.167.11.29\data2\photothrombosis\2025-07-22\2025-07-22_13-05-28\CSC1.ncs';

fprintf('Тестирование Nlx2MatCSC с файлом:\n%s\n\n', filename);

% Тест 1: Чтение только заголовка (самый легкий тест)
fprintf('1. Чтение заголовка...\n');
try
    Header = Nlx2MatCSC(filename, [0 0 0 0 0], 1, 1, []);
    fprintf('   ✓ Заголовок успешно прочитан (%d строк)\n', length(Header));
    fprintf('   Первые 3 строки заголовка:\n');
    for i = 1:min(3, length(Header))
        fprintf('   %s\n', Header{i});
    end
catch ME
    fprintf('   ✗ Ошибка: %s\n', ME.message);
end

fprintf('\n');

% Тест 2: Чтение только первых 10 записей (легкий тест данных)
fprintf('2. Чтение первых 10 записей...\n');
try
    [Timestamps, Samples] = Nlx2MatCSC(filename, [1 0 0 0 1], 0, 2, [1 10]);
    fprintf('   ✓ Данные успешно прочитаны\n');
    fprintf('   Количество записей: %d\n', length(Timestamps));
    fprintf('   Размер матрицы Samples: %s\n', mat2str(size(Samples)));
    fprintf('   Первая временная метка: %d\n', Timestamps(1));
    fprintf('   Последняя временная метка: %d\n', Timestamps(end));
catch ME
    fprintf('   ✗ Ошибка: %s\n', ME.message);
end

fprintf('\nТест завершен.\n');

