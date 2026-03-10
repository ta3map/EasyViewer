function mins = ZavFindMins(y, frad)
%mins = ZavFindMins(y, frad)
%find local minima
%
%INPUTS
%y - signal (single dimensional)
%frad - minimal distance between minima (not closer than, samples)
%
%OUTPUS
%mins - points of local minima (sample numbers)

if (size(y, 1) == 1)
    y = y';
end

dY = diff(y);%first derivative

%find nulls of first derivative with positive second derivative (points of minimum)
if (~isempty(dY))
    %derivative signature is changed from negative to non-negative! (nulls of funtion dY)
    %dY_nuls = find((sign(dY) == 0) | ((sign([dY(2:end); dY(end)]) - sign(dY)) > 1));%primary nuls
    dY_nuls = find(diff(dY) >= 0);%primary nuls of dY
    mins = dY_nuls + 1;%correction of indices on shift due to derivation
    
    %direct check of minima
    prg = (max(y) - min(y)) / 1e10;%magnitude threshold for minima
    mins((mins < 2) | (mins >= numel(y))) = [];%delete minima on edges
    ii = true(size(mins));
    for t = 1:numel(mins)
        g = mins(t) + (-1:1);
        g = y(g);
        if ~((((g(1) - g(2)) > prg) && ((g(3) - g(2)) > prg)) || ...
             (((g(1) - g(2)) > prg) && (g(3) == g(2))) || ...
             (((g(3) - g(2)) > prg) && (g(1) == g(2))) ...
           )
            ii(t) = false;%delete false minimum
        end
    end
    mins = mins(ii);
    if (nargin > 1) %frequency radius of minima (frad) and deep of minimum was assigned
        t = 1;%
        while (t < numel(mins)) %run over minima
            if ((mins(t + 1) - mins(t)) > frad) %not closer than
                t = t + 1;%accept strong minimum
            else
                if (y(mins(t + 1)) < y(mins(t)))
                    mins(t) = [];%delete neighbour minimum
                else
                    mins(t + 1) = [];%delete neighbour minimum
                end
            end
        end
    end
else
    mins = [];%no minima
end
