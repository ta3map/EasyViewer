function [tStamp, ampl, shape] = detectMUA(data, hd, mua_std_coef, remove_ttl_artifact)

    raw_Fs = 1/(hd.si*1e-6);
    Filt1 = AzaFilter2(data, raw_Fs, 'bandpass', [200 1000]);
    baseline = medfilt1(Filt1, 32);
    Filt1(Filt1>baseline) = baseline(Filt1>baseline);
    Filt1 = Filt1 - baseline;
    [ampl,spk,~,p] = findpeaks(-Filt1, 'MinPeakProminence', mua_std_coef*std(Filt1), 'MaxPeakWidth', 12);

    numPoints = numel(data);
    % Создание вектора времени в милисекундах
    Time = 1e3*((0:numPoints-1) / raw_Fs);
    
    
    if remove_ttl_artifact
        if isfield(hd, "inTTL_timestamps")
            ttl_window = 200;
            ttl_ticks = hd.inTTL_timestamps.t(:,1)/hd.fADCSampleInterval;
            % remove TTL artifact
            for ttl1 = ttl_ticks'
                cond = spk > ttl1 - ttl_window & spk < ttl1 + ttl_window & p < 10*std(Filt1);
                spk(cond) = [];
                p(cond) = [];
                ampl(cond) = [];
            end
        end
    end

    % вывод по ZAV формату
    tStamp = np_flatten(Time(spk))'; % сохраняем спайки канала в миллисекундном формате
    shape = [];
end