function varargout = struct2vars(data)
% STRUCT2VARS - Распаковка структуры в отдельные переменные
% Использование:
%   [lfp, spks, hd, zavp, lfpVar, chnlGrp, time, stims, sweep_info, time_forward, time_back] = struct2vars(data);
%   [lfp, spks, hd, zavp, lfpVar, chnlGrp, time, stims, sweep_info, time_forward, time_back, events] = struct2vars(data);
% 
% Примечание: В MATLAB данные не копируются, используются ссылки (copy-on-write).
% Дополнительная память минимальна - только метаданные структуры.
    
    field_order = {'lfp', 'spks', 'hd', 'zavp', 'lfpVar', 'chnlGrp', 'time', 'stims', 'sweep_info', 'time_forward', 'time_back', ...
                   'events', 'event_comments', 'event_amplitudes', 'event_channels', 'event_widths', 'event_prominences', 'event_metadata'};
    
    varargout = cell(1, nargout);
    for i = 1:min(nargout, length(field_order))
        field_name = field_order{i};
        if isfield(data, field_name)
            varargout{i} = data.(field_name);
        else
            varargout{i} = [];
        end
    end
end

