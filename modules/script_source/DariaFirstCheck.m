


clear;

[~,~,raw]=xlsread('G:\остальное\DashaRnf\photothr_dat.xlsx');



t1=17;

load([raw{t1,5}, '.mat'])

%
% clf
% plot(DcConverter(lfp(:, [1,33]), 1e3))


loadCadr=4;

IosPath=raw{t1,6};
[data, t] = readIOS(IosPath, 'startframe', 1, 'eachframe', loadCadr, 'Format', 'Lin');

eachCadr=round(mean(diff(t)));

data(:,:,3)=[];



Freq=1e6/hd.si;
Cf=Freq/1e3;


Lfp=DcConverter(lfp, 1e3);


% clear spk;
% for ch=[1:16, 33:48]
%     ch
%     [data]=ZavNrlynx2(raw{t1,1}, [],[ch], [], []);
%     Filt=AprWaveFilter(data, Freq, 'bandpass', [250 4000]);
%     spk(ch).s=LocalMinima(Filt, Cf, -4*minStd(Filt(1:300*Freq), 100*Freq));
% end


% load(['G:\HippoECL5\DataFastTemp\Fluor\t', num2str(t1), '_1\SuaData.mat'])
% 
% clear spk;
% for ch=1:32
%     spk(ch).s=[];
% end
% 
% for ch=1:16
%     spk(ch).s=Spk(ch).s;
% end
% 
% load(['G:\HippoECL5\DataFastTemp\Fluor\t', num2str(t1), '_33\SuaData.mat'])
% 
% for ch=17:32
%     spk(ch).s=Spk(ch-16).s;
% end


% Lfp=DcConverter(lfp, 1e3);


sHigh=AprWaveFilter(lfp, 1e3, 'high', 0.1);

%%


clear row;


load('\\10.167.11.31\zavnet1\et1Inj.mat')
ecogGroup=9;

for p=1:64
    if ~isnan(et1Inj(ecogGroup).ecogCh(p,2))
        row(et1Inj(ecogGroup).ecogCh(p,2), et1Inj(ecogGroup).ecogCh(p,3))=et1Inj(ecogGroup).ecogCh(p,1);
    end
end


%


ChanEcogInfo=et1Inj(ecogGroup).ecogCh;

ChanEcogInfo(:,1)=ChanEcogInfo(:,1);

ChanEcogInfo=ChanEcogInfo(~isnan(ChanEcogInfo(:,2)),:);


%%


clf
s1=AzaFilter2(Lfp(:,3), 1e3, 'high', 0.01);
plot(s1)
h11=LocalMinima(s1, 5e4, -2e4);
h11(1)=[];
Lines(h11);


%%

%

clf

SdNum=1;

% OnsSaved=str2num(raw{t1,9});

OnsSaved=h11(SdNum);
clear TotalData;


leftCadr=60;
rightCadr=80;

[~,ind]=min(abs(OnsSaved/1e3-t));
diapazonCadres=ind-round(leftCadr/eachCadr):ind+round(rightCadr/eachCadr);

diapazonTimes=t(ind-round(leftCadr/eachCadr):ind+round(rightCadr/eachCadr));


% lfp1Handle=subplot('Position', [0.02 0.02 0.3 0.9]);

lfp1Handle=subplot('Position', [0.52 0.45 0.45 0.24]);


LeftProbeGroup=33:48;


RightProbeGroup=1:16;



AzaManyCh(Lfp(round(diapazonTimes(1)*1e3):round(diapazonTimes(end)*1e3),LeftProbeGroup), [], -1, [], -1e4);
Lines(0);

hand9=get(lfp1Handle, 'Children');

% lfp2Handle=subplot('Position', [0.35 0.02 0.3 0.9]);

lfp2Handle=subplot('Position', [0.52 0.45+0.26 0.45 0.24]);

AzaManyCh(Lfp(round(diapazonTimes(1)*1e3):round(diapazonTimes(end)*1e3),RightProbeGroup), [], -1, [], -1e4);
Lines(0);

hand10=get(lfp2Handle, 'Children');


CsdCadr=ind;

baseframe = mean(double(data(:,:,CsdCadr-20:CsdCadr-5)),3);
baseframe(baseframe==0)=mean(mean(baseframe));

clear data2;
cn=0;
for sw = diapazonCadres
    cn=cn+1;
    frame = double(data(:,:,sw));
    data2(:,:,cn) = 100*(frame - baseframe)./baseframe;
end

NoizeMc=mean(reshape(data2(:,:,:), [size(data2,1)*size(data2,2), size(data2,3)]),1);

for q=1:size(data2,3)
    data2(:,:,q)=data2(:,:,q)-NoizeMc(q); %
end

data2 = imgaussfilt3(data2, [5,5,3]);

dframes2 = diff(data2, 1, 3);

% videoHandle=subplot('Position', [0.67 0.35 0.31 0.42]);

videoHandle=subplot('Position', [0.02 0.45 0.45 0.5]);

EcogCoordinates=et1Inj(ecogGroup).ecogCh(:,4:5);

ProbeCoordinates=[et1Inj(ecogGroup).prb1XY(1,:); et1Inj(ecogGroup).prb2XY(1,:)];

imagesc(dframes2(:,:,1))
hold on


% plot((EcogCoordinates(:,2)), size(data,1)-(EcogCoordinates(:,1)), 'ow', 'MarkerFaceColor', 'k', 'MarkerSize', 5)
% hold on
% plot(ProbeCoordinates(:,2), size(data,1)-ProbeCoordinates(:,1), 'ok', 'MarkerFaceColor', 'w',  'MarkerSize', 9)

% view(90,90)


% set(gca, 'YDir', 'reverse')

%
caxis([-0.5 0.5])

colormap(jet);

hand17=get(videoHandle, 'Children');



PopSpikeFreqHandle=subplot('Position', [0.52 0.02 0.45 0.4]);


% plot(sHighMean(round(diapazonTimes(1)*1e3):round(diapazonTimes(end)*1e3)))

hold on

% plot(lfp(round(diapazonTimes(1)*1e3):round(diapazonTimes(end)*1e3),130), 'r')


% plot(outP(round(diapazonTimes(1)*1e3):round(diapazonTimes(end)*1e3))*500+3000, 'k')

% plot(lfp(round(diapazonTimes(1)*1e3):round(diapazonTimes(end)*1e3), 132)-5000)


plot(lfp(round(diapazonTimes(1)*1e3):round(diapazonTimes(end)*1e3), 111))



Lines(1);


xlim([0 round(diapazonTimes(end)*1e3)-round(diapazonTimes(1)*1e3)])

handFreq=get(PopSpikeFreqHandle, 'Children');



for m=1:numel(diapazonCadres)-1
    
    set(hand9(1), 'XData', [diapazonTimes(m)*1e3-round(diapazonTimes(1)*1e3) diapazonTimes(m)*1e3-round(diapazonTimes(1)*1e3)])
    set(hand10(1), 'XData', [diapazonTimes(m)*1e3-round(diapazonTimes(1)*1e3) diapazonTimes(m)*1e3-round(diapazonTimes(1)*1e3)])
     set(handFreq(1), 'XData', [diapazonTimes(m)*1e3-round(diapazonTimes(1)*1e3) diapazonTimes(m)*1e3-round(diapazonTimes(1)*1e3)])
    set(hand17(end), 'CData', dframes2(:,:,m))
    pause(0.2);
    
end

%

clear OnsPos LfpMap MeasurePoPSpikes AmplSD AmplSDMap;



leftBord=5e4;
rightBord=8e4;

for qj=1:size(ChanEcogInfo,1)
    
    
    s1=Lfp(OnsSaved-leftBord:OnsSaved+rightBord,ChanEcogInfo(qj,1));
%     s1Pop=sHigh(OnsSaved-leftBord:OnsSaved+rightBord,ChanEcogInfo(qj,1));
    s1=AzaFilter2(s1, 1e3,'bandpass', [0.01 5]);
    s2=smooth(diff(AzaFilter2(s1, 1e3, 'low', 0.1)),1e3);
    
    %     plot(s2)
    
    
    s2(1:1e3)=NaN;
    s2(end-1e3:end)=NaN;
    [amplSlope, ind]=min(s2);
    
    
    
    s1tt=Lfp(OnsSaved-leftBord:OnsSaved+rightBord,ChanEcogInfo(qj,1));
    s1tt=AprWaveFilter(s1tt, 1e3,'low', [1]);
    s1tt=s1tt-medfilt1(s1tt,8e4);
    
    s1tt(1:1e3)=0;
    s1tt(end-1e3:end)=0;
    
    if amplSlope<-0.1
        OnsPos(ChanEcogInfo(qj,3),ChanEcogInfo(qj,2))=ind;

        LfpMap(:,ChanEcogInfo(qj,3),ChanEcogInfo(qj,2))=s1(1:10:end);
%         MeasurePoPSpikes(:,ChanEcogInfo(qj,3),ChanEcogInfo(qj,2))=s1Pop;
        AmplSDMap(ChanEcogInfo(qj,3),ChanEcogInfo(qj,2))=abs(min(s1(1:10:end)));
        
        AmplSD(ChanEcogInfo(qj,3),ChanEcogInfo(qj,2))=min(s1tt);
        
    end
    
end


subplot('Position', [0.02 0.02 0.45 0.4]);

imagesc(OnsPos');

hold on

Cfn=min(min(min(LfpMap)))*2;
for c1=1:6
    for c2=1:10
        %         plot([[0.8/size(LfpMap,1):0.8/size(LfpMap,1):0.8]+c2-0.4], flipud([c1-LfpMap(:, c2,c1)/Cfn]), 'k')
        plot([[0.8/size(LfpMap,1):0.8/size(LfpMap,1):0.8]+c2-0.4], [LfpMap(:, c2,c1)/Cfn+c1], 'k')
    end
end
hold on
% 
% plot(Probe1(1)+0.3, Probe1(2)+0.3, 'ok', 'MarkerSize', 7, 'MarkerFaceColor', 'w')
% 
% plot(Probe2(1)+0.3, Probe2(2)+0.3, 'ok', 'MarkerSize', 7, 'MarkerFaceColor', 'w')

% subplot('Position', [0.75 0.02 0.22 0.35]);
% imagesc(AmplSDMap');

%%

time1=[0.75e5    2.49e5];

time2=[1.9031e6    2.0066e6];

time3=[4.0768e6   4.1871e6];





clear Delta1 Alfa1;
for qj=1:size(ChanEcogInfo,1)
    
    
    sL=lfp(time1(1):time1(2),ChanEcogInfo(qj,1));

    sL=AzaFilter2(sL, 1e3,'high', [0.5]);
    
%     OnsPos(ChanEcogInfo(qj,3),ChanEcogInfo(qj,2))=ind;


prm=struct('tapers',[3 5],'pad',2,'Fs',1e3,'fpass',[0.5 4],'err',[2 0.05],'trialave',0);

[S,f]=mtspectrumc(sL, prm);

Delta1(ChanEcogInfo(qj,3),ChanEcogInfo(qj,2))=mean(S);


prm=struct('tapers',[3 5],'pad',2,'Fs',1e3,'fpass',[8 14],'err',[2 0.05],'trialave',0);

[S,f]=mtspectrumc(sL, prm);



Alfa1(ChanEcogInfo(qj,3),ChanEcogInfo(qj,2))=mean(S);

end



clear Delta2 Alfa2;
for qj=1:size(ChanEcogInfo,1)
    
    
    sL=lfp(time2(1):time2(2),ChanEcogInfo(qj,1));

    sL=AzaFilter2(sL, 1e3,'high', [0.5]);
    
%     OnsPos(ChanEcogInfo(qj,3),ChanEcogInfo(qj,2))=ind;


prm=struct('tapers',[3 5],'pad',2,'Fs',1e3,'fpass',[0.5 4],'err',[2 0.05],'trialave',0);
[S,f]=mtspectrumc(sL, prm);

Delta2(ChanEcogInfo(qj,3),ChanEcogInfo(qj,2))=mean(S);


prm=struct('tapers',[3 5],'pad',2,'Fs',1e3,'fpass',[8 14],'err',[2 0.05],'trialave',0);

[S,f]=mtspectrumc(sL, prm);


Alfa2(ChanEcogInfo(qj,3),ChanEcogInfo(qj,2))=mean(S);

end





clear Delta3 Alfa3;
for qj=1:size(ChanEcogInfo,1)
    
    
    sL=lfp(time3(1):time3(2),ChanEcogInfo(qj,1));

    sL=AzaFilter2(sL, 1e3,'high', [0.5]);
    
%     OnsPos(ChanEcogInfo(qj,3),ChanEcogInfo(qj,2))=ind;


prm=struct('tapers',[3 5],'pad',2,'Fs',1e3,'fpass',[0.5 4],'err',[2 0.05],'trialave',0);
[S,f]=mtspectrumc(sL, prm);

Delta3(ChanEcogInfo(qj,3),ChanEcogInfo(qj,2))=mean(S);



prm=struct('tapers',[3 5],'pad',2,'Fs',1e3,'fpass',[8 14],'err',[2 0.05],'trialave',0);

[S,f]=mtspectrumc(sL, prm);


Alfa3(ChanEcogInfo(qj,3),ChanEcogInfo(qj,2))=mean(S);


end

%%

 clf
 
 subplot(131)
imagesc(Delta1')

caxis([0 1e5])

 subplot(132)
imagesc(Delta2'./Delta1')

caxis([0 0.3])

 subplot(133)
imagesc(Delta3'./Delta1')

caxis([0 0.3])



%%


 clf
 
 subplot(131)
imagesc(Alfa1')

% caxis([0 1e5])

 subplot(132)
imagesc(Alfa2'./Alfa1')

caxis([0 0.3])

 subplot(133)
imagesc(Alfa3'./Alfa1')

caxis([0 0.3])


%%


 clf
 
 subplot(131)
imagesc([Alfa1/Delta1]')

caxis([0 0.1])

 subplot(132)
imagesc([Alfa2/Delta2]')

caxis([0 0.1])

% caxis([0 0.3])

 subplot(133)
imagesc([Alfa3/Delta3]')

caxis([0 0.1])

% caxis([0 0.3])





%% ne nado


clear AmplPoP;
for sk=1:60

sig=MeasurePoPSpikes(:, ChanEcogInfo(sk,3),ChanEcogInfo(sk,2));
hLocal=htemp(htemp>=OnsSaved-leftBord & htemp<= OnsSaved-20e3)-(OnsSaved-leftBord)+1;


% clf
% plot(sig(1:leftBord-20e3))

sng=sig(1:leftBord-20e3);

clear Ampl;
for n=2:numel(hLocal)-1
    
   [Ampl(n-1)]=min( sng(hLocal(n)-10:hLocal(n)+50));
   
end

 AmplPoP(ChanEcogInfo(sk,3),ChanEcogInfo(sk,2))=median(Ampl);
 
 
 
%     AmplSD(ChanEcogInfo(sk,3),ChanEcogInfo(sk,2))=min(s1);
    

   
end


%

clf
subplot(221)
imagesc(AmplPoP')
caxis([-1e4 1e4])


subplot(222)
imagesc(AmplSD')
caxis([-2e4 -5e3])

% Lines(hLocal, [500 1e3]);


subplot(223)

plot(AmplSD(:,3))
hold on
plot(AmplPoP(:,3))



subplot(224)

plot(abs(AmplSD(:,3)), abs(AmplPoP(:,3)), 'ok')


% 
% 
% 




%%

ChannelSelect=33;

SigLoc=sHigh(OnsSaved-10e4:OnsSaved+5e4,ChannelSelect);



prm=struct('tapers',[0.5 2 0],'pad',2,'Fs',1e3,'fpass',[0.5 45],'err',[2 0.05],'trialave',0);

% [S,time,f]=mtspecgramc(AprWaveFilter(SigLoc, 1e3, 'high', 0.1),[0.5 0.1],prm);
[S,time,f]=mtspecgramc(SigLoc,[2 0.5],prm);

clf
subplot(211)

plot(SigLoc)
xlim([0 numel(SigLoc)])

% hold on
%
% plot(Lfp(OnsSaved-10e4:OnsSaved+5e4,129)*100)

subplot(212)
imagesc(time,f,S')
set(gca, 'YDir', 'normal')

caxis([0 10000])


%%



clf
CurSrcDns(sHigh(OnsSaved-4e4:OnsSaved-2e4,row(6,:)));
AzaManyCh(sHigh(OnsSaved-4e4:OnsSaved-2e4,row(6,:)));



%%


clf
CurSrcDns(sHigh(OnsSaved-10e4:OnsSaved+2e4,1:16));
AzaManyCh(sHigh(OnsSaved-10e4:OnsSaved-2e4,1:16));
caxis([-100 100])



%%


clf
CurSrcDns(sHigh(OnsSaved-10e4:OnsSaved-2e4,33:48));
AzaManyCh(sHigh(OnsSaved-10e4:OnsSaved-2e4,33:48));
caxis([-100 100])



%%



ChannelSelect=33;

SigLoc=sHigh(OnsSaved-4e4:OnsSaved+1e6,ChannelSelect);


sH=AzaFilter2(SigLoc, 1e3, 'high', ChannelSelect);


clf
plot(sH)

htemp=LocalMinima(diff(SigLoc), 40, -100);

h=htemp+OnsSaved-4e4-1;

Lines(htemp, [-1e3 1e3]);

%%

Probe1=[4.5,4.5];

Probe2=[8.5,4.5];



%%


% 1) онсеты добавить
%     2) юнитсы

sw=34;


tt=h(sw);


% for tt=1042860
% for tt=881039

clear Aver Aver1 AverCom PopOnsMap;
cnt=0;
for c1=1:size(row,1)
    for c2=1:size(row,2)
        cnt=cnt+1;
        
    s1Loc =AzaFilter2(sHigh(tt-100:tt+200,row(c1, c2)), 1e3, 'high', 2);
       
       [~, idxv]=min(s1Loc(60:150));
       
           s1LocDiff =smooth(diff(AzaFilter2(sHigh(tt-100:tt+200,row(c1, c2)), 1e3, 'high', 2)), 30);

   [VlMax, idxv1]=min(s1LocDiff(60:150));
       
   if VlMax<-30
       PopOnsMap(c1,c2)=idxv1;
   else
       PopOnsMap(c1,c2)=NaN;
   end
   
       
%        idL=tt-100+95+idxv-1-1;

 idL=tt-100+60+idxv-1-1;
       
        Aver(:,cnt)=sHigh(idL-100:idL+100,row(c1, c2));
        
        Aver1(:,cnt)=sHigh(tt-100:tt+100,row(c1, c2));
        
        AverCom(:,cnt)=sHigh(idL-100:idL+100,row(c1, c2))-mean(sHigh(idL-100:idL+100,row),2);
        
    end
end



cnt=0;
clear Matr Ang;
for c1=1:size(row,1)
    for c2=1:size(row,2)
        cnt=cnt+1;
        Matr(c1,c2)=  Aver(101, cnt);
        
     
%         Matr(c1,c2)=  Aver(101, cnt);
        
%          if tt>OnsSaved-1e4+OnsPos(c2,c1)-1    
%              Matr(c1,c2)=10000;
%          end
        
        
        MatrCom(c1,c2)=  AverCom(101, cnt);
        Hlb=  hilbert(Aver(:,cnt));
        angles = angle(Hlb);
        Ang(c1,c2)=angles(101);
    end
end



clf
% subplot(231)
subplot('Position', [0.02 0.45 0.45 0.5]);

imagesc(Matr)
hold on

plot(Probe1(1)+0.3, Probe1(2)+0.3, 'ok', 'MarkerSize', 7, 'MarkerFaceColor', 'r')

plot(Probe2(1)+0.3, Probe2(2)+0.3, 'ok', 'MarkerSize', 7, 'MarkerFaceColor', 'r')
% 
% for c1=1:size(row,1)
%     for c2=1:size(row,2)
%         if tt>OnsSaved-1e4+OnsPos(c2,c1)-1
%             rectangle('Position', [c2-0.5 c1-0.5 1 1], 'EdgeColor', 'r', 'LineWidth', 2)
%         end
%     end
% end

caxis([-1e4 1e4])

% 
%     jet1=jet(1e3);
%     jet1(end,:)=[1 1 1];
%     
    colormap(jet);
        
    freezeColors;

% caxis([-0.5e4 0.5e4]) 

% caxis([-3e3 3e3])



Cfnt=-max(max(max(abs(Aver1))))*2;
%    Cfnt=-2e4;
%    Cfnt=-2e3;
cnt=0;
for c1=1:size(row,1)
    for c2=1:size(row,2)
        cnt=cnt+1;
        
        hold on
        
        
        plot([1/size(Aver,1):1/size(Aver,1):size(Aver,1)/size(Aver,1)]/1.2+c2-0.5,   [Aver1(:,cnt)-mean(Aver1(1:10,cnt))]/Cfnt+c1+0.2, 'k', 'LineWidth', 1)
        
    end
end
xxxx=[[1/size(Aver,1):1/size(Aver,1):size(Aver,1)/size(Aver,1)]/1.2+c2-0.5];

Lines(xxxx(101), [5.5 6.5]);


xlim([0 11])
ylim([0 7])

title(tt);


subplot('Position', [0.5 0.45 0.45 0.5]);


imagesc(PopOnsMap-nanmedian(nanmedian(PopOnsMap)))
colormap(jet);
caxis([-10 10])
% subplot(232)
% imagesc(Ang)
% caxis([-pi pi])


% [Gmag,Gdir] = imgradient(Matr,"prewitt");
%
% imagesc(Gdir)
%
% caxis([-180 180])


% subplot(234)
subplot('Position', [0.01 0.01 0.32 0.4]);

CurSrcDns(sHigh(tt-100:tt+100, 33:48));
AzaManyCh(sHigh(tt-100:tt+100, 33:48));


for ch=17:32
    nspk=[spk(ch).s(spk(ch).s>=Cf*(tt-100)&spk(ch).s<=Cf*(tt+100))]-Cf*(tt-100);
    if ~isempty(nspk)
        Lines(nspk/Cf, [ch-16-0.2 ch-16-0.5]);
    end
end

% for ch=1:16
%     nspk=[spks(ch).tStamp(spks(ch).tStamp>=1*(tt-100)&spks(ch).tStamp<=1*(tt+100))]-1*(tt-100);
%     if ~isempty(nspk)
%         Lines(nspk, [ch-0.2 ch-0.5]);
%     end
% end


Lines(101);
ylim([-1 17])

% subplot(235)
subplot('Position', [0.34 0.01 0.32 0.4]);

% imagesc(MatrCom)
% caxis([-0.2e4 0.2e4])
%
%
%    Cfnt=-max(max(max(abs(AverCom))))*2;
%
% cnt=0;
% for c1=1:size(row,1)
%     for c2=1:size(row,2)
%         cnt=cnt+1;
%
%         hold on
%
%
%         plot([1/size(Aver,1):1/size(Aver,1):size(Aver,1)/size(Aver,1)]/1.2+c2-0.5,   [AverCom(:,cnt)-mean(AverCom(1:10,cnt))]/Cfnt+c1+0.2, 'k', 'LineWidth', 1)
%
%     end
% end

CurSrcDns(sHigh(tt-100:tt+100, 1:16));
AzaManyCh(sHigh(tt-100:tt+100, 1:16));
ylim([-1 17])
Lines(101);

for ch=1:16
    nspk=[spk(ch).s(spk(ch).s>=Cf*(tt-100)&spk(ch).s<=Cf*(tt+100))]-Cf*(tt-100);
    if ~isempty(nspk)
        Lines(nspk/Cf, [ch-0.2 ch-0.5]);
    end
end

% for ch=1:16
%     nspk=[spks(ch).tStamp(spks(ch).tStamp>=1*(tt-100)&spks(ch).tStamp<=1*(tt+100))]-1*(tt-100);
%     if ~isempty(nspk)
%         Lines(nspk, [ch-0.2 ch-0.5]);
%     end
% end




% subplot(337)
%
%
% avs=AzaManyCh(lfp(tt-2000:tt+2000, 33:48), [], -0.25);
%
%
% subplot(338)
%
% AzaManyCh(lfp(tt-2000:tt+2000, 1:16), [], -0.25, [],avs);

% pause(0.1);



% subplot(233)

subplot('Position', [0.68 0.01 0.32 0.4]);

% 
plot(Lfp(:, [33, 1]))

xlim([OnsSaved-5e4 OnsSaved+15e4])

Lines(tt);



% Arise=interp2(OnsPos-OnsPos(1),3, 'spline');



%     imagesc([OnsPos-OnsPos(1)]');
    
    
    

% for c1=1:6
%     for c2=1:10
%
%         if tt> OnsSaved-1e4
%             LfpMap(:, c2,c1)
%                OnsSaved-1e4
%
%     end
% end


%%


timemap = tm(idx);

timemap(max(videoframes2,[], 3)<0.3)=NaN;

timemap = imgaussfilt(timemap, 10);

timemap = timemap - prctile(timemap(:), 1);

clf
contour(timemap, [0:3:numel(tm)], 'LineWidth',2, 'Showtext', 'off')
colormap(jet);
set(gca, 'YDir', 'reverse')




%%

% Vq = interp2(1:6,1:10,OnsPos-OnsPos(1),1:0.1:6,1:0.1:10);



Arise=interp2(OnsPos-OnsPos(1),5, 'spline');


clf
imagesc(Arise');


%%

clf
contour([OnsPos-OnsPos(1)]')
colormap(jet);
set(gca, 'YDir', 'reverse')


%%


clf
imagesc(OnsPos');

hold on

Cfn=min(min(min(LfpMap)))*2;
for c1=1:6
    for c2=1:10
        %         plot([[0.8/size(LfpMap,1):0.8/size(LfpMap,1):0.8]+c2-0.4], flipud([c1-LfpMap(:, c2,c1)/Cfn]), 'k')
        plot([[0.8/size(LfpMap,1):0.8/size(LfpMap,1):0.8]+c2-0.4], [LfpMap(:, c2,c1)/Cfn+c1], 'k')
    end
end

% subplot(236)
% 
% plot(Lfp(:, ChannelSelect))
% 
% xlim([OnsSaved-5e4 OnsSaved+20e4])
% 
% Lines(tt);



%%





% for tt=OnsSaved-2e4:10:OnsSaved+1e4

for tt=1100458
    
    % for tt=1042860
    % for tt=881039
    
    clear Aver;
    cnt=0;
    for c1=1:size(row,1)
        for c2=1:size(row,2)
            cnt=cnt+1;
            
            %         Aver(:,cnt)=AzaFilter2(s2(tt-100:tt+100,row(c1, c2)),1e3, 'high', 0.1);
            Aver(:,cnt)=sHigh(tt-100:tt+100,row(c1, c2));
        end
    end
    
    
    
    cnt=0;
    clear Matr Ang;
    for c1=1:size(row,1)
        for c2=1:size(row,2)
            cnt=cnt+1;
            Matr(c1,c2)=  Aver(101, cnt);
            Hlb=  hilbert(Aver(:,cnt));
            angles = angle(Hlb);
            Ang(c1,c2)=angles(101);
        end
    end
    
    clf
    subplot(321)
    imagesc(Matr)
    caxis([-0.5e4 0.5e4])
    
    % caxis([-3e3 3e3])
    
    
    
    %    Cfnt=-max(max(max(abs(Aver))))*2;
    Cfnt=-2e4;
    %    Cfnt=-2e3;
    cnt=0;
    for c1=1:size(row,1)
        for c2=1:size(row,2)
            cnt=cnt+1;
            
            hold on
            
            
            plot([1/size(Aver,1):1/size(Aver,1):size(Aver,1)/size(Aver,1)]/1.2+c2-0.5,   [Aver(:,cnt)-mean(Aver(1:10,cnt))]/Cfnt+c1+0.2, 'k', 'LineWidth', 1)
            
        end
    end
    xxxx=[[1/size(Aver,1):1/size(Aver,1):size(Aver,1)/size(Aver,1)]/1.2+c2-0.5];
    
    Lines(xxxx(101), [5.5 6.5]);
    
    
    xlim([0 11])
    ylim([0 7])
    
    title(tt);
    
    
    subplot(322)
    
    imagesc(Ang)
    caxis([-pi pi])
    
    
    % [Gmag,Gdir] = imgradient(Matr,"prewitt");
    %
    % imagesc(Gdir)
    %
    % caxis([-180 180])
    
    
    subplot(323)
    
    
    CurSrcDns(sHigh(tt-100:tt+100, 33:48));
    AzaManyCh(sHigh(tt-100:tt+100, 33:48));
    Lines(101);
    ylim([-1 17])
    
    subplot(324)
    
    CurSrcDns(sHigh(tt-100:tt+100, 1:16));
    AzaManyCh(sHigh(tt-100:tt+100, 1:16));
    ylim([-1 17])
    Lines(101);
    
    
    
    subplot(325)
    
    
    
    avs=AzaManyCh(lfp(tt-2000:tt+2000, 33:48), [], -0.25);
    
    
    
    
    subplot(326)
    
    AzaManyCh(lfp(tt-2000:tt+2000, 1:16), [], -0.25, [],avs);
    
    pause(0.1);
    
end






%%

clf
imagesc(Matr)

hold on

Cfnt=-1e4;
%    Cfnt=-2e3;
cnt=0;
for c1=1:size(row,1)
    for c2=1:size(row,2)
        cnt=cnt+1;
        
        hold on
        
        plot([1/size(Aver,1):1/size(Aver,1):size(Aver,1)/size(Aver,1)]/1.2+c2-0.5,   [Aver(:,cnt)-mean(Aver(1:10,cnt))]/Cfnt+c1+0.2, 'k', 'LineWidth', 1)
        
    end
end



%%



for tt=1033393
    
    clear Aver;
    cnt=0;
    for c1=1:size(row,1)
        for c2=1:size(row,2)
            cnt=cnt+1;
            
            %         Aver(:,cnt)=AzaFilter2(s2(tt-100:tt+100,row(c1, c2)),1e3, 'high', 0.1);
            Aver(:,cnt)=s2(tt-100:tt+100,row(c1, c2));
        end
    end
    
    
    
    cnt=0;
    clear Matr Ang;
    for c1=1:size(row,1)
        for c2=1:size(row,2)
            cnt=cnt+1;
            Matr(c1,c2)=  Aver(101, cnt);
            Hlb=  hilbert(Aver(:,cnt));
            angles = angle(Hlb);
            Ang(c1,c2)=angles(101);
        end
    end
end

clear MatrNew;
for c1=2:size(row,1)-1
    for c2=2:size(row,2)-1
        
        
        sumAll=[];
        
        try
            sumAll=[sumAll, Matr(c1-1,c2)];
        end
        
        try
            sumAll=[sumAll, Matr(c1+1,c2)];
        end
        
        try
            sumAll=[sumAll, Matr(c1,c2-1)];
        end
        
        try
            sumAll=[sumAll, Matr(c1,c2+1)];
        end
        
        
        
        try
            sumAll=[sumAll, Matr(c1-1,c2-1)];
        end
        
        try
            sumAll=[sumAll, Matr(c1-1,c2+1)];
        end
        
        try
            sumAll=[sumAll, Matr(c1+1,c2-1)];
        end
        
        try
            sumAll=[sumAll, Matr(c1+1,c2+1)];
        end
        
        
        
        MatrNew(c1,c2)=  Matr(c1,c2)*numel(sumAll)-sum(sumAll);
        
        
        
    end
end


clf

subplot(121)
imagesc(Matr)
caxis([-1e3 1e3])

hold on

Cfnt=-1e4;
%    Cfnt=-2e3;
cnt=0;
for c1=1:size(row,1)
    for c2=1:size(row,2)
        cnt=cnt+1;
        
        hold on
        
        plot([1/size(Aver,1):1/size(Aver,1):size(Aver,1)/size(Aver,1)]/1.2+c2-0.5,   [Aver(:,cnt)-mean(Aver(1:10,cnt))]/Cfnt+c1+0.2, 'k', 'LineWidth', 1)
        
    end
end



subplot(122)

CSD = icsd2d(Matr, 1);

imagesc(CSD);
caxis([-1e3 1e3])

% end

%%





%%

cnt=0;
clear Matr;
for c1=1:size(row,1)
    for c2=1:size(row,2)
        cnt=cnt+1;
        Matr(c1,c2)=  Aver(99, cnt);
    end
end

clf
imagesc(Matr)


cnt=0;
for c1=1:size(row,1)
    for c2=1:size(row,2)
        cnt=cnt+1;
        
        hold on
        
        plot([1/size(Aver,1):1/size(Aver,1):size(Aver,1)/size(Aver,1)]/1.2+c2-0.5,   [Aver(:,cnt)-mean(Aver(1:10,cnt))]/Cfnt+c1+0.2, 'k', 'LineWidth', 1)
        
    end
end


%%


vx = gradient(x, t);            % СXТ Velocity
vy = gradient(y, t);            % СYТ Velocity
vn = hypot(vx, vy);

%%

vx=gradient(Aver(99,:));



%%


ChanEcogInfo=et1Inj(ecogGroup).ecogCh;

ChanEcogInfo=ChanEcogInfo(~isnan(ChanEcogInfo(:,2)),:);


LastOns=OnsSaved;
clear LfpMap LfpMapFilt OnsPos;

OnsPos=-100*ones(10, 6);
AmplSDMap=-1000*ones(10, 6);
RatioMap=-0.5*ones(10, 6);
SlopeSDMap=-100*ones(10, 6);
RatioMapDelta=-0.5*ones(10, 6);
RatioMapRecov=-0.5*ones(10, 6);

InitialLeft=3.5e4;


Left=70;
Right=70;

prm=struct('tapers',[0.5 2 0],'pad',2,'Fs',1e3,'fpass',[0.5 45],'err',[2 0.05],'trialave',0);


for qj=1:size(ChanEcogInfo,1)
    
    
    
    %     for c1=1:10
    %         for c2=1:6
    
    s1=lfp(OnsSaved-InitialLeft:OnsSaved+4.5e4,ChanEcogInfo(qj,1));
    s1=AzaFilter2(s1, 1e3,'high', 0.001);
    s2=smooth(diff(AzaFilter2(s1, 1e3, 'low', 0.1)),3e3);
    
    %     plot(s1-mean(s1(1:2e4)));
    %     hold on
    %     plot(s2*1e3)
    
    s2(1:1e3)=NaN;
    s2(end-1e3:end)=NaN;
    [amplSlope, ind]=min(s2);
    if amplSlope<-0.2
        OnsPos(ChanEcogInfo(qj,3),ChanEcogInfo(qj,2))=ind;
        AmplSDMap(ChanEcogInfo(qj,3),ChanEcogInfo(qj,2))=abs(min(s1));
        
        SlopeSDMap(ChanEcogInfo(qj,3),ChanEcogInfo(qj,2))=abs(amplSlope);
        
        
        %         LastOns=ind;
        
        minPoint=OnsSelected-InitialLeft+ind-1;
        LastOns=minPoint;
        
        
        LfpMap(:, ChanEcogInfo(qj,3),ChanEcogInfo(qj,2))=AzaFilter2(lfp(minPoint-Left*1e3:100:minPoint+Right*1e3, ChanEcogInfo(qj,1)), 10, 'high', 0.001);
        
        
        %          LocSig=AzaFilter2(lfp(minPoint-Left*1e3:minPoint+Right*1e3, row(c1,c2)),1e3, 'high', 0.5);
        
        LocSig=lfp(minPoint-Left*1e3:minPoint+Right*1e3, ChanEcogInfo(qj,1));
        LocSig=LocSig-smooth(LocSig,2000);
        LocSig=AzaFilter2(LocSig,1e3, 'high', 0.5);
        
        LfpMapFilt(:, ChanEcogInfo(qj,3),ChanEcogInfo(qj,2))=LocSig(1:100:end);
        
        [S,tim,f]=mtspecgramc( LocSig-smooth(LocSig,2000),[2 0.5],prm);
        AcRatio=mean(mean(S(tim>=Left+10&tim<=Left+40,:) ,1))/mean(mean(S(tim>=Left-40&tim<=Left-10,:) ,1));
        
        AcRatioRecov=mean(mean(S(tim>=Left+120&tim<=Left+180,:) ,1))/mean(mean(S(tim>=Left-40&tim<=Left-10,:) ,1));
        
        RatioMap(ChanEcogInfo(qj,3),ChanEcogInfo(qj,2))=AcRatio;
        
        RatioMapRecov(ChanEcogInfo(qj,3),ChanEcogInfo(qj,2))=AcRatioRecov;
        
        RatioMapDelta(ChanEcogInfo(qj,3),ChanEcogInfo(qj,2))=mean(mean(S(tim>=Left-70&tim<=Left-10,:) ,1))/BaseValDelta(ChanEcogInfo(qj,3),ChanEcogInfo(qj,2));
        
    else
        OnsPos(ChanEcogInfo(qj,3),ChanEcogInfo(qj,2))=-100;
        AmplSDMap(ChanEcogInfo(qj,3),ChanEcogInfo(qj,2))=-100;
        SlopeSDMap(ChanEcogInfo(qj,3),ChanEcogInfo(qj,2))=-100;
        RatioMap(ChanEcogInfo(qj,3),ChanEcogInfo(qj,2))=-0.5;
        RatioMapDelta(ChanEcogInfo(qj,3),ChanEcogInfo(qj,2))=-0.5;
        RatioMapRecov(ChanEcogInfo(qj,3),ChanEcogInfo(qj,2))=-0.5;
        
        LfpMap(:, ChanEcogInfo(qj,3),ChanEcogInfo(qj,2))=AzaFilter2(lfp(LastOns-Left*1e3:100:LastOns+Right*1e3, ChanEcogInfo(qj,1)), 10, 'high', 0.001);
        %            LfpMapFilt(:, c1,c2)=AzaFilter2(lfp(LastOns-Left*1e3:100:LastOns+Right*1e3, row(c1,c2)), 10, 'bandpass', [0.5 45]);
        
        LocSig=lfp(LastOns-Left*1e3:LastOns+Right*1e3, ChanEcogInfo(qj,1));
        LocSig=LocSig-smooth(LocSig,2000);
        LocSig=AzaFilter2(LocSig,1e3, 'high', 0.5);
        LfpMapFilt(:, ChanEcogInfo(qj,3),ChanEcogInfo(qj,2))=LocSig(1:100:end);
        
        %         [S,tim,f]=mtspecgramc(LocSig,[2 0.5],prm);
        %            AcRatio=mean(mean(S(tim>=Right+10&tim<=Right+40,:) ,1))/mean(mean(S(tim>=Left-40&tim<=Left-10,:) ,1));
        %         RatioMap(ChanEcogInfo(qj,3),ChanEcogInfo(qj,2))=AcRatio;
        
    end
    
    
    
end

%%

jet1=jet(16000);
jet1(1,:)=[1 1 1];




% subplot(141)

%

%



subplot('Position', [0.02 0.02 0.22 0.35]);

imagesc(OnsPos')
% set(gca, 'YDir', 'normal')
% set(gca, 'XDir', 'reverse')
colormap(jet1);
hold on


Cfn=min(min(min(LfpMap)))*2;
for c1=1:6
    for c2=1:10
        %         plot([[0.8/size(LfpMap,1):0.8/size(LfpMap,1):0.8]+c2-0.4], flipud([c1-LfpMap(:, c2,c1)/Cfn]), 'k')
        plot([[0.8/size(LfpMap,1):0.8/size(LfpMap,1):0.8]+c2-0.4], [LfpMap(:, c2,c1)/Cfn+c1], 'k')
    end
end



title('SD Onsets')

subplot('Position', [0.26 0.02 0.22 0.35]);
imagesc(RatioMap')
% set(gca, 'YDir', 'normal')
% set(gca, 'XDir', 'reverse')
hold on
colormap(jet1);
caxis([0 2])





plot(et1Inj(ExpNum).prb1XY(2,2), et1Inj(ExpNum).prb1XY(2,1), ' ok', 'MarkerFaceColor', 'w', 'MarkerSize', 5)

plot(et1Inj(ExpNum).prb2XY(2,2),et1Inj(ExpNum).prb2XY(2,1), ' ok', 'MarkerFaceColor', 'w', 'MarkerSize', 5)


title('SD/PreSD')

Cf1=max(max(max(abs(LfpMapFilt))))*2;
for c1=1:6
    for c2=1:10
        %     plot([[0.8/size(LfpMapFilt,1):0.8/size(LfpMapFilt,1):0.8]+c2-0.4], [LfpMapFilt(:, c2,c1)/Cf1+c1], 'k')
        %   plot([[0.8/size(LfpMapFilt,1):0.8/size(LfpMapFilt,1):0.8]+c2-0.4], flipud([c1-LfpMapFilt(:, c2,c1)/Cf1]), 'k')
        plot([[0.8/size(LfpMapFilt,1):0.8/size(LfpMapFilt,1):0.8]+c2-0.4], [LfpMapFilt(:, c2,c1)/Cf1+c1], 'k')
    end
end

hold on


plot(et1Inj(ExpNum).prb1XY(2,2), et1Inj(ExpNum).prb1XY(2,1), ' ok', 'MarkerFaceColor', 'w', 'MarkerSize', 5)

plot(et1Inj(ExpNum).prb2XY(2,2),et1Inj(ExpNum).prb2XY(2,1), ' ok', 'MarkerFaceColor', 'w', 'MarkerSize', 5)



subplot('Position', [0.5 0.02 0.22 0.35]);
% imagesc(AmplSDMap')

imagesc(RatioMapRecov')

% set(gca, 'YDir', 'normal')
% set(gca, 'XDir', 'reverse')
hold on
title('Ampl SD')
% caxis([0 2])
caxis([0 1])

%  Cfn=min(min(min(LfpMap)))*0.5;
for c1=1:6
    for c2=1:10
        %           plot([[0.8/size(LfpMap,1):0.8/size(LfpMap,1):0.8]+c2-0.4], flipud([c1-LfpMap(:, c2,c1)/Cfn]), 'k')
        plot([[0.8/size(LfpMap,1):0.8/size(LfpMap,1):0.8]+c2-0.4], [LfpMap(:, c2,c1)/Cfn+c1], 'k')
    end
end


hold on


plot(et1Inj(ExpNum).prb1XY(2,2), et1Inj(ExpNum).prb1XY(2,1), ' ok', 'MarkerFaceColor', 'w', 'MarkerSize', 5)

plot(et1Inj(ExpNum).prb2XY(2,2),et1Inj(ExpNum).prb2XY(2,1), ' ok', 'MarkerFaceColor', 'w', 'MarkerSize', 5)

subplot('Position', [0.75 0.02 0.22 0.35]);

imagesc(RatioMapDelta')
% set(gca, 'YDir', 'normal')
% set(gca, 'XDir', 'reverse')
hold on
title('Delta Power PreSD/Control')
caxis([0 1])

plot(et1Inj(ExpNum).prb1XY(2,2), et1Inj(ExpNum).prb1XY(2,1), ' ok', 'MarkerFaceColor', 'w', 'MarkerSize', 5)

plot(et1Inj(ExpNum).prb2XY(2,2),et1Inj(ExpNum).prb2XY(2,1), ' ok', 'MarkerFaceColor', 'w', 'MarkerSize', 5)

%  Cfn=min(min(min(LfpMap)))*2;
% for c1=1:6
%     for c2=1:10
%
%     end
% end


%  end






%%


%  load Selected File


filenum=raw{group, 2};

load(et1Inj(ExpNum).files(filenum).f)


%   IosPath=et1Inj(ExpNum).files(filenum).ios;
%
%
% [data, t] = readIOS(IosPath, 'startframe', 1, 'eachframe', loadCadr, 'Format', 'Lin');




IosPath=et1Inj(ExpNum).files(filenum).ios;



lfp=double(lfp);

for ch=1:size(lfp,2)
    lfp(:,ch)=DcConverter(lfp(:,ch), 1e3);
end


%

% [~,~,raw]=xlsread('D:\GammaSD\NewProtocol.xls');

% t1=1;

loadCadr=1;


[data, t] = readIOS(IosPath, 'startframe', 1, 'eachframe', loadCadr, 'Format', 'Lin');

eachCadr=round(mean(diff(t)));

data(:,:,3)=[];


load(['D:\GammaSD\EcoGs\RNF_Zakharov/', num2str(group), '_mat'])




