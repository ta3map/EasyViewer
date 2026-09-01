function [xOut, yOut] = decimateForDisplay(x, y, maxPoints)
%DECIMATEFORDISPLAY Min/max envelope decimation for line rendering.

x = x(:);
y = y(:);
n = numel(x);

if n <= maxPoints
    xOut = x;
    yOut = y;
    return
end

nBins = max(1, floor(maxPoints / 2));
edges = round(linspace(1, n + 1, nBins + 1));
xOut = zeros(2 * nBins, 1);
yOut = zeros(2 * nBins, 1);
k = 1;

for b = 1:nBins
    i0 = edges(b);
    i1 = edges(b + 1) - 1;
    if b == nBins
        i1 = n;
    end
    if i0 > i1
        continue
    end

    segX = x(i0:i1);
    segY = y(i0:i1);
    [yMin, relMin] = min(segY);
    [yMax, relMax] = max(segY);
    iMin = i0 + relMin - 1;
    iMax = i0 + relMax - 1;

    if iMin <= iMax
        xOut(k) = x(iMin); yOut(k) = yMin; k = k + 1;
        xOut(k) = x(iMax); yOut(k) = yMax; k = k + 1;
    else
        xOut(k) = x(iMax); yOut(k) = yMax; k = k + 1;
        xOut(k) = x(iMin); yOut(k) = yMin; k = k + 1;
    end
end

xOut = xOut(1:k - 1);
yOut = yOut(1:k - 1);

end
