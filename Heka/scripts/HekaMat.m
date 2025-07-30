

function [data, Freq]=HekaMat(filename)


% usage Example
% [data, Freq]=HekaMat('\\ED02\FlizaAlina\cell-attach\bridge\07.09\Cell4\sin37.mat');

load(filename);

aa=who;

ThirdValue=[];
FourthValue=[];
cn=0;
FilesOfInterest=[];
for m=1:size(aa,1)
    bz=aa{m};
    if numel(bz)>=5&&isequal(bz(1:5), 'Trace')
        cn=cn+1;
        h1=findstr(bz, '_');
        ValueT=str2num(bz(h1(3)+1:h1(4)-1));
        ThirdValue(cn)=ValueT;
        ValueY=str2num(bz(h1(4)+1:end));
        FourthValue(cn)=ValueY;
        FilesOfInterest(cn)=m;
    end
end

% numberOfSweeps=max(ThirdValue);
% numberOfChannels=max(FourthValue);

data=[];
for listOfTraces=1:numel(FilesOfInterest)
    bz=aa{FilesOfInterest(listOfTraces)};
    h1=findstr(bz, '_');
    SweepNumber=str2num(bz(h1(3)+1:h1(4)-1));
    ChannelNumber=str2num(bz(h1(4)+1:end));
    data(:,ChannelNumber, SweepNumber)=eval([bz, '(:,2)']);
end

Freq=round(1/median(diff(eval([bz, '(:,1)']))));


end
