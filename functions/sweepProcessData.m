function [lfp, spks, stims, lfpVar] = sweepProcessData(p, spks, n, m, lfp, Fs, zavp, lfpVar)

    % Показываем окно прогресса
    hWaitBar = waitbar(0, 'Opening...', 'Name', 'Opening file with sweeps');
        
    sps_exist = not(isempty(spks));
    
    if sps_exist
        spks_new = repmat(struct('tStamp', [], 'ampl', [], 'shape', []), n, 1);
        for ch = 1:n
            spks_new(ch).tStamp = spks(ch, 1).tStamp;
            spks_new(ch).ampl = spks(ch, 1).ampl;
            spks_new(ch).shape = spks(ch, 1).shape;
        end
    else
        spks_new = [];
    end
    
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
                spks_new(ch).tStamp = [spks_new(ch).tStamp; spks(ch, i).tStamp + spks_time_shift_ms * (i - 1)];
                spks_new(ch).ampl = [spks_new(ch).ampl; spks(ch, i).ampl];
                spks_new(ch).shape = [spks_new(ch).shape; spks(ch, i).shape];
            end
        end
        current_message = [num2str(i) ' sweep of ' num2str(p)];
        disp(current_message)
        waitbar([i/p], hWaitBar, current_message);
    end
    
    close(hWaitBar);
    
    lfp = lfp_new;
    spks = spks_new;
    clear lfp_new spks_new

    % Проверяем, есть ли стимуляции
    if isfield(zavp, 'realStim') && ~isempty([zavp.realStim(:).r])
        stims = ([zavp.realStim(:).r] * zavp.siS + ((m:m:(m * p)) - m) / Fs)';
    else
        stims = [];
    end

    lfpVar = mean(lfpVar, 2); % случай со свипами
end
