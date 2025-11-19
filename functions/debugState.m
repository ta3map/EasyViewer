function debugState(caller, fmt, varargin)
    timestamp = datestr(now, 'HH:MM:SS.FFF');
    try
        message = sprintf(fmt, varargin{:});
    catch
        message = fmt;
    end
    fprintf('[%s][%s] %s\n', timestamp, caller, message);
end

