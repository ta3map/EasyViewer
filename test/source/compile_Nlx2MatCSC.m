% Команда для компиляции Nlx2MatCSC.mexw64
% Все необходимые .cpp файлы для успешной компиляции

files = {
    'Nlx2MatCSC.cpp', ...           % Главный MEX файл
    'ProcessorCSC.cpp', ...         % Реализация класса Processor для CSC
    'FileDataBucket.cpp', ...       % Управление файловыми источниками данных
    'GeneralOperations.cpp', ...    % Общие операции для работы с MEX
    'TimeBuf.cpp', ...              % Базовый класс для работы с временными буферами
    'TimeCSCBuf.cpp', ...           % Буфер для CSC файлов (Continuous Sampling)
    'TimeSEBuf.cpp', ...             % Буфер для SE файлов (Single Electrode)
    'TimeSTBuf.cpp', ...             % Буфер для ST файлов (Stereotrode)
    'TimeTSBuf.cpp', ...             % Буфер для TS файлов (Timestamp)
    'TimeTTBuf.cpp', ...             % Буфер для TT файлов (Tetrode)
    'TimeEventBuf.cpp', ...          % Буфер для Event файлов
    'TimeVideoBuf.cpp', ...          % Буфер для Video файлов
    'TimeMClustTSBuf.cpp', ...       % Буфер для MClust TS файлов
    'Nlx_Code.cpp' ...               % Функции для определения типа файла Neuralynx
};

% Компиляция
mex(files{:});

fprintf('Компиляция завершена успешно!\n');

