function [lfp, spks, stims, lfpVar, sweep_info] = sweepProcessData(p, spks, n, m, lfp, Fs, zavp, lfpVar)

    % Показываем окно прогресса
    hWaitBar = waitbar(0, 'Opening...', 'Name', 'Opening file with sweeps');
    
    sps_exist = ~isempty(spks);
    
    % Собираем спайки
    if sps_exist
        spks_new = repmat(struct('tStamp', [], 'ampl', [], 'shape', []), n, 1);
        for ch = 1:n
            spks_new(ch).tStamp = spks(ch, 1).tStamp;
            spks_new(ch).ampl   = spks(ch, 1).ampl;
            spks_new(ch).shape  = spks(ch, 1).shape;
        end
    else
        spks_new = [];
    end
    
    % Формируем lfp_new, «распрямляя» по свипам
    lfp_new = zeros(m * p, n);
    index = 1;
    for i = 1:p
        for j = 1:m
            lfp_new(index, :) = lfp(j, :, i);
            index = index + 1;
        end
        
        if sps_exist
            spks_time_shift_ms = (m / Fs) * 1000;
            for ch = 1:n
                spks_new(ch).tStamp = [
                    spks_new(ch).tStamp; 
                    spks(ch, i).tStamp + spks_time_shift_ms * (i - 1)
                ];
                spks_new(ch).ampl   = [spks_new(ch).ampl;  spks(ch, i).ampl];
                spks_new(ch).shape  = [spks_new(ch).shape; spks(ch, i).shape];
            end
        end
        current_message = sprintf('%d sweep of %d', i, p);
        % disp(current_message);
        waitbar(i/p, hWaitBar, current_message);
    end
    
    close(hWaitBar);
    
    lfp  = lfp_new;
    spks = spks_new;
    clear lfp_new spks_new

    % -- ФОРМИРУЕМ STIMS --
    %
    % Изначально считаем stims пустым. Если данные о стимах неконсистентны,
    % в конце останется [].
    stims = [];
    
    % Шаг 1: Проверяем, есть ли вообще поле realStim
    if isfield(zavp, 'realStim') && ~isempty(zavp.realStim)
        realStimArray = zavp.realStim(:); % делаем вектор структур
        nElems = numel(realStimArray);
        
        % Шаг 2: Собираем все поля r в ячейковый массив (чтобы не упасть на horzcat)
        rCells = cell(nElems, 1);
        for i = 1 : nElems
            if isfield(realStimArray(i), 'r') && ~isempty(realStimArray(i).r) ...
                    && isnumeric(realStimArray(i).r)
                % Приведём к строке или столбцу (договоримся, что всё храним как строчки)
                rCells{i} = realStimArray(i).r(:)';
            else
                % Если поле отсутствует/пустое/нечисловое - сделаем пустым,
                % потом вставим NaN при выравнивании
                rCells{i} = [];
            end
        end
        
        % Шаг 3: определяем, какой максимальной длины r встретились
        lenEach = cellfun(@length, rCells); 
        maxLen = max(lenEach);
        
        if maxLen == 0
            % Значит все r были пустыми => оставим stims = []
            warning('sweepProcessData:NoValidR',...
                'All realStim(:).r fields were empty or invalid. stims set to [].');
        else
            % Шаг 4: создаём большую матрицу [nElems x maxLen], заполняем NaN
            bigR = nan(nElems, maxLen);
            for i = 1 : nElems
                if ~isempty(rCells{i})
                    % занимаем первые lenEach(i) столбцов
                    bigR(i, 1:lenEach(i)) = rCells{i};
                end
            end
            
            % Шаг 5: если количество элементов совпадает с p (числом свипов),
            %       то применяем «сдвиг по времени» (по сути, как было в исходном коде).
            %       Иначе можно вывести предупреждение или придумать логику на случай
            %       расхождения.
            if nElems == p
                % Ваша формула: stims = ([zavp.realStim(:).r] * zavp.siS + ((m:m:(m * p)) - m) / Fs)'
                % Теперь каждая из nElems строк - это "один свип".
                % time_shifts — вектор из p значений (по одному на свип)
                time_shifts = ((m : m : (m*p)) - m) / Fs;  % размер 1 x p
                
                % Нам нужно «сдвинуть» каждую строку так, чтобы все значения
                % получили добавку time_shifts(i). Однако см. формулу: мы сначала
                % умножаем на zavp.siS, потом добавляем shift. 
                % Можно «преобразовать» прямо в bigR, например:
                for i = 1 : p
                    % поделим shift на zavp.siS, чтобы держать согласованность с bigR
                    shiftInRunits = time_shifts(i) / zavp.siS;
                    % сместим всю строку
                    bigR(i, :) = bigR(i, :) + shiftInRunits;
                end
            else
                warning('sweepProcessData:RealStimCountMismatch',...
                    'Number of realStim elements (%d) ~= p (%d). No time shift applied.', ...
                    nElems, p);
            end
            
            % Шаг 6: теперь аналог «( ... ) * zavp.siS', но у нас bigR в виде [nElems x maxLen].
            %        Если хотите собрать всё в один общий вектор (игнорируя NaN),
            %        можно сделать так:
            bigR = bigR * zavp.siS; % переводим «время» в секунды (или миллисекунды — зависит от siS)
            
            % Сложим всё в один вектор, убирая NaN:
            stimsAll = bigR';          % теперь [maxLen x nElems]
            stimsAll = stimsAll(:);    % превратим в вектор столбец
            stims = stimsAll(~isnan(stimsAll)); 
            % => stims теперь вектор, где последовательно лежат все «r», 
            %    сдвинутые по времени (при условии что nElems == p).
        end
    end

    % Окончание: lfpVar
    lfpVar = np_flatten(mean(lfpVar, 2))'; % случай со свипами
    
    % Создаем структуру с информацией о свипах
    sweep_info = struct();
    sweep_info.sweep_times = (0:p-1) * (m/Fs);  % времена начала каждого свипа в секундах
    sweep_info.sweep_duration = m/Fs;            % длительность одного свипа в секундах
    sweep_info.sweep_count = p;                  % количество свипов
    sweep_info.is_sweep_data = true;             % флаг, что это данные со свипами
    sweep_info.samples_per_sweep = m;            % количество сэмплов в одном свипе
    
end
