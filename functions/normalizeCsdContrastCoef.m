function coef = normalizeCsdContrastCoef(raw)
%NORMALIZECSDCONTRASTCOEF Clamp display contrast % to [10, 250], default 100.

coef = 100;
if nargin < 1 || isempty(raw)
    return
end
raw = double(raw);
raw = raw(:);
raw = raw(isfinite(raw) & isreal(raw));
raw = [raw; 100];
coef = min(max(raw(1), 10), 250);
end
