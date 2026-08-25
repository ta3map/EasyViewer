


clear;
Fnm='\\10.167.11.29\data2\Alina\EC_PYR_FS\EC_PYR_FS.xlsx';

[~,~,raw]=xlsread(Fnm);


FilesList(1).s=3:42;

FilesList(2).s=47:67;

FilesList(3).s=72:91;

FilesList(4).s=96:114;

FilesList(5).s=117:133;

FilesList(6).s=136:158;

FilesList(7).s=163:181;

FilesList(8).s=186:207;

FilesList(9).s=210:235;

for exper=1:9
    
for t1=FilesList(exper).s

clearvars -except t1 Fnm raw FilesList exper


Filename=raw{t1,1};


[data,Freq]=HekaMat(Filename);



%
n_channels = size(data,2);
n_sweeps = size(data,3);

clear lfp;
% Сохраняем свипы раздельно в формате [точки_времени, каналы, свипы]
lfp = zeros(size(data,1), n_channels, n_sweeps);

for CH=1:n_channels
    for sweep=1:n_sweeps
        d = data(:,CH,sweep);
        
        % Масштабирование данных
        if abs(median(d))>1e-3  &  abs(median(d))<1e-1
            lfp(:,CH,sweep)=1e3*d;
        elseif abs(median(d))<1e-7
            lfp(:,CH,sweep)=1e12*d;
        else
            lfp(:,CH,sweep)=d;
        end
    end
end


% Создаем события для каждого свипа отдельно
events_per_sweep = cell(1, n_sweeps);
for sweep=1:n_sweeps
    events_per_sweep{sweep} = 1; % Начало каждого свипа
end




    Cf=Freq/1e3;
    
    
    

clear spks
% Создаем структуру спайков для каждого канала и свипа
spks = repmat(struct('tStamp', [], 'ampl', Inf, 'shape', []), n_channels, n_sweeps);


% lfpVar = par.std;

clear lfpVar;
% Рассчитываем вариацию для каждого канала по всем свипам
for ch=1:size(lfp,2)
    % Объединяем данные всех свипов для расчета вариации
    all_sweeps_data = reshape(lfp(:,ch,:), [], 1);
    lfpVar(ch)=std(all_sweeps_data);
end


zavp.file = Filename(1:(end - 4));
zavp.rarStep = Freq/Freq;

% zavp.siS = 1e-6*1e6/Freq;
zavp.dwnSmplFrq = Freq;
zavp.siS = 1e-3;
zavp.prm = [];
% Сохраняем события для каждого свипа
zavp.realStim = events_per_sweep;
hd.fFileSignature = 'NLX';
hd.lActualEpisodes = n_sweeps; % Количество свипов
hd.si = 1e6/Freq;
hd.nADCNumChannels = size(lfp,2);
hd.nOperationMode = 3;
hd.recTime = [1 size(lfp,1)];
hd.sweepLengthInPts = size(lfp,1);

recChNames = cell(1, n_channels);
for i = 1:n_channels
    recChNames{i} = ['Ch', num2str(i)];
end
hd.recChNames = recChNames;

zavp.stimCh=4;
chnlGrp = 1:n_channels;

xx=findstr(Filename, '\');

NewPath=[Filename(1:xx(end-1)), Filename(xx(end-1)+1:xx(end)-1), '_preprocessed\'];

if ~exist(NewPath)
   mkdir(NewPath)
end



save([NewPath, Filename(xx(end)+1:end)], 'hd', 'lfp', 'lfpVar', 'spks', 'zavp', 'chnlGrp')


disp(['experiment: ' num2str(exper), ', index t1: ' num2str(t1)])
end

end
