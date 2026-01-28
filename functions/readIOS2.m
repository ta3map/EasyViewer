

function varargout = readIOS2(filename, varargin)

% Function to parse Suckov's IOS file (*.ios) 
% for compatibility with previous matlab code
%
% Usage: 
%     readIOS(filename, params) - specify output parameters 
% 
% Params:
%     format: 'LIN' or 'MAT'
%     zoom: zooms to the center of image of specified value, e.g. 4
%     resize: resizes image read after zooming, e.g. 0.25
%     xshift, yshift: integers added to shift the selection mask
%     acqlist: list of acquisitions to read, e.g. [1,2,3,5]
%     timestamp: timestamp interval to read, e.g. [0.5, 10.5]
%     startframe: frame index to start with, default 1
%     endframe:   frame index to stop at, default +Inf
%     eachframe:  frame step to read, default 1
%           
% Suchkov's binary file specification
%   uint8 - nbands - number of colors
%   uint16 - vidResX - X resolution of frame
%   uint16 - vidResY - Y resolution of frame
%   4*uint16 - ROIPosition - roi????
%   Multiple records till the EOF:
%      uint16*vidresX*vidresY*nbands - frame array
%      3*uint16 - base time in seconds, milliseconds and microseconds
%      uint16 - trigger number starting from 1
%
% Output data format
%   'LIN' linear output
%       data = [data, t, ntrig]
%       where 
%         t - linearized array of frame time
%         ntrig - linearized array of indexes of acquisition
%         data - linearized array of frames
%   'MAT' matlab-formatted output
%       data = struct with acqs

    output = NaN; % default return value in case of exception

    ip = inputParser();
    ip.CaseSensitive = false;
    ip.KeepUnmatched = true;
    ip.addRequired('filename', @(x) ischar(x) || isstring(x));
    expectedFormats = {'LIN','MAT'};
    ip.addParameter('format', 'MAT', @(x) any(validatestring(x,expectedFormats)));
    ip.addParameter('zoom', 1.0, @isnumeric);
    ip.addParameter('resize', 1.0, @isnumeric);
    ip.addParameter('xshift', 0, @isinteger);
    ip.addParameter('yshift', 0, @isinteger);
    ip.addParameter('acqList', NaN);
    ip.addParameter('eachframe', 1);
    ip.addParameter('startframe', 1);
    ip.addParameter('endframe', inf);
    ip.addParameter('timestamp', [-1, inf], @isnumeric);
    ip.addParameter('metadataOnly', false, @(x) islogical(x) || (isnumeric(x) && (x==0 || x==1)));
    ip.parse(filename, varargin{:});
    
    outMode = ip.Results.format;
    fname = ip.Results.filename;
    if isstring(fname)
        fname = char(fname);
    end
    z00m = ip.Results.zoom;
    rsize = ip.Results.resize;
    yShift = ip.Results.yshift;
    xShift = ip.Results.xshift;
    acqList = ip.Results.acqList;
    tsMin = ip.Results.timestamp(1);
    tsMax = ip.Results.timestamp(2);
    startframe = ip.Results.startframe; 
    eachframe = ip.Results.eachframe;
    endframe = ip.Results.endframe; 
    metadataOnly = ip.Results.metadataOnly;
    
    recfileID = fopen(fname, 'r');  
    try
        fseek(recfileID, 80, 0);
        nbands = fread(recfileID, 1, 'uint8=>double');
        vidRes = fread(recfileID, 2, 'uint16=>double');
        ROIPosition = fread(recfileID, 4, 'uint16=>double');
        base = fread(recfileID, 1, 'single=>double');
        signal = fread(recfileID, 1, 'single=>double');
        
        n2read = nbands*vidRes(1)*vidRes(2);
        bytesPerPixel = 2;
        recordSize = bytesPerPixel*n2read + 3*2 + 2;
        headerSize = 101;
        d = dir(fname);
        filesize = d.bytes;
        totalFrames = floor((filesize - headerSize) / recordSize);
        
        if metadataOnly
            t_all = zeros(totalFrames, 1, 'double');
            ntrig_all = zeros(totalFrames, 1, 'double');
            for k = 1:totalFrames
                fseek(recfileID, headerSize + (k-1)*recordSize + bytesPerPixel*n2read, 0);
                fulltime = fread(recfileID, 3, 'uint16=>double');
                trignum = fread(recfileID, 1, 'uint16=>double');
                if isempty(fulltime) || isempty(trignum)
                    break
                end
                t_all(k) = fulltime(1)+fulltime(2)*1e-3+fulltime(3)*1e-6;
                ntrig_all(k) = trignum;
            end
            physIdx_all = (1:totalFrames)';
            valid = ntrig_all > 0;
            t_all = t_all(valid);
            ntrig_all = ntrig_all(valid);
            physIdx_all = physIdx_all(valid);
            acqLabel = unique(ntrig_all, 'stable')';
            dt = 0;
            if length(t_all) >= 2
                dt = mean(diff(t_all));
            end
            meta = struct('totalFrames', totalFrames, 'vidRes', vidRes', ...
                't0', t_all(1), 'dt', dt, ...
                'acqFrameIdx', struct(), 'acqLabel', acqLabel);
            for a = 1:length(acqLabel)
                meta.acqFrameIdx.(getAcqName(acqLabel(a))) = physIdx_all(ntrig_all == acqLabel(a));
            end
            fclose(recfileID);
            varargout{1} = meta;
            return
        end
        
        bandOfInterest = 1;

        % preparing to parse binary data
        newvidres = vidRes/z00m;
        maskX = (int32(vidRes(2)/2)-int32(newvidres(2)/2)):...
                (int32(vidRes(2)/2)+int32(newvidres(2)/2));
        maskX = maskX + xShift;
        maskX = maskX(maskX>=1 & maskX<=vidRes(2));
        maskY = (int32(vidRes(1)/2)-int32(newvidres(1)/2)):...
                (int32(vidRes(1)/2)+int32(newvidres(1)/2));
        maskY = maskY + yShift;
        maskY = maskY(maskY>=1 & maskY<=vidRes(1));
        
        % account for zoom and resize
        newvidres = int32([length(maskY), length(maskX)]*rsize);
        
        % preallocating for speed
        bytesPerPixel = 2;
        typePerPixel = 'uint16';
        d = dir(fname);
        filesize = d.bytes;
        pixelsInFile = filesize/bytesPerPixel;       
        allFrames = floor(pixelsInFile/vidRes(1)/vidRes(2));
        nframes = floor(allFrames/eachframe);
        
        if startframe>allFrames
            warning('readIOS:OutOfBounds', 'Start frame beyond calculated frame number')
            varargout{1} = NaN;
            return
        end
        
        if any(isnan(acqList)) || (isempty(acqList))
            % Read all
            
            % check memory usage if possible, critical for big files
            if ispc
                [usrv, sysv] = memory();
                memav = sysv.PhysicalMemory.Available; % in bytes
                mem2use = nframes*newvidres(1)*newvidres(2)*bytesPerPixel;
                if mem2use>(memav*0.5)
                    error('readIOS:NotEnoughMemory', ...
                          'Available physical memory is not enough to read data. Consider zooming or rescaling');
                end
            end
            
            % Preallocate
            data = zeros(newvidres(2), newvidres(1), nframes-startframe+1, typePerPixel);
            t = zeros(nframes-startframe+1, 1, 'double');
            ntrig = zeros(nframes-startframe+1, 1, 'double');
            acqList = 1:999; % filler
        else
            warning('Cant make memory calculation, reading sequentially\nSlow dynamic allocation with overhead')
            data = zeros(newvidres(2), newvidres(1), 0, typePerPixel);
            t = zeros(0, 1, 'double');
            ntrig = zeros(0, 1, 'double');
        end            

        % start reading
        framesread = 0;
        framesstored = 0;
        
        % shift for start frame
        status = fseek(recfileID, ...
                       (bytesPerPixel*n2read+3*2+2)*(startframe-1),...
                       0); % shift frame data and supplementary
        if status<0
            error('readIOS:OutOfBounds', 'Start frame beyond record length')
        end
        
        
        curFrame2Read = startframe;
        while ~feof(recfileID)
            % check bounds
            if curFrame2Read>endframe
                break
            end
            
            % read frame
            [tmp, counts] = fread(recfileID, n2read, ['*' typePerPixel]);
                        
            if isempty(tmp)
                % no data to read
                break
            end

            if counts<n2read
                % incomplete frame
                warning('readIOS:LostFrame', ...
                        'Frame is lost while reading: %d of %d\n Reader is stopped', ...
                        framesread+1, nframes);
                break
            end
            
            % supplementary data
            fulltime = fread(recfileID, 3, 'uint16=>double');
            if isempty(fulltime)
                % no data to read
                break
            end
            frametime = fulltime(1)+fulltime(2)*1e-3+fulltime(3)*1e-6;
            trignum = fread(recfileID, 1, 'uint16=>double');
            if isempty(trignum)
                % no data to read
                break
            end
            
%             framesread = framesread+1;
%             curframe = mod(framesread-1, eachframe) + 1;
%             if curframe ~= startframe
%                 continue
%             end            
            
            if trignum>max(acqList)
                break
            end

            % decide if to return data
            if (frametime>=tsMin) && (frametime <= tsMax) && ismember(trignum, acqList)
                % preprocess
                tmp = reshape(tmp, vidRes(2), vidRes(1), nbands);
                frame = tmp(maskX, maskY, bandOfInterest);
                if rsize ~= 1.0
                    frame = imresize(frame, [newvidres(2), newvidres(1)]);                    
                end

                % store data
                data(:,:,framesstored+1) = frame;
                t(framesstored+1) = frametime;
                ntrig(framesstored+1) = trignum;
                framesstored = framesstored+1;  
            end           
            
            % shift for each frame
            if eachframe>1
                fseek(recfileID, ...
                      (bytesPerPixel*n2read+3*2+2)*(eachframe-1),...
                      0); % shift frame data and supplementary
            end
            
            curFrame2Read = curFrame2Read + eachframe;
            
        end

        fclose(recfileID);
        vidRes = newvidres;      
        
    catch exception
        fclose(recfileID);
        varargout{1} = NaN;
        throw(exception); 
    end

    switch upper(outMode)
        case 'LIN'
            data = permute(data(:,:,ntrig>0), [1,2,4,3]); % account for matlab image frames dimension
            
            varargout{2} = t(ntrig>0);
            varargout{3} = ntrig(ntrig>0);
            varargout{1} = data;
            return;
        case 'MAT'
            acqLabel = unique(ntrig(ntrig>0))';
            nAcq = length(acqLabel);
            output = struct('nAcq', nAcq,...
                            'acqLabel', acqLabel,...
                            'base', base,...
                            'signal', signal, ...
                            'vidRes', vidRes',...
                            'nbands', nbands);
            for acqNum = acqLabel
                mask = ntrig==acqNum;
                selectionFrames = data(:, :, mask);
                selectionTime = t(mask);

                s = size(selectionFrames);
                
                data(:, :, mask) = [];
                t(mask) = [];
                ntrig(mask) = [];
                
                if length(selectionTime) == 1
                    warning('readIOS:EmptyAcquisition', 'Empty acquisition %d', acqNum);
                    output.(getAcqName(acqNum)) = struct('frames', selectionFrames,...
                                                         't', selectionTime,...
                                                         'nframes', 1);
                else
                    output.(getAcqName(acqNum)) = struct('frames', permute(selectionFrames, [1,2,4,3]),...
                                                         't', selectionTime,...
                                                         'nframes', s(3));
                end
                
                % memory
                selectionFrames = [];
                selectionTime = [];
            end
            varargout{1} = output;
            return            
        otherwise 
            error('readIOS:UnknownOutputFormat', 'Format output %s is unknown', outMode);
    end
end
    
    
function name = getAcqName(idx)
    name = strcat('acq', int2str(idx));
end