function [lfp, spks, hd, zavp, lfpVar, chnlGrp] = hekaToZav(filepath)
    % Конвертирует Heka .mat файл в формат ZAV
    %
    % Параметры:
    %   filepath - путь к Heka .mat файлу
    %
    % Возвращает:
    %   lfp, spks, hd, zavp, lfpVar, chnlGrp - переменные в формате ZAV
    
    disp('Converting Heka file to ZAV format...');
    
    try
        % Загружаем данные через HekaMat
        [data, Freq] = HekaMat(filepath);
        
        % Получаем размеры данных
        n_channels = size(data, 2);
        n_sweeps = size(data, 3);
        n_points = size(data, 1);
        
        disp(['Found ' num2str(n_channels) ' channels, ' num2str(n_sweeps) ' sweeps, ' num2str(n_points) ' points per sweep']);
        
        % Сохраняем свипы раздельно в формате [точки_времени, каналы, свипы]
        lfp = zeros(n_points, n_channels, n_sweeps);
        
        % Обработка данных с масштабированием
        for CH = 1:n_channels
            for sweep = 1:n_sweeps
                d = data(:, CH, sweep);
                
                % Масштабирование данных (как в PreprocessingEC)
                if abs(median(d)) > 1e-3 && abs(median(d)) < 1e-1
                    lfp(:, CH, sweep) = 1e3 * d;
                elseif abs(median(d)) < 1e-7
                    lfp(:, CH, sweep) = 1e12 * d;
                else
                    lfp(:, CH, sweep) = d;
                end
            end
        end
        
        % Создаем события для каждого свипа в формате, совместимом с sweepProcessData
        zavp.realStim = struct('r', cell(1, n_sweeps));
        for sweep = 1:n_sweeps
            zavp.realStim(sweep).r = 1; % Начало каждого свипа
        end
        
        % Создаем структуру спайков для каждого канала и свипа
        spks = repmat(struct('tStamp', [], 'ampl', Inf, 'shape', []), n_channels, n_sweeps);
        
        % Рассчитываем вариацию для каждого канала по свипам
        lfpVar = zeros(n_channels, n_sweeps);
        for ch = 1:n_channels
            for sweep = 1:n_sweeps
                lfpVar(ch, sweep) = std(lfp(:, ch, sweep));
            end
        end
        
        % Создаем заголовок
        [~, filename, ~] = fileparts(filepath);
        zavp.file = filename;
        zavp.rarStep = Freq/Freq;
        zavp.dwnSmplFrq = Freq;
        zavp.siS = 1e-3;
        zavp.prm = [];
        zavp.stimCh = 4;
        
        hd.fFileSignature = 'HEKA';
        hd.lActualEpisodes = n_sweeps;
        hd.si = 1e6/Freq;
        hd.nADCNumChannels = n_channels;
        hd.nOperationMode = 3;
        hd.recTime = [1 n_points];
        hd.sweepLengthInPts = n_points;
        
        % Создаем имена каналов
        recChNames = cell(1, n_channels);
        for i = 1:n_channels
            recChNames{i} = ['Ch', num2str(i)];
        end
        hd.recChNames = recChNames;
        
        % Группы каналов
        chnlGrp = 1:n_channels;
        
        disp(['Successfully converted Heka file: ' filename]);
        disp(['Data size: [' num2str(size(lfp)) ']']);
        
    catch ME
        error(['Error converting Heka file: ' ME.message]);
    end
end 