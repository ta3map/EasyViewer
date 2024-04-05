function [csd, newtrange, newchrange] = CurSrcDnsAz(eeg, varargin)
    
    method = 1;
    % Input parameters parsing and setting defaults
    [trange, ~, chnum, chanrange, samplerate, step, ~] = ...
        DefaultArgsAz(varargin, {[], 'c', size(eeg,2), 1:size(eeg,2), 1e3, 1, []});
    
    % Ensure eeg is channels x time
    if size(eeg,1) < size(eeg,2)
        eeg = eeg';
    end

    % For 3D data, take the squeeze of the second dimension
    if length(size(eeg)) == 3
        eeg = sq(eeg); 
    end 

    % Set time range if not specified
    if isempty(trange)
        trange = (1:size(eeg,1)) / (samplerate/1000);
    end
    
    % Subtract the mean from each channel
    csd = eeg - repmat(mean(eeg), size(eeg,1), 1);

    % Calculate CSD
    if method == 1
        csd = -diff(csd, 2, 2);
    else
        ch = step+1 : chnum-step;
        csd = (csd(:,ch+step) - 2*csd(:,ch) + csd(:,ch-step)) / step^2;
        csd = -csd;  % Negate to conform to convention
    end

    % Interpolate the CSD for better visualization
    csd = interp2(csd, 3, 'linear');
    newtrange = linspace(trange(1), trange(end), size(csd,1))';
    newchrange = linspace(chanrange(2), chanrange(end), size(csd,2))';
end

function varargout = DefaultArgsAz(Args, DefArgs)
% auxillary function to replace argument check in the beginning and def. args assigment
% sets the absent or empty values of the Args (cell array, usually varargin)
% to their default values from the cell array DefArgs. 
% Output should contain the actuall names of arguments that you use in the function

% e.g. : in function MyFunction(somearguments , varargin)
% calling [SampleRate, BinSize] = DefaultArgs(varargin, {20000, 20});
% will assign the defualt values to SampleRate and BinSize arguments if they
% are empty or absent in the varargin cell list 
% (not passed to a function or passed empty)
if isempty(Args)
    Args ={[]};
end

% if iscell(Args) & isstr(Args{1}) & length(Args)==1
%     Args = Args{1};
% end
    
if ~iscell(DefArgs)
    DefArgs = {DefArgs};
end
nDefArgs = length(DefArgs);
nInArgs = length(Args);
%out = cell(nDefArgs,1);
if (nargout~=nDefArgs)
    error('number of defaults is different from assigned');
    %keyboard
end
for i=1:nDefArgs
    
    if (i>nInArgs | isempty(Args{i}))
        varargout(i) = {DefArgs{i}};
    else 
        varargout(i) = {Args{i}};
    end
end

end