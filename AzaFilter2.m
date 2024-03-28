


function Filt=AzaFilter2(data, Freq, type, Fc)
  
% dt = 1/Freq;
% tau = 1/(2.0*pi*Fc);
% alpha = dt / (dt + 2*tau);

% 
% Filt(1)=0;
% for h=2:numel(data) 
%     Filt(h) = alpha*(data(h)+data(h-1)) + (1-2*alpha)*Filt(h-1);
% end


if isequal(type, 'bandpass')
    RC=1/(2*pi*Fc(1));
    alpha=RC/(RC+1/Freq);
    
    Filt(1)=0;
    for h=2:numel(data)
        Filt(h) = alpha*(Filt(h-1)) + alpha*(data(h)-data(h-1));
    end
    
    RC=1/(2*pi*Fc(2));
    alpha=RC/(RC+1/Freq);
    
    Filt2(1)=0;
    for h=2:numel(data)
        Filt2(h) = alpha*(Filt2(h-1)) + alpha*(Filt(h)-Filt(h-1));
    end
      Filt=Filt-Filt2;

else
 
 RC=1/(2*pi*Fc);
 alpha=RC/(RC+1/Freq);

  
Filt(1)=0;
for h=2:numel(data) 
    Filt(h) = alpha*(Filt(h-1)) + alpha*(data(h)-data(h-1));
end

if isequal(type, 'low')
    Filt=data'-Filt;
end

end


Filt=Filt';

 
end